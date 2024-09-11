const max_num_players = @import("game.zig").max_num_players;
const float = @import("physics.zig").float;
const utils = @import("utils.zig");
const ID = @import("render.zig").ID;

// Convex Polygons.
// Must have vertices ordered in counterclockwise direction.
pub const Triangle = struct {
    X: @Vector(3, float),
    Y: @Vector(3, float),

    fn area(self: Triangle) float {
        const X = self.X;
        const Y = self.Y;

        return 0.5 * (X[0] * (Y[1] - Y[2]) + X[1] * (Y[2] - Y[0]) + X[2] * (Y[0] - Y[1]));
    }

    pub fn edges(self: Triangle) struct { [3]float, [3]float } {
        const X_end = @shuffle(float, self.X, undefined, [_]comptime_int{ 1, 2, 0 });
        const Y_end = @shuffle(float, self.Y, undefined, [_]comptime_int{ 1, 2, 0 });

        return .{ @as([3]float, X_end - self.X), @as([3]float, Y_end - self.Y) };
    }
    pub fn corners(self: Triangle) struct { [3]float, [3]float } {
        return .{ @as([3]float, self.X), @as([3]float, self.Y) };
    }
};

test "Triangle edges()" {
    const expectApproxEqRel = @import("std").testing.expectApproxEqRel;
    const triangle0 = Triangle{
        .X = .{ 0.1, 0.9, 0 },
        .Y = .{ 0, -0.2, 2.5 },
    };
    const dx, const dy = triangle0.edges();
    const expected_dx = [3]float{ 0.9 - 0.1, 0 - 0.9, 0.1 - 0 };
    const expected_dy = [3]float{ -0.2 - 0, 2.5 - (-0.2), 0 - 2.5 };

    for (0..dx.len) |i| {
        try expectApproxEqRel(dx[i], expected_dx[i], 1e-7);
        try expectApproxEqRel(dy[i], expected_dy[i], 1e-7);
    }
}

pub const Quad = struct {
    X: @Vector(4, float),
    Y: @Vector(4, float),

    fn area(self: Quad) float {
        const X = self.X;
        const Y = self.Y;

        const ABC = Triangle{ .X = .{ X[0], X[1], X[2] }, .Y = .{ Y[0], Y[1], Y[2] } };
        const ACD = Triangle{ .X = .{ X[0], X[2], X[3] }, .Y = .{ Y[0], Y[2], Y[3] } };

        return ABC.area() + ACD.area();
    }

    pub fn edges(self: Quad) struct { [4]float, [4]float } {
        const X_end = @shuffle(float, self.X, undefined, [_]comptime_int{ 1, 2, 3, 0 });
        const Y_end = @shuffle(float, self.Y, undefined, [_]comptime_int{ 1, 2, 3, 0 });

        return .{ @as([4]float, X_end - self.X), @as([4]float, Y_end - self.Y) };
    }
    pub fn corners(self: Quad) struct { [4]float, [4]float } {
        return .{ @as([4]float, self.X), @as([4]float, self.Y) };
    }
};

test "Quad edges()" {
    const expectApproxEqRel = @import("std").testing.expectApproxEqRel;
    const quad0 = Quad{
        .X = .{ 0.1, 0.9, 0, -0.2 },
        .Y = .{ 0, -0.2, 2.5, 0.1 },
    };
    const dx, const dy = quad0.edges();

    const expected_dx = [4]float{ 0.9 - 0.1, 0 - 0.9, -0.2 - 0, 0.1 - (-0.2) };
    const expected_dy = [4]float{ -0.2 - 0, 2.5 - (-0.2), 0.1 - 2.5, 0 - 0.1 };

    for (0..dx.len) |i| {
        try expectApproxEqRel(dx[i], expected_dx[i], 1e-7);
        try expectApproxEqRel(dy[i], expected_dy[i], 1e-7);
    }
}

pub const Shape = union(enum) {
    triangle: Triangle,
    quad: Quad,
};

pub const stage_width_meters: float = 20;
pub const stage_height_meters: float = stage_width_meters * (9.0 / 16.0);

pub const Position = struct {
    x: float,
    y: float,
};

pub fn Stage(
    comptime id: u8,
    comptime name: []const u8,
    comptime background_id: ID,
    comptime starting_positions: [max_num_players]Position,
    comptime num_shapes: comptime_int,
    comptime geometry: [num_shapes]Shape,
) type {
    return struct {
        id: u8 = id,
        name: []const u8 = name,
        background_id: ID = background_id,
        starting_positions: [max_num_players]Position = starting_positions,
        geometry: [num_shapes]Shape = geometry,
    };
}

pub const StageUnion = union(enum) {
    s0: @TypeOf(s0),
};

// TODO: only call these once before match
pub fn stageGeometry(i: usize) []const Shape {
    switch (i) {
        0 => return &s0.geometry,
        else => unreachable,
    }
}
pub fn stageBackground(i: usize) ID {
    switch (i) {
        0 => return s0.background_id,
        else => unreachable,
    }
}

pub const s0 = Stage(
    0,
    "Flat Earth Theory",
    ID.SPACE_BACKGROUND,
    .{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = -2.5 },
        .{ .x = -5, .y = 0 },
        .{ .x = 5, .y = 0 },
    },
    2,
    .{
        Shape{ .quad = .{
            .X = .{ -(stage_width_meters / 2), (stage_width_meters / 2), (stage_width_meters / 2), -(stage_width_meters / 2) },
            .Y = .{ -4.8, -4.8, -4.0, -4.0 },
        } },
        Shape{ .quad = .{
            .X = .{ -(stage_width_meters / 2) + 0.5, -(stage_width_meters / 2) + 1.5, -(stage_width_meters / 2) + 1.5, -(stage_width_meters / 2) + 0.5 },
            .Y = .{ -(stage_height_meters / 2), -(stage_height_meters / 2), (stage_height_meters / 2), (stage_height_meters / 2) },
        } },
    },
){};
