// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const warn = std.debug.warn;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;

/// Priority Dequeue for storing generic data. Initialize with `init`.
pub fn PriorityDequeue(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        len: usize,
        allocator: *Allocator,
        lessThanFn: fn (a: T, b: T) bool,

        /// Initialize and return a new dequeue. Provide `lessThanFn`
        /// that returns `true` when its first argument should
        /// get min-popped before its second argument. For example,
        /// to make `popMin` return the minimum value, provide
        ///
        /// `fn lessThanFn(a: T, b: T) bool { return a < b; }`
        pub fn init(allocator: *Allocator, lessThanFn: fn (T, T) bool) Self {
            return Self{
                .items = &[_]T{},
                .len = 0,
                .allocator = allocator,
                .lessThanFn = lessThanFn,
            };
        }

        fn lessThan(self: Self, a: T, b: T) bool {
            return self.lessThanFn(a, b);
        }

        fn greaterThan(self: Self, a: T, b: T) bool {
            return self.lessThanFn(b, a);
        }

        /// Free memory used by the dequeue.
        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }

        /// Insert a new element, maintaining priority.
        pub fn add(self: *Self, elem: T) !void {
            try ensureCapacity(self, self.len + 1);
            addUnchecked(self, elem);
        }

        /// Add each element in `items` to the dequeue.
        pub fn addSlice(self: *Self, items: []const T) !void {
            try self.ensureCapacity(self.len + items.len);
            for (items) |e| {
                self.addUnchecked(e);
            }
        }

        fn addUnchecked(self: *Self, elem: T) void {
            self.items[self.len] = elem;

            if (self.len > 0) {
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
            const leading_zeros = @clz(usize, index + 1);
            const highest_set_bit = @bitSizeOf(usize) - 1 - leading_zeros;
            return (highest_set_bit & 1) == 0;
        }

        fn nextIsMinLayer(self: Self) bool {
            return isMinLayer(self.len);
        }

        const StartIndexAndLayer = struct {
            index: usize,
            min_layer: bool,
        };

        fn getStartForSiftUp(self: Self, child: T, index: usize) StartIndexAndLayer {
            var child_index = index;
            var parent_index = parentIndex(child_index);
            const parent = self.items[parent_index];

            const min_layer = self.nextIsMinLayer();
            if ((min_layer and self.greaterThan(child, parent)) or (!min_layer and self.lessThan(child, parent))) {
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
                doSiftUp(self, start.index, lessThan);
            } else {
                doSiftUp(self, start.index, greaterThan);
            }
        }

        fn doSiftUp(self: *Self, start_index: usize, compare: fn (Self, T, T) bool) void {
            var child_index = start_index;
            while (child_index > 2) {
                var grandparent_index = grandparentIndex(child_index);
                const child = self.items[child_index];
                const grandparent = self.items[grandparent_index];

                // If the grandparent is already better, we have gone as far as we need to
                if (!compare(self.*, child, grandparent)) break;

                // Otherwise swap the item with it's grandparent
                self.items[grandparent_index] = child;
                self.items[child_index] = grandparent;
                child_index = grandparent_index;
            }
        }

        /// Look at the smallest element in the dequeue. Returns
        /// `null` if empty.
        pub fn peekMin(self: *Self) ?T {
            return if (self.len > 0) self.items[0] else null;
        }

        /// Look at the largest element in the dequeue. Returns
        /// `null` if empty.
        pub fn peekMax(self: *Self) ?T {
            if (self.len == 0) return null;
            if (self.len == 1) return self.items[0];
            if (self.len == 2) return self.items[1];
            return self.bestItemAtIndices(1, 2, greaterThan).item;
        }

        fn maxIndex(self: Self) ?usize {
            if (self.len == 0) return null;
            if (self.len == 1) return 0;
            if (self.len == 2) return 1;
            return self.bestItemAtIndices(1, 2, greaterThan).index;
        }

        /// Pop the smallest element from the dequeue. Returns
        /// `null` if empty.
        pub fn removeMinOrNull(self: *Self) ?T {
            return if (self.len > 0) self.removeMin() else null;
        }

        /// Remove and return the smallest element from the
        /// dequeue.
        pub fn removeMin(self: *Self) T {
            return self.removeIndex(0);
        }

        /// Pop the largest element from the dequeue. Returns
        /// `null` if empty.
        pub fn removeMaxOrNull(self: *Self) ?T {
            return if (self.len > 0) self.removeMax() else null;
        }

        /// Remove and return the largest element from the
        /// dequeue.
        pub fn removeMax(self: *Self) T {
            return self.removeIndex(self.maxIndex().?);
        }

        /// Remove and return element at index. Indices are in the
        /// same order as iterator, which is not necessarily priority
        /// order.
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
                self.doSiftDown(index, lessThan);
            } else {
                self.doSiftDown(index, greaterThan);
            }
        }

        fn doSiftDown(self: *Self, start_index: usize, compare: fn (Self, T, T) bool) void {
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
                    const best_left = self.bestItemAtIndices(first_grandchild_index, index2, compare);
                    const best_right = self.bestItemAtIndices(index3, last_grandchild_index, compare);
                    const best_grandchild = self.bestItem(best_left, best_right, compare);

                    // If the item is better than it's best grandchild, we are done
                    if (compare(self.*, elem, best_grandchild.item) or elem == best_grandchild.item) return;

                    // Otherwise, swap them
                    self.items[best_grandchild.index] = elem;
                    self.items[index] = best_grandchild.item;
                    index = best_grandchild.index;

                    // We might need to swap the element with it's parent
                    self.swapIfParentIsBetter(elem, index, compare);
                } else {
                    // The children or grandchildren are the last layer
                    const first_child_index = firstChildIndex(index);
                    if (first_child_index > self.len) return;

                    const best_descendent = self.bestDescendent(first_child_index, first_grandchild_index, compare);

                    // If the best descendant is still larger, we are done
                    if (compare(self.*, elem, best_descendent.item) or elem == best_descendent.item) return;

                    // Otherwise swap them
                    self.items[best_descendent.index] = elem;
                    self.items[index] = best_descendent.item;
                    index = best_descendent.index;

                    // If we didn't swap a grandchild, we are done
                    if (index < first_grandchild_index) return;

                    // We might need to swap the element with it's parent
                    self.swapIfParentIsBetter(elem, index, compare);
                    return;
                }

                // If we are now in the last layer, we are done
                if (index >= half) return;
            }
        }

        fn swapIfParentIsBetter(self: *Self, child: T, child_index: usize, compare: fn (Self, T, T) bool) void {
            const parent_index = parentIndex(child_index);
            const parent = self.items[parent_index];

            if (compare(self.*, parent, child)) {
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

        fn bestItem(self: Self, item1: ItemAndIndex, item2: ItemAndIndex, compare: fn (Self, T, T) bool) ItemAndIndex {
            if (compare(self, item1.item, item2.item)) {
                return item1;
            } else {
                return item2;
            }
        }

        fn bestItemAtIndices(self: Self, index1: usize, index2: usize, compare: fn (Self, T, T) bool) ItemAndIndex {
            var item1 = self.getItem(index1);
            var item2 = self.getItem(index2);
            return self.bestItem(item1, item2, compare);
        }

        fn bestDescendent(self: Self, first_child_index: usize, first_grandchild_index: usize, compare: fn (Self, T, T) bool) ItemAndIndex {
            const second_child_index = first_child_index + 1;
            if (first_grandchild_index >= self.len) {
                // No grandchildren, find the best child (second may not exist)
                if (second_child_index >= self.len) {
                    return .{
                        .item = self.items[first_child_index],
                        .index = first_child_index,
                    };
                } else {
                    return self.bestItemAtIndices(first_child_index, second_child_index, compare);
                }
            }

            const second_grandchild_index = first_grandchild_index + 1;
            if (second_grandchild_index >= self.len) {
                // One grandchild, so we know there is a second child. Compare first grandchild and second child
                return self.bestItemAtIndices(first_grandchild_index, second_child_index, compare);
            }

            const best_left_grandchild_index = self.bestItemAtIndices(first_grandchild_index, second_grandchild_index, compare).index;
            const third_grandchild_index = second_grandchild_index + 1;
            if (third_grandchild_index >= self.len) {
                // Two grandchildren, and we know the best. Compare this to second child.
                return self.bestItemAtIndices(best_left_grandchild_index, second_child_index, compare);
            } else {
                // Three grandchildren, compare the min of the first two with the third
                return self.bestItemAtIndices(best_left_grandchild_index, third_grandchild_index, compare);
            }
        }

        /// Return the number of elements remaining in the heap
        pub fn count(self: Self) usize {
            return self.len;
        }

        /// Return the number of elements that can be added to the
        /// dequeue before more memory is allocated.
        pub fn capacity(self: Self) usize {
            return self.items.len;
        }

        /// Heap takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// De-initialize with `deinit`.
        pub fn fromOwnedSlice(allocator: *Allocator, lessThanFn: fn (T, T) bool, items: []T) Self {
            var queue = Self{
                .items = items,
                .len = items.len,
                .allocator = allocator,
                .lessThanFn = lessThanFn,
            };

            if (queue.len <= 1) return queue;

            const half = (queue.len >> 1) - 1;
            var i: usize = 0;
            while (i <= half) : (i += 1) {
                const index = half - i;
                queue.siftDown(index);
            }
            return queue;
        }

        pub fn ensureCapacity(self: *Self, new_capacity: usize) !void {
            var better_capacity = self.capacity();
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            self.items = try self.allocator.realloc(self.items, better_capacity);
        }

        pub fn resize(self: *Self, new_len: usize) !void {
            try self.ensureCapacity(new_len);
            self.len = new_len;
        }

        pub fn shrink(self: *Self, new_len: usize) void {
            // TODO take advantage of the new realloc semantics
            assert(new_len <= self.len);
            self.len = new_len;
        }

        pub fn update(self: *Self, elem: T, new_elem: T) !void {
            var old_index: usize = std.mem.indexOfScalar(T, self.items, elem) orelse return error.ElementNotFound;
            _ = self.removeIndex(old_index);
            self.addUnchecked(new_elem);
        }

        pub const Iterator = struct {
            heap: *PriorityDequeue(T),
            count: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.count >= it.heap.len) return null;
                const out = it.count;
                it.count += 1;
                return it.heap.items[out];
            }

            pub fn reset(it: *Iterator) void {
                it.count = 0;
            }
        };

        /// Return an iterator that walks the heap without consuming
        /// it. Invalidated if the heap is modified.
        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .heap = self,
                .count = 0,
            };
        }

        fn dump(self: *Self) void {
            warn("{{ ", .{});
            warn("items: ", .{});
            for (self.items) |e, i| {
                if (i >= self.len) break;
                warn("{}, ", .{e});
            }
            warn("array: ", .{});
            for (self.items) |e, i| {
                warn("{}, ", .{e});
            }
            warn("len: {} ", .{self.len});
            warn("capacity: {}", .{self.capacity()});
            warn(" }}\n", .{});
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

fn lessThanComparison(a: u32, b: u32) bool {
    return a < b;
}

const Heap = PriorityDequeue(u32);

test "std.PriorityDequeue: add and remove min" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(54);
    try heap.add(12);
    try heap.add(7);
    try heap.add(23);
    try heap.add(25);
    try heap.add(13);

    expectEqual(@as(u32, 7), heap.removeMin());
    expectEqual(@as(u32, 12), heap.removeMin());
    expectEqual(@as(u32, 13), heap.removeMin());
    expectEqual(@as(u32, 23), heap.removeMin());
    expectEqual(@as(u32, 25), heap.removeMin());
    expectEqual(@as(u32, 54), heap.removeMin());
}

