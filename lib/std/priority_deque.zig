const std = @import("std.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Order = std.math.Order;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

/// A priority deque for storing generic data.
///
/// If a priority deque is constructed from slice `{5, 8, 2, 9, 7, 1, 4, 4}`, then
/// a `compareFn` returning:
///
///   + `Order.lt` will create a min heap, in which:
///       + `popMin` will remove the values in sequence: 1, 2, 4, 4, 5, 7, 8, 9
///       + `popMax` will remove the values in sequence: 9, 8, 7, 5, 4, 4, 2, 1
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
///   + `Order.gt` will create a max heap, in which:
///       + `popMin` will remove the values in sequence: 9, 8, 7, 5, 4, 4, 2, 1
///       + `popMax` will remove the values in sequence: 1, 2, 4, 4, 5, 7, 8, 9
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
pub fn PriorityDeque(comptime T: type, comptime Context: type, comptime compareFn: fn (context: Context, a: T, b: T) Order) type {
    return struct {
        const Self = @This();

        /// A slice of generic data.
        items: []T,
        /// The number of values in the deque
        len: usize,
        /// The priority order of elements in the deque.
        context: Context,

        /// A priority deque containing no elements.
        pub const empty: Self = .{
            .items = &.{},
            .len = 0,
            .context = undefined,
        };

        /// Initialize and return a new priority deque.
        pub fn withContext(context: Context) Self {
            return Self{
                .items = &[_]T{},
                .len = 0,
                .context = context,
            };
        }

        /// Free memory used by the deque.
        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.items);
        }

        /// Insert a new element into the deque, maintaining priority.
        pub fn push(self: *Self, allocator: Allocator, elem: T) !void {
            try self.ensureUnusedCapacity(allocator, 1);
            addUnchecked(self, elem);
        }

        /// Add each element in `items` to the deque.
        pub fn addSlice(self: *Self, allocator: Allocator, items: []const T) !void {
            try self.ensureUnusedCapacity(allocator, items.len);
            for (items) |e| {
                self.addUnchecked(e);
            }
        }

        /// Returns `true` if the deque is empty and `false` if not.
        pub fn isEmpty(self: Self) bool {
            return if (self.len > 0) false else true;
        }

        fn addUnchecked(self: *Self, elem: T) void {
            self.items[self.len] = elem;

            if (!self.isEmpty()) {
                const start = self.getStartForSiftUp(elem, self.len);
                self.siftUp(start);
            }

            self.len += 1;
        }

        fn isMinLayer(index: usize) bool {
            // In the min-max heap structure:
            // The first element is on a min layer;
            // next two are on a max layer;
            // next four are on a min layer, and so on.
            return 1 == @clz(index +% 1) & 1;
        }

        fn nextIsMinLayer(self: Self) bool {
            return isMinLayer(self.len);
        }

        const StartIndexAndLayer = struct {
            index: usize,
            min_layer: bool,
        };

        fn getStartForSiftUp(self: Self, child: T, index: usize) StartIndexAndLayer {
            const child_index = index;
            const parent_index = parentIndex(child_index);
            const parent = self.items[parent_index];

            const min_layer = self.nextIsMinLayer();
            const order = compareFn(self.context, child, parent);
            if ((min_layer and order == .gt) or (!min_layer and order == .lt)) {
                // We must swap the item with it's parent if it is on the "wrong" layer
                self.items[parent_index] = child;
                self.items[child_index] = parent;
                return .{
                    .index = parent_index,
                    .min_layer = !min_layer,
                };
            } else {
                return .{
                    .index = child_index,
                    .min_layer = min_layer,
                };
            }
        }

        fn siftUp(self: *Self, start: StartIndexAndLayer) void {
            if (start.min_layer) {
                doSiftUp(self, start.index, .lt);
            } else {
                doSiftUp(self, start.index, .gt);
            }
        }

        fn doSiftUp(self: *Self, start_index: usize, target_order: Order) void {
            var child_index = start_index;
            while (child_index > 2) {
                const grandparent_index = grandparentIndex(child_index);
                const child = self.items[child_index];
                const grandparent = self.items[grandparent_index];

                // If the grandparent is already better or equal, we have gone as far as we need to
                if (compareFn(self.context, child, grandparent) != target_order) break;

                // Otherwise swap the item with it's grandparent
                self.items[grandparent_index] = child;
                self.items[child_index] = grandparent;
                child_index = grandparent_index;
            }
        }

        /// Return the smallest element from the deque, or `null` if empty.
        pub fn peekMin(self: *Self) ?T {
            return if (!self.isEmpty()) self.items[0] else null;
        }

        /// Return the largest element from the deque, or `null` if empty.
        pub fn peekMax(self: *Self) ?T {
            if (self.len == 0) return null;
            if (self.len == 1) return self.items[0];
            if (self.len == 2) return self.items[1];
            return self.bestItemAtIndices(1, 2, .gt).item;
        }

        fn maxIndex(self: Self) ?usize {
            if (self.len == 0) return null;
            if (self.len == 1) return 0;
            if (self.len == 2) return 1;
            return self.bestItemAtIndices(1, 2, .gt).index;
        }

        /// Remove and return the smallest element from the deque, or `null` if empty
        pub fn popMin(self: *Self) ?T {
            return if (!self.isEmpty()) self.removeIndex(0) else null;
        }

        /// Remove and return the largest element from the deque, or `null` if empty.
        pub fn popMax(self: *Self) ?T {
            return if (!self.isEmpty()) self.removeIndex(self.maxIndex().?) else null;
        }

        /// Remove and return element at index. Indices are in the same order as the
        /// iterator, which is not necessarily priority order.
        pub fn removeIndex(self: *Self, index: usize) T {
            assert(self.len > index);
            const item = self.items[index];
            const last = self.items[self.len - 1];

            self.items[index] = last;
            self.len -= 1;
            siftDown(self, index);

            return item;
        }

        fn siftDown(self: *Self, index: usize) void {
            if (isMinLayer(index)) {
                self.doSiftDown(index, .lt);
            } else {
                self.doSiftDown(index, .gt);
            }
        }

        fn doSiftDown(self: *Self, start_index: usize, target_order: Order) void {
            var index = start_index;
            const half = self.len >> 1;
            while (true) {
                const first_grandchild_index = firstGrandchildIndex(index);
                const last_grandchild_index = first_grandchild_index + 3;

                const elem = self.items[index];

                if (last_grandchild_index < self.len) {
                    // All four grandchildren exist
                    const index2 = first_grandchild_index + 1;
                    const index3 = index2 + 1;

                    // Find the best grandchild
                    const best_left = self.bestItemAtIndices(first_grandchild_index, index2, target_order);
                    const best_right = self.bestItemAtIndices(index3, last_grandchild_index, target_order);
                    const best_grandchild = self.bestItem(best_left, best_right, target_order);

                    // If the item is better than or equal to its best grandchild, we are done
                    if (compareFn(self.context, best_grandchild.item, elem) != target_order) return;

                    // Otherwise, swap them
                    self.items[best_grandchild.index] = elem;
                    self.items[index] = best_grandchild.item;
                    index = best_grandchild.index;

                    // We might need to swap the element with it's parent
                    self.swapIfParentIsBetter(elem, index, target_order);
                } else {
                    // The children or grandchildren are the last layer
                    const first_child_index = firstChildIndex(index);
                    if (first_child_index >= self.len) return;

                    const best_descendent = self.bestDescendent(first_child_index, first_grandchild_index, target_order);

                    // If the item is better than or equal to its best descendant, we are done
                    if (compareFn(self.context, best_descendent.item, elem) != target_order) return;

                    // Otherwise swap them
                    self.items[best_descendent.index] = elem;
                    self.items[index] = best_descendent.item;
                    index = best_descendent.index;

                    // If we didn't swap a grandchild, we are done
                    if (index < first_grandchild_index) return;

                    // We might need to swap the element with it's parent
                    self.swapIfParentIsBetter(elem, index, target_order);
                    return;
                }

                // If we are now in the last layer, we are done
                if (index >= half) return;
            }
        }

        fn swapIfParentIsBetter(self: *Self, child: T, child_index: usize, target_order: Order) void {
            const parent_index = parentIndex(child_index);
            const parent = self.items[parent_index];

            if (compareFn(self.context, parent, child) == target_order) {
                self.items[parent_index] = child;
                self.items[child_index] = parent;
            }
        }

        const ItemAndIndex = struct {
            item: T,
            index: usize,
        };

        fn getItem(self: Self, index: usize) ItemAndIndex {
            return .{
                .item = self.items[index],
                .index = index,
            };
        }

        fn bestItem(self: Self, item1: ItemAndIndex, item2: ItemAndIndex, target_order: Order) ItemAndIndex {
            if (compareFn(self.context, item1.item, item2.item) == target_order) {
                return item1;
            } else {
                return item2;
            }
        }

        fn bestItemAtIndices(self: Self, index1: usize, index2: usize, target_order: Order) ItemAndIndex {
            const item1 = self.getItem(index1);
            const item2 = self.getItem(index2);
            return self.bestItem(item1, item2, target_order);
        }

        fn bestDescendent(self: Self, first_child_index: usize, first_grandchild_index: usize, target_order: Order) ItemAndIndex {
            const second_child_index = first_child_index + 1;
            if (first_grandchild_index >= self.len) {
                // No grandchildren, find the best child (second may not exist)
                if (second_child_index >= self.len) {
                    return .{
                        .item = self.items[first_child_index],
                        .index = first_child_index,
                    };
                } else {
                    return self.bestItemAtIndices(first_child_index, second_child_index, target_order);
                }
            }

            const second_grandchild_index = first_grandchild_index + 1;
            if (second_grandchild_index >= self.len) {
                // One grandchild, so we know there is a second child. Compare first grandchild and second child
                return self.bestItemAtIndices(first_grandchild_index, second_child_index, target_order);
            }

            const best_left_grandchild_index = self.bestItemAtIndices(first_grandchild_index, second_grandchild_index, target_order).index;
            const third_grandchild_index = second_grandchild_index + 1;
            if (third_grandchild_index >= self.len) {
                // Two grandchildren, and we know the best. Compare this to second child.
                return self.bestItemAtIndices(best_left_grandchild_index, second_child_index, target_order);
            } else {
                // Three grandchildren, compare the min of the first two with the third
                return self.bestItemAtIndices(best_left_grandchild_index, third_grandchild_index, target_order);
            }
        }

        /// Return the number of elements remaining in the deque
        pub fn count(self: Self) usize {
            return self.len;
        }

        /// Return the number of elements that can be added to the
        /// deque before more memory is allocated.
        pub fn capacity(self: Self) usize {
            return self.items.len;
        }

        /// Deque takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// De-initialize with `deinit(allocator)`.
        pub fn fromOwnedSlice(items: []T, context: Context) Self {
            var deque = Self{
                .items = items,
                .len = items.len,
                .context = context,
            };

            if (deque.len <= 1) return deque;

            const half = (deque.len >> 1) - 1;
            var i: usize = 0;
            while (i <= half) : (i += 1) {
                const index = half - i;
                deque.siftDown(index);
            }
            return deque;
        }

        /// Ensure that the deque can fit at least `new_capacity` items.
        pub fn ensureTotalCapacity(self: *Self, allocator: Allocator, new_capacity: usize) !void {
            var better_capacity = self.capacity();
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            self.items = try allocator.realloc(self.items, better_capacity);
        }

        /// Ensure that the deque can fit at least `additional_count` **more** items.
        pub fn ensureUnusedCapacity(self: *Self, allocator: Allocator, additional_count: usize) !void {
            return self.ensureTotalCapacity(allocator, self.len + additional_count);
        }

        /// Reduce allocated capacity to `new_len`.
        pub fn shrinkAndFree(self: *Self, allocator: Allocator, new_len: usize) void {
            assert(new_len <= self.items.len);

            // Cannot shrink to smaller than the current deque size without invalidating the heap property
            assert(new_len >= self.len);

            self.items = allocator.realloc(self.items[0..], new_len) catch |e| switch (e) {
                error.OutOfMemory => { // no problem, capacity is still correct then.
                    self.items.len = new_len;
                    return;
                },
            };
        }

        /// Replace an element in the deque with a new element, maintaining priority.
        /// If the element being updated doesn't exist, return `error.ElementNotFound`.
        pub fn update(self: *Self, elem: T, new_elem: T) !void {
            const old_index = blk: {
                var idx: usize = 0;
                while (idx < self.len) : (idx += 1) {
                    const item = self.items[idx];
                    if (compareFn(self.context, item, elem) == .eq) break :blk idx;
                }
                return error.ElementNotFound;
            };
            _ = self.removeIndex(old_index);
            self.addUnchecked(new_elem);
        }

        pub const Iterator = struct {
            deque: *PriorityDeque(T, Context, compareFn),
            count: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.count >= it.deque.len) return null;
                const out = it.count;
                it.count += 1;
                return it.deque.items[out];
            }

            pub fn reset(it: *Iterator) void {
                it.count = 0;
            }
        };

        /// Return an iterator that walks the deque without consuming
        /// it. The iteration order may differ from the priority order.
        /// Invalidated if the deque is modified.
        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .deque = self,
                .count = 0,
            };
        }

        fn dump(self: *Self) void {
            const print = std.debug.print;
            print("{{ ", .{});
            print("items: ", .{});
            for (self.items, 0..) |e, i| {
                if (i >= self.len) break;
                print("{}, ", .{e});
            }
            print("array: ", .{});
            for (self.items) |e| {
                print("{}, ", .{e});
            }
            print("len: {} ", .{self.len});
            print("capacity: {}", .{self.capacity()});
            print(" }}\n", .{});
        }

        fn parentIndex(index: usize) usize {
            return (index - 1) >> 1;
        }

        fn grandparentIndex(index: usize) usize {
            return parentIndex(parentIndex(index));
        }

        fn firstChildIndex(index: usize) usize {
            return (index << 1) + 1;
        }

        fn firstGrandchildIndex(index: usize) usize {
            return firstChildIndex(firstChildIndex(index));
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

const MinHeap = PriorityDeque(u32, void, lessThan);
const MaxHeap = PriorityDeque(u32, void, greaterThan);

test "add and remove times 2 min heap" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 54);
    try deque.push(allocator, 12);
    try deque.push(allocator, 7);
    try deque.push(allocator, 23);
    try deque.push(allocator, 25);
    try deque.push(allocator, 13);

    try expectEqual(@as(u32, 7), deque.popMin());
    try expectEqual(@as(u32, 12), deque.popMin());
    try expectEqual(@as(u32, 13), deque.popMin());
    try expectEqual(@as(u32, 23), deque.popMin());
    try expectEqual(@as(u32, 25), deque.popMin());
    try expectEqual(@as(u32, 54), deque.popMin());

    try deque.push(allocator, 54);
    try deque.push(allocator, 12);
    try deque.push(allocator, 7);
    try deque.push(allocator, 23);
    try deque.push(allocator, 25);
    try deque.push(allocator, 13);

    try expectEqual(@as(u32, 54), deque.popMax());
    try expectEqual(@as(u32, 25), deque.popMax());
    try expectEqual(@as(u32, 23), deque.popMax());
    try expectEqual(@as(u32, 13), deque.popMax());
    try expectEqual(@as(u32, 12), deque.popMax());
    try expectEqual(@as(u32, 7), deque.popMax());
}

