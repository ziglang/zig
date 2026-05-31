const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const MemoryPool = std.heap.MemoryPool;

/// Deprecated.
pub fn Managed(comptime Item: type) type {
    return ExtraManaged(Item, .{ .alignment = null });
}

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because it outperforms general purpose allocators.
/// Allocated items are aligned to `alignment`-byte addresses or `@alignOf(Item)`
/// if `alignment` is `null`.
/// Functions that potentially allocate memory accept an `Allocator` parameter.
pub fn Aligned(comptime Item: type, comptime alignment: Alignment) type {
    return Extra(Item, .{ .alignment = alignment });
}

/// Deprecated.
pub fn AlignedManaged(comptime Item: type, comptime alignment: Alignment) type {
    return ExtraManaged(Item, .{ .alignment = alignment });
}

pub const Options = struct {
    /// The alignment of the memory pool items. Use `null` for natural alignment.
    alignment: ?Alignment = null,

    /// If `true`, the memory pool can allocate additional items after a initial setup.
    /// If `false`, the memory pool will not allocate further after a call to `initPreheated`.
    growable: bool = true,
};

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because it outperforms general purpose allocators.
/// Functions that potentially allocate memory accept an `Allocator` parameter.
pub fn Extra(comptime Item: type, comptime pool_options: Options) type {
    if (pool_options.alignment) |a| {
        if (a.compare(.eq, .of(Item))) {
            var new_options = pool_options;
            new_options.alignment = null;
            return Extra(Item, new_options);
        }
    }
    return struct {
        const Pool = @This();

        arena_state: std.heap.ArenaAllocator.State,
        free_list: std.SinglyLinkedList,

        /// Size of the memory pool items. This is not necessarily the same
        /// as `@sizeOf(Item)` as the pool also uses the items for internal means.
        pub const item_size = @max(@sizeOf(Node), @sizeOf(Item));

        /// Alignment of the memory pool items. This is not necessarily the same
        /// as `@alignOf(Item)` as the pool also uses the items for internal means.
        pub const item_alignment: Alignment = .max(pool_options.alignment orelse .of(Item), .of(Node));

        const Node = std.SinglyLinkedList.Node;
        const ItemPtr = *align(item_alignment.toByteUnits()) Item;

        /// A MemoryPool containing no elements.
        pub const empty: Pool = .{
            .arena_state = .{},
            .free_list = .{},
        };

        /// Creates a new memory pool and pre-allocates `num` items.
        /// This allows up to `num` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn initCapacity(allocator: Allocator, num: usize) Allocator.Error!Pool {
            var pool: Pool = .empty;
            errdefer pool.deinit(allocator);
            try pool.addCapacity(allocator, num);
            return pool;
        }

        /// Destroys the memory pool and frees all allocated memory.
        pub fn deinit(pool: *Pool, allocator: Allocator) void {
            pool.arena_state.promote(allocator).deinit();
            pool.* = undefined;
        }

        pub fn toManaged(pool: Pool, allocator: Allocator) ExtraManaged(Item, pool_options) {
            return .{
                .allocator = allocator,
                .unmanaged = pool,
            };
        }

        /// Pre-allocates `num` items and adds them to the memory pool.
        /// This allows at least `num` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn addCapacity(pool: *Pool, allocator: Allocator, num: usize) Allocator.Error!void {
            var i: usize = 0;
            while (i < num) : (i += 1) {
                const memory = try pool.allocNew(allocator);
                pool.free_list.prepend(@ptrCast(memory));
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
            defer pool.arena_state = arena.state;

            const reset_successful = arena.reset(mode);
            pool.free_list = .{};

            return reset_successful;
        }

        /// Creates a new item and adds it to the memory pool.
        /// `allocator` may be `undefined` if pool is not `growable`.
        pub fn create(pool: *Pool, allocator: Allocator) Allocator.Error!ItemPtr {
            const ptr: ItemPtr = if (pool.free_list.popFirst()) |node|
                @ptrCast(@alignCast(node))
            else if (pool_options.growable)
                @ptrCast(try pool.allocNew(allocator))
            else
                return error.OutOfMemory;

            ptr.* = undefined;
            return ptr;
        }

        /// Destroys a previously created item.
        /// Only pass items to `ptr` that were previously created with `create()` of the same memory pool!
        pub fn destroy(pool: *Pool, ptr: ItemPtr) void {
            ptr.* = undefined;
            pool.free_list.prepend(@ptrCast(ptr));
        }

        fn allocNew(pool: *Pool, allocator: Allocator) Allocator.Error!*align(item_alignment.toByteUnits()) [item_size]u8 {
            var arena = pool.arena_state.promote(allocator);
            defer pool.arena_state = arena.state;
            const memory = try arena.allocator().alignedAlloc(u8, item_alignment, item_size);
            return memory[0..item_size];
        }
    };
}

