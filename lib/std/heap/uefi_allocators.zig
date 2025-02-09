const std = @import("../std.zig");

const mem = std.mem;
const uefi = std.os.uefi;

const Allocator = mem.Allocator;

const assert = std.debug.assert;

pub var global_page_allocator = PageAllocator{};
pub var global_pool_allocator = PoolAllocator{};

/// Allocates memory in pages.
///
/// This allocator is backed by `allocatePages` and is therefore only suitable for usage when Boot Services are available.
pub const PageAllocator = struct {
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
};

/// Supports the full std.mem.Allocator interface, including up to page alignment.
///
/// This allocator is backed by `allocatePool` and is therefore only suitable for usage when Boot Services are available.
pub const PoolAllocator = struct {
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
};

/// Asserts all allocations are at most 8 byte aligned. This is the highest alignment UEFI will give us directly.
///
/// This allocator is backed by `allocatePool` and is therefore only suitable for usage when Boot Services are available.
pub const RawPoolAllocator = struct {
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
};
