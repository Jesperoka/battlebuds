const std = @import("std");
const SDL = @import("sdl2"); // Add this package by using sdk.getNativeModule

fn print(arg: anytype) void {
    std.debug.print("{any}", .{arg});
}
fn strprint(str: []const u8) void {
    std.debug.print("{s}", .{str});
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

// const CharacterPositions = struct {
//    var

//     fn get(id: u8) {
//         return
//     }
// };

pub fn main() !void {
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
        _ = SDL.SDL_RenderClear(renderer);

        SDL.SDL_RenderPresent(renderer);
    }
}

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
