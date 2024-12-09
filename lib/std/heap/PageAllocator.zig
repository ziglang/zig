const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;

/// TODO: utilize this on windows
pub var next_mmap_addr_hint = std.atomic.Value(?[*]align(mem.page_size) u8).init(null);

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

/// Whether `posix.mremap` may be used
const use_mremap = @hasDecl(posix.system, "REMAP") and posix.system.REMAP != void;

fn mmapAlloc(bytes: usize, hint: ?[*]align(mem.page_size) u8) ![]align(mem.page_size) u8 {
    return posix.mmap(
        hint,
        bytes,
        posix.PROT.READ | posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );
}

fn mapUnget(memory: []align(mem.page_size) u8) void {
    std.posix.munmap(memory);
}

fn alloc(_: *anyopaque, n: usize, log2_align: u8, ra: usize) ?[*]u8 {
    _ = ra;
    _ = log2_align;
    assert(n > 0);
    if (n > maxInt(usize) - (mem.page_size - 1)) return null;

    if (native_os == .windows) {
        const addr = windows.VirtualAlloc(
            null,

            // VirtualAlloc will round the length to a multiple of page size.
            // VirtualAlloc docs: If the lpAddress parameter is NULL, this value is rounded up to the next page boundary
            n,

            windows.MEM_COMMIT | windows.MEM_RESERVE,
            windows.PAGE_READWRITE,
        ) catch return null;
        return @ptrCast(addr);
    }

    const aligned_len = mem.alignForward(usize, n, mem.page_size);
    const hint = next_mmap_addr_hint.load(.unordered);

    const slice = posix.mmap(
        hint,
        aligned_len,
        posix.PROT.READ | posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    ) catch {
        _ = next_mmap_addr_hint.cmpxchgStrong(hint, null, .monotonic, .monotonic);
        return null;
    };

    assert(mem.isAligned(@intFromPtr(slice.ptr), mem.page_size));
    const new_hint: [*]align(mem.page_size) u8 = @alignCast(slice.ptr + aligned_len);
    _ = next_mmap_addr_hint.cmpxchgStrong(hint, new_hint, .monotonic, .monotonic);

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
    const old_size_aligned = mem.alignForward(usize, buf_unaligned.len, mem.page_size);

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
        return new_size_aligned <= old_size_aligned;
    }

    const buf: []align(mem.page_size) u8 = @alignCast(buf_unaligned.ptr[0..old_size_aligned]);
    const result = switch (std.math.order(old_size_aligned, new_size_aligned)) {
        .lt => grow: {
            if (use_mremap) {
                const slice = posix.mremap(
                    buf.ptr[0..old_size_aligned],
                    new_size_aligned,
                    false,
                ) catch break :grow false;
                assert(slice.ptr == buf.ptr);
                break :grow true;
            } else {
                break :grow false;
            }
        },
        .eq => return true, // return now and don't set the hint
        .gt => shrink: {
            posix.munmap(@alignCast(buf.ptr[new_size_aligned..old_size_aligned]));
            break :shrink true;
        },
    };
    if (result) {
        const old_end: [*]align(mem.page_size) u8 = @alignCast(buf.ptr + old_size_aligned);
        const new_end: [*]align(mem.page_size) u8 = @alignCast(buf.ptr + new_size_aligned);
        _ = next_mmap_addr_hint.cmpxchgStrong(old_end, new_end, .monotonic, .monotonic);
    }
    return result;
}

fn free(_: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    _ = log2_buf_align;
    _ = return_address;

    if (native_os == .windows) {
        windows.VirtualFree(slice.ptr, 0, windows.MEM_RELEASE);
    } else {
        const buf_aligned_len = mem.alignForward(usize, slice.len, mem.page_size);
        const head: []align(mem.page_size) u8 = @alignCast(slice.ptr[0..buf_aligned_len]);
        posix.munmap(head);
        const tail: [*]align(mem.page_size) u8 = @alignCast(head.ptr + head.len);
        _ = next_mmap_addr_hint.cmpxchgStrong(tail, head.ptr, .monotonic, .monotonic);
    }
}
