const std = @import("std");
pub fn hashmap(comptime key: type, comptime value: type, comptime hashFunc: fn (key) usize) type {
    return struct {
        const This = @This();
        const max_fullness: f32 = 0.23;
        const Entry = struct {
            key: Key, value: Value
        };
        const Iterator = struct {
            parent: *This,
            tablePosition: usize,
            bucketPosition: usize,

            pub fn next(it: *Iterator) ?*Entry {
                return null;
            }
        };
        allocator: *std.mem.Allocator,
        table: std.ArrayList(std.ArrayList(Entry)),
        pub fn init(allocator: *std.mem.Allocator) This {
            return .{ .allocator = allocator, .table = std.ArrayList(std.ArrayList(Entry)).init(allocator) };
        }
        fn findInBucket(bucket: *std.ArrayList(Entry), key: Key) ?*Entry {
            for (bucket.items) |*item| {
                if (item.key == key)
                    return item;
            }
            return null;
        }
        pub fn deleteKey(this: *This, key: Key) bool;
        pub fn keyIsMember(this: *This, key: Key) ?*Entry;
        pub fn insert(this: *This, key: Key, value: Value) !*Entry {
            var hashed: usize = hashFunc(key);
            var table = this.table;
            var found = this.findInBucket(table[hashed % table.len], key);
            if (found != null) {
                found.?.value = value;
                return found.?;
            }
            var newEntry = try table[hash % table.items.len].addOne();
            newEntry.* = .{ .key = key, .value = value };
            return newEntry;
        }
        fn next_size(this: *const This) usize {
            if (this.table.items.len == 0)
                return 0;
        }
        fn rehash(this: *This, newsize: usize) !void;
        fn fullness(this: *const This) f32 {
            var s: f32;
            for (this.table.items) |*bucket| {
                s += bucket.items.len;
            }
        }
    };
}
pub fn main() void {}
