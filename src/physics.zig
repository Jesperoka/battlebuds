/// Some 2D rigid-body physics.
const std = @import("std");
const utils = @import("utils.zig");

const time = std.time;

// time.Timer
const uint = u8;
const float = f16;

pub const SimulatorState = struct {
    num_characters: uint = 1,
    newton_max_iters: u16 = 10,
    newton_epsilon: f32 = 10e-6,

    const Vec = @Vector(@This().num_characters, float);

    const PhysicsState = struct {
        X: Vec = @splat(0),
        Y: Vec = @splat(0),
        dX: Vec = @splat(0),
        dY: Vec = @splat(0),
        ddX: Vec = @splat(0), // Not used in arithmetic functions below
        ddY: Vec = @splat(0), // Not used in arithmetic functions below

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

    fn posVelAccTimeRelation(dt: f32, p0: Vec, v0: Vec, a: Vec) f32 {
        const delta_t: Vec = @splat(dt);
        const delta_t_squared: Vec = @splat(dt * dt); // is this better?
        const one_half: Vec = @splat(0.5);

        return p0 + v0 * delta_t + one_half * a * delta_t_squared;
    }

    fn velAccTimeRelation(dt: f32, v0: Vec, a: Vec) f32 {
        const delta_t: Vec = @splat(dt);

        return v0 + a * delta_t;
    }

    fn newtonianMotion(dt: f32, state: PhysicsState) PhysicsState {
        const X_next = posVelAccTimeRelation(dt, state.X0, state.dX, state.ddX);
        const Y_next = posVelAccTimeRelation(dt, state.Y0, state.dY, state.ddY);
        const dX_next = velAccTimeRelation(dt, state.dX, state.ddX);
        const dY_next = velAccTimeRelation(dt, state.dY, state.ddY);

        return .{ X_next, Y_next, dX_next, dY_next, state.ddX, state.ddY };
        // { dX_next, dY_next, state.ddX, state.ddY, @splat(0), @splat(0) }, // df
    }

    // I realized a bit late that I don't actually need to simulate differential equations,
    // since I can just evaluate Newton's equations of motion directly. That said, I'm keeping
    // this function for later if I make more complicated motion.
    fn implicitEuler(
        s0: PhysicsState,
        // t: f32 if we have a function of time, pass t + dt to f_and_df
        dt: f32,
        f_and_df: *const fn (s: PhysicsState) struct { PhysicsState, PhysicsState },
    ) PhysicsState {
        var s = s0; // we use initial state as Newton-Raphson guess.

        return inline for (0..@This().newton_max_iters) |_| {
            const f, const df = f_and_df(s);
            const numerator = s.minus(s0).minus(f.times_f32(dt));
            const denominator = PhysicsState.one_minus(df.times_f32(dt));

            s = s.minus(numerator.div(denominator));

            if (s.infnorm() <= @This().newton_epsilon) break s;
        } else s;
    }
};