test "std.PriorityDequeue: add and remove max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(54);
    try heap.add(12);
    try heap.add(7);
    try heap.add(23);
    try heap.add(25);
    try heap.add(13);

    expectEqual(@as(u32, 54), heap.removeMax());
    expectEqual(@as(u32, 25), heap.removeMax());
    expectEqual(@as(u32, 23), heap.removeMax());
    expectEqual(@as(u32, 13), heap.removeMax());
    expectEqual(@as(u32, 12), heap.removeMax());
    expectEqual(@as(u32, 7), heap.removeMax());
}

test "std.PriorityDequeue: add and remove same min" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.add(1);
    try heap.add(1);

    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 2), heap.removeMin());
    expectEqual(@as(u32, 2), heap.removeMin());
}

test "std.PriorityDequeue: add and remove same max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.add(1);
    try heap.add(1);

    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
}

test "std.PriorityDequeue: removeOrNull empty" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    expect(heap.removeMinOrNull() == null);
    expect(heap.removeMaxOrNull() == null);
}

test "std.PriorityDequeue: edge case 3 elements" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expectEqual(@as(u32, 2), heap.removeMin());
    expectEqual(@as(u32, 3), heap.removeMin());
    expectEqual(@as(u32, 9), heap.removeMin());
}

test "std.PriorityDequeue: edge case 3 elements max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expectEqual(@as(u32, 9), heap.removeMax());
    expectEqual(@as(u32, 3), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
}

