const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const os = std.os;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

fn alloc(_: *anyopaque, n: usize, log2_align: u8, ra: usize) ?[*]u8 {
    _ = ra;
    _ = log2_align;
    assert(n > 0);
    if (n > maxInt(usize) - (mem.page_size - 1)) return null;
    const aligned_len = mem.alignForward(usize, n, mem.page_size);

    if (builtin.os.tag == .windows) {
        const w = os.windows;
        const addr = w.VirtualAlloc(
            null,
            aligned_len,
            w.MEM_COMMIT | w.MEM_RESERVE,
            w.PAGE_READWRITE,
        ) catch return null;
        return @ptrCast(addr);
    }

    const hint = @atomicLoad(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, .Unordered);
    const slice = os.mmap(
        hint,
        aligned_len,
        os.PROT.READ | os.PROT.WRITE,
        os.MAP.PRIVATE | os.MAP.ANONYMOUS,
        -1,
        0,
    ) catch return null;
    assert(mem.isAligned(@intFromPtr(slice.ptr), mem.page_size));
    const new_hint: [*]align(mem.page_size) u8 = @alignCast(slice.ptr + aligned_len);
    _ = @cmpxchgStrong(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, hint, new_hint, .Monotonic, .Monotonic);
    return slice.ptr;
}

fn resize(
    _: *anyopaque,
    buf_unaligned: []u8,
    log2_buf_align: u8,
    new_size: usize,
    return_address: usize,
) bool {
    _ = log2_buf_align;
    _ = return_address;
    const new_size_aligned = mem.alignForward(usize, new_size, mem.page_size);

    if (builtin.os.tag == .windows) {
        const w = os.windows;
        if (new_size <= buf_unaligned.len) {
            const base_addr = @intFromPtr(buf_unaligned.ptr);
            const old_addr_end = base_addr + buf_unaligned.len;
            const new_addr_end = mem.alignForward(usize, base_addr + new_size, mem.page_size);
            if (old_addr_end > new_addr_end) {
                // For shrinking that is not releasing, we will only
                // decommit the pages not needed anymore.
                w.VirtualFree(
                    @as(*anyopaque, @ptrFromInt(new_addr_end)),
                    old_addr_end - new_addr_end,
                    w.MEM_DECOMMIT,
                );
            }
            return true;
        }
        const old_size_aligned = mem.alignForward(usize, buf_unaligned.len, mem.page_size);
        if (new_size_aligned <= old_size_aligned) {
            return true;
        }
        return false;
    }

    const buf_aligned_len = mem.alignForward(usize, buf_unaligned.len, mem.page_size);
    if (new_size_aligned == buf_aligned_len)
        return true;

    if (new_size_aligned < buf_aligned_len) {
        const ptr = buf_unaligned.ptr + new_size_aligned;
        // TODO: if the next_mmap_addr_hint is within the unmapped range, update it
        os.munmap(@alignCast(ptr[0 .. buf_aligned_len - new_size_aligned]));
        return true;
    }

    // TODO: call mremap
    // TODO: if the next_mmap_addr_hint is within the remapped range, update it
    return false;
}

fn free(_: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    _ = log2_buf_align;
    _ = return_address;

    if (builtin.os.tag == .windows) {
        os.windows.VirtualFree(slice.ptr, 0, os.windows.MEM_RELEASE);
    } else {
        const buf_aligned_len = mem.alignForward(usize, slice.len, mem.page_size);
        os.munmap(@alignCast(slice.ptr[0..buf_aligned_len]));
    }
}
