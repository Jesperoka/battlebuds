/// Common constants
const inf = @import("std").math.inf;
const float = @import("types.zig").float;
const Vec = @import("types.zig").Vec;
const VecBool = @import("types.zig").VecBool;
const VecI32 = @import("types.zig").VecI32;

//                  Game
// -----------------------------------------
pub const MAX_NUM_PLAYERS = 4;

pub const TIMESTEP_S: float = 1.0 / 60.0;
pub const TIMESTEP_NS: u64 = 1.667e+7;
pub const ANIMATION_SLOWDOWN_FACTOR: u64 = 3;

pub const DEFAULT_RUN_VELOCITY: float = 5.9;
pub const DEFAULT_RUN_ACCELERATION: float = 129.9;

pub const DEFAULT_JUMP_SQUAT_FRAMES: u8 = 5;
pub const DEFAULT_JUMP_VELOCITY: float = 9.9;
pub const DEFAULT_DOUBLE_JUMP_VELOCITY: float = DEFAULT_JUMP_VELOCITY;
pub const DEFAULT_HORIZONTAL_JUMP_VELOCITY: float = DEFAULT_RUN_VELOCITY;

// -----------------------------------------

//                  Window
// -----------------------------------------
pub const TITLE: [*]const u8 = "Battlebuds";
pub const X_RESOLUTION: u16 = 1920;
pub const Y_RESOLUTION: u16 = 1080;
pub const ASPECT_RATIO: float = 16.0 / 9.0;

pub const STAGE_WIDTH_METERS: float = 20;
pub const STAGE_HEIGHT_METERS: float = STAGE_WIDTH_METERS / ASPECT_RATIO;
pub const PIXELS_PER_METER: float = @as(float, @floatFromInt(X_RESOLUTION)) / STAGE_WIDTH_METERS;
// -----------------------------------------

//                  Numeric
// -----------------------------------------
pub const INFINITY: float = inf(float);

pub const VEC_LENGTH = 32;
pub const ZERO_VEC: Vec = @splat(0);
pub const ONE_VEC: Vec = @splat(1);
pub const TWO_VEC: Vec = @splat(2);
pub const TRUE_VEC: VecBool = @splat(true);
pub const FALSE_VEC: VecBool = @splat(false);
pub const INT_ZERO_VEC: VecI32 = @splat(0);
// -----------------------------------------