test "std.PriorityDequeue: peekMin" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    expect(heap.peekMin() == null);

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expect(heap.peekMin().? == 2);
    expect(heap.peekMin().? == 2);
}

test "std.PriorityDequeue: peekMax" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    expect(heap.peekMin() == null);

    try heap.add(9);
    try heap.add(3);
    try heap.add(2);

    expect(heap.peekMax().? == 9);
    expect(heap.peekMax().? == 9);
}

test "std.PriorityDequeue: sift up with odd indices" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try heap.add(e);
    }

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMin());
    }
}

test "std.PriorityDequeue: sift up with odd indices" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    for (items) |e| {
        try heap.add(e);
    }

    const sorted_items = [_]u32{ 25, 24, 24, 22, 21, 16, 15, 15, 14, 13, 12, 11, 7, 7, 6, 5, 2, 1 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMax());
    }
}

test "std.PriorityDequeue: addSlice min" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try heap.addSlice(items[0..]);

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMin());
    }
}

test "std.PriorityDequeue: addSlice max" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    try heap.addSlice(items[0..]);

    const sorted_items = [_]u32{ 25, 24, 24, 22, 21, 16, 15, 15, 14, 13, 12, 11, 7, 7, 6, 5, 2, 1 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMax());
    }
}

test "std.PriorityDequeue: fromOwnedSlice trivial case 0" {
    const items = [0]u32{};
    const heap_items = try testing.allocator.dupe(u32, &items);
    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, heap_items[0..]);
    defer heap.deinit();
    expectEqual(@as(usize, 0), heap.len);
    expect(heap.removeMinOrNull() == null);
}

