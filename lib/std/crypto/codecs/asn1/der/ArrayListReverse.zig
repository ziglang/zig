//! An ArrayList that grows backwards. Counts nested prefix length fields
//! in O(n) instead of O(n^depth) at the cost of extra buffering.
//!
//! Laid out in memory like:
//! capacity  |--------------------------|
//! data                   |-------------|

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const assert = std.debug.assert;
const testing = std.testing;

data: []u8,
capacity: usize,
allocator: Allocator,
writer: Io.Writer,

const ArrayListReverse = @This();
const Error = Allocator.Error;

pub fn init(allocator: Allocator) ArrayListReverse {
    return .{
        .data = &.{},
        .capacity = 0,
        .allocator = allocator,
        .writer = .{
            .buffer = &.{},
            .vtable = &vtable,
        },
    };
}

pub fn deinit(self: *ArrayListReverse) void {
    self.allocator.free(self.allocatedSlice());
}

pub fn ensureCapacity(self: *ArrayListReverse, new_capacity: usize) Error!void {
    if (self.capacity >= new_capacity) return;

    const old_memory = self.allocatedSlice();
    // Just make a new allocation to not worry about aliasing.
    const new_memory = try self.allocator.alloc(u8, new_capacity);
    @memcpy(new_memory[new_capacity - self.data.len ..], self.data);
    self.allocator.free(old_memory);
    self.data.ptr = new_memory.ptr + new_capacity - self.data.len;
    self.capacity = new_memory.len;
}

pub fn prependSlice(self: *ArrayListReverse, data: []const u8) Error!void {
    try self.ensureCapacity(self.data.len + data.len);
    const old_len = self.data.len;
    const new_len = old_len + data.len;
    assert(new_len <= self.capacity);
    self.data.len = new_len;

    const end = self.data.ptr;
    const begin = end - data.len;
    const slice = begin[0..data.len];
    @memcpy(slice, data);
    self.data.ptr = begin;
}

fn prependSliceSize(self: *ArrayListReverse, data: []const u8) Error!usize {
    try self.prependSlice(data);
    return data.len;
}

fn allocatedSlice(self: *ArrayListReverse) []u8 {
    return (self.data.ptr + self.data.len - self.capacity)[0..self.capacity];
}

/// Invalidates all element pointers.
pub fn clearAndFree(self: *ArrayListReverse) void {
    self.allocator.free(self.allocatedSlice());
    self.data.len = 0;
    self.capacity = 0;
}

const vtable: Io.Writer.VTable = .{
    .drain = &drain,
};

fn drain(w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
    const self: *ArrayListReverse = @fieldParentPtr("writer", w);

    assert(w.buffered().len == 0);

    if (data.len == 1 and splat == 1) {
        @branchHint(.likely);
        self.prependSlice(data[0]) catch return error.WriteFailed;
        return data[0].len;
    }

    const count = Io.Writer.countSplat(data, splat);
    self.ensureCapacity(self.data.len + count) catch return error.WriteFailed;
    const end = self.data.ptr;
    const begin = end - count;
    var slice = begin[0..count];

    for (data[0 .. data.len - 1]) |bytes| {
        @memcpy(slice[0..bytes.len], bytes);
        slice = slice[bytes.len..];
    }
    for (0..splat) |_| {
        const bytes = data[data.len - 1];
        @memcpy(slice[0..bytes.len], bytes);
        slice = slice[bytes.len..];
    }

    self.data.ptr = begin;
    self.data.len += count;
    return count;
}

test drain {
    var b: ArrayListReverse = .init(std.testing.allocator);
    defer b.deinit();

    var n = try b.writer.write(&.{ 1, 2, 3 });
    try std.testing.expectEqual(3, n);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, b.data);

    n = try b.writer.writeSplat(&.{
        &.{ 4, 5, 6 },
        &.{ 7, 8, 9 },
    }, 2);
    try std.testing.expectEqual(9, n);
    try std.testing.expectEqualSlices(
        u8,
        &.{
            4, 5, 6,
            7, 8, 9,
            7, 8, 9,
            1, 2, 3,
        },
        b.data,
    );
}

/// The caller owns the returned memory.
/// Capacity is cleared, making deinit() safe but unnecessary to call.
pub fn toOwnedSlice(self: *ArrayListReverse) Error![]u8 {
    const new_memory = try self.allocator.alloc(u8, self.data.len);
    @memcpy(new_memory, self.data);
    @memset(self.data, undefined);
    self.clearAndFree();
    return new_memory;
}

test ArrayListReverse {
    var b = ArrayListReverse.init(testing.allocator);
    defer b.deinit();
    const data: []const u8 = &.{ 4, 5, 6 };
    try b.prependSlice(data);
    try testing.expectEqual(data.len, b.data.len);
    try testing.expectEqualSlices(u8, data, b.data);

    const data2: []const u8 = &.{ 1, 2, 3 };
    try b.prependSlice(data2);
    try testing.expectEqual(data.len + data2.len, b.data.len);
    try testing.expectEqualSlices(u8, data2 ++ data, b.data);
}
