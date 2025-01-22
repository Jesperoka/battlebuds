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
const ID = @import("assets.zig").ID;
const ASSETS_PER_ID = @import("assets.zig").ASSETS_PER_ID;

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
    stage_assets: stages.StageAssets = undefined,
    timer: std.time.Timer,
    num_players: u8,

    pub fn init(
        comptime input_handler: *InputHandler,
        comptime renderer: *Renderer,
        comptime dynamic_entities: *DynamicEntities,
        comptime sim_state: *SimulatorState,
    ) Game {
        return Game{
            .input_handler = input_handler.init(),
            .renderer = renderer.init(), // Calls SDL_Init().
            .dynamic_entities = dynamic_entities,
            .sim_state = sim_state,
            .timer = std.time.Timer.start() catch unreachable,
            .num_players = input_handler.num_devices, // Relies on ordering of init.
        };
    }
    pub fn deinit(self: *Game) void {
        self.input_handler.deinit();
        self.renderer.deinit(); // Calls SDL_Quit().
    }

    pub fn run(self: *Game) void {
        game_outer_loop: while (true) {
            var counter: u64 = 0;

            // Select stage
            var current_stage: stages.StageID = .Meteor;

            stage_selection_loop: while (true) {
                self.timer.reset();
                defer self.read_player_inputs_while_waiting_for_end_of_frame();

                // TODO: play stage switch animation.
                current_stage = current_stage.switch_stage(self.player_actions[0].x_dir);

                const quit_game = handle_sdl_events();
                if (quit_game) break :game_outer_loop;

                self.renderer.draw_looping_animations(counter, &[_]ID{ID.MENU_WAITING_FORINPUT}, constants.TIMESTEP_NS) catch unreachable;
                self.renderer.render();

                if (self.player_actions[0].jump) break :stage_selection_loop;

                // TODO: allow button press to de- and re-init self.input_handler.
                // also allow button press on any of the controllers to add it to
                // self.num_players. Might be complicated a bit by ordering of reports.
                // self.input_handler.read_input() uses self.input_handler.devices array
                // to determine player ordering, which is set during init, and probably
                // determined by port position in hardware.
            }

            self.play_stage_selected_animation(current_stage, counter, constants.STAGE_SELECT_ANIMATION_TIMESTEP_NS);

            // Select Characters
            // TODO: implement + num_player detection.

            self.num_players = 2;

            // This is the actual character assignments.
            // NOTE: can maybe use EntityMode.init() here to default init mode of all characters.
            const entity_modes: [constants.MAX_NUM_PLAYERS]EntityMode = .{
                .{ .character_test = .STANDING },
                .{ .character_wurmple = .STANDING },
                .{ .dont_load = .TEXTURE },
                .{ .dont_load = .TEXTURE },
            };

            self.prepare_for_match(current_stage, entity_modes);

            // Play Start Countdown Animation
            // TODO: implement

            // Zero player characters and actions
            for (0..self.num_players) |i| {
                self.player_characters[i] = CharacterState{};
                self.player_actions[i] = InputHandler.PlayerAction{};
            }

            // Start match
            var stop = false;
            while (!stop) {
                self.timer.reset();
                defer self.read_player_inputs_while_waiting_for_end_of_frame();

                stop = self.step(counter);

                const quit_game = handle_sdl_events();
                if (quit_game) break :game_outer_loop;

                counter += 1;

                // NOTE: if I want to have uncapped frame rate, I need to only
                // update counter based on a fixed frame-rate time, so animations
                // still play at the correct frame rate, and then I just need to
                // pass the actual time between frames to the physics functions.
            }
        }
    }

    // Always reads player inputs atleast once.
    fn read_player_inputs_while_waiting_for_end_of_frame(self: *Game) void {
        var atleast_once = true;
        while (self.timer.read() < constants.TIMESTEP_NS or atleast_once) {
            atleast_once = false;

            const reports = self.input_handler.read_input();
            for (reports, 0..self.num_players) |report, i| {
                self.player_actions[i] = InputHandler.action(report);
            }
        }
    }

    fn play_stage_selected_animation(self: *Game, selected_stage: stages.StageID, global_counter: u64, frame_interval_ns: u64) void {
        const FRAME_TO_SHOW_STAGE = 7;
        const stage_assets = stages.stageAssets(selected_stage);

        for (0..ASSETS_PER_ID[ID.MENU_STAGE_SELECTED.int()]) |local_counter| {
            self.timer.reset();

            if (local_counter >= FRAME_TO_SHOW_STAGE) {
                self.renderer.draw_looping_animations(global_counter + local_counter, stage_assets.background, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
                self.renderer.draw_looping_animations(global_counter + local_counter, stage_assets.foreground, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
            }
            self.renderer.draw_animation_frame(local_counter, ID.MENU_STAGE_SELECTED) catch unreachable;

            self.renderer.render();
            while (self.timer.read() < frame_interval_ns) {} // Do nothing.
        }
    }

    fn step(self: *Game, counter: u64) bool {
        for (0..self.num_players) |player| {
            const entity_mode, const movement = handle_character_action(
                &self.player_characters[player],
                self.dynamic_entities.modes[player],
                self.sim_state.floor_collision[player],
                self.player_actions[player],
            );

            self.dynamic_entities.modes[player] = entity_mode;
            self.sim_state.physics_state.dY[player] = if (movement.jump) movement.vertical_velocity else self.sim_state.physics_state.dY[player];
            self.sim_state.physics_state.dX[player] = movement.horizontal_velocity;
            self.sim_state.physics_state.ddX[player] += movement.horizontal_acceleration;
        }

        self.sim_state.newtonianMotion(constants.TIMESTEP_S);
        self.sim_state.resolveCollisions(self.stage_assets.geometry);
        self.sim_state.gamePhysics();

        self.dynamic_entities.updatePosition(self.sim_state.physics_state.X, self.sim_state.physics_state.Y);

        self.renderer.draw_looping_animations(counter, self.stage_assets.background, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
        self.renderer.draw_dynamic_entities(counter, self.dynamic_entities, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
        self.renderer.draw_looping_animations(counter, self.stage_assets.foreground, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
        self.renderer.render();

        return false; // Temporary solution until game has win-condition.
        // return stop;
    }

    fn prepare_for_match(self: *Game, stage_id: stages.StageID, entity_modes: [constants.MAX_NUM_PLAYERS]EntityMode) void {
        const seed = @as(u64, @intCast(std.time.microTimestamp()));
        var prng = std.Random.DefaultPrng.init(seed);
        var shuffled_indices = utils.range(u8, 0, constants.MAX_NUM_PLAYERS);
        prng.random().shuffle(u8, &shuffled_indices);

        const starting_positions = stages.startingPositions(stage_id);

        self.dynamic_entities.init(starting_positions, shuffled_indices, entity_modes);
        self.sim_state.init(starting_positions, shuffled_indices);
        self.stage_assets = stages.stageAssets(stage_id);
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
        floor_collision: bool,
        action: InputHandler.PlayerAction,
    ) struct { EntityMode, CharacterMovement } {
        current_character_state.resources.has_jump = floor_collision or current_character_state.resources.has_jump;

        switch (current_entity_mode) {
            .dont_load => { // TODO: proper init so this can be handled to return DontLoadMode.
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
                    floor_collision,
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
    floor_collision: bool,
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

            // TODO: if enough frames in a row don't have floor_collision, transition to FLYING_XXXX depending on movement.

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
                current_character_state.action_dependent_frame_counter = constants.DEFAULT_JUMP_AGAIN_DELAY_FRAMES;
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

            if (action.jump and current_character_state.resources.has_jump and (current_character_state.action_dependent_frame_counter <= 0)) {
                jump = true; // TODO: trigger double jump effect animation
                current_character_state.resources.has_jump = false;
                vertical_velocity = constants.DEFAULT_DOUBLE_JUMP_VELOCITY;
            } else {
                current_character_state.action_dependent_frame_counter -|= 1;
            }

            switch (action.x_dir) {
                .NONE => {
                    current_character_state.mode = if (!floor_collision) .FLYING_NEUTRAL else .STANDING;
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
                    current_character_state.mode = if (!floor_collision) .FLYING_LEFT else .RUNNING_LEFT;
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
                    current_character_state.mode = if (!floor_collision) .FLYING_RIGHT else .RUNNING_RIGHT;
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

pub const HorizontalDirection = enum(i2) {
    LEFT = -1,
    RIGHT = 1,
    NONE = 0,
};

const PlaneAxialDirection = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
    NONE,
};

// InputHandling is going to be specific to my controllers for now.
pub const InputHandler = struct {
    const vendor_id: c_ushort = 0x081F;
    const product_id: c_ushort = 0xE401;
    const max_num_devices = 4;
    const report_read_time_ms = 100;
    const report_num_bytes = 8; // + 1 if numbered report

    const PlayerAction = struct {
        x_dir: HorizontalDirection = .NONE,
        jump: bool = false,
        shoot_dir: PlaneAxialDirection = .NONE,
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

    fn init(comptime self: *InputHandler) *InputHandler {
        utils.assert(hidapi.hid_init() == 0, "hid_init() failed.");

        const device_info = hidapi.hid_enumerate(vendor_id, product_id);
        defer hidapi.hid_free_enumeration(device_info);

        var current = device_info;

        var index_past_latest_discovered_device: usize = 0;
        while (current) |dev| {
            if (dev.*.vendor_id == vendor_id and dev.*.product_id == product_id) {
                self.devices[index_past_latest_discovered_device] = hidapi.hid_open_path(dev.*.path).?;
                index_past_latest_discovered_device += 1;
            }
            current = dev.*.next;
        }
        self.num_devices = @intCast(index_past_latest_discovered_device);

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
