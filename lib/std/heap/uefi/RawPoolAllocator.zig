/// Asserts all allocations are at most 8 byte aligned. This is the highest alignment UEFI will give us directly.
///
/// This allocator is backed by `allocatePool` and is therefore only suitable for usage when Boot Services are available.
const std = @import("../../std.zig");
const RawPoolAllocator = @This();

const mem = std.mem;
const uefi = std.os.uefi;

const Allocator = mem.Allocator;

const assert = std.debug.assert;

memory_type: uefi.tables.MemoryType = .loader_data,

pub fn allocator(self: *RawPoolAllocator) Allocator {
    return Allocator{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub const vtable = Allocator.VTable{
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
    _ = ret_addr;
    const self: *RawPoolAllocator = @ptrCast(@alignCast(ctx));

    // UEFI pool allocations are 8 byte aligned, so we can't do better than that.
    std.debug.assert(@intFromEnum(alignment) <= 3);

    const buf = uefi.system_table.boot_services.?.allocatePool(self.memory_type, len) catch return null;
    return buf.ptr;
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

    // The original capacity is not known, so we can't ever grow the buffer.
    if (new_len > buf.len) return false;

    // If this is a shrink, it will happen in place.
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

    uefi.system_table.boot_services.?.freePool(@alignCast(buf));
}
