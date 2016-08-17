const Allocator = @import("mem.zig").Allocator;
const io = @import("io.zig");

pub fn assert(b: bool) {
    if (!b) unreachable{}
}

pub fn printStackTrace() {
    var maybe_fp: ?&const u8 = @frameAddress();
    while (true) {
        const fp = maybe_fp ?? break;
        const return_address = *(&const usize)(usize(fp) + @sizeOf(usize));
        %%io.stderr.print_u64(return_address);
        %%io.stderr.printf("\n");
        maybe_fp = *(&const ?&const u8)(fp);
    }
}

pub var global_allocator = Allocator {
    .allocFn = globalAlloc,
    .reallocFn = globalRealloc,
    .freeFn = globalFree,
    .context = null,
};

var some_mem: [10 * 1024]u8 = undefined;
var some_mem_index: usize = 0;

fn globalAlloc(self: &Allocator, n: usize) -> %[]u8 {
    const result = some_mem[some_mem_index ... some_mem_index + n];
    some_mem_index += n;
    return result;
}

fn globalRealloc(self: &Allocator, old_mem: []u8, new_size: usize) -> %[]u8 {
    const result = %return globalAlloc(self, new_size);
    @memcpy(result.ptr, old_mem.ptr, old_mem.len);
    return result;
}

fn globalFree(self: &Allocator, old_mem: []u8) { }
