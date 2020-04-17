const std = @import("../std.zig");

/// This allocator is used in front of another allocator and counts the numbers of allocs and frees.
/// The test runner asserts every alloc has a corresponding free at the end of each test.
///
/// The detection algorithm is incredibly primitive and only accounts for number of calls.
/// This should be replaced by the general purpose debug allocator.
pub const LeakCountAllocator = struct {
    count: usize,
    allocator: std.mem.Allocator,
    internal_allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) LeakCountAllocator {
        return .{
            .count = 0,
            .allocator = .{
                .allocFn = alloc,
                .resizeFn = resize,
            },
            .internal_allocator = allocator,
        };
    }

    fn alloc(allocator: *std.mem.Allocator, len: usize, ptr_align: u29, len_align: u29) error{OutOfMemory}![]u8 {
        const self = @fieldParentPtr(LeakCountAllocator, "allocator", allocator);
        const ptr = try self.internal_allocator.callAllocFn(len, ptr_align, len_align);
        self.count += 1;
        return ptr;
    }

    fn resize(allocator: *std.mem.Allocator, old_mem: []u8, new_size: usize, len_align: u29) error{OutOfMemory}!usize {
        const self = @fieldParentPtr(LeakCountAllocator, "allocator", allocator);
        if (new_size == 0) {
            if (self.count == 0) {
                std.debug.panic("error - too many calls to free, most likely double free", .{});
            }
            self.count -= 1;
        }
        return self.internal_allocator.callResizeFn(old_mem, new_size, len_align) catch |e| {
            std.debug.assert(new_size > old_mem.len);
            return e;
        };
    }

    pub fn validate(self: LeakCountAllocator) !void {
        if (self.count > 0) {
            std.debug.warn("error - detected leaked allocations without matching free: {}\n", .{self.count});
            return error.Leak;
        }
    }
};
