//! Wraps a non-thread-safe allocator and makes it thread-safe.

child_allocator: Allocator,
mutex: std.Thread.Mutex = .{},

pub fn allocator(self: *ThreadSafeAllocator) Allocator {
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

fn alloc(ctx: *anyopaque, n: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(ctx));
    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawAlloc(n, alignment, ra);
}

fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(ctx));

    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawResize(buf, alignment, new_len, ret_addr);
}

fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(context));

    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawRemap(memory, alignment, new_len, return_address);
}

fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
    const self: *ThreadSafeAllocator = @ptrCast(@alignCast(ctx));

    self.mutex.lock();
    defer self.mutex.unlock();

    return self.child_allocator.rawFree(buf, alignment, ret_addr);
}

const std = @import("../std.zig");
const ThreadSafeAllocator = @This();
const Allocator = std.mem.Allocator;
