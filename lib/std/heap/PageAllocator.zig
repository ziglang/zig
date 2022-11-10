const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const os = std.os;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const alignPageAllocLen = std.heap.alignPageAllocLen;

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

fn alloc(_: *anyopaque, n: usize, alignment: u29, len_align: u29, ra: usize) error{OutOfMemory}![]u8 {
    _ = ra;
    assert(n > 0);
    if (n > maxInt(usize) - (mem.page_size - 1)) {
        return error.OutOfMemory;
    }
    const aligned_len = mem.alignForward(n, mem.page_size);

    if (builtin.os.tag == .windows) {
        const w = os.windows;

        // Although officially it's at least aligned to page boundary,
        // Windows is known to reserve pages on a 64K boundary. It's
        // even more likely that the requested alignment is <= 64K than
        // 4K, so we're just allocating blindly and hoping for the best.
        // see https://devblogs.microsoft.com/oldnewthing/?p=42223
        const addr = w.VirtualAlloc(
            null,
            aligned_len,
            w.MEM_COMMIT | w.MEM_RESERVE,
            w.PAGE_READWRITE,
        ) catch return error.OutOfMemory;

        // If the allocation is sufficiently aligned, use it.
        if (mem.isAligned(@ptrToInt(addr), alignment)) {
            return @ptrCast([*]u8, addr)[0..alignPageAllocLen(aligned_len, n, len_align)];
        }

        // If it wasn't, actually do an explicitly aligned allocation.
        w.VirtualFree(addr, 0, w.MEM_RELEASE);
        const alloc_size = n + alignment - mem.page_size;

        while (true) {
            // Reserve a range of memory large enough to find a sufficiently
            // aligned address.
            const reserved_addr = w.VirtualAlloc(
                null,
                alloc_size,
                w.MEM_RESERVE,
                w.PAGE_NOACCESS,
            ) catch return error.OutOfMemory;
            const aligned_addr = mem.alignForward(@ptrToInt(reserved_addr), alignment);

            // Release the reserved pages (not actually used).
            w.VirtualFree(reserved_addr, 0, w.MEM_RELEASE);

            // At this point, it is possible that another thread has
            // obtained some memory space that will cause the next
            // VirtualAlloc call to fail. To handle this, we will retry
            // until it succeeds.
            const ptr = w.VirtualAlloc(
                @intToPtr(*anyopaque, aligned_addr),
                aligned_len,
                w.MEM_COMMIT | w.MEM_RESERVE,
                w.PAGE_READWRITE,
            ) catch continue;

            return @ptrCast([*]u8, ptr)[0..alignPageAllocLen(aligned_len, n, len_align)];
        }
    }

    const max_drop_len = alignment - @min(alignment, mem.page_size);
    const alloc_len = if (max_drop_len <= aligned_len - n)
        aligned_len
    else
        mem.alignForward(aligned_len + max_drop_len, mem.page_size);
    const hint = @atomicLoad(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, .Unordered);
    const slice = os.mmap(
        hint,
        alloc_len,
        os.PROT.READ | os.PROT.WRITE,
        os.MAP.PRIVATE | os.MAP.ANONYMOUS,
        -1,
        0,
    ) catch return error.OutOfMemory;
    assert(mem.isAligned(@ptrToInt(slice.ptr), mem.page_size));

    const result_ptr = mem.alignPointer(slice.ptr, alignment) orelse
        return error.OutOfMemory;

    // Unmap the extra bytes that were only requested in order to guarantee
    // that the range of memory we were provided had a proper alignment in
    // it somewhere. The extra bytes could be at the beginning, or end, or both.
    const drop_len = @ptrToInt(result_ptr) - @ptrToInt(slice.ptr);
    if (drop_len != 0) {
        os.munmap(slice[0..drop_len]);
    }

    // Unmap extra pages
    const aligned_buffer_len = alloc_len - drop_len;
    if (aligned_buffer_len > aligned_len) {
        os.munmap(@alignCast(mem.page_size, result_ptr[aligned_len..aligned_buffer_len]));
    }

    const new_hint = @alignCast(mem.page_size, result_ptr + aligned_len);
    _ = @cmpxchgStrong(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, hint, new_hint, .Monotonic, .Monotonic);

    return result_ptr[0..alignPageAllocLen(aligned_len, n, len_align)];
}

fn resize(
    _: *anyopaque,
    buf_unaligned: []u8,
    buf_align: u29,
    new_size: usize,
    len_align: u29,
    return_address: usize,
) ?usize {
    _ = buf_align;
    _ = return_address;
    const new_size_aligned = mem.alignForward(new_size, mem.page_size);

    if (builtin.os.tag == .windows) {
        const w = os.windows;
        if (new_size <= buf_unaligned.len) {
            const base_addr = @ptrToInt(buf_unaligned.ptr);
            const old_addr_end = base_addr + buf_unaligned.len;
            const new_addr_end = mem.alignForward(base_addr + new_size, mem.page_size);
            if (old_addr_end > new_addr_end) {
                // For shrinking that is not releasing, we will only
                // decommit the pages not needed anymore.
                w.VirtualFree(
                    @intToPtr(*anyopaque, new_addr_end),
                    old_addr_end - new_addr_end,
                    w.MEM_DECOMMIT,
                );
            }
            return alignPageAllocLen(new_size_aligned, new_size, len_align);
        }
        const old_size_aligned = mem.alignForward(buf_unaligned.len, mem.page_size);
        if (new_size_aligned <= old_size_aligned) {
            return alignPageAllocLen(new_size_aligned, new_size, len_align);
        }
        return null;
    }

    const buf_aligned_len = mem.alignForward(buf_unaligned.len, mem.page_size);
    if (new_size_aligned == buf_aligned_len)
        return alignPageAllocLen(new_size_aligned, new_size, len_align);

    if (new_size_aligned < buf_aligned_len) {
        const ptr = @alignCast(mem.page_size, buf_unaligned.ptr + new_size_aligned);
        // TODO: if the next_mmap_addr_hint is within the unmapped range, update it
        os.munmap(ptr[0 .. buf_aligned_len - new_size_aligned]);
        return alignPageAllocLen(new_size_aligned, new_size, len_align);
    }

    // TODO: call mremap
    // TODO: if the next_mmap_addr_hint is within the remapped range, update it
    return null;
}

fn free(_: *anyopaque, buf_unaligned: []u8, buf_align: u29, return_address: usize) void {
    _ = buf_align;
    _ = return_address;

    if (builtin.os.tag == .windows) {
        os.windows.VirtualFree(buf_unaligned.ptr, 0, os.windows.MEM_RELEASE);
    } else {
        const buf_aligned_len = mem.alignForward(buf_unaligned.len, mem.page_size);
        const ptr = @alignCast(mem.page_size, buf_unaligned.ptr);
        os.munmap(ptr[0..buf_aligned_len]);
    }
}
