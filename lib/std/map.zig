const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const testing = std.testing;

const Color = enum {
    Red,
    Black,
};

/// Generic Map implementation (Red Black Tree similar to std::map)
pub fn Map(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        const Node = struct {
            key: K,
            value: V,
            color: Color,
            left: ?*Node,
            right: ?*Node,
            parent: ?*Node,

            fn init(allocator: Allocator, key: K, value: V) !*Node {
                const node = try allocator.create(Node);
                node.* = Node{
                    .key = key,
                    .value = value,
                    .color = Color.Red,
                    .left = null,
                    .right = null,
                    .parent = null,
                };
                return node;
            }
        };

        pub const Entry = struct {
            key: K,
            value: V,
        };

        pub const Iterator = struct {
            current: ?*Node,

            pub fn next(self: *Iterator) ?Entry {
                if (self.current) |node| {
                    const entry = Entry{ .key = node.key, .value = node.value };
                    self.current = successor(node);
                    return entry;
                }
                return null;
            }
        };

        allocator: Allocator,
        root: ?*Node,
        node_count: usize,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .root = null,
                .node_count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.clear();
        }

        pub fn clear(self: *Self) void {
            if (self.root) |root| {
                self.destroySubtree(root);
                self.root = null;
                self.node_count = 0;
            }
        }

        fn destroySubtree(self: *Self, node: *Node) void {
            if (node.left) |left| {
                self.destroySubtree(left);
            }
            if (node.right) |right| {
                self.destroySubtree(right);
            }
            self.allocator.destroy(node);
        }

        pub fn empty(self: *const Self) bool {
            return self.node_count == 0;
        }

        pub fn size(self: *const Self) usize {
            return self.node_count;
        }

        pub fn insert(self: *Self, key: K, value: V) !void {
            if (self.root == null) {
                self.root = try Node.init(self.allocator, key, value);
                self.root.?.color = Color.Black;
                self.node_count = 1;
                return;
            }

            var current = self.root.?;
            var parent: ?*Node = null;

            while (true) {
                parent = current;
                if (self.compare(key, current.key) < 0) {
                    if (current.left) |left| {
                        current = left;
                    } else {
                        current.left = try Node.init(self.allocator, key, value);
                        current.left.?.parent = current;
                        self.insertFixup(current.left.?);
                        self.node_count += 1;
                        return;
                    }
                } else if (self.compare(key, current.key) > 0) {
                    if (current.right) |right| {
                        current = right;
                    } else {
                        current.right = try Node.init(self.allocator, key, value);
                        current.right.?.parent = current;
                        self.insertFixup(current.right.?);
                        self.node_count += 1;
                        return;
                    }
                } else {
                    current.value = value;
                    return;
                }
            }
        }

        pub fn getOrPut(self: *Self, key: K, default: V) !*V {
            if (self.findNode(key)) |node| {
                return &node.value;
            } else {
                try self.insert(key, default);
                return &self.findNode(key).?.value;
            }
        }

        pub fn get(self: *const Self, key: K) ?V {
            if (self.findNode(key)) |node| {
                return node.value;
            }
            return null;
        }

        pub fn getPtr(self: *Self, key: K) ?*V {
            if (self.findNode(key)) |node| {
                return &node.value;
            }
            return null;
        }

        pub fn contains(self: *const Self, key: K) bool {
            return self.findNode(key) != null;
        }

        pub fn count(self: *const Self, key: K) usize {
            return if (self.contains(key)) 1 else 0;
        }

        pub fn erase(self: *Self, key: K) bool {
            if (self.findNode(key)) |node| {
                self.deleteNode(node);
                self.node_count -= 1;
                return true;
            }
            return false;
        }

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{ .current = self.minimum(self.root) };
        }

        fn compare(self: *const Self, a: K, b: K) i32 {
            _ = self;

            switch (@typeInfo(K)) {
                .int, .float => {
                    if (a < b) return -1;
                    if (a > b) return 1;
                    return 0;
                },
                .pointer => |ptr_info| {
                    if (ptr_info.child == u8) {
                        return switch (std.mem.order(u8, a, b)) {
                            .lt => -1,
                            .eq => 0,
                            .gt => 1,
                        };
                    } else {
                        @compileError("Unsupported pointer type for Map key");
                    }
                },
                .array => |arr_info| {
                    if (arr_info.child == u8) {
                        return switch (std.mem.order(u8, &a, &b)) {
                            .lt => -1,
                            .eq => 0,
                            .gt => 1,
                        };
                    } else {
                        @compileError("Unsupported array type for Map key");
                    }
                },
                .bool => {
                    if (a == b) return 0;
                    if (!a and b) return -1;
                    return 1;
                },
                else => @compileError("Unsupported key type for Map: " ++ @typeName(K)),
            }
        }

        fn findNode(self: *const Self, key: K) ?*Node {
            var current = self.root;
            while (current) |node| {
                const cmp = self.compare(key, node.key);
                if (cmp == 0) {
                    return node;
                } else if (cmp < 0) {
                    current = node.left;
                } else {
                    current = node.right;
                }
            }
            return null;
        }

        fn minimum(self: *const Self, node: ?*Node) ?*Node {
            _ = self;
            var current = node;
            while (current) |n| {
                if (n.left) |left| {
                    current = left;
                } else {
                    break;
                }
            }
            return current;
        }

        fn successor(node: *Node) ?*Node {
            if (node.right) |right| {
                var current = right;
                while (current.left) |left| {
                    current = left;
                }
                return current;
            }

            var current: ?*Node = node;
            var parent = node.parent;
            while (parent != null and current == parent.?.right) {
                current = parent;
                parent = parent.?.parent;
            }
            return parent;
        }

        fn insertFixup(self: *Self, node: *Node) void {
            var z = node;
            while (z.parent != null and z.parent.?.color == Color.Red) {
                if (z.parent == z.parent.?.parent.?.left) {
                    const uncle = z.parent.?.parent.?.right;
                    if (uncle != null and uncle.?.color == Color.Red) {
                        z.parent.?.color = Color.Black;
                        uncle.?.color = Color.Black;
                        z.parent.?.parent.?.color = Color.Red;
                        z = z.parent.?.parent.?;
                    } else {
                        if (z == z.parent.?.right) {
                            z = z.parent.?;
                            self.leftRotate(z);
                        }
                        z.parent.?.color = Color.Black;
                        z.parent.?.parent.?.color = Color.Red;
                        self.rightRotate(z.parent.?.parent.?);
                    }
                } else {
                    const uncle = z.parent.?.parent.?.left;
                    if (uncle != null and uncle.?.color == Color.Red) {
                        z.parent.?.color = Color.Black;
                        uncle.?.color = Color.Black;
                        z.parent.?.parent.?.color = Color.Red;
                        z = z.parent.?.parent.?;
                    } else {
                        if (z == z.parent.?.left) {
                            z = z.parent.?;
                            self.rightRotate(z);
                        }
                        z.parent.?.color = Color.Black;
                        z.parent.?.parent.?.color = Color.Red;
                        self.leftRotate(z.parent.?.parent.?);
                    }
                }
            }
            self.root.?.color = Color.Black;
        }

        fn leftRotate(self: *Self, x: *Node) void {
            const y = x.right.?;
            x.right = y.left;
            if (y.left) |left| {
                left.parent = x;
            }
            y.parent = x.parent;
            if (x.parent == null) {
                self.root = y;
            } else if (x == x.parent.?.left) {
                x.parent.?.left = y;
            } else {
                x.parent.?.right = y;
            }
            y.left = x;
            x.parent = y;
        }

        fn rightRotate(self: *Self, x: *Node) void {
            const y = x.left.?;
            x.left = y.right;
            if (y.right) |right| {
                right.parent = x;
            }
            y.parent = x.parent;
            if (x.parent == null) {
                self.root = y;
            } else if (x == x.parent.?.right) {
                x.parent.?.right = y;
            } else {
                x.parent.?.left = y;
            }
            y.right = x;
            x.parent = y;
        }

        fn deleteNode(self: *Self, z: *Node) void {
            var y = z;
            var y_original_color = y.color;
            var x: ?*Node = null;

            if (z.left == null) {
                x = z.right;
                self.transplant(z, z.right);
            } else if (z.right == null) {
                x = z.left;
                self.transplant(z, z.left);
            } else {
                y = self.minimum(z.right).?;
                y_original_color = y.color;
                x = y.right;
                if (y.parent == z) {
                    if (x) |node| {
                        node.parent = y;
                    }
                } else {
                    self.transplant(y, y.right);
                    y.right = z.right;
                    y.right.?.parent = y;
                }
                self.transplant(z, y);
                y.left = z.left;
                y.left.?.parent = y;
                y.color = z.color;
            }

            if (y_original_color == Color.Black) {
                self.deleteFixup(x);
            }

            self.allocator.destroy(z);
        }

        fn transplant(self: *Self, u: *Node, v: ?*Node) void {
            if (u.parent == null) {
                self.root = v;
            } else if (u == u.parent.?.left) {
                u.parent.?.left = v;
            } else {
                u.parent.?.right = v;
            }
            if (v) |node| {
                node.parent = u.parent;
            }
        }

        fn deleteFixup(self: *Self, x: ?*Node) void {
            var node = x;
            var x_parent: ?*Node = null;

            if (node) |n| {
                x_parent = n.parent;
            }

            while (node != self.root and (node == null or node.?.color == Color.Black)) {
                const parent = if (node) |n| n.parent else x_parent;

                if (parent == null) break;

                if (node == node.?.parent.?.left) {
                    var w = node.?.parent.?.right.?;
                    if (w.color == Color.Red) {
                        w.color = Color.Black;
                        node.?.parent.?.color = Color.Red;
                        self.leftRotate(node.?.parent.?);
                        w = node.?.parent.?.right.?;
                    }
                    if ((w.left == null or w.left.?.color == Color.Black) and
                        (w.right == null or w.right.?.color == Color.Black))
                    {
                        w.color = Color.Red;
                        node = node.?.parent;
                    } else {
                        if (w.right == null or w.right.?.color == Color.Black) {
                            if (w.left) |left| {
                                left.color = Color.Black;
                            }
                            w.color = Color.Red;
                            self.rightRotate(w);
                            w = node.?.parent.?.right.?;
                        }
                        w.color = node.?.parent.?.color;
                        node.?.parent.?.color = Color.Black;
                        if (w.right) |right| {
                            right.color = Color.Black;
                        }
                        self.leftRotate(node.?.parent.?);
                        node = self.root;
                    }
                } else {
                    var w = node.?.parent.?.left.?;
                    if (w.color == Color.Red) {
                        w.color = Color.Black;
                        node.?.parent.?.color = Color.Red;
                        self.rightRotate(node.?.parent.?);
                        w = node.?.parent.?.left.?;
                    }
                    if ((w.right == null or w.right.?.color == Color.Black) and
                        (w.left == null or w.left.?.color == Color.Black))
                    {
                        w.color = Color.Red;
                        node = node.?.parent;
                    } else {
                        if (w.left == null or w.left.?.color == Color.Black) {
                            if (w.right) |right| {
                                right.color = Color.Black;
                            }
                            w.color = Color.Red;
                            self.leftRotate(w);
                            w = node.?.parent.?.left.?;
                        }
                        w.color = node.?.parent.?.color;
                        node.?.parent.?.color = Color.Black;
                        if (w.left) |left| {
                            left.color = Color.Black;
                        }
                        self.rightRotate(node.?.parent.?);
                        node = self.root;
                    }
                }
            }
            if (node) |n| {
                n.color = Color.Black;
            }
        }
    };
}

