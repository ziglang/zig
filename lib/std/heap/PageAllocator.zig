const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;
const page_size_min = std.heap.page_size_min;

pub const vtable: Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

pub fn map(n: usize, alignment: mem.Alignment) ?[*]u8 {
    const page_size = std.heap.pageSize();
    if (n >= maxInt(usize) - page_size) return null;
    const alignment_bytes = alignment.toByteUnits();

    if (native_os == .windows) {
        // According to official documentation, VirtualAlloc aligns to page
        // boundary, however, empirically it reserves pages on a 64K boundary.
        // Since it is very likely the requested alignment will be honored,
        // this logic first tries a call with exactly the size requested,
        // before falling back to the loop below.
        // https://devblogs.microsoft.com/oldnewthing/?p=42223
        const addr = windows.VirtualAlloc(
            null,
            // VirtualAlloc will round the length to a multiple of page size.
            // "If the lpAddress parameter is NULL, this value is rounded up to
            // the next page boundary".
            n,
            windows.MEM_COMMIT | windows.MEM_RESERVE,
            windows.PAGE_READWRITE,
        ) catch return null;

        if (mem.isAligned(@intFromPtr(addr), alignment_bytes))
            return @ptrCast(addr);

        // Fallback: reserve a range of memory large enough to find a
        // sufficiently aligned address, then free the entire range and
        // immediately allocate the desired subset. Another thread may have won
        // the race to map the target range, in which case a retry is needed.
        windows.VirtualFree(addr, 0, windows.MEM_RELEASE);

        const overalloc_len = n + alignment_bytes - page_size;
        const aligned_len = mem.alignForward(usize, n, page_size);

        while (true) {
            const reserved_addr = windows.VirtualAlloc(
                null,
                overalloc_len,
                windows.MEM_RESERVE,
                windows.PAGE_NOACCESS,
            ) catch return null;
            const aligned_addr = mem.alignForward(usize, @intFromPtr(reserved_addr), alignment_bytes);
            windows.VirtualFree(reserved_addr, 0, windows.MEM_RELEASE);
            const ptr = windows.VirtualAlloc(
                @ptrFromInt(aligned_addr),
                aligned_len,
                windows.MEM_COMMIT | windows.MEM_RESERVE,
                windows.PAGE_READWRITE,
            ) catch continue;
            return @ptrCast(ptr);
        }
    }

    const aligned_len = mem.alignForward(usize, n, page_size);
    const max_drop_len = alignment_bytes - @min(alignment_bytes, page_size);
    const overalloc_len = if (max_drop_len <= aligned_len - n)
        aligned_len
    else
        mem.alignForward(usize, aligned_len + max_drop_len, page_size);
    const hint = @atomicLoad(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, .unordered);
    const slice = posix.mmap(
        hint,
        overalloc_len,
        posix.PROT.READ | posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    ) catch return null;
    const result_ptr = mem.alignPointer(slice.ptr, alignment_bytes) orelse return null;
    // Unmap the extra bytes that were only requested in order to guarantee
    // that the range of memory we were provided had a proper alignment in it
    // somewhere. The extra bytes could be at the beginning, or end, or both.
    const drop_len = result_ptr - slice.ptr;
    if (drop_len != 0) posix.munmap(slice[0..drop_len]);
    const remaining_len = overalloc_len - drop_len;
    if (remaining_len > aligned_len) posix.munmap(@alignCast(result_ptr[aligned_len..remaining_len]));
    const new_hint: [*]align(page_size_min) u8 = @alignCast(result_ptr + aligned_len);
    _ = @cmpxchgStrong(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, hint, new_hint, .monotonic, .monotonic);
    return result_ptr;
}

fn alloc(context: *anyopaque, n: usize, alignment: mem.Alignment, ra: usize) ?[*]u8 {
    _ = context;
    _ = ra;
    assert(n > 0);
    return map(n, alignment);
}

fn resize(
    context: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    return_address: usize,
) bool {
    _ = context;
    _ = alignment;
    _ = return_address;
    return realloc(memory, new_len, false) != null;
}

fn remap(
    context: *anyopaque,
    memory: []u8,
    alignment: mem.Alignment,
    new_len: usize,
    return_address: usize,
) ?[*]u8 {
    _ = context;
    _ = alignment;
    _ = return_address;
    return realloc(memory, new_len, true);
}

fn free(context: *anyopaque, memory: []u8, alignment: mem.Alignment, return_address: usize) void {
    _ = context;
    _ = alignment;
    _ = return_address;
    return unmap(@alignCast(memory));
}

pub fn unmap(memory: []align(page_size_min) u8) void {
    if (native_os == .windows) {
        windows.VirtualFree(memory.ptr, 0, windows.MEM_RELEASE);
    } else {
        const page_aligned_len = mem.alignForward(usize, memory.len, std.heap.pageSize());
        posix.munmap(memory.ptr[0..page_aligned_len]);
    }
}

pub fn realloc(uncasted_memory: []u8, new_len: usize, may_move: bool) ?[*]u8 {
    const memory: []align(page_size_min) u8 = @alignCast(uncasted_memory);
    const page_size = std.heap.pageSize();
    const new_size_aligned = mem.alignForward(usize, new_len, page_size);

    if (native_os == .windows) {
        if (new_len <= memory.len) {
            const base_addr = @intFromPtr(memory.ptr);
            const old_addr_end = base_addr + memory.len;
            const new_addr_end = mem.alignForward(usize, base_addr + new_len, page_size);
            if (old_addr_end > new_addr_end) {
                // For shrinking that is not releasing, we will only decommit
                // the pages not needed anymore.
                windows.VirtualFree(
                    @ptrFromInt(new_addr_end),
                    old_addr_end - new_addr_end,
                    windows.MEM_DECOMMIT,
                );
            }
            return memory.ptr;
        }
        const old_size_aligned = mem.alignForward(usize, memory.len, page_size);
        if (new_size_aligned <= old_size_aligned) {
            return memory.ptr;
        }
        return null;
    }

    const page_aligned_len = mem.alignForward(usize, memory.len, page_size);
    if (new_size_aligned == page_aligned_len)
        return memory.ptr;

    if (posix.MREMAP != void) {
        // TODO: if the next_mmap_addr_hint is within the remapped range, update it
        const new_memory = posix.mremap(memory.ptr, memory.len, new_len, .{ .MAYMOVE = may_move }, null) catch return null;
        return new_memory.ptr;
    }

    if (new_size_aligned < page_aligned_len) {
        const ptr = memory.ptr + new_size_aligned;
        // TODO: if the next_mmap_addr_hint is within the unmapped range, update it
        posix.munmap(@alignCast(ptr[0 .. page_aligned_len - new_size_aligned]));
        return memory.ptr;
    }

    return null;
}
