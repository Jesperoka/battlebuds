/// Some 2D rigid-body physics.
const std = @import("std");
const utils = @import("utils.zig");
const stages = @import("stages.zig");
const ppm = @import("render.zig").pixels_per_meter;

const time = std.time;

// time.Timer
pub const float = f32;
pub const vec_length = 32;
pub const inf = std.math.inf(float);

pub const Vec = @Vector(vec_length, float);
pub const VecU16 = @Vector(vec_length, u16);
pub const VecBool = @Vector(vec_length, bool);

pub const Zero: Vec = @splat(0);
pub const One: Vec = @splat(1);
pub const Two: Vec = @splat(2);
pub const True: VecBool = @splat(true);
pub const False: VecBool = @splat(false);
pub const IntZero: VecU16 = @splat(0);

fn vecOr(a: VecBool, b: VecBool) VecBool { // https://github.com/ziglang/zig/issues/14306
    return @select(bool, a, a, b);
}
fn vecAnd(a: VecBool, b: VecBool) VecBool { // https://github.com/ziglang/zig/issues/14306
    return @select(bool, a, b, a);
}
fn vecNot(a: VecBool) VecBool {
    return a != True;
}
fn vecFloatFromBool(a: VecBool) Vec {
    return @floatFromInt(@intFromBool(a));
}
fn vecDot(X0: Vec, Y0: Vec, X1: Vec, Y1: Vec) Vec {
    return X0 * X1 + Y0 * Y1;
}
fn vecDotSelf(X: Vec, Y: Vec) Vec {
    return X * X + Y * Y;
}
fn vecLeftOrth(X: Vec, Y: Vec) struct { Vec, Vec } {
    return .{ -Y, X };
}
fn vecRightOrth(X: Vec, Y: Vec) struct { Vec, Vec } {
    return .{ Y, -X };
}

const PhysicsState = struct {
    X: Vec = @splat(0),
    Y: Vec = @splat(0),
    dX: Vec = @splat(0),
    dY: Vec = @splat(0),
    ddX: Vec = @splat(0), // Not used in arithmetic functions below
    ddY: Vec = @splat(0), // Not used in arithmetic functions below

    W: Vec = @splat(50 / ppm), // Not used in arithmetic functions below
    H: Vec = @splat(50 / ppm), // Not used in arithmetic functions below

    fn minus(this: PhysicsState, that: PhysicsState) PhysicsState {
        return .{
            this.X - that.X,
            this.Y - that.Y,
            this.dX - that.dX,
            this.dY - that.dY,
        };
    }
    fn div(this: PhysicsState, that: PhysicsState) PhysicsState {
        return .{
            this.X / that.X,
            this.Y / that.Y,
            this.dX / that.dX,
            this.dY / that.dY,
        };
    }
    fn times_f32(this: PhysicsState, that: f32) PhysicsState {
        const that_vec: Vec = @splat(that);

        return .{
            this.X * that_vec,
            this.Y * that_vec,
            this.dX * that_vec,
            this.dY * that_vec,
        };
    }
    fn one_minus(this: PhysicsState) PhysicsState {
        const one: Vec = @splat(1);

        return .{
            one - this.X,
            one - this.Y,
            one - this.dX,
            one - this.dY,
        };
    }
    fn infnorm(this: PhysicsState) f32 {
        const maxes = @max(@max(@max(this.X, this.Y), this.dX), this.dY);

        return @reduce(.Max, maxes);
    }
};

