/// Gameplay logic
const std = @import("std");
const utils = @import("utils.zig");
const hidapi = @cImport(@cInclude("hidapi.h"));
const stages = @import("stages.zig");

const SDL_PollEvent = @import("sdl2").SDL_PollEvent;
const SDL_Event = @import("sdl2").SDL_Event;
const SDL_QUIT = @import("sdl2").SDL_QUIT;
const SDL_KEYDOWN = @import("sdl2").SDL_KEYDOWN;
const SDL_KeyboardEvent = @import("sdl2").SDL_KeyboardEvent;
const SDLK_q = @import("sdl2").SDLK_q;
const SDL_Renderer = @import("sdl2").SDL_Renderer;
const SDL_Window = @import("sdl2").SDL_Window;

pub const Renderer = @import("render.zig").Renderer;
pub const pixels_per_meter = @import("render.zig").pixels_per_meter;
pub const Entities = @import("render.zig").Entities;
pub const SimulatorState = @import("physics.zig").SimulatorState;

const vec_length = @import("physics.zig").vec_length;
const Vec = @import("physics.zig").Vec;
const float = @import("physics.zig").float;

pub const max_num_players = 4;

const timestep_s: float = 1.0 / 60.0;
const timestep_ns: u64 = 1.667e+7;

pub const Game = struct {
    player_actions: [max_num_players]InputHandler.PlayerAction = undefined,
    input_handler: *InputHandler,
    renderer: *Renderer,
    entities: *Entities,
    sim_state: *SimulatorState,
    stage_assets: stages.StageAssets,
    timer: std.time.Timer,
    num_players: u8,

    pub fn init(
        comptime num_players: u8,
        input_handler: *InputHandler,
        renderer: *Renderer,
        entities: *Entities,
        sim_state: *SimulatorState,
    ) Game {
        // Random starting locations
        var indices = comptime utils.range(u8, 0, num_players);
        const seed = @as(u64, @intCast(std.time.microTimestamp()));
        var prng = std.Random.DefaultPrng.init(seed);
        prng.random().shuffle(u8, &indices);

        return Game{
            .input_handler = input_handler.init(num_players),
            .renderer = renderer.init(),
            .entities = entities.init(num_players, &stages.s0, indices),
            .sim_state = sim_state.init(num_players, &stages.s0, indices),
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
        var stop = false;

        // TODO: make outer loop with stage selection;
        // self.stage_assets = stages.stageAssets(0);

        // Zero player actions
        for (0..self.num_players) |i| {
            self.player_actions[i] = InputHandler.PlayerAction{};
        }

        // Start match
        while (!stop) {
            self.timer.reset();
            stop = self.step();

            // Always read player inputs
            var atleast_once = true;
            while (self.timer.read() < timestep_ns or atleast_once) {
                atleast_once = false;
                const reports = self.input_handler.read_input();
                for (reports, 0..self.num_players) |report, i| {
                    self.player_actions[i] = InputHandler.action(report);
                }
            }
        }
    }

    fn step(self: *Game) bool {
        const stop = handle_sdl_events();

        // PLAYER INPUT
        const jump_velocity: float = 9.9;
        const move_acceleration: float = 129.9;
        const move_velocity: float = 5.9;
        for (0..self.num_players) |player| {

            // TODO: only allow jumping again after having made contact with surface

            const jump: float = if (self.player_actions[player].jump) jump_velocity else self.sim_state.physics_state.dY[player];
            const move_vel: float, const move_acc: float = switch (self.player_actions[player].x_dir) {
                .RIGHT => .{ move_velocity, move_acceleration },
                .LEFT => .{ -move_velocity, -move_acceleration },
                .NONE => .{ self.sim_state.physics_state.dX[player], 0 },
            };
            self.sim_state.physics_state.dY[player] = jump;
            self.sim_state.physics_state.dX[player] = move_vel;
            self.sim_state.physics_state.ddX[player] += move_acc;
        }

        // self.sim_state.physics_state = SimulatorState.newtonianMotion(timestep_s, self.sim_state.physics_state);
        self.sim_state.newtonianMotion(timestep_s);
        self.sim_state.resolveCollisions(self.stage_assets.geometry);
        self.sim_state.gamePhysics();

        self.entities.updateDynamicEntities(self.sim_state.physics_state.X, self.sim_state.physics_state.Y);

        self.renderer.draw(self.stage_assets.background) catch unreachable;
        self.renderer.drawEntitites(self.entities) catch unreachable;
        self.renderer.draw(self.stage_assets.foreground) catch unreachable;
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

    fn init(self: *InputHandler, comptime num_players: u8) *InputHandler {
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
