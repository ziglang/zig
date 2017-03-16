const debug = @import("debug.zig");
const assert = debug.assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

pub fn List(comptime T: type) -> type{
    struct {
        const Self = this;

        /// Use toSlice instead of slicing this directly, because if you don't
        /// specify the end position of the slice, this will potentially give
        /// you uninitialized memory.
        items: []T,
        len: usize,
        allocator: &Allocator,

        pub fn init(allocator: &Allocator) -> Self {
            Self {
                .items = []T{},
                .len = 0,
                .allocator = allocator,
            }
        }

        pub fn deinit(l: &Self) {
            l.allocator.free(l.items);
        }

        pub fn toSlice(l: &Self) -> []T {
            return l.items[0...l.len];
        }

        pub fn toSliceConst(l: &const Self) -> []const T {
            return l.items[0...l.len];
        }

        pub fn append(l: &Self, item: T) -> %void {
            const new_item_ptr = %return l.addOne();
            *new_item_ptr = item;
        }

        pub fn resize(l: &Self, new_len: usize) -> %void {
            %return l.ensureCapacity(new_len);
            l.len = new_len;
        }

        pub fn ensureCapacity(l: &Self, new_capacity: usize) -> %void {
            var better_capacity = l.items.len;
            if (better_capacity >= new_capacity) return;
            while (true) {
                better_capacity += better_capacity / 2 + 8;
                if (better_capacity >= new_capacity) break;
            }
            l.items = %return l.allocator.realloc(T, l.items, better_capacity);
        }

        pub fn addOne(l: &Self) -> %&T {
            const new_length = l.len + 1;
            %return l.ensureCapacity(new_length);
            const result = &l.items[l.len];
            l.len = new_length;
            return result;
        }
    }
}

test "basicListTest" {
    var list = List(i32).init(&debug.global_allocator);
    defer list.deinit();

    {var i: usize = 0; while (i < 10; i += 1) {
        %%list.append(i32(i + 1));
    }}

    {var i: usize = 0; while (i < 10; i += 1) {
        assert(list.items[i] == i32(i + 1));
    }}
}
