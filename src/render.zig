/// Using SDL2 for window management and pointers to GPU buffers.
const std = @import("std");
const SDL = @import("sdl2");
const png = @cImport(@cInclude("png.h"));
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
});

const constants = @import("constants.zig");
const visual_assets = @import("visual_assets.zig");
const utils = @import("utils.zig");
const stages = @import("stages.zig");

const Vec = @import("types.zig").Vec;
const VecI32 = @import("types.zig").VecI32;
const float = @import("types.zig").float;

const WindowSettings = struct {
    const title: [*]const u8 = "Battlebuds";
    const width: u16 = constants.X_RESOLUTION;
    const height: u16 = constants.Y_RESOLUTION;
    const x0 = SDL.SDL_WINDOWPOS_CENTERED;
    const y0 = SDL.SDL_WINDOWPOS_CENTERED;
    const sdl_flags = SDL.SDL_WINDOW_SHOWN; // | SDL.SDL_WINDOW_BORDERLESS;
};

fn toPixelX(x: float) u16 {
    return @intFromFloat(x * constants.PIXELS_PER_METER + @as(float, @floatFromInt(WindowSettings.width / 2)));
}

fn vecToPixelX(X: Vec) VecI32 {
    const ppm: Vec = @splat(constants.PIXELS_PER_METER);
    const screen_halfwidth: VecI32 = @splat(WindowSettings.width / 2);

    return @intFromFloat(X * ppm + @as(Vec, @floatFromInt(screen_halfwidth)));
}

fn toPixelY(y: float) i32 {
    return @intFromFloat(@as(float, @floatFromInt(WindowSettings.height / 2)) - y * constants.PIXELS_PER_METER);
}

fn vecToPixelY(Y: Vec) VecI32 {
    const ppm: Vec = @splat(constants.PIXELS_PER_METER);
    const screen_halfheight: VecI32 = @splat(WindowSettings.height / 2);

    return @intFromFloat(-Y * ppm + @as(Vec, @floatFromInt(screen_halfheight)));
}

const Image = struct {
    buffer: ?*anyopaque,
    width: c_int,
    height: c_int,
    stride: c_int,
    bit_depth: c_int,

    fn free(self: Image) void {
        c.free(self.buffer);
    }
};

const ReadError = error{ OutOfMemory, FailedImageRead };

pub const DynamicEntities = struct {
    const NUM = constants.VEC_LENGTH;

    X: VecI32 = @splat(0),
    Y: VecI32 = @splat(0),
    modes: [NUM]visual_assets.EntityMode = .{.{ .dont_load = visual_assets.DontLoadMode.TEXTURE }} ** NUM,

    pub inline fn init(
        self: *DynamicEntities,
        starting_positions: [constants.MAX_NUM_PLAYERS]stages.Position,
        shuffled_indices: [constants.MAX_NUM_PLAYERS]u8,
        entity_modes: [constants.MAX_NUM_PLAYERS]visual_assets.EntityMode,
    ) void {
        for (shuffled_indices, 0..constants.MAX_NUM_PLAYERS) |idx, i| {
            self.X[i] = toPixelX(starting_positions[idx].x);
            self.Y[i] = toPixelY(starting_positions[idx].y);
            self.modes[i] = entity_modes[i];
        }
    }

    pub fn updatePosition(self: *DynamicEntities, X: Vec, Y: Vec) void {
        self.X = vecToPixelX(X);
        self.Y = vecToPixelY(Y);
    }
};

