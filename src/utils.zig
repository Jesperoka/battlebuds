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

pub fn divAsFloat(comptime float_type: type, int_1: anytype, int_2: anytype) float_type {
    return @as(float_type, @floatFromInt(int_1)) / @as(float_type, @floatFromInt(int_2));
}

pub fn mulFloatInt(comptime float_type: type, float_value: anytype, int_value: anytype) float_type {
    return float_value * @as(float_type, @floatFromInt(int_value));
}

pub fn not(comptime float_type: type, value: anytype) float_type {
    if (value > 0.0) {
        return 1.0;
    } else {
        return 0.0;
    }
}

pub fn range(comptime T: type, comptime n: T, comptime N: T) [N - n]T {
    comptime assert(n < N, "Range must go from low to high.");
    var ints: [N - n]T = undefined;
    for (n..N, 0..N - n) |int, i| {
        ints[i] = @intCast(int);
    }

    return ints;
}

pub const StaticMapError = error{
    MapIsFull,
    MissingItem,
};

const uint = u16;

// Making my own static-size lookup table for fun and to learn a bit more comptime.
// Insert the most frequently accessed items first (at back or front).
// In the case of duplicates, the first match is returned. Up to user not to be stupid.
pub fn StaticMap(comptime len: uint, comptime T_names: type, comptime T_things: type) struct {
    comptime len: uint = len,
    names: [len]T_names = .{undefined} ** len,
    things: [len]T_things = undefined,
    cur_front_idx: uint = 0,
    cur_back_idx: uint = len - 1,

    fn space(self: *@This()) uint {
        if (self.cur_back_idx < self.cur_front_idx) {
            return 0;
        }
        return self.cur_back_idx - self.cur_front_idx + 1;
    }

    inline fn eq(a: T_names, b: T_names) bool {
        const typeInfo = @typeInfo(T_names);
        const Slice = std.builtin.Type.Pointer.Size.Slice;

        switch (typeInfo) {
            .Pointer => |ptr| if (ptr.size == Slice) return std.mem.eql(ptr.child, a, b),
            else => return a == b,
        }
    }

    pub fn insert(self: *@This(), name: T_names, thing: T_things, comptime back: bool) StaticMapError!void {
        if (self.cur_back_idx < 0 or self.cur_back_idx < self.cur_front_idx or self.cur_front_idx > len - 1) {
            return StaticMapError.MapIsFull;
        }

        if (back) {
            self.things[self.cur_back_idx] = thing;
            self.names[self.cur_back_idx] = name;
            self.cur_back_idx -= 1;
        } else {
            self.things[self.cur_front_idx] = thing;
            self.names[self.cur_front_idx] = name;
            self.cur_front_idx += 1;
        }
    }

    inline fn lookup_front(self: *@This(), name: T_names) StaticMapError!T_things {
        return for (0..self.cur_front_idx) |idx| {
            if (eq(name, self.names[idx])) return self.things[idx];
            //
        } else for (self.cur_back_idx..len) |idx| {
            const back_idx = (len - 1) - (idx - self.cur_back_idx); // len, len-1, len-2, ...
            if (eq(name, self.names[back_idx])) return self.things[back_idx];
            //
        } else StaticMapError.MissingItem;
    }

    inline fn lookup_back(self: *@This(), name: T_names) StaticMapError!T_things {
        return for (self.cur_back_idx..len) |idx| {
            const back_idx = (len - 1) - (idx - self.cur_back_idx); // len, len-1, len-2, ...
            if (eq(name, self.names[back_idx])) return self.things[back_idx];
            //
        } else for (0..self.cur_front_idx) |idx| {
            if (eq(name, self.names[idx])) return self.things[idx];
            //
        } else StaticMapError.MissingItem;
    }

    // Allows for looking up from back or front by user's choice.
    pub fn lookup(self: *@This(), name: T_names, comptime back: bool) StaticMapError!T_things {
        return if (back) self.lookup_back(name) else self.lookup_front(name);
    }
} {
    return .{};
}

