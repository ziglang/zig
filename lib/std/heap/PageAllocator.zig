const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const native_os = builtin.os.tag;
const windows = std.os.windows;
const ntdll = windows.ntdll;
const posix = std.posix;
const page_size_min = std.heap.page_size_min;

const SUCCESS = @import("../os/windows/ntstatus.zig").NTSTATUS.SUCCESS;
const MEM_RESERVE_PLACEHOLDER = windows.MEM_RESERVE_PLACEHOLDER;
const MEM_PRESERVE_PLACEHOLDER = windows.MEM_PRESERVE_PLACEHOLDER;

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
        if (alignment_bytes < page_size_min) {
            var base_addr: ?*anyopaque = null;
            var size: windows.SIZE_T = n;

            const status = ntdll.NtAllocateVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&base_addr), 0, &size, windows.MEM_COMMIT | windows.MEM_RESERVE, windows.PAGE_READWRITE);

            if (status == SUCCESS and mem.isAligned(@intFromPtr(base_addr), alignment_bytes)) {
                return @ptrCast(base_addr);
            }

            if (status == SUCCESS) {
                var region_size: windows.SIZE_T = 0;
                _ = ntdll.NtFreeVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&base_addr), &region_size, windows.MEM_RELEASE);
            }
        }

        const overalloc_len = n + alignment_bytes - page_size;
        const aligned_len = mem.alignForward(usize, n, page_size);

        var base_addr: ?*anyopaque = null;
        var size = overalloc_len;

        var status = ntdll.NtAllocateVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&base_addr), 0, &size, windows.MEM_RESERVE | MEM_RESERVE_PLACEHOLDER, windows.PAGE_NOACCESS);

        if (status != SUCCESS) return null;

        const placeholder_addr = @intFromPtr(base_addr);
        const aligned_addr = mem.alignForward(usize, placeholder_addr, alignment_bytes);
        const prefix_size = aligned_addr - placeholder_addr;

        if (prefix_size > 0) {
            var prefix_base = base_addr;
            var prefix_size_param: windows.SIZE_T = prefix_size;
            _ = ntdll.NtFreeVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&prefix_base), &prefix_size_param, windows.MEM_RELEASE | MEM_PRESERVE_PLACEHOLDER);
        }

        const suffix_start = aligned_addr + aligned_len;
        const suffix_size = (placeholder_addr + overalloc_len) - suffix_start;
        if (suffix_size > 0) {
            var suffix_base = @as(?*anyopaque, @ptrFromInt(suffix_start));
            var suffix_size_param: windows.SIZE_T = suffix_size;
            _ = ntdll.NtFreeVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&suffix_base), &suffix_size_param, windows.MEM_RELEASE | MEM_PRESERVE_PLACEHOLDER);
        }

        base_addr = @ptrFromInt(aligned_addr);
        size = aligned_len;

        status = ntdll.NtAllocateVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&base_addr), 0, &size, windows.MEM_COMMIT | MEM_PRESERVE_PLACEHOLDER, windows.PAGE_READWRITE);

        if (status == SUCCESS) {
            return @ptrCast(base_addr);
        }

        base_addr = @as(?*anyopaque, @ptrFromInt(aligned_addr));
        size = aligned_len;
        _ = ntdll.NtFreeVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&base_addr), &size, windows.MEM_RELEASE);

        return null;
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

fn resize(context: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, return_address: usize) bool {
    _ = context;
    _ = alignment;
    _ = return_address;
    return realloc(memory, new_len, false) != null;
}

fn remap(context: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
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
        var base_addr: ?*anyopaque = memory.ptr;
        var region_size: windows.SIZE_T = 0;
        _ = ntdll.NtFreeVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&base_addr), &region_size, windows.MEM_RELEASE);
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
                var decommit_addr: ?*anyopaque = @ptrFromInt(new_addr_end);
                var decommit_size: windows.SIZE_T = old_addr_end - new_addr_end;

                _ = ntdll.NtAllocateVirtualMemory(windows.GetCurrentProcess(), @ptrCast(&decommit_addr), 0, &decommit_size, windows.MEM_RESET, windows.PAGE_NOACCESS);
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
