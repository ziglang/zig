const builtin = @import("builtin");
const debug = @import("debug.zig");
const assert = debug.assert;
const ll = @import("linked_list.zig");
const mem = @import("mem.zig");
const mp = @import("mem_pool.zig");

error Unsupported;

// XXX: make reasonable values for these
// XXX: make the size class list a comptime argument to a function that
// generates the type instead of being a global list
const SIZE_CLASSES = []usize { 8, 64, 1024, 4096 };

// XXX: smae deal with configurability
const POOL_COUNTS: usize = 1024;

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

    fn get_size_class(self: &Self, size: usize) -> ?usize {
        for (SIZE_CLASSES) |size_class, i| {
            if (size_class >= size) {
                return i;
            }
        }

        null
    }

    // XXX: is there a way to make separate comptime and non-ct versions of
    // this?
    fn get_pool(self: &Self, size: usize) -> ?&mp.RawMemoryPool {
        const size_class = self.get_size_class(size) ?? null;
        &self.pools[size_class]
    }

    fn raw_alloc(self: &mem.Allocator, n: usize) -> %[]u8 {
        // XXX: mmap
        error.Unsupported
    }

    fn raw_free(self: &mem.Allocator, bytes: []u8) -> void {
        // XXX: munmap
    }

    fn alloc(allocator: &mem.Allocator, n: usize, alignment: usize) -> %[]u8 {
        var self = @fieldParentPtr(GpAlloc, "allocator", allocator);

        // XXX: if this request is too big for any of the pre-defined pools then
        // just create a separate buffer juts for it
        var size_class = self.get_size_class(n) ?? {
            return raw_alloc(allocator, n);
        };

        var pool = &self.pools[size_class];
        const mem_base = %return pool.alloc();

        // XXX: account for alignment

        // mark the prefix metadata with the size class where this memory should
        // be returned to when it's freed
        var md = @intToPtr(&AllocMd, mem_base);
        md.size_class = size_class;

        // return a pointer to the payload data immediately following the
        // allocator metadata
        const payload_base = @intToPtr(&u8, mem_base + @sizeOf(AllocMd));
        payload_base[0..n]
    }

    fn realloc(allocator: &mem.Allocator, old_mem: []u8, new_size: usize, alignment: usize) -> %[]u8 {
        error.Unsupported
    }

    fn free(allocator: &mem.Allocator, bytes: []u8) -> void {
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
        pool.free(@ptrToInt(md))
    }

    // XXX: allow user to configure maximum memory usage at creation time
    // XXX: provide option to grow pools on demand
    pub fn init() -> %Self {
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
            res.pools[i] = %return mp.RawMemoryPool.init(
                size_class + @sizeOf(AllocMd), POOL_COUNTS);
            %defer {
                res.pools[i].deinit() %% {}
            }
        }

        res
    }
};

const TestStruct = struct {
    foo: usize,
    bar: u32
};

test "basic_alloc" {
    var allocator = %%GpAlloc.init();

    var obj: []TestStruct = %%allocator.allocator.alloc(TestStruct, 4);

    obj[0].foo = 5;
}
