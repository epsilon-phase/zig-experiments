const std = @import("std");
fn arraylist_user(alloc: *std.mem.Allocator) !std.ArrayList(i32) {
    var al = std.ArrayList(i32).init(alloc);
    var i: i32 = 0;
    while (i < 100) {
        var item = try al.addOne();
        item.* = i;
        i += 1;
    }
    return al;
}
pub fn main() !void {
    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpalloc.deinit());
    const gpa = &gpalloc.allocator;
    const stdout = std.io.getStdOut().writer();
    var array_list = try arraylist_user(gpa);
    defer array_list.deinit();
    for (array_list.items) |*item| {
        try stdout.print("{}\n", .{item.*});
    }
}
