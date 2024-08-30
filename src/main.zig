const std = @import("std");
const utils = @import("utils.zig");
const game = @import("game.zig");

pub fn main() !void {
    const num_players = 2;

    var input_handler = game.InputHandler{};
    var battlebuds = game.Game.init(num_players, &input_handler);
    // battlebuds.init(num_players);
    battlebuds.run();
}
