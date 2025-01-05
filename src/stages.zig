/// All the maps in the game.
const constants = @import("constants.zig");
const utils = @import("utils.zig");

const HorizontalDirection = @import("game.zig").HorizontalDirection;
const fields = @import("std").meta.fields;
const float = @import("types.zig").float;
const ID = @import("assets.zig").ID;

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
    pub fn vertexCentroid(self: Triangle) struct { float, float } {
        return .{ (self.X[0] + self.X[1] + self.X[2]) / 3, (self.Y[0] + self.Y[1] + self.Y[2]) / 3 };
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

    // We don't compute the area centroid, for performance.
    pub fn vertexCentroid(self: Quad) struct { float, float } {
        return .{ (self.X[0] + self.X[1] + self.X[2] + self.X[3]) / 4, (self.Y[0] + self.Y[1] + self.Y[2] + self.Y[3]) / 4 };
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

pub const Position = struct {
    x: float,
    y: float,
};

pub fn Stage(
    comptime id: StageID,
    comptime name: []const u8,
    comptime num_background_assets: comptime_int,
    comptime background_asset_ids: [num_background_assets]ID,
    comptime num_foreground_assets: comptime_int,
    comptime foreground_asset_ids: [num_foreground_assets]ID,
    comptime starting_positions: [constants.MAX_NUM_PLAYERS]Position,
    comptime num_shapes: comptime_int,
    comptime geometry: [num_shapes]Shape,
) type {
    return struct {
        id: StageID = id,
        name: []const u8 = name,
        background_asset_ids: [num_background_assets]ID = background_asset_ids,
        foreground_asset_ids: [num_foreground_assets]ID = foreground_asset_ids,
        starting_positions: [constants.MAX_NUM_PLAYERS]Position = starting_positions,
        geometry: [num_shapes]Shape = geometry,
    };
}

pub const StageAssets = struct {
    geometry: []const Shape,
    background: []const ID,
    foreground: []const ID,
};

pub const StageID = enum(i16) {
    Meteor,
    Test00,

    // pub fn next(self: StageID) StageID {
    //     return @enumFromInt((@intFromEnum(self) + 1) % fields(StageID).len);
    // }

    // pub fn previous(self: StageID) StageID {
    //     return @enumFromInt((@intFromEnum(self) - 1) % fields(StageID).len);
    // }

    pub fn switch_stage(self: StageID, x_dir: HorizontalDirection) StageID {
        const number_of_stages: i16 = @intCast(fields(StageID).len);

        return @enumFromInt(@mod(@intFromEnum(self) + @intFromEnum(x_dir), number_of_stages));
    }
};

pub fn stageAssets(stage_id: StageID) StageAssets {
    switch (stage_id) {
        .Meteor => return StageAssets{
            .geometry = &meteor.geometry,
            .background = &meteor.background_asset_ids,
            .foreground = &meteor.foreground_asset_ids,
        },
        .Test00 => return StageAssets{
            .geometry = &test00.geometry,
            .background = &test00.background_asset_ids,
            .foreground = &test00.foreground_asset_ids,
        },
    }
}

pub fn startingPositions(stage_id: StageID) [constants.MAX_NUM_PLAYERS]Position {
    switch (stage_id) {
        .Meteor => return meteor.starting_positions,
        .Test00 => return test00.starting_positions,
    }
}

const below_screen = 1080 + 200;

// TODO MAYBE: create a stage creator in python
pub const meteor = Stage(
    .Meteor,
    "Meteor",
    2,
    .{ ID.STAGE_METEOR_BACKGROUND, ID.STAGE_METEOR_FLOOR },
    1,
    .{ID.STAGE_METEOR_PLATFORMS},
    .{
        .{ .x = 0, .y = -1.5 }, // TODO: find good starting positions.
        .{ .x = 0, .y = -1.5 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
    },
    11,
    .{
        // Floor left box
        Shape{ .quad = .{
            .X = .{
                fromPixelX(147),
                fromPixelX(147),
                fromPixelX(321),
                fromPixelX(321),
            },
            .Y = .{
                fromPixelY(725),
                fromPixelY(below_screen),
                fromPixelY(below_screen),
                fromPixelY(725),
            },
        } },
        // Floor bottom box
        Shape{ .quad = .{
            .X = .{
                fromPixelX(321),
                fromPixelX(321),
                fromPixelX(1598),
                fromPixelX(1598),
            },
            .Y = .{
                fromPixelY(996),
                fromPixelY(below_screen),
                fromPixelY(below_screen),
                fromPixelY(996),
            },
        } },
        // Floor middle trapezoid
        Shape{ .quad = .{
            .X = .{
                fromPixelX(596),
                fromPixelX(1322),
                fromPixelX(1153),
                fromPixelX(764),
            },
            .Y = .{
                fromPixelY(996),
                fromPixelY(996),
                fromPixelY(881),
                fromPixelY(881),
            },
        } },
        // Floor right box
        Shape{ .quad = .{
            .X = .{
                fromPixelX(1598),
                fromPixelX(1598),
                fromPixelX(1770),
                fromPixelX(1770),
            },
            .Y = .{
                fromPixelY(725),
                fromPixelY(below_screen),
                fromPixelY(below_screen),
                fromPixelY(725),
            },
        } },
        // Top left platform
        Shape{ .quad = .{
            .X = .{
                fromPixelX(502),
                fromPixelX(126),
                fromPixelX(136),
                fromPixelX(502),
            },
            .Y = .{
                fromPixelY(239),
                fromPixelY(216),
                fromPixelY(346),
                fromPixelY(374),
            },
        } },
        // Middle left platform 1
        Shape{ .quad = .{
            .X = .{
                fromPixelX(694),
                fromPixelX(542),
                fromPixelX(649),
                fromPixelX(695),
            },
            .Y = .{
                fromPixelY(457),
                fromPixelY(577),
                fromPixelY(657),
                fromPixelY(624),
            },
        } },
        // Middle left platform 2
        Shape{ .quad = .{
            .X = .{
                fromPixelX(542),
                fromPixelX(536),
                fromPixelX(570),
                fromPixelX(649),
            },
            .Y = .{
                fromPixelY(577),
                fromPixelY(711),
                fromPixelY(711),
                fromPixelY(657),
            },
        } },
        // Middle platform
        Shape{ .quad = .{
            .X = .{
                fromPixelX(880),
                fromPixelX(857),
                fromPixelX(1038),
                fromPixelX(1027),
            },
            .Y = .{
                fromPixelY(214),
                fromPixelY(614),
                fromPixelY(614),
                fromPixelY(214),
            },
        } },
        // Middle Right platform 1
        Shape{ .quad = .{
            .X = .{
                fromPixelX(1370),
                fromPixelX(1213),
                fromPixelX(1215),
                fromPixelX(1288),
            },
            .Y = .{
                fromPixelY(577),
                fromPixelY(458),
                fromPixelY(629),
                fromPixelY(675),
            },
        } },
        // Middle Right platform 2
        Shape{ .quad = .{
            .X = .{
                fromPixelX(1370),
                fromPixelX(1288),
                fromPixelX(1343),
                fromPixelX(1374),
            },
            .Y = .{
                fromPixelY(577),
                fromPixelY(675),
                fromPixelY(712),
                fromPixelY(712),
            },
        } },
        // Top Right platform
        Shape{ .quad = .{
            .X = .{
                fromPixelX(1797),
                fromPixelX(1412),
                fromPixelX(1404),
                fromPixelX(1791),
            },
            .Y = .{
                fromPixelY(219),
                fromPixelY(223),
                fromPixelY(371),
                fromPixelY(356),
            },
        } },
    },
){};

pub const test00 = Stage(
    .Test00,
    "Test00",
    2,
    .{ ID.STAGE_TEST00_BACKGROUND, ID.STAGE_TEST00_PLATFORMS },
    0,
    .{},
    .{
        .{ .x = 0, .y = -1.5 }, // TODO: find good starting positions.
        .{ .x = 0, .y = -1.5 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
    },
    2,
    .{
        // Bottom platform
        Shape{ .quad = .{
            .X = .{
                fromPixelX(1555),
                fromPixelX(429),
                fromPixelX(429),
                fromPixelX(1555),
            },
            .Y = .{
                fromPixelY(834),
                fromPixelY(834),
                fromPixelY(below_screen),
                fromPixelY(below_screen),
            },
        } },
        // Top platform
        Shape{ .quad = .{
            .X = .{
                fromPixelX(1369),
                fromPixelX(620),
                fromPixelX(620),
                fromPixelX(1369),
            },
            .Y = .{
                fromPixelY(559),
                fromPixelY(559),
                fromPixelY(573),
                fromPixelY(573),
            },
        } },
    },
){};

pub fn fromPixelX(comptime x: comptime_int) float {
    return x / constants.PIXELS_PER_METER - (constants.STAGE_WIDTH_METERS / 2);
}

pub fn fromPixelY(comptime y: comptime_int) float {
    return -y / constants.PIXELS_PER_METER + (constants.STAGE_HEIGHT_METERS / 2);
}
