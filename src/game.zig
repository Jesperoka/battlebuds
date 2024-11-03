/// Gameplay logic
const std = @import("std");
const hidapi = @cImport(@cInclude("hidapi.h"));

const SDL_PollEvent = @import("sdl2").SDL_PollEvent;
const SDL_Event = @import("sdl2").SDL_Event;
const SDL_QUIT = @import("sdl2").SDL_QUIT;
const SDL_KEYDOWN = @import("sdl2").SDL_KEYDOWN;
const SDL_KeyboardEvent = @import("sdl2").SDL_KeyboardEvent;
const SDLK_q = @import("sdl2").SDLK_q;
const SDL_Renderer = @import("sdl2").SDL_Renderer;
const SDL_Window = @import("sdl2").SDL_Window;

const constants = @import("constants.zig");
const utils = @import("utils.zig");
const stages = @import("stages.zig");

// Private Types
const float = @import("types.zig").float;
const EntityMode = @import("assets.zig").EntityMode;

// Public Types
pub const Renderer = @import("render.zig").Renderer;
pub const DynamicEntities = @import("render.zig").DynamicEntities;
pub const SimulatorState = @import("physics.zig").SimulatorState;

// Main gameplay loop structure
pub const Game = struct {
    player_characters: [constants.MAX_NUM_PLAYERS]CharacterState = undefined,
    player_actions: [constants.MAX_NUM_PLAYERS]InputHandler.PlayerAction = undefined,
    input_handler: *InputHandler,
    renderer: *Renderer,
    dynamic_entities: *DynamicEntities,
    sim_state: *SimulatorState,
    stage_assets: stages.StageAssets,
    timer: std.time.Timer,
    num_players: u8,

    pub fn init(
        comptime num_players: u8,
        comptime input_handler: *InputHandler,
        comptime renderer: *Renderer,
        comptime dynamic_entities: *DynamicEntities,
        comptime sim_state: *SimulatorState,
    ) Game {
        // Random starting locations
        const seed = @as(u64, @intCast(std.time.microTimestamp()));
        var prng = std.Random.DefaultPrng.init(seed);
        var indices = comptime utils.range(u8, 0, num_players);
        prng.random().shuffle(u8, &indices);

        return Game{
            .input_handler = input_handler.init(num_players),
            .renderer = renderer.init(),
            .dynamic_entities = dynamic_entities.init(num_players, &stages.stage0, indices),
            .sim_state = sim_state.init(num_players, &stages.stage0, indices),
            .stage_assets = stages.stageAssets(0),
            .timer = std.time.Timer.start() catch unreachable,
            .num_players = num_players,
        };
    }
    pub fn deinit(self: *Game) void {
        self.input_handler.deinit();
        self.renderer.deinit();
    }

    pub fn run(self: *Game) void {
        // TODO: make outer loop with stage selection;
        // self.stage_assets = stages.stageAssets(0);

        // Zero player characters and actions
        for (0..self.num_players) |i| {
            self.player_characters[i] = CharacterState{};
            self.player_actions[i] = InputHandler.PlayerAction{};
        }

        var stop = false;
        var counter: u64 = 0;

        // Start match
        while (!stop) {
            self.timer.reset();
            stop = self.step(counter);

            // Always read player inputs
            var atleast_once = true;
            while (self.timer.read() < constants.TIMESTEP_NS or atleast_once) {
                atleast_once = false;
                const reports = self.input_handler.read_input();
                for (reports, 0..self.num_players) |report, i| {
                    self.player_actions[i] = InputHandler.action(report);
                }
            }
            counter += 1;
        }
    }

    fn step(self: *Game, counter: u64) bool {
        const stop = handle_sdl_events();

        for (0..self.num_players) |player| {
            const entity_mode, const movement = handle_character_action(
                &self.player_characters[player],
                self.dynamic_entities.modes[player],
                self.player_actions[player],
            );

            self.player_characters[player].resources.has_jump = self.sim_state.floor_collision[player] or self.player_characters[player].resources.has_jump;

            self.dynamic_entities.modes[player] = entity_mode;
            self.sim_state.physics_state.dY[player] = if (movement.jump) movement.vertical_velocity else self.sim_state.physics_state.dY[player];
            self.sim_state.physics_state.dX[player] = movement.horizontal_velocity;
            self.sim_state.physics_state.ddX[player] += movement.horizontal_acceleration;
        }

        self.sim_state.newtonianMotion(constants.TIMESTEP_S);
        self.sim_state.resolveCollisions(self.stage_assets.geometry);
        self.sim_state.gamePhysics();

        self.dynamic_entities.updatePosition(self.sim_state.physics_state.X, self.sim_state.physics_state.Y);

        self.renderer.draw(counter, self.stage_assets.background) catch unreachable;
        self.renderer.drawDynamicEntitites(counter, self.dynamic_entities) catch unreachable;
        self.renderer.draw(counter, self.stage_assets.foreground) catch unreachable;
        self.renderer.render();

        return stop;
    }

    fn handle_sdl_events() bool {
        var event: SDL_Event = undefined;
        while (SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                SDL_QUIT => return true,
                SDL_KEYDOWN => {
                    const keyboard_event: *SDL_KeyboardEvent = @ptrCast(&event);
                    if (keyboard_event.keysym.sym == SDLK_q) return true;
                },
                else => {},
            }
        }
        return false;
    }

    fn handle_character_action(
        current_character_state: *CharacterState,
        current_entity_mode: EntityMode,
        action: InputHandler.PlayerAction,
    ) struct { EntityMode, CharacterMovement } {
        switch (current_entity_mode) {
            .dont_load => {
                current_character_state.mode = .RUNNING_RIGHT;
                return .{ .{ .character_wurmple = .RUNNING_RIGHT }, .{} };
            },
            inline .character_wurmple,
            .character_guy,
            .character_test,
            => |character| {
                return base_character_state_transition(
                    @TypeOf(character),
                    current_character_state,
                    action,
                );
            },
            else => |character| {
                std.debug.print("\n???: {any}", .{character});
                unreachable;
            },
        }
        unreachable;
    }
};

