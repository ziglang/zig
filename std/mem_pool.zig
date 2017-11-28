const builtin = @import("builtin");
const ll = @import("linked_list.zig");
const mem = @import("mem.zig");
const linux = @import("os/linux.zig");

fn raw_alloc_linux(bytes: usize) -> %usize {
    const ret = linux.mmap(null, bytes, linux.PROT_READ | linux.PROT_WRITE,
        linux.MAP_SHARED | linux.MAP_ANONYMOUS, -1, 0);
    const err = linux.getErrno(ret);

    switch (err) {
        0 => ret,
        linux.ENOMEM => error.OutOfMemory,
        else => {
            error.Unexpected
        }
    }
}

const raw_alloc = switch (builtin.os) {
    builtin.Os.linux => raw_alloc_linux,
    else => @compileError("memory pools not supported on this OS")
};

pub const RawMemoryPool = struct {
    free_list: ll.LinkedList(void),
    n: usize,
    pool: usize,

    const Self = this;

    const MemNode = struct {
        linkage: ll.LinkedList(void).Node
    };

    pub fn init(obj_size: usize, n: usize) -> %Self {
        // XXX: best way to check for overflow here?
        const node_size = obj_size + @sizeOf(MemNode);
        const total_size = node_size * n;
        const raw_mem = %return raw_alloc(total_size);

        var pool = Self {
            .free_list = ll.LinkedList(void).init(),
            .n = n,
            .pool = raw_mem
        };

        var i: usize = 0;
        while (i < n) : (i += 1) {
            var node = @intToPtr(&MemNode, pool.pool + i * node_size);

            node.linkage = ll.LinkedList(void).Node.init({});

            pool.free_list.append(&node.linkage);
        }

        pool
    }

    pub fn deinit(pool: &Self) -> %void {
        // XXX: unmap memory
    }

    pub fn alloc(pool: &Self) -> %usize {
        var node = pool.free_list.pop() ?? return error.OutOfMemory;
        @ptrToInt(node) + @sizeOf(ll.LinkedList(void).Node)
    }

    pub fn free(pool: &Self, item: usize) -> void {
        var node = @intToPtr(&ll.LinkedList(void).Node,
            item - @sizeOf(ll.LinkedList(void).Node));
        pool.free_list.append(node);
    }
};

pub fn MemoryPool(comptime T: type) -> type {
    // XXX: replace below usages of LinkedList(T) with this
    //const free_list_t = ll.LinkedList(T);

    struct {
        raw_pool: RawMemoryPool,

        const Self = this;

        pub fn init(n: usize) -> %Self {
            Self {
                .raw_pool = %return RawMemoryPool.init(@sizeOf(T), n)
            }
        }

        pub fn alloc(pool: &Self) -> %&T {
            @intToPtr(&T, %return pool.raw_pool.alloc())
        }

        pub fn free(pool: &Self, item: &T) -> void {
            pool.raw_pool.free(@ptrToInt(item))
        }
    }
}
