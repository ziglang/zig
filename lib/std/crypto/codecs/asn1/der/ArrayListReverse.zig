//! An ArrayList that grows backwards. Counts nested prefix length fields
//! in O(n) instead of O(n^depth) at the cost of extra buffering.
//!
//! Laid out in memory like:
//! capacity  |--------------------------|
//! data                   |-------------|
data: []u8,
capacity: usize,
allocator: Allocator,

const ArrayListReverse = @This();
const Error = Allocator.Error;

pub fn init(allocator: Allocator) ArrayListReverse {
    return .{ .data = &.{}, .capacity = 0, .allocator = allocator };
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

pub const Writer = std.io.Writer(*ArrayListReverse, Error, prependSliceSize);
/// Warning: This writer writes backwards. `fn print` will NOT work as expected.
pub fn writer(self: *ArrayListReverse) Writer {
    return .{ .context = self };
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

/// The caller owns the returned memory.
/// Capacity is cleared, making deinit() safe but unnecessary to call.
pub fn toOwnedSlice(self: *ArrayListReverse) Error![]u8 {
    const new_memory = try self.allocator.alloc(u8, self.data.len);
    @memcpy(new_memory, self.data);
    @memset(self.data, undefined);
    self.clearAndFree();
    return new_memory;
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const testing = std.testing;

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
