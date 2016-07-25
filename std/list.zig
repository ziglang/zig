const assert = @import("debug.zig").assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

pub inline fn List(inline T: type) -> type {
    SmallList(T, 8)
}

pub struct SmallList(T: type, STATIC_SIZE: isize) {
    const Self = SmallList(T, STATIC_SIZE);

    items: []T,
    length: isize,
    prealloc_items: [STATIC_SIZE]T,
    allocator: &Allocator,

    pub fn init(l: &Self, allocator: &Allocator) {
        l.items = l.prealloc_items[0...];
        l.length = 0;
        l.allocator = allocator;
    }

    pub fn deinit(l: &Self) {
        if (l.items.ptr != &l.prealloc_items[0]) {
            l.allocator.free(T, l.items);
        }
    }

    pub fn append(l: &Self, item: T) -> %void {
        const new_length = l.length + 1;
        %return l.ensure_capacity(new_length);
        l.items[l.length] = item;
        l.length = new_length;
    }

    pub fn ensure_capacity(l: &Self, new_capacity: isize) -> %void {
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

var global_allocator = Allocator {
    .alloc_fn = global_alloc,
    .realloc_fn = global_realloc,
    .free_fn = global_free,
    .context = null,
};

var some_mem: [200]u8 = undefined;
var some_mem_index: isize = 0;

fn global_alloc(self: &Allocator, n: isize) -> %[]u8 {
    const result = some_mem[some_mem_index ... some_mem_index + n];
    some_mem_index += n;
    return result;
}

fn global_realloc(self: &Allocator, old_mem: []u8, new_size: isize) -> %[]u8 {
    const result = %return global_alloc(self, new_size);
    @memcpy(result.ptr, old_mem.ptr, old_mem.len);
    return result;
}

fn global_free(self: &Allocator, old_mem: []u8) {
}

#attribute("test")
fn basic_list_test() {
    var list: SmallList(i32, 4) = undefined;
    list.init(&global_allocator);
    defer list.deinit();

    {var i: isize = 0; while (i < 10; i += 1) {
        %%list.append(i32(i + 1));
    }}

    {var i: isize = 0; while (i < 10; i += 1) {
        assert(list.items[i] == i32(i + 1));
    }}
}
