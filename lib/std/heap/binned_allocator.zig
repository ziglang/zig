//! # Binned Allocator
//!
//! This is designed to be a fast, general-purpose allocator, for use in place of GeneralPurposeAllocator when speed is the priority.
//! It uses a collection of "bins" for various sizes of allocation, combined with a binary tree for allocations larger than 4kiB.
//!
//! Features:
//!  - zero per-allocation metadata
//!  - optional thread-safety (on by default; disable for improved single-threaded performance)
//!  - primitive leak checking (for full checking, use GeneralPurposeAllocator)
//!  - does not free to backing allocator, allowing use with FixedBufferAllocator
//!
//! Limitations:
//!  - allocations will be at least as big as their alignment
//!  - allocation sizes will be rounded up to the nearest bin size
//!  - alignment cannot be greater than std.mem.page_size (see also #7952)
//!  - does not free to backing allocator, leading to memory leaks for some niche allocation patterns

const std = @import("std");
const builtin = @import("builtin");

pub const Config = struct {
    /// Whether to synchronize usage of this allocator.
    /// For actual thread safety, the backing allocator must also be thread safe.
    thread_safe: bool = !builtin.single_threaded,

    /// Whether to warn about leaked memory on deinit.
    /// This reporting is extremely limited; for proper leak checking use GeneralPurposeAllocator.
    report_leaks: bool = true,
};

pub fn BinnedAllocator(comptime config: Config) type {
    return struct {
        backing_allocator: std.mem.Allocator = std.heap.page_allocator,
        bins: Bins = .{},
        large: BinaryTreeAllocator = .{},
        large_count: if (config.report_leaks) usize else u0 = 0,

        const Bins = struct {
            Bin(16, 8) = .{},
            Bin(64, 4) = .{},
            Bin(256, 2) = .{},
            Bin(1024, 0) = .{},
            Bin(4096, 0) = .{},
        };
        comptime {
            var prev: usize = 0;
            for (Bins{}) |bin| {
                std.debug.assert(bin.size > prev);
                prev = bin.size;
            }
        }

        const Self = @This();

        pub fn deinit(self: *Self) void {
            const log = std.log.scoped(.binned_allocator);

            inline for (&self.bins) |*bin| {
                if (config.report_leaks) {
                    const leaks = bin.list.count() - bin.freeCount();
                    if (leaks > 0) {
                        log.warn("{} leaked blocks in {}-byte bin", .{ leaks, bin.size });
                    }
                }
                bin.deinit(self.backing_allocator);
            }

            if (config.report_leaks) {
                if (self.large_count > 0) {
                    log.warn("{} large blocks leaked. Large leaks cannot be cleaned up!", .{self.large_count});
                }
            }
        }

        pub fn allocator(self: *Self) std.mem.Allocator {
            return .{
                .ptr = self,
                .vtable = &.{
                    .alloc = alloc,
                    .resize = resize,
                    .free = free,
                },
            };
        }

        fn alloc(ctx: *anyopaque, len: usize, log2_align: u8, ret_addr: usize) ?[*]u8 {
            const self: *Self = @ptrCast(@alignCast(ctx));

            const align_ = @as(usize, 1) << @intCast(log2_align);
            const size = @max(len, align_);
            inline for (&self.bins) |*bin| {
                if (size <= bin.size) {
                    return bin.alloc(self.backing_allocator);
                }
            }

            if (self.large.alloc(self.backing_allocator, len, log2_align, ret_addr)) |ptr| {
                if (config.report_leaks) self.large_count += 1;
                return ptr;
            } else {
                return null;
            }
        }

        fn resize(ctx: *anyopaque, buf: []u8, log2_align: u8, new_len: usize, ret_addr: usize) bool {
            const self: *Self = @ptrCast(@alignCast(ctx));

            const align_ = @as(usize, 1) << @intCast(log2_align);
            comptime var prev_size: usize = 0;
            inline for (&self.bins) |*bin| {
                if (buf.len <= bin.size and align_ <= bin.size) {
                    // Check it still fits
                    return new_len > prev_size and new_len <= bin.size;
                }
                prev_size = bin.size;
            }

            // Assuming it's a large alloc
            if (new_len <= prev_size) return false; // New size fits into a bin
            return self.large.resize(buf, log2_align, new_len, ret_addr);
        }

        fn free(ctx: *anyopaque, buf: []u8, log2_align: u8, ret_addr: usize) void {
            const self: *Self = @ptrCast(@alignCast(ctx));

            const align_ = @as(usize, 1) << @intCast(log2_align);
            inline for (&self.bins) |*bin| {
                if (buf.len <= bin.size and align_ <= bin.size) {
                    bin.free(buf.ptr);
                    return;
                }
            }

            // Assuming it's a large alloc
            self.large.free(buf, log2_align, ret_addr);
            if (config.report_leaks) self.large_count -= 1;
        }

        const Mutex = if (config.thread_safe)
            std.Thread.Mutex
        else
            struct {
                fn lock(_: @This()) void {}
                fn unlock(_: @This()) void {}
            };

        fn Bin(comptime slot_size: usize, comptime init_count: usize) type {
            return struct {
                mutex: Mutex = .{},
                list: std.SegmentedList(Slot(slot_size), init_count) = .{},
                free_head: ?*Slot(slot_size) = null,
                comptime size: usize = slot_size,

                fn deinit(self: *@This(), al: std.mem.Allocator) void {
                    self.list.deinit(al);
                }

                fn alloc(self: *@This(), al: std.mem.Allocator) ?[*]u8 {
                    self.mutex.lock();
                    defer self.mutex.unlock();

                    const slot = if (self.free_head) |s| blk: {
                        self.free_head = s.next;
                        break :blk s;
                    } else self.list.addOne(al) catch return null;
                    slot.* = .{ .buf = undefined };
                    return &slot.buf;
                }

                fn free(self: *@This(), ptr: [*]u8) void {
                    self.mutex.lock();
                    defer self.mutex.unlock();

                    const slot: *Slot(slot_size) = @ptrCast(@alignCast(ptr));
                    slot.* = .{ .next = self.free_head };
                    self.free_head = slot;
                }

                // Only public in case someone wants to dump out internal allocator debug info
                pub fn freeCount(self: *@This()) usize {
                    self.mutex.lock();
                    defer self.mutex.unlock();

                    var slot_opt = self.free_head;
                    var count: usize = 0;
                    while (slot_opt) |slot| : (slot_opt = slot.next) {
                        count += 1;
                    }
                    return count;
                }
            };
        }
        fn Slot(comptime size: usize) type {
            return extern union {
                buf: [size]u8 align(size), // Allocated
                next: ?*@This(), // Free

                comptime {
                    if (@sizeOf(@This()) != size or @alignOf(@This()) != size) {
                        @compileError("Slot size too small!");
                    }
                }
            };
        }
    };
}

