const std = @import("../std.zig");
const io = std.io;
const testing = std.testing;
const mem = std.mem;
const assert = std.debug.assert;

/// This turns a byte buffer into an `io.Writer`, `io.Reader`, or `io.Seeker`.
/// If the supplied byte buffer is const, then `io.Writer` is not available.
pub fn FixedBufferStream(comptime Buffer: type) type {
    return struct {
        /// `Buffer` is either a `[]u8` or `[]const u8`.
        buffer: Buffer,
        pos: usize,

        pub const ReadError = error{};
        pub const WriteError = error{NoSpaceLeft};
        pub const SeekError = error{OperationNotSupported};

        pub const Reader = io.Reader(*Self, ReadError, read);
        pub const Writer = io.Writer(*Self, WriteError, write);
        pub const Seeker = io.Seeker(*Self, SeekError, seek);

        const Self = @This();

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn read(self: *Self, dest: []u8) ReadError!usize {
            const size = @min(dest.len, self.buffer.len - self.pos);
            const end = self.pos + size;

            @memcpy(dest[0..size], self.buffer[self.pos..end]);
            self.pos = end;

            return size;
        }

        /// If the returned number of bytes written is less than requested, the
        /// buffer is full. Returns `error.NoSpaceLeft` when no bytes would be written.
        /// Note: `error.NoSpaceLeft` matches the corresponding error from
        /// `std.fs.File.WriteError`.
        pub fn write(self: *Self, bytes: []const u8) WriteError!usize {
            if (bytes.len == 0) return 0;
            if (self.pos >= self.buffer.len) return error.NoSpaceLeft;

            const n = if (self.pos + bytes.len <= self.buffer.len)
                bytes.len
            else
                self.buffer.len - self.pos;

            @memcpy(self.buffer[self.pos..][0..n], bytes[0..n]);
            self.pos += n;

            if (n == 0) return error.NoSpaceLeft;

            return n;
        }

        pub fn seek(self: *Self, whence: io.Whence) SeekError!u64 {
            switch (whence) {
                .start => |offset| {
                    self.pos = @intCast(@min(self.buffer.len, offset));
                },
                .current, .end => |offset| {
                    var base: u64 = @intCast(if (whence == .end) self.buffer.len else self.pos);
                    var newpos: i64 = @as(i64, @intCast(base)) + offset;
                    if (newpos < 0) {
                        self.pos = 0;
                    } else {
                        self.pos = @intCast(@min(@as(u64, @intCast(newpos)), self.buffer.len));
                    }
                },
                .get_end_pos => {
                    return @intCast(self.buffer.len);
                },
                .set_end_pos => return error.OperationNotSupported,
            }
            return @intCast(self.pos);
        }

        pub fn seeker(self: *Self) Seeker {
            return .{ .context = self };
        }

        // Deprecations
        pub const seekableStream = @compileError("Deprecated; use seeker() instead.");
        pub const seekTo = @compileError("Deprecated; use seeker().seekTo instead.");
        pub const seekBy = @compileError("Deprecated; use seeker().seekBy instead.");
        pub const getEndPos = @compileError("Deprecated; use seeker().getEndPos instead.");
        pub const getPos = @compileError("Deprecated; use seeker().getPos instead.");

        pub fn getWritten(self: Self) Buffer {
            return self.buffer[0..self.pos];
        }

        pub fn reset(self: *Self) void {
            self.pos = 0;
        }
    };
}

pub fn fixedBufferStream(buffer: anytype) FixedBufferStream(Slice(@TypeOf(buffer))) {
    return .{ .buffer = buffer, .pos = 0 };
}

fn Slice(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => |ptr_info| {
            var new_ptr_info = ptr_info;
            switch (ptr_info.size) {
                .Slice => {},
                .One => switch (@typeInfo(ptr_info.child)) {
                    .Array => |info| new_ptr_info.child = info.child,
                    else => @compileError("invalid type given to fixedBufferStream"),
                },
                else => @compileError("invalid type given to fixedBufferStream"),
            }
            new_ptr_info.size = .Slice;
            return @Type(.{ .Pointer = new_ptr_info });
        },
        else => @compileError("invalid type given to fixedBufferStream"),
    }
}

test "FixedBufferStream output" {
    var buf: [255]u8 = undefined;
    var fbs = fixedBufferStream(&buf);
    const stream = fbs.writer();

    try stream.print("{s}{s}!", .{ "Hello", "World" });
    try testing.expectEqualSlices(u8, "HelloWorld!", fbs.getWritten());
}

test "FixedBufferStream output at comptime" {
    comptime {
        var buf: [255]u8 = undefined;
        var fbs = fixedBufferStream(&buf);
        const stream = fbs.writer();

        try stream.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualSlices(u8, "HelloWorld!", fbs.getWritten());
    }
}

test "FixedBufferStream output 2" {
    var buffer: [10]u8 = undefined;
    var fbs = fixedBufferStream(&buffer);

    try fbs.writer().writeAll("Hello");
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Hello"));

    try fbs.writer().writeAll("world");
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    try testing.expectError(error.NoSpaceLeft, fbs.writer().writeAll("!"));
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Helloworld"));

    try fbs.seeker().rewind();
    try testing.expect(fbs.getWritten().len == 0);

    try testing.expectError(error.NoSpaceLeft, fbs.writer().writeAll("Hello world!"));
    try testing.expect(mem.eql(u8, fbs.getWritten(), "Hello worl"));

    var seeker = fbs.seeker();
    try seeker.seekTo((try seeker.getEndPos()) + 1);
    try testing.expectError(error.NoSpaceLeft, fbs.writer().writeAll("H"));
}

test "FixedBufferStream input" {
    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6, 7 };
    var fbs = fixedBufferStream(&bytes);

    var dest: [4]u8 = undefined;

    var read = try fbs.reader().read(&dest);
    try testing.expect(read == 4);
    try testing.expect(mem.eql(u8, dest[0..4], bytes[0..4]));

    read = try fbs.reader().read(&dest);
    try testing.expect(read == 3);
    try testing.expect(mem.eql(u8, dest[0..3], bytes[4..7]));

    read = try fbs.reader().read(&dest);
    try testing.expect(read == 0);

    var seeker = fbs.seeker();
    try seeker.seekTo((try seeker.getEndPos()) + 1);
    read = try fbs.reader().read(&dest);
    try testing.expect(read == 0);
}
