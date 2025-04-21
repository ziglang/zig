const std = @import("../std.zig");
const Reader = @This();
const assert = std.debug.assert;
const BufferedWriter = std.io.BufferedWriter;

context: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Writes bytes from the internally tracked stream position to `bw`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and at
    /// most `limit`. The number of bytes read, including zero, does not
    /// indicate end of stream.
    ///
    /// If the reader has an internal seek position, it moves forward in
    /// accordance with the number of bytes return from this function.
    ///
    /// The implementation should do a maximum of one underlying read call.
    read: *const fn (context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) RwError!usize,

    /// Writes bytes from the internally tracked stream position to `data`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and
    /// at most the sum of each data slice length. The number of bytes read,
    /// including zero, does not indicate end of stream.
    ///
    /// If the reader has an internal seek position, it moves forward in
    /// accordance with the number of bytes return from this function.
    ///
    /// The implementation should do a maximum of one underlying read call.
    readVec: *const fn (context: ?*anyopaque, data: []const []u8) Error!usize,

    /// Consumes bytes from the internally tracked stream position without
    /// providing access to them.
    ///
    /// Returns the number of bytes discarded, which will be at minimum `0` and
    /// at most `limit`. The number of bytes returned, including zero, does not
    /// indicate end of stream.
    ///
    /// If the reader has an internal seek position, it moves forward in
    /// accordance with the number of bytes return from this function.
    ///
    /// The implementation should do a maximum of one underlying read call.
    discard: *const fn (context: ?*anyopaque, limit: Limit) Error!usize,
};

pub const RwError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// End of stream indicated from the `Reader`. This error cannot originate
    /// from the `Writer`.
    EndOfStream,
};

pub const Error = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    EndOfStream,
};

/// For functions that handle end of stream as a success case.
pub const RwAllError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

/// For functions that cannot fail with `error.EndOfStream`.
pub const ShortError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
};

pub const Limit = enum(usize) {
    nothing = 0,
    unlimited = std.math.maxInt(usize),
    _,

    /// `std.math.maxInt(usize)` is interpreted to mean `.unlimited`.
    pub fn limited(n: usize) Limit {
        return @enumFromInt(n);
    }

    pub fn min(a: Limit, b: Limit) Limit {
        return @enumFromInt(@min(@intFromEnum(a), @intFromEnum(b)));
    }

    pub fn minInt(l: Limit, n: usize) usize {
        return @min(n, @intFromEnum(l));
    }

    pub fn slice(l: Limit, s: []u8) []u8 {
        return s[0..l.minInt(s.len)];
    }

    pub fn toInt(l: Limit) ?usize {
        return switch (l) {
            else => @intFromEnum(l),
            .unlimited => null,
        };
    }

    /// Reduces a slice to account for the limit, leaving room for one extra
    /// byte above the limit, allowing for the use case of differentiating
    /// between end-of-stream and reaching the limit.
    pub fn slice1(l: Limit, non_empty_buffer: []u8) []u8 {
        assert(non_empty_buffer.len >= 1);
        return non_empty_buffer[0..@min(@intFromEnum(l) +| 1, non_empty_buffer.len)];
    }

    pub fn nonzero(l: Limit) bool {
        return @intFromEnum(l) > 0;
    }

    /// Return a new limit reduced by `amount` or return `null` indicating
    /// limit would be exceeded.
    pub fn subtract(l: Limit, amount: usize) ?Limit {
        if (l == .unlimited) return .unlimited;
        if (amount > @intFromEnum(l)) return null;
        return @enumFromInt(@intFromEnum(l) - amount);
    }
};

pub fn read(r: Reader, bw: *BufferedWriter, limit: Limit) RwError!usize {
    return r.vtable.read(r.context, bw, limit);
}

pub fn readVec(r: Reader, data: []const []u8) Error!usize {
    return r.vtable.readVec(r.context, data);
}

pub fn discard(r: Reader, limit: Limit) Error!usize {
    return r.vtable.discard(r.context, limit);
}

/// Returns total number of bytes written to `bw`.
pub fn readAll(r: Reader, bw: *BufferedWriter) RwAllError!usize {
    const readFn = r.vtable.read;
    var offset: usize = 0;
    while (true) {
        offset += readFn(r.context, bw, .unlimited) catch |err| switch (err) {
            error.EndOfStream => return offset,
            else => |e| return e,
        };
    }
}

/// Consumes the stream until the end, ignoring all the data, returning the
/// number of bytes discarded.
pub fn discardRemaining(r: Reader) ShortError!usize {
    const discardFn = r.vtable.discard;
    var offset: usize = 0;
    while (true) {
        offset += discardFn(r.context, .unlimited) catch |err| switch (err) {
            error.EndOfStream => return offset,
            else => |e| return e,
        };
    }
}

pub const ReadAllocError = std.mem.Allocator.Error || ShortError;

/// Allocates enough memory to hold all the contents of the stream. If the allocated
/// memory would be greater than `max_size`, returns `error.StreamTooLong`.
///
/// Caller owns returned memory.
///
/// If this function returns an error, the contents from the stream read so far are lost.
pub fn readAlloc(r: Reader, gpa: std.mem.Allocator, max_size: usize) ReadAllocError![]u8 {
    const readFn = r.vtable.read;
    var aw: std.io.AllocatingWriter = undefined;
    errdefer aw.deinit();
    aw.init(gpa);
    var remaining = max_size;
    while (remaining > 0) {
        const n = readFn(r.context, &aw.buffered_writer, .limited(remaining)) catch |err| switch (err) {
            error.WriteFailed => return error.OutOfMemory,
            error.EndOfStream => break,
            error.ReadFailed => return error.ReadFailed,
        };
        remaining -= n;
    }
    return aw.toOwnedSlice();
}

pub const failing: Reader = .{
    .context = undefined,
    .vtable = &.{
        .read = failingRead,
        .readVec = failingReadVec,
        .discard = failingDiscard,
    },
};

pub const ending: Reader = .{
    .context = undefined,
    .vtable = &.{
        .read = endingRead,
        .readVec = endingReadVec,
        .discard = endingDiscard,
    },
};

pub fn unbuffered(r: Reader) std.io.BufferedReader {
    return buffered(r, &.{});
}

pub fn buffered(r: Reader, buffer: []u8) std.io.BufferedReader {
    return .{
        .unbuffered_reader = r,
        .seek = 0,
        .buffer = buffer,
        .end = 0,
    };
}

fn endingRead(context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) RwError!usize {
    _ = context;
    _ = bw;
    _ = limit;
    return error.EndOfStream;
}

fn endingReadVec(context: ?*anyopaque, data: []const []u8) Error!usize {
    _ = context;
    _ = data;
    return error.EndOfStream;
}

fn endingDiscard(context: ?*anyopaque, limit: Limit) Error!usize {
    _ = context;
    _ = limit;
    return error.EndOfStream;
}

fn failingRead(context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) RwError!usize {
    _ = context;
    _ = bw;
    _ = limit;
    return error.ReadFailed;
}

fn failingReadVec(context: ?*anyopaque, data: []const []u8) Error!usize {
    _ = context;
    _ = data;
    return error.ReadFailed;
}

fn failingDiscard(context: ?*anyopaque, limit: Limit) Error!usize {
    _ = context;
    _ = limit;
    return error.ReadFailed;
}

test "readAlloc when the backing reader provides one byte at a time" {
    const OneByteReader = struct {
        str: []const u8,
        curr: usize,

        fn read(self: *@This(), dest: []u8) usize {
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
