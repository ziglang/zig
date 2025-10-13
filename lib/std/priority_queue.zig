const std = @import("std.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Order = std.math.Order;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

/// A priority queue for storing generic data.
///
/// If a priority queue is constructed from slice `{5, 8, 2, 9, 7, 1, 4, 4}`, then
/// a `compareFn` returning:
///
///   + `Order.lt` will create a min heap, in which the smallest value will have the highest
///     priority. The values will be popped in the sequence: 1, 2, 4, 4, 5, 7, 8, 9.
///
///     A `compareFn` implementing this kind of functionality will look like:
///
///     ```
///     fn lessThan(context: void, a: T, b: T) Order {
///         _ = context;
///         return std.math.order(a, b);
///     }
///     ```
///
///   + `Order.gt` will create a max heap, in which the largest value will have the highest
///     priority. The values will be popped in sequence: 9, 8, 7, 5, 4, 4, 2, 1.
///
///     A `compareFn` implementing this kind of functionality will look like:
///
///     ```
///     fn greaterThan(context: void, a: T, b: T) Order {
///         _ = context;
///         return std.math.order(a, b).invert();  // or, return std.math.order(b, a);
///     }
///     ```
///
pub fn PriorityQueue(comptime T: type, comptime Context: type, comptime compareFn: fn (context: Context, a: T, b: T) Order) type {
    return struct {
        const Self = @This();

        /// A slice of generic data.
        items: []T,
        /// The number of values that can be stored without allocating new memory.
        capacity: usize,
        /// The priority order of elements in the queue.
        context: Context,

        /// A priority queue containing no elements.
        pub const empty: Self = .{
            .items = &.{},
            .capacity = 0,
            .context = undefined,
        };

        /// Initialize a priority queue with priority order.
        pub fn withContext(context: Context) Self {
            return Self{
                .items = &.{},
                .capacity = 0,
                .context = context,
            };
        }

        /// Free memory used by the priority queue.
        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.allocatedSlice());
        }

        /// Insert a new element into the priority queue by ensuring it has enough
        /// capacity and maintaining priority of elements.
        pub fn push(self: *Self, allocator: Allocator, elem: T) !void {
            try self.ensureUnusedCapacity(allocator, 1);
            addUnchecked(self, elem);
        }

        /// Insert a new element to the end of the queue by maintaining the priority
        /// element at root.
        fn addUnchecked(self: *Self, elem: T) void {
            self.items.len += 1;
            self.items[self.items.len - 1] = elem;
            siftUp(self, self.items.len - 1);
        }

        /// Ensure that the highest priority element is at the root of the queue
        /// while inserting.
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

        /// Add each element in the `items` slice to the queue.
        pub fn addSlice(self: *Self, allocator: Allocator, items: []const T) !void {
            try self.ensureUnusedCapacity(allocator, items.len);
            for (items) |e| {
                self.addUnchecked(e);
            }
        }

        /// Returns `true` if the priority queue is empty and `false` if not.
        pub fn isEmpty(self: Self) bool {
            return if (self.items.len > 0) false else true;
        }

        /// Return the highest priority element from the queue, or `null` if empty.
        pub fn peek(self: *Self) ?T {
            return if (!self.isEmpty()) self.items[0] else null;
        }

        /// Remove and return the highest priority element from the queue, or `null`
        /// if empty.
        pub fn pop(self: *Self) ?T {
            return if (!self.isEmpty()) self.removeIndex(0) else null;
        }

        /// Remove and return the element at index. Indices are in the same order as
        /// the iterator, which is not necessarily priority order.
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

        /// Return the number of elements present in the priority queue.
        pub fn count(self: Self) usize {
            return self.items.len;
        }

        /// Return the number of elements that can be added to the priority queue
        /// before more memory is allocated.
        pub fn getCapacity(self: Self) usize {
            return self.capacity;
        }

        /// Returns a slice of all the items plus the extra capacity, whose memory
        /// contents are `undefined`.
        fn allocatedSlice(self: Self) []T {
            // `items.len` is the length, not the capacity.
            return self.items.ptr[0..self.capacity];
        }

        /// Ensure that the highest priority element is at the root of the queue
        /// while removing.
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

        /// PriorityQueue takes ownership of the passed in slice. The slice must have
        /// been allocated with `allocator`.
        /// Deinitialize with `deinit(allocator)`
        pub fn fromOwnedSlice(items: []T, context: Context) Self {
            var self = Self{
                .items = items,
                .capacity = items.len,
                .context = context,
            };

            var i = self.items.len >> 1;
            while (i > 0) {
                i -= 1;
                self.siftDown(i);
            }
            return self;
        }

        /// Ensure that the priority queue can fit at least `new_capacity` items.
        pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, new_capacity: usize) !void {
            var better_capacity = self.capacity;
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            const old_memory = self.allocatedSlice();
            const new_memory = try allocator.realloc(old_memory, better_capacity);
            self.items.ptr = new_memory.ptr;
            self.capacity = new_memory.len;
        }

        /// Ensure that the queue can fit at least `additional_count` **more** items.
        pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, additional_count: usize) !void {
            return self.ensureTotalCapacity(
                allocator,
                self.items.len + additional_count,
            );
        }

        /// Reduce allocated capacity to `new_capacity`.
        pub fn shrinkAndFree(self: *Self, allocator: Allocator, new_capacity: usize) void {
            assert(new_capacity <= self.capacity);

            // Cannot shrink to smaller than the current queue size without invalidating the heap property
            assert(new_capacity >= self.items.len);

            const old_memory = self.allocatedSlice();
            const new_memory = allocator.realloc(old_memory, new_capacity) catch |e| switch (e) {
                error.OutOfMemory => { // no problem, capacity is still correct then.
                    return;
                },
            };

            self.items.ptr = new_memory.ptr;
            self.capacity = new_memory.len;
        }

        /// Remove all elements from the items slice.
        pub fn clearRetainingCapacity(self: *Self) void {
            self.items.len = 0;
        }

        /// Invalidates all element pointers.
        pub fn clearAndFree(self: *Self, allocator: Allocator) void {
            allocator.free(self.allocatedSlice());
            self.items = &.{};
            self.capacity = 0;
            self.context = undefined;
        }

        /// Replace an element in the queue with a new element, maintaining priority.
        /// If the element being updated doesn't exist, return `error.ElementNotFound`.
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
            print("capacity: {}", .{self.capacity});
            print(" }}\n", .{});
        }
    };
}

