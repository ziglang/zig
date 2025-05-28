const std = @import("../std.zig");
const Reader = @This();
const assert = std.debug.assert;
const BufferedWriter = std.io.BufferedWriter;
const BufferedReader = std.io.BufferedReader;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Limit = std.io.Limit;

pub const Limited = @import("Reader/Limited.zig");

context: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Writes bytes from the internally tracked stream position to `bw`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and
    /// at most `limit`. The number returned, including zero, does not indicate
    /// end of stream. `limit` is guaranteed to be at least as large as the
    /// buffer capacity of `bw`.
    ///
    /// The reader's internal logical seek position moves forward in accordance
    /// with the number of bytes returned from this function.
    ///
    /// Implementations are encouraged to utilize mandatory minimum buffer
    /// sizes combined with short reads (returning a value less than `limit`)
    /// in order to minimize complexity.
    read: *const fn (context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) StreamError!usize,

    /// Consumes bytes from the internally tracked stream position without
    /// providing access to them.
    ///
    /// Returns the number of bytes discarded, which will be at minimum `0` and
    /// at most `limit`. The number of bytes returned, including zero, does not
    /// indicate end of stream.
    ///
    /// The reader's internal logical seek position moves forward in accordance
    /// with the number of bytes returned from this function.
    ///
    /// Implementations are encouraged to utilize mandatory minimum buffer
    /// sizes combined with short reads (returning a value less than `limit`)
    /// in order to minimize complexity.
    ///
    /// If an implementation sets this to `null`, a default implementation is
    /// provided which is based on calling `read`, borrowing
    /// `BufferedReader.buffer` to construct a temporary `BufferedWriter` and
    /// ignoring the written data.
    discard: *const fn (context: ?*anyopaque, limit: Limit) DiscardError!usize = null,
};

pub const StreamError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// End of stream indicated from the `Reader`. This error cannot originate
    /// from the `Writer`.
    EndOfStream,
};

pub const DiscardError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    EndOfStream,
};

pub const RwRemainingError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const ShortError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
};

pub fn read(r: Reader, bw: *BufferedWriter, limit: Limit) StreamError!usize {
    const before = bw.count;
    const n = try r.vtable.read(r.context, bw, limit);
    assert(n <= @intFromEnum(limit));
    assert(bw.count == before + n);
    return n;
}

pub fn discard(r: Reader, limit: Limit) DiscardError!usize {
    const n = try r.vtable.discard(r.context, limit);
    assert(n <= @intFromEnum(limit));
    return n;
}

/// Returns total number of bytes written to `bw`.
pub fn readRemaining(r: Reader, bw: *BufferedWriter) RwRemainingError!usize {
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
    try readRemainingArrayList(r, gpa, null, &buffer, limit, 1);
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
    minimum_buffer_size: usize,
) LimitedAllocError!void {
    var remaining = limit;
    while (true) {
        try list.ensureUnusedCapacity(gpa, minimum_buffer_size);
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
        .discard = failingDiscard,
    },
};

pub const ending: Reader = .{
    .context = undefined,
    .vtable = &.{
        .read = endingRead,
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

pub fn limited(r: Reader, limit: Limit) Limited {
    return .{
        .unlimited_reader = r,
        .remaining = limit,
    };
}

fn endingRead(context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) StreamError!usize {
    _ = context;
    _ = bw;
    _ = limit;
    return error.EndOfStream;
}

fn endingDiscard(context: ?*anyopaque, limit: Limit) DiscardError!usize {
    _ = context;
    _ = limit;
    return error.EndOfStream;
}

fn failingRead(context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) StreamError!usize {
    _ = context;
    _ = bw;
    _ = limit;
    return error.ReadFailed;
}

fn failingDiscard(context: ?*anyopaque, limit: Limit) DiscardError!usize {
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

/// Provides a `Reader` implementation by passing data from an underlying
/// reader through `Hasher.update`.
///
/// The underlying reader is best unbuffered.
///
/// This implementation makes suboptimal buffering decisions due to being
/// generic. A better solution will involve creating a reader for each hash
/// function, where the discard buffer can be tailored to the hash
/// implementation details.
pub fn Hashed(comptime Hasher: type) type {
    return struct {
        in: *BufferedReader,
        hasher: Hasher,

        pub fn readable(this: *@This(), buffer: []u8) BufferedReader {
            return .{
                .unbuffered_reader = .{
                    .context = this,
                    .vtable = &.{
                        .read = @This().read,
                        .discard = @This().discard,
                    },
                },
                .buffer = buffer,
                .end = 0,
                .seek = 0,
            };
        }

        fn read(context: ?*anyopaque, bw: *BufferedWriter, limit: Limit) StreamError!usize {
            const this: *@This() = @alignCast(@ptrCast(context));
            const slice = limit.slice(try bw.writableSliceGreedy(1));
            const n = try this.in.readVec(&.{slice});
            this.hasher.update(slice[0..n]);
            bw.advance(n);
            return n;
        }

        fn discard(context: ?*anyopaque, limit: Limit) DiscardError!usize {
            const this: *@This() = @alignCast(@ptrCast(context));
            var bw = this.hasher.writable(&.{});
            const n = this.in.read(&bw, limit) catch |err| switch (err) {
                error.WriteFailed => unreachable,
                else => |e| return e,
            };
            return n;
        }

        fn readVec(context: ?*anyopaque, data: []const []u8) DiscardError!usize {
            const this: *@This() = @alignCast(@ptrCast(context));
            const n = try this.in.readVec(data);
            var remaining: usize = n;
            for (data) |slice| {
                if (remaining < slice.len) {
                    this.hasher.update(slice[0..remaining]);
                    return n;
                } else {
                    remaining -= slice.len;
                    this.hasher.update(slice);
                }
            }
            assert(remaining == 0);
            return n;
        }
    };
}
