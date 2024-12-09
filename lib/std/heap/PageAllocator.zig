const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const native_os = builtin.os.tag;
const windows = std.os.windows;
const posix = std.posix;

pub var next_mmap_addr_hint = std.atomic.Value(?[*]align(mem.page_size) u8).init(null);

pub const vtable = Allocator.VTable{
    .alloc = alloc,
    .resize = resize,
    .free = free,
};

/// Whether `posix.mremap` may be used
const use_mremap = @hasDecl(posix.system, "REMAP") and posix.system.REMAP != void;

/// Whether an invalid `next_mmap_addr_hint` will cause `mapGet` to fail
const invalid_hint_fails = switch (native_os) {
    .windows => true,
    else => false,
};

/// Allocated pages of memory. The size of the allocation is rounded up to the page.
/// `hint` is a hint for where the allocation should be mapped to.
/// If `invalid_hint_fails`, then this function fails when an allocation cannot be made exactly at `hint`.
/// Otherwise, this function may return an address other than `hint`.
fn mapGet(bytes: usize, hint: ?[*]align(mem.page_size) u8) ![*]align(mem.page_size) u8 {
    return switch (native_os) {
        .windows => @ptrCast(@alignCast(try windows.VirtualAlloc(
            @ptrCast(hint),
            bytes,
            windows.MEM_COMMIT | windows.MEM_RESERVE,
            windows.PAGE_READWRITE,
        ))),
        else => (try posix.mmap(
            hint,
            bytes,
            posix.PROT.READ | posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        )).ptr,
    };
}

/// Unmaps allocated memory. The size of the allocation is rounded up to the page.
/// Using `free` frees the allocation entirely,
/// while using `shrink` may simply decommit memory for later use.
fn mapFree(memory: []align(mem.page_size) u8, kind: enum { free, shrink }) void {
    switch (native_os) {
        .windows => windows.VirtualFree(
            @ptrCast(memory.ptr),
            memory.len,
            switch (kind) {
                .free => windows.MEM_RELEASE,
                .shrink => windows.MEM_DECOMMIT,
            },
        ),
        else => posix.munmap(memory),
    }
}

/// Attempts to shrink memory acquired for `mapGet` to `new_size` bytes.
/// Returns true of success, and false on failure.
fn mapShrink(memory: []align(mem.page_size) u8, new_size: usize) bool {
    const new_size_aligned = mem.alignForward(usize, new_size, mem.page_size);
    const old_size_aligned = mem.alignForward(usize, memory.len, mem.page_size);

    assert(new_size_aligned < old_size_aligned);

    mapFree(@alignCast(memory.ptr[new_size_aligned..old_size_aligned]), .shrink);
    return true;
}

/// Attempts to grow memory acquired for `mapGet` to `new_size` bytes.
/// Returns true of success, and false on failure.
fn mapGrow(memory: []align(mem.page_size) u8, new_size: usize) bool {
    assert(new_size > memory.len);

    const new_size_aligned = mem.alignForward(usize, new_size, mem.page_size);
    const old_size_aligned = mem.alignForward(usize, memory.len, mem.page_size);

    assert(new_size_aligned > old_size_aligned);

    if (use_mremap) {
        const slice = posix.mremap(
            memory.ptr[0..old_size_aligned],
            new_size_aligned,
            false,
        ) catch return false;
        assert(slice.ptr == memory.ptr);
        return true;
    } else {
        return false;
    }
}

fn alloc(_: *anyopaque, n: usize, log2_align: u8, ra: usize) ?[*]u8 {
    _ = ra;
    _ = log2_align;
    assert(n > 0);
    if (n > maxInt(usize) - (mem.page_size - 1)) return null;

    const aligned_len = mem.alignForward(usize, n, mem.page_size);
    const hint = next_mmap_addr_hint.load(.unordered);
    const head = mapGet(aligned_len, hint) catch blk: {
        if (invalid_hint_fails and next_mmap_addr_hint.rmw(.Xchg, null, .monotonic) != null) {
            // for systems where an invalid hint causes allocation failure,
            // if we encounter an error, first attempt to retry without a hint
            break :blk mapGet(aligned_len, null) catch return null;
        } else {
            return null;
        }
    };
    assert(mem.isAligned(@intFromPtr(head), mem.page_size));
    _ = next_mmap_addr_hint.cmpxchgStrong(hint, @alignCast(head + aligned_len), .monotonic, .monotonic);
    return head;
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
    const buf: []align(mem.page_size) u8 = @alignCast(buf_unaligned.ptr[0..old_size_aligned]);
    const ordering = std.math.order(old_size_aligned, new_size_aligned);
    const result = switch (ordering) {
        .lt => mapGrow(buf, new_size_aligned),
        .eq => true,
        .gt => mapShrink(buf, new_size_aligned),
    };
    if (result and ordering != .eq) {
        const old_end: [*]align(mem.page_size) u8 = @alignCast(buf.ptr + old_size_aligned);
        const new_end: [*]align(mem.page_size) u8 = @alignCast(buf.ptr + new_size_aligned);
        _ = next_mmap_addr_hint.cmpxchgStrong(old_end, new_end, .monotonic, .monotonic);
    }
    return result;
}

fn free(_: *anyopaque, slice: []u8, log2_buf_align: u8, return_address: usize) void {
    _ = log2_buf_align;
    _ = return_address;

    const aligned_len = mem.alignForward(usize, slice.len, mem.page_size);
    const head: []align(mem.page_size) u8 = @alignCast(slice.ptr[0..aligned_len]);
    mapFree(head, .free);
    const tail: [*]align(mem.page_size) u8 = @alignCast(head.ptr + head.len);
    _ = next_mmap_addr_hint.cmpxchgStrong(tail, head.ptr, .monotonic, .monotonic);
}
