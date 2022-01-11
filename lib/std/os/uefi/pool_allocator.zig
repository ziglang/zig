const std = @import("std");

const mem = std.mem;
const uefi = std.os.uefi;

const assert = std.debug.assert;

const Allocator = mem.Allocator;

const UefiPoolAllocator = struct {
    fn getHeader(ptr: [*]u8) *[*]align(8) u8 {
        return @intToPtr(*[*]align(8) u8, @ptrToInt(ptr) - @sizeOf(usize));
    }

    fn alignedAlloc(len: usize, alignment: usize) ?[*]u8 {
        var unaligned_ptr: [*]align(8) u8 = undefined;

        if (uefi.system_table.boot_services.?.allocatePool(uefi.efi_pool_memory_type, len, &unaligned_ptr) != .Success)
            return null;

        const unaligned_addr = @ptrToInt(unaligned_ptr);
        const aligned_addr = mem.alignForward(unaligned_addr + @sizeOf(usize), alignment);

        var aligned_ptr = unaligned_ptr + (aligned_addr - unaligned_addr);
        getHeader(aligned_ptr).* = unaligned_ptr;

        return aligned_ptr;
    }

    fn alignedFree(ptr: [*]u8) void {
        _ = uefi.system_table.boot_services.?.freePool(getHeader(ptr).*);
    }

    fn alloc(
        _: *anyopaque,
        len: usize,
        ptr_align: u29,
        len_align: u29,
        ret_addr: usize,
    ) Allocator.Error![]u8 {
        _ = ret_addr;

        assert(len > 0);
        assert(std.math.isPowerOfTwo(ptr_align));

        var ptr = alignedAlloc(len, ptr_align) orelse return error.OutOfMemory;

        if (len_align == 0)
            return ptr[0..len];

        return ptr[0..mem.alignBackwardAnyAlign(len, len_align)];
    }

    fn resize(
        _: *anyopaque,
        buf: []u8,
        buf_align: u29,
        new_len: usize,
        len_align: u29,
        ret_addr: usize,
    ) ?usize {
        _ = buf_align;
        _ = ret_addr;

        return if (new_len <= buf.len) mem.alignAllocLen(buf.len, new_len, len_align) else null;
    }

    fn free(
        _: *anyopaque,
        buf: []u8,
        buf_align: u29,
        ret_addr: usize,
    ) void {
        _ = buf_align;
        _ = ret_addr;
        alignedFree(buf.ptr);
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
    .free = uefi_free,
};

fn uefi_alloc(
    _: *anyopaque,
    len: usize,
    ptr_align: u29,
    len_align: u29,
    ret_addr: usize,
) Allocator.Error![]u8 {
    _ = len_align;
    _ = ret_addr;

    std.debug.assert(ptr_align <= 8);

    var ptr: [*]align(8) u8 = undefined;

    if (uefi.system_table.boot_services.?.allocatePool(uefi.efi_pool_memory_type, len, &ptr) != .Success) {
        return error.OutOfMemory;
    }

    return ptr[0..len];
}

fn uefi_resize(
    _: *anyopaque,
    buf: []u8,
    old_align: u29,
    new_len: usize,
    len_align: u29,
    ret_addr: usize,
) ?usize {
    _ = old_align;
    _ = ret_addr;

    if (new_len <= buf.len) {
        return mem.alignAllocLen(buf.len, new_len, len_align);
    }

    return null;
}

fn uefi_free(
    _: *anyopaque,
    buf: []u8,
    buf_align: u29,
    ret_addr: usize,
) void {
    _ = buf_align;
    _ = ret_addr;
    _ = uefi.system_table.boot_services.?.freePool(@alignCast(8, buf.ptr));
}
