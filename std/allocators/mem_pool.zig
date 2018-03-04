const builtin = @import("builtin");
const ll = @import("../linked_list.zig");
const mem = @import("../mem.zig");
const linux = @import("../os/linux/index.zig");

pub const RawMemoryPool = struct {
    free_list: ll.LinkedList(void),
    n: usize,
    pool: []u8,
    base_alloc: &mem.Allocator,

    const Self = this;

    const MemNode = struct {
        linkage: ll.LinkedList(void).Node
    };

    pub fn init(obj_size: usize, n: usize, base_alloc: &mem.Allocator) !Self {
        // XXX: best way to check for overflow here?
        const node_size = obj_size + @sizeOf(MemNode);
        const total_size = node_size * n;

        const raw_mem = try base_alloc.alloc(u8, total_size);

        var pool = Self {
            .free_list = ll.LinkedList(void).init(),
            .n = n,
            .pool = raw_mem,
            .base_alloc = base_alloc
        };

        var i: usize = 0;
        const pool_base = @ptrToInt(pool.pool.ptr);
        while (i < n) : (i += 1) {
            var node = @intToPtr(&MemNode, pool_base + i * node_size);

            node.linkage = ll.LinkedList(void).Node.init({});

            pool.free_list.append(&node.linkage);
        }

        return pool;
    }

    pub fn deinit(pool: &Self) !void {
        // XXX: unmap memory
    }

    pub fn alloc(pool: &Self) !usize {
        var node = pool.free_list.pop() ?? return error.OutOfMemory;
        return @ptrToInt(node) + @sizeOf(ll.LinkedList(void).Node);
    }

    pub fn free(pool: &Self, item: usize) void {
        var node = @intToPtr(&ll.LinkedList(void).Node,
            item - @sizeOf(ll.LinkedList(void).Node));
        pool.free_list.append(node);
    }
};

pub fn MemoryPool(comptime T: type) type {
    // XXX: replace below usages of LinkedList(T) with this
    //const free_list_t = ll.LinkedList(T);

    return struct {
        raw_pool: RawMemoryPool,

        const Self = this;

        pub fn init(n: usize) !Self {
            return Self {
                .raw_pool = try RawMemoryPool.init(@sizeOf(T), n)
            };
        }

        pub fn alloc(pool: &Self) !&T {
            return @intToPtr(&T, try pool.raw_pool.alloc());
        }

        pub fn free(pool: &Self, item: &T) void {
            pool.raw_pool.free(@ptrToInt(item));
        }
    };
}
