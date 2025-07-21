const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const print = std.debug.print;
const ReadError = std.fs.File.ReadError;
const OpenError = std.fs.File.OpenError;
const SeekError = std.fs.File.SeekError;
const AllocatorError = std.mem.Allocator.Error;
const DecompressionReadError = @TypeOf(@constCast(&std.compress.zlib.decompressor(@constCast(&std.io.fixedBufferStream(&[_]u8{})).reader())).reader()).Error;
const Allocator = std.mem.Allocator;
const TARGET_ENDIANESS = @import("builtin").target.cpu.arch.endian();

const Instant = std.time.Instant;

const SUPPORTED_PER_CHANNEL_BIT_DEPTH = 8;
const SUPPORTED_NUMBER_OF_CHANNELS = 4;
const BYTES_PER_PIXEL = 4;
const PNG_HEADER_DATA_LENGTH = 13;

// This is the output image after decoding.
pub const PngImage = struct {
    data: []u8,
    width: u32,
    height: u32,
    stride: u32,

    pub fn deinit(self: *PngImage, allocator: Allocator) void {
        allocator.free(self.data);
    }
};

// It would be nicer if we had arrays in packed structs/unions. But we don't yet.
fn PunnableBigEndianInt(backing_type: type) type {
    return packed struct {
        const BYTE_LENGTH: comptime_int = @sizeOf(backing_type);

        value: backing_type,

        fn bytes(self: *@This()) []u8 {
            return @as(*[@sizeOf(backing_type)]u8, @ptrCast(self));
        }

        fn native_endian(self: @This()) backing_type {
            if (comptime TARGET_ENDIANESS == .little) {
                return @byteSwap(self.value);
            } else {
                return self.value;
            }
        }
    };
}

const PngFilterType = enum(u8) { NONE = 0, SUB = 1, UP = 2, AVERAGE = 3, PAETH = 4 };
const PngColorType = enum(u8) { GRAYSCALE = 0, RGB = 2, PALETTE = 3, GRAYSCALE_ALPHA = 4, RGB_ALPHA = 6 };
const PngCompressionMethod = enum(u8) { DEFLATE = 0 };
const PngFilterMethod = enum(u8) { ADAPTIVE = 0 };
const PngInterlaceMethod = enum(u8) { NONE = 0, ADAM7 = 1 };

pub const PngSignatureError = error{
    InvalidSignature,
};

const PngSignature = extern union {
    bytes: [8]u8,
    uint: u64,

    pub fn from_file(file: fs.File) FileReadError!PngSignature {
        var signature: PngSignature = undefined;
        try read_into(file, &signature.bytes);

        return signature;
    }

    pub fn validate(self: *const PngSignature, comptime optimistic: bool) PngSignatureError!void {
        const EXPECTED_PNG_SIGNATURE = comptime [8]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

        if (comptime optimistic) return;

        if (!(self.uint == comptime @as(u64, @bitCast(EXPECTED_PNG_SIGNATURE)))) {
            return PngSignatureError.InvalidSignature;
        }
    }
};

const PngChunkType = enum(u32) {
    HEADER = @bitCast([4]u8{ 'I', 'H', 'D', 'R' }),
    DATA = @bitCast([4]u8{ 'I', 'D', 'A', 'T' }),
    END = @bitCast([4]u8{ 'I', 'E', 'N', 'D' }),

    _, // Catch all.

    pub inline fn bytes(chunk_type: *PngChunkType) []u8 {
        return @as(*[4]u8, @ptrCast(chunk_type));
    }
};

pub const PngChunkError = error{
    CrcCheckFailed,
    DataBufferTooSmall,
} || FileReadError || AllocatorError || SeekError;

