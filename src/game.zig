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
const PlaneAxialDirection = @import("types.zig").PlaneAxialDirection;
const HorizontalDirection = @import("types.zig").HorizontalDirection;
const EntityMode = @import("visual_assets.zig").EntityMode;
const VisualAssetID = @import("visual_assets.zig").ID;
const DontLoadMode = @import("visual_assets.zig").DontLoadMode;
const ASSETS_PER_ID = @import("visual_assets.zig").ASSETS_PER_ID;
const AudioAssetID = @import("audio_assets.zig").ID;
const CharacterState = @import("state_machine.zig").CharacterState;
const CharacterMovement = @import("state_machine.zig").CharacterMovement;
const AnimationCounterCorrection = @import("state_machine.zig").AnimationCounterCorrection;
const CharacterCreatedEntity = @import("state_machine.zig").CharacterCreatedEntity;

// Functions
const IDFromEntityMode = @import("visual_assets.zig").IDFromEntityMode;
const corrected_animation_counter = @import("render.zig").corrected_animation_counter;
const base_character_state_transition = @import("state_machine.zig").base_character_state_transition;

// Public Types
pub const Renderer = @import("render.zig").Renderer;
pub const AudioPlayer = @import("audio.zig").AudioPlayer;
pub const DynamicEntities = @import("render.zig").DynamicEntities;
pub const SimulatorState = @import("physics.zig").SimulatorState;

