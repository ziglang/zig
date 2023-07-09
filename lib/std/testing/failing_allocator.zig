const std = @import("../std.zig");
const mem = std.mem;

/// Allocator that fails after N allocations, useful for making sure out of
/// memory conditions are handled correctly.
///
/// To use this, first initialize it and get an allocator with
///
/// `const failing_allocator = &FailingAllocator.init(<allocator>,
///                                                   <fail_index>).allocator;`
///
/// Then use `failing_allocator` anywhere you would have used a
/// different allocator.
pub const FailingAllocator = struct {
    index: usize,
    fail_index: usize,
    internal_allocator: mem.Allocator,
    allocated_bytes: usize,
    freed_bytes: usize,
    allocations: usize,
    deallocations: usize,
    stack_addresses: [num_stack_frames]usize,
    has_induced_failure: bool,

    const num_stack_frames = if (std.debug.sys_can_stack_trace) 16 else 0;

    /// `fail_index` is the number of successful allocations you can
    /// expect from this allocator. The next allocation will fail.
    /// For example, if this is called with `fail_index` equal to 2,
    /// the following test will pass:
    ///
    /// var a = try failing_alloc.create(i32);
    /// var b = try failing_alloc.create(i32);
    /// testing.expectError(error.OutOfMemory, failing_alloc.create(i32));
    pub fn init(internal_allocator: mem.Allocator, fail_index: usize) FailingAllocator {
        return FailingAllocator{
            .internal_allocator = internal_allocator,
            .fail_index = fail_index,
            .index = 0,
            .allocated_bytes = 0,
            .freed_bytes = 0,
            .allocations = 0,
            .deallocations = 0,
            .stack_addresses = undefined,
            .has_induced_failure = false,
        };
    }

    pub fn allocator(self: *FailingAllocator) mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        log2_ptr_align: u8,
        return_address: usize,
    ) ?[*]u8 {
        const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
        if (self.index == self.fail_index) {
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
        const result = self.internal_allocator.rawAlloc(len, log2_ptr_align, return_address) orelse
            return null;
        self.allocated_bytes += len;
        self.allocations += 1;
        self.index += 1;
        return result;
    }

    fn resize(
        ctx: *anyopaque,
        old_mem: []u8,
        log2_old_align: u8,
        new_len: usize,
        ra: usize,
    ) bool {
        const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
        if (!self.internal_allocator.rawResize(old_mem, log2_old_align, new_len, ra))
            return false;
        if (new_len < old_mem.len) {
            self.freed_bytes += old_mem.len - new_len;
        } else {
            self.allocated_bytes += new_len - old_mem.len;
        }
        return true;
    }

    fn free(
        ctx: *anyopaque,
        old_mem: []u8,
        log2_old_align: u8,
        ra: usize,
    ) void {
        const self: *FailingAllocator = @ptrCast(@alignCast(ctx));
        self.internal_allocator.rawFree(old_mem, log2_old_align, ra);
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
};