test "add and remove min structs" {
    const allocator = std.testing.allocator;
    const S = struct {
        size: u32,
    };
    var deque = PriorityDeque(S, void, struct {
        fn order(context: void, a: S, b: S) Order {
            _ = context;
            return std.math.order(a.size, b.size);
        }
    }.order).withContext({});
    defer deque.deinit(allocator);

    try deque.push(allocator, .{ .size = 54 });
    try deque.push(allocator, .{ .size = 12 });
    try deque.push(allocator, .{ .size = 7 });
    try deque.push(allocator, .{ .size = 23 });
    try deque.push(allocator, .{ .size = 25 });
    try deque.push(allocator, .{ .size = 13 });

    try expectEqual(@as(u32, 7), deque.popMin().?.size);
    try expectEqual(@as(u32, 12), deque.popMin().?.size);
    try expectEqual(@as(u32, 13), deque.popMin().?.size);
    try expectEqual(@as(u32, 23), deque.popMin().?.size);
    try expectEqual(@as(u32, 25), deque.popMin().?.size);
    try expectEqual(@as(u32, 54), deque.popMin().?.size);
}

test "add and remove times 2 max heap" {
    const allocator = std.testing.allocator;
    var deque: MaxHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 54);
    try deque.push(allocator, 12);
    try deque.push(allocator, 7);
    try deque.push(allocator, 23);
    try deque.push(allocator, 25);
    try deque.push(allocator, 13);

    try expectEqual(@as(u32, 54), deque.popMin());
    try expectEqual(@as(u32, 25), deque.popMin());
    try expectEqual(@as(u32, 23), deque.popMin());
    try expectEqual(@as(u32, 13), deque.popMin());
    try expectEqual(@as(u32, 12), deque.popMin());
    try expectEqual(@as(u32, 7), deque.popMin());

    try deque.push(allocator, 54);
    try deque.push(allocator, 12);
    try deque.push(allocator, 7);
    try deque.push(allocator, 23);
    try deque.push(allocator, 25);
    try deque.push(allocator, 13);

    try expectEqual(@as(u32, 7), deque.popMax());
    try expectEqual(@as(u32, 12), deque.popMax());
    try expectEqual(@as(u32, 13), deque.popMax());
    try expectEqual(@as(u32, 23), deque.popMax());
    try expectEqual(@as(u32, 25), deque.popMax());
    try expectEqual(@as(u32, 54), deque.popMax());
}

