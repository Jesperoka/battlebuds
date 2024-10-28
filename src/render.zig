/// Using SDL2 for window management and pointers to GPU buffers.
const std = @import("std");
const SDL = @import("sdl2");
const png = @cImport(@cInclude("png.h"));
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
});

const constants = @import("constants.zig");
const assets = @import("assets.zig");
const utils = @import("utils.zig");
const stages = @import("stages.zig");
const textureMap = @import("assets.zig").textureMap;

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

pub const Entities = struct {
    const max_entities = 1024;
    const num_dynamic_entities = constants.VEC_LENGTH;

    X_dynamic: VecI32 = @splat(0),
    Y_dynamic: VecI32 = @splat(0),
    modes_dynamic: [num_dynamic_entities]assets.EntityMode = .{.{ .common = assets.CommonMode.NONE }} ** num_dynamic_entities,

    pub inline fn init(
        comptime self: *Entities,
        comptime num_players: u8,
        comptime stage: *const @TypeOf(stages.stage0),
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
        self.X_dynamic = vecToPixelX(X);
        self.Y_dynamic = vecToPixelY(Y);
    }
};

pub const Renderer = struct {
    textures: Textures = undefined,
    renderer: *SDL.SDL_Renderer = undefined,
    window: *SDL.SDL_Window = undefined,
    num_textures: u8 = undefined,

    pub fn init(comptime self: *Renderer) *Renderer {
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

        self.textures.init();

        utils.assert(self.textures.map.cur_back_idx < self.textures.map.cur_front_idx, "Can't loop through texture map if it's not full.");

        for (self.textures.map.things) |textures| {
            for (textures) |texture| {
                if (SDL.SDL_SetTextureBlendMode(texture.ptr, SDL.SDL_BLENDMODE_BLEND) < 0) {
                    utils.sdlPanic();
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        self.textures.deinit();
        _ = SDL.SDL_DestroyRenderer(self.renderer);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    pub fn drawEntitites(
        self: *Renderer,
        counter: usize,
        entities: *Entities,
    ) !void {
        const N = Entities.num_dynamic_entities;

        for (
            @as([N]i32, entities.X_dynamic),
            @as([N]i32, entities.Y_dynamic),
            entities.modes_dynamic,
        ) |x, y, mode| {
            const id: assets.ID = try assets.IDFromEntityMode(mode); // TODO: rework
            if (id == .NONE) continue;

            const textures = try self.textures.map.lookup(id, false);
            const texture = textures[counter % assets.ASSETS_PER_ID[id]];

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

    pub fn draw(
        self: *Renderer,
        counter: usize,
        IDs: []const assets.ID,
    ) !void {
        for (IDs) |id| {
            const textures = try self.textures.map.lookup(id, false);
            const texture = textures[counter % assets.ASSETS_PER_ID[id]];
            _ = SDL.SDL_RenderCopy(self.renderer, texture.ptr, null, null);
        }
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

pub const Textures = struct {
    const FORMAT: c_int = SDL.SDL_PIXELFORMAT_ABGR8888;
    const ACCESS_MODE: c_int = SDL.SDL_TEXTUREACCESS_STREAMING;

    map: assets.TextureMap,

    pub fn init(
        self: *Textures,
        renderer: *SDL.SDL_Renderer,
    ) !Textures {
        for (assets.ID) |id| {
            var textures: [assets.ASSETS_PER_ID]assets.Texture = undefined;
            var count = 0;

            // For simplicity, just check all assets.
            for (assets.game_assets) |asset| {
                if (asset.id != id) continue;

                const texture = try loadTexture(asset.path, renderer, FORMAT, ACCESS_MODE) catch unreachable;
                textures[count] = texture;
                count += 1;

                if (count >= textures.len) break;
            }
            self.map.insert(textures, id, false);
        }

        return self;
    }

    pub fn deinit(self: *Textures) void {
        for (self.map.things) |textures| {
            for (textures) |texture| {
                SDL.SDL_DestroyTexture(texture.ptr);
            }
        }
    }
};

fn loadTexture(
    path: []const u8,
    renderer: *SDL.SDL_Renderer,
    comptime format: c_int,
    comptime access_mode: c_int,
) !assets.Texture {
    const c_str_path = @as([*:0]const u8, @ptrCast(path));
    const image = try readPng(c_str_path, png.PNG_FORMAT_RGBA);
    defer image.free();

    const texture_ptr = SDL.SDL_CreateTexture(
        renderer,
        format,
        access_mode,
        image.width,
        image.height,
    ) orelse utils.sdlPanic();

    var pixels: ?*c_int = undefined;
    var stride: c_int = undefined;
    const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));
    const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

    utils.assert(
        SDL.SDL_LockTexture(texture_ptr, null, pixels_ptr, stride_ptr) == 0,
        "SDL_LockTexture() failed.",
    );

    const stride_gpu = toUsizeChecked(stride);
    const stride_cpu = toUsizeChecked(image.stride);
    const start_addr_gpu = opaqueToAddr(pixels_ptr[0].?);
    const start_addr_cpu = opaqueToAddr(image.buffer.?);
    const width = toUsizeChecked(image.width);
    const height = toUsizeChecked(image.height);

    copyPixels(start_addr_cpu, start_addr_gpu, stride_cpu, stride_gpu, width, height);

    SDL.SDL_UnlockTexture(texture_ptr);

    return .{ texture_ptr, width, height };
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