fn printMap(comment: []const u8, m: *const Map([]const u8, i32)) void {
    print("{s}", .{comment});
    var iter = m.iterator();
    while (iter.next()) |entry| {
        print("[{s}] = {}; ", .{ entry.key, entry.value });
    }
    print("\n", .{});
}

test "Map initialization and basic properties" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try testing.expect(map.empty());
    try testing.expectEqual(@as(usize, 0), map.size());
}

test "Map single insertion and retrieval" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("hello", 42);

    try testing.expect(!map.empty());
    try testing.expectEqual(@as(usize, 1), map.size());
    try testing.expect(map.contains("hello"));
    try testing.expectEqual(@as(i32, 42), map.get("hello").?);
    try testing.expectEqual(@as(usize, 1), map.count("hello"));
}

test "Map multiple insertions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("apple", 1);
    try map.insert("banana", 2);
    try map.insert("cherry", 3);
    try map.insert("date", 4);
    try map.insert("elderberry", 5);

    try testing.expectEqual(@as(usize, 5), map.size());
    try testing.expectEqual(@as(i32, 1), map.get("apple").?);
    try testing.expectEqual(@as(i32, 2), map.get("banana").?);
    try testing.expectEqual(@as(i32, 3), map.get("cherry").?);
    try testing.expectEqual(@as(i32, 4), map.get("date").?);
    try testing.expectEqual(@as(i32, 5), map.get("elderberry").?);
}

