/// Allocates memory in pages.
///
/// This allocator is backed by `allocatePages` and is therefore only suitable for usage when Boot Services are available.
const std = @import("../../std.zig");
const PageAllocator = @This();

const mem = std.mem;
const uefi = std.os.uefi;

const Allocator = mem.Allocator;

const assert = std.debug.assert;

memory_type: uefi.tables.MemoryType = .loader_data,

pub fn allocator(self: *PageAllocator) Allocator {
    return Allocator{
        .ptr = self,
        .vtable = &vtable,
    };
}

const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

fn alloc(
    ctx: *anyopaque,
    len: usize,
    alignment: mem.Alignment,
    ret_addr: usize,
) ?[*]u8 {
    _ = alignment;
    _ = ret_addr;

    const self: *PageAllocator = @ptrCast(@alignCast(ctx));

    assert(len > 0);
    const pages = mem.alignForward(usize, len, 4096) / 4096;

    const buf = uefi.system_table.boot_services.?.allocatePages(.any, self.memory_type, pages) catch return null;
    return buf.ptr;
}

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = alignment;
    _ = ret_addr;

    const self: *PageAllocator = @ptrCast(@alignCast(ctx));

    // If the buffer was originally larger than the new length, we can grow or shrink it in place.
    const original_len = mem.alignForward(usize, buf.len, 4096);
    const new_aligned_len = mem.alignForward(usize, new_len, 4096);

    if (original_len >= new_aligned_len) return true;

    const new_pages_required = (new_aligned_len - original_len) / 4096;
    const start_of_new_pages = @intFromPtr(buf.ptr) + original_len;

    // Try to allocate the necessary pages at the end of the buffer.
    const new_pages = uefi.system_table.boot_services.?.allocatePages(.{ .at_address = start_of_new_pages }, self.memory_type, new_pages_required) catch return false;
    _ = new_pages;

    // If the above function succeeds, then the new pages were successfully allocated.
    return true;
}

fn remap(
    ctx: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) ?[*]u8 {
    _ = ctx;
    _ = buf;
    _ = alignment;
    _ = new_len;
    _ = ret_addr;
    return null;
}

fn free(
    ctx: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    ret_addr: usize,
) void {
    _ = ctx;
    _ = alignment;
    _ = ret_addr;

    const aligned_len = mem.alignForward(usize, buf.len, 4096);
    const ptr: [*]align(4096) u8 = @alignCast(buf.ptr);

    uefi.system_table.boot_services.?.freePages(ptr[0..aligned_len]);
}
