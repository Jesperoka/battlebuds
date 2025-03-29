/// This file contains the state machine transition functions for game's entites.

// Modules
const constants = @import("constants.zig");

// Types
const IDFromEntityMode = @import("visual_assets.zig").IDFromEntityMode;
const EntityMode = @import("visual_assets.zig").EntityMode;
const PlayerAction = @import("game.zig").PlayerAction;
const PlaneAxialDirection = @import("types.zig").PlaneAxialDirection;
const float = @import("types.zig").float;

// Functions
const corrected_animation_counter = @import("render.zig").corrected_animation_counter;
const print = @import("std").debug.print;

// Constants
const ASSETS_PER_ID = @import("visual_assets.zig").ASSETS_PER_ID;

// TODO: These will be public, maybe move to types.zig.
pub const CharacterMode = enum(u8) {
    NONE,
    STANDING,
    RUNNING_LEFT,
    RUNNING_RIGHT,
    JUMPING,
    FLYING_NEUTRAL,
    FLYING_LEFT,
    FLYING_RIGHT,
    ATTACKING_UP,
    ATTACKING_DOWN,
    ATTACKING_LEFT,
    ATTACKING_RIGHT,

    fn enum_literal(comptime mode: CharacterMode) @TypeOf(.enum_literal) {
        switch (mode) {
            inline .STANDING => return .STANDING,
            inline .RUNNING_LEFT => return .RUNNING_LEFT,
            inline .RUNNING_RIGHT => return .RUNNING_RIGHT,
            inline .JUMPING => return .JUMPING,
            inline .FLYING_NEUTRAL => return .FLYING_NEUTRAL,
            inline .FLYING_LEFT => return .FLYING_LEFT,
            inline .FLYING_RIGHT => return .FLYING_RIGHT,
            inline .ATTACKING_UP => return .ATTACKING_UP,
            inline .ATTACKING_DOWN => return .ATTACKING_DOWN,
            inline .ATTACKING_LEFT => return .ATTACKING_LEFT,
            inline .ATTACKING_RIGHT => return .ATTACKING_RIGHT,
            inline .NONE => return .NONE,
        }
    }

    // Exists for a little bit of flexibility in how attacks are designed (don't know if they will be the same for all characters yet).
    // If they all end up the same => just assign the CharacterMode directly to attack_dir.
    fn enum_literal_from_attack_direction(attack_dir: PlaneAxialDirection) @TypeOf(.enum_literal) {
        switch (attack_dir) {
            inline .UP => return .ATTACKING_UP,
            inline .DOWN => return .ATTACKING_DOWN,
            inline .LEFT => return .ATTACKING_LEFT,
            inline .RIGHT => return .ATTACKING_RIGHT,
            inline .NONE => return .NONE,
        }
    }
};

const CharacterResources = packed struct {
    health_points: u4 = 15,
    ammo_count: u3 = 7,
    has_jump: bool = true,
};

pub const CharacterState = packed struct {
    resources: CharacterResources = .{},
    mode: CharacterMode = .NONE,
    action_dependent_frame_counter: u8 = 0,
};

pub const CharacterMovement = struct {
    jump: bool = false,
    horizontal_velocity: float = 0,
    vertical_velocity: float = 0,
    horizontal_acceleration: float = 0,
};

pub const AnimationCounterCorrection = packed struct {
    frames: u7 = 0,
    update: bool = false,
};

// Side-effect: Updates current_character_state.
fn character_shooting_state_transition(
    CharacterType: type,
    current_character_state: *CharacterState,
    horizontal_velocity: float,
    vertical_velocity: float,
    global_counter: u64,
    comptime ATTACKING_DIRECTION_ENUM_LITERAL: @TypeOf(.enum_literal),
) struct { EntityMode, CharacterMovement, AnimationCounterCorrection } {
    const horizontal_velocity_attack_modifier: float = 1.0; // TODO: switch on CharacterType.
    const num_animation_frames: u8 = @intCast(ASSETS_PER_ID[IDFromEntityMode(EntityMode.from_enum_literal(CharacterType, ATTACKING_DIRECTION_ENUM_LITERAL)).int()]);
    const frame_correction: u7 = @intCast(corrected_animation_counter(global_counter, constants.ANIMATION_SLOWDOWN_FACTOR) % num_animation_frames);

    current_character_state.mode = ATTACKING_DIRECTION_ENUM_LITERAL;
    current_character_state.action_dependent_frame_counter = @intFromFloat(@as(float, @floatFromInt(num_animation_frames)) * constants.ANIMATION_SLOWDOWN_FACTOR);

    return .{
        EntityMode.from_enum_literal(CharacterType, ATTACKING_DIRECTION_ENUM_LITERAL),
        .{
            .jump = false,
            .horizontal_velocity = horizontal_velocity_attack_modifier * horizontal_velocity,
            .vertical_velocity = vertical_velocity,
            .horizontal_acceleration = 0,
        },
        .{ .frames = frame_correction, .update = true },
    };
}

