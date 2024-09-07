const max_num_players = @import("game.zig").max_num_players;
const float = @import("physics.zig").float;

pub const Rectangle = struct { x_tl: float, y_tl: float, x_br: float, y_br: float };
pub const Circle = struct { center: float, radius: float };
pub const TriangleLeft = struct { hypotenuse: float };
pub const TriangleRight = struct { hypotenuse: float };

pub const Shape = union(enum) {
    rect: Rectangle,
    circ: Circle,
    tri_left: TriangleLeft,
    tri_right: TriangleRight,
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
    comptime starting_positions: [max_num_players]Position,
    comptime num_shapes: comptime_int,
    comptime geometry: [num_shapes]Shape,
) type {
    return struct {
        id: u8 = id,
        name: []const u8 = name,
        starting_positions: [max_num_players]Position = starting_positions,

        geometry: [num_shapes]Shape = geometry,

        // TODO: add whatever I need for environment collision
        // i.e. rectangles and other geometry.
        // I need to make a utility to export a map to a visible format,
        // so that I can make art for the stage on top of the stage geometry.
        // Maybe just scale up some ASCII art to the screen resolution.
    };
}

pub const s0 = Stage(
    0,
    "Flat Earth Theory",
    .{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = -2.5 },
        .{ .x = -5, .y = 0 },
        .{ .x = 5, .y = 0 },
    },
    4,
    .{
        Shape{ .rect = .{ .x_tl = -(stage_width_meters / 2), .y_tl = -3.5, .x_br = (stage_width_meters / 2), .y_br = -4.4 } },
        Shape{ .rect = .{ .x_tl = -(stage_width_meters / 2), .y_tl = 3.5, .x_br = (stage_width_meters / 2), .y_br = 3.3 } },
        Shape{ .rect = .{ .x_tl = -5.3, .y_tl = (stage_height_meters / 2), .x_br = -5.0, .y_br = -(stage_height_meters / 2) } },
        Shape{ .rect = .{ .x_tl = 5.3, .y_tl = (stage_height_meters / 2), .x_br = 5.0, .y_br = -(stage_height_meters / 2) } },
    },
){};
