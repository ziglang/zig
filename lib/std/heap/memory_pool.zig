const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

const debug_mode = @import("builtin").mode == .Debug;

pub const MemoryPoolError = Allocator.Error;

pub const MemoryPool = MemoryPoolWithAllocator;

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
/// For a pool that can be initialized directly and does not store an
/// `Allocator` field, see `MemoryPoolUnmanaged`.
pub fn MemoryPoolWithAllocator(comptime Item: type) type {
    return MemoryPoolAlignedWithAllocator(Item, .of(Item));
}

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
/// This type does not store an `Allocator` field - the `Allocator` must be passed in
/// with each function call that requires it. See `MemoryPoolWithAllocator` for
/// a type that stores an `Allocator` field for convenience.
pub fn MemoryPoolUnmanaged(comptime Item: type) type {
    return MemoryPoolAlignedUnmanaged(Item, .of(Item));
}

pub const MemoryPoolAligned = MemoryPoolAlignedWithAllocator;

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
/// For a pool that can be initialized directly and does not store an
/// `Allocator` field, see `MemoryPoolAlignedUnmanaged`.
pub fn MemoryPoolAlignedWithAllocator(comptime Item: type, comptime alignment: Alignment) type {
    if (alignment.compare(.eq, .of(Item))) {
        return MemoryPoolExtraWithAllocator(Item, .{});
    } else {
        return MemoryPoolExtraWithAllocator(Item, .{ .alignment = alignment });
    }
}

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
/// This type does not store an `Allocator` field - the `Allocator` must be passed in
/// with each function call that requires it. See `MemoryPoolAlignedWithAllocator` for
/// a type that stores an `Allocator` field for convenience.
pub fn MemoryPoolAlignedUnmanaged(comptime Item: type, comptime alignment: Alignment) type {
    if (alignment.compare(.eq, .of(Item))) {
        return MemoryPoolExtraUnmanaged(Item, .{});
    } else {
        return MemoryPoolExtraUnmanaged(Item, .{ .alignment = alignment });
    }
}

pub const MemoryPoolExtra = MemoryPoolExtraWithAllocator;

