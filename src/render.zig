/// SDL2 for window management and pointers to GPU buffers.
const std = @import("std");
const SDL = @import("sdl2");
const utils = @import("utils.zig");
const stages = @import("stages.zig");
const Vec = @import("physics.zig").Vec;
const VecU16 = @import("physics.zig").VecU16;
const float = @import("physics.zig").float;
const vec_length = @import("physics.zig").vec_length;
const png = @cImport(@cInclude("png.h"));
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
});

const WindowSettings = struct {
    const title: [*]const u8 = "Battlebuds";
    const width: u16 = 1920;
    const height: u16 = 1080;
    const x0 = SDL.SDL_WINDOWPOS_CENTERED;
    const y0 = SDL.SDL_WINDOWPOS_CENTERED;
    const sdl_flags = SDL.SDL_WINDOW_SHOWN; // | SDL.SDL_WINDOW_BORDERLESS;
};

pub const pixels_per_meter: float = @as(float, @floatFromInt(WindowSettings.width)) / stages.stage_width_meters;

// We assume x is on the screen, check at callsite.
fn toPixelX(x: float) u16 {
    return @intFromFloat(x * pixels_per_meter + @as(float, @floatFromInt(WindowSettings.width / 2)));
}
fn vecToPixelX(X: Vec) VecU16 {
    const ppm: Vec = @splat(pixels_per_meter);
    const screen_halfwidth: VecU16 = @splat(WindowSettings.width / 2);

    return @intFromFloat(X * ppm + @as(Vec, @floatFromInt(screen_halfwidth)));
}

