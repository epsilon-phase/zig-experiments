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

var current_state = struct{
    display_mass: bool,
};
pub fn main() void {
    current_state.display_mass = false;
}
