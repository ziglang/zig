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
    allocator: mem.Allocator,
    index: usize,
    fail_index: usize,
    internal_allocator: *mem.Allocator,
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
    pub fn init(allocator: *mem.Allocator, fail_index: usize) FailingAllocator {
        return FailingAllocator{
            .internal_allocator = allocator,
            .fail_index = fail_index,
            .index = 0,
            .allocated_bytes = 0,
            .freed_bytes = 0,
            .allocations = 0,
            .deallocations = 0,
            .allocator = mem.Allocator{
                .reallocFn = realloc,
                .shrinkFn = shrink,
            },
        };
    }

    fn realloc(allocator: *mem.Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) ![]u8 {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.reallocFn(
            self.internal_allocator,
            old_mem,
            old_align,
            new_size,
            new_align,
        );
        if (new_size < old_mem.len) {
            self.freed_bytes += old_mem.len - new_size;
            if (new_size == 0)
                self.deallocations += 1;
        } else if (new_size > old_mem.len) {
            self.allocated_bytes += new_size - old_mem.len;
            if (old_mem.len == 0)
                self.allocations += 1;
        }
        self.index += 1;
        return result;
    }

    fn shrink(allocator: *mem.Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        const r = self.internal_allocator.shrinkFn(self.internal_allocator, old_mem, old_align, new_size, new_align);
        self.freed_bytes += old_mem.len - r.len;
        if (new_size == 0)
            self.deallocations += 1;
        return r;
    }
};