test "add and remove same min" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 1);
    try deque.push(allocator, 1);
    try deque.push(allocator, 2);
    try deque.push(allocator, 2);
    try deque.push(allocator, 1);
    try deque.push(allocator, 1);

    try expectEqual(@as(u32, 1), deque.popMin());
    try expectEqual(@as(u32, 1), deque.popMin());
    try expectEqual(@as(u32, 1), deque.popMin());
    try expectEqual(@as(u32, 1), deque.popMin());
    try expectEqual(@as(u32, 2), deque.popMin());
    try expectEqual(@as(u32, 2), deque.popMin());
}

test "add and remove same max" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 1);
    try deque.push(allocator, 1);
    try deque.push(allocator, 2);
    try deque.push(allocator, 2);
    try deque.push(allocator, 1);
    try deque.push(allocator, 1);

    try expectEqual(@as(u32, 2), deque.popMax());
    try expectEqual(@as(u32, 2), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
}

test "pop empty deque" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try expect(deque.popMin() == null);
    try expect(deque.popMax() == null);
}

test "edge case 3 elements" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 9);
    try deque.push(allocator, 3);
    try deque.push(allocator, 2);

    try expectEqual(@as(u32, 2), deque.popMin());
    try expectEqual(@as(u32, 3), deque.popMin());
    try expectEqual(@as(u32, 9), deque.popMin());
}