test "std.PriorityDequeue: fromOwnedSlice trivial case 1" {
    const items = [1]u32{1};
    const heap_items = try testing.allocator.dupe(u32, &items);
    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, heap_items[0..]);
    defer heap.deinit();

    expectEqual(@as(usize, 1), heap.len);
    expectEqual(items[0], heap.removeMin());
    expect(heap.removeMinOrNull() == null);
}

test "std.PriorityDequeue: fromOwnedSlice" {
    const items = [_]u32{ 15, 7, 21, 14, 13, 22, 12, 6, 7, 25, 5, 24, 11, 16, 15, 24, 2, 1 };
    const heap_items = try testing.allocator.dupe(u32, items[0..]);
    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, heap_items[0..]);
    defer heap.deinit();

    const sorted_items = [_]u32{ 1, 2, 5, 6, 7, 7, 11, 12, 13, 14, 15, 15, 16, 21, 22, 24, 24, 25 };
    for (sorted_items) |e| {
        expectEqual(e, heap.removeMin());
    }
}

test "std.PriorityDequeue: update min heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(55);
    try heap.add(44);
    try heap.add(11);
    try heap.update(55, 5);
    try heap.update(44, 4);
    try heap.update(11, 1);
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 4), heap.removeMin());
    expectEqual(@as(u32, 5), heap.removeMin());
}

test "std.PriorityDequeue: update same min heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.update(1, 5);
    try heap.update(2, 4);
    expectEqual(@as(u32, 1), heap.removeMin());
    expectEqual(@as(u32, 2), heap.removeMin());
    expectEqual(@as(u32, 4), heap.removeMin());
    expectEqual(@as(u32, 5), heap.removeMin());
}

test "std.PriorityDequeue: update max heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(55);
    try heap.add(44);
    try heap.add(11);
    try heap.update(55, 5);
    try heap.update(44, 1);
    try heap.update(11, 4);

    expectEqual(@as(u32, 5), heap.removeMax());
    expectEqual(@as(u32, 4), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
}

