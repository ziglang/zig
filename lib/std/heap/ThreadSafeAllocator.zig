//! Wraps a non-thread-safe allocator and makes it thread-safe.

child_allocator: Allocator,
mutex: std.Thread.Mutex = .{},

pub fn allocator(self: *ThreadSafeAllocator) Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .free = free,
        },
    };
}

fn alloc(ctx: *anyopaque, n: usize, log2_ptr_align: u8, ra: usize) ?[*]u8 {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(ctx));
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawAlloc(n, log2_ptr_align, ra);
}

fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(ctx));

    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawResize(buf, log2_buf_align, new_len, ret_addr);
}

fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(ctx));

    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawFree(buf, log2_buf_align, ret_addr);
}

const std = @import("../std.zig");
const ThreadSafeAllocator = @This();
const Allocator = std.mem.Allocator;
