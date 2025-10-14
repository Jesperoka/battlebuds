/// Common constants
const inf = @import("std").math.inf;
const float = @import("types.zig").float;
const Vec = @import("types.zig").Vec;
const VecBool = @import("types.zig").VecBool;
const VecI32 = @import("types.zig").VecI32;

//                  Game
// -----------------------------------------
pub const MAX_NUM_PLAYERS = 4;

const BASE_FRAMERATE: float = 60; // Don't change.
pub const FRAMERATE: float = 144;
pub const FRAMERATE_TO_BASE_FRAMERATE_RATIO: float = FRAMERATE / BASE_FRAMERATE;

pub const TIMESTEP_S: float = 1.0 / FRAMERATE; // 1.0 / 60.0;
pub const TIMESTEP_NS: u64 = @intFromFloat((1.0 / FRAMERATE) * 1e+9); // 1.667e+7;
pub const SECONDS_TO_HOLD_TO_QUIT_GAME: float = 1.0;

pub const ANIMATION_SLOWDOWN_FACTOR: float = 3.0 * FRAMERATE_TO_BASE_FRAMERATE_RATIO;
pub const STAGE_SELECT_ANIMATION_TIMESTEP_NS: u64 = (5.0 / BASE_FRAMERATE) * 1e+9;
pub const STAGE_SWITCH_ANIMATION_TIMESTEP_NS: u64 = (5.0 / BASE_FRAMERATE) * 1e+9;
pub const STAGE_SWITCH_ANIMATION_NUM_FRAMES: u64 = 3;

pub const DEFAULT_RUN_VELOCITY: float = 5.9;
pub const DEFAULT_RUN_ACCELERATION: float = 0.0;

pub const DEFAULT_JUMP_SQUAT_FRAMES: u8 = 5;
pub const DEFAULT_JUMP_AGAIN_DELAY_FRAMES: u8 = @intFromFloat(5 * FRAMERATE_TO_BASE_FRAMERATE_RATIO);
pub const DEFAULT_JUMP_VELOCITY: float = 15.9;
pub const DEFAULT_DOUBLE_JUMP_VELOCITY: float = DEFAULT_JUMP_VELOCITY;
pub const DEFAULT_HORIZONTAL_JUMP_VELOCITY: float = DEFAULT_RUN_VELOCITY;

pub const UI_ASSETS_PER_PLAYER: u8 = 2;
pub const MAX_HEALTH_POINTS: u8 = 15;
pub const MAX_AMMO_COUNT: u8 = 7;
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

pub const STAGE_THUMBNAIL_WIDTH: u16 = 940;
pub const STAGE_THUMBNAIL_HEIGHT: u16 = 540;
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
