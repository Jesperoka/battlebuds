const std = @import("std");
const SDL = @import("sdl2");
const png = @cImport(@cInclude("png.h"));
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
    // @cInclude("stdio.h");
});

const assert = std.debug.assert;

fn print(arg: anytype) void {
    std.debug.print("{any}", .{arg});
}
fn strprint(str: []const u8) void {
    std.debug.print("{s}", .{str});
}

// Translated expanded C macros from libpng
//-----------------------------------------
fn image_size(image: png.png_image) c_ulong {
    return @as(c_ulong, @bitCast(@as(c_ulong, ((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 4)) >> @intCast(2)) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.height))) *% ((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else (@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.width))))));
}
fn image_row_stride(image: png.png_image) c_int {
    return @as(c_int, @bitCast((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else (@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.width))));
}
fn image_pixel_size(image: png.png_image) c_int {
    return @as(c_int, @bitCast(if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else ((@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% (((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 4)) >> @intCast(2)) +% @as(c_uint, @bitCast(@as(c_int, 1))))));
}
//-----------------------------------------

const ReadError = error{ OutOfMemory, FailedImageRead };

const Image = struct {
    buffer: ?*anyopaque = undefined,
    width: c_int = undefined,
    height: c_int = undefined,
    stride: c_int = undefined,
    bit_depth: c_int = undefined,
};

// Based on example.c from libpng. Note: calls malloc
fn read_png(path: [*:0]const u8, format: c_uint) ReadError!Image {
    var img: png.png_image = undefined;
    _ = c.memset(&img, 0, @sizeOf(png.png_image));
    img.version = png.PNG_IMAGE_VERSION;

    if (png.png_image_begin_read_from_file(&img, path) != 0) {
        img.format = format;
        const buf = c.malloc(image_size(img));

        if (buf == null) {
            png.png_image_free(&img);
            return ReadError.OutOfMemory;
        }
        if (png.png_image_finish_read(&img, null, buf, 0, null) != 0) {
            const pixel_size = image_pixel_size(img);
            const stride = image_row_stride(img);
            return Image{ .buffer = buf.?, .width = @intCast(img.width), .height = @intCast(img.height), .stride = stride, .bit_depth = 8 * pixel_size };
        } else {
            c.free(buf); // Buffer was allocated, but image read failed.
        }
    }
    std.debug.print("Error message from libpng: {s}", .{img.message});
    return ReadError.FailedImageRead;
}

fn parse_keyboard_event(keycode: c_int) bool {
    if (keycode == SDL.SDLK_q) return true;

    return false;
}

const WindowSettings = struct {
    const title: [*]const u8 = "Battlebuds";
    const width: u16 = 1920;
    const height: u16 = 1080;
    const x0 = SDL.SDL_WINDOWPOS_CENTERED;
    const y0 = SDL.SDL_WINDOWPOS_CENTERED;
    const sdl_flags = SDL.SDL_WINDOW_SHOWN; // | SDL.SDL_WINDOW_BORDERLESS;
};

const CharacterPositions = struct {
    const uint = u8;
    const float = f16;

    const num_characters: uint = 1;

    var X: @Vector(num_characters, float) = @splat(0);
    var Y: @Vector(num_characters, float) = @splat(0);

    fn get(idx: uint) @Vector(2, float) {
        return @Vector(2, float){ X[idx], Y[idx] };
    }
    // inline fn getX(idx: uint) float {
    //     return X[idx];
    // }
    // inline fn getY(idx: uint) float {
    //     return Y[idx];
    // }
};

pub fn main() !void {
    const image: Image = try read_png("assets/first_guy_big.png", png.PNG_FORMAT_RGBA);

    if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer SDL.SDL_Quit();

    const window = SDL.SDL_CreateWindow(
        WindowSettings.title,
        WindowSettings.x0,
        WindowSettings.y0,
        WindowSettings.width,
        WindowSettings.height,
        WindowSettings.sdl_flags,
    ) orelse sdlPanic();
    defer _ = SDL.SDL_DestroyWindow(window);

    const renderer = SDL.SDL_CreateRenderer(window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer _ = SDL.SDL_DestroyRenderer(renderer);

    var r_mask: u32 = undefined; //0x000000FF;
    var g_mask: u32 = undefined; //0x0000FF00;
    var b_mask: u32 = undefined; //0x00FF0000;
    var a_mask: u32 = undefined; //0xFF000000;

    const format = SDL.SDL_PIXELFORMAT_BGRA8888;
    _ = SDL.SDL_PixelFormatEnumToMasks(format, @constCast(&image.bit_depth), @constCast(&r_mask), @constCast(&g_mask), @constCast(&b_mask), @constCast(&a_mask));

    const surface: *SDL.SDL_Surface = SDL.SDL_CreateRGBSurfaceFrom(image.buffer, image.width, image.height, image.bit_depth, image.stride, r_mask, g_mask, b_mask, a_mask).?;
    _ = surface;
    // const texture: *SDL.SDL_Texture = SDL.SDL_CreateTextureFromSurface(renderer, surface).?; // Gives static texture access.

    const texture: *SDL.SDL_Texture = SDL.SDL_CreateTexture(renderer, format, SDL.SDL_TEXTUREACCESS_STREAMING, image.width, image.height).?;

    const src_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 0, .y = 0, .w = image.width, .h = image.height });
    const dst_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 50, .y = 50, .w = image.width, .h = image.height });

    var pixels: ?*c_int = undefined; // This is some dumb C shit, holy hell.
    const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));

    var stride: c_int = undefined;
    const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

    // print(SDL.SDL_UpdateTexture(texture, src_rect, surface.pixels, surface.pitch));

    print(SDL.SDL_LockTexture(texture, src_rect, pixels_ptr, stride_ptr));

    // Do stuff with pixels

    const gpu_pixel: [*]?*anyopaque = pixels_ptr;
    const start_addr = @intFromPtr(@as(*u8, @ptrCast(gpu_pixel[0].?)));

    { // function // TODO: after it works, try replacing the column loop with slicing
        // const cpu_pixel: [*]u8 = @constCast(&image.buffer[0]);

        for (0..@intCast(image.height)) |row| {
            // 32 bit rows, so we point to start of row.
            var ptr = @as([*]u32, @ptrFromInt(start_addr + row * @as(usize, @intCast(stride))));

            for (0..@intCast(image.width)) |_| {

                // gpu_pixel = 0xFF000000 |
                ptr += 1;
                ptr[0] = 0x00_00_FF_00;
                // gpu_pixel = @as([*]u8, @ptrCast(cpu_pixel))[idx];
            }
        }
    }

    SDL.SDL_UnlockTexture(texture);

    main_loop: while (true) {
        var event: SDL.SDL_Event = undefined;

        while (SDL.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                SDL.SDL_QUIT => break :main_loop,
                SDL.SDL_KEYDOWN => {
                    const keyboard_event: *SDL.SDL_KeyboardEvent = @ptrCast(&event);
                    if (parse_keyboard_event(keyboard_event.keysym.sym)) break :main_loop;
                },

                else => {},
            }
        }

        _ = SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF);
        _ = SDL.SDL_RenderClear(renderer); // Note: read "Clear" as "Fill"
        _ = SDL.SDL_RenderCopy(renderer, texture, src_rect, dst_rect);
        SDL.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
