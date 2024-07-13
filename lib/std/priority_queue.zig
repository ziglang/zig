const std = @import("std.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Order = std.math.Order;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

/// Priority queue for storing generic data. Initialize with `init`.
/// Provide `compareFn` that returns `Order.lt` when its second
/// argument should get popped before its third argument,
/// `Order.eq` if the arguments are of equal priority, or `Order.gt`
/// if the third argument should be popped first.
/// For example, to make `pop` return the smallest number, provide
/// `fn lessThan(context: void, a: T, b: T) Order { _ = context; return std.math.order(a, b); }`
pub fn PriorityQueue(comptime T: type, comptime Context: type, comptime compareFn: fn (context: Context, a: T, b: T) Order) type {
    return struct {
        const Self = @This();

        items: []T,
        cap: usize,
        allocator: Allocator,
        context: Context,

        /// Initialize and return a priority queue.
        pub fn init(allocator: Allocator, context: Context) Self {
            return Self{
                .items = &[_]T{},
                .cap = 0,
                .allocator = allocator,
                .context = context,
            };
        }

        /// Free memory used by the queue.
        pub fn deinit(self: Self) void {
            self.allocator.free(self.allocatedSlice());
        }

        /// Insert a new element, maintaining priority.
        pub fn add(self: *Self, elem: T) !void {
            try self.ensureUnusedCapacity(1);
            addUnchecked(self, elem);
        }

        fn addUnchecked(self: *Self, elem: T) void {
            self.items.len += 1;
            self.items[self.items.len - 1] = elem;
            siftUp(self, self.items.len - 1);
        }

        fn siftUp(self: *Self, start_index: usize) void {
            const child = self.items[start_index];
            var child_index = start_index;
            while (child_index > 0) {
                const parent_index = ((child_index - 1) >> 1);
                const parent = self.items[parent_index];
                if (compareFn(self.context, child, parent) != .lt) break;
                self.items[child_index] = parent;
                child_index = parent_index;
            }
            self.items[child_index] = child;
        }

        /// Add each element in `items` to the queue.
        pub fn addSlice(self: *Self, items: []const T) !void {
            try self.ensureUnusedCapacity(items.len);
            for (items) |e| {
                self.addUnchecked(e);
            }
        }

        /// Look at the highest priority element in the queue. Returns
        /// `null` if empty.
        pub fn peek(self: *Self) ?T {
            return if (self.items.len > 0) self.items[0] else null;
        }

        /// Pop the highest priority element from the queue. Returns
        /// `null` if empty.
        pub fn removeOrNull(self: *Self) ?T {
            return if (self.items.len > 0) self.remove() else null;
        }

        /// Remove and return the highest priority element from the
        /// queue.
        pub fn remove(self: *Self) T {
            return self.removeIndex(0);
        }

        /// Remove and return element at index. Indices are in the
        /// same order as iterator, which is not necessarily priority
        /// order.
        pub fn removeIndex(self: *Self, index: usize) T {
            assert(self.items.len > index);
            const last = self.items[self.items.len - 1];
            const item = self.items[index];
            self.items[index] = last;
            self.items.len -= 1;

            if (index == self.items.len) {
                // Last element removed, nothing more to do.
            } else if (index == 0) {
                siftDown(self, index);
            } else {
                const parent_index = ((index - 1) >> 1);
                const parent = self.items[parent_index];
                if (compareFn(self.context, last, parent) == .gt) {
                    siftDown(self, index);
                } else {
                    siftUp(self, index);
                }
            }

            return item;
        }

        /// Return the number of elements remaining in the priority
        /// queue.
        pub fn count(self: Self) usize {
            return self.items.len;
        }

        /// Return the number of elements that can be added to the
        /// queue before more memory is allocated.
        pub fn capacity(self: Self) usize {
            return self.cap;
        }

        /// Returns a slice of all the items plus the extra capacity, whose memory
        /// contents are `undefined`.
        fn allocatedSlice(self: Self) []T {
            // `items.len` is the length, not the capacity.
            return self.items.ptr[0..self.cap];
        }

        fn siftDown(self: *Self, target_index: usize) void {
            const target_element = self.items[target_index];
            var index = target_index;
            while (true) {
                var lesser_child_i = (std.math.mul(usize, index, 2) catch break) | 1;
                if (!(lesser_child_i < self.items.len)) break;

                const next_child_i = lesser_child_i + 1;
                if (next_child_i < self.items.len and compareFn(self.context, self.items[next_child_i], self.items[lesser_child_i]) == .lt) {
                    lesser_child_i = next_child_i;
                }

                if (compareFn(self.context, target_element, self.items[lesser_child_i]) == .lt) break;

                self.items[index] = self.items[lesser_child_i];
                index = lesser_child_i;
            }
            self.items[index] = target_element;
        }

        /// PriorityQueue takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit`.
        pub fn fromOwnedSlice(allocator: Allocator, items: []T, context: Context) Self {
            var self = Self{
                .items = items,
                .cap = items.len,
                .allocator = allocator,
                .context = context,
            };

            var i = self.items.len >> 1;
            while (i > 0) {
                i -= 1;
                self.siftDown(i);
            }
            return self;
        }

        /// Ensure that the queue can fit at least `new_capacity` items.
        pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) !void {
            var better_capacity = self.cap;
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            const old_memory = self.allocatedSlice();
            const new_memory = try self.allocator.realloc(old_memory, better_capacity);
            self.items.ptr = new_memory.ptr;
            self.cap = new_memory.len;
        }

        /// Ensure that the queue can fit at least `additional_count` **more** item.
        pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) !void {
            return self.ensureTotalCapacity(self.items.len + additional_count);
        }

        /// Reduce allocated capacity to `new_capacity`.
        pub fn shrinkAndFree(self: *Self, new_capacity: usize) void {
            assert(new_capacity <= self.cap);

            // Cannot shrink to smaller than the current queue size without invalidating the heap property
            assert(new_capacity >= self.items.len);

            const old_memory = self.allocatedSlice();
            const new_memory = self.allocator.realloc(old_memory, new_capacity) catch |e| switch (e) {
                error.OutOfMemory => { // no problem, capacity is still correct then.
                    return;
                },
            };

            self.items.ptr = new_memory.ptr;
            self.cap = new_memory.len;
        }

        pub fn update(self: *Self, elem: T, new_elem: T) !void {
            const update_index = blk: {
                var idx: usize = 0;
                while (idx < self.items.len) : (idx += 1) {
                    const item = self.items[idx];
                    if (compareFn(self.context, item, elem) == .eq) break :blk idx;
                }
                return error.ElementNotFound;
            };
            const old_elem: T = self.items[update_index];
            self.items[update_index] = new_elem;
            switch (compareFn(self.context, new_elem, old_elem)) {
                .lt => siftUp(self, update_index),
                .gt => siftDown(self, update_index),
                .eq => {}, // Nothing to do as the items have equal priority
            }
        }

        pub const Iterator = struct {
            queue: *PriorityQueue(T, Context, compareFn),
            count: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.count >= it.queue.items.len) return null;
                const out = it.count;
                it.count += 1;
                return it.queue.items[out];
            }

            pub fn reset(it: *Iterator) void {
                it.count = 0;
            }
        };

        /// Return an iterator that walks the queue without consuming
        /// it. The iteration order may differ from the priority order.
        /// Invalidated if the heap is modified.
        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .queue = self,
                .count = 0,
            };
        }

        fn dump(self: *Self) void {
            const print = std.debug.print;
            print("{{ ", .{});
            print("items: ", .{});
            for (self.items) |e| {
                print("{}, ", .{e});
            }
            print("array: ", .{});
            for (self.items) |e| {
                print("{}, ", .{e});
            }
            print("len: {} ", .{self.items.len});
            print("capacity: {}", .{self.cap});
            print(" }}\n", .{});
        }
    };
}