// We assume y is on the screen, check at callsite.
fn toPixelY(y: float) u16 {
    return @intFromFloat(@as(float, @floatFromInt(WindowSettings.height / 2)) - y * pixels_per_meter);
}
fn vecToPixelY(Y: Vec) VecU16 {
    const ppm: Vec = @splat(pixels_per_meter);
    const screen_halfheight: VecU16 = @splat(WindowSettings.height / 2);

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

const Asset = struct {
    path: []const u8,
    id: ID,
};

const ID = enum {
    NONE,
    FIRST_GUY,
};

const game_assets: [1]Asset = .{
    .{ .path = "assets/first_guy_big.png", .id = .FIRST_GUY },
    // "assets/first_guy.png",
};

const Textures = struct {
    const Tex = struct {
        ptr: *SDL.SDL_Texture,
        width: c_int,
        height: c_int,
    };
    map: @TypeOf(utils.StaticMap(game_assets.len, Tex, ID)) = utils.StaticMap(game_assets.len, Tex, ID),
};

const ReadError = error{ OutOfMemory, FailedImageRead };

pub const Entities = struct {
    const max_entities = 1024;
    const num_dynamic_entities = vec_length;
    // var pos_memory: [2 * max_entities]u16 = .{inactive_barrier} ** (2 * max_entities);
    // var mode_memory: [max_entities]EntityMode = .{.{ .first_guy = FirstGuyMode.NONE }} ** max_entities;

    X_dynamic: VecU16 = @splat(0),
    Y_dynamic: VecU16 = @splat(0),
    modes_dynamic: [num_dynamic_entities]EntityMode = .{.{ .common = CommonMode.NONE }} ** num_dynamic_entities,

    pub fn init(
        self: *Entities,
        comptime num_players: u8,
        stage: *const @TypeOf(stages.s0),
        shuffled_indices: [num_players]u8,
    ) *Entities {
        for (shuffled_indices, 0..num_players) |idx, i| {
            self.X_dynamic[i] = toPixelX(stage.starting_positions[idx].x);
            self.Y_dynamic[i] = toPixelY(stage.starting_positions[idx].y);
            self.modes_dynamic[i] = .{ .first_guy = .STANDING };
        }

        return self;
    }

    pub fn updateDynamicEntities(self: *Entities, X: Vec, Y: Vec) void {
        // TODO: can do this as a vector operation potentially
        self.X_dynamic = vecToPixelX(X);
        self.Y_dynamic = vecToPixelY(Y);
    }
};

const ModeBackingInt = u16;

const CommonMode = enum(ModeBackingInt) {
    NONE,
};

const CharacterMode = enum(ModeBackingInt) {
    DEAD,
    STANDING,
    RUNNING,
    JUMPING,
};

const ObjectMode = enum(ModeBackingInt) {
    NORMAL,
    BREAKING,
    BROKEN,
    BALLISTIC,
};

const FirstGuyMode = enum(ModeBackingInt) {
    DEAD,
    STANDING,
    RUNNING,
    JUMPING,
};

const EntityMode = union(enum(ModeBackingInt)) {
    common: CommonMode,
    first_guy: FirstGuyMode,
    character: CharacterMode,
    object: ObjectMode,
};

const ModeIdError = error{
    MissingMode,
};

// I want to do this with a utils.StaticMap later
// so I can make a character select screen that maps asset groups to
// character types.
fn EntityModeToAssetID(mode: EntityMode) ModeIdError!ID {
    switch (mode) {
        .common => |common_mode| switch (common_mode) {
            .NONE => return ID.NONE,
        },
        .first_guy => |first_guy_mode| switch (first_guy_mode) {
            .DEAD => return ModeIdError.MissingMode,
            .STANDING => return ID.FIRST_GUY,
            .RUNNING => return ModeIdError.MissingMode,
            .JUMPING => return ModeIdError.MissingMode,
        },
        .object => |obj_mode| switch (obj_mode) {
            .NORMAL => return ModeIdError.MissingMode,
            .BREAKING => return ModeIdError.MissingMode,
            .BROKEN => return ModeIdError.MissingMode,
            .BALLISTIC => return ModeIdError.MissingMode,
        },
        else => return ModeIdError.MissingMode,
    }
    unreachable;
    // return ModeIdError.MissingMode;
}

pub const Renderer = struct {
    textures: Textures = undefined,
    renderer: *SDL.SDL_Renderer = undefined,
    window: *SDL.SDL_Window = undefined,
    num_textures: u8 = undefined,

    pub fn init(self: *Renderer) *Renderer {
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

        self.load_textures(&game_assets) catch |err| std.debug.panic("Error: {any}", .{err});

        // NOTE: This will fail if the map is not full
        for (0..self.textures.map.things.len) |i| {
            if (SDL.SDL_SetTextureBlendMode(self.textures.map.things[i].ptr, SDL.SDL_BLENDMODE_BLEND) < 0) {
                utils.sdlPanic();
            }
        }

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        for (self.textures.map.things) |tex| SDL.SDL_DestroyTexture(tex.ptr);
        _ = SDL.SDL_DestroyRenderer(self.renderer);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    // Read .png files to GPU texture buffers and store their pointers.
    fn load_textures(self: *Renderer, comptime assets: []const Asset) !void {
        const format = SDL.SDL_PIXELFORMAT_ABGR8888;
        const access_mode = SDL.SDL_TEXTUREACCESS_STREAMING;

        for (assets) |asset| {
            const path = @as([*:0]const u8, @ptrCast(asset.path));
            const image = try readPng(path, png.PNG_FORMAT_RGBA);
            defer image.free();

            try self.textures.map.insert(
                asset.id,
                .{
                    .ptr = SDL.SDL_CreateTexture(
                        self.renderer,
                        format,
                        access_mode,
                        image.width,
                        image.height,
                    ) orelse utils.sdlPanic(),
                    .width = image.width,
                    .height = image.height,
                },
                false,
            );
            // self.textures.sdl_textures[i] = SDL.SDL_CreateTexture(self.renderer, format, access_mode, image.width, image.height,) orelse utils.sdlPanic();

            var pixels: ?*c_int = undefined;
            var stride: c_int = undefined;
            const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));
            const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

            utils.assert(SDL.SDL_LockTexture(
                (try self.textures.map.lookup(asset.id, false)).ptr,
                null,
                pixels_ptr,
                stride_ptr,
            ) == 0, "SDL_LockTexture() failed.");

            const stride_gpu = toUsizeChecked(stride);
            const stride_cpu = toUsizeChecked(image.stride);
            const start_addr_gpu = opaqueToAddr(pixels_ptr[0].?);
            const start_addr_cpu = opaqueToAddr(image.buffer.?);
            const width = toUsizeChecked(image.width);
            const height = toUsizeChecked(image.height);

            copyPixels(start_addr_cpu, start_addr_gpu, stride_cpu, stride_gpu, width, height);

            SDL.SDL_UnlockTexture(
                (try self.textures.map.lookup(asset.id, false)).ptr,
            );
        }
    }

    pub fn render(self: *Renderer, entities: *Entities) !void {
        fillWithColor(self.renderer); // TODO: remove when I have background

        const N = Entities.num_dynamic_entities;
        for (
            @as([N]u16, entities.X_dynamic),
            @as([N]u16, entities.Y_dynamic),
            entities.modes_dynamic,
        ) |x, y, mode| {
            const id: ID = try EntityModeToAssetID(mode);
            if (id == .NONE) continue;

            const tex = try self.textures.map.lookup(id, false);
            _ = SDL.SDL_RenderCopy(self.renderer, tex.ptr, null, &SDL.SDL_Rect{ .x = x - @divExact(tex.width, 2), .y = y - @divExact(tex.height, 2), .w = tex.width, .h = tex.height });
        }

        SDL.SDL_RenderPresent(self.renderer);
    }
};

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

fn fillWithColor(renderer: *SDL.SDL_Renderer) void {
    if (SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF) < 0) {
        utils.sdlPanic();
    }
    if (SDL.SDL_RenderClear(renderer) < 0) { // Note: read "Clear" as "Fill"
        utils.sdlPanic();
    }
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
