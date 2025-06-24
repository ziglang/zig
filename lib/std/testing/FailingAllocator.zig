//! Allocator that fails after N allocations, useful for making sure out of
//! memory conditions are handled correctly.
const std = @import("../std.zig");
const mem = std.mem;
const FailingAllocator = @This();

alloc_index: usize,
resize_index: usize,
internal_allocator: mem.Allocator,
allocated_bytes: usize,
freed_bytes: usize,
allocations: usize,
deallocations: usize,
stack_addresses: [num_stack_frames]usize,
has_induced_failure: bool,
fail_index: usize,
resize_fail_index: usize,

const num_stack_frames = if (std.debug.sys_can_stack_trace) 16 else 0;

pub const Config = struct {
    /// The number of successful allocations you can expect from this allocator.
    /// The next allocation will fail.
    fail_index: usize = std.math.maxInt(usize),

    /// Number of successful resizes to expect from this allocator. The next resize will fail.
    resize_fail_index: usize = std.math.maxInt(usize),
};

pub fn init(internal_allocator: mem.Allocator, config: Config) FailingAllocator {
    return FailingAllocator{
        .internal_allocator = internal_allocator,
        .alloc_index = 0,
        .resize_index = 0,
        .allocated_bytes = 0,
        .freed_bytes = 0,
        .allocations = 0,
        .deallocations = 0,
        .stack_addresses = undefined,
        .has_induced_failure = false,
        .fail_index = config.fail_index,
        .resize_fail_index = config.resize_fail_index,
    };
}

pub fn allocator(self: *FailingAllocator) mem.Allocator {
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

fn alloc(
    ctx: *anyopaque,
    len: usize,
    alignment: mem.Alignment,
    return_address: usize,
) ?[*]u8 {
    const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
    if (self.alloc_index == self.fail_index) {
        if (!self.has_induced_failure) {
            @memset(&self.stack_addresses, 0);
            var stack_trace = std.builtin.StackTrace{
                .instruction_addresses = &self.stack_addresses,
                .index = 0,
            };
            std.debug.captureStackTrace(return_address, &stack_trace);
            self.has_induced_failure = true;
        }
        return null;
    }
    const result = self.internal_allocator.rawAlloc(len, alignment, return_address) orelse
        return null;
    self.allocated_bytes += len;
    self.allocations += 1;
    self.alloc_index += 1;
    return result;
}

fn resize(
    ctx: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ra: usize,
) bool {
    const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
    if (self.resize_index == self.resize_fail_index)
        return false;
    if (!self.internal_allocator.rawResize(memory, alignment, new_len, ra))
        return false;
    if (new_len < memory.len) {
        self.freed_bytes += memory.len - new_len;
    } else {
        self.allocated_bytes += new_len - memory.len;
    }
    self.resize_index += 1;
    return true;
}

fn remap(
    ctx: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ra: usize,
) ?[*]u8 {
    const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
    if (self.resize_index == self.resize_fail_index) return null;
    const new_ptr = self.internal_allocator.rawRemap(memory, alignment, new_len, ra) orelse return null;
    if (new_len < memory.len) {
        self.freed_bytes += memory.len - new_len;
    } else {
        self.allocated_bytes += new_len - memory.len;
    }
    self.resize_index += 1;
    return new_ptr;
}

fn free(
    ctx: *anyopaque,
    old_mem: []u8,
    alignment: mem.Alignment,
    ra: usize,
) void {
    const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
    self.internal_allocator.rawFree(old_mem, alignment, ra);
    self.deallocations += 1;
    self.freed_bytes += old_mem.len;
}

/// Only valid once `has_induced_failure == true`
pub fn getStackTrace(self: *FailingAllocator) std.builtin.StackTrace {
    std.debug.assert(self.has_induced_failure);
    var len: usize = 0;
    while (len < self.stack_addresses.len and self.stack_addresses[len] != 0) {
        len += 1;
    }
    return .{
        .instruction_addresses = &self.stack_addresses,
        .index = len,
    };
}

test FailingAllocator {
    // Fail on allocation
    {
        var failing_allocator_state = FailingAllocator.init(std.testing.allocator, .{
            .fail_index = 2,
        });
        const failing_alloc = failing_allocator_state.allocator();

        const a = try failing_alloc.create(i32);
        defer failing_alloc.destroy(a);
        const b = try failing_alloc.create(i32);
        defer failing_alloc.destroy(b);
        try std.testing.expectError(error.OutOfMemory, failing_alloc.create(i32));
    }
    // Fail on resize
    {
        var failing_allocator_state = FailingAllocator.init(std.testing.allocator, .{
            .resize_fail_index = 1,
        });
        const failing_alloc = failing_allocator_state.allocator();

        const resized_slice = blk: {
            const slice = try failing_alloc.alloc(u8, 8);
            errdefer failing_alloc.free(slice);

            break :blk failing_alloc.remap(slice, 6) orelse return error.UnexpectedRemapFailure;
        };
        defer failing_alloc.free(resized_slice);

        // Remap and resize should fail from here on out
        try std.testing.expectEqual(null, failing_alloc.remap(resized_slice, 4));
        try std.testing.expectEqual(false, failing_alloc.resize(resized_slice, 4));

        // Note: realloc could succeed because it falls back to free+alloc
    }
}