fn lessThan(context: void, a: u32, b: u32) Order {
    _ = context;
    return std.math.order(a, b);
}

fn greaterThan(context: void, a: u32, b: u32) Order {
    return lessThan(context, a, b).invert();
}

const PQlt = PriorityQueue(u32, void, lessThan);
const PQgt = PriorityQueue(u32, void, greaterThan);

test "add and remove min heap" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(54);
    try queue.add(12);
    try queue.add(7);
    try queue.add(23);
    try queue.add(25);
    try queue.add(13);
    try expectEqual(@as(u32, 7), queue.remove());
    try expectEqual(@as(u32, 12), queue.remove());
    try expectEqual(@as(u32, 13), queue.remove());
    try expectEqual(@as(u32, 23), queue.remove());
    try expectEqual(@as(u32, 25), queue.remove());
    try expectEqual(@as(u32, 54), queue.remove());
}

test "add and remove same min heap" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(1);
    try queue.add(1);
    try queue.add(2);
    try queue.add(2);
    try queue.add(1);
    try queue.add(1);
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 2), queue.remove());
}

test "removeOrNull on empty" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try expect(queue.removeOrNull() == null);
}

test "edge case 3 elements" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(9);
    try queue.add(3);
    try queue.add(2);
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 3), queue.remove());
    try expectEqual(@as(u32, 9), queue.remove());
}

