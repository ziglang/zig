const std = @import("std.zig");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn ArrayList(comptime T: type) type {
    return AlignedArrayList(T, null);
}

pub fn AlignedArrayList(comptime T: type, comptime alignment: ?u29) type {
    if (alignment) |a| {
        if (a == @alignOf(T)) {
            return AlignedArrayList(T, null);
        }
    }
    return struct {
        const Self = @This();

        /// Use toSlice instead of slicing this directly, because if you don't
        /// specify the end position of the slice, this will potentially give
        /// you uninitialized memory.
        items: Slice,
        len: usize,
        allocator: *Allocator,

        pub const Slice = if (alignment) |a| ([]align(a) T) else []T;
        pub const SliceConst = if (alignment) |a| ([]align(a) const T) else []const T;

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn init(allocator: *Allocator) Self {
            return Self{
                .items = [_]T{},
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items);
        }

        pub fn toSlice(self: Self) Slice {
            return self.items[0..self.len];
        }

        pub fn toSliceConst(self: Self) SliceConst {
            return self.items[0..self.len];
        }

        pub fn at(self: Self, i: usize) T {
            return self.toSliceConst()[i];
        }

        /// Sets the value at index `i`, or returns `error.OutOfBounds` if
        /// the index is not in range.
        pub fn setOrError(self: Self, i: usize, item: T) !void {
            if (i >= self.len) return error.OutOfBounds;
            self.items[i] = item;
        }

        /// Sets the value at index `i`, asserting that the value is in range.
        pub fn set(self: *Self, i: usize, item: T) void {
            assert(i < self.len);
            self.items[i] = item;
        }

        pub fn count(self: Self) usize {
            return self.len;
        }

        pub fn capacity(self: Self) usize {
            return self.items.len;
        }

        /// ArrayList takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSlice(allocator: *Allocator, slice: Slice) Self {
            return Self{
                .items = slice,
                .len = slice.len,
                .allocator = allocator,
            };
        }

        /// The caller owns the returned memory. ArrayList becomes empty.
        pub fn toOwnedSlice(self: *Self) Slice {
            const allocator = self.allocator;
            const result = allocator.shrink(self.items, self.len);
            self.* = init(allocator);
            return result;
        }

        pub fn insert(self: *Self, n: usize, item: T) !void {
            try self.ensureCapacity(self.len + 1);
            self.len += 1;

            mem.copyBackwards(T, self.items[n + 1 .. self.len], self.items[n .. self.len - 1]);
            self.items[n] = item;
        }

        pub fn insertSlice(self: *Self, n: usize, items: SliceConst) !void {
            try self.ensureCapacity(self.len + items.len);
            self.len += items.len;

            mem.copyBackwards(T, self.items[n + items.len .. self.len], self.items[n .. self.len - items.len]);
            mem.copy(T, self.items[n .. n + items.len], items);
        }

        pub fn append(self: *Self, item: T) !void {
            const new_item_ptr = try self.addOne();
            new_item_ptr.* = item;
        }

        pub fn appendAssumeCapacity(self: *Self, item: T) void {
            const new_item_ptr = self.addOneAssumeCapacity();
            new_item_ptr.* = item;
        }

        pub fn orderedRemove(self: *Self, i: usize) T {
            const newlen = self.len - 1;
            if (newlen == i) return self.pop();

            const old_item = self.at(i);
            for (self.items[i..newlen]) |*b, j| b.* = self.items[i + 1 + j];
            self.items[newlen] = undefined;
            self.len = newlen;
            return old_item;
        }

        /// Removes the element at the specified index and returns it.
        /// The empty slot is filled from the end of the list.
        pub fn swapRemove(self: *Self, i: usize) T {
            if (self.len - 1 == i) return self.pop();

            const slice = self.toSlice();
            const old_item = slice[i];
            slice[i] = self.pop();
            return old_item;
        }

        /// Removes the element at the specified index and returns it
        /// or an error.OutOfBounds is returned. If no error then
        /// the empty slot is filled from the end of the list.
        pub fn swapRemoveOrError(self: *Self, i: usize) !T {
            if (i >= self.len) return error.OutOfBounds;
            return self.swapRemove(i);
        }

        pub fn appendSlice(self: *Self, items: SliceConst) !void {
            try self.ensureCapacity(self.len + items.len);
            mem.copy(T, self.items[self.len..], items);
            self.len += items.len;
        }

        pub fn resize(self: *Self, new_len: usize) !void {
            try self.ensureCapacity(new_len);
            self.len = new_len;
        }

        pub fn shrink(self: *Self, new_len: usize) void {
            assert(new_len <= self.len);
            self.len = new_len;
            self.items = self.allocator.realloc(self.items, new_len) catch |e| switch (e) {
                error.OutOfMemory => return, // no problem, capacity is still correct then.
            };
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

        pub fn addOne(self: *Self) !*T {
            const new_length = self.len + 1;
            try self.ensureCapacity(new_length);
            return self.addOneAssumeCapacity();
        }

        pub fn addOneAssumeCapacity(self: *Self) *T {
            assert(self.count() < self.capacity());
            const result = &self.items[self.len];
            self.len += 1;
            return result;
        }

        pub fn pop(self: *Self) T {
            self.len -= 1;
            return self.items[self.len];
        }

        pub fn popOrNull(self: *Self) ?T {
            if (self.len == 0) return null;
            return self.pop();
        }

        pub const Iterator = struct {
            list: *const Self,
            // how many items have we returned
            count: usize,

            pub fn next(it: *Iterator) ?T {
                if (it.count >= it.list.len) return null;
                const val = it.list.at(it.count);
                it.count += 1;
                return val;
            }

            pub fn reset(it: *Iterator) void {
                it.count = 0;
            }
        };

        pub fn iterator(self: *const Self) Iterator {
            return Iterator{
                .list = self,
                .count = 0,
            };
        }
    };
}

