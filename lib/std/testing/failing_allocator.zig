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
        };
    }

    pub fn allocator(self: *FailingAllocator) mem.Allocator {
        return mem.Allocator.init(self, alloc, resize, free);
    }

    fn alloc(
        self: *FailingAllocator,
        len: usize,
        ptr_align: u29,
        len_align: u29,
        return_address: usize,
    ) error{OutOfMemory}![]u8 {
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.rawAlloc(len, ptr_align, len_align, return_address);
        self.allocated_bytes += result.len;
        self.allocations += 1;
        self.index += 1;
        return result;
    }

    fn resize(
        self: *FailingAllocator,
        old_mem: []u8,
        old_align: u29,
        new_len: usize,
        len_align: u29,
        ra: usize,
    ) ?usize {
        const r = self.internal_allocator.rawResize(old_mem, old_align, new_len, len_align, ra) orelse return null;
        if (r < old_mem.len) {
            self.freed_bytes += old_mem.len - r;
        } else {
            self.allocated_bytes += r - old_mem.len;
        }
        return r;
    }

    fn free(
        self: *FailingAllocator,
        old_mem: []u8,
        old_align: u29,
        ra: usize,
    ) void {
        self.internal_allocator.rawFree(old_mem, old_align, ra);
        self.deallocations += 1;
        self.freed_bytes += old_mem.len;
    }
};