test "StaticMap functionality" {
    var my_map = StaticMap(8, []const u8, []const u8);
    try my_map.insert("One", "Thing 1", false);
    try my_map.insert("Two", "Thing 2", false);

    try my_map.insert("Three", "Thing 3", true);
    try my_map.insert("Four", "Thing 4", true);
    try my_map.insert("Five", "Thing 5", true);

    const front: [2][]const u8 = .{ "Thing 1", "Thing 2" };
    const back: [3][]const u8 = .{ "Thing 5", "Thing 4", "Thing 3" };

    try std.testing.expect(std.mem.eql(u8, my_map.things[0], front[0]));
    try std.testing.expect(std.mem.eql(u8, my_map.things[1], front[1]));
    try std.testing.expect(std.mem.eql(u8, my_map.things[5], back[0]));
    try std.testing.expect(std.mem.eql(u8, my_map.things[6], back[1]));
    try std.testing.expect(std.mem.eql(u8, my_map.things[7], back[2]));

    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("Three", false), "Thing 3"));
    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("Three", false), "Thing 3"));

    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("One", false), "Thing 1"));
    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("Two", false), "Thing 2"));

    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("Three", true), "Thing 3"));
    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("One", true), "Thing 1"));
    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("Two", true), "Thing 2"));
    try std.testing.expect(std.mem.eql(u8, try my_map.lookup("Two", true), "Thing 2"));

    try std.testing.expect(StaticMapError.MissingItem == my_map.lookup("Doesn't Exist", false));
    try std.testing.expect(StaticMapError.MissingItem == my_map.lookup("Doesn't Exist", true));

    try std.testing.expect(StaticMapError.MapIsFull != my_map.insert("Duplicate", "Thing 6", false));
    try std.testing.expect(StaticMapError.MapIsFull != my_map.insert("Duplicate", "Thing 7", true));
    try std.testing.expect(StaticMapError.MapIsFull != my_map.insert("Duplicate", "Thing 8", false));

    try std.testing.expect(StaticMapError.MapIsFull == my_map.insert("Duplicate", "Thing 9", false));
    try std.testing.expect(StaticMapError.MapIsFull == my_map.insert("Duplicate", "Thing 9", true));

    const TempStruct = struct {
        x: f32 = 0,
        y: f32 = 0,

        fn eq(self: *const @This(), other: @This()) bool {
            return self.x == other.x and self.y == other.y;
        }
    };

    const MyEnum = enum {
        EMPTY,
        ONE,
        TWO,
        THREE,
    };

    var my_map_2 = StaticMap(8, MyEnum, TempStruct);

    try my_map_2.insert(MyEnum.EMPTY, TempStruct{}, false);
    try my_map_2.insert(MyEnum.ONE, TempStruct{ .x = 1, .y = 0.43 }, false);
    try my_map_2.insert(MyEnum.TWO, TempStruct{ .x = 1, .y = 0.43 }, true);

    try std.testing.expect((TempStruct{ .x = 0, .y = 0 }).eq(try my_map_2.lookup(MyEnum.EMPTY, false)));
    try std.testing.expect((try my_map_2.lookup(MyEnum.EMPTY, true)).eq(TempStruct{}));
    try std.testing.expect((try my_map_2.lookup(MyEnum.ONE, true)).eq(TempStruct{ .x = 1, .y = 0.43 }));
    try std.testing.expect((try my_map_2.lookup(MyEnum.ONE, false)).eq(TempStruct{ .x = 1, .y = 0.43 }));
    try std.testing.expect(!((try my_map_2.lookup(MyEnum.ONE, false)).eq(TempStruct{ .x = 9.999, .y = 999 })));
    try std.testing.expect(!((try my_map_2.lookup(MyEnum.ONE, true)).eq(TempStruct{ .x = 9.999, .y = 999 })));
}
