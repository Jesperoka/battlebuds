const std = @import("std");
const SDL = @import("sdl2");
const png = @cImport(@cInclude("png.h"));
const hid = @cImport(@cInclude("hidapi.h"));
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

const ReadError = error{ OutOfMemory, FailedImageRead };

const Image = struct {
    buffer: ?*anyopaque = undefined,
    width: c_int = undefined,
    height: c_int = undefined,
    stride: c_int = undefined,
    bit_depth: c_int = undefined,

    fn free() void {
        c.free(@This().buffer);
    }
};

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

fn parseKeyboardEvent(keycode: c_int) bool {
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

pub fn main() !void {
    const image: Image = try readPng("assets/first_guy_big.png", png.PNG_FORMAT_RGBA);

    // if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO | SDL.SDL_INIT_JOYSTICK) < 0)

    // assert(SDL.SDL_hid_init() == 0);
    // const vendor_id: c_ushort = @as(c_ushort, @intCast(0x081f));
    // const product_id: c_ushort = @as(c_ushort, @intCast(0xe401));
    // const hid_device = SDL.SDL_hid_open(vendor_id, product_id).?;
    for (@typeInfo(hid).Struct.decls) |f| {
        strprint("\n");
        strprint(f.name);
        // std.debug.warn(f.name ++ " {}\n", @as(f.field_type, @field(SDL, f.name)));
    }
    // std.builtin.Type
    // print(hid_device);

    if (SDL.SDL_Init(SDL.SDL_INIT_EVERYTHING) < 0)
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

    const format = SDL.SDL_PIXELFORMAT_ABGR8888;
    const access_mode = SDL.SDL_TEXTUREACCESS_STREAMING;
    _ = SDL.SDL_PixelFormatEnumToMasks(format, @constCast(&image.bit_depth), @constCast(&r_mask), @constCast(&g_mask), @constCast(&b_mask), @constCast(&a_mask));

    // const surface: *SDL.SDL_Surface = SDL.SDL_CreateRGBSurfaceFrom(image.buffer, image.width, image.height, image.bit_depth, image.stride, r_mask, g_mask, b_mask, a_mask).?;
    // const texture: *SDL.SDL_Texture = SDL.SDL_CreateTextureFromSurface(renderer, surface).?; // Gives static texture access.

    const texture: *SDL.SDL_Texture = SDL.SDL_CreateTexture(renderer, format, access_mode, image.width, image.height).?;

    var pixels: ?*c_int = undefined;
    const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));

    var stride: c_int = undefined;
    const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

    assert(SDL.SDL_LockTexture(texture, null, pixels_ptr, stride_ptr) == 0);

    const stride_gpu = toUsizeChecked(stride);
    const start_addr_gpu = opaqueToAddr(pixels_ptr[0].?);

    const stride_cpu = toUsizeChecked(image.stride);
    const start_addr_cpu = opaqueToAddr(image.buffer.?);

    const width = toUsizeChecked(image.width);
    const height = toUsizeChecked(image.height);

    copyPixels(start_addr_cpu, start_addr_gpu, stride_cpu, stride_gpu, width, height);

    SDL.SDL_UnlockTexture(texture);

    const src_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 0, .y = 0, .w = image.width, .h = image.height });
    const dst_rect: *SDL.SDL_Rect = @constCast(&.{ .x = 1920 / 2 - 50, .y = 1080 / 2 - 50, .w = image.width, .h = image.height });

    // var event_filter: *SDL.SDL_EventFilter = undefined;
    // var userdata: [*]?*anyopaque = undefined;

    // assert(SDL.SDL_GetEventFilter(event_filter, userdata) == SDL.SDL_FALSE);
    strprint("\n");

    // print(event_filter);
    // print(userdata);

    main_loop: while (true) {
        var event: SDL.SDL_Event = undefined;

        while (SDL.SDL_PollEvent(&event) != 0) {
            // print(event.type);
            switch (event.type) {
                SDL.SDL_QUIT => break :main_loop,
                SDL.SDL_KEYDOWN => {
                    const keyboard_event: *SDL.SDL_KeyboardEvent = @ptrCast(&event);
                    if (parseKeyboardEvent(keyboard_event.keysym.sym)) break :main_loop;
                },
                SDL.SDL_CONTROLLERBUTTONDOWN => {
                    strprint("HEYO!");
                    const controller_button_event: *SDL.SDL_ControllerButtonEvent = @ptrCast(&event);
                    print(controller_button_event);
                },

                else => {},
            }
        }
        //

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