fn lessThan(context: void, a: u32, b: u32) Order {
    _ = context;
    return std.math.order(a, b);
}

fn greaterThan(context: void, a: u32, b: u32) Order {
    _ = context;
    return std.math.order(a, b).invert();
}

const MinHeap = PriorityQueue(u32, void, lessThan);
const MaxHeap = PriorityQueue(u32, void, greaterThan);

test "add and remove min heap" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 54);
    try queue.push(allocator, 12);
    try queue.push(allocator, 7);
    try queue.push(allocator, 23);
    try queue.push(allocator, 25);
    try queue.push(allocator, 13);
    try expectEqual(@as(u32, 7), queue.pop());
    try expectEqual(@as(u32, 12), queue.pop());
    try expectEqual(@as(u32, 13), queue.pop());
    try expectEqual(@as(u32, 23), queue.pop());
    try expectEqual(@as(u32, 25), queue.pop());
    try expectEqual(@as(u32, 54), queue.pop());
}

test "add and remove same min heap" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 1);
    try queue.push(allocator, 1);
    try queue.push(allocator, 2);
    try queue.push(allocator, 2);
    try queue.push(allocator, 1);
    try queue.push(allocator, 1);
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 2), queue.pop());
}

test "remove from empty" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try expect(queue.pop() == null);
}