/// This allocator is used for allocations larger than the maximum bin size.
///
/// It uses a red-black tree to sort freed memory blocks by size, so one of similar size can be chosen next time an allocation is performed.
/// A second red-black tree is used to sort the same blocks by address, to allow merging adjacent blocks.
///
/// There is no metadata overhead for allocations, however alignment lengths will be rounded up to the nearest power of two, or a multiple of std.mem.page_size, whichever is smaller.
const BinaryTreeAllocator = struct {
    // OPTIM: we could construct these on the fly to avoid storing the function pointers. However, std.rb should probably just take these at comptime instead
    size_tree: std.rb.Tree = std.rb.Tree.init(FreeBlock.sizeCompare),
    addr_tree: std.rb.Tree = std.rb.Tree.init(FreeBlock.addrCompare),

    const max_align = std.mem.page_size;

    fn alloc(self: *BinaryTreeAllocator, backing_allocator: std.mem.Allocator, requested_size: usize, log2_align: u8, ret_addr: usize) ?[*]u8 {
        const size = blockSize(requested_size, log2_align) catch return null;

        // Search for a suitable free block
        var best: ?*FreeBlock = null;
        var next = self.size_tree.root;
        while (next) |node| {
            const block = @fieldParentPtr(FreeBlock, "size_node", node);
            if (block.size == size) {
                // Perfect size! We're done here
                best = block;
                break;
            } else if (block.size > size) {
                // Big enough, but keep looking for smaller blocks
                best = block;
                next = node.left;
            } else {
                // Too small, look for bigger blocks
                next = node.right;
            }
        }

        if (best) |block| {
            std.debug.assert(std.mem.isAlignedLog2(@intFromPtr(block), log2_align));

            // Remove block from tree
            self.size_tree.remove(&block.size_node);
            self.addr_tree.remove(&block.addr_node);

            const ptr: [*]u8 = @ptrCast(block);
            self.splitBlock(ptr, block.size, size);
            return ptr;
        } else {
            // Fall back to backing allocator
            const alloc_align = if (size >= max_align)
                comptime std.math.log2(max_align)
            else
                @ctz(size);
            std.debug.assert(alloc_align >= log2_align);
            return backing_allocator.rawAlloc(size, alloc_align, ret_addr);
        }
    }

    // Split a block down to a given size and add the rest to the tree
    // Works for both allocated and unallocated blocks
    fn splitBlock(self: *BinaryTreeAllocator, ptr: [*]u8, old_size: usize, new_size: usize) void {
        var current_size = old_size;
        if (current_size == new_size) {
            // Nothing needs done :)
        } else if (current_size > max_align and new_size >= max_align) {
            std.debug.assert(std.mem.isAligned(new_size, max_align));
            std.debug.assert(std.mem.isAligned(current_size, max_align));

            // Split into two blocks
            const split_block = FreeBlock.split(ptr, &current_size, new_size);
            _ = self.size_tree.insert(&split_block.size_node);
            _ = self.addr_tree.insert(&split_block.addr_node);
        } else {
            if (current_size > max_align) {
                std.debug.assert(std.mem.isAligned(current_size, max_align));

                // Split off an initial block
                const split_block = FreeBlock.split(ptr, &current_size, max_align);
                _ = self.size_tree.insert(&split_block.size_node);
                _ = self.addr_tree.insert(&split_block.addr_node);
            }

            std.debug.assert(new_size < max_align);
            std.debug.assert(std.math.isPowerOfTwo(new_size));
            std.debug.assert(std.math.isPowerOfTwo(current_size));

            // Split the block by binary partitioning
            while (current_size > new_size) {
                const split_block = FreeBlock.split(ptr, &current_size, current_size >> 1);
                _ = self.size_tree.insert(&split_block.size_node);
                _ = self.addr_tree.insert(&split_block.addr_node);
            }
        }
    }

    fn resize(self: *BinaryTreeAllocator, buf: []u8, log2_align: u8, new_len: usize, _: usize) bool {
        // FIXME: Unfortunately, we cannot pass through resize requests to the backing allocator, as we don't store
        //        metadata about which allocations are which. Whether this is worth fixing remains to be seen.

        const old_size = blockSize(buf.len, log2_align) catch unreachable;
        const new_size = blockSize(new_len, log2_align) catch return false;

        // Shrinking is easy
        if (old_size >= new_size) {
            self.splitBlock(buf.ptr, old_size, new_size);
            return true;
        }

        const adj = self.findAdjacentBlocks(buf.ptr, old_size, false);
        const after = adj.after orelse return false;

        // Check if we can resize
        const last_block = a: {
            var allocated_size = old_size;
            var block = after;
            while (FreeBlock.canMerge(allocated_size, block.size)) {
                allocated_size += block.size;
                if (new_size <= allocated_size) {
                    // We have enough space now
                    break :a block;
                }

                const next_node = block.addr_node.next() orelse {
                    // No more blocks to resize into
                    return false;
                };
                const next_block = @fieldParentPtr(FreeBlock, "addr_node", next_node);
                if (@intFromPtr(next_block) != @intFromPtr(buf.ptr) + allocated_size) {
                    // The next block is no longer adjacent
                    return false;
                }
            } else {
                // Next block can't be merged
                return false;
            }
        };

        // Actually resize
        var block = after;
        var allocated_size = old_size;
        while (block != last_block) {
            const next_node = block.addr_node.next().?;
            const next_block = @fieldParentPtr(FreeBlock, "addr_node", next_node);

            self.size_tree.remove(&block.size_node);
            self.addr_tree.remove(&block.addr_node);
            allocated_size += block.size;

            block = next_block;
        }

        self.size_tree.remove(&block.size_node);
        self.addr_tree.remove(&block.addr_node);

        if (allocated_size + block.size > new_size) {
            // Needs splitting
            std.debug.assert(block.size > max_align); // Wouldn't be able to merge otherwise
            const split_block = FreeBlock.split(@ptrCast(block), &block.size, new_size - allocated_size);
            std.debug.assert(std.mem.isAligned(split_block.size, max_align));

            _ = self.size_tree.insert(&split_block.size_node);
            _ = self.addr_tree.insert(&split_block.addr_node);
        }

        return true;
    }

    fn free(self: *BinaryTreeAllocator, buf: []u8, log2_align: u8, _: usize) void {
        const size = blockSize(buf.len, log2_align) catch unreachable;

        const adj = self.findAdjacentBlocks(buf.ptr, size, true);

        var block: *FreeBlock = @ptrCast(@alignCast(buf.ptr));
        block.size = size;
        if (adj.before != null and FreeBlock.canMerge(adj.before.?.size, block.size)) {
            // Merge blocks
            self.size_tree.remove(&adj.before.?.size_node);
            adj.before.?.size += block.size;

            block = adj.before.?;
        } else {
            // Insert block into tree
            _ = self.addr_tree.insert(&block.addr_node);
        }
        if (adj.after != null and FreeBlock.canMerge(block.size, adj.after.?.size)) {
            // Remove after-block from tree so we can merge it
            self.size_tree.remove(&adj.after.?.size_node);
            self.addr_tree.remove(&adj.after.?.addr_node);

            // Merge blocks
            block.size += adj.after.?.size;
        }
        _ = self.size_tree.insert(&block.size_node);
    }

    fn blockSize(alloc_size: usize, log2_align: u8) error{ AlignmentTooHigh, OutOfMemory }!usize {
        const align_ = @as(usize, 1) << @intCast(log2_align);
        if (align_ > max_align) {
            return error.AlignmentTooHigh;
        }
        if (alloc_size > std.math.maxInt(usize) - max_align) {
            return error.OutOfMemory;
        }

        const size = if (alloc_size <= align_)
            align_
        else if (alloc_size >= max_align)
            std.mem.alignForward(usize, alloc_size, max_align)
        else
            std.math.ceilPowerOfTwoAssert(usize, alloc_size);

        std.debug.assert(size >= @sizeOf(FreeBlock)); // alloc asserts this

        return size;
    }

    fn findAdjacentBlocks(self: *BinaryTreeAllocator, ptr: [*]u8, size: usize, comptime need_before: bool) AdjacentBlocks {
        const alloc_start = @intFromPtr(ptr);
        const alloc_end = alloc_start + size;

        // Search for adjacent blocks to merge with
        var adj: AdjacentBlocks = .{};
        var next = self.addr_tree.root;
        while (next) |node| {
            const block = @fieldParentPtr(FreeBlock, "size_node", node);
            const block_start = @intFromPtr(block);
            const block_end = block_start + block.size;

            if (block_end < alloc_start) {
                // Address too low
                next = node.right;
            } else if (block_start > alloc_end) {
                // Address too high
                next = node.left;
            } else {
                if (block_end == alloc_start) {
                    adj.before = block;
                } else if (block_start == alloc_end) {
                    adj.after = block;
                } else {
                    unreachable;
                }

                if (adj.before == null and need_before) {
                    // Search for lower nodes
                    next = node.left;
                } else if (adj.after == null) {
                    // Search for higher nodes
                    next = node.right;
                } else {
                    // We have both adjacent blocks; done
                    break;
                }
            }
        }

        return adj;
    }
    const AdjacentBlocks = struct {
        before: ?*FreeBlock = null,
        after: ?*FreeBlock = null,
    };

    /// Metadata for a free memory block
    const FreeBlock = struct {
        size: usize,
        size_node: std.rb.Node,
        addr_node: std.rb.Node,

        comptime {
            std.debug.assert(@sizeOf(FreeBlock) <= max_align);
        }

        /// Splits a given block in two, returning the next block
        /// Works for both allocated and free blocks
        /// Modifies block_size
        fn split(ptr: [*]u8, block_size: *usize, new_size: usize) *FreeBlock {
            const split_block: *FreeBlock = @ptrCast(@alignCast(ptr + new_size));
            split_block.size = block_size.* - new_size;
            std.debug.assert(split_block.size >= @sizeOf(FreeBlock));
            block_size.* = new_size;
            return split_block;
        }

        /// Given the sizes of two adjacent blocks, check if they can merge
        fn canMerge(a: usize, b: usize) bool {
            if (a >= max_align and b >= max_align) {
                std.debug.assert(std.mem.isAligned(a, max_align));
                std.debug.assert(std.mem.isAligned(b, max_align));

                return true;
            } else if (a == b) {
                std.debug.assert(std.math.isPowerOfTwo(a));

                return true;
            } else {
                return false;
            }
        }

        fn sizeCompare(a_node: *std.rb.Node, b_node: *std.rb.Node, _: *std.rb.Tree) std.math.Order {
            const a = @fieldParentPtr(FreeBlock, "size_node", a_node);
            const b = @fieldParentPtr(FreeBlock, "size_node", b_node);
            return std.math.order(a.size, b.size);
        }
        fn addrCompare(a_node: *std.rb.Node, b_node: *std.rb.Node, _: *std.rb.Tree) std.math.Order {
            const a = @fieldParentPtr(FreeBlock, "addr_node", a_node);
            const b = @fieldParentPtr(FreeBlock, "addr_node", b_node);
            return std.math.order(@intFromPtr(a), @intFromPtr(b));
        }
    };
};