test "peek" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try expect(queue.peek() == null);
    try queue.add(9);
    try queue.add(3);
    try queue.add(2);
    try expectEqual(@as(u32, 2), queue.peek().?);
    try expectEqual(@as(u32, 2), queue.peek().?);
}

test "sift up with odd indices" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try queue.add(e);
    }

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.remove());
    }
}

test "addSlice" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try queue.addSlice(items[0..]);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.remove());
    }
}

test "fromOwnedSlice trivial case 0" {
    const items = [0]u32{};
    const queue_items = try testing.allocator.dupe(u32, &items);
    var queue = PQlt.fromOwnedSlice(testing.allocator, queue_items[0..], {});
    defer queue.deinit();
    try expectEqual(@as(usize, 0), queue.count());
    try expect(queue.removeOrNull() == null);
}

test "fromOwnedSlice trivial case 1" {
    const items = [1]u32{1};
    const queue_items = try testing.allocator.dupe(u32, &items);
    var queue = PQlt.fromOwnedSlice(testing.allocator, queue_items[0..], {});
    defer queue.deinit();

    try expectEqual(@as(usize, 1), queue.count());
    try expectEqual(items[0], queue.remove());
    try expect(queue.removeOrNull() == null);
}

test "fromOwnedSlice" {
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    const heap_items = try testing.allocator.dupe(u32, items[0..]);
    var queue = PQlt.fromOwnedSlice(testing.allocator, heap_items[0..], {});
    defer queue.deinit();

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.remove());
    }
}

test "add and remove max heap" {
    var queue = PQgt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(54);
    try queue.add(12);
    try queue.add(7);
    try queue.add(23);
    try queue.add(25);
    try queue.add(13);
    try expectEqual(@as(u32, 54), queue.remove());
    try expectEqual(@as(u32, 25), queue.remove());
    try expectEqual(@as(u32, 23), queue.remove());
    try expectEqual(@as(u32, 13), queue.remove());
    try expectEqual(@as(u32, 12), queue.remove());
    try expectEqual(@as(u32, 7), queue.remove());
}

test "add and remove same max heap" {
    var queue = PQgt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(1);
    try queue.add(1);
    try queue.add(2);
    try queue.add(2);
    try queue.add(1);
    try queue.add(1);
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
}

test "iterator" {
    var queue = PQlt.init(testing.allocator, {});
    var map = std.AutoHashMap(u32, void).init(testing.allocator);
    defer {
        queue.deinit();
        map.deinit();
    }

    const items = [_]u32{ 54, 12, 7, 23, 25, 13 };
    for (items) |e| {
        _ = try queue.add(e);
        try map.put(e, {});
    }

    var it = queue.iterator();
    while (it.next()) |e| {
        _ = map.remove(e);
    }

    try expectEqual(@as(usize, 0), map.count());
}

