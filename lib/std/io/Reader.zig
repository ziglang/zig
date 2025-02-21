const std = @import("../std.zig");
const Reader = @This();
const assert = std.debug.assert;

context: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Writes bytes starting from `offset` to `bw`, or returns
    /// `error.Unseekable`, indicating `streamRead` should be used instead.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and at
    /// most `limit`. The number of bytes read, including zero, does not
    /// indicate end of stream.
    ///
    /// If the reader has an internal seek position, it is not mutated.
    ///
    /// The implementation should do a maximum of one underlying read call.
    ///
    /// If this is `null` it is equivalent to always returning
    /// `error.Unseekable`.
    seekRead: ?*const fn (ctx: *anyopaque, bw: *std.io.BufferedWriter, limit: Limit, offset: u64) anyerror!Status,

    /// Writes bytes from the internally tracked stream position to `bw`, or
    /// returns `error.Unstreamable`, indicating `seekRead` should be used
    /// instead.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and at
    /// most `limit`. The number of bytes read, including zero, does not
    /// indicate end of stream.
    ///
    /// If the reader has an internal seek position, it moves forward in accordance
    /// with the number of bytes return from this function.
    ///
    /// The implementation should do a maximum of one underlying read call.
    ///
    /// If this is `null` it is equivalent to always returning
    /// `error.Unstreamable`.
    streamRead: ?*const fn (ctx: *anyopaque, bw: *std.io.BufferedWriter, limit: Limit) anyerror!Status,
};

pub const Len = @Type(.{ .signedness = .unsigned, .bits = @bitSizeOf(usize) - 1 });

pub const Status = packed struct(usize) {
    /// Number of bytes that were written to `writer`.
    len: Len,
    /// Indicates end of stream.
    end: bool,
};

pub const Limit = enum(usize) {
    none = std.math.maxInt(usize),
    _,
};

/// Returns total number of bytes written to `w`.
pub fn readAll(r: Reader, w: *std.io.BufferedWriter) anyerror!usize {
    if (r.vtable.pread != null) {
        return seekReadAll(r, w) catch |err| switch (err) {
            error.Unseekable => {},
            else => return err,
        };
    }
    return streamReadAll(r, w);
}

/// Returns total number of bytes written to `w`.
///
/// May return `error.Unseekable`, indicating this function cannot be used to
/// read from the reader.
pub fn seekReadAll(r: Reader, w: *std.io.BufferedWriter, start_offset: u64) anyerror!usize {
    const vtable_seekRead = r.vtable.seekRead.?;
    var offset: u64 = start_offset;
    while (true) {
        const status = try vtable_seekRead(r.context, w, .none, offset);
        offset += status.len;
        if (status.end) return @intCast(offset - start_offset);
    }
}

/// Returns total number of bytes written to `w`.
pub fn streamReadAll(r: Reader, w: *std.io.BufferedWriter) anyerror!usize {
    const vtable_streamRead = r.vtable.streamRead.?;
    var offset: usize = 0;
    while (true) {
        const status = try vtable_streamRead(r.context, w, .none);
        offset += status.len;
        if (status.end) return offset;
    }
}

/// Allocates enough memory to hold all the contents of the stream. If the allocated
/// memory would be greater than `max_size`, returns `error.StreamTooLong`.
///
/// Caller owns returned memory.
///
/// If this function returns an error, the contents from the stream read so far are lost.
pub fn streamReadAlloc(r: Reader, gpa: std.mem.Allocator, max_size: usize) anyerror![]u8 {
    const vtable_streamRead = r.vtable.streamRead.?;

    var bw: std.io.BufferedWriter = .{
        .buffer = .empty,
        .mode = .{ .allocator = gpa },
    };
    const list = &bw.buffer;
    defer list.deinit(gpa);

    var remaining = max_size;
    while (remaining > 0) {
        const status = try vtable_streamRead(r.context, &bw, .init(remaining));
        if (status.end) return list.toOwnedSlice(gpa);
        remaining -= status.len;
    }
}

/// Reads the stream until the end, ignoring all the data.
/// Returns the number of bytes discarded.
pub fn discardAll(r: Reader) anyerror!usize {
    var bw = std.io.null_writer.unbuffered();
    return streamReadAll(r, &bw);
}

pub fn buffered(r: Reader, buffer: []u8) std.io.BufferedReader {
    return .{
        .reader = r,
        .buffered_writer = .{
            .buffer = buffer,
            .mode = .fixed,
        },
    };
}

pub fn allocating(r: Reader, gpa: std.mem.Allocator) std.io.BufferedReader {
    return .{
        .reader = r,
        .buffered_writer = .{
            .buffer = .empty,
            .mode = .{ .allocator = gpa },
        },
    };
}

pub fn unbuffered(r: Reader) std.io.BufferedReader {
    return buffered(r, &.{});
}

test "when the backing reader provides one byte at a time" {
    const OneByteReader = struct {
        str: []const u8,
        curr: usize,

        fn read(self: *@This(), dest: []u8) anyerror!usize {
            if (self.str.len <= self.curr or dest.len == 0)
                return 0;

            dest[0] = self.str[self.curr];
            self.curr += 1;
            return 1;
        }

        fn reader(self: *@This()) std.io.Reader {
            return .{
                .context = self,
            };
        }
    };

    const str = "This is a test";
    var one_byte_stream: OneByteReader = .init(str);
    const res = try one_byte_stream.reader().streamReadAlloc(std.testing.allocator, str.len + 1);
    defer std.testing.allocator.free(res);
    try std.testing.expectEqualStrings(str, res);
}