test "small allocations - free in same order" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var list = std.ArrayList(*u64).init(std.testing.allocator);
    defer list.deinit();

    var i: usize = 0;
    while (i < 513) : (i += 1) {
        const ptr = try allocator.create(u64);
        try list.append(ptr);
    }

    for (list.items) |ptr| {
        allocator.destroy(ptr);
    }
}

test "small allocations - free in reverse order" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var list = std.ArrayList(*u64).init(std.testing.allocator);
    defer list.deinit();

    var i: usize = 0;
    while (i < 513) : (i += 1) {
        const ptr = try allocator.create(u64);
        try list.append(ptr);
    }

    while (list.popOrNull()) |ptr| {
        allocator.destroy(ptr);
    }
}

test "small allocations - alloc free alloc" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    const a = try allocator.create(u64);
    allocator.destroy(a);
    const b = try allocator.create(u64);
    allocator.destroy(b);
}

test "large allocations" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    const ptr1 = try allocator.alloc(u64, 42768);
    const ptr2 = try allocator.alloc(u64, 52768);
    allocator.free(ptr1);
    const ptr3 = try allocator.alloc(u64, 62768);
    allocator.free(ptr3);
    allocator.free(ptr2);
}

test "very large allocation" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, std.math.maxInt(usize)));
}

