const std = @import("../std.zig");

const debug_mode = @import("builtin").mode == .Debug;

pub const MemoryPoolError = error{OutOfMemory};

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
pub fn MemoryPool(comptime Item: type) type {
    return MemoryPoolAligned(Item, @alignOf(Item));
}

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
pub fn MemoryPoolAligned(comptime Item: type, comptime alignment: u29) type {
    if (@alignOf(Item) == alignment) {
        return MemoryPoolExtra(Item, .{});
    } else {
        return MemoryPoolExtra(Item, .{ .alignment = alignment });
    }
}

pub const Options = struct {
    /// The alignment of the memory pool items. Use `null` for natural alignment.
    alignment: ?u29 = null,

    /// If `true`, the memory pool can allocate additional items after a initial setup.
    /// If `false`, the memory pool will not allocate further after a call to `initPreheated`.
    growable: bool = true,
};

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
pub fn MemoryPoolExtra(comptime Item: type, comptime pool_options: Options) type {
    return struct {
        const Pool = @This();

        /// Size of the memory pool items. This is not necessarily the same
        /// as `@sizeOf(Item)` as the pool also uses the items for internal means.
        pub const item_size = @max(@sizeOf(Node), @sizeOf(Item));

        // This needs to be kept in sync with Node.
        const node_alignment = @alignOf(*anyopaque);

        /// Alignment of the memory pool items. This is not necessarily the same
        /// as `@alignOf(Item)` as the pool also uses the items for internal means.
        pub const item_alignment = @max(node_alignment, pool_options.alignment orelse @alignOf(Item));

        const Node = struct {
            next: ?*align(item_alignment) @This(),
        };
        const NodePtr = *align(item_alignment) Node;
        const ItemPtr = *align(item_alignment) Item;

        arena: std.heap.ArenaAllocator,
        free_list: ?NodePtr = null,

        /// Creates a new memory pool.
        pub fn init(allocator: std.mem.Allocator) Pool {
            return .{ .arena = std.heap.ArenaAllocator.init(allocator) };
        }

        /// Creates a new memory pool and pre-allocates `initial_size` items.
        /// This allows the up to `initial_size` active allocations before a
        /// `OutOfMemory` error happens when calling `create()`.
        pub fn initPreheated(allocator: std.mem.Allocator, initial_size: usize) MemoryPoolError!Pool {
            var pool = init(allocator);
            errdefer pool.deinit();

            var i: usize = 0;
            while (i < initial_size) : (i += 1) {
                const raw_mem = try pool.allocNew();
                const free_node = @as(NodePtr, @ptrCast(raw_mem));
                free_node.* = Node{
                    .next = pool.free_list,
                };
                pool.free_list = free_node;
            }

            return pool;
        }

        /// Destroys the memory pool and frees all allocated memory.
        pub fn deinit(pool: *Pool) void {
            pool.arena.deinit();
            pool.* = undefined;
        }

        pub const ResetMode = std.heap.ArenaAllocator.ResetMode;

        /// Resets the memory pool and destroys all allocated items.
        /// This can be used to batch-destroy all objects without invalidating the memory pool.
        ///
        /// The function will return whether the reset operation was successful or not.
        /// If the reallocation  failed `false` is returned. The pool will still be fully
        /// functional in that case, all memory is released. Future allocations just might
        /// be slower.
        ///
        /// NOTE: If `mode` is `free_all`, the function will always return `true`.
        pub fn reset(pool: *Pool, mode: ResetMode) bool {
            // TODO: Potentially store all allocated objects in a list as well, allowing to
            //       just move them into the free list instead of actually releasing the memory.

            const reset_successful = pool.arena.reset(mode);

            pool.free_list = null;

            return reset_successful;
        }

        /// Creates a new item and adds it to the memory pool.
        pub fn create(pool: *Pool) !ItemPtr {
            const node = if (pool.free_list) |item| blk: {
                pool.free_list = item.next;
                break :blk item;
            } else if (pool_options.growable)
                @as(NodePtr, @ptrCast(try pool.allocNew()))
            else
                return error.OutOfMemory;

            const ptr = @as(ItemPtr, @ptrCast(node));
            ptr.* = undefined;
            return ptr;
        }

        /// Destroys a previously created item.
        /// Only pass items to `ptr` that were previously created with `create()` of the same memory pool!
        pub fn destroy(pool: *Pool, ptr: ItemPtr) void {
            ptr.* = undefined;

            const node = @as(NodePtr, @ptrCast(ptr));
            node.* = Node{
                .next = pool.free_list,
            };
            pool.free_list = node;
        }

        fn allocNew(pool: *Pool) MemoryPoolError!*align(item_alignment) [item_size]u8 {
            const mem = try pool.arena.allocator().alignedAlloc(u8, item_alignment, item_size);
            return mem[0..item_size]; // coerce slice to array pointer
        }
    };
}

test "basic" {
    var pool = MemoryPool(u32).init(std.testing.allocator);
    defer pool.deinit();

    const p1 = try pool.create();
    const p2 = try pool.create();
    const p3 = try pool.create();

    // Assert uniqueness
    try std.testing.expect(p1 != p2);
    try std.testing.expect(p1 != p3);
    try std.testing.expect(p2 != p3);

    pool.destroy(p2);
    const p4 = try pool.create();

    // Assert memory reuse
    try std.testing.expect(p2 == p4);
}

test "preheating (success)" {
    var pool = try MemoryPool(u32).initPreheated(std.testing.allocator, 4);
    defer pool.deinit();

    _ = try pool.create();
    _ = try pool.create();
    _ = try pool.create();
}

test "preheating (failure)" {
    const failer = std.testing.failing_allocator;
    try std.testing.expectError(error.OutOfMemory, MemoryPool(u32).initPreheated(failer, 5));
}

test "growable" {
    var pool = try MemoryPoolExtra(u32, .{ .growable = false }).initPreheated(std.testing.allocator, 4);
    defer pool.deinit();

    _ = try pool.create();
    _ = try pool.create();
    _ = try pool.create();
    _ = try pool.create();

    try std.testing.expectError(error.OutOfMemory, pool.create());
}

test "greater than pointer default alignment" {
    const Foo = struct {
        data: u64 align(16),
    };

    var pool = MemoryPool(Foo).init(std.testing.allocator);
    defer pool.deinit();

    const foo: *Foo = try pool.create();
    _ = foo;
}

test "greater than pointer manual alignment" {
    const Foo = struct {
        data: u64,
    };

    var pool = MemoryPoolAligned(Foo, 16).init(std.testing.allocator);
    defer pool.deinit();

    const foo: *align(16) Foo = try pool.create();
    _ = foo;
}
