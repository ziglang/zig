const assert = @import("index.zig").assert;
const mem = @import("mem.zig");
const Allocator = mem.Allocator;

/*
fn List(T: type) -> type {
    List(T, 8)
}
*/

pub struct SmallList(T: type, STATIC_SIZE: isize) {
    items: []T,
    length: isize,
    prealloc_items: [STATIC_SIZE]T,
    allocator: &Allocator,

    pub fn init(l: &SmallList(T, STATIC_SIZE), allocator: &Allocator) {
        l.items = l.prealloc_items[0...];
        l.length = 0;
        l.allocator = allocator;
    }

    pub fn deinit(l: &SmallList(T, STATIC_SIZE)) {
        if (l.items.ptr == &l.prealloc_items[0]) {
            l.allocator.free(l.allocator, ([]u8)(l.items));
        }
    }

    pub fn append(l: &SmallList(T, STATIC_SIZE), item: T) -> %void {
        const new_length = l.length + 1;
        %return l.ensure_capacity(new_length);
        l.items[l.length] = item;
        l.length = new_length;
    }

    pub fn ensure_capacity(l: &SmallList(T, STATIC_SIZE), new_capacity: isize) -> %void {
        const old_capacity = l.items.len;
        var better_capacity = old_capacity;
        while (better_capacity < new_capacity) {
            better_capacity *= 2;
        }
        if (better_capacity != old_capacity) {
            const alloc_bytes = better_capacity * @sizeof(T);
            if (l.items.ptr == &l.prealloc_items[0]) {
                l.items = ([]T)(%return l.allocator.alloc(l.allocator, alloc_bytes));
                @memcpy(l.items.ptr, &l.prealloc_items[0], old_capacity * @sizeof(T));
            } else {
                l.items = ([]T)(%return l.allocator.realloc(l.allocator, ([]u8)(l.items), alloc_bytes));
            }
        }
    }
}

var global_allocator = Allocator {
    .alloc = global_alloc,
    .realloc = global_realloc,
    .free = global_free,
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