test "Map key update (overwrite existing key)" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("key", 10);
    try testing.expectEqual(@as(i32, 10), map.get("key").?);
    try testing.expectEqual(@as(usize, 1), map.size());

    try map.insert("key", 20);
    try testing.expectEqual(@as(i32, 20), map.get("key").?);
    try testing.expectEqual(@as(usize, 1), map.size());
}

test "Map non-existent key retrieval" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("exists", 42);

    try testing.expect(map.get("nonexistent") == null);
    try testing.expect(!map.contains("nonexistent"));
    try testing.expectEqual(@as(usize, 0), map.count("nonexistent"));
}

test "Map erase functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("a", 1);
    try map.insert("b", 2);
    try map.insert("c", 3);

    try testing.expectEqual(@as(usize, 3), map.size());

    try testing.expect(map.erase("b"));
    try testing.expectEqual(@as(usize, 2), map.size());
    try testing.expect(!map.contains("b"));
    try testing.expect(map.get("b") == null);

    try testing.expect(!map.erase("nonexistent"));
    try testing.expectEqual(@as(usize, 2), map.size());

    try testing.expect(map.contains("a"));
    try testing.expect(map.contains("c"));
}

test "Map clear functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("x", 1);
    try map.insert("y", 2);
    try map.insert("z", 3);

    try testing.expectEqual(@as(usize, 3), map.size());
    try testing.expect(!map.empty());

    map.clear();

    try testing.expectEqual(@as(usize, 0), map.size());
    try testing.expect(map.empty());
    try testing.expect(!map.contains("x"));
    try testing.expect(!map.contains("y"));
    try testing.expect(!map.contains("z"));
}