const PngChunk = struct {
    length: PunnableBigEndianInt(u32),
    type: PngChunkType,
    data: []u8,
    checksum: PunnableBigEndianInt(u32),

    fn read_length_and_type(self: *PngChunk, file: fs.File) PngChunkError!void {
        try read_into(file, self.length.bytes());
        try read_into(file, self.type.bytes());
    }

    fn read_the_rest(self: *PngChunk, comptime optimistic: bool, file: fs.File, data_buffer: []u8) PngChunkError!void {
        if (data_buffer.len < self.length.native_endian()) {
            return PngChunkError.DataBufferTooSmall;
        }
        self.data = data_buffer;
        try read_into(file, self.data);

        if (comptime optimistic) {
            try file.seekBy(@TypeOf(self.checksum).BYTE_LENGTH);
        } else {
            try read_into(file, self.checksum.bytes());
        }
    }
};

const CrcError = error{
    CrcCheckFailed,
};

fn cyclic_redundancy_check(
    comptime optimistic: bool,
    type_bytes: []const u8,
    data_bytes: []const u8,
    expected_checksum: PunnableBigEndianInt(u32),
) CrcError!void {
    if (comptime optimistic) return;

    if (compute_checksum: {
        var polynomial_code = std.hash.crc.Crc32.init();
        polynomial_code.update(type_bytes);
        polynomial_code.update(data_bytes);
        break :compute_checksum polynomial_code.final();
    } != expected_checksum.native_endian()) {
        return CrcError.CrcCheckFailed;
    }
}

pub const PngHeaderError = error{
    InvalidHeaderFormat,
    UnsupportedColorType,
    UnsupportedBitDepth,
    UnsupportedCompressionMethod,
    UnsupportedFilterMethod,
    UnsupportedInterlaceMethod,
} || CrcError;

const HeaderBackingInt: type = u200;

const PngHeaderFields = packed struct(HeaderBackingInt) {
    length: PunnableBigEndianInt(u32),
    type: PngChunkType,
    width: PunnableBigEndianInt(u32),
    height: PunnableBigEndianInt(u32),
    bit_depth: u8,
    color_type: PngColorType,
    compression_method: PngCompressionMethod,
    filter_method: PngFilterMethod,
    interlace_method: PngInterlaceMethod,
    checksum: PunnableBigEndianInt(u32),

    pub fn validate(self: *const PngHeaderFields) PngHeaderError!void {
        if (self.length.native_endian() != PNG_HEADER_DATA_LENGTH) return PngHeaderError.InvalidHeaderFormat;
        if (self.type != PngChunkType.HEADER) return PngHeaderError.InvalidHeaderFormat;
        // if (self.width.native_endian() == 0 or self.height.native_endian() == 0) return PngHeaderError.InvalidHeaderFormat;
        if (self.bit_depth != SUPPORTED_PER_CHANNEL_BIT_DEPTH) return PngHeaderError.UnsupportedBitDepth;
        if (self.color_type != PngColorType.RGB_ALPHA) return PngHeaderError.UnsupportedColorType;
        if (self.compression_method != PngCompressionMethod.DEFLATE) return PngHeaderError.UnsupportedCompressionMethod;
        if (self.filter_method != PngFilterMethod.ADAPTIVE) return PngHeaderError.UnsupportedFilterMethod;
        if (self.interlace_method != PngInterlaceMethod.NONE) return PngHeaderError.UnsupportedInterlaceMethod;
    }
};

const PngHeader = packed struct(HeaderBackingInt) {
    const TYPE_OFFSET: comptime_int = 4;
    const CRC_OFFSET: comptime_int = 21;

    fields: PngHeaderFields,

    pub fn from_file(file: fs.File) PngChunkError!PngHeader {
        var png_header: PngHeader = undefined;
        try read_into(file, png_header.bytes());

        return png_header;
    }

    pub fn bytes(self: *PngHeader) []u8 {
        return @as(*[25]u8, @ptrCast(self));
    }

    pub fn const_bytes(self: *const PngHeader) []const u8 {
        return @as(*const [25]u8, @ptrCast(self));
    }

    pub fn validate(self: *const PngHeader, comptime optimistic: bool) PngHeaderError!void {
        if (comptime optimistic) return;

        try self.fields.validate();

        try cyclic_redundancy_check(
            optimistic,
            self.const_bytes()[TYPE_OFFSET .. TYPE_OFFSET + 4],
            self.const_bytes()[TYPE_OFFSET + 4 .. CRC_OFFSET],
            self.fields.checksum,
        );
    }
};

