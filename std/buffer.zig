const std = @import("index.zig");
const debug = std.debug;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = debug.assert;
const ArrayList = std.ArrayList;

const fmt = std.fmt;

/// A buffer that allocates memory and maintains a null byte at the end.
pub const Buffer = struct {
    list: ArrayList(u8),

    /// Must deinitialize with deinit.
    pub fn init(allocator: *Allocator, m: []const u8) !Buffer {
        var self = try initSize(allocator, m.len);
        mem.copy(u8, self.list.items, m);
        return self;
    }

    /// Must deinitialize with deinit.
    pub fn initSize(allocator: *Allocator, size: usize) !Buffer {
        var self = initNull(allocator);
        try self.resize(size);
        return self;
    }

    /// Must deinitialize with deinit.
    /// None of the other operations are valid until you do one of these:
    /// * ::replaceContents
    /// * ::resize
    pub fn initNull(allocator: *Allocator) Buffer {
        return Buffer{ .list = ArrayList(u8).init(allocator) };
    }

    /// Must deinitialize with deinit.
    pub fn initFromBuffer(buffer: *const Buffer) !Buffer {
        return Buffer.init(buffer.list.allocator, buffer.toSliceConst());
    }

    /// Buffer takes ownership of the passed in slice. The slice must have been
    /// allocated with `allocator`.
    /// Must deinitialize with deinit.
    pub fn fromOwnedSlice(allocator: *Allocator, slice: []u8) !Buffer {
        var self = Buffer{ .list = ArrayList(u8).fromOwnedSlice(allocator, slice) };
        try self.list.append(0);
        return self;
    }

    /// The caller owns the returned memory. The Buffer becomes null and
    /// is safe to `deinit`.
    pub fn toOwnedSlice(self: *Buffer) []u8 {
        const allocator = self.list.allocator;
        const result = allocator.shrink(u8, self.list.items, self.len());
        self.* = initNull(allocator);
        return result;
    }

    pub fn deinit(self: *Buffer) void {
        self.list.deinit();
    }

    pub fn toSlice(self: *const Buffer) []u8 {
        return self.list.toSlice()[0..self.len()];
    }

    pub fn toSliceConst(self: *const Buffer) []const u8 {
        return self.list.toSliceConst()[0..self.len()];
    }

    pub fn shrink(self: *Buffer, new_len: usize) void {
        assert(new_len <= self.len());
        self.list.shrink(new_len + 1);
        self.list.items[self.len()] = 0;
    }

    pub fn resize(self: *Buffer, new_len: usize) !void {
        try self.list.resize(new_len + 1);
        self.list.items[self.len()] = 0;
    }

    pub fn isNull(self: *const Buffer) bool {
        return self.list.len == 0;
    }

    pub fn len(self: *const Buffer) usize {
        return self.list.len - 1;
    }

    pub fn append(self: *Buffer, m: []const u8) !void {
        const old_len = self.len();
        try self.resize(old_len + m.len);
        mem.copy(u8, self.list.toSlice()[old_len..], m);
    }

    pub fn appendByte(self: *Buffer, byte: u8) !void {
        const old_len = self.len();
        try self.resize(old_len + 1);
        self.list.toSlice()[old_len] = byte;
    }

    pub fn eql(self: *const Buffer, m: []const u8) bool {
        return mem.eql(u8, self.toSliceConst(), m);
    }

    pub fn startsWith(self: *const Buffer, m: []const u8) bool {
        if (self.len() < m.len) return false;
        return mem.eql(u8, self.list.items[0..m.len], m);
    }

    pub fn endsWith(self: *const Buffer, m: []const u8) bool {
        const l = self.len();
        if (l < m.len) return false;
        const start = l - m.len;
        return mem.eql(u8, self.list.items[start..l], m);
    }

    pub fn replaceContents(self: *Buffer, m: []const u8) !void {
        try self.resize(m.len);
        mem.copy(u8, self.list.toSlice(), m);
    }

    /// For passing to C functions.
    pub fn ptr(self: *const Buffer) [*]u8 {
        return self.list.items.ptr;
    }
};

test "simple Buffer" {
    const cstr = @import("cstr.zig");

    var buf = try Buffer.init(debug.global_allocator, "");
    assert(buf.len() == 0);
    try buf.append("hello");
    try buf.append(" ");
    try buf.append("world");
    assert(buf.eql("hello world"));
    assert(mem.eql(u8, cstr.toSliceConst(buf.toSliceConst().ptr), buf.toSliceConst()));

    var buf2 = try Buffer.initFromBuffer(&buf);
    assert(buf.eql(buf2.toSliceConst()));

    assert(buf.startsWith("hell"));
    assert(buf.endsWith("orld"));

    try buf2.resize(4);
    assert(buf.startsWith(buf2.toSlice()));
}
