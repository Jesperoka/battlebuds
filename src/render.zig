/// blech
const std = @import("std");
const SDL = @import("sdl2");
const utils = @import("utils.zig");
const png = @cImport(@cInclude("png.h"));
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
    // @cInclude("stdio.h");
});

const WindowSettings = struct {
    const title: [*]const u8 = "Battlebuds";
    const width: u16 = 1920;
    const height: u16 = 1080;
    const x0 = SDL.SDL_WINDOWPOS_CENTERED;
    const y0 = SDL.SDL_WINDOWPOS_CENTERED;
    const sdl_flags = SDL.SDL_WINDOW_SHOWN; // | SDL.SDL_WINDOW_BORDERLESS;
};

const game_assets = [_][]const u8{
    "assets/first_guy_big.png",
    // "assets/first_guy.png",
};

// TODO: don't need default
const Image = struct {
    buffer: ?*anyopaque = undefined,
    width: c_int = undefined,
    height: c_int = undefined,
    stride: c_int = undefined,
    bit_depth: c_int = undefined,

    fn free(self: Image) void {
        c.free(self.buffer);
    }
};

const ReadError = error{ OutOfMemory, FailedImageRead };

pub const Renderer = struct {
    var image: Image = .{}; // TODO: delete

    textures: [game_assets.len]*SDL.SDL_Texture = undefined,
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

        self.num_textures = game_assets.len;
        self.load_textures(&game_assets) catch |err| std.debug.panic("Error: {any}", .{err});

        for (0..self.textures.len) |i| {
            if (SDL.SDL_SetTextureBlendMode(self.textures[i], SDL.SDL_BLENDMODE_BLEND) < 0) {
                utils.sdlPanic();
            }
        }
        self.render(); // this call is necessary

        return self;
    }

    fn deinit(self: *Renderer) void {
        for (.textures) |texture| SDL.SDL_DestroyTexture(texture);
        _ = SDL.SDL_DestroyRenderer(self.renderer);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    fn load_textures(self: *Renderer, comptime assets: []const []const u8) ReadError!void {
        const format = SDL.SDL_PIXELFORMAT_ABGR8888;
        const access_mode = SDL.SDL_TEXTUREACCESS_STREAMING;

        for (assets, 0..self.num_textures) |path, i| {
            const img = try readPng(@as([*:0]const u8, @ptrCast(path)), png.PNG_FORMAT_RGBA);
            defer image.free(); // TODO: free
            image = img;

            self.textures[i] = SDL.SDL_CreateTexture(self.renderer, format, access_mode, image.width, image.height) orelse utils.sdlPanic();

            var pixels: ?*c_int = undefined;
            var stride: c_int = undefined;
            const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));
            const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

            utils.assert(SDL.SDL_LockTexture(self.textures[i], null, pixels_ptr, stride_ptr) == 0, "SDL_LockTexture() failed.");

            const stride_gpu = toUsizeChecked(stride);
            const stride_cpu = toUsizeChecked(image.stride);
            const start_addr_gpu = opaqueToAddr(pixels_ptr[0].?);
            const start_addr_cpu = opaqueToAddr(image.buffer.?);
            const width = toUsizeChecked(image.width);
            const height = toUsizeChecked(image.height);

            copyPixels(start_addr_cpu, start_addr_gpu, stride_cpu, stride_gpu, width, height);

            SDL.SDL_UnlockTexture(self.textures[i]);
        }
    }

    // TODO: I need to think about whether I want the SimulationState to contain information
    // about rendering in terms of who is offscreen or what, or maybe I just want a separate
    // rendering information struct.

    pub fn render(self: *Renderer) void {
        const src_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 0, .y = 0, .w = image.width, .h = image.height });
        const dst_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 1920 / 2 - 49, .y = 1080 / 2 - 49, .w = image.width, .h = image.height });
        // const dst_rect_2: *SDL.SDL_Rect = @constCast(&.{ .x = 500 / 2 - 49, .y = 300 / 2 - 49, .w = image.width, .h = image.height });

        fillWithColor(self.renderer);
        _ = SDL.SDL_RenderCopy(self.renderer, self.textures[0], src_rect, dst_rect);
        // _ = SDL.SDL_RenderCopy(self.renderer, self.textures[1], src_rect, dst_rect_2);
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