pub const FileReadError = error{
    EndOfStream,
} || ReadError;

fn read_into(file: fs.File, buffer: []u8) FileReadError!void {
    const bytes_read = try file.readAll(buffer);

    if (bytes_read < buffer.len) {
        return FileReadError.EndOfStream;
    }
}

pub const PngDecompressionError = error{
    CouldNotReadAll,
} || DecompressionReadError || AllocatorError;

fn decompress_image_data(
    input_compressed_image_data: []const u8,
    output_decompressed_image_data: []u8,
) PngDecompressionError!void {
    var compressed_data_stream = std.io.fixedBufferStream(input_compressed_image_data);
    var zlib_decompressor = std.compress.zlib.decompressor(compressed_data_stream.reader());
    const bytes_read = try zlib_decompressor.reader().readAll(output_decompressed_image_data);

    comptime std.debug.assert(@TypeOf(zlib_decompressor.reader()).Error == DecompressionReadError);

    if (bytes_read != output_decompressed_image_data.len) {
        return PngDecompressionError.CouldNotReadAll;
    }
}

fn paeth_predictor_function(comptime int_type: type, left_byte: int_type, above_byte: int_type, upper_left_byte: int_type) int_type {
    const predicted_value = left_byte + above_byte - upper_left_byte;
    const distance_to_left = @abs(predicted_value - left_byte);
    const distance_to_above = @abs(predicted_value - above_byte);
    const distance_to_upper_left = @abs(predicted_value - upper_left_byte);

    if (distance_to_left <= distance_to_above and distance_to_left <= distance_to_upper_left) {
        return left_byte;
    } else if (distance_to_above <= distance_to_upper_left) {
        return above_byte;
    } else {
        return upper_left_byte;
    }
}

const PngReconstructionError = error{ InvalidFilterType, PathologicalImageNotSupported } || AllocatorError || std.meta.IntToEnumError;

// TODO: Optimization
//      Constraints:
//          Pixels rely on any of the previous, above or above-left pixels. So we can't parallelize trivially.
//          However, there are several combinations of (possibly consecutive) filter types that can be parallelized.
//
//          - All rows that use NONE can be done in parallel, and will not affect the other rows no matter what.
//
//          - All rows that use SUB can be parallelized along their columns.
//
//          - rows that uses UP can be parallelized along the row, as long as the previous row is already unfiltered.
//
//          - The first 4 bytes (1 pixel) of each row can all be done in parallel if they use NONE or SUB,
//          and their unfiltered value is just their own value, so it's skipped entirely if we first strip filter type data.
//
//          - The first 4 bytes (1 pixel) of each row can be done in parallel if they use UP, AVERAGE or PAETH,
//          as long as the previous row is already unfiltered.

