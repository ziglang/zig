const std = @import("std");

const mem = std.mem;
const uefi = std.os.uefi;

const assert = std.debug.assert;

const Allocator = mem.Allocator;

const UefiPoolAllocator = struct {
    fn getHeader(ptr: [*]u8) *[*]align(8) u8 {
        return @as(*[*]align(8) u8, @ptrFromInt(@intFromPtr(ptr) - @sizeOf(usize)));
    }

    fn alloc(
        _: *anyopaque,
        len: usize,
        alignment: mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        _ = ret_addr;

        assert(len > 0);

        const ptr_align = alignment.toByteUnits();

        const metadata_len = mem.alignForward(usize, @sizeOf(usize), ptr_align);

        const full_len = metadata_len + len;

        var unaligned_ptr: [*]align(8) u8 = undefined;
        if (uefi.system_table.boot_services.?.allocatePool(uefi.efi_pool_memory_type, full_len, &unaligned_ptr) != .success) return null;

        const unaligned_addr = @intFromPtr(unaligned_ptr);
        const aligned_addr = mem.alignForward(usize, unaligned_addr + @sizeOf(usize), ptr_align);

        const aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
        getHeader(aligned_ptr).* = unaligned_ptr;

        return aligned_ptr;
    }

    fn resize(
        _: *anyopaque,
        buf: []u8,
        alignment: mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        _ = ret_addr;
        _ = alignment;

        if (new_len > buf.len) return false;
        return true;
    }

    fn remap(
        _: *anyopaque,
        buf: []u8,
        alignment: mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        _ = alignment;
        _ = ret_addr;

        if (new_len > buf.len) return null;
        return buf.ptr;
    }

    fn free(
        _: *anyopaque,
        buf: []u8,
        alignment: mem.Alignment,
        ret_addr: usize,
    ) void {
        _ = alignment;
        _ = ret_addr;
        _ = uefi.system_table.boot_services.?.freePool(getHeader(buf.ptr).*);
    }
};

/// Supports the full Allocator interface, including alignment.
/// For a direct call of `allocatePool`, see `raw_pool_allocator`.
pub const pool_allocator = Allocator{
    .ptr = undefined,
    .vtable = &pool_allocator_vtable,
};

const pool_allocator_vtable = Allocator.VTable{
    .alloc = UefiPoolAllocator.alloc,
    .resize = UefiPoolAllocator.resize,
    .remap = UefiPoolAllocator.remap,
    .free = UefiPoolAllocator.free,
};

/// Asserts allocations are 8 byte aligned and calls `boot_services.allocatePool`.
pub const raw_pool_allocator = Allocator{
    .ptr = undefined,
    .vtable = &raw_pool_allocator_table,
};

const raw_pool_allocator_table = Allocator.VTable{
    .alloc = uefi_alloc,
    .resize = uefi_resize,
    .remap = uefi_remap,
    .free = uefi_free,
};

fn uefi_alloc(
    _: *anyopaque,
    len: usize,
    alignment: mem.Alignment,
    ret_addr: usize,
) ?[*]u8 {
    _ = ret_addr;

    std.debug.assert(@intFromEnum(alignment) <= 3);

    var ptr: [*]align(8) u8 = undefined;
    if (uefi.system_table.boot_services.?.allocatePool(uefi.efi_pool_memory_type, len, &ptr) != .success) return null;

    return ptr;
}

fn uefi_resize(
    _: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = ret_addr;

    std.debug.assert(@intFromEnum(alignment) <= 3);

    if (new_len > buf.len) return false;
    return true;
}

fn uefi_remap(
    _: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    ret_addr: usize,
) ?[*]u8 {
    _ = ret_addr;

    std.debug.assert(@intFromEnum(alignment) <= 3);

    if (new_len > buf.len) return null;
    return buf.ptr;
}

fn uefi_free(
    _: *anyopaque,
    buf: []u8,
    alignment: mem.Alignment,
    ret_addr: usize,
) void {
    _ = alignment;
    _ = ret_addr;
    _ = uefi.system_table.boot_services.?.freePool(@alignCast(buf.ptr));
}