pub const Options = struct {
    /// The alignment of the memory pool items. Use `null` for natural alignment.
    alignment: ?Alignment = null,

    /// If `true`, the memory pool can allocate additional items after a initial setup.
    /// If `false`, the memory pool will not allocate further after a call to `initPreheated`.
    growable: bool = true,
};

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
/// For a pool that can be initialized directly and does not store an
/// `Allocator` field, see `MemoryPoolExtraUnmanaged`.
pub fn MemoryPoolExtraWithAllocator(comptime Item: type, comptime pool_options: Options) type {
    return struct {
        const Pool = @This();

        pub const Unmanaged = MemoryPoolExtraUnmanaged(Item, pool_options);

        /// Size of the memory pool items. This is not necessarily the same
        /// as `@sizeOf(Item)` as the pool also uses the items for internal means.
        pub const item_size = Unmanaged.item_size;

        // This needs to be kept in sync with Node.
        const node_alignment = Unmanaged.node_alignment;

        /// Alignment of the memory pool items. This is not necessarily the same
        /// as `@alignOf(Item)` as the pool also uses the items for internal means.
        pub const item_alignment = Unmanaged.item_alignment;

        const Node = Unmanaged.Node;
        const NodePtr = Unmanaged.NodePtr;
        const ItemPtr = Unmanaged.ItemPtr;

        allocator: Allocator,
        unmanaged: Unmanaged,

        /// Creates a new memory pool.
        pub fn init(allocator: Allocator) Pool {
            return Unmanaged.init.promote(allocator);
        }

        /// Creates a new memory pool and pre-allocates `initial_size` items.
        /// This allows the up to `initial_size` active allocations before a
        /// `OutOfMemory` error happens when calling `create()`.
        pub fn initPreheated(allocator: std.mem.Allocator, initial_size: usize) Allocator.Error!Pool {
            const unmanaged = try Unmanaged.initPreheated(allocator, initial_size);
            return unmanaged.promote(allocator);
        }

        /// Destroys the memory pool and frees all allocated memory.
        pub fn deinit(pool: *Pool) void {
            pool.unmanaged.deinit(pool.allocator);
            pool.* = undefined;
        }

        /// Preheats the memory pool by pre-allocating `size` items.
        /// This allows up to `size` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn preheat(pool: *Pool, size: usize) Allocator.Error!void {
            return pool.unmanaged.preheat(pool.allocator, size);
        }

        pub const ResetMode = Unmanaged.ResetMode;

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
            return pool.unmanaged.reset(pool.allocator, mode);
        }

        /// Creates a new item and adds it to the memory pool.
        pub fn create(pool: *Pool) Allocator.Error!ItemPtr {
            return pool.unmanaged.create(pool.allocator);
        }

        /// Destroys a previously created item.
        /// Only pass items to `ptr` that were previously created with `create()` of the same memory pool!
        pub fn destroy(pool: *Pool, ptr: ItemPtr) void {
            return pool.unmanaged.destroy(ptr);
        }

        fn allocNew(pool: *Pool) Allocator.Error!*align(item_alignment) [item_size]u8 {
            return pool.unmanaged.allocNew(pool.allocator);
        }
    };
}

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
/// This type does not store an `Allocator` field - the `Allocator` must be passed in
/// with each function call that requires it. See `MemoryPoolExtraWithAllocator` for
/// a type that stores an `Allocator` field for convenience.
pub fn MemoryPoolExtraUnmanaged(comptime Item: type, comptime pool_options: Options) type {
    return struct {
        const Pool = @This();

        pub const Managed = MemoryPoolExtraWithAllocator(Item, pool_options);

        /// Size of the memory pool items. This is not necessarily the same
        /// as `@sizeOf(Item)` as the pool also uses the items for internal means.
        pub const item_size = @max(@sizeOf(Node), @sizeOf(Item));

        // This needs to be kept in sync with Node.
        const node_alignment: Alignment = .of(*anyopaque);

        /// Alignment of the memory pool items. This is not necessarily the same
        /// as `@alignOf(Item)` as the pool also uses the items for internal means.
        pub const item_alignment = node_alignment.max(pool_options.alignment orelse .of(Item));

        const Node = struct {
            next: ?*align(item_alignment.toByteUnits()) @This(),
        };
        const NodePtr = *align(item_alignment.toByteUnits()) Node;
        const ItemPtr = *align(item_alignment.toByteUnits()) Item;

        arena_state: std.heap.ArenaAllocator.State,
        free_list: ?NodePtr,

        /// Creates a new memory pool.
        pub const init = Pool{
            .arena_state = .{},
            .free_list = null,
        };

        /// Creates a new memory pool and pre-allocates `initial_size` items.
        /// This allows the up to `initial_size` active allocations before a
        /// `OutOfMemory` error happens when calling `create()`.
        pub fn initPreheated(allocator: Allocator, initial_size: usize) Allocator.Error!Pool {
            var pool = init;
            errdefer pool.deinit(allocator);
            try pool.preheat(allocator, initial_size);
            return pool;
        }

        /// Destroys the memory pool and frees all allocated memory.
        pub fn deinit(pool: *Pool, allocator: Allocator) void {
            pool.arena_state.promote(allocator).deinit();
            pool.* = undefined;
        }

        pub fn promote(pool: Pool, allocator: Allocator) Managed {
            return .{
                .allocator = allocator,
                .unmanaged = pool,
            };
        }

        /// Preheats the memory pool by pre-allocating `size` items.
        /// This allows up to `size` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn preheat(pool: *Pool, allocator: Allocator, size: usize) Allocator.Error!void {
            var i: usize = 0;
            while (i < size) : (i += 1) {
                const raw_mem = try pool.allocNew(allocator);
                const free_node = @as(NodePtr, @ptrCast(raw_mem));
                free_node.* = Node{
                    .next = pool.free_list,
                };
                pool.free_list = free_node;
            }
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
        pub fn reset(pool: *Pool, allocator: Allocator, mode: ResetMode) bool {
            // TODO: Potentially store all allocated objects in a list as well, allowing to
            //       just move them into the free list instead of actually releasing the memory.

            var arena = pool.arena_state.promote(allocator);
            const reset_successful = arena.reset(mode);

            pool.arena_state = arena.state;
            pool.free_list = null;

            return reset_successful;
        }

        /// Creates a new item and adds it to the memory pool.
        /// `allocator` may be `undefined` if pool is not `growable`.
        pub fn create(pool: *Pool, allocator: Allocator) Allocator.Error!ItemPtr {
            const node = if (pool.free_list) |item| blk: {
                pool.free_list = item.next;
                break :blk item;
            } else if (pool_options.growable)
                @as(NodePtr, @ptrCast(try pool.allocNew(allocator)))
            else
                return Allocator.Error.OutOfMemory;

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

        fn allocNew(pool: *Pool, allocator: Allocator) Allocator.Error!*align(item_alignment.toByteUnits()) [item_size]u8 {
            var arena = pool.arena_state.promote(allocator);
            const mem = try arena.allocator().alignedAlloc(u8, item_alignment, item_size);
            pool.arena_state = arena.state;
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

    var pool = MemoryPoolAligned(Foo, .@"16").init(std.testing.allocator);
    defer pool.deinit();

    const foo: *align(16) Foo = try pool.create();
    _ = foo;
}
