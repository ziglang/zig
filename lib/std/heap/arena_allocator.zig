const std = @import("../std.zig");
const assert = std.debug.assert;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

/// This allocator takes an existing allocator, wraps it, and provides an interface where
/// you can allocate and then free it all together. Calls to free an individual item only
/// free the item if it was the most recent allocation, otherwise calls to free do
/// nothing.
pub const ArenaAllocator = struct {
    child_allocator: Allocator,
    begin: ?*Region,
    end: ?*Region,

    pub const Region = struct {
        next: ?*Region,
        count: usize, // Current usage in bytes
        capacity: usize, // Total capacity in bytes
        base_ptr: [*]u8, // Pointer to the beginning of the allocation
        data: [*]u8, // base_ptr + @sizeOf(Region)
    };

    pub const Mark = struct {
        region: ?*Region,
        count: usize,
    };

    const DEFAULT_REGION_CAPACITY: usize = 64 * 1024; // 64 KiB

    pub fn init(child_allocator: Allocator) ArenaAllocator {
        return .{
            .child_allocator = child_allocator,
            .begin = null,
            .end = null,
        };
    }

    pub fn allocator(self: *ArenaAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    inline fn new_region(self: *ArenaAllocator, capacity: usize, alignment: Alignment) ?*Region {
        const header_size = @sizeOf(Region);
        const size_bytes = header_size + capacity;
        const region_align_bytes = @alignOf(Region);
        const alloc_align_bytes = @max(alignment.toByteUnits(), region_align_bytes);
        const alloc_alignment = Alignment.fromByteUnits(alloc_align_bytes);
        const raw = self.child_allocator.rawAlloc(size_bytes, alloc_alignment, @returnAddress()) orelse return null;
        const base_ptr: [*]u8 = raw;
        const data_ptr: [*]u8 = @ptrCast(@as([*]u8, @ptrFromInt(@intFromPtr(base_ptr))) + header_size);
        const region: *Region = @ptrCast(@alignCast(base_ptr));
        region.* = .{
            .next = null,
            .count = 0,
            .capacity = capacity,
            .base_ptr = base_ptr,
            .data = data_ptr,
        };
        return region;
    }

    inline fn free_region(self: *ArenaAllocator, region: *Region) void {
        const size_bytes = @sizeOf(Region) + region.capacity;
        const alloc_alignment = Alignment.fromByteUnits(@alignOf(Region));
        const slice: []u8 = region.base_ptr[0..size_bytes];
        self.child_allocator.rawFree(slice, alloc_alignment, @returnAddress());
    }

    fn alloc(ctx: *anyopaque, n: usize, alignment: Alignment, ra: usize) ?[*]u8 {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        _ = ra;
        const ptr_align = alignment.toByteUnits();
        const add_call = @addWithOverflow(n, if (ptr_align == 0) 0 else ptr_align - 1);
        if (add_call[1] != 0) return null;
        const aligned_size = add_call[0];

        if (self.end == null) {
            assert(self.begin == null);
            const capacity = @max(DEFAULT_REGION_CAPACITY, aligned_size);
            self.end = self.new_region(capacity, alignment) orelse return null;
            self.begin = self.end;
        }

        var current_region = self.end.?;
        while (current_region.count + aligned_size > current_region.capacity and current_region.next != null) {
            current_region = current_region.next.?;
        }
        if (current_region.count + aligned_size > current_region.capacity) {
            assert(current_region.next == null);
            const capacity = @max(DEFAULT_REGION_CAPACITY, aligned_size);
            current_region.next = self.new_region(capacity, alignment) orelse return null;
            current_region = current_region.next.?;
            self.end = current_region;
        }

        const addr = @intFromPtr(current_region.data) + current_region.count;
        const adjusted_addr = mem.alignForward(usize, addr, ptr_align);
        const alignment_offset = adjusted_addr - addr;
        if (current_region.count + alignment_offset + n > current_region.capacity) return null;

        const result: [*]u8 = @ptrCast(@as([*]u8, @ptrFromInt(adjusted_addr)));
        current_region.count += alignment_offset + n;
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        _ = alignment;
        _ = ret_addr;
        if (self.end == null) return false;
        const current_region = self.end.?;
        const current_buf = current_region.data[0..current_region.count];
        if (@intFromPtr(current_buf.ptr) + current_buf.len != @intFromPtr(buf.ptr) + buf.len) {
            return new_len <= buf.len;
        }
        if (buf.len >= new_len) {
            current_region.count -= buf.len - new_len;
            return true;
        } else if (current_region.count + (new_len - buf.len) <= current_region.capacity) {
            current_region.count += new_len - buf.len;
            return true;
        }
        return false;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        const self: *ArenaAllocator = @ptrCast(@alignCast(context));
        if (new_len <= memory.len) return memory.ptr;
        const new_ptr = alloc(self, new_len, alignment, return_address) orelse return null;
        @memmove(new_ptr[0..memory.len], memory);
        return new_ptr;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: Alignment, ret_addr: usize) void {
        const self: *ArenaAllocator = @ptrCast(@alignCast(ctx));
        _ = alignment;
        _ = ret_addr;
        if (self.end == null) return;
        const current_region = self.end.?;
        const current_buf = current_region.data[0..current_region.count];
        if (@intFromPtr(current_buf.ptr) + current_buf.len == @intFromPtr(buf.ptr) + buf.len) {
            current_region.count -= buf.len;
        }
    }

    pub fn deinit(self: *ArenaAllocator) void {
        var current = self.begin;
        while (current) |region| {
            const next = region.next;
            self.free_region(region);
            current = next;
        }
        self.begin = null;
        self.end = null;
    }

    pub inline fn snapshot(self: *ArenaAllocator) Mark {
        if (self.end == null) {
            assert(self.begin == null);
            return .{ .region = null, .count = 0 };
        }
        return .{ .region = self.end, .count = self.end.?.count };
    }

    pub fn reset(self: *ArenaAllocator) void {
        _ = self.resetWithMode(.free_all);
    }

    pub const ResetMode = union(enum) {
        free_all,
        retain_capacity,
        retain_with_limit: usize,
    };

    pub inline fn resetWithMode(self: *ArenaAllocator, mode: ResetMode) bool {
        var requested_capacity: usize = 0;
        const max_alignment: Alignment = Alignment.fromByteUnits(@alignOf(Region));

        // Collect requested_capacity without modifying the list
        if (mode != .free_all) {
            if (self.begin) |first_region| {
                var current: ?*Region = first_region;
                while (current) |region| {
                    requested_capacity += region.count;
                    current = region.next;
                }
            }
        }
        // Free all regions
        var current = self.begin;
        while (current) |region| {
            const next = region.next;
            self.free_region(region);
            current = next;
        }
        self.begin = null;
        self.end = null;

        // Apply capacity limit for .retain_with_limit
        switch (mode) {
            .free_all => requested_capacity = 0,
            .retain_capacity => {}, // Keep requested_capacity
            .retain_with_limit => |limit| requested_capacity = @min(requested_capacity, limit),
        }

        if (requested_capacity == 0) {
            return true;
        }

        // Create a new region with the requested capacity
        const nw_region = self.new_region(requested_capacity, max_alignment) orelse {
            return false;
        };
        self.begin = nw_region;
        self.end = nw_region;
        return true;
    }

    pub fn rewind(self: *ArenaAllocator, mark: Mark) void {
        if (mark.region == null) {
            self.reset();
            return;
        }
        mark.region.?.count = mark.count;
        var current = mark.region.?.next;
        while (current) |region| {
            region.count = 0;
            current = region.next;
        }
        self.end = mark.region;
    }

    pub fn trim(self: *ArenaAllocator) void {
        if (self.end == null) return;
        var current = self.end.?.next;
        while (current) |region| {
            const next = region.next;
            self.free_region(region);
            current = next;
        }
        self.end.?.next = null;
    }
};

test "reset with preheating" {
    var arena_allocator = ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    // provides some variance in the allocated data
    var rng_src = std.Random.DefaultPrng.init(std.testing.random_seed);
    const random = rng_src.random();
    var rounds: usize = 25;
    while (rounds > 0) {
        rounds -= 1;
        _ = arena_allocator.reset(.retain_capacity);
        var alloced_bytes: usize = 0;
        const total_size: usize = random.intRangeAtMost(usize, 256, 16384);
        while (alloced_bytes < total_size) {
            const size = random.intRangeAtMost(usize, 16, 256);
            const alignment: Alignment = .@"32";
            const slice = try arena_allocator.allocator().alignedAlloc(u8, alignment, size);
            try std.testing.expect(alignment.check(@intFromPtr(slice.ptr)));
            try std.testing.expectEqual(size, slice.len);
            alloced_bytes += slice.len;
        }
    }
}

test "reset while retaining a buffer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    var arena_allocator = ArenaAllocator.init(gpa.allocator());
    defer arena_allocator.deinit();
    const a = arena_allocator.allocator();
    _ = try a.alloc(u8, 1);
    _ = try a.alloc(u8, 1000);
    try std.testing.expect(arena_allocator.begin != null);
    try std.testing.expect(arena_allocator.resetWithMode(.{ .retain_with_limit = 1000 }));
}
