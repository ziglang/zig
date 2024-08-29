/// Like `std.ArrayListUnmanaged(u8)` but backed by memory mapping.
const MemoryMappedList = @This();

const std = @import("std");
const assert = std.debug.assert;
const util = @import("util.zig");
const check = util.check;

/// Contents of the list.
///
/// Pointers to elements in this slice are invalidated by various functions
/// of this ArrayList in accordance with the respective documentation. In
/// all cases, "invalidated" means that the memory has been passed to this
/// allocator's resize or free function.
items: []align(std.mem.page_size) volatile u8,

/// How many bytes this list can hold without allocating additional memory.
capacity: usize,

pub fn init(file: std.fs.File, length: usize, capacity: usize) MemoryMappedList {
    const ptr = check(@src(), std.posix.mmap(
        null,
        capacity,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    ), .{});
    return .{
        .items = ptr[0..length],
        .capacity = capacity,
    };
}

/// Append the slice of items to the list.
/// Asserts that the list can hold the additional items.
pub fn appendSliceAssumeCapacity(l: *MemoryMappedList, items: []const u8) void {
    const old_len = l.items.len;
    const new_len = old_len + items.len;
    assert(new_len <= l.capacity);
    l.items.len = new_len;
    @memcpy(l.items[old_len..][0..items.len], items);
}

/// Append a value to the list `n` times.
/// Never invalidates element pointers.
/// The function is inline so that a comptime-known `value` parameter will
/// have better memset codegen in case it has a repeated byte pattern.
/// Asserts that the list can hold the additional items.
pub inline fn appendNTimesAssumeCapacity(l: *MemoryMappedList, value: u8, n: usize) void {
    const new_len = l.items.len + n;
    assert(new_len <= l.capacity);
    @memset(l.items.ptr[l.items.len..new_len], value);
    l.items.len = new_len;
}
