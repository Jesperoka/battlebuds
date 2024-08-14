const std = @import("std");
const c_xcb_example = @cImport(@cInclude("xcb_example5.c"));

pub fn main() !void {
    std.debug.print("\nProgram start!\n", .{});
    _ = c_xcb_example.run();
    // std.debug.print("\n{d}\n", .{errno});
    std.debug.print("\nProgram end!\n", .{});
}
