//! Effectively a stack of u1 values implemented using ArrayList(u8).

const BitStack = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

bytes: std.ArrayList(u8),
bit_len: usize = 0,

pub fn init(allocator: Allocator) @This() {
    return .{
        .bytes = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.bytes.deinit();
    self.* = undefined;
}

pub fn ensureTotalCapacity(self: *@This(), bit_capacity: usize) Allocator.Error!void {
    const byte_capacity = (bit_capacity + 7) >> 3;
    try self.bytes.ensureTotalCapacity(byte_capacity);
}

pub fn push(self: *@This(), b: u1) Allocator.Error!void {
    const byte_index = self.bit_len >> 3;
    if (self.bytes.items.len <= byte_index) {
        try self.bytes.append(0);
    }

    pushWithStateAssumeCapacity(self.bytes.items, &self.bit_len, b);
}

pub fn peek(self: *const @This()) u1 {
    return peekWithState(self.bytes.items, self.bit_len);
}

pub fn pop(self: *@This()) u1 {
    return popWithState(self.bytes.items, &self.bit_len);
}

/// Standalone function for working with a fixed-size buffer.
pub fn pushWithStateAssumeCapacity(buf: []u8, bit_len: *usize, b: u1) void {
    const byte_index = bit_len.* >> 3;
    const bit_index = @as(u3, @intCast(bit_len.* & 7));

    buf[byte_index] &= ~(@as(u8, 1) << bit_index);
    buf[byte_index] |= @as(u8, b) << bit_index;

    bit_len.* += 1;
}

/// Standalone function for working with a fixed-size buffer.
pub fn peekWithState(buf: []const u8, bit_len: usize) u1 {
    const byte_index = (bit_len - 1) >> 3;
    const bit_index = @as(u3, @intCast((bit_len - 1) & 7));
    return @as(u1, @intCast((buf[byte_index] >> bit_index) & 1));
}

/// Standalone function for working with a fixed-size buffer.
pub fn popWithState(buf: []const u8, bit_len: *usize) u1 {
    const b = peekWithState(buf, bit_len.*);
    bit_len.* -= 1;
    return b;
}

const testing = std.testing;
test BitStack {
    var stack = BitStack.init(testing.allocator);
    defer stack.deinit();

    try stack.push(1);
    try stack.push(0);
    try stack.push(0);
    try stack.push(1);

    try testing.expectEqual(@as(u1, 1), stack.peek());
    try testing.expectEqual(@as(u1, 1), stack.pop());
    try testing.expectEqual(@as(u1, 0), stack.peek());
    try testing.expectEqual(@as(u1, 0), stack.pop());
    try testing.expectEqual(@as(u1, 0), stack.pop());
    try testing.expectEqual(@as(u1, 1), stack.pop());
}
