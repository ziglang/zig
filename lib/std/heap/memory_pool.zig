const std = @import("../std.zig");
const Alignment = std.mem.Alignment;

const debug_mode = @import("builtin").mode == .Debug;

pub const MemoryPoolError = error{OutOfMemory};

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
pub fn MemoryPool(comptime Item: type) type {
    return MemoryPoolAligned(Item, .of(Item));
}

/// A memory pool that can allocate objects of a single type very quickly.
/// Use this when you need to allocate a lot of objects of the same type,
/// because It outperforms general purpose allocators.
pub fn MemoryPoolAligned(comptime Item: type, comptime alignment: Alignment) type {
    if (@alignOf(Item) == comptime alignment.toByteUnits()) {
        return MemoryPoolExtra(Item, .{});
    } else {
        return MemoryPoolExtra(Item, .{ .alignment = alignment });
    }
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
/// because It outperforms general purpose allocators.
pub fn MemoryPoolExtra(comptime Item: type, comptime pool_options: Options) type {
    return struct {
        const Pool = @This();

        /// Size of the memory pool items. This may be larger than `@sizeOf(Item)`
        /// as the pool also uses the items for internal means.
        pub const item_size = @max(@sizeOf(Node), @sizeOf(Item));

        // This needs to be kept in sync with Node.
        const node_alignment: Alignment = .of(*anyopaque);

        /// Alignment of the memory pool items. This may be larger than `@alignOf(Item)`
        /// as the pool also uses the items for internal means.
        pub const item_alignment: Alignment = node_alignment.max(pool_options.alignment orelse .of(Item));

        const Node = struct { next: ?*align(unit_al_bytes) @This() };
        const Byte = std.meta.Int(.unsigned, std.mem.byte_size_in_bits);
        const Unit = [item_alignment.forward(item_size)]Byte;
        const unit_al_bytes = item_alignment.toByteUnits();

        const ItemPtr = *align(unit_al_bytes) Item;
        const NodePtr = *align(unit_al_bytes) Node;

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
            try pool.preheat(initial_size);
            return pool;
        }

        /// Destroys the memory pool and frees all allocated memory.
        pub fn deinit(self: *Pool) void {
            self.arena.deinit();
            self.* = undefined;
        }

        /// Preheats the memory pool by pre-allocating `size` items.
        /// This allows up to `size` active allocations before an
        /// `OutOfMemory` error might happen when calling `create()`.
        pub fn preheat(self: *Pool, size: usize) MemoryPoolError!void {
            const raw_mem = try self.allocNew(size);
            const uni_slc = raw_mem[0..size];
            for (uni_slc) |*unit| {
                const free_node: NodePtr = @ptrCast(unit);
                free_node.next = self.free_list;
                self.free_list = free_node;
            }
        }

        pub const ResetMode = union(enum) {
            /// Releases all allocated memory in the memory pool.
            free_all,
            /// This will pre-heat the memory pool for future allocations by allocating a
            /// large enough buffer to accomodate the highest amount of actively allocated items
            /// in the past. Preheating will speed up the allocation process by invoking the
            /// backing allocator less often than before. If `reset()` is used in a loop, this
            /// means if the highest amount of actively allocated items is never being surpassed,
            /// no memory allocations are performed anymore.
            retain_capacity,
            /// This is the same as `retain_capacity`, but the memory will be shrunk to
            /// only hold at most this value of items.
            retain_with_limit: usize,
        };

        /// Resets the memory pool and destroys all allocated items.
        /// This can be used to batch-destroy all objects without invalidating the memory pool.
        ///
        /// The function will return whether the reset operation was successful or not.
        /// If the reallocation  failed `false` is returned. The pool will still be fully
        /// functional in that case, all memory is released. Future allocations just might
        /// be slower.
        ///
        /// NOTE: If `mode` is `free_all`, the function will always return `true`.
        pub fn reset(self: *Pool, mode: ResetMode) bool {
            const ArenaResetMode = std.heap.ArenaAllocator.ResetMode;
            const arena_mode = switch (mode) {
                .free_all => .free_all,
                .retain_capacity => .retain_capacity,
                .retain_with_limit => |limit| ArenaResetMode{ .retain_with_limit = limit * item_size },
            };
            self.free_list = null;
            if (!self.arena.reset(arena_mode)) return false;
            // When the backing arena allocator is being reset to
            // a capacity greater than 0, then its internals consists
            // of a *single* buffer node of said capacity. This means,
            // we can safely pre-heat without causing additional allocations.
            const arena_capacity = self.arena.queryCapacity() / item_size;
            if (arena_capacity != 0) self.preheat(arena_capacity) catch unreachable;
            return true;
        }

        /// Creates a new item and adds it to the memory pool.
        pub fn create(self: *Pool) !ItemPtr {
            const node_ptr: NodePtr = if (self.free_list) |item| blk: {
                self.free_list = item.next;
                break :blk item;
            } else if (pool_options.growable)
                @ptrCast(try self.allocNew(1))
            else
                return error.OutOfMemory;

            const ptr: ItemPtr = @ptrCast(node_ptr);
            ptr.* = undefined;
            return ptr;
        }

        /// Destroys a previously created item.
        /// Only pass items to `ptr` that were previously created with `create()` of the same memory pool!
        pub fn destroy(self: *Pool, ptr: ItemPtr) void {
            ptr.* = undefined;
            const node_ptr: NodePtr = @ptrCast(ptr);
            node_ptr.next = self.free_list;
            self.free_list = node_ptr;
        }

        fn allocNew(self: *Pool, n: usize) MemoryPoolError![*]align(unit_al_bytes) Unit {
            const mem = try self.arena.allocator().alignedAlloc(Unit, item_alignment, n);
            return mem.ptr;
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

test "reset" {
    const pool_extra = MemoryPoolExtra(u32, .{ .growable = false });
    var pool = try pool_extra.initPreheated(std.testing.allocator, 3);
    defer pool.deinit();

    try std.testing.expect(pool.create() != error.OutOfMemory);
    try std.testing.expect(pool.create() != error.OutOfMemory);
    try std.testing.expect(pool.create() != error.OutOfMemory);
    try std.testing.expect(pool.create() == error.OutOfMemory);

    try std.testing.expect(pool.reset(.{ .retain_with_limit = 2 }));

    try std.testing.expect(pool.create() != error.OutOfMemory);
    try std.testing.expect(pool.create() != error.OutOfMemory);
    try std.testing.expect(pool.create() == error.OutOfMemory);

    try std.testing.expect(pool.reset(.{ .retain_with_limit = 1 }));

    try std.testing.expect(pool.create() != error.OutOfMemory);
    try std.testing.expect(pool.create() == error.OutOfMemory);
}
