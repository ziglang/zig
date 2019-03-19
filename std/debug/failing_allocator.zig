const std = @import("../std.zig");
const mem = std.mem;

/// Allocator that fails after N allocations, useful for making sure out of
/// memory conditions are handled correctly.
pub const FailingAllocator = struct {
    allocator: mem.Allocator,
    index: usize,
    fail_index: usize,
    internal_allocator: *mem.Allocator,
    allocated_bytes: usize,
    freed_bytes: usize,
    deallocations: usize,

    pub fn init(allocator: *mem.Allocator, fail_index: usize) FailingAllocator {
        return FailingAllocator{
            .internal_allocator = allocator,
            .fail_index = fail_index,
            .index = 0,
            .allocated_bytes = 0,
            .freed_bytes = 0,
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
        if (new_size <= old_mem.len) {
            self.freed_bytes += old_mem.len - new_size;
        } else {
            self.allocated_bytes += new_size - old_mem.len;
        }
        self.deallocations += 1;
        self.index += 1;
        return result;
    }

    fn shrink(allocator: *mem.Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        self.freed_bytes += old_mem.len - new_size;
        return self.internal_allocator.shrinkFn(self.internal_allocator, old_mem, old_align, new_size, new_align);
    }
};
