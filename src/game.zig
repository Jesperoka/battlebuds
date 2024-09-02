/// Gameplay logic
const std = @import("std");
const utils = @import("utils.zig");
pub const Renderer = @import("render.zig").Renderer;
const SimulatorState = @import("physics.zig").SimulatorState;
const hidapi = @cImport(@cInclude("hidapi.h"));

const SDL_PollEvent = @import("sdl2").SDL_PollEvent;
const SDL_Event = @import("sdl2").SDL_Event;
const SDL_QUIT = @import("sdl2").SDL_QUIT;
const SDL_KEYDOWN = @import("sdl2").SDL_KEYDOWN;
const SDL_KeyboardEvent = @import("sdl2").SDL_KeyboardEvent;
const SDLK_q = @import("sdl2").SDLK_q;
const SDL_Renderer = @import("sdl2").SDL_Renderer;
const SDL_Window = @import("sdl2").SDL_Window;

pub const Game = struct {
    const max_num_players = 4;

    player_actions: [max_num_players]InputHandler.PlayerAction = undefined,
    input_handler: *InputHandler,
    renderer: *Renderer,
    sim_state: SimulatorState,
    timer: std.time.Timer,
    num_players: u8,

    pub fn init(
        comptime num_players: u8,
        input_handler: *InputHandler,
        renderer: *Renderer,
    ) Game {
        return Game{
            .input_handler = input_handler.init(num_players),
            .renderer = renderer.init(),
            .sim_state = SimulatorState{ .num_characters = num_players },
            .timer = std.time.Timer.start() catch unreachable,
            .num_players = num_players,
        };
    }
    pub fn deinit() void {}

    pub fn run(self: *Game) void {
        defer deinit();

        var stop = false;
        while (!stop) {
            stop = self.step();
        }
    }

    fn step(self: *Game) bool {
        const reports = self.input_handler.read_input();
        for (reports, 0..self.num_players) |report, i| {
            self.player_actions[i] = InputHandler.action(report);
        }
        const stop = handle_sdl_events();

        // simulate

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
