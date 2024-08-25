const std = @import("std");
const SDL = @import("sdl2"); // Add this package by using sdk.getNativeModule
const png = @cImport(@cInclude("png.h"));
const c = @cImport({
    @cInclude("stdlib.h");
    // @cInclude("stdio.h");
    @cInclude("string.h");
});

const assert = std.debug.assert;

fn print(arg: anytype) void {
    std.debug.print("{any}", .{arg});
}
fn strprint(str: []const u8) void {
    std.debug.print("{s}", .{str});
}

// Needed because png.PNG_IMAGE_SIZE macro was not getting translated in a compatible way.
// Made by running translate-c on the expanded macro in separate file.
fn image_size(arg_image: png.png_image) c_ulong {
    var image = arg_image;
    _ = &image; // TODO: delete these when I'm certain they aren't needed
    var size: c_ulong = @as(c_ulong, @bitCast(@as(c_ulong, ((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 4)) >> @intCast(2)) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.height))) *% ((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else (@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.width))))));
    _ = &size; // TODO: delete these when I'm certain they aren't needed

    return size;
}

fn image_row_stride(arg_image: png.png_image) c_int {
    var image = arg_image;
    _ = &image; // TODO: delete these when I'm certain they aren't needed
    var stride: c_int = @as(c_int, @bitCast((if ((@as(c_uint, @bitCast(image.format)) & @as(c_uint, 8)) != 0) @as(c_uint, @bitCast(@as(c_int, 1))) else (@as(c_uint, @bitCast(image.format)) & (@as(c_uint, 2) | @as(c_uint, 1))) +% @as(c_uint, @bitCast(@as(c_int, 1)))) *% @as(c_uint, @bitCast(image.width))));
    _ = &stride; // TODO: delete these when I'm certain they aren't needed

    return stride;
}

const ReadError = error{ OutOfMemory, FailedImageRead };

const Image = struct {
    buffer: ?*anyopaque = undefined,
    width: c_int = undefined,
    height: c_int = undefined,
    stride: c_int = undefined,
    // TODO: const depth: c_ulong = undefined
};

// Based on example.c from libpng
// ALLOCATES!
fn read_png(path: [*:0]const u8, format: c_uint) ReadError!Image {
    var img: png.png_image = undefined;
    _ = c.memset(&img, 0, @sizeOf(png.png_image));
    img.version = png.PNG_IMAGE_VERSION;

    if (png.png_image_begin_read_from_file(&img, path) != 0) {
        img.format = format;

        const buf = c.malloc(image_size(img));
        // defer if (buf) |b| c.free(b); // this was dumb of me, keeping for future reference of what not to do

        if (buf == null) {
            png.png_image_free(&img);
            return ReadError.OutOfMemory;
        }
        if (png.png_image_finish_read(&img, null, buf, 0, null) != 0) {
            print(image_size(img));
            const stride = image_row_stride(img);
            return Image{ .buffer = buf.?, .width = @intCast(img.width), .height = @intCast(img.height), .stride = stride };
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
    const image: Image = try read_png("assets/first_guy_big.png", png.PNG_FORMAT_BGRA);

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

    strprint("\n");
    strprint("\n");
    print(image.stride);
    strprint("\n");
    strprint("\n");

    // TODO: figure out if the PNG reading is giving me a currupt image, or if the formatting is wrong (both probably).

    const surface: *SDL.SDL_Surface = SDL.SDL_CreateRGBSurfaceFrom(image.buffer, image.width, image.height, 32, image.stride, 0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF).?;
    // const surface: *SDL.SDL_Surface = SDL.SDL_CreateRGBSurfaceFrom(image.buffer, image.width, image.height, 1, image.stride, 0, 0, 0, 0).?;
    const texture: *SDL.SDL_Texture = SDL.SDL_CreateTextureFromSurface(renderer, surface).?;

    strprint("\nHERE\n");

    const src_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 0, .y = 0, .w = 100, .h = 100 });
    const dst_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 50, .y = 50, .w = 100, .h = 100 });

    // print(SDL.SDL_LockTexture(texture, texture_rect, image.buffer[0], image.stride));
    // SDL.SDL_UnlockTexture(texture);
    strprint("\nHERE2\n");

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

        // _ = SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF);
        _ = SDL.SDL_RenderClear(renderer); // Note: read "Clear" as "Fill"
        _ = SDL.SDL_RenderCopy(renderer, texture, src_rect, dst_rect);
        SDL.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
