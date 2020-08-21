// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const debug = std.debug;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = debug.assert;
const testing = std.testing;
const ArrayList = std.ArrayList;

/// A contiguous, growable list of items in memory, with a sentinel after them.
/// The sentinel is maintained when appending, resizing, etc.
/// If you do not need a sentinel, consider using `ArrayList` instead.
pub fn ArrayListSentineled(comptime T: type, comptime sentinel: T) type {
    return struct {
        list: ArrayList(T),

        const Self = @This();

        /// Must deinitialize with deinit.
        pub fn init(allocator: *Allocator, m: []const T) !Self {
            var self = try initSize(allocator, m.len);
            mem.copy(T, self.list.items, m);
            return self;
        }

        /// Initialize memory to size bytes of undefined values.
        /// Must deinitialize with deinit.
        pub fn initSize(allocator: *Allocator, size: usize) !Self {
            var self = initNull(allocator);
            try self.resize(size);
            return self;
        }

        /// Initialize with capacity to hold at least num bytes.
        /// Must deinitialize with deinit.
        pub fn initCapacity(allocator: *Allocator, num: usize) !Self {
            var self = Self{ .list = try ArrayList(T).initCapacity(allocator, num + 1) };
            self.list.appendAssumeCapacity(sentinel);
            return self;
        }

        /// Must deinitialize with deinit.
        /// None of the other operations are valid until you do one of these:
        /// * `replaceContents`
        /// * `resize`
        pub fn initNull(allocator: *Allocator) Self {
            return Self{ .list = ArrayList(T).init(allocator) };
        }

        /// Must deinitialize with deinit.
        pub fn initFromBuffer(buffer: Self) !Self {
            return Self.init(buffer.list.allocator, buffer.span());
        }

        /// Takes ownership of the passed in slice. The slice must have been
        /// allocated with `allocator`.
        /// Must deinitialize with deinit.
        pub fn fromOwnedSlice(allocator: *Allocator, slice: []T) !Self {
            var self = Self{ .list = ArrayList(T).fromOwnedSlice(allocator, slice) };
            try self.list.append(sentinel);
            return self;
        }

        /// The caller owns the returned memory. The list becomes null and is safe to `deinit`.
        pub fn toOwnedSlice(self: *Self) [:sentinel]T {
            const allocator = self.list.allocator;
            const result = self.list.toOwnedSlice();
            self.* = initNull(allocator);
            return result[0 .. result.len - 1 :sentinel];
        }

        /// Only works when `T` is `u8`.
        pub fn allocPrint(allocator: *Allocator, comptime format: []const u8, args: anytype) !Self {
            const size = std.math.cast(usize, std.fmt.count(format, args)) catch |err| switch (err) {
                error.Overflow => return error.OutOfMemory,
            };
            var self = try Self.initSize(allocator, size);
            assert((std.fmt.bufPrint(self.list.items, format, args) catch unreachable).len == size);
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit();
        }

        pub fn span(self: anytype) @TypeOf(self.list.items[0..:sentinel]) {
            return self.list.items[0..self.len() :sentinel];
        }

        pub fn shrink(self: *Self, new_len: usize) void {
            assert(new_len <= self.len());
            self.list.shrink(new_len + 1);
            self.list.items[self.len()] = sentinel;
        }

        pub fn resize(self: *Self, new_len: usize) !void {
            try self.list.resize(new_len + 1);
            self.list.items[self.len()] = sentinel;
        }

        pub fn isNull(self: Self) bool {
            return self.list.items.len == 0;
        }

        pub fn len(self: Self) usize {
            return self.list.items.len - 1;
        }

        pub fn capacity(self: Self) usize {
            return if (self.list.capacity > 0)
                self.list.capacity - 1
            else
                0;
        }

        pub fn appendSlice(self: *Self, m: []const T) !void {
            const old_len = self.len();
            try self.resize(old_len + m.len);
            mem.copy(T, self.list.items[old_len..], m);
        }

        pub fn append(self: *Self, byte: T) !void {
            const old_len = self.len();
            try self.resize(old_len + 1);
            self.list.items[old_len] = byte;
        }

        pub fn eql(self: Self, m: []const T) bool {
            return mem.eql(T, self.span(), m);
        }

        pub fn startsWith(self: Self, m: []const T) bool {
            if (self.len() < m.len) return false;
            return mem.eql(T, self.list.items[0..m.len], m);
        }

        pub fn endsWith(self: Self, m: []const T) bool {
            const l = self.len();
            if (l < m.len) return false;
            const start = l - m.len;
            return mem.eql(T, self.list.items[start..l], m);
        }

        pub fn replaceContents(self: *Self, m: []const T) !void {
            try self.resize(m.len);
            mem.copy(T, self.list.span(), m);
        }

        /// Initializes an OutStream which will append to the list.
        /// This function may be called only when `T` is `u8`.
        pub fn outStream(self: *Self) std.io.OutStream(*Self, error{OutOfMemory}, appendWrite) {
            return .{ .context = self };
        }

        /// Same as `append` except it returns the number of bytes written, which is always the same
        /// as `m.len`. The purpose of this function existing is to match `std.io.OutStream` API.
        /// This function may be called only when `T` is `u8`.
        pub fn appendWrite(self: *Self, m: []const u8) !usize {
            try self.appendSlice(m);
            return m.len;
        }
    };
}

test "simple" {
    var buf = try ArrayListSentineled(u8, 0).init(testing.allocator, "");
    defer buf.deinit();

    testing.expect(buf.len() == 0);
    try buf.appendSlice("hello");
    try buf.appendSlice(" ");
    try buf.appendSlice("world");
    testing.expect(buf.eql("hello world"));
    testing.expect(mem.eql(u8, mem.spanZ(buf.span().ptr), buf.span()));

    var buf2 = try ArrayListSentineled(u8, 0).initFromBuffer(buf);
    defer buf2.deinit();
    testing.expect(buf.eql(buf2.span()));

    testing.expect(buf.startsWith("hell"));
    testing.expect(buf.endsWith("orld"));

    try buf2.resize(4);
    testing.expect(buf.startsWith(buf2.span()));
}

test "initSize" {
    var buf = try ArrayListSentineled(u8, 0).initSize(testing.allocator, 3);
    defer buf.deinit();
    testing.expect(buf.len() == 3);
    try buf.appendSlice("hello");
    testing.expect(mem.eql(u8, buf.span()[3..], "hello"));
}

test "initCapacity" {
    var buf = try ArrayListSentineled(u8, 0).initCapacity(testing.allocator, 10);
    defer buf.deinit();
    testing.expect(buf.len() == 0);
    testing.expect(buf.capacity() >= 10);
    const old_cap = buf.capacity();
    try buf.appendSlice("hello");
    testing.expect(buf.len() == 5);
    testing.expect(buf.capacity() == old_cap);
    testing.expect(mem.eql(u8, buf.span(), "hello"));
}

test "print" {
    var buf = try ArrayListSentineled(u8, 0).init(testing.allocator, "");
    defer buf.deinit();

    try buf.outStream().print("Hello {} the {}", .{ 2, "world" });
    testing.expect(buf.eql("Hello 2 the world"));
}

test "outStream" {
    var buffer = try ArrayListSentineled(u8, 0).initSize(testing.allocator, 0);
    defer buffer.deinit();
    const buf_stream = buffer.outStream();

    const x: i32 = 42;
    const y: i32 = 1234;
    try buf_stream.print("x: {}\ny: {}\n", .{ x, y });

    testing.expect(mem.eql(u8, buffer.span(), "x: 42\ny: 1234\n"));
}
