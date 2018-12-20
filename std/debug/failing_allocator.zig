const std = @import("../index.zig");
const mem = std.mem;

const Error = mem.AllocatorError;

/// Allocator that fails after N allocations, useful for making sure out of
/// memory conditions are handled correctly.
pub const FailingAllocator = struct {
    index: usize,
    fail_index: usize,
    internal_allocator: mem.Allocator,
    allocated_bytes: usize,
    freed_bytes: usize,
    deallocations: usize,

    pub fn init(internal_allocator: mem.Allocator, fail_index: usize) FailingAllocator {
        return FailingAllocator{
            .internal_allocator = internal_allocator,
            .fail_index = fail_index,
            .index = 0,
            .allocated_bytes = 0,
            .freed_bytes = 0,
            .deallocations = 0,
        };
    }

    fn alloc(self: *FailingAllocator, n: usize, alignment: u29) Error![]u8 {
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.impl.alloc(n, alignment);
        self.allocated_bytes += result.len;
        self.index += 1;
        return result;
    }

    fn realloc(self: *FailingAllocator, old_mem: []u8, new_size: usize, alignment: u29) Error![]u8 {
        if (new_size <= old_mem.len) {
            self.freed_bytes += old_mem.len - new_size;
            return self.internal_allocator.impl.realloc(old_mem, new_size, alignment);
        }
        if (self.index == self.fail_index) {
            return error.OutOfMemory;
        }
        const result = try self.internal_allocator.impl.realloc(old_mem, new_size, alignment);
        self.allocated_bytes += new_size - old_mem.len;
        self.deallocations += 1;
        self.index += 1;
        return result;
    }

    fn free(self: *FailingAllocator, bytes: []u8) void {
        self.freed_bytes += bytes.len;
        self.deallocations += 1;
        return self.internal_allocator.impl.free(bytes);
    }
    
    pub fn allocatorInterface(self: *FailingAllocator) mem.AllocatorInterface(*FailingAllocator) {
        return mem.AllocatorInterface(*FailingAllocator).init(self);
    }
    
    pub fn allocator(self: *FailingAllocator) mem.Allocator {
        return mem.Allocator.init(mem.AbstractAllocator.init(self));
    }
};
