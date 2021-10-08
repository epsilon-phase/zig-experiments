const std = @import("std");
const math = std.math;
pub const ray = @cImport({
    @cInclude("raylib.h");
});
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

// An arbitrarly large vector of a given type. Supports most arithmetic operations
pub fn NVec(comptime value: type, comptime dimensions: u32) type {
    return struct {
        comptime {
            @setFloatMode(.Optimized);
        }
        const This = @This();
        v: [dimensions]value,
        pub fn add(a: This, b: This) This {
            var r: This = undefined;
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                r.v[i] = a.v[i] + b.v[i];
            }
            return r;
        }
        pub fn zero() This {
            var a: This = undefined;
            for (a.v) |*i| {
                i.* = 0;
            }
            return a;
        }
        pub fn sub(a: This, b: This) This {
            var r: This = undefined;
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                r.v[i] = a.v[i] - b.v[i];
            }
            return r;
        }
        pub fn scale(a: This, s: value) This {
            var r = a;
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                r.v[i] = a.v[i] * s;
            }
            return r;
        }
        pub fn dot(a: This, b: This) value {
            comptime var i: usize = 0;
            var r: value = 0;
            inline while (i < dimensions) : (i += 1) {
                r += a.v[i] * b.v[i];
            }
            return r;
        }
        pub fn distance(a: This, b: This) value {
            var s: value = 0;
            var i: usize = 0;
            while (i < dimensions) : (i += 1) {
                const c = a.v[i] - b.v[i];
                s += c * c;
            }
            return @sqrt(s);
        }
        pub fn magnitude(a: This) value {
            var z: This = undefined;
            for (z.v) |*c| {
                c.* = 0;
            }
            return a.distance(z);
        }
        pub fn normalize(a: This) This {
            return a.scale(1.0 / a.magnitude());
        }
        pub fn random(minimum: This, maximum: This, rand: *std.rand.Random) This {
            var r: This = undefined;
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                r.v[i] = minimum.v[i] + (maximum.v[i] - minimum.v[i]) * rand.float(value);
            }
            return r;
        }
        pub fn wrap(c: This, a: This, b: This) This {
            var r: This = c;
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                if (r.v[i] < a.v[i])
                    r.v[i] = b.v[i];
                if (r.v[i] > b.v[i])
                    r.v[i] = a.v[i];
            }
            return r;
        }
        usingnamespace if (dimensions >= 2) struct {
            pub fn y(a: *This) value {
                return &a.v[1];
            }
        } else struct {};
        pub fn eq(a: This, b: This) bool {
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                if (a.v[i] != b.v[i])
                    return false;
            }
            return true;
        }
        usingnamespace if (dimensions == 2 or dimensions == 3) struct {
            const raylibType = if (dimensions == 2) ray.Vector2 else ray.Vector3;
            pub fn toRaylib(a: This) raylibType {
                var r: raylibType = undefined;
                r.x = @floatCast(f32, a.v[0]);
                r.y = @floatCast(f32, a.v[1]);
                comptime if (dimensions == 3) {
                    r.z = @floatCast(f32, a.v[2]);
                };
                return r;
            }
        } else struct {};
        pub fn format(val: This, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.print("{{", .{});
            const names = .{ "x", "y", "z", "w", "t", "u", "v" };
            comptime var i: usize = 0;
            inline while (i < dimensions) : (i += 1) {
                try writer.print("{s}={}", .{ names[i], val.v[i] });
                if (i != dimensions - 1) {
                    try writer.print(", ", .{});
                }
            }
            try writer.print("}}", .{});
        }
        pub const region = struct {
            min: This,
            max: This,
            pub fn getRandomPoint(a: This.region, rand: *std.rand.Random) This {
                return This.random(a.min, a.max, rand);
            }
        };
    };
}
test "nvector additions" {
    const v2 = NVec(f32, 2);
    const expect = std.testing.expect;
    var a: v2 = .{ .v = [2]f32{ 0, 0 } };
    var b: v2 = .{ .v = [2]f32{ 1, 1 } };
    try expect(a.add(b).eq(.{ .v = [2]f32{ 1, 1 } }));
    try expect(!a.add(b).eq(.{ .v = [2]f32{ 2, 2 } }));
}
test "dot" {
    const v2 = NVec(f32, 2);
    const expect = std.testing.expect;
    var b: v2 = .{ .v = [2]f32{ 1, 1 } };
    try expect(b.dot(.{ .v = [2]f32{ 2, 2 } }) == 4.0);
}

test "magnitude" {
    const v2 = NVec(f32, 2);
    const expect = std.testing.expect;
    var a: v2 = .{ .v = [2]f32{ 1, 0 } };
    try expect(a.magnitude() == 1);
    a.v[1] = 1;
    try expect(a.magnitude() == @sqrt(2.0));
}

test "Wrap" {
    const v2 = NVec(f32, 2);
    const expect = std.testing.expect;
    var reg: v2.region = .{ .min = .{ .v = [2]f32{ -1, -1 } }, .max = .{ .v = [2]f32{ 1, 1 } } };
    var a: v2 = .{ .v = [2]f32{ 2, 0 } };
    var b: v2 = .{ .v = [2]f32{ -2, 0 } };
    try expect(a.wrap(reg.min, reg.max).eq(.{ .v = [2]f32{ -1, 0 } }));
    try expect(b.wrap(reg.min, reg.max).eq(.{ .v = [2]f32{ 1, 0 } }));
}

test "Format" {
    const v2 = NVec(f32, 2);
    const expect = std.testing.expect;
    var a: v2 = .{ .v = [2]f32{ 0, 0 } };
    var t = std.testing.expectFmt("{x=0.0e+00, y=0.0e+00}", "{}", .{a});
}