test "realloc" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice = try allocator.alignedAlloc(u8, @alignOf(u32), 1);
    defer allocator.free(slice);
    slice[0] = 0x12;

    // This reallocation should keep its pointer address.
    const old_slice = slice;
    slice = try allocator.realloc(slice, 2);
    try std.testing.expect(old_slice.ptr == slice.ptr);
    try std.testing.expect(slice[0] == 0x12);
    slice[1] = 0x34;

    // This requires upgrading to a larger bin size
    slice = try allocator.realloc(slice, 17);
    try std.testing.expect(old_slice.ptr != slice.ptr);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[1] == 0x34);
}

test "shrink" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice = try allocator.alloc(u8, 20);
    defer allocator.free(slice);

    @memset(slice, 0x11);

    try std.testing.expect(allocator.resize(slice, 17));
    slice = slice[0..17];

    for (slice) |b| {
        try std.testing.expect(b == 0x11);
    }

    try std.testing.expect(!allocator.resize(slice, 16));

    for (slice) |b| {
        try std.testing.expect(b == 0x11);
    }
}

test "large object - grow" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice1 = try allocator.alloc(u8, 8192 - 20);
    defer allocator.free(slice1);

    const old = slice1;
    slice1 = try allocator.realloc(slice1, 8192 - 10);
    try std.testing.expect(slice1.ptr == old.ptr);

    slice1 = try allocator.realloc(slice1, 8192);
    try std.testing.expect(slice1.ptr == old.ptr);

    slice1 = try allocator.realloc(slice1, 8192 + 1);
}

