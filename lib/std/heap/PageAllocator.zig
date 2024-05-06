const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;

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

    if (native_os == .windows) {
        const addr = windows.VirtualAlloc(
            null,
            aligned_len,
            windows.MEM_COMMIT | windows.MEM_RESERVE,
            windows.PAGE_READWRITE,
        ) catch return null;
        return @ptrCast(addr);
    }

    const hint = @atomicLoad(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, .unordered);
    const slice = posix.mmap(
        hint,
        aligned_len,
        posix.PROT.READ | posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    ) catch return null;
    assert(mem.isAligned(@intFromPtr(slice.ptr), mem.page_size));
    const new_hint: [*]align(mem.page_size) u8 = @alignCast(slice.ptr + aligned_len);
    _ = @cmpxchgStrong(@TypeOf(std.heap.next_mmap_addr_hint), &std.heap.next_mmap_addr_hint, hint, new_hint, .monotonic, .monotonic);
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

    if (native_os == .windows) {
        if (new_size <= buf_unaligned.len) {
            const base_addr = @intFromPtr(buf_unaligned.ptr);
            const old_addr_end = base_addr + buf_unaligned.len;
            const new_addr_end = mem.alignForward(usize, base_addr + new_size, mem.page_size);
            if (old_addr_end > new_addr_end) {
                // For shrinking that is not releasing, we will only
                // decommit the pages not needed anymore.
                windows.VirtualFree(
                    @as(*anyopaque, @ptrFromInt(new_addr_end)),
                    old_addr_end - new_addr_end,
                    windows.MEM_DECOMMIT,
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
        posix.munmap(@alignCast(ptr[0 .. buf_aligned_len - new_size_aligned]));
        return true;
    }

    // TODO: call mremap
    // TODO: if the next_mmap_addr_hint is within the remapped range, update it
    return false;
}

fn free(_: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    _ = log2_buf_align;
    _ = return_address;

    if (native_os == .windows) {
        windows.VirtualFree(slice.ptr, 0, windows.MEM_RELEASE);
    } else {
        const buf_aligned_len = mem.alignForward(usize, slice.len, mem.page_size);
        posix.munmap(@alignCast(slice.ptr[0..buf_aligned_len]));
    }
}