pub const Renderer = struct {
    renderer: *SDL.SDL_Renderer = undefined,
    window: *SDL.SDL_Window = undefined,
    num_textures: u8 = undefined,

    pub fn init(comptime self: *Renderer) *Renderer {
        // TODO: Once controller exiting is done, disable SDL_INIT_EVENTS.
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) {
            utils.sdlPanic();
        }
        self.window = SDL.SDL_CreateWindow(
            WindowSettings.title,
            WindowSettings.x0,
            WindowSettings.y0,
            WindowSettings.width,
            WindowSettings.height,
            WindowSettings.sdl_flags,
        ) orelse utils.sdlPanic();

        self.renderer = SDL.SDL_CreateRenderer(self.window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse utils.sdlPanic();

        if (SDL.SDL_SetRenderDrawBlendMode(self.renderer, SDL.SDL_BLENDMODE_BLEND) < 0) {
            utils.sdlPanic();
        }

        Textures.init(self.renderer);

        utils.assert(Textures.map.cur_back_idx < Textures.map.cur_front_idx, "Can't loop through texture map if it's not full.");

        for (Textures.map.things) |textures| {
            for (textures) |*texture| {
                if (texture.ptr) |ptr| {
                    if (SDL.SDL_SetTextureBlendMode(ptr, SDL.SDL_BLENDMODE_BLEND) < 0) {
                        utils.sdlPanic();
                    }
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        Textures.deinit();
        _ = SDL.SDL_DestroyRenderer(self.renderer);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    fn corrected_animation_counter(counter: usize, comptime slowdown_factor: float) usize {
        return @intFromFloat(@floor(@as(float, @floatFromInt(counter)) / slowdown_factor));
    }

    pub fn draw_dynamic_entities(
        self: *Renderer,
        counter: usize,
        dynamic_entities: *DynamicEntities,
        comptime slowdown_factor: float,
    ) !void {
        const N = DynamicEntities.NUM;

        for (
            @as([N]i32, dynamic_entities.X),
            @as([N]i32, dynamic_entities.Y),
            dynamic_entities.modes,
        ) |x, y, mode| {
            const id = visual_assets.IDFromEntityMode(mode);
            if (id == .DONT_LOAD_TEXTURE) continue;

            const textures = try Textures.map.lookup(id, false);
            const animation_counter = corrected_animation_counter(counter, slowdown_factor);
            const texture = textures[animation_counter % textures.len];

            _ = SDL.SDL_RenderCopy(
                self.renderer,
                texture.ptr,
                null,
                &SDL.SDL_Rect{
                    .x = x - @divExact(texture.width, 2),
                    .y = y - @divExact(texture.height, 2),
                    .w = texture.width,
                    .h = texture.height,
                },
            );
        }
    }

    pub fn draw_looping_animations(
        self: *Renderer,
        counter: usize,
        asset_ids: []const visual_assets.ID,
        comptime slowdown_factor: float,
    ) !void {
        for (asset_ids) |asset_id| {
            const animation_counter = corrected_animation_counter(counter, slowdown_factor);
            self.draw_animation_frame(animation_counter, asset_id) catch unreachable;
            // const textures = try Textures.map.lookup(asset_id, false);
            // const texture = textures[animation_counter % textures.len];
            // _ = SDL.SDL_RenderCopy(self.renderer, texture.ptr, null, null);
        }
    }
    pub fn draw_animation_frame(
        self: *Renderer,
        frame_index: usize,
        asset_id: visual_assets.ID,
    ) !void {
        const textures = try Textures.map.lookup(asset_id, false);
        const texture = textures[frame_index % textures.len];
        _ = SDL.SDL_RenderCopy(self.renderer, texture.ptr, null, null);
    }

    pub fn render(self: *Renderer) void {
        SDL.SDL_RenderPresent(self.renderer);
    }
};

fn fillWithColor(renderer: *SDL.SDL_Renderer) void {
    if (SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF) < 0) {
        utils.sdlPanic();
    }
    if (SDL.SDL_RenderClear(renderer) < 0) { // Note: read "Clear" as "Fill"
        utils.sdlPanic();
    }
}

// TODO: look into whether texture_slices can be const or not.
pub const Textures = struct {
    const FORMAT: c_int = SDL.SDL_PIXELFORMAT_ABGR8888;
    const ACCESS_MODE: c_int = SDL.SDL_TEXTUREACCESS_STREAMING;

    var map = utils.StaticMap(visual_assets.ID.size(), visual_assets.ID, []visual_assets.Texture);

    pub fn init(
        renderer: *SDL.SDL_Renderer,
    ) void {
        inline for (std.meta.fields(visual_assets.ID)) |enum_field| {
            const id: visual_assets.ID = @enumFromInt(enum_field.value);
            var count: usize = 0;

            // For simplicity, just check all visual assets.
            for (visual_assets.ALL) |visual_asset| {
                if (visual_asset.id != id or visual_asset.id == .DONT_LOAD_TEXTURE) continue;

                loadTexture(
                    &visual_assets.texture_slices[id.int()][count],
                    visual_asset.path,
                    renderer,
                    FORMAT,
                    ACCESS_MODE,
                ) catch unreachable;

                count += 1;

                if (count > visual_assets.texture_slices[id.int()].len) break;
            }
            map.insert(id, visual_assets.texture_slices[id.int()], false) catch unreachable;
        }
    }

    pub fn deinit() void {
        for (map.things) |textures| {
            for (textures) |texture| {
                SDL.SDL_DestroyTexture(texture.ptr);
            }
        }
    }
};

fn loadTexture(
    texture: *visual_assets.Texture,
    path: []const u8,
    renderer: *SDL.SDL_Renderer,
    comptime format: c_int,
    comptime access_mode: c_int,
) ReadError!void {
    const c_str_path = @as([*:0]const u8, @ptrCast(path));
    const image = try readPng(c_str_path, png.PNG_FORMAT_RGBA);
    defer image.free();

    texture.ptr = SDL.SDL_CreateTexture(
        renderer,
        format,
        access_mode,
        image.width,
        image.height,
    ) orelse utils.sdlPanic();

    texture.width = image.width;
    texture.height = image.height;

    var pixels: ?*c_int = undefined;
    var stride: c_int = undefined;
    const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));
    const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

    utils.assert(
        SDL.SDL_LockTexture(texture.ptr, null, pixels_ptr, stride_ptr) == 0,
        "SDL_LockTexture() failed.",
    );

    const stride_gpu = toUsizeChecked(stride);
    const stride_cpu = toUsizeChecked(image.stride);
    const start_addr_gpu = opaqueToAddr(pixels_ptr[0].?);
    const start_addr_cpu = opaqueToAddr(image.buffer.?);
    const width = toUsizeChecked(image.width);
    const height = toUsizeChecked(image.height);

    copyPixels(start_addr_cpu, start_addr_gpu, stride_cpu, stride_gpu, width, height);

    SDL.SDL_UnlockTexture(texture.ptr);

    // return .{ .ptr = texture.ptr, .width = image.width, .height = image.height };
}

// Translated expanded C macros from libpng
//-----------------------------------------
fn imageSize(image: png.png_image) c_ulong {
    return @as(c_ulong, @bitCast(@as(c_ulong, ((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 4)) >> @intCast(2)) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.height))) *% ((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else (@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.width))))));
}
fn imageRowStride(image: png.png_image) c_int {
    return @as(c_int, @bitCast((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else (@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.width))));
}
fn imagePixelSize(image: png.png_image) c_int {
    return @as(c_int, @bitCast(if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else ((@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% (((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 4)) >> @intCast(2)) +% @as(c_uint, @bitCast(@as(c_int, 1))))));
}
//-----------------------------------------

// Based on example.c from libpng. Note: calls malloc
fn readPng(path: [*:0]const u8, format: c_uint) ReadError!Image {
    var img: png.png_image = undefined;
    _ = c.memset(&img, 0, @sizeOf(png.png_image));
    img.version = png.PNG_IMAGE_VERSION;

    if (png.png_image_begin_read_from_file(&img, path) != 0) {
        img.format = format;
        const buf = c.malloc(imageSize(img));

        if (buf == null) {
            png.png_image_free(&img);
            return ReadError.OutOfMemory;
        }
        if (png.png_image_finish_read(&img, null, buf, 0, null) != 0) {
            const pixel_size = imagePixelSize(img);
            const stride = imageRowStride(img);
            return Image{ .buffer = buf.?, .width = @intCast(img.width), .height = @intCast(img.height), .stride = stride, .bit_depth = 8 * pixel_size };
        } else {
            c.free(buf); // Buffer was allocated, but image read failed.
        }
    }
    std.debug.print("Error message from libpng: {s}", .{img.message});
    return ReadError.FailedImageRead;
}

fn opaqueToAddr(ptr: *anyopaque) usize {
    return @intFromPtr(@as(*u8, @ptrCast(ptr)));
}

fn toUsizeChecked(integer: anytype) usize {
    @setRuntimeSafety(true);
    return @as(usize, @intCast(integer));
}

// C-style pointer arithmatic
fn copyPixels(start_addr_src: usize, start_addr_dest: usize, stride_src: usize, stride_dest: usize, width: usize, height: usize) void {
    for (0..height) |row| {
        var ptr_src = @as([*]u32, @ptrFromInt(start_addr_src + row * stride_src));
        var ptr_dest = @as([*]u32, @ptrFromInt(start_addr_dest + row * stride_dest));

        for (0..width) |_| {
            ptr_src += 1;
            ptr_dest += 1;
            ptr_dest[0] = ptr_src[0];
        }
    }
}