test "realloc small object to large object" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice = try allocator.alloc(u8, 70);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[60] = 0x34;

    // This requires upgrading to a large object
    const large_object_size = 8192 + 50;
    slice = try allocator.realloc(slice, large_object_size);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);
}

test "shrink large object to large object" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice = try allocator.alloc(u8, 8192 + 50);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[60] = 0x34;

    if (!allocator.resize(slice, 8192 + 1)) return;
    slice = slice.ptr[0 .. 8192 + 1];
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);

    try std.testing.expect(allocator.resize(slice, 8192 + 1));
    slice = slice[0 .. 8192 + 1];
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);

    slice = try allocator.realloc(slice, 8192);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);
}

test "shrink large object to large object with larger alignment" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var debug_buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&debug_buffer);
    const debug_allocator = fba.allocator();

    const alloc_size = 8192 + 50;
    var slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    defer allocator.free(slice);

    const big_alignment: usize = switch (builtin.os.tag) {
        .windows => 65536, // Windows aligns to 64K.
        else => 8192,
    };
    // This loop allocates until we find a page that is not aligned to the big
    // alignment. Then we shrink the allocation after the loop, but increase the
    // alignment to the higher one, that we know will force it to realloc.
    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    while (std.mem.isAligned(@intFromPtr(slice.ptr), big_alignment)) {
        try stuff_to_free.append(slice);
        slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    }
    while (stuff_to_free.popOrNull()) |item| {
        allocator.free(item);
    }
    slice[0] = 0x12;
    slice[60] = 0x34;

    slice = try allocator.reallocAdvanced(slice, big_alignment, alloc_size / 2);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[60] == 0x34);
}