pub fn unfilter_image(
    comptime optimistic: bool,
    filtered_data: []u8,
    pixel_width: u32,
    pixel_height: u32,
) PngReconstructionError!void {
    const int_type = i32;
    const image_byte_width = pixel_width * BYTES_PER_PIXEL;
    const scanline_width = image_byte_width + 1;

    if (comptime optimistic) @setRuntimeSafety(false);
    defer if (comptime optimistic) @setRuntimeSafety(true);

    for (0..pixel_height) |row_index| {
        const filter_type: PngFilterType = @enumFromInt(filtered_data[row_index * scanline_width]);
        const filtered_scanline_start_index = row_index * scanline_width;
        const unfiltered_scanline_start_index = filtered_scanline_start_index - row_index;

        // Handle the first 4 bytes separately (no left pixel exists).
        for (0..BYTES_PER_PIXEL) |column_byte_index| {
            const write_index = unfiltered_scanline_start_index + column_byte_index;
            const filtered_byte = filtered_data[filtered_scanline_start_index + 1 + column_byte_index];

            // NOTE: left is always 0 for the first 4 bytes.
            filtered_data[write_index] = @intCast(filter_result: {
                switch (filter_type) {
                    .NONE, .SUB => break :filter_result filtered_byte,
                    .UP => {
                        const upper = @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index]);
                        break :filter_result @as(int_type, filtered_byte) + upper;
                    },
                    .AVERAGE => {
                        const upper =  @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index]);
                        break :filter_result @as(int_type, filtered_byte) + @divFloor(upper, 2);
                    },
                    .PAETH => {
                        const upper =  @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index]);
                        break :filter_result  @as(int_type, filtered_byte) + paeth_predictor_function(int_type, 0, upper, 0);
                    },
                }
            } & 0xFF);
        }

        for (BYTES_PER_PIXEL..image_byte_width) |column_byte_index| {
            const write_index = unfiltered_scanline_start_index + column_byte_index;
            const filtered_byte = filtered_data[filtered_scanline_start_index + 1 + column_byte_index];

            filtered_data[write_index] = @intCast(filter_result: {
                switch (filter_type) {
                    .NONE => break :filter_result @as(int_type, filtered_byte),
                    .SUB => {
                        const left = @as(int_type, filtered_data[write_index - BYTES_PER_PIXEL]);
                        break :filter_result @as(int_type, filtered_byte) + left;
                    },
                    .UP => {
                        const upper = @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index]);
                        break :filter_result @as(int_type, filtered_byte) + upper;
                    },
                    .AVERAGE => {
                        const left = @as(int_type, filtered_data[write_index - BYTES_PER_PIXEL]);
                        const upper = @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index]);
                        break :filter_result @as(int_type, filtered_byte) + @divFloor(left + upper, 2);
                    },
                    .PAETH => {
                        const left = @as(int_type, filtered_data[write_index - BYTES_PER_PIXEL]);
                        const upper = @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index]);
                        const upper_left = @as(int_type, filtered_data[unfiltered_scanline_start_index - image_byte_width + column_byte_index - BYTES_PER_PIXEL]);
                        break :filter_result @as(int_type, filtered_byte) + paeth_predictor_function(int_type, left, upper, upper_left);
                    },
                }
            } & 0xFF);
        }
    }
}

pub const PngDecodeError = error{
    MissingHeaderChunk,
} || OpenError || FileReadError || SeekError || PngSignatureError || PngHeaderError || PngChunkError || PngDecompressionError || PngReconstructionError;

pub const PngDecodeConfig = struct {
    compression_factor_lower_bound: u16 = 1, // No compression.
    // no_allocations: bool = false,
    optimistic: bool = false,
};

