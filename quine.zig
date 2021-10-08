const std = @import("std");
const file = @embedFile("quine.zig");
pub fn main() !void {
    std.debug.print("{s}", .{file});
}
