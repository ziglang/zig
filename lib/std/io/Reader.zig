const std = @import("../std.zig");
const Reader = @This();
const assert = std.debug.assert;

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
    ///
    /// If `error.Unstreamable` is returned, the resource cannot be used via a
    /// streaming reading interface.
    read: *const fn (ctx: ?*anyopaque, bw: *std.io.BufferedWriter, limit: Limit) anyerror!Status,

    /// Writes bytes from the internally tracked stream position to `data`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and at
    /// most `limit`. The number of bytes read, including zero, does not
    /// indicate end of stream.
    ///
    /// If the reader has an internal seek position, it moves forward in
    /// accordance with the number of bytes return from this function.
    ///
    /// The implementation should do a maximum of one underlying read call.
    ///
    /// If `error.Unstreamable` is returned, the resource cannot be used via a
    /// streaming reading interface.
    readv: *const fn (ctx: ?*anyopaque, data: []const []u8) anyerror!Status,
};

pub const Len = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @bitSizeOf(usize) - 1 } });

pub const Status = packed struct(usize) {
    /// Number of bytes that were transferred. Zero does not mean end of
    /// stream.
    len: Len = 0,
    /// Indicates end of stream.
    end: bool = false,
};

pub const Limit = enum(usize) {
    zero = 0,
    none = std.math.maxInt(usize),
    _,

    /// `std.math.maxInt(usize)` is interpreted to mean "no limit".
    pub fn init(n: usize) Limit {
        return @enumFromInt(n);
    }

    pub fn min(l: Limit, n: usize) usize {
        return @min(n, @intFromEnum(l));
    }

    pub fn slice(l: Limit, s: []u8) []u8 {
        return s[0..min(l, s.len)];
    }

    pub fn toInt(l: Limit) ?usize {
        return if (l == .none) null else @intFromEnum(l);
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
        if (l == .none) return .{ .next = .none };
        if (amount > @intFromEnum(l)) return null;
        return @enumFromInt(@intFromEnum(l) - amount);
    }
};

pub fn read(r: Reader, w: *std.io.BufferedWriter, limit: Limit) anyerror!Status {
    return r.vtable.read(r.context, w, limit);
}

pub fn readv(r: Reader, data: []const []u8) anyerror!Status {
    return r.vtable.readv(r.context, data);
}

/// Returns total number of bytes written to `w`.
pub fn readAll(r: Reader, w: *std.io.BufferedWriter) anyerror!usize {
    const readFn = r.vtable.read;
    var offset: usize = 0;
    while (true) {
        const status = try readFn(r.context, w, .none);
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
pub fn readAlloc(r: Reader, gpa: std.mem.Allocator, max_size: usize) anyerror![]u8 {
    const readFn = r.vtable.read;
    var aw: std.io.AllocatingWriter = undefined;
    errdefer aw.deinit();
    const bw = aw.init(gpa);
    var remaining = max_size;
    while (remaining > 0) {
        const status = try readFn(r.context, bw, .init(remaining));
        if (status.end) break;
        remaining -= status.len;
    }
    return aw.toOwnedSlice(gpa);
}

/// Reads the stream until the end, ignoring all the data.
/// Returns the number of bytes discarded.
pub fn discardUntilEnd(r: Reader) anyerror!usize {
    var bw = std.io.null_writer.unbuffered();
    return readAll(r, &bw);
}

test "readAlloc when the backing reader provides one byte at a time" {
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