test "Map getOrPut functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    const value_ptr1 = try map.getOrPut("new_key");
    try testing.expectEqual(@as(i32, 0), value_ptr1.*); // Default value
    try testing.expectEqual(@as(usize, 1), map.size());

    value_ptr1.* = 100;
    try testing.expectEqual(@as(i32, 100), map.get("new_key").?);

    const value_ptr2 = try map.getOrPut("new_key");
    try testing.expectEqual(@as(i32, 100), value_ptr2.*);
    try testing.expectEqual(@as(usize, 1), map.size()); // Size shouldn't change
}

test "Map iterator functionality" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    var empty_iter = map.iterator();
    try testing.expect(empty_iter.next() == null);

    try map.insert("gamma", 3);
    try map.insert("alpha", 1);
    try map.insert("beta", 2);

    var iter = map.iterator();
    var count: usize = 0;
    var keys_found = std.ArrayList([]const u8).init(allocator);
    defer keys_found.deinit();

    while (iter.next()) |entry| {
        count += 1;
        try keys_found.append(entry.key);
    }

    try testing.expectEqual(@as(usize, 3), count);
    try testing.expectEqual(@as(usize, 3), keys_found.items.len);

    try testing.expectEqualStrings("alpha", keys_found.items[0]);
    try testing.expectEqualStrings("beta", keys_found.items[1]);
    try testing.expectEqualStrings("gamma", keys_found.items[2]);
}

test "Map with integer keys" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map(i32, []const u8).init(allocator);
    defer map.deinit();

    try map.insert(100, "hundred");
    try map.insert(50, "fifty");
    try map.insert(150, "one-fifty");
    try map.insert(25, "twenty-five");
    try map.insert(75, "seventy-five");

    try testing.expectEqual(@as(usize, 5), map.size());
    try testing.expectEqualStrings("fifty", map.get(50).?);
    try testing.expectEqualStrings("hundred", map.get(100).?);
    try testing.expect(map.contains(25));
    try testing.expect(!map.contains(200));
}

