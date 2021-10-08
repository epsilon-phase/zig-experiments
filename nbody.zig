const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const cmath = @cImport({
    @cInclude("math.h");
});
fn bad_sqrt(x: f32) f32 {
    return 1 + (x - 1) / 2;
}
pub fn vector2(comptime value: type) type {
    return struct {
        const This = @This();
        x: value,
        y: value,
        pub inline fn add(this: This, other: This) This {
            @setFloatMode(.Optimized);
            var t: This = v2{ .x = 0, .y = 0 };
            t = .{ .x = this.x + other.x, .y = this.y + other.y };
            return t;
        }
        pub inline fn sub(this: This, other: This) This {
            return this.add(.{ .x = -other.x, .y = -other.y });
        }
        pub inline fn scale(this: This, v: value) This {
            @setFloatMode(.Optimized);
            return .{ .x = this.x * v, .y = this.y * v };
        }
        pub inline fn distance(this: This, other: This) value {
            @setFloatMode(.Optimized);
            const sqrt = cmath.sqrtf;
            const pow = std.math.pow;
            const dx: f32 = this.x - other.x;
            const dy: f32 = this.y - other.y;
            return @sqrt(dx * dx + dy * dy);
        }
        pub inline fn fast_dist(this: This, other: This) value {
            @setFloatMode(.Optimized);
            const dx: f32 = this.x - other.x;
            const dy: f32 = this.y - other.y;
            return dx * dx + dy * dy;
        }
        //Wrap the value around, like when pacman reaches the edge of the map
        pub inline fn wrap(c: This, a: This, b: This) This {
            @setFloatMode(.Optimized);
            var r: This = .{ .x = c.x, .y = c.y };
            if (r.x < a.x) {
                r.x = b.x;
            } else if (r.x > b.x) {
                r.x = a.x;
            }
            if (r.y < a.y) {
                r.y = b.y;
            } else if (r.y > b.y) {
                r.y = a.y;
            }
            return r;
        }
        pub inline fn magnitude(a: This) value {
            @setFloatMode(.Optimized);
            const sqrt = std.math.sqrt;
            return sqrt(a.x * a.x + a.y * a.y);
        }
        pub fn normalize(a: This) This {
            @setFloatMode(.Optimized);
            if (a.x == 0 and a.y == 0)
                return .{ .x = 0, .y = 0 };
            return a.scale(1.0 / a.magnitude());
        }
        pub fn random(minimum: This, maximum: This, rand: *std.rand.Random) This {
            var nx = minimum.x + (maximum.x - minimum.x) * rand.float(value);
            var ny = minimum.y + (maximum.y - minimum.y) * rand.float(value);
            return .{ .x = nx, .y = ny };
        }
        pub fn toRaylib(this: This) ray.Vector2 {
            var ret: ray.Vector2 = .{ .x = this.x, .y = this.y };
            // ret.x = this.x;
            // ret.y = this.y;
            return ret;
        }
        pub const Region = struct {
            min: This,
            max: This,
            pub fn randomInsideRegion(this: @This(), rand: *std.rand.Random) This {
                return This.random(this.min, this.max, rand);
            }
        };
    };
}
const v2 = vector2(f32);
const max_velocity: f32 = 30.0;
const trail_length = 40;
const trail_start_color: ray.Color = .{ .r = 255, .b = 0, .g = 0, .a = 255 };
const trail_end_color: ray.Color = .{ .r = 0, .b = 255, .g = 0, .a = 255 };
fn color_interpolate(a: ray.Color, b: ray.Color, t: f32) ray.Color {
    var r: f32 = (@intToFloat(f32, a.r) / 255.0) * (1 - t) + (@intToFloat(f32, b.r) / 255.0) * t;
    var g: f32 = (@intToFloat(f32, a.g) / 255.0) * (1 - t) + (@intToFloat(f32, b.g) / 255.0) * t;
    var b1: f32 = (@intToFloat(f32, a.b) / 255.0) * (1 - t) + (@intToFloat(f32, b.b) / 255.0) * t;
    var col: ray.Color = .{ .r = @floatToInt(u8, r * 255), .g = @floatToInt(u8, g * 255), .b = @floatToInt(u8, b1 * 255), .a = 255 };
    return col;
}
fn trail_color_at_index(index: usize) ray.Color {
    var t = @intToFloat(f32, index) / trail_length;

    return color_interpolate(trail_start_color, trail_end_color, t);
}
const particle = struct {
    const This = @This();
    position: vector2(f32) = v2{ .x = 0, .y = 0 },
    velocity: vector2(f32) = v2{ .x = 0.0, .y = 0.0 },
    acceleration: vector2(f32) = v2{ .x = 0.0, .y = 0.0 },
    trail: [trail_length]v2 = undefined,
    mass: f32,
    radius: f32,
    pub fn get_radius(this: *const This) f32 {
        //var result: f32 = std.math.ln(this.mass) / std.math.ln(3.0);
        var result: f32 = @log(this.mass) / comptime std.math.ln(3.0);
        if (result > 40) {
            result = 40 - @log(this.mass) / comptime std.math.ln(5.0);
        }
        return result;
    }
    //Returns true if the two particles overlap
    pub fn overlaps(this: *const This, other: *const This) bool {
        var r1 = this.radius;
        var r2 = other.radius;
        var dist = this.position.distance(other.position);
        return (r1 + r2) > dist;
    }
    fn reset_trail(this: *This) void {
        for (this.trail) |*t| {
            t.* = this.position;
        }
    }
    fn update_trail(this: *This) void {
        var i: usize = trail_length - 1;
        var current: v2 = this.position;
        for (this.trail) |*t| {
            var tmp: v2 = t.*;
            t.* = current;
            current = tmp;
        }
    }
    //Handles the base movement
    pub fn motion_step(this: *This, timestep: f32, g: f32) void {
        this.position = this.position.add(this.velocity.scale(timestep));
        this.velocity = this.velocity.add(this.acceleration.scale(g));
        if (this.velocity.magnitude() > max_velocity)
            this.velocity = this.velocity.scale(0.9);
        this.acceleration = .{ .x = 0, .y = 0 };

        if (this.position.fast_dist(this.trail[0]) > 4)
            this.update_trail();
    }
    pub inline fn attraction(this: *const This, other: *const This, g: f32) vector2(f32) {
        @setFloatMode(.Optimized);
        var dist = this.position.distance(other.position);
        var vector_to = other.position.sub(this.position).normalize();
        return vector_to.scale((this.mass * other.mass) / (dist * dist)).scale(g / this.mass);
    }
    pub fn absorb(this: *This, other: *const This) bool {
        if (!this.overlaps(other)) {
            return false;
        }
        var total_mass = this.mass + other.mass;

        this.position = this.position.scale(this.mass / total_mass)
            .add(other.position.scale(other.mass / total_mass));
        this.acceleration = this.acceleration.scale(this.mass / (total_mass)).add(
            other.acceleration.scale(other.mass / total_mass),
        );
        this.velocity = this.velocity.scale(this.mass).add(other.velocity.scale(other.mass)).scale(1.0 / total_mass);
        // this.velocity = this.velocity.scale(this.mass / total_mass).
        // add(other.velocity.scale(other.mass / total_mass));
        this.mass += other.mass;
        this.radius = this.get_radius();
        //this.reset_trail();
        return true;
    }
    pub fn init_particle(this: *This, window: v2.Region, velocity: v2.Region, max_mass: f32, rand: *std.rand.Random) void {
        this.mass = max_mass * rand.float(f32) + 1.0;
        this.position = window.randomInsideRegion(rand);
        this.acceleration = .{ .x = 0.0, .y = 0.0 };
        //        this.velocity = .{ .x = 0.0, .y = 0.0 };
        this.velocity = velocity.randomInsideRegion(rand);
        this.reset_trail();
        this.radius = this.get_radius();
    }
    pub fn velocityLine(this: *const This, a: *ray.Vector2, b: *ray.Vector2) void {
        a.* = this.position.toRaylib();
        var velocity = this.velocity.normalize().scale((this.velocity.magnitude() / max_velocity) * this.radius);
        b.* = this.position.add(velocity).toRaylib();
    }
    pub fn accelerationLine(this: *const This, a: *ray.Vector2, b: *ray.Vector2) void {
        a.* = this.position.toRaylib();
        var acceleration = this.acceleration.normalize().scale(this.radius); //.scale(this.mass).scale(1.0 / timestep);
        b.* = this.position.add(acceleration).toRaylib();
    }
    pub fn draw_trail(this: *const This) void {
        var trail_index: usize = 1;
        while (trail_index < trail_length) {
            var dist = this.trail[trail_index].distance(this.trail[trail_index - 1]);
            if (dist < 100)
                ray.DrawLineV(this.trail[trail_index].toRaylib(), this.trail[trail_index - 1].toRaylib(), trail_color_at_index(trail_index));
            trail_index += 1;
        }
    }
    pub fn draw_mass(this: *const This) void {
        var msg = ray.TextFormat("%i", @floatToInt(c_int, this.mass));
        ray.DrawText(
            msg,
            @floatToInt(c_int, this.position.x),
            @floatToInt(c_int, this.position.y),
            16,
            ray.GREEN,
        );
    }
    pub fn draw(this: *const This) void {
        ray.DrawCircleV(this.position.toRaylib(), this.radius, ray.BLACK);
        var a: ray.Vector2 = ray.Vector2{ .x = 0.0, .y = 0.0 };
        var b: ray.Vector2 = ray.Vector2{ .x = 0.0, .y = 0.0 };
        this.velocityLine(&a, &b);
        ray.DrawLineV(a, b, ray.BLUE);
        this.accelerationLine(&a, &b);
        ray.DrawLineV(a, b, ray.RED);
    }
};

