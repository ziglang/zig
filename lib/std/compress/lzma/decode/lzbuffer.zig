const std = @import("../../../std.zig");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;

/// An accumulating buffer for LZ sequences
pub const LzAccumBuffer = struct {
    /// Buffer
    buf: ArrayListUnmanaged(u8),

    /// Buffer memory limit
    memlimit: usize,

    /// Total number of bytes sent through the buffer
    len: usize,

    const Self = @This();

    pub fn init(memlimit: usize) Self {
        return Self{
            .buf = .{},
            .memlimit = memlimit,
            .len = 0,
        };
    }

    pub fn appendByte(self: *Self, allocator: Allocator, byte: u8) !void {
        try self.buf.append(allocator, byte);
        self.len += 1;
    }

    /// Reset the internal dictionary
    pub fn reset(self: *Self, writer: anytype) !void {
        try writer.writeAll(self.buf.items);
        self.buf.clearRetainingCapacity();
        self.len = 0;
    }

    /// Retrieve the last byte or return a default
    pub fn lastOr(self: Self, lit: u8) u8 {
        const buf_len = self.buf.items.len;
        return if (buf_len == 0)
            lit
        else
            self.buf.items[buf_len - 1];
    }

    /// Retrieve the n-th last byte
    pub fn lastN(self: Self, dist: usize) !u8 {
        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        return self.buf.items[buf_len - dist];
    }

    /// Append a literal
    pub fn appendLiteral(
        self: *Self,
        allocator: Allocator,
        lit: u8,
        writer: anytype,
    ) !void {
        _ = writer;
        if (self.len >= self.memlimit) {
            return error.CorruptInput;
        }
        try self.buf.append(allocator, lit);
        self.len += 1;
    }

    /// Fetch an LZ sequence (length, distance) from inside the buffer
    pub fn appendLz(
        self: *Self,
        allocator: Allocator,
        len: usize,
        dist: usize,
        writer: anytype,
    ) !void {
        _ = writer;

        const buf_len = self.buf.items.len;
        if (dist > buf_len) {
            return error.CorruptInput;
        }

        var offset = buf_len - dist;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const x = self.buf.items[offset];
            try self.buf.append(allocator, x);
            offset += 1;
        }
        self.len += len;
    }

    pub fn finish(self: *Self, writer: anytype) !void {
        try writer.writeAll(self.buf.items);
        self.buf.clearRetainingCapacity();
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.buf.deinit(allocator);
        self.* = undefined;
    }
};

/// A circular buffer for LZ sequences
pub const LzCircularBuffer = struct {
    /// Circular buffer
    buf: ArrayListUnmanaged(u8),

    /// Length of the buffer
    dict_size: usize,

    /// Buffer memory limit
    memlimit: usize,

    /// Current position
    cursor: usize,

    /// Total number of bytes sent through the buffer
    len: usize,

    const Self = @This();

    pub fn init(dict_size: usize, memlimit: usize) Self {
        return Self{
            .buf = .{},
            .dict_size = dict_size,
            .memlimit = memlimit,
            .cursor = 0,
            .len = 0,
        };
    }

    pub fn get(self: Self, index: usize) u8 {
        return if (0 <= index and index < self.buf.items.len)
            self.buf.items[index]
        else
            0;
    }

    pub fn set(self: *Self, allocator: Allocator, index: usize, value: u8) !void {
        if (index >= self.memlimit) {
            return error.CorruptInput;
        }
        try self.buf.ensureTotalCapacity(allocator, index + 1);
        while (self.buf.items.len < index) {
            self.buf.appendAssumeCapacity(0);
        }
        self.buf.appendAssumeCapacity(value);
    }

    /// Retrieve the last byte or return a default
    pub fn lastOr(self: Self, lit: u8) u8 {
        return if (self.len == 0)
            lit
        else
            self.get((self.dict_size + self.cursor - 1) % self.dict_size);
    }

    /// Retrieve the n-th last byte
    pub fn lastN(self: Self, dist: usize) !u8 {
        if (dist > self.dict_size or dist > self.len) {
            return error.CorruptInput;
        }

        const offset = (self.dict_size + self.cursor - dist) % self.dict_size;
        return self.get(offset);
    }

    /// Append a literal
    pub fn appendLiteral(
        self: *Self,
        allocator: Allocator,
        lit: u8,
        writer: anytype,
    ) !void {
        try self.set(allocator, self.cursor, lit);
        self.cursor += 1;
        self.len += 1;

        // Flush the circular buffer to the output
        if (self.cursor == self.dict_size) {
            try writer.writeAll(self.buf.items);
            self.cursor = 0;
        }
    }

    /// Fetch an LZ sequence (length, distance) from inside the buffer
    pub fn appendLz(
        self: *Self,
        allocator: Allocator,
        len: usize,
        dist: usize,
        writer: anytype,
    ) !void {
        if (dist > self.dict_size or dist > self.len) {
            return error.CorruptInput;
        }

        var offset = (self.dict_size + self.cursor - dist) % self.dict_size;
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const x = self.get(offset);
            try self.appendLiteral(allocator, x, writer);
            offset += 1;
            if (offset == self.dict_size) {
                offset = 0;
            }
        }
    }

    pub fn finish(self: *Self, writer: anytype) !void {
        if (self.cursor > 0) {
            try writer.writeAll(self.buf.items[0..self.cursor]);
            self.cursor = 0;
        }
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        self.buf.deinit(allocator);
        self.* = undefined;
    }
};
