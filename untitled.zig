const std = @import("std");

pub fn hashmap(comptime Key: type, comptime Value: type, comptime hashFunc: fn (Key) usize) type {
    return struct {
        const This = @This();
        const Tuple = struct {
            key: Key, value: Value, next: ?*Tuple
        };
        alloc: *std.mem.Allocator,
        buckets: usize,
        table: []?*Tuple,
        sizes: []usize,
        fn nextSize(this: *This) usize {
            if (this.buckets == 0)
                return 1;
            return std.math.floor(buckets * 1.5);
        }
        pub fn init(alloc: *std.mem.Allocator) !This {
            var table = try alloc.alloc(?*Tuple, 10);
            var sizes = try alloc.alloc(usize, 10);
            var i: usize = 0;
            while (i < 10) {
                table[i] = null;
                sizes[i] = 0;
                i += 1;
            }
            return This{ .alloc = alloc, .buckets = 10, .table = table, .sizes = sizes };
        }
        pub fn set(this: *This, k: Key, v: Value) !void {
            var hash = hashFunc(k);
            if (this.table[hash % this.buckets] == null) {
                var new = try this.alloc.create(Tuple);
                this.table[hash % this.buckets] = new;
                new.* = .{ .value = v, .key = k, .next = null };
            } else {
                var tloc: ?*Tuple = this.table[hash % this.buckets];
                if (tloc != null) {
                    var t = tloc.?;
                    while (t.next != null) {
                        if (t.key == k) {
                            t.value = v;
                            return;
                        }
                        if (t.next == null) break;
                        t = t.next.?;
                    }
                    var newnode = try this.alloc.create(Tuple);
                    newnode.* = .{ .key = k, .value = v, .next = null };
                    t.next = newnode;
                    this.sizes[hash % this.buckets] += 1;
                } else {
                    var newnode = try this.alloc.create(Tuple);
                    newnode.* = .{ .key = k, .value = v, .next = null };
                    this.table[hash % this.buckets] = newnode;
                }
            }
        }
        pub fn destroy(this: *This) void {
            defer this.alloc.free(this.table);
            defer this.alloc.free(this.sizes);
            var i: usize = 0;
            while (i < this.buckets) {
                if (this.table[i] != null) {
                    var q: usize = 0;
                    var t = this.table[i].?;
                    while (t.next != null) {
                        var c: *Tuple = t;
                        if (t.next == null)
                            break;
                        t = t.next.?;
                        this.alloc.destroy(c);
                        q += 1;
                    }
                    this.alloc.destroy(t);
                }
                i += 1;
            }
        }
        pub fn get(this: *This, k: Key) ?Value {
            var hash = hashFunc(k);
            var table_entry = this.table[hash % this.buckets];
            if (table_entry == null)
                return null;
            while (table_entry != null) {
                if (table_entry.?.key == k) {
                    return table_entry.?.value;
                }
                table_entry = table_entry.?.next;
            }
            return null;
        }
    };
}
pub fn intHash(i: i32) usize {
    var hash: usize = @intCast(usize, i ^ i << 5);
    return hash;
}
fn arraylist_user() !std.ArrayList(i32) {
    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpalloc.deinit();
    const gpa = &gpalloc.allocator;
    var al = std.ArrayList(i32).init(gpa);
    var i = 0;
    while (i < 100) {
        try al.addOne(i);
        i += 1;
    }
    return al;
}
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var i: usize = 1;
    while (i < 10) {
        try stdout.print("{}\n", .{i});
        i += 1;
    }

}
test "Testing setting shit" {
    var talloc = std.testing.allocator;
    var assert = std.debug.assert;
    var ht = try hashmap(i32, i32, intHash).init(talloc);
    defer ht.destroy();
    try ht.set(12, 10);
    var i: i32 = 0;
    while (i < 100) {
        try ht.set(i, i);
        assert(ht.get(i) == i);
        i += 1;
    }
}