test "edge case 3 elements max" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 9);
    try deque.push(allocator, 3);
    try deque.push(allocator, 2);

    try expectEqual(@as(u32, 9), deque.popMax());
    try expectEqual(@as(u32, 3), deque.popMax());
    try expectEqual(@as(u32, 2), deque.popMax());
}

test "peekMin" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try expect(deque.peekMin() == null);

    try deque.push(allocator, 9);
    try deque.push(allocator, 3);
    try deque.push(allocator, 2);

    try expect(deque.peekMin().? == 2);
    try expect(deque.peekMin().? == 2);
}

test "peekMax" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try expect(deque.peekMin() == null);

    try deque.push(allocator, 9);
    try deque.push(allocator, 3);
    try deque.push(allocator, 2);

    try expect(deque.peekMax().? == 9);
    try expect(deque.peekMax().? == 9);
}

test "sift up with odd indices, popMin" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try deque.push(allocator, e);
    }

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, deque.popMin());
    }
}

test "sift up with odd indices, popMax" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try deque.push(allocator, e);
    }

    const sorted_items = [_]u32{ 25, 24, 24, 22, 21, 16, 15, 15, 14, 13, 12, 11, 7, 7, 6, 5, 2, 1 };
    for (sorted_items) |e| {
        try expectEqual(e, deque.popMax());
    }
}

