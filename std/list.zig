const debug = @import("debug.zig");
const assert = debug.assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

pub struct List(T: type) {
    const Self = List(T);

    items: []T,
    len: usize,
    allocator: &Allocator,

    pub fn init(allocator: &Allocator) -> Self {
        Self {
            .items = zeroes,
            .len = 0,
            .allocator = allocator,
        }
    }

    pub fn deinit(l: &Self) {
        l.allocator.free(T, l.items);
    }

    pub fn toSlice(l: &Self) -> []T {
        return l.items[0...l.len];
    }

    pub fn append(l: &Self, item: T) -> %void {
        const new_length = l.len + 1;
        %return l.ensureCapacity(new_length);
        l.items[l.len] = item;
        l.len = new_length;
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
}

#attribute("test")
fn basicListTest() {
    var list = List(i32).init(&debug.global_allocator);
    defer list.deinit();

    {var i: usize = 0; while (i < 10; i += 1) {
        %%list.append(i32(i + 1));
    }}

    {var i: usize = 0; while (i < 10; i += 1) {
        assert(list.items[i] == i32(i + 1));
    }}
}
