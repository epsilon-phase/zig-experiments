const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
pub fn vector2(comptime value: type) type {
    return struct {
        const This = @This();
        x: value,
        y: value,
        pub inline fn add(this: This, other: This) This {
            var t: This = v2{ .x = 0, .y = 0 };
            t = .{ .x = this.x + other.x, .y = this.y + other.y };
            return t;
        }
        pub fn sub(this: This, other: This) This {
            return this.add(.{ .x = -other.x, .y = -other.y });
        }
        pub inline fn scale(this: This, v: value) This {
            return .{ .x = this.x * v, .y = this.y * v };
        }
        pub inline fn distance(this: This, other: This) value {
            const sqrt = std.math.sqrt;
            const pow = std.math.pow;
            return sqrt(pow(value, this.x - other.x, 2) + pow(value, this.y - other.y, 2));
        }
        //Wrap the value around, like when pacman reaches the edge of the map
        pub inline fn wrap(c: This, a: This, b: This) This {
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
            const sqrt = std.math.sqrt;
            return sqrt(a.x * a.x + a.y * a.y);
        }
        pub fn normalize(a: This) This {
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
    };
}
const v2 = vector2(f32);
const max_velocity: f32 = 30.0;
const particle = struct {
    const This = @This();
    position: vector2(f32) = v2{ .x = 0, .y = 0 },
    velocity: vector2(f32) = v2{ .x = 0.0, .y = 0.0 },
    acceleration: vector2(f32) = v2{ .x = 0.0, .y = 0.0 },
    mass: f32,
    pub fn radius(this: *const This) f32 {
        var result: f32 = std.math.ln(this.mass) / std.math.ln(3.0);
        if (result > 40) {
            return 40 - std.math.ln(this.mass) / std.math.ln(5.0);
        }
        return result;
    }
    //Returns true if the two particles overlap
    pub fn overlaps(this: *const This, other: *const This) bool {
        var r1 = this.radius();
        var r2 = other.radius();
        var dist = this.position.distance(other.position);
        return (r1 + r2) > dist;
    }
    //Handles the base movement
    pub fn motion_step(this: *This, timestep: f32) void {
        this.position = this.position.add(this.velocity.scale(timestep));
        this.velocity = this.velocity.add(this.acceleration.scale(timestep));
        if (this.velocity.magnitude() > max_velocity)
            this.velocity = this.velocity.scale(0.9);
        this.acceleration = .{ .x = 0, .y = 0 };
    }
    pub inline fn attraction(this: *const This, other: *const This, g: f32) vector2(f32) {
        var dist = this.position.distance(other.position);
        var vector_to = other.position.sub(this.position).normalize();
        return vector_to.scale(g * (this.mass * other.mass) / std.math.pow(f32, dist, 2)).scale(1.0 / this.mass);
    }
    pub fn absorb(this: *This, other: *const This) bool {
        if (!this.overlaps(other)) {
            return false;
        }
        var total_mass = this.mass + other.mass;

        this.position = this.position.scale(this.mass / total_mass).
            add(other.position.scale(other.mass / total_mass));
        this.acceleration = this.acceleration.scale(this.mass / (total_mass)).add(other.acceleration.scale(other.mass / total_mass));
        this.velocity = this.velocity.scale(this.mass).add(other.velocity.scale(other.mass)).scale(1.0 / total_mass);
        // this.velocity = this.velocity.scale(this.mass / total_mass).
        // add(other.velocity.scale(other.mass / total_mass));
        this.mass += other.mass;
        return true;
    }
    pub fn init_particle(this: *This, window_start: v2, window_end: v2, rand: *std.rand.Random) void {
        this.mass = @intToFloat(f32, rand.intRangeLessThan(i32, 1, 100));
        this.position = v2.random(window_start, window_end, rand);
        this.acceleration = .{ .x = 0.0, .y = 0.0 };
        this.velocity = .{ .x = 0.0, .y = 0.0 };
    }
    pub fn velocityLine(this: *const This, a: *ray.Vector2, b: *ray.Vector2) void {
        a.* = this.position.toRaylib();
        var velocity = this.velocity.normalize().scale((this.velocity.magnitude() / max_velocity) * this.radius());
        b.* = this.position.add(velocity).toRaylib();
    }
    pub fn accelerationLine(this: *const This, a: *ray.Vector2, b: *ray.Vector2, timestep: f32) void {
        a.* = this.position.toRaylib();
        var acceleration = this.acceleration.normalize().scale(this.radius()).scale(1.0 / timestep);
        b.* = this.position.add(acceleration).toRaylib();
    }
};

test "Particle Test" {
    var p1: particle = .{ .position = .{ .x = 0.0, .y = 0.0 }, .mass = 500 };
    var p2: particle = .{ .position = .{ .x = 1, .y = 1 }, .mass = 500 };
    std.debug.assert(p1.overlaps(&p2));
}

const ParticleCollection = struct {
    const This = @This();
    particles: [150]particle,
    window_start: vector2(f32) = v2{ .x = 0.0, .y = 0.0 },
    window_end: vector2(f32) = v2{ .x = 100, .y = 100 },
    timestep: f32 = 1.0 / 60.0,
    gravitational_constant: f32 = 1e-3,
    rand: *std.rand.Random,
    pub fn init_particles(this: *This) void {
        for (this.particles) |*p| {
            p.init_particle(this.window_start, this.window_end, this.rand);
        }
    }
    pub fn step_world(this: *This) void {
        var i: usize = 0;
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
        for (this.particles) |*p| {
            p.motion_step(this.timestep);
            p.position = p.position.wrap(this.window_start, this.window_end);
        }
        i = 0;
        while (i < this.particles.len - 1) {
            var j: usize = i + 1;
            var p1 = &this.particles[i];
            while (j < this.particles.len) {
                var p2 = &this.particles[j];
                if (p1.absorb(p2)) {
                    var oldpos = p2.position;
                    p2.init_particle(this.window_start, this.window_end, this.rand);
                    var newpos = p2.position;
                }
                j += 1;
            }
            i += 1;
        }
    }
    pub fn drawSystem(this: *const This) void {
        for (this.particles) |p| {
            ray.DrawCircle(@floatToInt(c_int, p.position.x), @floatToInt(c_int, p.position.y), p.radius(), ray.BLACK);
            var a: ray.Vector2 = ray.Vector2{ .x = 0.0, .y = 0.0 };
            var b: ray.Vector2 = ray.Vector2{ .x = 0.0, .y = 0.0 };
            p.velocityLine(&a, &b);
            ray.DrawLineV(a, b, ray.BLUE);
            p.accelerationLine(&a, &b, this.timestep);
            ray.DrawLineV(a, b, ray.RED);
            // ray.DrawText(ray.TextFormat("%i", @floatToInt(c_int, p.mass)), @floatToInt(c_int, p.position.x), @floatToInt(c_int, p.position.y), 16, ray.GREEN);
        }
    }
};

pub fn main() !void {
    const width = 800;
    const height = 450;
    ray.InitWindow(width, height, "Nbody");
    ray.SetTargetFPS(60);
    var iterations: u32 = 1;
    //This is very much *not* good practice, but it's the easiest way to start this
    var rand = std.rand.Xoroshiro128.init(@intCast(u64, std.time.milliTimestamp()));
    //Don't initialize the particles yet.
    var p: ParticleCollection = .{ .particles = undefined, .rand = &rand.random };
    p.window_end = .{ .x = width, .y = height };
    p.init_particles();
    var frame: u32 = 0;
    while (!ray.WindowShouldClose()) {
        if (frame % 60 == 0 and frame != 0) {
            if (ray.GetFrameTime() >= (1.0 / 60.0) * 1.01) {
                iterations = std.math.max(1, iterations - 1);
            } else {
                iterations += 1;
            }
        }
        var iterations_remaining = iterations;
        while (iterations_remaining > 0) {
            p.step_world();
            iterations_remaining -= 1;
        }

        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        p.drawSystem();
        var status = ray.TextFormat("FPS: %i, Iterations: %i", ray.GetFPS(), iterations);
        var status_size = ray.MeasureTextEx(ray.GetFontDefault(), status, 16, 1.0);
        ray.DrawRectangleV(ray.Vector2{ .x = 100.0, .y = 100.0 }, status_size, ray.GRAY);
        ray.DrawText(status, 100, 100, 16, ray.BLACK);
        // p.step_world();
        frame +%= 1;
    }
}