test "addSlice min" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try deque.addSlice(allocator, items[0..]);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, deque.popMin());
    }
}

test "addSlice max" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try deque.addSlice(allocator, items[0..]);

    const sorted_items = [_]u32{ 25, 24, 24, 22, 21, 16, 15, 15, 14, 13, 12, 11, 7, 7, 6, 5, 2, 1 };
    for (sorted_items) |e| {
        try expectEqual(e, deque.popMax());
    }
}

test "fromOwnedSlice trivial case 0" {
    const allocator = std.testing.allocator;
    const items = [0]u32{};
    const dq_items = try allocator.dupe(u32, &items);

    var deque = MinHeap.fromOwnedSlice(dq_items[0..], {});
    defer deque.deinit(allocator);

    try expectEqual(@as(usize, 0), deque.len);
    try expect(deque.popMin() == null);
}

test "fromOwnedSlice trivial case 1" {
    const allocator = std.testing.allocator;
    const items = [1]u32{1};
    const dq_items = try testing.allocator.dupe(u32, &items);
    var deque = MinHeap.fromOwnedSlice(dq_items[0..], {});
    defer deque.deinit(allocator);

    try expectEqual(@as(usize, 1), deque.len);
    try expectEqual(items[0], deque.popMin());
    try expect(deque.popMin() == null);
}