pub const SimulatorState = struct {
    const newton_max_iters: u16 = 10;
    const newton_epsilon: f32 = 10e-6;

    physics_state: PhysicsState = .{},
    colliding: Vec = Zero,
    X_push: Vec = Zero,
    Y_push: Vec = Zero,

    pub fn init(
        self: *SimulatorState,
        comptime num_players: u8,
        stage: *const @TypeOf(stages.s0),
        shuffled_indices: [num_players]u8,
    ) *SimulatorState {
        for (shuffled_indices, 0..num_players) |idx, i| {
            self.physics_state.X[i] = @as(float, @floatCast(stage.starting_positions[idx].x));
            self.physics_state.Y[i] = @as(float, @floatCast(stage.starting_positions[idx].y));
        }

        return self;
    }

    fn posVelAccTimeRelation(dt: float, p0: Vec, v0: Vec, a: Vec) Vec {
        const delta_t: Vec = @splat(dt);
        const delta_t_squared: Vec = @splat(dt * dt); // is this better?
        const one_half: Vec = @splat(0.5);

        return p0 + v0 * delta_t + one_half * a * delta_t_squared;
    }

    fn velAccTimeRelation(dt: float, v0: Vec, a: Vec) Vec {
        const delta_t: Vec = @splat(dt);

        return v0 + a * delta_t;
    }

    pub fn newtonianMotion(self: *SimulatorState, dt: float) void {
        self.physics_state.X = posVelAccTimeRelation(dt, self.physics_state.X, self.physics_state.dX, self.physics_state.ddX);
        self.physics_state.Y = posVelAccTimeRelation(dt, self.physics_state.Y, self.physics_state.dY, self.physics_state.ddY);
        self.physics_state.dX = velAccTimeRelation(dt, self.physics_state.dX, self.physics_state.ddX);
        self.physics_state.dY = velAccTimeRelation(dt, self.physics_state.dY, self.physics_state.ddY);
    }

    fn edges(X: Vec, Y: Vec, W: Vec, H: Vec) struct { [4]Vec, [4]Vec } {
        // 3----2
        // |    |
        // 0----1

        const X0 = X - (W / Two);
        const X1 = X + (W / Two);
        const X2 = X + (W / Two);
        const X3 = X - (W / Two);

        const Y0 = Y - (H / Two);
        const Y1 = Y - (H / Two);
        const Y2 = Y + (H / Two);
        const Y3 = Y + (H / Two);

        return .{
            .{ X1 - X0, X2 - X1, X3 - X2, X0 - X3 },
            .{ Y1 - Y0, Y2 - Y1, Y3 - Y2, Y0 - Y3 },
        };
    }

    fn corners(X: Vec, Y: Vec, W: Vec, H: Vec) struct { [4]Vec, [4]Vec } {
        // 3----2
        // |    |
        // 0----1

        const X0 = X - (W / Two);
        const X1 = X + (W / Two);
        const X2 = X + (W / Two);
        const X3 = X - (W / Two);

        const Y0 = Y - (H / Two);
        const Y1 = Y - (H / Two);
        const Y2 = Y + (H / Two);
        const Y3 = Y + (H / Two);

        return .{
            .{ X0, X1, X2, X3 },
            .{ Y0, Y1, Y2, Y3 },
        };
    }

    fn separatingAxis(
        X_orths: []const Vec,
        Y_orths: []const Vec,
        X_verts_0: []const Vec,
        Y_verts_0: []const Vec,
        X_verts_1: []const Vec,
        Y_verts_1: []const Vec,
    ) struct { VecU16, Vec, Vec } {
        var X_push: Vec = @splat(inf);
        var Y_push: Vec = @splat(inf);
        var separated = False;

        for (X_orths, Y_orths) |X_orth, Y_orth| {
            var min0: Vec = @splat(inf);
            var min1: Vec = @splat(inf);
            var max0: Vec = @splat(-inf);
            var max1: Vec = @splat(-inf);

            for (X_verts_0, Y_verts_0) |X, Y| {
                const P = vecDot(X, Y, X_orth, Y_orth);
                min0 = @min(min0, P);
                max0 = @max(max0, P);
            }
            for (X_verts_1, Y_verts_1) |X, Y| {
                const P = vecDot(X, Y, X_orth, Y_orth);
                min1 = @min(min1, P);
                max1 = @max(max1, P);
            }
            const eps: Vec = @splat(1.0 / ppm);
            const D_min_proj = @min(max1 - min0, max0 - min1);
            const O_squared = vecDotSelf(X_orth, Y_orth);

            const overlapping = vecAnd(max0 >= min1, max1 >= min0);

            separated = vecOr(separated, vecNot(overlapping));

            const D_min_proj_scaled = @select(
                float,
                overlapping,
                (D_min_proj / O_squared) + eps,
                Zero,
            );

            const X_new_push = D_min_proj_scaled * X_orth;
            const Y_new_push = D_min_proj_scaled * Y_orth;

            const L2_push = vecDotSelf(X_push, Y_push);
            const L2_new_push = vecDotSelf(X_new_push, Y_new_push);

            const new_push = vecAnd(L2_new_push < L2_push, overlapping);

            X_push = @select(float, new_push, X_new_push, X_push);
            Y_push = @select(float, new_push, Y_new_push, Y_push);
        }
        const mask = vecFloatFromBool(vecNot(separated));
        X_push = mask * X_push;
        Y_push = mask * Y_push;

        return .{ @intFromBool(vecNot(separated)), X_push, Y_push };
    }

    pub fn resolveCollisions(self: *SimulatorState, geoms: []const stages.Shape) void {
        const X_edges_dynamic, const Y_edges_dynamic = edges(
            self.physics_state.X,
            self.physics_state.Y,
            self.physics_state.W,
            self.physics_state.H,
        );
        const X_corners_dynamic, const Y_corners_dynamic = corners(
            self.physics_state.X,
            self.physics_state.Y,
            self.physics_state.W,
            self.physics_state.H,
        );
        const hitbox_len = X_edges_dynamic.len;

        var colliding: VecU16 = IntZero;
        var X_minimal_push: Vec = Zero;
        var Y_minimal_push: Vec = Zero;

        for (geoms) |geom| {
            switch (geom) {
                inline .triangle, .quad => |shape| {
                    const x_edges, const y_edges = shape.edges();
                    const x_verts, const y_verts = shape.corners();
                    const geom_len = x_edges.len;

                    var X_corners_static: [geom_len]Vec = undefined;
                    var Y_corners_static: [geom_len]Vec = undefined;
                    var X_orths: [hitbox_len + geom_len]Vec = undefined;
                    var Y_orths: [hitbox_len + geom_len]Vec = undefined;

                    for (x_edges, y_edges, x_verts, y_verts, 0..geom_len) |x_edge, y_edge, x_vert, y_vert, i| {
                        X_orths[i], Y_orths[i] = vecRightOrth(@splat(x_edge), @splat(y_edge));
                        X_corners_static[i] = @splat(x_vert);
                        Y_corners_static[i] = @splat(y_vert);
                    }
                    for (X_edges_dynamic, Y_edges_dynamic, geom_len..geom_len + hitbox_len) |X_edge_dynamic, Y_edge_dynamic, i| {
                        X_orths[i], Y_orths[i] = vecRightOrth(X_edge_dynamic, Y_edge_dynamic);
                    }

                    const col, const X_push, const Y_push = separatingAxis(
                        &X_orths,
                        &Y_orths,
                        &X_corners_dynamic,
                        &Y_corners_dynamic,
                        &X_corners_static,
                        &Y_corners_static,
                    );
                    colliding +%= col;
                    X_minimal_push += X_push;
                    Y_minimal_push -= Y_push;
                },
                // else => unreachable,
            }
        }
        self.colliding = @floatFromInt(colliding);
        self.physics_state.X += X_minimal_push;
        self.physics_state.Y += Y_minimal_push;

        self.X_push = X_minimal_push;
        self.Y_push = Y_minimal_push;
    }

    pub fn gamePhysics(self: *SimulatorState) void {
        const gravity: @Vector(vec_length, float) = @splat(-50.81);
        const friction_coeff: Vec = @splat(10.0);
        const drag_coeff: Vec = @splat(0.2);
        const elasticity: Vec = @splat(0.3);

        const dX = self.physics_state.dX;
        const dY = self.physics_state.dY;

        const bounce_vel_cutoff: Vec = @splat(10.0);

        const bounce_x: Vec = vecFloatFromBool(@abs(dX) > bounce_vel_cutoff);
        const bounce_y: Vec = vecFloatFromBool(@abs(dY) > bounce_vel_cutoff);

        const bounce_dX: Vec = self.X_push;
        const bounce_dY: Vec = self.Y_push;

        const glide_vel_cutoff: Vec = @splat(1.0);

        const glide_x: Vec = vecFloatFromBool(@abs(dX) > glide_vel_cutoff);
        const glide_y: Vec = vecFloatFromBool(@abs(dY) > glide_vel_cutoff);

        const preserved_dX: Vec = @select(float, self.X_push < self.Y_push, dX, Zero);
        const preserved_dY: Vec = @select(float, self.Y_push < self.X_push, dY, Zero);

        self.physics_state.dX = self.colliding * (bounce_x * elasticity * bounce_dX + glide_x * preserved_dX) + (One - self.colliding) * (dX);
        self.physics_state.dY = self.colliding * (bounce_y * elasticity * bounce_dY + glide_y * preserved_dY) + (One - self.colliding) * (dY);

        self.physics_state.ddX = self.colliding * (-friction_coeff * preserved_dX) + (One - self.colliding) * (-drag_coeff * dX * @abs(dX));
        self.physics_state.ddY = self.colliding * (-friction_coeff * preserved_dY) + (One - self.colliding) * (-drag_coeff * dY * @abs(dY) + gravity);
    }

    // I realized a bit late that I don't actually need to simulate differential equations,
    // since I can just evaluate Newton's equations of motion directly. That said, I'm keeping
    // this function for later if I make more complicated motion.
    fn implicitEuler(
        s0: PhysicsState,
        // t: f32 if we have a function of time, pass t + dt to f_and_df
        dt: float,
        f_and_df: *const fn (s: PhysicsState) struct { PhysicsState, PhysicsState },
    ) PhysicsState {
        var s = s0; // we use initial state as Newton-Raphson guess.

        return inline for (0..newton_max_iters) |_| {
            const f, const df = f_and_df(s);
            const numerator = s.minus(s0).minus(f.times_f32(dt));
            const denominator = PhysicsState.one_minus(df.times_f32(dt));

            s = s.minus(numerator.div(denominator));

            if (s.infnorm() <= newton_epsilon) break s;
        } else s;
    }
};
