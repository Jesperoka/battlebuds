const std = @import("std");
const xcb = @cImport({
    @cInclude("xcb/xcb.h");
    // @cInclude("xcb/xproto.h");
});

pub inline fn tiny_square(comptime x: i16, comptime y: i16) xcb.xcb_rectangle_t {
    return xcb.xcb_rectangle_t{ .x = x, .y = y, .width = 10, .height = 10 };
}
pub fn small_square(x: i16, y: i16) struct { i16, i16, u16, u16 } {
    return .{ x, y, 50, 50 };
}
pub fn medium_square(x: i16, y: i16) struct { i16, i16, u16, u16 } {
    return .{ x, y, 100, 100 };
}
pub fn large_square(x: i16, y: i16) struct { i16, i16, u16, u16 } {
    return .{ x, y, 300, 300 };
}
pub fn huge_square(x: i16, y: i16) struct { i16, i16, u16, u16 } {
    return .{ x, y, 600, 600 };
}

pub fn temp() void {
    std.debug.print("{s}", .{"hello there"});
}

// just testing some stuff
pub var first_guy: [44][*c]u8 = [44][*c]u8{
    @constCast("20 20 23 1 "),
    @constCast("  c None"),
    @constCast(". c black"),
    @constCast("X c #020804"),
    @constCast("o c #0C0806"),
    @constCast("O c #092C13"),
    @constCast("+ c #465C78"),
    @constCast("@ c gray50"),
    @constCast("# c #880015"),
    @constCast("$ c #82563D"),
    @constCast("% c #FF7F27"),
    @constCast("& c #B87957"),
    @constCast("* c #B97A56"),
    @constCast("= c #B97A57"),
    @constCast("- c #23B14B"),
    @constCast("; c #22B14C"),
    @constCast(": c #B5E61D"),
    @constCast("> c #9C8E76"),
    @constCast(", c #577294"),
    @constCast("< c #7092BE"),
    @constCast("1 c #00A2E8"),
    @constCast("2 c #EFE4B0"),
    @constCast("3 c #C3C3C3"),
    @constCast("4 c white"),
    @constCast("                    "),
    @constCast("                    "),
    @constCast("      %%%%%         "),
    @constCast("     %.X.O@%%       "),
    @constCast("    %.;;-::@@%      "),
    @constCast("    %.;;;...o@%     "),
    @constCast("     %...&&&&&.%    "),
    @constCast("     %>>.......%    "),
    @constCast("     %>>214214%     "),
    @constCast("      %>2<12<1%     "),
    @constCast("      %>22222%      "),
    @constCast("      %>>2222%      "),
    @constCast("     %%>>>2%%    %  "),
    @constCast("    %.<......%%%%.% "),
    @constCast("   %<..333333....#.%"),
    @constCast("   %<.,.@@@@.<%%%%% "),
    @constCast("   %,,++....<<<%    "),
    @constCast("    %+++.++,,<%     "),
    @constCast("    %+..++++...%    "),
    @constCast("    %.$$.%%.$$$.%   "),
};