// Main gameplay loop structure
pub const Game = struct {
    player_characters: [constants.MAX_NUM_PLAYERS]CharacterState = undefined,
    player_actions: [constants.MAX_NUM_PLAYERS]PlayerAction = undefined,
    player_playing: [constants.MAX_NUM_PLAYERS]bool = .{false} ** constants.MAX_NUM_PLAYERS,
    input_handler: *InputHandler,
    renderer: *Renderer,
    audio_player: *AudioPlayer,
    dynamic_entities: *DynamicEntities,
    sim_state: *SimulatorState,
    stage_assets: stages.StageAssets = undefined,
    timer: std.time.Timer,
    num_players: u8,

    pub fn init(
        comptime input_handler: *InputHandler,
        comptime renderer: *Renderer,
        comptime audio_player: *AudioPlayer,
        comptime dynamic_entities: *DynamicEntities,
        comptime sim_state: *SimulatorState,
    ) Game {
        return Game{
            .input_handler = input_handler.init(),
            .renderer = renderer.init(), // Calls SDL_Init().
            .audio_player = audio_player.init(),
            .dynamic_entities = dynamic_entities,
            .sim_state = sim_state,
            .timer = std.time.Timer.start() catch unreachable,
            .num_players = input_handler.num_devices, // Relies on being init after input_handler.
        };
    }

    pub fn deinit(self: *Game) void {
        self.input_handler.deinit();
        self.audio_player.deinit();
        self.renderer.deinit(); // Calls SDL_Quit(), must therefore be called after other structs that use SDL.
    }

    fn input_read_loop(input_handler: *InputHandler, quit_game: *bool, reconnecting: *bool, ready_to_reconnect: *bool) void {
        while (!quit_game.*) { // Doesn't need to be atomic, since it will only ever go from false to true once.
            while (!quit_game.* and !@atomicLoad(bool, reconnecting, .unordered)) {
                input_handler.read_input();
            }
            @atomicStore(bool, ready_to_reconnect, true, .unordered);
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    pub fn run(self: *Game) void {
        var quit_game = false;
        var reconnecting = false;
        var ready_to_reconnect = false;

        const input_reading_thread = std.Thread.spawn(.{}, input_read_loop, .{
            self.input_handler,
            &quit_game,
            &reconnecting,
            &ready_to_reconnect,
        }) catch unreachable;

        defer input_reading_thread.join();
        var current_stage: stages.StageID = .Meteor;

        game_outer_loop: while (true) {
            var counter: u64 = 0;

            // self.audio_player.play(AudioAssetID.MENU_MUSIC_TRACK1, 0);

            // TODO: Clean this up a bit. Too much branching.
            // Select stage and characters.
            stage_selection_loop: while (true) {
                self.timer.reset();
                defer self.wait_for_end_of_frame();

                self.input_handler.update_player_actions_inplace(&self.player_actions);

                // TODO: How is it possible that we enter this loop and print the exit message,
                // but at the same time enter a match?
                if (self.quit_game_hold_loop()) {
                    quit_game = true;
                    break :game_outer_loop;
                }

                if (self.player_actions[0].meta_action == .RECONNECT) {
                    @atomicStore(bool, &reconnecting, true, .unordered);

                    while (!@atomicLoad(bool, &ready_to_reconnect, .unordered)) {
                        std.atomic.spinLoopHint(); // Wait for read loop to kick out.
                    }

                    counter += self.play_reconnection_animation(); // NOTE: Should be a very quick animation.
                    self.input_handler.deinit();
                    self.input_handler = self.input_handler.init();
                    self.num_players = self.input_handler.num_devices;
                    counter += self.play_reconnection_animation(); // TODO: Different animation.

                    @atomicStore(bool, &reconnecting, false, .unordered);
                    @atomicStore(bool, &ready_to_reconnect, false, .unordered);

                    continue;
                    // TODO: Reset discovered controllers graphics.
                    // TODO: Reset active players.
                }

                const direction = self.player_actions[0].x_dir;
                const previous_stage = current_stage;
                current_stage = current_stage.switch_stage(direction);

                if (previous_stage == current_stage) {
                    self.draw_stage_select_animation(counter, current_stage);
                } else {
                    counter += self.play_stage_switch_animation(
                        direction,
                        previous_stage,
                        current_stage,
                        counter,
                        constants.STAGE_SWITCH_ANIMATION_TIMESTEP_NS,
                    );
                }

                var active_players_changed = false;

                // TODO: TEMPORARY
                for (0..self.num_players) |i| {
                    if (self.player_actions[i].meta_action == .PAUSE) {
                        self.player_playing[i] = !self.player_playing[i];
                        self.dynamic_entities.active[i] = if (self.player_playing[i]) 1.0 else 0.0;
                        active_players_changed = true;
                    }

                    try self.renderer.draw_looping_animations_at(
                        counter + 5 * i,
                        &[_]VisualAssetID{if (self.player_playing[i]) VisualAssetID.UI_PLAYER_PLAYING else VisualAssetID.UI_PLAYER_NOTPLAYING},
                        &.{@intCast(i * ((constants.X_RESOLUTION - 200) / constants.MAX_NUM_PLAYERS) + 100)},
                        &.{@intCast(constants.Y_RESOLUTION - 100)},
                        constants.ANIMATION_SLOWDOWN_FACTOR,
                    );
                }
                if (active_players_changed) {
                    // TODO: Differenct animation.
                    counter += self.play_reconnection_animation(); // NOTE: Should be a very quick animation.
                }

                // TODO: Show discovered controllers graphics.
                // TODO: Show players playing graphics.

                self.renderer.render();

                if (self.player_actions[0].jump and !self.player_actions[0].parry and (self.player_actions[0].meta_action == .NONE)) break :stage_selection_loop;

                counter += 1;
            }

            counter += self.play_stage_selected_animation(
                current_stage,
                counter,
                constants.STAGE_SELECT_ANIMATION_TIMESTEP_NS,
            );

            // TODO: Should be able to jump the here to do quick rematch, and play rematch animation (text that says: "Salty??").

            // This is the actual character assignments.
            // NOTE: can maybe use EntityMode.from_enum_literal() here to default init mode of all characters.

            const entity_modes: [constants.MAX_NUM_PLAYERS]EntityMode = assign_entity_modes: {
                var modes: [constants.MAX_NUM_PLAYERS]EntityMode = .{.{ .dont_load = .TEXTURE }} ** constants.MAX_NUM_PLAYERS;

                for (0..self.num_players) |i| {
                    if (self.player_playing[i]) {
                        modes[i] = .{ .character_wurmple = .STANDING };
                    }
                }

                break :assign_entity_modes modes;
            };

            self.prepare_for_match(current_stage, entity_modes);

            // Play Start Countdown Animation
            // TODO: implement

            // Zero player characters and actions
            for (0..self.num_players) |i| {
                self.player_characters[i] = CharacterState{};
                self.player_actions[i] = PlayerAction{};
            }

            // Start match
            match_loop: while (true) {
                self.timer.reset();
                defer self.wait_for_end_of_frame();

                self.input_handler.update_player_actions_inplace(&self.player_actions);

                switch (self.step(counter)) {
                    .NONE => {},
                    .PAUSE => counter += self.pause_menu_loop(counter),
                    .QUIT_MATCH => break :match_loop,
                    .RECONNECT => {},
                }

                counter += 1;

                // NOTE: if I want to have uncapped frame rate, I need to only
                // update counter based on a fixed frame-rate time, so animations
                // still play at the correct frame rate, and then I just need to
                // pass the actual time between frames to the physics functions.
            }
            counter += self.play_end_match_animation();
        }
    }

    fn wait_for_end_of_frame(self: *Game) void {
        while (self.timer.read() < constants.TIMESTEP_NS) {
            std.atomic.spinLoopHint(); // Do nothing.
        }
    }

    fn quit_game_hold_loop(self: *Game) bool {
        var local_counter: u32 = 0;

        while (self.player_actions[0].meta_action == .QUIT_MATCH) {
            self.timer.reset();
            defer self.wait_for_end_of_frame();

            self.input_handler.update_player_actions_inplace(&self.player_actions);

            if (local_counter >= constants.SECONDS_TO_HOLD_TO_QUIT_GAME * constants.FRAMERATE) {
                return true;
            }

            // TODO: implement
            self.renderer.draw_looping_animations(
                local_counter,
                &[_]VisualAssetID{VisualAssetID.UI_PAUSED_BACKGROUND},
                constants.ANIMATION_SLOWDOWN_FACTOR,
            ) catch unreachable;

            self.renderer.render();

            local_counter += 1;
        }

        return false;
    }

    // TODO: Implement. This one should switch between a few different end match animations depending on what happens.
    fn play_end_match_animation(self: *Game) u64 {
        const frames: u64 = @intFromFloat(0.1 * constants.FRAMERATE);

        for (0..frames) |_| {
            self.timer.reset();
            defer self.wait_for_end_of_frame();
            self.input_handler.update_player_actions_inplace(&self.player_actions);
        }

        return frames;
    }

    // TODO: Implement
    fn play_reconnection_animation(self: *Game) u64 {
        const frames: u64 = @intFromFloat(0.1 * constants.FRAMERATE);

        for (0..frames) |_| {
            self.timer.reset();
            defer self.wait_for_end_of_frame();
            self.input_handler.update_player_actions_inplace(&self.player_actions);
        }

        return frames;
    }

    // TODO: Implement
    fn play_pause_animation(self: *Game) u64 {
        const frames: u64 = @intFromFloat(1.0 * constants.FRAMERATE);

        for (0..frames) |_| {
            self.timer.reset();
            defer self.wait_for_end_of_frame();
            self.input_handler.update_player_actions_inplace(&self.player_actions);
        }

        return frames;
    }

    // TODO: Implement
    fn play_unpause_animation(self: *Game) u64 {
        const frames: u64 = @intFromFloat(1.0 * constants.FRAMERATE);

        for (0..frames) |_| {
            self.timer.reset();
            defer self.wait_for_end_of_frame();
            self.input_handler.update_player_actions_inplace(&self.player_actions);
        }

        return frames;
    }

    fn pause_menu_loop(self: *Game, counter: u64) u64 {
        var local_counter = counter;

        local_counter += self.play_pause_animation();

        while (true) {
            self.timer.reset();
            defer self.wait_for_end_of_frame();

            self.input_handler.update_player_actions_inplace(&self.player_actions);

            if (self.player_actions[0].meta_action == .PAUSE) {
                break;
            }

            // TODO: implement
            self.renderer.draw_looping_animations(
                local_counter,
                &[_]VisualAssetID{VisualAssetID.UI_PAUSED_BACKGROUND},
                constants.ANIMATION_SLOWDOWN_FACTOR,
            ) catch unreachable;

            self.renderer.render();

            local_counter += 1;
        }

        local_counter += self.play_unpause_animation();

        return local_counter;
    }

    fn draw_stage_select_animation(self: *Game, counter: u64, current_stage: stages.StageID) void {
        self.renderer.draw_looping_animations_at(
            counter,
            &[_]VisualAssetID{stages.stageThumbnailID(current_stage)},
            &.{constants.X_RESOLUTION / 2 - constants.STAGE_THUMBNAIL_WIDTH / 2},
            &.{constants.Y_RESOLUTION / 2 - constants.STAGE_THUMBNAIL_HEIGHT / 2},
            constants.ANIMATION_SLOWDOWN_FACTOR,
        ) catch unreachable;

        self.renderer.draw_looping_animations(
            counter,
            &[_]VisualAssetID{VisualAssetID.MENU_WAITING_FORINPUT},
            constants.ANIMATION_SLOWDOWN_FACTOR,
        ) catch unreachable;
    }

    fn play_stage_switch_animation(
        self: *Game,
        direction: HorizontalDirection,
        from_stage: stages.StageID,
        to_stage: stages.StageID,
        global_counter: u64,
        frame_interval_ns: u64,
    ) u64 {
        const x_final_position: i32 = constants.X_RESOLUTION / 2 - constants.STAGE_THUMBNAIL_WIDTH / 2;
        const y_final_position: i32 = constants.Y_RESOLUTION / 2 - constants.STAGE_THUMBNAIL_HEIGHT / 2;

        for (0..constants.STAGE_SWITCH_ANIMATION_NUM_FRAMES) |local_counter| {
            self.timer.reset();

            const fraction_complete = utils.divAsFloat(f32, local_counter, constants.STAGE_SWITCH_ANIMATION_NUM_FRAMES);

            self.renderer.draw_looping_animations_at(
                global_counter + local_counter,
                &[_]VisualAssetID{stages.stageThumbnailID(from_stage)}, // TODO: Could be a good idea to have a blurred version of the thumbnail here.
                &.{x_final_position + @as(i32, @intFromFloat(utils.mulFloatInt(f32, fraction_complete, direction.int() * constants.STAGE_THUMBNAIL_WIDTH)))},
                &.{y_final_position},
                constants.ANIMATION_SLOWDOWN_FACTOR,
            ) catch unreachable;

            self.renderer.draw_looping_animations_at(
                global_counter + local_counter,
                &[_]VisualAssetID{stages.stageThumbnailID(to_stage)}, // TODO: Could be a good iea to have a blurred version of the thumbnail here.
                &.{x_final_position - direction.int() * constants.STAGE_THUMBNAIL_WIDTH + @as(i32, @intFromFloat(utils.mulFloatInt(f32, fraction_complete, direction.int() * constants.STAGE_THUMBNAIL_WIDTH)))},
                &.{y_final_position},
                constants.ANIMATION_SLOWDOWN_FACTOR,
            ) catch unreachable;

            self.renderer.draw_looping_animations(
                global_counter + local_counter,
                &[_]VisualAssetID{VisualAssetID.MENU_WAITING_FORINPUT},
                constants.ANIMATION_SLOWDOWN_FACTOR,
            ) catch unreachable;

            self.renderer.render();

            while (self.timer.read() < frame_interval_ns) {
                std.atomic.spinLoopHint(); // Do nothing.
            }
        }

        return constants.STAGE_SWITCH_ANIMATION_NUM_FRAMES;
    }

    fn play_stage_selected_animation(
        self: *Game,
        selected_stage: stages.StageID,
        global_counter: u64,
        frame_interval_ns: u64,
    ) u64 {
        const FRAME_TO_SHOW_STAGE = 7;
        const stage_assets = stages.stageAssets(selected_stage);
        const num_animation_frames = ASSETS_PER_ID[VisualAssetID.MENU_STAGE_SELECTED.int()];

        for (0..num_animation_frames) |local_counter| {
            self.timer.reset();

            if (local_counter >= FRAME_TO_SHOW_STAGE) {
                self.renderer.draw_looping_animations(global_counter + local_counter, stage_assets.background, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
                self.renderer.draw_looping_animations(global_counter + local_counter, stage_assets.foreground, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
            }
            self.renderer.draw_animation_frame(local_counter, VisualAssetID.MENU_STAGE_SELECTED) catch unreachable;
            self.renderer.render();

            while (self.timer.read() < frame_interval_ns) {
                std.atomic.spinLoopHint(); // Do nothing.
            }
        }

        return num_animation_frames;
    }

    // TODO: move this elsewhere later.
    fn ui_assets_from_player_states(
        player_states: [constants.MAX_NUM_PLAYERS]CharacterState,
    ) [constants.MAX_NUM_PLAYERS * constants.UI_ASSETS_PER_PLAYER + constants.MAX_NUM_PLAYERS]VisualAssetID {
        const UI_HEALTH_ASSET_IDS: [constants.MAX_HEALTH_POINTS + 1]VisualAssetID = comptime .{
            VisualAssetID.UI_HEALTH_EQUALS0,
            VisualAssetID.UI_HEALTH_EQUALS1,
            VisualAssetID.UI_HEALTH_EQUALS2,
            VisualAssetID.UI_HEALTH_EQUALS3,
            VisualAssetID.UI_HEALTH_EQUALS4,
            VisualAssetID.UI_HEALTH_EQUALS5,
            VisualAssetID.UI_HEALTH_EQUALS6,
            VisualAssetID.UI_HEALTH_EQUALS7,
            VisualAssetID.UI_HEALTH_EQUALS8,
            VisualAssetID.UI_HEALTH_EQUALS9,
            VisualAssetID.UI_HEALTH_EQUALS10,
            VisualAssetID.UI_HEALTH_EQUALS11,
            VisualAssetID.UI_HEALTH_EQUALS12,
            VisualAssetID.UI_HEALTH_EQUALS13,
            VisualAssetID.UI_HEALTH_EQUALS14,
            VisualAssetID.UI_HEALTH_EQUALS15,
        };

        const UI_AMMO_ASSET_IDS: [constants.MAX_AMMO_COUNT + 1]VisualAssetID = comptime .{
            VisualAssetID.UI_AMMO_EQUALS0,
            VisualAssetID.UI_AMMO_EQUALS1,
            VisualAssetID.UI_AMMO_EQUALS2,
            VisualAssetID.UI_AMMO_EQUALS3,
            VisualAssetID.UI_AMMO_EQUALS4,
            VisualAssetID.UI_AMMO_EQUALS5,
            VisualAssetID.UI_AMMO_EQUALS6,
            VisualAssetID.UI_AMMO_EQUALS7,
        };

        return .{
            UI_HEALTH_ASSET_IDS[player_states[0].resources.health_points],
            UI_HEALTH_ASSET_IDS[player_states[1].resources.health_points],
            UI_HEALTH_ASSET_IDS[player_states[2].resources.health_points],
            UI_HEALTH_ASSET_IDS[player_states[3].resources.health_points],
            UI_AMMO_ASSET_IDS[player_states[0].resources.ammo_count],
            UI_AMMO_ASSET_IDS[player_states[1].resources.ammo_count],
            UI_AMMO_ASSET_IDS[player_states[2].resources.ammo_count],
            UI_AMMO_ASSET_IDS[player_states[3].resources.ammo_count],
            // TODO: Add player UI frames.
            // VisualAssetID.UI_FRAME_PLAYER1,
            // VisualAssetID.UI_FRAME_PLAYER2,
            // VisualAssetID.UI_FRAME_PLAYER3,
            // VisualAssetID.UI_FRAME_PLAYER4,
            VisualAssetID.DONT_LOAD_TEXTURE,
            VisualAssetID.DONT_LOAD_TEXTURE,
            VisualAssetID.DONT_LOAD_TEXTURE,
            VisualAssetID.DONT_LOAD_TEXTURE,
        };
    }

    const MetaAction = enum(u3) {
        NONE,
        PAUSE,
        QUIT_MATCH,
        RECONNECT,
    };

    fn step(self: *Game, counter: u64) MetaAction {
        var meta_action = Game.MetaAction.NONE;

        for (0..self.num_players) |player| {
            if (self.player_actions[player].meta_action != .NONE) {
                meta_action = self.player_actions[player].meta_action;
            }

            if (!self.player_playing[player]) {
                continue;
            }

            const entity_mode, const movement, const counter_correction, const character_created_entity = handle_character_action(
                &self.player_characters[player],
                self.dynamic_entities.modes[player],
                self.sim_state.floor_collision[player],
                self.sim_state.physics_state.dX[player],
                self.sim_state.physics_state.dY[player],
                self.player_actions[player],
                counter,
            );

            if (counter_correction.update) {
                self.dynamic_entities.counter_corrections[player] = counter_correction.frames;
            }

            self.dynamic_entities.modes[player] = entity_mode;

            self.sim_state.physics_state.dY[player] = movement.vertical_velocity;
            self.sim_state.physics_state.dX[player] = movement.horizontal_velocity;
            self.sim_state.physics_state.ddX[player] += movement.horizontal_acceleration;

            inline for (0..7) |local_index| {
                const player_bullet_begin: usize = constants.MAX_NUM_PLAYERS + player * 7;
                const character_created_entity_index = player_bullet_begin + local_index;

                if (self.sim_state.floor_collision[character_created_entity_index]) {
                    // TODO: Can set to ground state here, and let persist for a little while/animate disappearance.
                    self.dynamic_entities.active[character_created_entity_index] = 0.0;
                    self.dynamic_entities.modes[character_created_entity_index] = EntityMode.from_enum_literal(DontLoadMode, .TEXTURE);
                    self.dynamic_entities.damage_on_hit[character_created_entity_index] = 0.0;
                }
            }

            switch (character_created_entity.entity_mode) {
                inline .dont_load => {},
                inline .projectile_test => {
                    // TODO: Update vector to track projectile modes.

                    const character_created_entity_index: usize = constants.MAX_NUM_PLAYERS + player * 7 + self.player_characters[player].resources.ammo_count;
                    self.dynamic_entities.active[character_created_entity_index] = 1.0;
                    self.dynamic_entities.modes[character_created_entity_index] = character_created_entity.entity_mode;
                    self.dynamic_entities.damage_on_hit[character_created_entity_index] = 1.0;

                    // TODO: Temporary until dynamic entity hitboxes are reworked.
                    self.sim_state.physics_state.W[character_created_entity_index] = 0.15;
                    self.sim_state.physics_state.H[character_created_entity_index] = 0.15;

                    self.sim_state.physics_state.X[character_created_entity_index] = self.sim_state.physics_state.X[player];
                    self.sim_state.physics_state.Y[character_created_entity_index] = self.sim_state.physics_state.Y[player];
                    self.sim_state.physics_state.dX[character_created_entity_index] = character_created_entity.horizontal_velocity;
                    self.sim_state.physics_state.dY[character_created_entity_index] = character_created_entity.vertical_velocity;
                },
                else => {
                    std.debug.print("wtf: {any}", .{character_created_entity.entity_mode});
                    unreachable;
                },
            }

            // TODO: Temporary inline implementation for testing.
            for (0..player) |other_player| {
                const other_player_bullet_begin: usize = constants.MAX_NUM_PLAYERS + other_player * 7;

                const too_close, const damage_vector = temp: {
                    var too_close_x: @Vector(7, bool) = undefined;
                    var too_close_y: @Vector(7, bool) = undefined;
                    var damage_vector: @Vector(7, f32) = undefined;

                    inline for (0..7) |local_index| {
                        const distance_x: f32 = @abs(self.sim_state.physics_state.X[other_player_bullet_begin + local_index] - self.sim_state.physics_state.X[player]);
                        const distance_y: f32 = @abs(self.sim_state.physics_state.Y[other_player_bullet_begin + local_index] - self.sim_state.physics_state.Y[player]);

                        too_close_x[local_index] = distance_x < self.sim_state.physics_state.W[player] / 2.0;
                        too_close_y[local_index] = distance_y < self.sim_state.physics_state.H[player] / 2.0;
                        damage_vector[local_index] = self.dynamic_entities.damage_on_hit[other_player_bullet_begin + local_index];
                        self.dynamic_entities.active[other_player_bullet_begin + local_index] = 0.0;
                        self.dynamic_entities.modes[other_player_bullet_begin + local_index] = EntityMode.from_enum_literal(DontLoadMode, .TEXTURE);
                        self.dynamic_entities.damage_on_hit[other_player_bullet_begin + local_index] = 0.0;
                    }
                    break :temp .{ @select(bool, too_close_x, too_close_y, too_close_x), damage_vector };
                };

                const ZERO: @Vector(7, f32) = comptime @splat(0.0);
                const damage = @reduce(.Add, @select(f32, too_close, damage_vector, ZERO));

                self.player_characters[player].resources.health_points -|= @intFromFloat(damage);
                // TODO: Transition to hitstun state.
            }

            // TODO: Temporary inline implementation for testing.
            for (player + 1..self.num_players) |other_player| {
                if (!self.player_playing[other_player]) {
                    continue;
                }

                const other_player_bullet_begin: usize = constants.MAX_NUM_PLAYERS + other_player * 7;

                const too_close, const damage_vector = temp: {
                    var too_close_x: @Vector(7, bool) = undefined;
                    var too_close_y: @Vector(7, bool) = undefined;
                    var damage_vector: @Vector(7, f32) = undefined;

                    inline for (0..7) |local_index| {
                        const distance_x: f32 = @abs(self.sim_state.physics_state.X[other_player_bullet_begin + local_index] - self.sim_state.physics_state.X[player]);
                        const distance_y: f32 = @abs(self.sim_state.physics_state.Y[other_player_bullet_begin + local_index] - self.sim_state.physics_state.Y[player]);

                        too_close_x[local_index] = distance_x < self.sim_state.physics_state.W[player] / 2.0;
                        too_close_y[local_index] = distance_y < self.sim_state.physics_state.H[player] / 2.0;
                        damage_vector[local_index] = self.dynamic_entities.damage_on_hit[other_player_bullet_begin + local_index];
                        self.dynamic_entities.active[other_player_bullet_begin + local_index] = 0.0;
                        self.dynamic_entities.modes[other_player_bullet_begin + local_index] = EntityMode.from_enum_literal(DontLoadMode, .TEXTURE);
                        self.dynamic_entities.damage_on_hit[other_player_bullet_begin + local_index] = 0.0;
                    }
                    break :temp .{ @select(bool, too_close_x, too_close_y, too_close_x), damage_vector };
                };

                const ZERO: @Vector(7, f32) = comptime @splat(0.0);
                const damage = @reduce(.Add, @select(f32, too_close, damage_vector, ZERO));

                self.player_characters[player].resources.health_points -|= @intFromFloat(damage);
                // TODO: Transition to hitstun state.
            }
        }

        self.sim_state.newtonianMotion(constants.TIMESTEP_S);
        // TODO: Rename function to indicate that it resolves collisions between dynamic and static entities.
        // It does not resolve collisions between dynamic entities.
        self.sim_state.resolveCollisions(self.stage_assets.geometry);
        self.sim_state.gamePhysics(self.dynamic_entities.active);

        self.dynamic_entities.updatePosition(self.sim_state.physics_state.X, self.sim_state.physics_state.Y);

        self.renderer.draw_looping_animations(counter, self.stage_assets.background, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
        self.renderer.draw_dynamic_entities(counter, self.dynamic_entities, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;
        self.renderer.draw_looping_animations(counter, self.stage_assets.foreground, constants.ANIMATION_SLOWDOWN_FACTOR) catch unreachable;

        // TODO: WIP
        self.renderer.draw_looping_animations_at(
            counter,
            &ui_assets_from_player_states(self.player_characters),
            // Just use some hardcoded pixel values for SDL_Rect for now
            &.{ 0, 400, 800, 1200, 0, 400, 800, 1200, 0, 0, 0, 0 },
            &.{ 500, 500, 500, 500, 620, 620, 620, 620, 0, 0, 0, 0 },
            constants.ANIMATION_SLOWDOWN_FACTOR,
        ) catch unreachable;

        self.renderer.render();

        return meta_action;
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

    fn handle_character_action(
        current_character_state: *CharacterState,
        current_entity_mode: EntityMode,
        floor_collision: bool,
        horizontal_velocity: float,
        vertical_velocity: float,
        action: PlayerAction,
        global_counter: u64,
    ) struct { EntityMode, CharacterMovement, AnimationCounterCorrection, CharacterCreatedEntity } {
        current_character_state.resources.has_jump = floor_collision or current_character_state.resources.has_jump;

        switch (current_entity_mode) {
            inline .dont_load => return .{ current_entity_mode, .{}, .{}, .{} },
            inline .character_wurmple,
            .character_test,
            => |character| {
                return base_character_state_transition(
                    @TypeOf(character),
                    current_character_state,
                    floor_collision,
                    horizontal_velocity,
                    vertical_velocity,
                    action,
                    global_counter,
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

pub const PlayerAction = packed struct {
    meta_action: Game.MetaAction = .NONE,
    parry: bool = false,
    jump: bool = false,
    x_dir: HorizontalDirection = .NONE,
    attack_dir: PlaneAxialDirection = .NONE,
};

comptime { // Stay conscious of size of PlayerAction.
    std.debug.assert(@bitSizeOf(PlayerAction) == 10);
    std.debug.assert(@sizeOf(PlayerAction) == 2);
}

// InputHandling is going to be specific to my controllers for now.
pub const InputHandler = struct {
    const vendor_id: c_ushort = 0x081F;
    const product_id: c_ushort = 0xE401;
    const max_num_devices = 4;
    const report_num_bytes = 8; // + 1 if numbered report
    const report_read_time_ms = 100;

    const UsbGamepadReport = packed struct(u64) {
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

        fn to_horizontal_direction(self: UsbGamepadReport) HorizontalDirection {
            return if (self.x_axis == 0) .LEFT else if (self.x_axis == 255) .RIGHT else .NONE;
        }

        fn to_attack_direction(self: UsbGamepadReport) PlaneAxialDirection {
            return ( //
                if (@bitCast(self.X)) .UP //
                else if (@bitCast(self.A)) .RIGHT //
                else if (@bitCast(self.B)) .DOWN //
                else if (@bitCast(self.Y)) .LEFT //
                else .NONE //
            );
        }

        fn to_meta_action(self: UsbGamepadReport) Game.MetaAction {
            return ( //
                if (@bitCast(self.start) and @bitCast(self.select) and @bitCast(self.L) and @bitCast(self.R)) .QUIT_MATCH //
                else if (@bitCast(self.start) and !(@bitCast(self.select) or @bitCast(self.L) or @bitCast(self.R))) .PAUSE //
                else if (@bitCast(self.select) and !(@bitCast(self.start) or @bitCast(self.L) or @bitCast(self.R))) .RECONNECT //
                else .NONE //
            );
        }

        fn to_action(gamepad_report: UsbGamepadReport) PlayerAction {
            return PlayerAction{
                .x_dir = gamepad_report.to_horizontal_direction(),
                .parry = @bitCast(gamepad_report.L),
                .jump = @bitCast(gamepad_report.R),
                .attack_dir = gamepad_report.to_attack_direction(),
                .meta_action = gamepad_report.to_meta_action(),
            };
        }
    }; // 64 bits

    comptime {
        std.debug.assert(@sizeOf(UsbGamepadReport) == report_num_bytes);
    }

    report_data: [max_num_devices][report_num_bytes]u8 = undefined,
    devices: [max_num_devices]*hidapi.hid_device = undefined,
    reports: [max_num_devices]*UsbGamepadReport = undefined, // Points to report_data.
    num_devices: u8 = undefined,

    fn init(self: *InputHandler) *InputHandler {
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
            utils.assert(
                hidapi.hid_read(self.devices[i], &self.report_data[i], report_num_bytes) != -1,
                "Could not hid_read() device during initialization()",
            );

            self.reports[i] = @ptrCast(@alignCast(&self.report_data[i]));
        }

        return self;
    }

    fn deinit(self: *InputHandler) void {
        for (0..self.num_devices) |idx| {
            hidapi.hid_close(self.devices[idx]);
        }
        _ = hidapi.hid_exit();
    }

    // Called in a dedicated reading thread.
    fn read_input(self: *InputHandler) void {
        for (0..self.num_devices) |i| {
            var single_report_data: [report_num_bytes]u8 = undefined;

            utils.assert(hidapi.hid_read_timeout(
                self.devices[i],
                &single_report_data,
                report_num_bytes,
                report_read_time_ms,
            ) != -1, "hid_read() failed.");

            @atomicStore(
                UsbGamepadReport,
                self.reports[i],
                @bitCast(single_report_data),
                .unordered,
            );
        }
    }

    // Called from anywhere.
    fn update_player_actions_inplace(
        self: *InputHandler,
        player_actions: []PlayerAction,
    ) void {
        for (0..self.num_devices) |i| {
            const report = @atomicLoad(
                UsbGamepadReport,
                self.reports[i],
                .unordered,
            );

            player_actions[i] = report.to_action();
        }
    }
};
