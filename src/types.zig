/// Common types
const VEC_LENGTH = @import("constants.zig").VEC_LENGTH;

pub const float = f32;
pub const Vec = @Vector(VEC_LENGTH, float);
pub const VecI32 = @Vector(VEC_LENGTH, i32);
pub const VecBool = @Vector(VEC_LENGTH, bool);

pub const HorizontalDirection = enum(i2) {
    LEFT = -1,
    RIGHT = 1,
    NONE = 0,
};

pub const PlaneAxialDirection = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    NONE,
};
