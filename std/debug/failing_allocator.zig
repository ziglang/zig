const std = @import("../index.zig");
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
                .allocFn = alloc,
                .reallocFn = realloc,
                .freeFn = free,
            },
        };
    }

    fn alloc(allocator: *mem.Allocator, n: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.allocFn(self.internal_allocator, n, alignment);
        self.allocated_bytes += result.len;
        self.index += 1;
        return result;
    }

    fn realloc(allocator: *mem.Allocator, old_mem: []u8, new_size: usize, alignment: u29) ![]u8 {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        if (new_size <= old_mem.len) {
            self.freed_bytes += old_mem.len - new_size;
            return self.internal_allocator.reallocFn(self.internal_allocator, old_mem, new_size, alignment);
        }
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.reallocFn(self.internal_allocator, old_mem, new_size, alignment);
        self.allocated_bytes += new_size - old_mem.len;
        self.deallocations += 1;
        self.index += 1;
        return result;
    }

    fn free(allocator: *mem.Allocator, bytes: []u8) void {
        const self = @fieldParentPtr(FailingAllocator, "allocator", allocator);
        self.freed_bytes += bytes.len;
        self.deallocations += 1;
        return self.internal_allocator.freeFn(self.internal_allocator, bytes);
    }
};