test "std.PriorityDequeue: update same max heap" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(1);
    try heap.add(1);
    try heap.add(2);
    try heap.add(2);
    try heap.update(1, 5);
    try heap.update(2, 4);
    expectEqual(@as(u32, 5), heap.removeMax());
    expectEqual(@as(u32, 4), heap.removeMax());
    expectEqual(@as(u32, 2), heap.removeMax());
    expectEqual(@as(u32, 1), heap.removeMax());
}

test "std.PriorityDequeue: iterator" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    var map = std.AutoHashMap(u32, void).init(testing.allocator);
    defer {
        heap.deinit();
        map.deinit();
    }

    const items = [_]u32{ 54, 12, 7, 23, 25, 13 };
    for (items) |e| {
        _ = try heap.add(e);
        _ = try map.put(e, {});
    }

    var it = heap.iterator();
    while (it.next()) |e| {
        _ = map.remove(e);
    }

    expectEqual(@as(usize, 0), map.count());
}

test "std.PriorityDequeue: remove at index" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    try heap.add(3);
    try heap.add(2);
    try heap.add(1);

    var it = heap.iterator();
    var elem = it.next();
    var idx: usize = 0;
    const two_idx = while (elem != null) : (elem = it.next()) {
        if (elem.? == 2)
            break idx;
        idx += 1;
    } else unreachable;

    expectEqual(heap.removeIndex(two_idx), 2);
    expectEqual(heap.removeMin(), 1);
    expectEqual(heap.removeMin(), 3);
    expectEqual(heap.removeMinOrNull(), null);
}

test "std.PriorityDequeue: iterator while empty" {
    var heap = Heap.init(testing.allocator, lessThanComparison);
    defer heap.deinit();

    var it = heap.iterator();

    expectEqual(it.next(), null);
}

test "std.PriorityDequeue: fuzz testing min" {
    var prng = std.rand.DefaultPrng.init(0x12345678);

    const test_case_count = 100;
    const heap_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMin(&prng.random, heap_size);
    }
}

fn fuzzTestMin(rng: *std.rand.Random, comptime heap_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, heap_size);

    var heap = Heap.fromOwnedSlice(allocator, lessThanComparison, items);
    defer heap.deinit();

    var last_removed: ?u32 = null;
    while (heap.removeMinOrNull()) |next| {
        if (last_removed) |last| {
            expect(last <= next);
        }
        last_removed = next;
    }
}

test "std.PriorityDequeue: fuzz testing max" {
    var prng = std.rand.DefaultPrng.init(0x87654321);

    const test_case_count = 100;
    const heap_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMax(&prng.random, heap_size);
    }
}

fn fuzzTestMax(rng: *std.rand.Random, heap_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, heap_size);

    var heap = Heap.fromOwnedSlice(testing.allocator, lessThanComparison, items);
    defer heap.deinit();

    var last_removed: ?u32 = null;
    while (heap.removeMaxOrNull()) |next| {
        if (last_removed) |last| {
            expect(last >= next);
        }
        last_removed = next;
    }
}

test "std.PriorityDequeue: fuzz testing min and max" {
    var prng = std.rand.DefaultPrng.init(0x87654321);

    const test_case_count = 100;
    const heap_size = 1_000;

    var i: usize = 0;
    while (i < test_case_count) : (i += 1) {
        try fuzzTestMinMax(&prng.random, heap_size);
    }
}

fn fuzzTestMinMax(rng: *std.rand.Random, heap_size: usize) !void {
    const allocator = testing.allocator;
    const items = try generateRandomSlice(allocator, rng, heap_size);

    var heap = Heap.fromOwnedSlice(allocator, lessThanComparison, items);
    defer heap.deinit();

    var last_min: ?u32 = null;
    var last_max: ?u32 = null;
    var i: usize = 0;
    while (i < heap_size) : (i += 1) {
        if (i % 2 == 0) {
            const next = heap.removeMin();
            if (last_min) |last| {
                expect(last <= next);
            }
            last_min = next;
        } else {
            const next = heap.removeMax();
            if (last_max) |last| {
                expect(last >= next);
            }
            last_max = next;
        }
    }
}

fn generateRandomSlice(allocator: *std.mem.Allocator, rng: *std.rand.Random, size: usize) ![]u32 {
    var array = std.ArrayList(u32).init(allocator);
    try array.ensureCapacity(size);

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = rng.int(u32);
        try array.append(elem);
    }

    return array.toOwnedSlice();
}