test "std.ArrayList.init" {
    var bytes: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;

    var list = ArrayList(i32).init(allocator);
    defer list.deinit();

    testing.expect(list.count() == 0);
    testing.expect(list.capacity() == 0);
}

test "std.ArrayList.basic" {
    var bytes: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;

    var list = ArrayList(i32).init(allocator);
    defer list.deinit();

    // setting on empty list is out of bounds
    testing.expectError(error.OutOfBounds, list.setOrError(0, 1));

    {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            list.append(@intCast(i32, i + 1)) catch unreachable;
        }
    }

    {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            testing.expect(list.items[i] == @intCast(i32, i + 1));
        }
    }

    for (list.toSlice()) |v, i| {
        testing.expect(v == @intCast(i32, i + 1));
    }

    for (list.toSliceConst()) |v, i| {
        testing.expect(v == @intCast(i32, i + 1));
    }

    testing.expect(list.pop() == 10);
    testing.expect(list.len == 9);

    list.appendSlice([_]i32{
        1,
        2,
        3,
    }) catch unreachable;
    testing.expect(list.len == 12);
    testing.expect(list.pop() == 3);
    testing.expect(list.pop() == 2);
    testing.expect(list.pop() == 1);
    testing.expect(list.len == 9);

    list.appendSlice([_]i32{}) catch unreachable;
    testing.expect(list.len == 9);

    // can only set on indices < self.len
    list.set(7, 33);
    list.set(8, 42);

    testing.expectError(error.OutOfBounds, list.setOrError(9, 99));
    testing.expectError(error.OutOfBounds, list.setOrError(10, 123));

    testing.expect(list.pop() == 42);
    testing.expect(list.pop() == 33);
}

test "std.ArrayList.orderedRemove" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.append(4);
    try list.append(5);
    try list.append(6);
    try list.append(7);

    //remove from middle
    testing.expectEqual(i32(4), list.orderedRemove(3));
    testing.expectEqual(i32(5), list.at(3));
    testing.expectEqual(usize(6), list.len);

    //remove from end
    testing.expectEqual(i32(7), list.orderedRemove(5));
    testing.expectEqual(usize(5), list.len);

    //remove from front
    testing.expectEqual(i32(1), list.orderedRemove(0));
    testing.expectEqual(i32(2), list.at(0));
    testing.expectEqual(usize(4), list.len);
}

test "std.ArrayList.swapRemove" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.append(4);
    try list.append(5);
    try list.append(6);
    try list.append(7);

    //remove from middle
    testing.expect(list.swapRemove(3) == 4);
    testing.expect(list.at(3) == 7);
    testing.expect(list.len == 6);

    //remove from end
    testing.expect(list.swapRemove(5) == 6);
    testing.expect(list.len == 5);

    //remove from front
    testing.expect(list.swapRemove(0) == 1);
    testing.expect(list.at(0) == 5);
    testing.expect(list.len == 4);
}

test "std.ArrayList.swapRemoveOrError" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    // Test just after initialization
    testing.expectError(error.OutOfBounds, list.swapRemoveOrError(0));

    // Test after adding one item and remote it
    try list.append(1);
    testing.expect((try list.swapRemoveOrError(0)) == 1);
    testing.expectError(error.OutOfBounds, list.swapRemoveOrError(0));

    // Test after adding two items and remote both
    try list.append(1);
    try list.append(2);
    testing.expect((try list.swapRemoveOrError(1)) == 2);
    testing.expect((try list.swapRemoveOrError(0)) == 1);
    testing.expectError(error.OutOfBounds, list.swapRemoveOrError(0));

    // Test out of bounds with one item
    try list.append(1);
    testing.expectError(error.OutOfBounds, list.swapRemoveOrError(1));

    // Test out of bounds with two items
    try list.append(2);
    testing.expectError(error.OutOfBounds, list.swapRemoveOrError(2));
}

test "std.ArrayList.iterator" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    var count: i32 = 0;
    var it = list.iterator();
    while (it.next()) |next| {
        testing.expect(next == count + 1);
        count += 1;
    }

    testing.expect(count == 3);
    testing.expect(it.next() == null);
    it.reset();
    count = 0;
    while (it.next()) |next| {
        testing.expect(next == count + 1);
        count += 1;
        if (count == 2) break;
    }

    it.reset();
    testing.expect(it.next().? == 1);
}

test "std.ArrayList.insert" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.insert(0, 5);
    testing.expect(list.items[0] == 5);
    testing.expect(list.items[1] == 1);
    testing.expect(list.items[2] == 2);
    testing.expect(list.items[3] == 3);
}

test "std.ArrayList.insertSlice" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);
    try list.append(4);
    try list.insertSlice(1, [_]i32{
        9,
        8,
    });
    testing.expect(list.items[0] == 1);
    testing.expect(list.items[1] == 9);
    testing.expect(list.items[2] == 8);
    testing.expect(list.items[3] == 2);
    testing.expect(list.items[4] == 3);
    testing.expect(list.items[5] == 4);

    const items = [_]i32{1};
    try list.insertSlice(0, items[0..0]);
    testing.expect(list.len == 6);
    testing.expect(list.items[0] == 1);
}

const Item = struct {
    integer: i32,
    sub_items: ArrayList(Item),
};

test "std.ArrayList: ArrayList(T) of struct T" {
    var root = Item{ .integer = 1, .sub_items = ArrayList(Item).init(debug.global_allocator) };
    try root.sub_items.append(Item{ .integer = 42, .sub_items = ArrayList(Item).init(debug.global_allocator) });
    testing.expect(root.sub_items.items[0].integer == 42);
}
