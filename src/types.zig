/// Common types
const VEC_LENGTH = @import("constants.zig").VEC_LENGTH;

pub const float = f32;
pub const Vec = @Vector(VEC_LENGTH, float);
pub const VecI32 = @Vector(VEC_LENGTH, i32);
pub const VecBool = @Vector(VEC_LENGTH, bool);
