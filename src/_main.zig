const std = @import("std");
const c_libdrm_demo = @cImport(@cInclude("libdrm_example.c"));

pub fn main() !void {
    std.debug.print("\nProgram start!\n", .{});
    _ = c_libdrm_demo.display_info();
    // std.debug.print("\n{d}\n", .{errno});
    std.debug.print("\nProgram end!\n", .{});
}