/// Deprecated.
pub fn ExtraManaged(comptime Item: type, comptime pool_options: Options) type {
    if (pool_options.alignment) |a| {
        if (a.compare(.eq, .of(Item))) {
            var new_options = pool_options;
            new_options.alignment = null;
            return ExtraManaged(Item, new_options);
        }
    }
    return struct {
        const Pool = @This();

        allocator: Allocator,
        unmanaged: Unmanaged,

        pub const Unmanaged = Extra(Item, pool_options);
        pub const item_size = Unmanaged.item_size;
        pub const item_alignment = Unmanaged.item_alignment;

        const ItemPtr = Unmanaged.ItemPtr;

        /// Creates a new memory pool.
        pub fn init(allocator: Allocator) Pool {
            return Unmanaged.empty.toManaged(allocator);
        }

        /// Creates a new memory pool and pre-allocates `num` items.
        /// This allows up to `num` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn initCapacity(allocator: Allocator, num: usize) Allocator.Error!Pool {
            return (try Unmanaged.initCapacity(allocator, num)).toManaged(allocator);
        }

        /// Destroys the memory pool and frees all allocated memory.
        pub fn deinit(pool: *Pool) void {
            pool.unmanaged.deinit(pool.allocator);
            pool.* = undefined;
        }

        /// Pre-allocates `num` items and adds them to the memory pool.
        /// This allows at least `num` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn addCapacity(pool: *Pool, num: usize) Allocator.Error!void {
            return pool.unmanaged.addCapacity(pool.allocator, num);
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

test "basic" {
    const a = std.testing.allocator;

    {
        var pool: MemoryPool(u32) = .empty;
        defer pool.deinit(a);

        const p1 = try pool.create(a);
        const p2 = try pool.create(a);
        const p3 = try pool.create(a);

        // Assert uniqueness
        try std.testing.expect(p1 != p2);
        try std.testing.expect(p1 != p3);
        try std.testing.expect(p2 != p3);

        pool.destroy(p2);
        const p4 = try pool.create(a);

        // Assert memory reuse
        try std.testing.expect(p2 == p4);
    }

    {
        var pool: Managed(u32) = .init(std.testing.allocator);
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
}

test "initCapacity (success)" {
    const a = std.testing.allocator;

    {
        var pool: MemoryPool(u32) = try .initCapacity(a, 4);
        defer pool.deinit(a);

        _ = try pool.create(a);
        _ = try pool.create(a);
        _ = try pool.create(a);
    }

    {
        var pool: Managed(u32) = try .initCapacity(a, 4);
        defer pool.deinit();

        _ = try pool.create();
        _ = try pool.create();
        _ = try pool.create();
    }
}

test "initCapacity (failure)" {
    const failer = std.testing.failing_allocator;
    try std.testing.expectError(error.OutOfMemory, MemoryPool(u32).initCapacity(failer, 5));
    try std.testing.expectError(error.OutOfMemory, Managed(u32).initCapacity(failer, 5));
}

test "growable" {
    const a = std.testing.allocator;

    {
        var pool: Extra(u32, .{ .growable = false }) = try .initCapacity(a, 4);
        defer pool.deinit(a);

        _ = try pool.create(a);
        _ = try pool.create(a);
        _ = try pool.create(a);
        _ = try pool.create(a);

        try std.testing.expectError(error.OutOfMemory, pool.create(a));
    }

    {
        var pool: ExtraManaged(u32, .{ .growable = false }) = try .initCapacity(a, 4);
        defer pool.deinit();

        _ = try pool.create();
        _ = try pool.create();
        _ = try pool.create();
        _ = try pool.create();

        try std.testing.expectError(error.OutOfMemory, pool.create());
    }
}

test "greater than pointer default alignment" {
    const Foo = struct {
        data: u64 align(16),
    };
    const a = std.testing.allocator;

    {
        var pool: MemoryPool(Foo) = .empty;
        defer pool.deinit(a);

        const foo: *Foo = try pool.create(a);
        pool.destroy(foo);
    }

    {
        var pool: Managed(Foo) = .init(a);
        defer pool.deinit();

        const foo: *Foo = try pool.create();
        pool.destroy(foo);
    }
}

test "greater than pointer manual alignment" {
    const Foo = struct {
        data: u64,
    };
    const a = std.testing.allocator;

    {
        var pool: Aligned(Foo, .@"16") = .empty;
        defer pool.deinit(a);

        const foo: *align(16) Foo = try pool.create(a);
        pool.destroy(foo);
    }

    {
        var pool: AlignedManaged(Foo, .@"16") = .init(a);
        defer pool.deinit();

        const foo: *align(16) Foo = try pool.create();
        pool.destroy(foo);
    }
}