test "Particle Test" {
    var p1: particle = .{ .position = .{ .x = 0.0, .y = 0.0 }, .mass = 500 };
    var p2: particle = .{ .position = .{ .x = 1, .y = 1 }, .mass = 500 };
    std.debug.assert(p1.overlaps(&p2));
}

const state_t = struct { draw_text: bool = true, draw_mass: bool = false };
var state: state_t = undefined;
const ParticleCollection = struct {
    const This = @This();
    particles: [150]particle,
    window_start: vector2(f32) = v2{ .x = 0.0, .y = 0.0 },
    window_end: vector2(f32) = v2{ .x = 100, .y = 100 },
    timestep: f32 = 1.0 / 60.0,
    gravitational_constant: f32 = 1e-3,
    steps: usize = 0,
    rand: *std.rand.Random,
    const max_mag = 2.0;
    const velocity_region: v2.Region = .{ .min = .{ .x = -max_mag, .y = -max_mag / 5.0 }, .max = .{ .x = max_mag, .y = max_mag / 5.0 } };
    pub fn init_particles(this: *This) void {
        for (this.particles) |*p| {
            p.init_particle(
                .{ .min = this.window_start, .max = this.window_end },
                This.velocity_region,
                this.maximum_mass(),
                this.rand,
            );
        }
    }
    fn maximum_mass(this: *const This) f32 {
        if (this.steps == 0)
            return 100.0;
        return 100.0 + std.math.max(0, std.math.log(f32, 2.0, this.particles[0].mass));
    }
    pub fn step_world(this: *This) void {
        defer this.steps += 1;
        var i: usize = 0;
        for (this.particles) |*p| {
            p.motion_step(this.timestep, this.gravitational_constant);
            p.position = p.position.wrap(this.window_start, this.window_end);
        }
        for (this.particles) |*a| {
            for (this.particles[i + 1 ..]) |*b| {
                //No self attraction please, allowing that would result in division by zero
                if (a == b)
                    continue;
                // This does not result in physically accurate acceleration, but it makes it a lot more
                // interesting to watch,since it's a lot faster :)
                a.acceleration = a.acceleration.add(a.attraction(b, this.gravitational_constant).scale(this.timestep));

                b.acceleration = b.acceleration.add(b.attraction(a, this.gravitational_constant).scale(this.timestep));
            }
            i += 1;
        }
        i = 0;
        while (i < this.particles.len - 1) : (i += 1) {
            var j: usize = i + 1;
            var p1 = &this.particles[i];
            while (j < this.particles.len) : (j += 1) {
                var p2 = &this.particles[j];
                if (p1.absorb(p2)) {
                    var oldpos = p2.position;
                    p2.init_particle(.{ .min = this.window_start, .max = this.window_end }, This.velocity_region, this.maximum_mass(), this.rand);
                    var newpos = p2.position;
                }
            }
        }
    }
    pub fn drawSystem(this: *const This) void {
        for (this.particles) |p| {
            p.draw_trail();
        }
        for (this.particles) |p| {
            p.draw();
            if (state.draw_mass) {
                p.draw_mass();
            }
        }
    }
};
pub fn main() !void {
    const width = 800;
    const height = 450;
    ray.InitWindow(width, height, "Nbody");
    ray.SetTargetFPS(60);
    var iterations: u32 = 1;
    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT);
    //This is very much *not* good practice, but it's the easiest way to start this
    var rand = std.rand.Xoroshiro128.init(@intCast(u64, std.time.milliTimestamp()));
    //Don't initialize the particles yet.
    var p: ParticleCollection = .{ .particles = undefined, .rand = &rand.random };
    var show_text: bool = true;
    p.window_end = .{ .x = width, .y = height };
    p.init_particles();
    var frame: u32 = 0;
    while (!ray.WindowShouldClose()) {
        if (frame % 60 == 0 and frame != 0) {
            if (ray.GetFrameTime() >= (1.0 / 60.0) * 1.01) {
                iterations = std.math.max(1, iterations - 1);
            } else {
                iterations += 5;
            }
        }
        var iterations_remaining = iterations;
        while (iterations_remaining > 0) {
            p.step_world();
            iterations_remaining -= 1;
        }
        if (ray.IsKeyPressed(ray.KEY_T)) {
            state.draw_text = !state.draw_text;
        }
        if (ray.IsKeyPressed(ray.KEY_R)) {
            p.init_particles();
            iterations = 0;
            p.steps = 0;
            frame = 0;
        }
        if (ray.IsKeyPressed(ray.KEY_M)) {
            state.draw_mass = !state.draw_mass;
        }

        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        p.drawSystem();
        if (state.draw_text) {
            var status = ray.TextFormat(
                "FPS: %i, Iterations: %i, total steps: %llu \nSimulated Time: %llu seconds",
                ray.GetFPS(),
                iterations,
                p.steps,
                @floatToInt(u64, std.math.round((@intToFloat(f64, p.steps) / 60.0))),
            );
            var status_size = ray.MeasureTextEx(ray.GetFontDefault(), status, 16, 1.0);
            ray.DrawRectangleV(ray.Vector2{ .x = 100.0, .y = 100.0 }, status_size, ray.GRAY);
            ray.DrawText(status, 100, 100, 16, ray.BLACK);
        }
        // p.step_world();
        frame +%= 1;
    }
}
