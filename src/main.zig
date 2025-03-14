/// Entrypoint
const game = @import("game.zig");

// const std = @import("std");
// const utils = @import("utils.zig");

var input_handler = game.InputHandler{};
var renderer = game.Renderer{};
var audio_player = game.AudioPlayer{};
var dynamic_entities = game.DynamicEntities{};
var sim_state = game.SimulatorState{};

pub fn main() !void {
    var battlebuds = game.Game.init(
        &input_handler,
        &renderer,
        &audio_player,
        &dynamic_entities,
        &sim_state,
    );
    defer battlebuds.deinit();

    battlebuds.run();
}