fn character_jumping_state_transition(
    CharacterType: type,
    current_character_state: *CharacterState,
    horizontal_velocity: float,
    vertical_velocity: float,
    global_counter: u64,
) struct { EntityMode, CharacterMovement, AnimationCounterCorrection } {

    // NOTE: Can switch on CharacterType to determine the JUMP_SQUAT_FRAMES.

    const frame_correction: u7 = @intCast(corrected_animation_counter(global_counter, constants.ANIMATION_SLOWDOWN_FACTOR) % constants.DEFAULT_JUMP_SQUAT_FRAMES);
    current_character_state.mode = .JUMPING;
    current_character_state.action_dependent_frame_counter = @intFromFloat(@as(float, @floatFromInt(constants.DEFAULT_JUMP_SQUAT_FRAMES)) * constants.ANIMATION_SLOWDOWN_FACTOR);

    return .{
        EntityMode.from_enum_literal(CharacterType, .JUMPING),
        .{
            .jump = false,
            .horizontal_velocity = horizontal_velocity,
            .vertical_velocity = vertical_velocity,
            .horizontal_acceleration = 0,
        },
        .{ .frames = frame_correction, .update = true },
    };
}

// This function is a bit control-flow heavy, because it has to be.
// It's the base-character state-machine transition function.
// EntityMode determines the rendered texture, while CharacterState determines how EntityMode changes.
// CharacterState also determines the change in PhysicsState that results from the character action.
pub fn base_character_state_transition(
    CharacterType: type,
    current_character_state: *CharacterState,
    floor_collision: bool,
    horizontal_velocity: float,
    vertical_velocity: float,
    action: PlayerAction,
    global_counter: u64,
) struct { EntityMode, CharacterMovement, AnimationCounterCorrection } {
    switch (current_character_state.mode) {
        inline .NONE => {
            // TODO: Can do a spawn animation first here (.SPAWNING state transition).
            current_character_state.mode = .STANDING;
            return .{
                EntityMode.from_enum_literal(CharacterType, .STANDING),
                .{
                    .jump = false,
                    .horizontal_velocity = horizontal_velocity,
                    .vertical_velocity = vertical_velocity,
                    .horizontal_acceleration = 0,
                },
                .{},
            };
        },
        inline .STANDING,
        .RUNNING_LEFT,
        .RUNNING_RIGHT,
        => {

            // TODO: if enough frames in a row don't have floor_collision, transition to FLYING_XXXX depending on movement.

            if (action.jump) {
                return character_jumping_state_transition(
                    CharacterType,
                    current_character_state,
                    horizontal_velocity,
                    vertical_velocity,
                    global_counter,
                );
            }

            switch (action.attack_dir) {
                inline .UP, .DOWN, .LEFT, .RIGHT => |ATTACK_DIRECTION| return character_shooting_state_transition(
                    CharacterType,
                    current_character_state,
                    horizontal_velocity,
                    vertical_velocity,
                    global_counter,
                    CharacterMode.enum_literal_from_attack_direction(ATTACK_DIRECTION),
                ),
                inline .NONE => {},
            }

            switch (action.x_dir) {
                inline .NONE => {
                    current_character_state.mode = .STANDING;
                    return .{
                        EntityMode.from_enum_literal(CharacterType, .STANDING),
                        .{ .jump = false, .horizontal_velocity = horizontal_velocity, .vertical_velocity = vertical_velocity, .horizontal_acceleration = 0 },
                        .{},
                    };
                },
                inline .LEFT => {
                    current_character_state.mode = .RUNNING_LEFT;
                    return .{
                        EntityMode.from_enum_literal(CharacterType, .RUNNING_LEFT),
                        .{
                            .jump = false,
                            .horizontal_velocity = -@max(@abs(horizontal_velocity), constants.DEFAULT_RUN_VELOCITY),
                            .vertical_velocity = vertical_velocity,
                            .horizontal_acceleration = -constants.DEFAULT_RUN_ACCELERATION,
                        },
                        .{},
                    };
                },
                inline .RIGHT => {
                    current_character_state.mode = .RUNNING_RIGHT;
                    return .{
                        EntityMode.from_enum_literal(CharacterType, .RUNNING_RIGHT),
                        .{
                            .jump = false,
                            .horizontal_velocity = @max(@abs(horizontal_velocity), constants.DEFAULT_RUN_VELOCITY),
                            .vertical_velocity = vertical_velocity,
                            .horizontal_acceleration = constants.DEFAULT_RUN_ACCELERATION,
                        },
                        .{},
                    };
                },
            }
        },
        inline .JUMPING => {
            if (current_character_state.action_dependent_frame_counter > 0) {
                current_character_state.action_dependent_frame_counter -= 1;
                return .{
                    EntityMode.from_enum_literal(CharacterType, .JUMPING),
                    .{
                        .jump = false,
                        .horizontal_velocity = horizontal_velocity,
                        .vertical_velocity = vertical_velocity,
                        .horizontal_acceleration = 0,
                    },
                    .{},
                };
            } else {
                current_character_state.action_dependent_frame_counter = constants.DEFAULT_JUMP_AGAIN_DELAY_FRAMES;
                switch (action.x_dir) {
                    inline .NONE => {
                        current_character_state.mode = .FLYING_NEUTRAL;
                        return .{
                            EntityMode.from_enum_literal(CharacterType, .FLYING_NEUTRAL),
                            .{
                                .jump = true,
                                .horizontal_velocity = horizontal_velocity,
                                .vertical_velocity = constants.DEFAULT_JUMP_VELOCITY,
                                .horizontal_acceleration = 0,
                            },
                            .{ .frames = 0, .update = true },
                        };
                    },
                    inline .LEFT => {
                        current_character_state.mode = .FLYING_LEFT;
                        return .{
                            EntityMode.from_enum_literal(CharacterType, .FLYING_LEFT),
                            .{
                                .jump = true,
                                .horizontal_velocity = -@max(@abs(horizontal_velocity), constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY),
                                .vertical_velocity = constants.DEFAULT_JUMP_VELOCITY,
                                .horizontal_acceleration = -constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                            },
                            .{},
                        };
                    },
                    inline .RIGHT => {
                        current_character_state.mode = .FLYING_RIGHT;
                        return .{
                            EntityMode.from_enum_literal(CharacterType, .FLYING_RIGHT),
                            .{
                                .jump = true,
                                .horizontal_velocity = @max(@abs(horizontal_velocity), constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY),
                                .vertical_velocity = constants.DEFAULT_JUMP_VELOCITY,
                                .horizontal_acceleration = constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                            },
                            .{},
                        };
                    },
                }
            }
        },
        inline .ATTACKING_UP,
        .ATTACKING_DOWN,
        .ATTACKING_LEFT,
        .ATTACKING_RIGHT,
        => |ATTACKING_DIRECTION| {
            if (current_character_state.action_dependent_frame_counter > 0) {
                current_character_state.action_dependent_frame_counter -= 1;
                return .{
                    EntityMode.from_enum_literal(CharacterType, ATTACKING_DIRECTION.enum_literal()),
                    .{
                        .jump = false,
                        .horizontal_velocity = horizontal_velocity,
                        .vertical_velocity = vertical_velocity,
                        .horizontal_acceleration = 0,
                    },
                    .{},
                };
            } else {
                // TODO: Knockback/Recoil
                current_character_state.mode = .STANDING;
                return .{
                    EntityMode.from_enum_literal(CharacterType, .STANDING),
                    .{
                        .jump = false,
                        .horizontal_velocity = horizontal_velocity,
                        .vertical_velocity = vertical_velocity,
                        .horizontal_acceleration = 0,
                    },
                    .{ .frames = 0, .update = true },
                };
            }
        },
        inline .FLYING_NEUTRAL,
        .FLYING_LEFT,
        .FLYING_RIGHT,
        => {
            var new_vertical_velocity: float = vertical_velocity;
            var jump: bool = false;

            if (action.jump and current_character_state.resources.has_jump and (current_character_state.action_dependent_frame_counter <= 0)) {
                jump = true; // TODO: trigger double jump effect animation
                current_character_state.resources.has_jump = false;
                new_vertical_velocity = @max(@abs(vertical_velocity), constants.DEFAULT_DOUBLE_JUMP_VELOCITY);
            } else {
                current_character_state.action_dependent_frame_counter -|= 1;
            }

            switch (action.x_dir) {
                inline .NONE => {
                    current_character_state.mode = if (!floor_collision) .FLYING_NEUTRAL else .STANDING;
                    return .{
                        EntityMode.from_enum_literal(CharacterType, .FLYING_NEUTRAL),
                        .{
                            .jump = jump,
                            .horizontal_velocity = horizontal_velocity,
                            .vertical_velocity = new_vertical_velocity,
                            .horizontal_acceleration = 0,
                        },
                        .{},
                    };
                },
                inline .LEFT => {
                    current_character_state.mode = if (!floor_collision) .FLYING_LEFT else .RUNNING_LEFT;
                    return .{
                        EntityMode.from_enum_literal(CharacterType, .FLYING_LEFT),
                        .{
                            .jump = jump,
                            .horizontal_velocity = -@max(@abs(horizontal_velocity), constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY),
                            .vertical_velocity = new_vertical_velocity,
                            .horizontal_acceleration = -constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                        },
                        .{},
                    };
                },
                inline .RIGHT => {
                    current_character_state.mode = if (!floor_collision) .FLYING_RIGHT else .RUNNING_RIGHT;
                    return .{
                        EntityMode.from_enum_literal(CharacterType, .FLYING_RIGHT),
                        .{
                            .jump = jump,
                            .horizontal_velocity = @max(@abs(horizontal_velocity), constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY),
                            .vertical_velocity = new_vertical_velocity,
                            .horizontal_acceleration = constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                        },
                        .{},
                    };
                },
            }
        },
    }
    print("wtf: {any}", .{current_character_state.mode});
    unreachable;
}
