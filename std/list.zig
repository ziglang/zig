const debug = @import("debug.zig");
const assert = debug.assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

pub fn List(inline T: type) -> type {
    SmallList(T, @sizeOf(usize))
}

// TODO: make sure that setting static_size to 0 codegens to the same code
// as if this were programmed without static_size at all.
pub struct SmallList(T: type, static_size: usize) {
    const Self = SmallList(T, static_size);

    items: []T,
    len: usize,
    prealloc_items: [static_size]T,
    allocator: &Allocator,

    pub fn init(l: &Self, allocator: &Allocator) {
        l.items = l.prealloc_items[0...];
        l.len = 0;
        l.allocator = allocator;
    }

    pub fn deinit(l: &Self) {
        if (l.items.ptr != &l.prealloc_items[0]) {
            l.allocator.free(T, l.items);
        }
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
        const old_capacity = l.items.len;
        var better_capacity = old_capacity;
        while (better_capacity < new_capacity) {
            better_capacity *= 2;
        }
        if (better_capacity != old_capacity) {
            if (l.items.ptr == &l.prealloc_items[0]) {
                l.items = %return l.allocator.alloc(T, better_capacity);
                mem.copy(T, l.items, l.prealloc_items[0...old_capacity]);
            } else {
                l.items = %return l.allocator.realloc(T, l.items, better_capacity);
            }
        }
    }
}

#attribute("test")
fn basicListTest() {
    var list: List(i32) = undefined;
    list.init(&debug.global_allocator);
    defer list.deinit();

    {var i: usize = 0; while (i < 10; i += 1) {
        %%list.append(i32(i + 1));
    }}

    {var i: usize = 0; while (i < 10; i += 1) {
        assert(list.items[i] == i32(i + 1));
    }}
}