test "Map stress test - many insertions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map(i32, i32).init(allocator);
    defer map.deinit();

    const num_elements = 1000;

    for (0..num_elements) |i| {
        try map.insert(@intCast(i), @intCast(i * 2));
    }

    try testing.expectEqual(@as(usize, num_elements), map.size());

    for (0..num_elements) |i| {
        const key: i32 = @intCast(i);
        const expected_value: i32 = @intCast(i * 2);
        try testing.expect(map.contains(key));
        try testing.expectEqual(expected_value, map.get(key).?);
    }
}

test "Map stress test - insertions and deletions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map(i32, i32).init(allocator);
    defer map.deinit();

    const num_elements = 500;

    for (0..num_elements) |i| {
        try map.insert(@intCast(i), @intCast(i));
    }

    try testing.expectEqual(@as(usize, num_elements), map.size());

    var deleted_count: usize = 0;
    for (0..num_elements) |i| {
        if (i % 2 == 0) {
            const key: i32 = @intCast(i);
            try testing.expect(map.erase(key));
            deleted_count += 1;
        }
    }

    try testing.expectEqual(@as(usize, num_elements - deleted_count), map.size());

    for (0..num_elements) |i| {
        const key: i32 = @intCast(i);
        if (i % 2 == 0) {
            try testing.expect(!map.contains(key));
        } else {
            try testing.expect(map.contains(key));
            try testing.expectEqual(key, map.get(key).?);
        }
    }
}

test "Map iterator after modifications" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map(i32, i32).init(allocator);
    defer map.deinit();

    try map.insert(5, 50);
    try map.insert(3, 30);
    try map.insert(7, 70);
    try map.insert(1, 10);
    try map.insert(9, 90);

    try testing.expect(map.erase(3));

    var iter = map.iterator();
    var count: usize = 0;
    var sum: i32 = 0;

    while (iter.next()) |entry| {
        count += 1;
        sum += entry.key;
    }

    try testing.expectEqual(@as(usize, 4), count);
    try testing.expectEqual(@as(i32, 1 + 5 + 7 + 9), sum);
}

test "Map edge cases - single element operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map(i32, i32).init(allocator);
    defer map.deinit();

    try map.insert(42, 84);
    try testing.expectEqual(@as(usize, 1), map.size());
    try testing.expectEqual(@as(i32, 84), map.get(42).?);

    var iter = map.iterator();
    const entry = iter.next().?;
    try testing.expectEqual(@as(i32, 42), entry.key);
    try testing.expectEqual(@as(i32, 84), entry.value);
    try testing.expect(iter.next() == null);

    try testing.expect(map.erase(42));
    try testing.expectEqual(@as(usize, 0), map.size());
    try testing.expect(map.empty());
}

test "Map duplicate key handling" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("duplicate", 1);
    try map.insert("duplicate", 2);
    try map.insert("duplicate", 3);

    try testing.expectEqual(@as(usize, 1), map.size());
    try testing.expectEqual(@as(i32, 3), map.get("duplicate").?);
}

test "Map with different value types" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var bool_map = Map([]const u8, bool).init(allocator);
    defer bool_map.deinit();

    try bool_map.insert("true_key", true);
    try bool_map.insert("false_key", false);

    try testing.expect(bool_map.get("true_key").?);
    try testing.expect(!bool_map.get("false_key").?);

    var float_map = Map([]const u8, f64).init(allocator);
    defer float_map.deinit();

    try float_map.insert("pi", 3.14159);
    try float_map.insert("e", 2.71828);

    try testing.expectApproxEqRel(@as(f64, 3.14159), float_map.get("pi").?, 0.00001);
    try testing.expectApproxEqRel(@as(f64, 2.71828), float_map.get("e").?, 0.00001);
}

test "Map sequential operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = Map([]const u8, i32).init(allocator);
    defer map.deinit();

    try map.insert("first", 1);
    try testing.expectEqual(@as(i32, 1), map.get("first").?);

    try map.insert("second", 2);
    try testing.expectEqual(@as(usize, 2), map.size());

    try testing.expect(map.erase("first"));
    try testing.expectEqual(@as(usize, 1), map.size());
    try testing.expect(!map.contains("first"));
    try testing.expect(map.contains("second"));

    map.clear();
    try testing.expect(map.empty());

    try map.insert("new", 100);
    try testing.expectEqual(@as(usize, 1), map.size());
    try testing.expectEqual(@as(i32, 100), map.get("new").?);
}