test "edge case 3 elements" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 9);
    try queue.push(allocator, 3);
    try queue.push(allocator, 2);
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 3), queue.pop());
    try expectEqual(@as(u32, 9), queue.pop());
}

test "peek" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try expect(queue.peek() == null);
    try queue.push(allocator, 9);
    try queue.push(allocator, 3);
    try queue.push(allocator, 2);
    try expectEqual(@as(u32, 2), queue.peek().?);
    try expectEqual(@as(u32, 2), queue.peek().?);
}

test "sift up with odd indices" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try queue.push(allocator, e);
    }

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.pop());
    }
}

test "addSlice" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try queue.addSlice(allocator, items[0..]);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.pop());
    }
}

test "fromOwnedSlice trivial case 0" {
    const allocator = std.testing.allocator;
    const items = [0]u32{};
    const queue_items = try allocator.dupe(u32, &items);
    var queue = MinHeap.fromOwnedSlice(queue_items[0..], {});
    defer queue.deinit(allocator);

    try expectEqual(@as(usize, 0), queue.count());
    try expect(queue.pop() == null);
}

test "fromOwnedSlice trivial case 1" {
    const allocator = std.testing.allocator;
    const items = [1]u32{1};
    const queue_items = try allocator.dupe(u32, &items);
    var queue = MinHeap.fromOwnedSlice(queue_items[0..], {});
    defer queue.deinit(allocator);

    try expectEqual(@as(usize, 1), queue.count());
    try expectEqual(items[0], queue.pop());
    try expect(queue.pop() == null);
}

test "fromOwnedSlice" {
    const allocator = std.testing.allocator;
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    const heap_items = try allocator.dupe(u32, items[0..]);
    var queue = MinHeap.fromOwnedSlice(heap_items[0..], {});
    defer queue.deinit(allocator);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.pop());
    }
}

test "add and remove max heap" {
    const allocator = std.testing.allocator;
    var queue: MaxHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 54);
    try queue.push(allocator, 12);
    try queue.push(allocator, 7);
    try queue.push(allocator, 23);
    try queue.push(allocator, 25);
    try queue.push(allocator, 13);
    try expectEqual(@as(u32, 54), queue.pop());
    try expectEqual(@as(u32, 25), queue.pop());
    try expectEqual(@as(u32, 23), queue.pop());
    try expectEqual(@as(u32, 13), queue.pop());
    try expectEqual(@as(u32, 12), queue.pop());
    try expectEqual(@as(u32, 7), queue.pop());
}

test "add and remove same max heap" {
    const allocator = std.testing.allocator;
    var queue: MaxHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 1);
    try queue.push(allocator, 1);
    try queue.push(allocator, 2);
    try queue.push(allocator, 2);
    try queue.push(allocator, 1);
    try queue.push(allocator, 1);
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
}

test "iterator" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    var map = std.AutoHashMap(u32, void).init(allocator);
    defer {
        queue.deinit(allocator);
        map.deinit();
    }

    const items = [_]u32{ 54, 12, 7, 23, 25, 13 };
    for (items) |e| {
        _ = try queue.push(allocator, e);
        try map.put(e, {});
    }

    var it = queue.iterator();
    while (it.next()) |e| {
        _ = map.remove(e);
    }

    try expectEqual(@as(usize, 0), map.count());
}

test "remove at index" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    const items = [_]u32{ 2, 1, 8, 9, 3, 4, 5 };
    for (items) |e| {
        _ = try queue.push(allocator, e);
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
    while (queue.pop()) |n| : (i += 1) {
        try expectEqual(n, sorted_items[i]);
    }
    try expectEqual(queue.pop(), null);
}

test "iterator while empty" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    var it = queue.iterator();

    try expectEqual(it.next(), null);
}

