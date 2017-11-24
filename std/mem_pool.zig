const builtin = @import("builtin");
const mem = @import("mem.zig");
const std = @import("std");
const linux = std.os.linux;

fn raw_alloc_linux(bytes: usize) -> %usize {
    const ret = linux.mmap(null, bytes, linux.PROT_READ | linux.PROT_WRITE,
        linux.MAP_SHARED | linux.MAP_ANONYMOUS, -1, 0);
    const err = linux.getErrno(ret);

    switch (err) {
        0 => ret,
        linux.ENOMEM => error.OutOfMemory,
        else => {
            std.debug.warn("mmap returned error {}\n", err);
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
    //const free_list_t = std.LinkedList(T);

    struct {
        free_list: std.LinkedList(T),
        n: usize,
        pool: usize,

        const Self = this;

        pub fn init(n: usize) -> %Self {
            const raw_mem = %return raw_alloc(n * @sizeOf(std.LinkedList(T).Node));

            var pool = Self {
                .free_list = std.LinkedList(T).init(),
                .n = n,
                .pool = raw_mem
            };

            var i: usize = 0;
            while (i < n) : (i += 1) {
                var node = @intToPtr(&std.LinkedList(T).Node,
                    pool.pool + i * @sizeOf(std.LinkedList(T).Node));

                const val: T = undefined;
                *node = std.LinkedList(T).Node.init(&val);

                pool.free_list.append(node);
            }

            pool
        }

        pub fn alloc(pool: &Self) -> %&T {
            var node = pool.free_list.pop() ?? return error.OutOfMemory;
            &node.data
        }

        pub fn free(pool: &Self, item: &T) -> void {
            var node = @fieldParentPtr(std.LinkedList(T).Node, "data", item);
            pool.free_list.append(node);
        }
    }
}
