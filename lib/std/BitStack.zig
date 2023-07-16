//! Effectively a stack of u1 values implemented using ArrayList(u8).

const BitStack = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

bytes: std.ArrayList(u8),
bit_len: u32 = 0,

pub fn init(allocator: Allocator) @This() {
    return .{
        .bytes = std.ArrayList(u8).init(allocator),
    };
}

pub fn deinit(self: *@This()) void {
    self.bytes.deinit();
    self.* = undefined;
}

pub fn ensureTotalCapacity(self: *@This(), bit_capcity: u32) Allocator.Error!void {
    const byte_capacity = (bit_capcity + 7) >> 3;
    try self.bytes.ensureTotalCapacity(byte_capacity);
}

pub fn push(self: *@This(), b: u1) Allocator.Error!void {
    const byte_index = self.bit_len >> 3;
    const bit_index = @as(u3, @intCast(self.bit_len & 7));

    if (self.bytes.items.len <= byte_index) {
        try self.bytes.append(0);
    }

    self.bytes.items[byte_index] &= ~(@as(u8, 1) << bit_index);
    self.bytes.items[byte_index] |= @as(u8, b) << bit_index;

    self.bit_len += 1;
}

pub fn peek(self: *const @This()) u1 {
    const byte_index = (self.bit_len - 1) >> 3;
    const bit_index = @as(u3, @intCast((self.bit_len - 1) & 7));
    return @as(u1, @intCast((self.bytes.items[byte_index] >> bit_index) & 1));
}

pub fn pop(self: *@This()) u1 {
    const b = self.peek();
    self.bit_len -= 1;
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
