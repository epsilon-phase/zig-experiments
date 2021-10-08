const std = @import("std");
const vectors = @import("./vector.zig");
// This may not be a good idea
// but we can't really think of a better way to do this without parameterizing it,
// and that could be a tad difficult
// Probably relevant to usingnamespace and that mixin pattern we saw described a few days ago
const ray = vectors.ray;

const float_type = f32;

const v3 = vectors.NVec(float_type, 3);
const trail_length = 20;
fn color_interpolate(c1: ray.Color, c2: ray.Color, t: f32) ray.Color {
    var r: f32 = @intToFloat(f32, c2.r) * (1.0 - t) + @intToFloat(f32, c1.r) * t;
    var g: f32 = @intToFloat(f32, c2.g) * (1.0 - t) + @intToFloat(f32, c1.g) * t;
    var b: f32 = @intToFloat(f32, c2.b) * (1.0 - t) + @intToFloat(f32, c1.b) * t;
    return .{ .r = @floatToInt(u8, r), .g = @floatToInt(u8, g), .b = @floatToInt(u8, b), .a = 255 };
}
const particle = struct {
    comptime {
        @setFloatMode(.Optimized);
    }
    const This = @This();
    pos: v3,
    velocity: v3,
    acceleration: v3,
    mass: float_type,
    radius: float_type,
    trail: [trail_length]v3 = undefined,
    pub fn get_radius(a: *const This) float_type {
        // Inversion of volume to radius
        return std.math.pow(float_type, a.mass * (3.0 / 4.0), 0.3333);
    }
    pub fn overlaps(a: *const This, b: *const This) bool {
        return a.pos.distance(b.pos) < a.radius + b.radius;
    }
    pub fn update_trail(a: *This) void {
        var index: usize = trail_length - 1;
        while (index > 0) : (index -= 1) {
            a.trail[index] = a.trail[index - 1];
        }
        a.trail[0] = a.pos;
    }
    pub fn draw_trail(a: *const This) void {
        var index: usize = 1;
        while (index < trail_length) : (index += 1) {
            if (a.trail[index - 1].distance(a.trail[index]) > 30)
                continue;
            ray.DrawLine3D(a.trail[index - 1].toRaylib(), a.trail[index].toRaylib(), color_interpolate(ray.BLUE, ray.RED, @intToFloat(f32, index) / trail_length));
        }
    }
    // Advance the position of the particle forward by (timestep) seconds
    pub fn motion_step(a: *This, r: *const v3.region, timestep: float_type) void {
        var newpos = a.pos.add(a.velocity.scale(timestep));
        a.velocity = a.velocity.add(a.acceleration.scale(timestep));
        var diff: f32 = 0;
        var sum: f32 = 0;
        comptime var t: usize = 0;
        inline while (t < 3) : (t += 1) {
            diff += @fabs(newpos.v[t] - a.trail[0].v[t]);
        }
        //Wrap around
        a.pos = newpos.wrap(r.min, r.max);
        if (diff > 5) {
            a.update_trail();
        }
    }

    pub fn draw_particle(a: This, color: ray.Color) void {
        var p = a.pos.toRaylib();
        ray.DrawSphere(p, a.radius, color);
        a.draw_trail();
    }

    pub fn attraction(a: *const This, b: *const This, gravity: float_type) v3 {
        var dist = a.pos.distance(b.pos);
        var vector_to: v3 = b.pos.sub(a.pos).normalize();
        return vector_to.scale((a.mass * b.mass) / (dist * dist)).scale(gravity / a.mass);
    }

    // Absorb another particle if they overlap.
    // Only modifies the first particle, leaving the second to be reinitialized elsewhere.
    // Returns true on absorb.
    pub fn absorb(this: *This, other: *const This) bool {
        if (!this.overlaps(other)) {
            return false;
        }
        var total_mass = this.mass + other.mass;
        this.pos = this.pos.scale(this.mass / total_mass).add(other.pos.scale(other.mass / total_mass));
        this.acceleration = this.acceleration.scale(this.mass).add(other.velocity.scale(other.mass)).scale(1.0 / total_mass);
        this.velocity = this.velocity.scale(this.mass).add(other.velocity.scale(other.mass)).scale(1.0 / total_mass);
        this.mass += other.mass;
        this.radius = this.get_radius();
        return true;
    }

    // Randomize a particle in-place.
    pub fn random_particle(
        this: *This,
        rand: *std.rand.Random,
        region: v3.region,
        maximum_velocity: float_type,
        maximum_mass: float_type,
    ) void {
        this.pos = region.getRandomPoint(rand);
        this.velocity = v3.random(
            .{ .v = [3]float_type{ -1, -1, -1 } },
            .{ .v = [3]float_type{ 1, 1, 1 } },
            rand,
        ).normalize().scale(
            rand.float(float_type) * maximum_velocity,
        );
        this.mass = rand.float(float_type) * maximum_mass + 1.0;
        this.radius = this.get_radius();
    }
};