test "shrinkAndFree" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.ensureTotalCapacity(allocator, 4);
    try expect(queue.getCapacity() >= 4);

    try queue.push(allocator, 1);
    try queue.push(allocator, 2);
    try queue.push(allocator, 3);
    try expect(queue.getCapacity() >= 4);
    try expectEqual(@as(usize, 3), queue.count());

    queue.shrinkAndFree(allocator, 3);
    try expectEqual(@as(usize, 3), queue.getCapacity());
    try expectEqual(@as(usize, 3), queue.count());

    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 3), queue.pop());
    try expect(queue.pop() == null);
}

test "update min heap" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 55);
    try queue.push(allocator, 44);
    try queue.push(allocator, 11);
    try queue.update(55, 5);
    try queue.update(44, 4);
    try queue.update(11, 1);
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 4), queue.pop());
    try expectEqual(@as(u32, 5), queue.pop());
}

test "update same min heap" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 1);
    try queue.push(allocator, 1);
    try queue.push(allocator, 2);
    try queue.push(allocator, 2);
    try queue.update(1, 5);
    try queue.update(2, 4);
    try expectEqual(@as(u32, 1), queue.pop());
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 4), queue.pop());
    try expectEqual(@as(u32, 5), queue.pop());
}

test "update max heap" {
    const allocator = std.testing.allocator;
    var queue: MaxHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 55);
    try queue.push(allocator, 44);
    try queue.push(allocator, 11);
    try queue.update(55, 5);
    try queue.update(44, 1);
    try queue.update(11, 4);
    try expectEqual(@as(u32, 5), queue.pop());
    try expectEqual(@as(u32, 4), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
}

test "update same max heap" {
    const allocator = std.testing.allocator;
    var queue: MaxHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 1);
    try queue.push(allocator, 1);
    try queue.push(allocator, 2);
    try queue.push(allocator, 2);
    try queue.update(1, 5);
    try queue.update(2, 4);
    try expectEqual(@as(u32, 5), queue.pop());
    try expectEqual(@as(u32, 4), queue.pop());
    try expectEqual(@as(u32, 2), queue.pop());
    try expectEqual(@as(u32, 1), queue.pop());
}

test "update after remove" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.push(allocator, 1);
    try expectEqual(@as(u32, 1), queue.pop());
    try expectError(error.ElementNotFound, queue.update(1, 1));
}

test "siftUp in remove" {
    const allocator = std.testing.allocator;
    var queue: MinHeap = .empty;
    defer queue.deinit(allocator);

    try queue.addSlice(
        allocator,
        &.{ 0, 1, 100, 2, 3, 101, 102, 4, 5, 6, 7, 103, 104, 105, 106, 8 },
    );

    _ = queue.removeIndex(std.mem.indexOfScalar(u32, queue.items[0..queue.count()], 102).?);

    const sorted_items = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 100, 101, 103, 104, 105, 106 };
    for (sorted_items) |e| {
        try expectEqual(e, queue.pop());
    }
}

fn contextLessThan(context: []const u32, a: usize, b: usize) Order {
    return std.math.order(context[a], context[b]);
}

const MinHeapCTX = PriorityQueue(usize, []const u32, contextLessThan);

test "add and remove min heap with context comparator" {
    const allocator = std.testing.allocator;
    const context = [_]u32{ 5, 3, 4, 2, 2, 8, 0 };

    var queue: MinHeapCTX = .withContext(context[0..]);
    defer queue.deinit(allocator);

    try queue.push(allocator, 0);
    try queue.push(allocator, 1);
    try queue.push(allocator, 2);
    try queue.push(allocator, 3);
    try queue.push(allocator, 4);
    try queue.push(allocator, 5);
    try queue.push(allocator, 6);
    try expectEqual(@as(usize, 6), queue.pop());
    try expectEqual(@as(usize, 4), queue.pop());
    try expectEqual(@as(usize, 3), queue.pop());
    try expectEqual(@as(usize, 1), queue.pop());
    try expectEqual(@as(usize, 2), queue.pop());
    try expectEqual(@as(usize, 0), queue.pop());
    try expectEqual(@as(usize, 5), queue.pop());
}