// This function is a bit control-flow heavy, because it has to be.
// It's the base-character state-machine transition function.
// EntityMode determines the rendered texture, while CharacterState determines how EntityMode changes.
// CharacterState also determines the change in PhysicsState that results from the character action.
fn base_character_state_transition(
    CharacterType: type,
    current_character_state: *CharacterState,
    action: InputHandler.PlayerAction,
) struct { EntityMode, CharacterMovement } {
    switch (current_character_state.mode) {
        .NONE => {
            // BUG: TODO - PROPER INIT!
            // current_entity_mode.* = .{ .dont_load = .TEXTURE }; // TODO: init entity modes properly, so this can be uncommented and the stuff below deleted
            if (action.jump) {
                current_character_state.mode = .RUNNING_RIGHT;
                return .{ .{ .character_wurmple = .RUNNING_RIGHT }, .{} };
            } else {
                current_character_state.mode = .RUNNING_RIGHT;
                return .{ .{ .dont_load = .TEXTURE }, .{} };
            }
        },
        .STANDING,
        .RUNNING_LEFT,
        .RUNNING_RIGHT,
        => {
            if (action.jump) {
                current_character_state.mode = .JUMPING;
                current_character_state.action_dependent_frame_counter = constants.DEFAULT_JUMP_SQUAT_FRAMES;
                return .{ EntityMode.init(CharacterType, .JUMPING), .{} };
            }
            switch (action.x_dir) {
                .NONE => {
                    current_character_state.mode = .STANDING;
                    return .{ EntityMode.init(CharacterType, .STANDING), .{} };
                },
                .LEFT => {
                    current_character_state.mode = .RUNNING_LEFT;
                    return .{
                        EntityMode.init(CharacterType, .RUNNING_LEFT),
                        .{
                            .jump = false,
                            .vertical_velocity = 0,
                            .horizontal_velocity = -constants.DEFAULT_RUN_VELOCITY,
                            .horizontal_acceleration = -constants.DEFAULT_RUN_ACCELERATION,
                        },
                    };
                },
                .RIGHT => {
                    current_character_state.mode = .RUNNING_RIGHT;
                    return .{
                        EntityMode.init(CharacterType, .RUNNING_RIGHT),
                        .{
                            .jump = false,
                            .vertical_velocity = 0,
                            .horizontal_velocity = constants.DEFAULT_RUN_VELOCITY,
                            .horizontal_acceleration = constants.DEFAULT_RUN_ACCELERATION,
                        },
                    };
                },
            }
        },
        .JUMPING => {
            if (current_character_state.action_dependent_frame_counter > 0) {
                current_character_state.action_dependent_frame_counter -= 1;
                return .{
                    EntityMode.init(CharacterType, .JUMPING),
                    .{},
                };
            } else {
                current_character_state.resources.has_jump = false; // TODO: test if works
                switch (action.x_dir) {
                    .NONE => {
                        current_character_state.mode = .FLYING_NEUTRAL;
                        return .{
                            EntityMode.init(CharacterType, .FLYING_NEUTRAL),
                            .{
                                .jump = true,
                                .vertical_velocity = constants.DEFAULT_JUMP_VELOCITY,
                                .horizontal_velocity = 0,
                                .horizontal_acceleration = 0,
                            },
                        };
                    },
                    .LEFT => {
                        current_character_state.mode = .FLYING_LEFT;
                        return .{
                            EntityMode.init(CharacterType, .FLYING_LEFT),
                            .{
                                .jump = true,
                                .vertical_velocity = constants.DEFAULT_JUMP_VELOCITY,
                                .horizontal_velocity = -constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY,
                                .horizontal_acceleration = -constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                            },
                        };
                    },
                    .RIGHT => {
                        current_character_state.mode = .FLYING_RIGHT;
                        return .{
                            EntityMode.init(CharacterType, .FLYING_LEFT),
                            .{
                                .jump = true,
                                .vertical_velocity = constants.DEFAULT_JUMP_VELOCITY,
                                .horizontal_velocity = constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY,
                                .horizontal_acceleration = constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                            },
                        };
                    },
                }
            }
        },
        inline .FLYING_NEUTRAL,
        .FLYING_LEFT,
        .FLYING_RIGHT,
        => {
            var vertical_velocity: float = 0;
            var jump: bool = false;
            if (action.jump and current_character_state.resources.has_jump) {
                // TODO: trigger double jump effect animation
                jump = true;
                current_character_state.resources.has_jump = false;
                vertical_velocity = constants.DEFAULT_DOUBLE_JUMP_VELOCITY;
            }
            switch (action.x_dir) {
                .NONE => {
                    current_character_state.mode = .FLYING_NEUTRAL;
                    return .{
                        EntityMode.init(CharacterType, .FLYING_NEUTRAL),
                        .{
                            .jump = jump,
                            .vertical_velocity = vertical_velocity,
                            .horizontal_velocity = 0,
                            .horizontal_acceleration = 0,
                        },
                    };
                },
                .LEFT => {
                    current_character_state.mode = .FLYING_LEFT;
                    return .{
                        EntityMode.init(CharacterType, .FLYING_LEFT),
                        .{
                            .jump = jump,
                            .vertical_velocity = vertical_velocity,
                            .horizontal_velocity = -constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY,
                            .horizontal_acceleration = -constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                        },
                    };
                },
                .RIGHT => {
                    current_character_state.mode = .FLYING_RIGHT;
                    return .{
                        EntityMode.init(CharacterType, .FLYING_RIGHT),
                        .{
                            .jump = jump,
                            .vertical_velocity = vertical_velocity,
                            .horizontal_velocity = constants.DEFAULT_HORIZONTAL_JUMP_VELOCITY,
                            .horizontal_acceleration = constants.DEFAULT_RUN_ACCELERATION, // TODO: own constant
                        },
                    };
                },
            }
        },
    }
    std.debug.print("wtf: {any}", .{current_character_state.mode});
    unreachable;
}