const particleCollection = struct {
    const This = @This();
    alloc: *std.mem.Allocator,
    particles: []particle,
    rand: *std.rand.Random,
    region: v3.region,
    collisions: u32 = 0,
    const gravitational_constant: float_type = 0.01;
    const timestep: float_type = 1.0 / 60.0;
    const max_vel = 10.0;
    const max_mass = 100.0;
    pub fn new(alloc: *std.mem.Allocator, rand: *std.rand.Random, n: usize, region: v3.region) !This {
        var r: This = undefined;
        r.region = region;
        r.alloc = alloc;
        r.particles = try alloc.alloc(particle, n);
        r.rand = rand;
        r.reset_particles();
        return r;
    }
    pub fn reset_particles(a: *This) void {
        a.collisions = 0;
        for (a.particles) |*i| {
            i.random_particle(a.rand, a.region, max_vel, max_mass);
        }
    }
    pub fn destroy(a: *This) void {
        a.alloc.free(a.particles);
    }
    pub fn step(a: *This) void {
        for (a.particles) |*i| {
            i.acceleration = v3.zero();
        }
        for (a.particles) |*i, x| {
            if (a.particles.len != x + 1) {
                for (a.particles[x + 1 .. a.particles.len - 1]) |*j| {
                    i.acceleration = i.acceleration.add(i.attraction(j, gravitational_constant));
                    j.acceleration = j.acceleration.add(j.attraction(i, gravitational_constant));
                    if (i.absorb(j)) {
                        j.random_particle(a.rand, a.region, max_vel, max_mass);
                        a.collisions +%= 1;
                    }
                }
            }
            i.motion_step(&a.region, timestep);
            if (i.velocity.magnitude() > 40.0) {
                i.velocity = i.velocity.scale(40.0 / i.velocity.magnitude());
            }
        }
    }
    pub fn resize(this: *This, increase: bool) !void {
        var old = this.particles.len;
        if (increase) {
            this.particles = try this.alloc.realloc(this.particles, this.particles.len + 10);
            for (this.particles[old..]) |*i| {
                i.random_particle(this.rand, this.region, max_vel, max_mass);
            }
        } else {
            this.particles = try this.alloc.realloc(this.particles, std.math.max(this.particles.len - 10, 10));
        }
    }
    pub fn draw(this: *This) void {
        ray.DrawPoint3D(this.region.min.toRaylib(), ray.GREEN);
        ray.DrawPoint3D(this.region.max.toRaylib(), ray.GREEN);
        for (this.particles) |*a, x| {
            a.draw_particle(if (x % 2 == 0) ray.BLUE else ray.RED);
        }
    }
};
const config_type = struct { draw_text: bool = true };
var config: config_type = .{};

pub fn main() !void {
    const width = 800;
    const height = 450;
    const depth = 450;
    ray.InitWindow(width, height, "Nbody");
    ray.SetTargetFPS(60);
    var iterations: u32 = 1;
    ray.SetConfigFlags(ray.FLAG_MSAA_4X_HINT);
    // The confines of the simulation space
    const region: v3.region = .{
        .min = .{ .v = [_]float_type{ 0, 0, 0 } },
        .max = .{ .v = [_]float_type{ width, height, depth } },
    };
    var c: ray.Camera = .{
        .position = .{ .x = 0, .y = 20, .z = 225 },
        .target = .{ .x = 400, .y = 225, .z = 100 },
        .up = .{ .x = 0, .y = 1, .z = 0 },
        .fovy = 50,
        .projection = ray.CAMERA_PERSPECTIVE,
    };
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();
    //This is very much *not* good practice, but it's the easiest way to start this
    var rand = std.rand.Xoroshiro128.init(@intCast(u64, std.time.milliTimestamp()));
    var pc: particleCollection = try particleCollection.new(&alloc.allocator, &rand.random, 50, region);
    defer pc.destroy();
    var frame: u32 = 0;
    var total_steps: usize = 0;
    var frame_time: f32 = 0.0;
    var times: u32 = 0;
    var buf: [400]u8 = undefined;
    while (!ray.WindowShouldClose()) : (frame +%= 1) {
        frame_time += ray.GetFrameTime();
        if (frame_time > 1) {
            if (times < 60) {
                iterations = std.math.max(1, iterations - 1);
            } else {
                iterations += 1;
            }
            times = 0;
            frame_time = 0.0;
        }
        var iterations_remaining = iterations;
        while (iterations_remaining > 0) : (iterations_remaining -= 1) {
            pc.step();
            total_steps += 1;
        }
        if (ray.IsKeyPressed(ray.KEY_UP)) {
            try pc.resize(true);
        }
        if (ray.IsKeyPressed(ray.KEY_DOWN)) {
            try pc.resize(false);
            std.debug.print("{} particles\n", .{pc.particles.len});
        }
        if (ray.IsKeyPressed(ray.KEY_T)) {
            config.draw_text = !config.draw_text;
        }
        if (ray.IsKeyPressed(ray.KEY_R)) {
            pc.reset_particles();
            times = 0;
        }
        ray.BeginDrawing();
        defer ray.EndDrawing();
        ray.ClearBackground(ray.WHITE);
        ray.BeginMode3D(c);
        pc.draw();
        ray.DrawCubeWiresV(region.min.add(region.max).scale(0.5).toRaylib(), region.max.sub(region.min).toRaylib(), ray.BLACK);
        //        ray.DrawCubeWiresV(region.min.toRaylib(), region.max.toRaylib(), ray.BLACK);
        ray.EndMode3D();
        if (config.draw_text) {
            var thing = try std.fmt.bufPrint(&buf, "Frames: {}, Iterations: {}, frameTime={d:.3}\nCollisions: {d}, particles: {d}\x00", .{ frame, iterations, ray.GetFrameTime(), pc.collisions, pc.particles.len });
            //var status = ray.TextFormat("Frames: %i Iterations: %i, frame time: %i, collisions: %i", frame, iterations, @floatToInt(i32, ray.GetFrameTime() * 1000.0), pc.collisions);
            var status_size = ray.MeasureTextEx(ray.GetFontDefault(), &buf, 16, 1.0);

            ray.DrawRectangleV(ray.Vector2{ .x = 100.0, .y = 100.0 }, status_size, ray.GRAY);
            ray.DrawText(&buf, 100, 100, 16, ray.BLACK);
        }
        times += 1;
    }
}
