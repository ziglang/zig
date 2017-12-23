const debug = @import("debug.zig");
const assert = debug.assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

pub fn ArrayList(comptime T: type) -> type {
    return AlignedArrayList(T, @alignOf(T));
}

pub fn AlignedArrayList(comptime T: type, comptime A: u29) -> type{
    return struct {
        const Self = this;

        /// Use toSlice instead of slicing this directly, because if you don't
        /// specify the end position of the slice, this will potentially give
        /// you uninitialized memory.
        items: []align(A) T,
        len: usize,
        allocator: &Allocator,

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn init(allocator: &Allocator) -> Self {
            return Self {
                .items = []align(A) T{},
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(l: &Self) {
            l.allocator.free(l.items);
        }

        pub fn toSlice(l: &Self) -> []align(A) T {
            return l.items[0..l.len];
        }

        pub fn toSliceConst(l: &const Self) -> []align(A) const T {
            return l.items[0..l.len];
        }

        /// ArrayList takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn fromOwnedSlice(allocator: &Allocator, slice: []align(A) T) -> Self {
            return Self {
                .items = slice,
                .len = slice.len,
                .allocator = allocator,
            };
        }

        /// The caller owns the returned memory. ArrayList becomes empty.
        pub fn toOwnedSlice(self: &Self) -> []align(A) T {
            const allocator = self.allocator;
            const result = allocator.alignedShrink(T, A, self.items, self.len);
            *self = init(allocator);
            return result;
        }

        pub fn append(l: &Self, item: &const T) -> %void {
            const new_item_ptr = %return l.addOne();
            *new_item_ptr = *item;
        }

        pub fn appendSlice(l: &Self, items: []align(A) const T) -> %void {
            %return l.ensureCapacity(l.len + items.len);
            mem.copy(T, l.items[l.len..], items);
            l.len += items.len;
        }

        pub fn resize(l: &Self, new_len: usize) -> %void {
            %return l.ensureCapacity(new_len);
            l.len = new_len;
        }

        pub fn shrink(l: &Self, new_len: usize) {
            assert(new_len <= l.len);
            l.len = new_len;
        }

        pub fn ensureCapacity(l: &Self, new_capacity: usize) -> %void {
            var better_capacity = l.items.len;
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            l.items = %return l.allocator.alignedRealloc(T, A, l.items, better_capacity);
        }

        pub fn addOne(l: &Self) -> %&T {
            const new_length = l.len + 1;
            %return l.ensureCapacity(new_length);
            const result = &l.items[l.len];
            l.len = new_length;
            return result;
        }

        pub fn pop(self: &Self) -> T {
            self.len -= 1;
            return self.items[self.len];
        }

        pub fn popOrNull(self: &Self) -> ?T {
            if (self.len == 0)
                return null;
            return self.pop();
        }
    };
}

test "basic ArrayList test" {
    var list = ArrayList(i32).init(debug.global_allocator);
    defer list.deinit();

    {var i: usize = 0; while (i < 10) : (i += 1) {
        %%list.append(i32(i + 1));
    }}

    {var i: usize = 0; while (i < 10) : (i += 1) {
        assert(list.items[i] == i32(i + 1));
    }}

    assert(list.pop() == 10);
    assert(list.len == 9);

    %%list.appendSlice([]const i32 { 1, 2, 3 });
    assert(list.len == 12);
    assert(list.pop() == 3);
    assert(list.pop() == 2);
    assert(list.pop() == 1);
    assert(list.len == 9);

    %%list.appendSlice([]const i32 {});
    assert(list.len == 9);
}