pub fn decode_png_file(
    comptime config: PngDecodeConfig,
    filename: []const u8,
    allocator: Allocator,
) PngDecodeError!PngImage {
    comptime std.debug.assert(config.compression_factor_lower_bound < 1032);

    const t0 = Instant.now() catch unreachable;
    const png_file = try fs.cwd().openFile(filename, .{});
    defer png_file.close();

    const t1 = Instant.now() catch unreachable;
    const signature = try PngSignature.from_file(png_file);
    try signature.validate(config.optimistic);

    const t2 = Instant.now() catch unreachable;
    const header = try PngHeader.from_file(png_file);
    try header.validate(config.optimistic);

    const t3 = Instant.now() catch unreachable;

    const decompressed_image_size: usize = ( //
        header.fields.width.native_endian() * header.fields.height.native_endian() * BYTES_PER_PIXEL //
        + header.fields.height.native_endian() // One extra byte per row for the filter type.
    );

    // This overallocates a bit, but I don't know if we can do better before parsing chunks.
    const upper_bound_compressed_image_size = ( //
        (try png_file.metadata()).size() //
        - @bitSizeOf(PngSignature) / 8 - @bitSizeOf(PngHeader) / 8 //
        - 3 * @sizeOf(PngChunkType) //
    );

    const t4 = Instant.now() catch unreachable;

    const work_buffer = try allocator.alignedAlloc(u8, BYTES_PER_PIXEL, decompressed_image_size + upper_bound_compressed_image_size);

    var actual_compressed_image_size: usize = 0;
    var previous_data_chunk_index: usize = decompressed_image_size;

    const t5 = Instant.now() catch unreachable;

    chunk_read_loop: while (true) {
        var png_chunk: PngChunk = undefined;
        try png_chunk.read_length_and_type(png_file);

        switch (png_chunk.type) {
            .DATA => {},
            .END => break :chunk_read_loop,
            else => {
                try png_file.seekBy(@intCast(png_chunk.length.native_endian() + @TypeOf(png_chunk.checksum).BYTE_LENGTH));
                continue :chunk_read_loop;
            },
        }

        try png_chunk.read_the_rest(
            config.optimistic,
            png_file,
            work_buffer[previous_data_chunk_index .. previous_data_chunk_index + png_chunk.length.native_endian()],
        );

        try cyclic_redundancy_check(
            config.optimistic,
            png_chunk.type.bytes(),
            png_chunk.data,
            png_chunk.checksum,
        );

        previous_data_chunk_index += png_chunk.length.native_endian();
    }
    actual_compressed_image_size = previous_data_chunk_index - decompressed_image_size;

    const t6 = Instant.now() catch unreachable;

    try decompress_image_data(
        work_buffer[decompressed_image_size .. decompressed_image_size + actual_compressed_image_size],
        work_buffer[0..decompressed_image_size],
    );

    const t7 = Instant.now() catch unreachable;

    try unfilter_image(
        config.optimistic,
        work_buffer[0..decompressed_image_size],
        header.fields.width.native_endian(),
        header.fields.height.native_endian(),
    );

    const t8 = Instant.now() catch unreachable;

    // TODO: Print stats about which parts of the process takes how long.

    std.debug.print("Diff: {d} bytes\n", .{@as(i64, @intCast(actual_compressed_image_size)) - @as(i64, @intCast(upper_bound_compressed_image_size))});
    std.debug.print("PNG signature read took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t1.since(t0)))});
    std.debug.print("PNG header read took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t2.since(t1)))});
    std.debug.print("PNG header validated took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t3.since(t2)))});
    std.debug.print("PNG allocate work buffer took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t5.since(t4)))});
    std.debug.print("PNG read chunks took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t6.since(t5)))});
    std.debug.print("PNG decompress image data took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t7.since(t6)))});
    std.debug.print("PNG unfilter image took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t8.since(t7)))});
    std.debug.print("PNG total decode took: {d:.3} ms\n", .{1e-6 * @as(f64, @floatFromInt(t8.since(t0)))});

    if (!allocator.resize(work_buffer, decompressed_image_size)) {
        if (!config.optimistic) {
            std.debug.print("Passed allocator does not support resize, returning full buffer with work data still included.", .{});
        }
        return PngImage{
            .data = work_buffer,
            .width = header.fields.width.native_endian(),
            .height = header.fields.height.native_endian(),
            .stride = header.fields.width.native_endian() * BYTES_PER_PIXEL,
        };
    } else {
        return PngImage{
            .data = work_buffer[0..decompressed_image_size],
            .width = header.fields.width.native_endian(),
            .height = header.fields.height.native_endian(),
            .stride = header.fields.width.native_endian() * BYTES_PER_PIXEL,
        };
    }
}
