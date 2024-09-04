const std = @import("std");
const utils = @import("utils.zig");
const game = @import("game.zig");

pub fn main() !void {
    const num_players = 2;
    var input_handler = game.InputHandler{};
    var renderer = game.Renderer{};
    var entities = game.Entities{};
    var sim_state = game.SimulatorState{};

    var battlebuds = game.Game.init(
        num_players,
        &input_handler,
        &renderer,
        &entities,
        &sim_state,
    );

    defer battlebuds.deinit();

    battlebuds.run();
}