test "realloc large object to small object" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice = try allocator.alloc(u8, 8192 + 50);
    defer allocator.free(slice);
    slice[0] = 0x12;
    slice[16] = 0x34;

    slice = try allocator.realloc(slice, 19);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);
}

test "non-page-allocator backing allocator" {
    var binned = BinnedAllocator(.{}){ .backing_allocator = std.testing.allocator };
    defer binned.deinit();
    const allocator = binned.allocator();

    const ptr = try allocator.create(i32);
    defer allocator.destroy(ptr);
}

test "realloc large object to larger alignment" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var debug_buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&debug_buffer);
    const debug_allocator = fba.allocator();

    var slice = try allocator.alignedAlloc(u8, 16, 8192 + 50);
    defer allocator.free(slice);

    const big_alignment: usize = switch (builtin.os.tag) {
        .windows => 65536, // Windows aligns to 64K.
        else => 8192,
    };
    // This loop allocates until we find a page that is not aligned to the big alignment.
    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    while (std.mem.isAligned(@intFromPtr(slice.ptr), big_alignment)) {
        try stuff_to_free.append(slice);
        slice = try allocator.alignedAlloc(u8, 16, 8192 + 50);
    }
    while (stuff_to_free.popOrNull()) |item| {
        allocator.free(item);
    }
    slice[0] = 0x12;
    slice[16] = 0x34;

    slice = try allocator.reallocAdvanced(slice, 32, 8192 + 100);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);

    slice = try allocator.reallocAdvanced(slice, 32, 8192 + 25);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);

    slice = try allocator.reallocAdvanced(slice, big_alignment, 8192 + 100);
    try std.testing.expect(slice[0] == 0x12);
    try std.testing.expect(slice[16] == 0x34);
}

test "large object does not shrink to small" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    var slice = try allocator.alloc(u8, 8192 + 50);
    defer allocator.free(slice);

    try std.testing.expect(!allocator.resize(slice, 4));
}

test "objects of size 1024 and 2048" {
    var binned = BinnedAllocator(.{}){};
    defer binned.deinit();
    const allocator = binned.allocator();

    const slice = try allocator.alloc(u8, 1025);
    const slice2 = try allocator.alloc(u8, 3000);

    allocator.free(slice);
    allocator.free(slice2);
}
