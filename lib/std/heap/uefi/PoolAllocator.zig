/// Supports the full std.mem.Allocator interface, including up to page alignment.
///
/// This allocator is backed by `allocatePool` and is therefore only suitable for usage when Boot Services are available.
const std = @import("../../std.zig");
const PoolAllocator = @This();

const mem = std.mem;
const uefi = std.os.uefi;

const Allocator = mem.Allocator;

const assert = std.debug.assert;

memory_type: uefi.tables.MemoryType = .loader_data,

pub fn allocator(self: *PoolAllocator) Allocator {
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

const Header = struct {
    ptr: [*]align(8) u8,
    len: usize,
};

fn getHeader(ptr: [*]u8) *align(1) Header {
    return @ptrCast(ptr - @sizeOf(Header));
}

fn alloc(
    ctx: *anyopaque,
    len: usize,
    alignment: mem.Alignment,
    ret_addr: usize,
) ?[*]u8 {
    _ = ret_addr;
    const self: *PoolAllocator = @ptrCast(@alignCast(ctx));

    assert(len > 0);

    const ptr_align = alignment.toByteUnits();

    // The maximum size of the metadata and any alignment padding.
    const metadata_len = mem.alignForward(usize, @sizeOf(Header), ptr_align);

    const full_len = metadata_len + len;

    const buf = uefi.system_table.boot_services.?.allocatePool(self.memory_type, full_len) catch return null;
    const unaligned_ptr = buf.ptr;

    const unaligned_addr = @intFromPtr(unaligned_ptr);
    const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(Header), ptr_align);

    const aligned_ptr: [*]u8 = @ptrFromInt(aligned_addr);
    getHeader(aligned_ptr).ptr = unaligned_ptr;
    getHeader(aligned_ptr).len = unaligned_addr + full_len - aligned_addr;

    return aligned_ptr;
}

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = ctx;
    _ = alignment;
    _ = ret_addr;

    // If the buffer was originally larger than the new length, we can grow or shrink it in place.
    if (getHeader(buf.ptr).len >= new_len) return true;

    // Otherwise, we cannot grow the buffer.
    return false;
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

    const header = getHeader(buf.ptr);

    uefi.system_table.boot_services.?.freePool(header.ptr[0..header.len]);
}
