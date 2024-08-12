// Keeping everything in main until it becomes too big.
const std = @import("std");
const c_libdrm = @cImport(@cInclude("xf86drmMode.h"));

pub fn main() void {
    c_libdrm
        .std.debug.print("{s}", .{"Hello World"});

    std.debug.print("{s}", .{"\n"});
}
