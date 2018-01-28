const builtin = @import("builtin");
const debug = @import("debug/index.zig");
const assert = debug.assert;
const ll = @import("linked_list.zig");
const mem = @import("mem.zig");
const mp = @import("mem_pool.zig");
const rand = @import("rand.zig");

error Unsupported;

// XXX: make reasonable values for these
// XXX: make the size class list a comptime argument to a function that
// generates the type instead of being a global list
const SIZE_CLASSES = []usize { 8, 64, 1024, 4096 };

// XXX: same deal with configurability
const POOL_COUNTS: usize = 16 * 1024;

pub const GpAlloc = struct {
    allocator: mem.Allocator,

    // each of these memory pools actually returns slices of the corresponding
    // size class
    pools: [SIZE_CLASSES.len]mp.RawMemoryPool,

    const Self = this;

    const AllocMd = struct {
        // XXX: any good way to pack this to work well with smaller size
        // classes?
        size_class: usize
    };

    fn get_size_class(self: &Self, size: usize) ?usize {
        for (SIZE_CLASSES) |size_class, i| {
            if (size_class >= size) {
                return i;
            }
        }

        return null;
    }

    // XXX: is there a way to make separate comptime and non-ct versions of
    // this?
    fn get_pool(self: &Self, size: usize) ?&mp.RawMemoryPool {
        const size_class = self.get_size_class(size) ?? null;
        return &self.pools[size_class];
    }

    fn raw_alloc(self: &mem.Allocator, n: usize) %[]u8 {
        // XXX: mmap
        return error.Unsupported;
    }

    fn raw_free(self: &mem.Allocator, bytes: []u8) void {
        // XXX: munmap
    }

    fn alloc(allocator: &mem.Allocator, n: usize, alignment: u29) %[]u8 {
        var self = @fieldParentPtr(GpAlloc, "allocator", allocator);
        return self.alloc_impl(n, alignment);
    }

    // This is mainly split out for testing purposes
    fn alloc_impl(self: &Self, n: usize, alignment: u29) %[]u8 {
        // XXX: if this request is too big for any of the pre-defined pools then
        // just create a separate buffer juts for it
        var size_class = self.get_size_class(n) ?? {
            return raw_alloc(&self.allocator, n);
        };

        var pool = &self.pools[size_class];

        const mem_base = try pool.alloc();

        // XXX: account for alignment

        // mark the prefix metadata with the size class where this memory should
        // be returned to when it's freed
        var md = @intToPtr(&AllocMd, mem_base);
        md.size_class = size_class;

        // return a pointer to the payload data immediately following the
        // allocator metadata
        const payload_base = @intToPtr(&u8, mem_base + @sizeOf(AllocMd));
        return payload_base[0..n];
    }

    fn realloc(allocator: &mem.Allocator, old_mem: []u8, new_size: usize, alignment: u29) %[]u8 {
        return error.Unsupported;
    }

    fn free(allocator: &mem.Allocator, bytes: []u8) void {
        var self = @fieldParentPtr(GpAlloc, "allocator", allocator);
        var payload = @ptrToInt(bytes.ptr);
        const size_class = self.get_size_class(bytes.len) ?? {
            raw_free(allocator, bytes);
            return;
        };

        var md = @intToPtr(&AllocMd, payload - @sizeOf(AllocMd));
        if (builtin.mode == builtin.Mode.Debug) {
            assert(md.size_class == size_class);
        }

        var pool = &self.pools[size_class];
        pool.free(@ptrToInt(md));
    }

    // XXX: allow user to configure maximum memory usage at creation time
    // XXX: provide option to grow pools on demand
    pub fn init() %Self {
        const undef_pool: mp.RawMemoryPool = undefined;
        var res = Self {
            .allocator = mem.Allocator{
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free
            },
            .pools = []mp.RawMemoryPool { undef_pool } ** SIZE_CLASSES.len
        };

        const pool_base: usize = @ptrToInt(&res.pools);
        for (SIZE_CLASSES) |size_class, i| {
            res.pools[i] = try mp.RawMemoryPool.init(
                size_class + @sizeOf(AllocMd), POOL_COUNTS);
            errdefer {
                res.pools[i].deinit() %% {};
            }
        }

        return res;
    }
};