test "fromOwnedSlice" {
    const allocator = std.testing.allocator;
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    const dq_items = try testing.allocator.dupe(u32, items[0..]);
    var deque = MinHeap.fromOwnedSlice(dq_items[0..], {});
    defer deque.deinit(allocator);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        try expectEqual(e, deque.popMin());
    }
}

test "update min deque" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 55);
    try deque.push(allocator, 44);
    try deque.push(allocator, 11);
    try deque.update(55, 5);
    try deque.update(44, 4);
    try deque.update(11, 1);
    try expectEqual(@as(u32, 1), deque.popMin());
    try expectEqual(@as(u32, 4), deque.popMin());
    try expectEqual(@as(u32, 5), deque.popMin());
}

test "update same min deque" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 1);
    try deque.push(allocator, 1);
    try deque.push(allocator, 2);
    try deque.push(allocator, 2);
    try deque.update(1, 5);
    try deque.update(2, 4);
    try expectEqual(@as(u32, 1), deque.popMin());
    try expectEqual(@as(u32, 2), deque.popMin());
    try expectEqual(@as(u32, 4), deque.popMin());
    try expectEqual(@as(u32, 5), deque.popMin());
}

test "update max deque" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 55);
    try deque.push(allocator, 44);
    try deque.push(allocator, 11);
    try deque.update(55, 5);
    try deque.update(44, 1);
    try deque.update(11, 4);

    try expectEqual(@as(u32, 5), deque.popMax());
    try expectEqual(@as(u32, 4), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
}

test "update same max deque" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 1);
    try deque.push(allocator, 1);
    try deque.push(allocator, 2);
    try deque.push(allocator, 2);
    try deque.update(1, 5);
    try deque.update(2, 4);
    try expectEqual(@as(u32, 5), deque.popMax());
    try expectEqual(@as(u32, 4), deque.popMax());
    try expectEqual(@as(u32, 2), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
}

test "update after remove" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 1);
    try expectEqual(@as(u32, 1), deque.popMin());
    try expectError(error.ElementNotFound, deque.update(1, 1));
}

test "iterator" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    var map = std.AutoHashMap(u32, void).init(allocator);
    defer {
        deque.deinit(allocator);
        map.deinit();
    }

    const items = [_]u32{ 54, 12, 7, 23, 25, 13 };
    for (items) |e| {
        _ = try deque.push(allocator, e);
        _ = try map.put(e, {});
    }

    var it = deque.iterator();
    while (it.next()) |e| {
        _ = map.remove(e);
    }

    try expectEqual(@as(usize, 0), map.count());
}

test "remove at index" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.push(allocator, 3);
    try deque.push(allocator, 2);
    try deque.push(allocator, 1);

    var it = deque.iterator();
    var elem = it.next();
    var idx: usize = 0;
    const two_idx = while (elem != null) : (elem = it.next()) {
        if (elem.? == 2)
            break idx;
        idx += 1;
    } else unreachable;

    try expectEqual(deque.removeIndex(two_idx), 2);
    try expectEqual(deque.popMin(), 1);
    try expectEqual(deque.popMin(), 3);
    try expectEqual(deque.popMin(), null);
}

test "iterator while empty" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    var it = deque.iterator();

    try expectEqual(it.next(), null);
}

test "shrinkAndFree" {
    const allocator = std.testing.allocator;
    var deque: MinHeap = .empty;
    defer deque.deinit(allocator);

    try deque.ensureTotalCapacity(allocator, 4);
    try expect(deque.capacity() >= 4);

    try deque.push(allocator, 1);
    try deque.push(allocator, 2);
    try deque.push(allocator, 3);
    try expect(deque.capacity() >= 4);
    try expectEqual(@as(usize, 3), deque.len);

    deque.shrinkAndFree(allocator, 3);
    try expectEqual(@as(usize, 3), deque.capacity());
    try expectEqual(@as(usize, 3), deque.len);

    try expectEqual(@as(u32, 3), deque.popMax());
    try expectEqual(@as(u32, 2), deque.popMax());
    try expectEqual(@as(u32, 1), deque.popMax());
    try expect(deque.popMax() == null);
}