const CharacterMode = enum(u8) {
    NONE,
    STANDING,
    RUNNING_LEFT,
    RUNNING_RIGHT,
    JUMPING,
    FLYING_NEUTRAL,
    FLYING_LEFT,
    FLYING_RIGHT,
};

const CharacterResources = packed struct {
    health_points: u4 = 15,
    ammo_count: u3 = 7,
    has_jump: bool = true,
};

const CharacterState = packed struct {
    resources: CharacterResources = .{},
    mode: CharacterMode = .NONE,
    action_dependent_frame_counter: u8 = 0,
};

const CharacterMovement = struct {
    jump: bool = false,
    vertical_velocity: float = 0,
    horizontal_velocity: float = 0,
    horizontal_acceleration: float = 0,
};

// InputHandling is going to be specific to my controllers for now.
pub const InputHandler = struct {
    const vendor_id: c_ushort = 0x081F;
    const product_id: c_ushort = 0xE401;
    const max_num_devices = 4;
    const report_read_time_ms = 100;
    const report_num_bytes = 8; // + 1 if numbered report

    const PlayerAction = struct {
        x_dir: enum { LEFT, RIGHT, NONE } = .NONE,
        jump: bool = false,
        shoot_dir: enum { UP, DOWN, LEFT, RIGHT, NONE } = .NONE,
    };

    const UsbGamepadReport = packed struct {
        x_axis: u8, // left: 0, middle: 127, right: 255
        y_axis: u8, // down: 0, middle: 127, up: 255
        padding0: u28,
        X: u1,
        A: u1,
        B: u1,
        Y: u1,
        L: u1,
        R: u1,
        unused_buttons: u2,
        select: u1,
        start: u1,
        unknown: u10,
    }; // 64 bits

    comptime {
        std.debug.assert(@sizeOf(UsbGamepadReport) == report_num_bytes);
    }

    report_data: [max_num_devices][report_num_bytes]u8 = undefined,
    reports: [max_num_devices]*UsbGamepadReport = undefined,
    devices: [max_num_devices]*hidapi.hid_device = undefined,
    num_devices: u8 = undefined,

    fn init(comptime self: *InputHandler, comptime num_players: u8) *InputHandler {
        self.num_devices = num_players;
        utils.assert(hidapi.hid_init() == 0, "hid_init() failed.");

        const device_info = hidapi.hid_enumerate(vendor_id, product_id);
        defer hidapi.hid_free_enumeration(device_info);

        var current = device_info;

        var j: usize = 0;
        while (current) |dev| {
            if (dev.*.vendor_id == vendor_id and dev.*.product_id == product_id) {
                self.devices[j] = hidapi.hid_open_path(dev.*.path).?;
                j += 1;
            }
            current = dev.*.next;
        }

        for (0..self.num_devices) |i| {
            utils.assert(hidapi.hid_read(self.devices[i], &self.report_data[i], report_num_bytes) != -1, "Could not hid_read() device during initialization()");

            self.reports[i] = @ptrCast(@alignCast(&self.report_data[i]));
        }

        return self;
    }

    fn deinit(self: *InputHandler) void {
        for (0..self.num_devices) |idx| {
            hidapi.hid_close(self.devices[idx]);
        }
    }

    fn read_input(self: *InputHandler) []*UsbGamepadReport {
        for (0..self.num_devices) |i| {
            utils.assert(hidapi.hid_read_timeout(
                self.devices[i],
                &self.report_data[i],
                report_num_bytes,
                report_read_time_ms,
            ) != -1, "hid_read() failed.");
        }
        return self.reports[0..self.num_devices];
    }

    fn action(gamepad_report: *UsbGamepadReport) PlayerAction {
        return PlayerAction{
            .x_dir = if (gamepad_report.x_axis == 0) .LEFT else if (gamepad_report.x_axis == 255) .RIGHT else .NONE,
            .jump = @bitCast(gamepad_report.R),
            .shoot_dir = if (@bitCast(gamepad_report.Y)) .LEFT else if (@bitCast(gamepad_report.A)) .RIGHT else if (@bitCast(gamepad_report.X)) .UP else if (@bitCast(gamepad_report.B)) .DOWN else .NONE,
        };
    }
};