const TestStruct = struct {
    foo: usize,
    bar: u32
};

const TestAllocation = struct {
    start: usize,
    len: usize
};

const N_ALLOC: usize = 4096;
const N_ROUNDS: usize = N_ALLOC * 2;

test "memory_available" {
    var gp_allocator = GpAlloc.init() catch unreachable;
    var allocator = &gp_allocator.allocator;

    // pick a fixed size so we always draw from the same size class
    const Foo = struct {
        data: [2468]u8
    };

    var last_alloc: []Foo = undefined;
    var i: usize = 0;

    // we should be able to allocate each of the items in the size pool
    while (i < POOL_COUNTS) : (i += 1) {
        last_alloc = allocator.alloc(Foo, 1) catch unreachable;
    }

    // the next allocation should fail because the size pool is empty
    var empty_alloc = allocator.alloc(Foo, 1);
    if (empty_alloc) |val| {
        unreachable;
    } else |err| {
        assert(err == error.OutOfMemory);
    }

    // after freeing one of the allocated items, we should be able to allocate
    // new ones again
    allocator.free(last_alloc);
    last_alloc = allocator.alloc(Foo, 1) catch unreachable;

    empty_alloc = allocator.alloc(Foo, 1);
    if (empty_alloc) |val| {
        unreachable;
    } else |err| {
        assert(err == error.OutOfMemory);
    }
}

// allocate and free a bunch of memory over and over and make sure that we never
// hand out overlapping chunks
test "no_overlap" {
    var gp_allocator = GpAlloc.init() catch unreachable;
    var allocator = &gp_allocator.allocator;

    const base_allocation = TestAllocation {
        .start = 0,
        .len = 0
    };


    var i: usize = 0;
    var n_active: usize = 0;
    var r = rand.Rand.init(12345);
    const ITEM_SIZES = []usize { 10, 123, 456, 789};

    const AllocAction = enum {
        Alloc,
        Free
    };

    // XXX: use a tree or something here once we have one in the stdlib
    var allocations = []TestAllocation { base_allocation } ** N_ALLOC;

    while (i < N_ROUNDS) : (i += 1) {
        const action = switch (n_active) {
            0 => AllocAction.Alloc,
            N_ALLOC => AllocAction.Free,
            else => if (r.range(usize, 0, 10) < 7)
                AllocAction.Alloc
            else
                AllocAction.Free
        };

        switch (action) {
            AllocAction.Alloc => {
                const item_size = r.choose(usize, ITEM_SIZES[0..]);
                const item = gp_allocator.alloc_impl(item_size, 1) catch unreachable;

                assert(item.len == item_size);

                var j: usize = 0;
                var alloc_stored = false;
                while (j < N_ALLOC) : (j += 1) {
                    var allocation = &allocations[j];
                    const new_start = @ptrToInt(item.ptr);
                    const new_end = new_start + item.len;
                    if (allocation.start == 0) {
                        if (!alloc_stored) {
                            allocation.start = new_start;
                            allocation.len = item.len;
                            alloc_stored = true;
                        }
                    } else {
                        const old_start = allocation.start;
                        const old_end = old_start + allocation.len;

                        if (new_start < old_start) {
                            assert(new_end <= old_start);
                        } else if (new_start > old_start) {
                            assert(new_start >= old_end);
                        } else {
                            assert(false);
                        }
                    }
                }

                assert(alloc_stored);
                n_active += 1;
            },
            AllocAction.Free => {
                assert(n_active > 0);
                const free_index = r.range(usize, 0, n_active);
                
                var j: usize = 0;
                var allocs_seen: usize = 0;
                while (j < N_ALLOC) : (j += 1) {
                    var allocation = &allocations[j];

                    if (allocation.start == 0) {
                        continue;
                    }

                    if (allocs_seen == free_index) {
                        var slice_start = @intToPtr(&u8, allocation.start);
                        var slice = slice_start[0..allocation.len];
                        allocator.free(slice);
                        *allocation = base_allocation;
                        break;
                    }

                    allocs_seen += 1;
                } else {
                    assert(false);
                }

                n_active -= 1;
            }
        }
    }
}
