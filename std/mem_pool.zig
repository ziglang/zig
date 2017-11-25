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

pub fn MemoryPool(comptime T: type) -> type {
    // XXX: replace below usages of LinkedList(T) with this
    //const free_list_t = ll.LinkedList(T);

    struct {
        free_list: ll.LinkedList(T),
        n: usize,
        pool: usize,

        const Self = this;

        pub fn init(n: usize) -> %Self {
            const raw_mem = %return raw_alloc(n * @sizeOf(ll.LinkedList(T).Node));

            var pool = Self {
                .free_list = ll.LinkedList(T).init(),
                .n = n,
                .pool = raw_mem
            };

            var i: usize = 0;
            while (i < n) : (i += 1) {
                var node = @intToPtr(&ll.LinkedList(T).Node,
                    pool.pool + i * @sizeOf(ll.LinkedList(T).Node));

                const val: T = undefined;
                *node = ll.LinkedList(T).Node.init(&val);

                pool.free_list.append(node);
            }

            pool
        }

        pub fn alloc(pool: &Self) -> %&T {
            var node = pool.free_list.pop() ?? return error.OutOfMemory;
            &node.data
        }

        pub fn free(pool: &Self, item: &T) -> void {
            var node = @fieldParentPtr(ll.LinkedList(T).Node, "data", item);
            pool.free_list.append(node);
        }
    }
}
