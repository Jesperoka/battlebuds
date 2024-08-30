/// Convenience functions
const std = @import("std");
const SDL_GetError = @import("sdl2").SDL_GetError;

pub fn assert(ok: bool, msg: []const u8) void {
    if (ok) return;
    const @"_" = "\nAssertion error: {s}\n";
    std.debug.print(@"_", .{msg});
    unreachable;
}

pub fn print(arg: anytype) void {
    std.debug.print("{any}", .{arg});
}
pub fn strprint(str: anytype) void {
    std.debug.print("{s}", .{str});
}

pub fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
