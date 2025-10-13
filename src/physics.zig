/// Some 2D rigid-body physics.
const constants = @import("constants.zig");
const std = @import("std");
const utils = @import("utils.zig");
const stages = @import("stages.zig");

const float = @import("types.zig").float;
const Vec = @import("types.zig").Vec;
const VecBool = @import("types.zig").VecBool;
const VecI32 = @import("types.zig").VecI32;

fn vecOr(a: VecBool, b: VecBool) VecBool { // https://github.com/ziglang/zig/issues/14306
    return @select(bool, a, a, b);
}
fn vecAnd(a: VecBool, b: VecBool) VecBool { // https://github.com/ziglang/zig/issues/14306
    return @select(bool, a, b, a);
}
fn vecNot(a: VecBool) VecBool {
    return a != constants.TRUE_VEC;
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

pub const PhysicsState = struct {
    X: Vec = @splat(0),
    Y: Vec = @splat(0),
    dX: Vec = @splat(0),
    dY: Vec = @splat(0),
    ddX: Vec = @splat(0), // Not used in arithmetic functions below
    ddY: Vec = @splat(0), // Not used in arithmetic functions below

    // TODO: Rework dynamic entity hitboxes.
    // TODO: This is a temporary solution. Rework entity shape.
    W: Vec = @splat(100 / constants.PIXELS_PER_METER), // Not used in arithmetic functions below
    H: Vec = @splat(100 / constants.PIXELS_PER_METER), // Not used in arithmetic functions below

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
    colliding: Vec = constants.ZERO_VEC,
    X_push: Vec = constants.ZERO_VEC,
    Y_push: Vec = constants.ZERO_VEC,

    floor_collision: VecBool = constants.FALSE_VEC,

    pub fn init(
        self: *SimulatorState,
        starting_positions: [constants.MAX_NUM_PLAYERS]stages.Position,
        shuffled_indices: [constants.MAX_NUM_PLAYERS]u8,
    ) void {
        for (shuffled_indices, 0..constants.MAX_NUM_PLAYERS) |idx, i| {
            self.physics_state.X[i] = starting_positions[idx].x;
            self.physics_state.Y[i] = starting_positions[idx].y;
        }
    }

    fn posVelAccTimeRelation(dt: float, p0: Vec, v0: Vec, a: Vec) Vec {
        const delta_t: Vec = @splat(dt);
        const delta_t_squared: Vec = @splat(dt * dt);
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

    // TODO: Rework dynamic entity hitboxes.
    fn edges(X: Vec, Y: Vec, W: Vec, H: Vec) struct { [4]Vec, [4]Vec } {
        // 3----2
        // |    |
        // 0----1

        const X0 = X - (W / constants.TWO_VEC);
        const X1 = X + (W / constants.TWO_VEC);
        const X2 = X + (W / constants.TWO_VEC);
        const X3 = X - (W / constants.TWO_VEC);

        const Y0 = Y - (H / constants.TWO_VEC);
        const Y1 = Y - (H / constants.TWO_VEC);
        const Y2 = Y + (H / constants.TWO_VEC);
        const Y3 = Y + (H / constants.TWO_VEC);

        return .{
            .{ X1 - X0, X2 - X1, X3 - X2, X0 - X3 },
            .{ Y1 - Y0, Y2 - Y1, Y3 - Y2, Y0 - Y3 },
        };
    }

    // TODO: Rework dynamic entity hitboxes.
    fn corners(X: Vec, Y: Vec, W: Vec, H: Vec) struct { [4]Vec, [4]Vec } {
        // 3----2
        // |    |
        // 0----1

        const X0 = X - (W / constants.TWO_VEC);
        const X1 = X + (W / constants.TWO_VEC);
        const X2 = X + (W / constants.TWO_VEC);
        const X3 = X - (W / constants.TWO_VEC);

        const Y0 = Y - (H / constants.TWO_VEC);
        const Y1 = Y - (H / constants.TWO_VEC);
        const Y2 = Y + (H / constants.TWO_VEC);
        const Y3 = Y + (H / constants.TWO_VEC);

        return .{
            .{ X0, X1, X2, X3 },
            .{ Y0, Y1, Y2, Y3 },
        };
    }

    fn pushAway(X_push: Vec, Y_push: Vec, X: Vec, Y: Vec, X_shape: Vec, Y_shape: Vec) struct { Vec, Vec } {
        const X_displacement = X_shape - X;
        const Y_displacement = Y_shape - Y;
        const dot_product = vecDot(X_push, Y_push, X_displacement, Y_displacement);
        const X_push_flipped = @select(float, dot_product > constants.ZERO_VEC, -X_push, X_push);
        const Y_push_flipped = @select(float, dot_product > constants.ZERO_VEC, -Y_push, Y_push);

        return .{ X_push_flipped, Y_push_flipped };
    }

    fn separatingAxis(
        X_orths: []const Vec,
        Y_orths: []const Vec,
        X_verts_0: []const Vec,
        Y_verts_0: []const Vec,
        X_verts_1: []const Vec,
        Y_verts_1: []const Vec,
    ) struct { VecBool, Vec, Vec } {
        var X_push: Vec = @splat(999999999.0); // If we use inf, we get NaNs unless we filter.
        var Y_push: Vec = @splat(999999999.0); // If we use inf, we get NaNs unless we filter.
        var separated = constants.FALSE_VEC;

        for (X_orths, Y_orths) |X_orth, Y_orth| {
            var min0: Vec = @splat(constants.INFINITY);
            var min1: Vec = @splat(constants.INFINITY);
            var max0: Vec = @splat(-constants.INFINITY);
            var max1: Vec = @splat(-constants.INFINITY);

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
            const eps: Vec = @splat(0.0 / constants.PIXELS_PER_METER);
            const D_min_proj = @min(max1 - min0, max0 - min1);

            var O_squared = vecDotSelf(X_orth, Y_orth);
            O_squared = @select(float, O_squared != constants.ZERO_VEC, O_squared, constants.ZERO_VEC);

            const overlapping = vecAnd(max0 >= min1, max1 >= min0);

            separated = vecOr(separated, vecNot(overlapping));

            const D_min_proj_scaled = @select(
                float,
                overlapping,
                (D_min_proj / O_squared) + eps,
                constants.ZERO_VEC,
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

        return .{ vecNot(separated), X_push, Y_push };
    }

    pub fn resolveCollisions(self: *SimulatorState, geoms: []const stages.Shape) void {
        // TODO: Rework dynamic entity hitboxes.
        // But when I have collision between bullets and characters, I need to check
        // ownership of the bullet somehow.
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

        var colliding: VecBool = constants.FALSE_VEC;
        var X_minimal_push: Vec = constants.ZERO_VEC;
        var Y_minimal_push: Vec = constants.ZERO_VEC;

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

                    const new_collision, const X_push_pre_flip, const Y_push_pre_flip = separatingAxis(
                        &X_orths,
                        &Y_orths,
                        &X_corners_dynamic,
                        &Y_corners_dynamic,
                        &X_corners_static,
                        &Y_corners_static,
                    );
                    const x_shape, const y_shape = shape.vertexCentroid();
                    const X_push, const Y_push = pushAway(X_push_pre_flip, Y_push_pre_flip, self.physics_state.X, self.physics_state.Y, @splat(x_shape), @splat(y_shape));

                    // TODO: IDEA: Y_push is upward and greater than X_push => get your jump back.
                    // This might be a bit quirky, since on steeply angled planes, whether you get your jump
                    // back or not depends on the velocity and direction of collision.
                    // But it might also actually be a fun mechanic...

                    colliding = vecOr(colliding, new_collision);
                    X_minimal_push += X_push;
                    Y_minimal_push += Y_push;
                },
                // else => unreachable,
            }
        }
        self.colliding = vecFloatFromBool(colliding);
        self.physics_state.X += X_minimal_push;
        self.physics_state.Y += Y_minimal_push;

        self.X_push = X_minimal_push;
        self.Y_push = Y_minimal_push;

        self.floor_collision = vecAnd(colliding, vecAnd(Y_minimal_push > constants.ZERO_VEC, Y_minimal_push >= @abs(X_minimal_push)));
    }

    pub fn gamePhysics(self: *SimulatorState) void {
        const gravity: Vec = @splat(-50.81);
        const friction_coeff: Vec = @splat(2.8);
        const drag_coeff: Vec = @splat(0.2);
        const elasticity: Vec = @splat(0.3);

        const dX = self.physics_state.dX;
        const dY = self.physics_state.dY;

        const bounce_vel_cutoff: Vec = @splat(7.0);

        const do_bounce_x: Vec = vecFloatFromBool(@abs(dX) > bounce_vel_cutoff);
        const do_bounce_y: Vec = vecFloatFromBool(@abs(dY) > bounce_vel_cutoff);

        const bounce_dX: Vec = -dX;
        const bounce_dY: Vec = -dY;

        const glide_vel_cutoff: Vec = @splat(5.0);

        const do_glide_x: Vec = vecFloatFromBool(@abs(dX) > glide_vel_cutoff);
        const do_glide_y: Vec = vecFloatFromBool(@abs(dY) > glide_vel_cutoff);

        // std.debug.print("\nX_push[0]: {}, Y_push[0]: {}, colliding[0]: {}, floor_collision[0]: {}, do_glide_x[0]: {}, do_glide_y[0]: {}\n", .{
        //     self.X_push[0],
        //     self.Y_push[0],
        //     self.colliding[0],
        //     self.floor_collision[0],
        //     do_glide_x[0],
        //     do_glide_y[0],
        // });

        // TODO: Project onto the normal of the push vector.
        const preserved_dX: Vec = @select(float, @abs(self.X_push) < @abs(self.Y_push), dX, constants.ZERO_VEC);
        const preserved_dY: Vec = @select(float, @abs(self.Y_push) < @abs(self.X_push), dY, constants.ZERO_VEC);

        self.physics_state.dX = self.colliding * (do_bounce_x * elasticity * bounce_dX + do_glide_x * preserved_dX) + (constants.ONE_VEC - self.colliding) * (dX);
        self.physics_state.dY = self.colliding * (do_bounce_y * elasticity * bounce_dY + do_glide_y * preserved_dY) + (constants.ONE_VEC - self.colliding) * (dY);

        self.physics_state.ddX = vecFloatFromBool(self.floor_collision) * (-friction_coeff * preserved_dX) + (constants.ONE_VEC - self.colliding) * (-drag_coeff * dX * @abs(dX));
        self.physics_state.ddY = vecFloatFromBool(self.floor_collision) * (-@as(Vec, @splat(0.0)) * preserved_dY) + (constants.ONE_VEC - self.colliding) * (-drag_coeff * dY * @abs(dY)) + gravity;
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