test "remove at index" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    const items = [_]u32{ 2, 1, 8, 9, 3, 4, 5 };
    for (items) |e| {
        _ = try queue.add(e);
    }

    var it = queue.iterator();
    var idx: usize = 0;
    const two_idx = while (it.next()) |elem| {
        if (elem == 2)
            break idx;
        idx += 1;
    } else unreachable;
    const sorted_items = [_]u32{ 1, 3, 4, 5, 8, 9 };
    try expectEqual(queue.removeIndex(two_idx), 2);

    var i: usize = 0;
    while (queue.removeOrNull()) |n| : (i += 1) {
        try expectEqual(n, sorted_items[i]);
    }
    try expectEqual(queue.removeOrNull(), null);
}

test "iterator while empty" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    var it = queue.iterator();

    try expectEqual(it.next(), null);
}

test "shrinkAndFree" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.ensureTotalCapacity(4);
    try expect(queue.capacity() >= 4);

    try queue.add(1);
    try queue.add(2);
    try queue.add(3);
    try expect(queue.capacity() >= 4);
    try expectEqual(@as(usize, 3), queue.count());

    queue.shrinkAndFree(3);
    try expectEqual(@as(usize, 3), queue.capacity());
    try expectEqual(@as(usize, 3), queue.count());

    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 3), queue.remove());
    try expect(queue.removeOrNull() == null);
}

test "update min heap" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(55);
    try queue.add(44);
    try queue.add(11);
    try queue.update(55, 5);
    try queue.update(44, 4);
    try queue.update(11, 1);
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 4), queue.remove());
    try expectEqual(@as(u32, 5), queue.remove());
}

test "update same min heap" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(1);
    try queue.add(1);
    try queue.add(2);
    try queue.add(2);
    try queue.update(1, 5);
    try queue.update(2, 4);
    try expectEqual(@as(u32, 1), queue.remove());
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 4), queue.remove());
    try expectEqual(@as(u32, 5), queue.remove());
}

test "update max heap" {
    var queue = PQgt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(55);
    try queue.add(44);
    try queue.add(11);
    try queue.update(55, 5);
    try queue.update(44, 1);
    try queue.update(11, 4);
    try expectEqual(@as(u32, 5), queue.remove());
    try expectEqual(@as(u32, 4), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
}

test "update same max heap" {
    var queue = PQgt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(1);
    try queue.add(1);
    try queue.add(2);
    try queue.add(2);
    try queue.update(1, 5);
    try queue.update(2, 4);
    try expectEqual(@as(u32, 5), queue.remove());
    try expectEqual(@as(u32, 4), queue.remove());
    try expectEqual(@as(u32, 2), queue.remove());
    try expectEqual(@as(u32, 1), queue.remove());
}

test "update after remove" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.add(1);
    try expectEqual(@as(u32, 1), queue.remove());
    try expectError(error.ElementNotFound, queue.update(1, 1));
}

test "siftUp in remove" {
    var queue = PQlt.init(testing.allocator, {});
    defer queue.deinit();

    try queue.addSlice(&.{ 0, 1, 100, 2, 3, 101, 102, 4, 5, 6, 7, 103, 104, 105, 106, 8 });

    _ = queue.removeIndex(std.mem.indexOfScalar(u32, queue.items[0..queue.count()], 102).?);

    const sorted_items = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 100, 101, 103, 104, 105, 106 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.remove());
    }
}

fn contextLessThan(context: []const u32, a: usize, b: usize) Order {
    return std.math.order(context[a], context[b]);
}

const CPQlt = PriorityQueue(usize, []const u32, contextLessThan);

test "add and remove min heap with context comparator" {
    const context = [_]u32{ 5, 3, 4, 2, 2, 8, 0 };

    var queue = CPQlt.init(testing.allocator, context[0..]);
    defer queue.deinit();

    try queue.add(0);
    try queue.add(1);
    try queue.add(2);
    try queue.add(3);
    try queue.add(4);
    try queue.add(5);
    try queue.add(6);
    try expectEqual(@as(usize, 6), queue.remove());
    try expectEqual(@as(usize, 4), queue.remove());
    try expectEqual(@as(usize, 3), queue.remove());
    try expectEqual(@as(usize, 1), queue.remove());
    try expectEqual(@as(usize, 2), queue.remove());
    try expectEqual(@as(usize, 0), queue.remove());
    try expectEqual(@as(usize, 5), queue.remove());
}
