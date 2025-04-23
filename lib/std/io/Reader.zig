const std = @import("../std.zig");
const Reader = @This();
const assert = std.debug.assert;
const BufferedWriter = std.io.BufferedWriter;
const BufferedReader = std.io.BufferedReader;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;

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
    const n = try r.vtable.read(r.context, bw, limit);
    assert(n <= @intFromEnum(limit));
    return n;
}

pub fn readVec(r: Reader, data: []const []u8) Error!usize {
    return r.vtable.readVec(r.context, data);
}

pub fn discard(r: Reader, limit: Limit) Error!usize {
    const n = try r.vtable.discard(r.context, limit);
    assert(n <= @intFromEnum(limit));
    return n;
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

pub const LimitedAllocError = Allocator.Error || ShortError || error{StreamTooLong};

/// Transfers all bytes from the current position to the end of the stream, up
/// to `limit`, returning them as a caller-owned allocated slice.
///
/// If `limit` is exceeded, returns `error.StreamTooLong`. In such case, the
/// stream is advanced one byte beyond the limit, and the consumed data is
/// unrecoverable. Other functions listed below do not have this caveat.
///
/// See also:
/// * `readRemainingArrayList`
/// * `BufferedReader.readRemainingArrayList`
pub fn readRemainingAlloc(r: Reader, gpa: Allocator, limit: Reader.Limit) LimitedAllocError![]u8 {
    var buffer: ArrayList(u8) = .empty;
    defer buffer.deinit(gpa);
    try readRemainingArrayList(r, gpa, null, &buffer, limit);
    return buffer.toOwnedSlice(gpa);
}

/// Transfers all bytes from the current position to the end of the stream, up
/// to `limit`, appending them to `list`.
///
/// If `limit` is exceeded:
/// * The array list's length is increased by exactly one byte past `limit`.
/// * The stream seek position is advanced by exactly one byte past `limit`.
/// * `error.StreamTooLong` is returned.
///
/// The other function listed below has different semantics for an exceeded
/// limit.
///
/// See also:
/// * `BufferedReader.readRemainingArrayList`
pub fn readRemainingArrayList(
    r: Reader,
    gpa: Allocator,
    comptime alignment: ?std.mem.Alignment,
    list: *std.ArrayListAlignedUnmanaged(u8, alignment),
    limit: Limit,
) LimitedAllocError!void {
    var remaining = limit;
    while (true) {
        try list.ensureUnusedCapacity(gpa, 1);
        const buffer = remaining.slice1(list.unusedCapacitySlice());
        const n = r.vtable.readVec(r.context, &.{buffer}) catch |err| switch (err) {
            error.EndOfStream => return,
            error.ReadFailed => return error.ReadFailed,
        };
        list.items.len += n;
        remaining = remaining.subtract(n) orelse return error.StreamTooLong;
    }
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

pub fn unbuffered(r: Reader) BufferedReader {
    return buffered(r, &.{});
}

pub fn buffered(r: Reader, buffer: []u8) BufferedReader {
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
