const std = @import("std");
const gpa = std.heap.GeneralPurposeHeapAllocator;

const linked_list = struct {
    const This = @This();
    const node = struct {
        value: i32,
        next: ?*node,
        pub fn reverse(from: ?*node, to: ?*node) ?*node {
            if (to == null) return from;
            var n = to.?.next;
            to.?.next = from;
            return reverse(to, n);
        }
    };
    const Iterator = struct {
        const Iterator = @This();
        current: ?*node,
        pub fn next(iter: *Iterator) ?*i32 {
            if (iter.current == null)
                return null;
            var value = &iter.current.?.value;
            iter.current = iter.current.?.next;
            return value;
        }
    };
    root: ?*node,
    allocator: *std.mem.Allocator,
    pub fn push(this: *This, value: i32) !void {
        var c = this.root;
        var new = try this.allocator.create(This.node);
        new.value = value;
        new.next = this.root;
        this.root = new;
    }
    pub fn init(alloc: *std.mem.Allocator) This {
        return .{ .root = null, .allocator = alloc };
    }
    pub fn reverse(this: *This) void {
        this.root = node.reverse(null, this.root);
    }
    pub fn iterator(this: *This) Iterator {
        return .{ .current = this.root };
    }
};
test "Pushing works" {
    const expect = std.testing.expect;
    var c: i32 = 0;
    var buffer: [400]u8 = undefined;
    const alloc = &std.heap.FixedBufferAllocator.init(&buffer).allocator;
    var list = linked_list.init(alloc);
    const pre_reverse = [_]i32{ 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 };
    var i: usize = 0;
    c = 0;
    while (c < 10) {
        try list.push(c);
        c += 1;
    }
    var iter = list.iterator();
    while (iter.next()) |v| {
        // std.debug.print("{}\n", .{v.*});
        expect(v.* == pre_reverse[i]);
        i += 1;
    }
    expect(i == 10);
    list.reverse();
    iter = list.iterator();
    i = 0;
    const reversed = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    while (iter.next()) |v| {
        // std.debug.print("{}\n", .{v.*});
        expect(v.* == reversed[i]);
        i += 1;
    }
    expect(i == 10);
}
