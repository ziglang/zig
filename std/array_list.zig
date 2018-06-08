const std = @import("index.zig");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn ArrayList(comptime T: type) type {
    return AlignedArrayList(T, @alignOf(T));
}

pub fn AlignedArrayList(comptime T: type, comptime A: u29) type {
    return struct {
        const Self = this;

        /// Use toSlice instead of slicing this directly, because if you don't
        /// specify the end position of the slice, this will potentially give
        /// you uninitialized memory.
        items: []align(A) T,
        len: usize,
        allocator: *Allocator,

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn init(allocator: *Allocator) Self {
            return Self{
                .items = []align(A) T{},
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(l: *const Self) void {
            l.allocator.free(l.items);
        }

        pub fn toSlice(l: *const Self) []align(A) T {
            return l.items[0..l.len];
        }

        pub fn toSliceConst(l: *const Self) []align(A) const T {
            return l.items[0..l.len];
        }

        pub fn at(l: *const Self, n: usize) T {
            return l.toSliceConst()[n];
        }

        pub fn set(self: *const Self, n: usize, item: *const T) !void {
            if (n >= self.len) return error.OutOfBounds;
            self.items[n] = item.*;
        }

        pub fn count(self: *const Self) usize {
            return self.len;
        }

        /// ArrayList takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSlice(allocator: *Allocator, slice: []align(A) T) Self {
            return Self{
                .items = slice,
                .len = slice.len,
                .allocator = allocator,
            };
        }

        /// The caller owns the returned memory. ArrayList becomes empty.
        pub fn toOwnedSlice(self: *Self) []align(A) T {
            const allocator = self.allocator;
            const result = allocator.alignedShrink(T, A, self.items, self.len);
            self.* = init(allocator);
            return result;
        }

        pub fn insert(l: *Self, n: usize, item: *const T) !void {
            try l.ensureCapacity(l.len + 1);
            l.len += 1;

            mem.copy(T, l.items[n + 1 .. l.len], l.items[n .. l.len - 1]);
            l.items[n] = item.*;
        }

        pub fn insertSlice(l: *Self, n: usize, items: []align(A) const T) !void {
            try l.ensureCapacity(l.len + items.len);
            l.len += items.len;

            mem.copy(T, l.items[n + items.len .. l.len], l.items[n .. l.len - items.len]);
            mem.copy(T, l.items[n .. n + items.len], items);
        }

        pub fn append(l: *Self, item: *const T) !void {
            const new_item_ptr = try l.addOne();
            new_item_ptr.* = item.*;
        }

        pub fn appendSlice(l: *Self, items: []align(A) const T) !void {
            try l.ensureCapacity(l.len + items.len);
            mem.copy(T, l.items[l.len..], items);
            l.len += items.len;
        }

        pub fn resize(l: *Self, new_len: usize) !void {
            try l.ensureCapacity(new_len);
            l.len = new_len;
        }

        pub fn shrink(l: *Self, new_len: usize) void {
            assert(new_len <= l.len);
            l.len = new_len;
        }

        pub fn ensureCapacity(l: *Self, new_capacity: usize) !void {
            var better_capacity = l.items.len;
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            l.items = try l.allocator.alignedRealloc(T, A, l.items, better_capacity);
        }

        pub fn addOne(l: *Self) !*T {
            const new_length = l.len + 1;
            try l.ensureCapacity(new_length);
            const result = &l.items[l.len];
            l.len = new_length;
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

test "basic ArrayList test" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

        // setting on empty list is out of bounds
    list.set(0, 1) catch |err| {
        assert(err == error.OutOfBounds);
    };

    {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            list.append(i32(i + 1)) catch unreachable;
        }
    }

    {
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            assert(list.items[i] == i32(i + 1));
        }
    }

    for (list.toSlice()) |v, i| {
        assert(v == i32(i + 1));
    }

    for (list.toSliceConst()) |v, i| {
        assert(v == i32(i + 1));
    }

    assert(list.pop() == 10);
    assert(list.len == 9);

    list.appendSlice([]const i32{
        1,
        2,
        3,
    }) catch unreachable;
    assert(list.len == 12);
    assert(list.pop() == 3);
    assert(list.pop() == 2);
    assert(list.pop() == 1);
    assert(list.len == 9);

    list.appendSlice([]const i32{}) catch unreachable;
    assert(list.len == 9);
    
    // can only set on indices < self.len
    list.set(7, 33) catch unreachable;
    list.set(8, 42) catch unreachable;
    
    list.set(9, 99) catch |err| {
        assert(err == error.OutOfBounds);
    };
    list.set(10, 123) catch |err| {
        assert(err == error.OutOfBounds);
    };

    assert(list.pop() == 42);
    assert(list.pop() == 33);
}

test "iterator ArrayList test" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    var count: i32 = 0;
    var it = list.iterator();
    while (it.next()) |next| {
        assert(next == count + 1);
        count += 1;
    }

    assert(count == 3);
    assert(it.next() == null);
    it.reset();
    count = 0;
    while (it.next()) |next| {
        assert(next == count + 1);
        count += 1;
        if (count == 2) break;
    }

    it.reset();
    assert(??it.next() == 1);
}

test "insert ArrayList test" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    try list.append(1);
    try list.insert(0, 5);
    assert(list.items[0] == 5);
    assert(list.items[1] == 1);

    try list.insertSlice(1, []const i32{
        9,
        8,
    });
    assert(list.items[0] == 5);
    assert(list.items[1] == 9);
    assert(list.items[2] == 8);

    const items = []const i32{1};
    try list.insertSlice(0, items[0..0]);
    assert(list.items[0] == 5);
}
