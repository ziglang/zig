const std = @import("index.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

// Imagine that `fn at(self: &Self, index: usize) &T` is a customer asking for a box
// from a warehouse, based on a flat array, boxes ordered from 0 to N - 1.
// But the warehouse actually stores boxes in shelves of increasing powers of 2 sizes.
// So when the customer requests a box index, we have to translate it to shelf index
// and box index within that shelf. Illustration:
//
// customer indexes:
// shelf 0:  0
// shelf 1:  1  2
// shelf 2:  3  4  5  6
// shelf 3:  7  8  9 10 11 12 13 14
// shelf 4: 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
// shelf 5: 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62
// ...
//
// warehouse indexes:
// shelf 0:  0
// shelf 1:  0  1
// shelf 2:  0  1  2  3
// shelf 3:  0  1  2  3  4  5  6  7
// shelf 4:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
// shelf 5:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
// ...
//
// With this arrangement, here are the equations to get the shelf index and
// box index based on customer box index:
//
// shelf_index = floor(log2(customer_index + 1))
// shelf_count = ceil(log2(box_count + 1))
// box_index = customer_index + 1 - 2 ** shelf
// shelf_size = 2 ** shelf_index
//
// Now we complicate it a little bit further by adding a preallocated shelf, which must be
// a power of 2:
// prealloc=4
//
// customer indexes:
// prealloc:  0  1  2  3
//  shelf 0:  4  5  6  7  8  9 10 11
//  shelf 1: 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27
//  shelf 2: 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59
// ...
//
// warehouse indexes:
// prealloc:  0  1  2  3
//  shelf 0:  0  1  2  3  4  5  6  7
//  shelf 1:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
//  shelf 2:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
// ...
//
// Now the equations are:
//
// shelf_index = floor(log2(customer_index + prealloc)) - log2(prealloc) - 1
// shelf_count = ceil(log2(box_count + prealloc)) - log2(prealloc) - 1
// box_index = customer_index + prealloc - 2 ** (log2(prealloc) + 1 + shelf)
// shelf_size = prealloc * 2 ** (shelf_index + 1)

/// This is a stack data structure where pointers to indexes have the same lifetime as the data structure
/// itself, unlike ArrayList where push() invalidates all existing element pointers.
/// The tradeoff is that elements are not guaranteed to be contiguous. For that, use ArrayList.
/// Note however that most elements are contiguous, making this data structure cache-friendly.
///
/// Because it never has to copy elements from an old location to a new location, it does not require
/// its elements to be copyable, and it avoids wasting memory when backed by an ArenaAllocator.
/// Note that the push() and pop() convenience methods perform a copy, but you can instead use
/// addOne(), at(), setCapacity(), and shrinkCapacity() to avoid copying items.
///
/// This data structure has O(1) push and O(1) pop.
///
/// It supports preallocated elements, making it especially well suited when the expected maximum
/// size is small. `prealloc_item_count` must be 0, or a power of 2.
pub fn SegmentedList(comptime T: type, comptime prealloc_item_count: usize) type {
    return struct {
        const Self = this;
        const prealloc_exp = blk: {
            // we don't use the prealloc_exp constant when prealloc_item_count is 0.
            assert(prealloc_item_count != 0);

            const value = std.math.log2_int(usize, prealloc_item_count);
            assert((1 << value) == prealloc_item_count); // prealloc_item_count must be a power of 2
            break :blk @typeOf(1)(value);
        };
        const ShelfIndex = std.math.Log2Int(usize);

        prealloc_segment: [prealloc_item_count]T,
        dynamic_segments: [][*]T,
        allocator: *Allocator,
        len: usize,

        pub const prealloc_count = prealloc_item_count;

        /// Deinitialize with `deinit`
        pub fn init(allocator: *Allocator) Self {
            return Self{
                .allocator = allocator,
                .len = 0,
                .prealloc_segment = undefined,
                .dynamic_segments = [][*]T{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.freeShelves(@intCast(ShelfIndex, self.dynamic_segments.len), 0);
            self.allocator.free(self.dynamic_segments);
            self.* = undefined;
        }

        pub fn at(self: *Self, i: usize) *T {
            assert(i < self.len);
            return self.uncheckedAt(i);
        }

        pub fn count(self: *const Self) usize {
            return self.len;
        }

        pub fn push(self: *Self, item: *const T) !void {
            const new_item_ptr = try self.addOne();
            new_item_ptr.* = item.*;
        }

        pub fn pushMany(self: *Self, items: []const T) !void {
            for (items) |item| {
                try self.push(item);
            }
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;

            const index = self.len - 1;
            const result = self.uncheckedAt(index).*;
            self.len = index;
            return result;
        }

        pub fn addOne(self: *Self) !*T {
            const new_length = self.len + 1;
            try self.growCapacity(new_length);
            const result = self.uncheckedAt(self.len);
            self.len = new_length;
            return result;
        }

        /// Grows or shrinks capacity to match usage.
        pub fn setCapacity(self: *Self, new_capacity: usize) !void {
            if (new_capacity <= usize(1) << (prealloc_exp + self.dynamic_segments.len)) {
                return self.shrinkCapacity(new_capacity);
            } else {
                return self.growCapacity(new_capacity);
            }
        }

        /// Only grows capacity, or retains current capacity
        pub fn growCapacity(self: *Self, new_capacity: usize) !void {
            const new_cap_shelf_count = shelfCount(new_capacity);
            const old_shelf_count = @intCast(ShelfIndex, self.dynamic_segments.len);
            if (new_cap_shelf_count > old_shelf_count) {
                self.dynamic_segments = try self.allocator.realloc([*]T, self.dynamic_segments, new_cap_shelf_count);
                var i = old_shelf_count;
                errdefer {
                    self.freeShelves(i, old_shelf_count);
                    self.dynamic_segments = self.allocator.shrink([*]T, self.dynamic_segments, old_shelf_count);
                }
                while (i < new_cap_shelf_count) : (i += 1) {
                    self.dynamic_segments[i] = (try self.allocator.alloc(T, shelfSize(i))).ptr;
                }
            }
        }

        /// Only shrinks capacity or retains current capacity
        pub fn shrinkCapacity(self: *Self, new_capacity: usize) void {
            if (new_capacity <= prealloc_item_count) {
                const len = @intCast(ShelfIndex, self.dynamic_segments.len);
                self.freeShelves(len, 0);
                self.allocator.free(self.dynamic_segments);
                self.dynamic_segments = [][*]T{};
                return;
            }

            const new_cap_shelf_count = shelfCount(new_capacity);
            const old_shelf_count = @intCast(ShelfIndex, self.dynamic_segments.len);
            assert(new_cap_shelf_count <= old_shelf_count);
            if (new_cap_shelf_count == old_shelf_count) {
                return;
            }

            self.freeShelves(old_shelf_count, new_cap_shelf_count);
            self.dynamic_segments = self.allocator.shrink([*]T, self.dynamic_segments, new_cap_shelf_count);
        }

        pub fn uncheckedAt(self: *Self, index: usize) *T {
            if (index < prealloc_item_count) {
                return &self.prealloc_segment[index];
            }
            const shelf_index = shelfIndex(index);
            const box_index = boxIndex(index, shelf_index);
            return &self.dynamic_segments[shelf_index][box_index];
        }

        fn shelfCount(box_count: usize) ShelfIndex {
            if (prealloc_item_count == 0) {
                return std.math.log2_int_ceil(usize, box_count + 1);
            }
            return std.math.log2_int_ceil(usize, box_count + prealloc_item_count) - prealloc_exp - 1;
        }

        fn shelfSize(shelf_index: ShelfIndex) usize {
            if (prealloc_item_count == 0) {
                return usize(1) << shelf_index;
            }
            return usize(1) << (shelf_index + (prealloc_exp + 1));
        }

        fn shelfIndex(list_index: usize) ShelfIndex {
            if (prealloc_item_count == 0) {
                return std.math.log2_int(usize, list_index + 1);
            }
            return std.math.log2_int(usize, list_index + prealloc_item_count) - prealloc_exp - 1;
        }

        fn boxIndex(list_index: usize, shelf_index: ShelfIndex) usize {
            if (prealloc_item_count == 0) {
                return (list_index + 1) - (usize(1) << shelf_index);
            }
            return list_index + prealloc_item_count - (usize(1) << ((prealloc_exp + 1) + shelf_index));
        }

        fn freeShelves(self: *Self, from_count: ShelfIndex, to_count: ShelfIndex) void {
            var i = from_count;
            while (i != to_count) {
                i -= 1;
                self.allocator.free(self.dynamic_segments[i][0..shelfSize(i)]);
            }
        }

        pub const Iterator = struct {
            list: *Self,
            index: usize,
            box_index: usize,
            shelf_index: ShelfIndex,
            shelf_size: usize,

            pub fn next(it: *Iterator) ?*T {
                if (it.index >= it.list.len) return null;
                if (it.index < prealloc_item_count) {
                    const ptr = &it.list.prealloc_segment[it.index];
                    it.index += 1;
                    if (it.index == prealloc_item_count) {
                        it.box_index = 0;
                        it.shelf_index = 0;
                        it.shelf_size = prealloc_item_count * 2;
                    }
                    return ptr;
                }

                const ptr = &it.list.dynamic_segments[it.shelf_index][it.box_index];
                it.index += 1;
                it.box_index += 1;
                if (it.box_index == it.shelf_size) {
                    it.shelf_index += 1;
                    it.box_index = 0;
                    it.shelf_size *= 2;
                }
                return ptr;
            }

            pub fn prev(it: *Iterator) ?*T {
                if (it.index == 0) return null;

                it.index -= 1;
                if (it.index < prealloc_item_count) return &it.list.prealloc_segment[it.index];

                if (it.box_index == 0) {
                    it.shelf_index -= 1;
                    it.shelf_size /= 2;
                    it.box_index = it.shelf_size - 1;
                } else {
                    it.box_index -= 1;
                }

                return &it.list.dynamic_segments[it.shelf_index][it.box_index];
            }

            pub fn peek(it: *Iterator) ?*T {
                if (it.index >= it.list.len)
                    return null;
                if (it.index < prealloc_item_count)
                    return &it.list.prealloc_segment[it.index];

                return &it.list.dynamic_segments[it.shelf_index][it.box_index];
            }

            pub fn set(it: *Iterator, index: usize) void {
                it.index = index;
                if (index < prealloc_item_count) return;
                it.shelf_index = shelfIndex(index);
                it.box_index = boxIndex(index, it.shelf_index);
                it.shelf_size = shelfSize(it.shelf_index);
            }
        };

        pub fn iterator(self: *Self, start_index: usize) Iterator {
            var it = Iterator{
                .list = self,
                .index = undefined,
                .shelf_index = undefined,
                .box_index = undefined,
                .shelf_size = undefined,
            };
            it.set(start_index);
            return it;
        }
    };
}

test "std.SegmentedList" {
    var da = std.heap.DirectAllocator.init();
    defer da.deinit();
    var a = &da.allocator;

    try testSegmentedList(0, a);
    try testSegmentedList(1, a);
    try testSegmentedList(2, a);
    try testSegmentedList(4, a);
    try testSegmentedList(8, a);
    try testSegmentedList(16, a);
}

fn testSegmentedList(comptime prealloc: usize, allocator: *Allocator) !void {
    var list = SegmentedList(i32, prealloc).init(allocator);
    defer list.deinit();

    {
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            try list.push(@intCast(i32, i + 1));
            assert(list.len == i + 1);
        }
    }

    {
        var i: usize = 0;
        while (i < 100) : (i += 1) {
            assert(list.at(i).* == @intCast(i32, i + 1));
        }
    }

    {
        var it = list.iterator(0);
        var x: i32 = 0;
        while (it.next()) |item| {
            x += 1;
            assert(item.* == x);
        }
        assert(x == 100);
        while (it.prev()) |item| : (x -= 1) {
            assert(item.* == x);
        }
        assert(x == 0);
    }

    assert(list.pop().? == 100);
    assert(list.len == 99);

    try list.pushMany([]i32{
        1,
        2,
        3,
    });
    assert(list.len == 102);
    assert(list.pop().? == 3);
    assert(list.pop().? == 2);
    assert(list.pop().? == 1);
    assert(list.len == 99);

    try list.pushMany([]const i32{});
    assert(list.len == 99);

    var i: i32 = 99;
    while (list.pop()) |item| : (i -= 1) {
        assert(item == i);
        list.shrinkCapacity(list.len);
    }
}
