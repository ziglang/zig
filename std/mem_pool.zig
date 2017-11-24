const builtin = @import("builtin");
const ll = @import("linked_list.zig");
const mem = @import("mem.zig");
const std = @import("std");
const linux = std.os.linux;

fn raw_alloc_linux(bytes: usize) -> %usize {
    const ret = linux.mmap(null, bytes, linux.PROT_READ | linux.PROT_WRITE,
        linux.MAP_ANONYMOUS, -1, 0);
    const err = linux.getErrno(ret);

    switch (err) {
        0 => ret,
        linux.ENOMEM => error.OutOfMemory,
        else => error.Unexpected
    }
}

const raw_alloc = switch (builtin.os) {
    builtin.Os.linux => raw_alloc_linux,
    else => @compileError("memory pools not supported on this OS")
};

pub fn MemoryPool(comptime T: type) -> type {
    const free_list_t = ll.LinkedList(T);

    struct {
        free_list: free_list_t,
        n: usize,
        pool: usize,

        const Self = this;

        pub fn init(n: usize) -> %Self {
            const raw_mem = %return raw_alloc(n * @sizeOf(free_list_t.Node));

            var pool = Self {
                .free_list = free_list_t.init(),
                .n = n,
                .pool = raw_mem
            };

            var i = 0;
            while (i < n) : (i += 1) {
                var node = @intToPtr(&free_list_t.Node,
                    pool.pool + i * @sizeOf(free_list_t.Node));

                const val: T = undefined;
                *node = free_list_t.Node.init(&val);

                pool.free_list.append(node);
            }

            pool
        }

        pub fn alloc(pool: &Self) -> %&T {
            var node = pool.free_list.pop() ?? return error.OutOfMemory;
            &node.data
        }

        pub fn free(pool: &Self, item: &T) -> void {
            var node = @fieldParentPtr(free_list_t.Node, "data", item);
            pool.free_list.append(node);
        }
    }
}