test "fuzz testing min" {
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    const random = prng.random();

    const test_case_count = 100;
    const dq_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMin(random, dq_size);
    }
}

fn fuzzTestMin(rng: std.Random, comptime dq_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, dq_size);

    var deque = MinHeap.fromOwnedSlice(items, {});
    defer deque.deinit(allocator);

    var last_removed: ?u32 = null;
    while (deque.popMin()) |next| {
        if (last_removed) |last| {
            try expect(last <= next);
        }
        last_removed = next;
    }
}

test "fuzz testing max" {
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    const random = prng.random();

    const test_case_count = 100;
    const dq_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMax(random, dq_size);
    }
}

fn fuzzTestMax(rng: std.Random, dq_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, dq_size);

    var deque = MinHeap.fromOwnedSlice(items, {});
    defer deque.deinit(allocator);

    var last_removed: ?u32 = null;
    while (deque.popMax()) |next| {
        if (last_removed) |last| {
            try expect(last >= next);
        }
        last_removed = next;
    }
}

test "fuzz testing min and max" {
    var prng = std.Random.DefaultPrng.init(std.testing.random_seed);
    const random = prng.random();

    const test_case_count = 100;
    const dq_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMinMax(random, dq_size);
    }
}

fn fuzzTestMinMax(rng: std.Random, dq_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, dq_size);

    var deque = MinHeap.fromOwnedSlice(items, {});
    defer deque.deinit(allocator);

    var last_min: ?u32 = null;
    var last_max: ?u32 = null;
    var i: usize = 0;
    while (i < dq_size) : (i += 1) {
        if (i % 2 == 0) {
            const next = deque.popMin().?;
            if (last_min) |last| {
                try expect(last <= next);
            }
            last_min = next;
        } else {
            const next = deque.popMax().?;
            if (last_max) |last| {
                try expect(last >= next);
            }
            last_max = next;
        }
    }
}

fn generateRandomSlice(allocator: std.mem.Allocator, rng: std.Random, size: usize) ![]u32 {
    var array = std.array_list.Managed(u32).init(allocator);
    try array.ensureTotalCapacity(size);

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = rng.int(u32);
        try array.append(elem);
    }

    return array.toOwnedSlice();
}

fn contextLessThan(context: []const u32, a: usize, b: usize) Order {
    return std.math.order(context[a], context[b]);
}

const CPDQ = PriorityDeque(usize, []const u32, contextLessThan);

test "add and remove" {
    const allocator = std.testing.allocator;
    const context = [_]u32{ 5, 3, 4, 2, 2, 8, 0 };

    var deque = CPDQ.withContext(context[0..]);
    defer deque.deinit(allocator);

    try deque.push(allocator, 0);
    try deque.push(allocator, 1);
    try deque.push(allocator, 2);
    try deque.push(allocator, 3);
    try deque.push(allocator, 4);
    try deque.push(allocator, 5);
    try deque.push(allocator, 6);
    try expectEqual(@as(usize, 6), deque.popMin());
    try expectEqual(@as(usize, 5), deque.popMax());
    try expectEqual(@as(usize, 3), deque.popMin());
    try expectEqual(@as(usize, 0), deque.popMax());
    try expectEqual(@as(usize, 4), deque.popMin());
    try expectEqual(@as(usize, 2), deque.popMax());
    try expectEqual(@as(usize, 1), deque.popMin());
}

var all_cmps_unique = true;

test "don't compare a value to a copy of itself" {
    const allocator = std.testing.allocator;
    var depq = PriorityDeque(u32, void, struct {
        fn uniqueLessThan(_: void, a: u32, b: u32) Order {
            all_cmps_unique = all_cmps_unique and (a != b);
            return std.math.order(a, b);
        }
    }.uniqueLessThan).withContext({});
    defer depq.deinit(allocator);

    try depq.push(allocator, 1);
    try depq.push(allocator, 2);
    try depq.push(allocator, 3);
    try depq.push(allocator, 4);
    try depq.push(allocator, 5);
    try depq.push(allocator, 6);

    _ = depq.removeIndex(2);
    try expectEqual(all_cmps_unique, true);
}
