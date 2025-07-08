const Reader = @This();

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const std = @import("../std.zig");
const Writer = std.io.Writer;
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Limit = std.io.Limit;

pub const Limited = @import("Reader/Limited.zig");

vtable: *const VTable,
buffer: []u8,
/// Number of bytes which have been consumed from `buffer`.
seek: usize,
/// In `buffer` before this are buffered bytes, after this is `undefined`.
end: usize,

pub const VTable = struct {
    /// Writes bytes from the internally tracked logical position to `w`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and
    /// at most `limit`. The number returned, including zero, does not indicate
    /// end of stream. `limit` is guaranteed to be at least as large as the
    /// buffer capacity of `w`, a value whose minimum size is determined by the
    /// stream implementation.
    ///
    /// The reader's internal logical seek position moves forward in accordance
    /// with the number of bytes returned from this function.
    ///
    /// Implementations are encouraged to utilize mandatory minimum buffer
    /// sizes combined with short reads (returning a value less than `limit`)
    /// in order to minimize complexity.
    ///
    /// Although this function is usually called when `buffer` is empty, it is
    /// also called when it needs to be filled more due to the API user
    /// requesting contiguous memory. In either case, the existing buffer data
    /// should be ignored; new data written to `w`.
    stream: *const fn (r: *Reader, w: *Writer, limit: Limit) StreamError!usize,

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
    /// The default implementation is is based on calling `stream`, borrowing
    /// `buffer` to construct a temporary `Writer` and ignoring the written
    /// data.
    discard: *const fn (r: *Reader, limit: Limit) Error!usize = defaultDiscard,
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

pub const Error = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    EndOfStream,
};

pub const StreamRemainingError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const ShortError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
};

pub const failing: Reader = .{
    .vtable = &.{
        .read = failingStream,
        .discard = failingDiscard,
    },
    .buffer = &.{},
    .seek = 0,
    .end = 0,
};

/// This is generally safe to `@constCast` because it has an empty buffer, so
/// there is not really a way to accidentally attempt mutation of these fields.
const ending_state: Reader = .fixed(&.{});
pub const ending: *Reader = @constCast(&ending_state);

pub fn limited(r: *Reader, limit: Limit, buffer: []u8) Limited {
    return .init(r, limit, buffer);
}

/// Constructs a `Reader` such that it will read from `buffer` and then end.
pub fn fixed(buffer: []const u8) Reader {
    return .{
        .vtable = &.{
            .stream = endingStream,
            .discard = endingDiscard,
        },
        // This cast is safe because all potential writes to it will instead
        // return `error.EndOfStream`.
        .buffer = @constCast(buffer),
        .end = buffer.len,
        .seek = 0,
    };
}

pub fn stream(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
    const buffer = limit.slice(r.buffer[r.seek..r.end]);
    if (buffer.len > 0) {
        @branchHint(.likely);
        const n = try w.write(buffer);
        r.seek += n;
        return n;
    }
    const before = w.count;
    const n = try r.vtable.stream(r, w, limit);
    assert(n <= @intFromEnum(limit));
    assert(w.count == before + n);
    return n;
}

pub fn discard(r: *Reader, limit: Limit) Error!usize {
    const buffered_len = r.end - r.seek;
    const remaining: Limit = if (limit.toInt()) |n| l: {
        if (buffered_len >= n) {
            r.seek += n;
            return n;
        }
        break :l .limited(n - buffered_len);
    } else .unlimited;
    r.seek = 0;
    r.end = 0;
    const n = try r.vtable.discard(r, remaining);
    assert(n <= @intFromEnum(remaining));
    return buffered_len + n;
}

pub fn defaultDiscard(r: *Reader, limit: Limit) Error!usize {
    assert(r.seek == 0);
    assert(r.end == 0);
    var w: Writer = .discarding(r.buffer);
    const n = r.stream(&w, limit) catch |err| switch (err) {
        error.WriteFailed => unreachable,
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => return error.EndOfStream,
    };
    if (n > @intFromEnum(limit)) {
        const over_amt = n - @intFromEnum(limit);
        r.seek = w.end - over_amt;
        r.end = w.end;
        assert(r.end <= w.buffer.len); // limit may be exceeded only by an amount within buffer capacity.
        return @intFromEnum(limit);
    }
    return n;
}

/// "Pump" exactly `n` bytes from the reader to the writer.
pub fn streamExact(r: *Reader, w: *Writer, n: usize) StreamError!void {
    var remaining = n;
    while (remaining != 0) remaining -= try r.stream(w, .limited(remaining));
}

/// "Pump" data from the reader to the writer, handling `error.EndOfStream` as
/// a success case.
///
/// Returns total number of bytes written to `w`.
pub fn streamRemaining(r: *Reader, w: *Writer) StreamRemainingError!usize {
    var offset: usize = 0;
    while (true) {
        offset += r.stream(w, .unlimited) catch |err| switch (err) {
            error.EndOfStream => return offset,
            else => |e| return e,
        };
    }
}

/// Consumes the stream until the end, ignoring all the data, returning the
/// number of bytes discarded.
pub fn discardRemaining(r: *Reader) ShortError!usize {
    var offset: usize = r.end - r.seek;
    r.seek = 0;
    r.end = 0;
    while (true) {
        offset += r.vtable.discard(r, .unlimited) catch |err| switch (err) {
            error.EndOfStream => return offset,
            else => |e| return e,
        };
    }
}

pub const LimitedAllocError = Allocator.Error || ShortError || error{StreamTooLong};

/// Transfers all bytes from the current position to the end of the stream, up
/// to `limit`, returning them as a caller-owned allocated slice.
///
/// If `limit` would be exceeded, `error.StreamTooLong` is returned instead. In
/// such case, the next byte that would be read will be the first one to exceed
/// `limit`, and all preceeding bytes have been discarded.
///
/// Asserts `buffer` has nonzero capacity.
///
/// See also:
/// * `appendRemaining`
pub fn allocRemaining(r: *Reader, gpa: Allocator, limit: Limit) LimitedAllocError![]u8 {
    var buffer: ArrayList(u8) = .empty;
    defer buffer.deinit(gpa);
    try appendRemaining(r, gpa, null, &buffer, limit);
    return buffer.toOwnedSlice(gpa);
}

/// Transfers all bytes from the current position to the end of the stream, up
/// to `limit`, appending them to `list`.
///
/// If `limit` would be exceeded, `error.StreamTooLong` is returned instead. In
/// such case, the next byte that would be read will be the first one to exceed
/// `limit`, and all preceeding bytes have been appended to `list`.
///
/// Asserts `buffer` has nonzero capacity.
///
/// See also:
/// * `allocRemaining`
pub fn appendRemaining(
    r: *Reader,
    gpa: Allocator,
    comptime alignment: ?std.mem.Alignment,
    list: *std.ArrayListAlignedUnmanaged(u8, alignment),
    limit: Limit,
) LimitedAllocError!void {
    const buffer = r.buffer;
    const buffer_contents = buffer[r.seek..r.end];
    const copy_len = limit.minInt(buffer_contents.len);
    try list.ensureUnusedCapacity(gpa, copy_len);
    @memcpy(list.unusedCapacitySlice()[0..copy_len], buffer[0..copy_len]);
    list.items.len += copy_len;
    r.seek += copy_len;
    if (copy_len == buffer_contents.len) {
        r.seek = 0;
        r.end = 0;
    }
    var remaining = limit.subtract(copy_len).?;
    while (true) {
        try list.ensureUnusedCapacity(gpa, 1);
        const dest = remaining.slice(list.unusedCapacitySlice());
        const additional_buffer: []u8 = if (@intFromEnum(remaining) == dest.len) buffer else &.{};
        const n = readVec(r, &.{ dest, additional_buffer }) catch |err| switch (err) {
            error.EndOfStream => break,
            error.ReadFailed => return error.ReadFailed,
        };
        if (n > dest.len) {
            r.end = n - dest.len;
            list.items.len += dest.len;
            return error.StreamTooLong;
        }
        list.items.len += n;
        remaining = remaining.subtract(n).?;
    }
}

/// Writes bytes from the internally tracked stream position to `data`.
///
/// Returns the number of bytes written, which will be at minimum `0` and
/// at most the sum of each data slice length. The number of bytes read,
/// including zero, does not indicate end of stream.
///
/// The reader's internal logical seek position moves forward in accordance
/// with the number of bytes returned from this function.
pub fn readVec(r: *Reader, data: []const []u8) Error!usize {
    return readVecLimit(r, data, .unlimited);
}

/// Equivalent to `readVec` but reads at most `limit` bytes.
///
/// This ultimately will lower to a call to `stream`, but it must ensure
/// that the buffer used has at least as much capacity, in case that function
/// depends on a minimum buffer capacity. It also ensures that if the `stream`
/// implementation calls `Writer.writableVector`, it will get this data slice
/// along with the buffer at the end.
pub fn readVecLimit(r: *Reader, data: []const []u8, limit: Limit) Error!usize {
    comptime assert(@intFromEnum(Limit.unlimited) == std.math.maxInt(usize));
    var remaining = @intFromEnum(limit);
    for (data, 0..) |buf, i| {
        const buffer_contents = r.buffer[r.seek..r.end];
        const copy_len = @min(buffer_contents.len, buf.len, remaining);
        @memcpy(buf[0..copy_len], buffer_contents[0..copy_len]);
        r.seek += copy_len;
        remaining -= copy_len;
        if (remaining == 0) break;
        if (buf.len - copy_len == 0) continue;

        // All of `buffer` has been copied to `data`. We now set up a structure
        // that enables the `Writer.writableVector` API, while also ensuring
        // API that directly operates on the `Writable.buffer` has its minimum
        // buffer capacity requirements met.
        r.seek = 0;
        r.end = 0;
        const first = buf[copy_len..];
        const middle = data[i + 1 ..];
        var wrapper: Writer.VectorWrapper = .{
            .it = .{
                .first = first,
                .middle = middle,
                .last = r.buffer,
            },
            .writer = .{
                .buffer = if (first.len >= r.buffer.len) first else r.buffer,
                .vtable = Writer.VectorWrapper.vtable,
            },
        };
        var n = r.vtable.stream(r, &wrapper.writer, .limited(remaining)) catch |err| switch (err) {
            error.WriteFailed => {
                assert(!wrapper.used);
                if (wrapper.writer.buffer.ptr == first.ptr) {
                    remaining -= wrapper.writer.end;
                } else {
                    assert(wrapper.writer.end <= r.buffer.len);
                    r.end = wrapper.writer.end;
                }
                break;
            },
            else => |e| return e,
        };
        if (!wrapper.used) {
            if (wrapper.writer.buffer.ptr == first.ptr) {
                remaining -= n;
            } else {
                assert(n <= r.buffer.len);
                r.end = n;
            }
            break;
        }
        if (n < first.len) {
            remaining -= n;
            break;
        }
        remaining -= first.len;
        n -= first.len;
        for (middle) |mid| {
            if (n < mid.len) {
                remaining -= n;
                break;
            }
            remaining -= mid.len;
            n -= mid.len;
        }
        assert(n <= r.buffer.len);
        r.end = n;
        break;
    }
    return @intFromEnum(limit) - remaining;
}

pub fn buffered(r: *Reader) []u8 {
    return r.buffer[r.seek..r.end];
}

pub fn bufferedLen(r: *const Reader) usize {
    return r.end - r.seek;
}

pub fn hashed(r: *Reader, hasher: anytype) Hashed(@TypeOf(hasher)) {
    return .{ .in = r, .hasher = hasher };
}

pub fn readVecAll(r: *Reader, data: [][]u8) Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    while (index < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try r.readVec(data[index..]);
        }
        while (index < data.len and truncate >= data[index].len) {
            truncate -= data[index].len;
            index += 1;
        }
    }
}

/// Returns the next `len` bytes from the stream, filling the buffer as
/// necessary.
///
/// Invalidates previously returned values from `peek`.
///
/// Asserts that the `Reader` was initialized with a buffer capacity at
/// least as big as `len`.
///
/// If there are fewer than `len` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `peek`
/// * `toss`
pub fn peek(r: *Reader, n: usize) Error![]u8 {
    try r.fill(n);
    return r.buffer[r.seek..][0..n];
}

/// Returns all the next buffered bytes, after filling the buffer to ensure it
/// contains at least `n` bytes.
///
/// Invalidates previously returned values from `peek` and `peekGreedy`.
///
/// Asserts that the `Reader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `peek`
/// * `toss`
pub fn peekGreedy(r: *Reader, n: usize) Error![]u8 {
    try r.fill(n);
    return r.buffer[r.seek..r.end];
}

/// Skips the next `n` bytes from the stream, advancing the seek position. This
/// is typically and safely used after `peek`.
///
/// Asserts that the number of bytes buffered is at least as many as `n`.
///
/// The "tossed" memory remains alive until a "peek" operation occurs.
///
/// See also:
/// * `peek`.
/// * `discard`.
pub fn toss(r: *Reader, n: usize) void {
    r.seek += n;
    assert(r.seek <= r.end);
}

/// Equivalent to `toss(r.bufferedLen())`.
pub fn tossBuffered(r: *Reader) void {
    r.seek = 0;
    r.end = 0;
}

/// Equivalent to `peek` followed by `toss`.
///
/// The data returned is invalidated by the next call to `take`, `peek`,
/// `fill`, and functions with those prefixes.
pub fn take(r: *Reader, n: usize) Error![]u8 {
    const result = try r.peek(n);
    r.toss(n);
    return result;
}

/// Returns the next `n` bytes from the stream as an array, filling the buffer
/// as necessary and advancing the seek position `n` bytes.
///
/// Asserts that the `Reader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `take`
pub fn takeArray(r: *Reader, comptime n: usize) Error!*[n]u8 {
    return (try r.take(n))[0..n];
}

/// Returns the next `n` bytes from the stream as an array, filling the buffer
/// as necessary, without advancing the seek position.
///
/// Asserts that the `Reader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `peek`
/// * `takeArray`
pub fn peekArray(r: *Reader, comptime n: usize) Error!*[n]u8 {
    return (try r.peek(n))[0..n];
}

/// Skips the next `n` bytes from the stream, advancing the seek position.
///
/// Unlike `toss` which is infallible, in this function `n` can be any amount.
///
/// Returns `error.EndOfStream` if fewer than `n` bytes could be discarded.
///
/// See also:
/// * `toss`
/// * `discardRemaining`
/// * `discardShort`
/// * `discard`
pub fn discardAll(r: *Reader, n: usize) Error!void {
    if ((try r.discardShort(n)) != n) return error.EndOfStream;
}

pub fn discardAll64(r: *Reader, n: u64) Error!void {
    var remaining: u64 = n;
    while (remaining > 0) {
        const limited_remaining = std.math.cast(usize, remaining) orelse std.math.maxInt(usize);
        try discardAll(r, limited_remaining);
        remaining -= limited_remaining;
    }
}

/// Skips the next `n` bytes from the stream, advancing the seek position.
///
/// Unlike `toss` which is infallible, in this function `n` can be any amount.
///
/// Returns the number of bytes discarded, which is less than `n` if and only
/// if the stream reached the end.
///
/// See also:
/// * `discardAll`
/// * `discardRemaining`
/// * `discard`
pub fn discardShort(r: *Reader, n: usize) ShortError!usize {
    const proposed_seek = r.seek + n;
    if (proposed_seek <= r.end) {
        @branchHint(.likely);
        r.seek = proposed_seek;
        return n;
    }
    var remaining = n - (r.end - r.seek);
    r.end = 0;
    r.seek = 0;
    while (true) {
        const discard_len = r.vtable.discard(r, .limited(remaining)) catch |err| switch (err) {
            error.EndOfStream => return n - remaining,
            error.ReadFailed => return error.ReadFailed,
        };
        remaining -= discard_len;
        if (remaining == 0) return n;
    }
}

/// Fill `buffer` with the next `buffer.len` bytes from the stream, advancing
/// the seek position.
///
/// Invalidates previously returned values from `peek`.
///
/// If the provided buffer cannot be filled completely, `error.EndOfStream` is
/// returned instead.
///
/// See also:
/// * `peek`
/// * `readSliceShort`
pub fn readSliceAll(r: *Reader, buffer: []u8) Error!void {
    const n = try readSliceShort(r, buffer);
    if (n != buffer.len) return error.EndOfStream;
}

/// Fill `buffer` with the next `buffer.len` bytes from the stream, advancing
/// the seek position.
///
/// Invalidates previously returned values from `peek`.
///
/// Returns the number of bytes read, which is less than `buffer.len` if and
/// only if the stream reached the end.
///
/// See also:
/// * `readSliceAll`
pub fn readSliceShort(r: *Reader, buffer: []u8) ShortError!usize {
    const in_buffer = r.buffer[r.seek..r.end];
    const copy_len = @min(buffer.len, in_buffer.len);
    @memcpy(buffer[0..copy_len], in_buffer[0..copy_len]);
    if (buffer.len - copy_len == 0) {
        r.seek += copy_len;
        return buffer.len;
    }
    var i: usize = copy_len;
    r.end = 0;
    r.seek = 0;
    while (true) {
        const remaining = buffer[i..];
        var wrapper: Writer.VectorWrapper = .{
            .it = .{
                .first = remaining,
                .last = r.buffer,
            },
            .writer = .{
                .buffer = if (remaining.len >= r.buffer.len) remaining else r.buffer,
                .vtable = Writer.VectorWrapper.vtable,
            },
        };
        const n = r.vtable.stream(r, &wrapper.writer, .unlimited) catch |err| switch (err) {
            error.WriteFailed => {
                if (!wrapper.used) {
                    assert(r.seek == 0);
                    r.seek = remaining.len;
                    r.end = wrapper.writer.end;
                    @memcpy(remaining, r.buffer[0..remaining.len]);
                }
                return buffer.len;
            },
            error.EndOfStream => return i,
            error.ReadFailed => return error.ReadFailed,
        };
        if (n < remaining.len) {
            i += n;
            continue;
        }
        r.end = n - remaining.len;
        return buffer.len;
    }
}

/// Fill `buffer` with the next `buffer.len` bytes from the stream, advancing
/// the seek position.
///
/// Invalidates previously returned values from `peek`.
///
/// If the provided buffer cannot be filled completely, `error.EndOfStream` is
/// returned instead.
///
/// The function is inline to avoid the dead code in case `endian` is
/// comptime-known and matches host endianness.
///
/// See also:
/// * `readSliceAll`
/// * `readSliceEndianAlloc`
pub inline fn readSliceEndian(
    r: *Reader,
    comptime Elem: type,
    buffer: []Elem,
    endian: std.builtin.Endian,
) Error!void {
    try readSliceAll(r, @ptrCast(buffer));
    if (native_endian != endian) for (buffer) |*elem| std.mem.byteSwapAllFields(Elem, elem);
}

pub const ReadAllocError = Error || Allocator.Error;

/// The function is inline to avoid the dead code in case `endian` is
/// comptime-known and matches host endianness.
pub inline fn readSliceEndianAlloc(
    r: *Reader,
    allocator: Allocator,
    comptime Elem: type,
    len: usize,
    endian: std.builtin.Endian,
) ReadAllocError![]Elem {
    const dest = try allocator.alloc(Elem, len);
    errdefer allocator.free(dest);
    try readSliceAll(r, @ptrCast(dest));
    if (native_endian != endian) for (dest) |*elem| std.mem.byteSwapAllFields(Elem, elem);
    return dest;
}

/// Shortcut for calling `readSliceAll` with a buffer provided by `allocator`.
pub fn readAlloc(r: *Reader, allocator: Allocator, len: usize) ReadAllocError![]u8 {
    const dest = try allocator.alloc(u8, len);
    errdefer allocator.free(dest);
    try readSliceAll(r, dest);
    return dest;
}

pub const DelimiterError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// For "inclusive" functions, stream ended before the delimiter was found.
    /// For "exclusive" functions, stream ended and there are no more bytes to
    /// return.
    EndOfStream,
    /// The delimiter was not found within a number of bytes matching the
    /// capacity of the `Reader`.
    StreamTooLong,
};

/// Returns a slice of the next bytes of buffered data from the stream until
/// `sentinel` is found, advancing the seek position.
///
/// Returned slice has a sentinel.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `peekSentinel`
/// * `takeDelimiterExclusive`
/// * `takeDelimiterInclusive`
pub fn takeSentinel(r: *Reader, comptime sentinel: u8) DelimiterError![:sentinel]u8 {
    const result = try r.peekSentinel(sentinel);
    r.toss(result.len + 1);
    return result;
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `sentinel` is found, without advancing the seek position.
///
/// Returned slice has a sentinel; end of stream does not count as a delimiter.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `takeSentinel`
/// * `peekDelimiterExclusive`
/// * `peekDelimiterInclusive`
pub fn peekSentinel(r: *Reader, comptime sentinel: u8) DelimiterError![:sentinel]u8 {
    const result = try r.peekDelimiterInclusive(sentinel);
    return result[0 .. result.len - 1 :sentinel];
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position.
///
/// Returned slice includes the delimiter as the last byte.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `takeSentinel`
/// * `takeDelimiterExclusive`
/// * `peekDelimiterInclusive`
pub fn takeDelimiterInclusive(r: *Reader, delimiter: u8) DelimiterError![]u8 {
    const result = try r.peekDelimiterInclusive(delimiter);
    r.toss(result.len);
    return result;
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, without advancing the seek position.
///
/// Returned slice includes the delimiter as the last byte.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `peekSentinel`
/// * `peekDelimiterExclusive`
/// * `takeDelimiterInclusive`
pub fn peekDelimiterInclusive(r: *Reader, delimiter: u8) DelimiterError![]u8 {
    const buffer = r.buffer[0..r.end];
    const seek = r.seek;
    if (std.mem.indexOfScalarPos(u8, buffer, seek, delimiter)) |end| {
        @branchHint(.likely);
        return buffer[seek .. end + 1];
    }
    while (r.buffer.len - r.end != 0) {
        const end_cap = r.buffer[r.end..];
        var writer: Writer = .fixed(end_cap);
        const n = r.vtable.stream(r, &writer, .limited(end_cap.len)) catch |err| switch (err) {
            error.WriteFailed => unreachable,
            else => |e| return e,
        };
        r.end += n;
        if (std.mem.indexOfScalarPos(u8, end_cap[0..n], 0, delimiter)) |end| {
            return r.buffer[seek .. r.end - n + end + 1];
        }
    }
    var i: usize = 0;
    while (seek - i != 0) {
        const begin_cap = r.buffer[i..seek];
        var writer: Writer = .fixed(begin_cap);
        const n = r.vtable.stream(r, &writer, .limited(begin_cap.len)) catch |err| switch (err) {
            error.WriteFailed => unreachable,
            else => |e| return e,
        };
        i += n;
        if (std.mem.indexOfScalarPos(u8, r.buffer[0..seek], i, delimiter)) |end| {
            std.mem.rotate(u8, r.buffer, seek);
            r.seek = 0;
            r.end += i;
            return r.buffer[0 .. seek + end + 1];
        }
    } else if (i != 0) {
        std.mem.rotate(u8, r.buffer, seek);
        r.seek = 0;
        r.end += i;
    }
    return error.StreamTooLong;
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position.
///
/// Returned slice excludes the delimiter. End-of-stream is treated equivalent
/// to a delimiter, unless it would result in a length 0 return value, in which
/// case `error.EndOfStream` is returned instead.
///
/// If the delimiter is not found within a number of bytes matching the
/// capacity of this `Reader`, `error.StreamTooLong` is returned. In
/// such case, the stream state is unmodified as if this function was never
/// called.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `takeDelimiterInclusive`
/// * `peekDelimiterExclusive`
pub fn takeDelimiterExclusive(r: *Reader, delimiter: u8) DelimiterError![]u8 {
    const result = r.peekDelimiterInclusive(delimiter) catch |err| switch (err) {
        error.EndOfStream => {
            const remaining = r.buffer[r.seek..r.end];
            if (remaining.len == 0) return error.EndOfStream;
            r.toss(remaining.len);
            return remaining;
        },
        else => |e| return e,
    };
    r.toss(result.len);
    return result[0 .. result.len - 1];
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, without advancing the seek position.
///
/// Returned slice excludes the delimiter. End-of-stream is treated equivalent
/// to a delimiter, unless it would result in a length 0 return value, in which
/// case `error.EndOfStream` is returned instead.
///
/// If the delimiter is not found within a number of bytes matching the
/// capacity of this `Reader`, `error.StreamTooLong` is returned. In
/// such case, the stream state is unmodified as if this function was never
/// called.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `peekDelimiterInclusive`
/// * `takeDelimiterExclusive`
pub fn peekDelimiterExclusive(r: *Reader, delimiter: u8) DelimiterError![]u8 {
    const result = r.peekDelimiterInclusive(delimiter) catch |err| switch (err) {
        error.EndOfStream => {
            const remaining = r.buffer[r.seek..r.end];
            if (remaining.len == 0) return error.EndOfStream;
            r.toss(remaining.len);
            return remaining;
        },
        else => |e| return e,
    };
    return result[0 .. result.len - 1];
}

/// Appends to `w` contents by reading from the stream until `delimiter` is
/// found. Does not write the delimiter itself.
///
/// Returns number of bytes streamed, which may be zero, or error.EndOfStream
/// if the delimiter was not found.
///
/// See also:
/// * `streamDelimiterEnding`
/// * `streamDelimiterLimit`
pub fn streamDelimiter(r: *Reader, w: *Writer, delimiter: u8) StreamError!usize {
    const n = streamDelimiterLimit(r, w, delimiter, .unlimited) catch |err| switch (err) {
        error.StreamTooLong => unreachable, // unlimited is passed
        else => |e| return e,
    };
    if (r.seek == r.end) return error.EndOfStream;
    return n;
}

/// Appends to `w` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// Returns number of bytes streamed, which may be zero. End of stream can be
/// detected by checking if the next byte in the stream is the delimiter.
///
/// See also:
/// * `streamDelimiter`
/// * `streamDelimiterLimit`
pub fn streamDelimiterEnding(
    r: *Reader,
    w: *Writer,
    delimiter: u8,
) StreamRemainingError!usize {
    return streamDelimiterLimit(r, w, delimiter, .unlimited) catch |err| switch (err) {
        error.StreamTooLong => unreachable, // unlimited is passed
        else => |e| return e,
    };
}

pub const StreamDelimiterLimitError = error{
    ReadFailed,
    WriteFailed,
    /// The delimiter was not found within the limit.
    StreamTooLong,
};

/// Appends to `w` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// Returns number of bytes streamed, which may be zero. End of stream can be
/// detected by checking if the next byte in the stream is the delimiter.
pub fn streamDelimiterLimit(
    r: *Reader,
    w: *Writer,
    delimiter: u8,
    limit: Limit,
) StreamDelimiterLimitError!usize {
    var remaining = @intFromEnum(limit);
    while (remaining != 0) {
        const available = Limit.limited(remaining).slice(r.peekGreedy(1) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => return @intFromEnum(limit) - remaining,
        });
        if (std.mem.indexOfScalar(u8, available, delimiter)) |delimiter_index| {
            try w.writeAll(available[0..delimiter_index]);
            r.toss(delimiter_index);
            remaining -= delimiter_index;
            return @intFromEnum(limit) - remaining;
        }
        try w.writeAll(available);
        r.toss(available.len);
        remaining -= available.len;
    }
    return error.StreamTooLong;
}

/// Reads from the stream until specified byte is found, discarding all data,
/// including the delimiter.
///
/// Returns number of bytes discarded, or `error.EndOfStream` if the delimiter
/// is not found.
///
/// See also:
/// * `discardDelimiterExclusive`
/// * `discardDelimiterLimit`
pub fn discardDelimiterInclusive(r: *Reader, delimiter: u8) Error!usize {
    const n = discardDelimiterLimit(r, delimiter, .unlimited) catch |err| switch (err) {
        error.StreamTooLong => unreachable, // unlimited is passed
        else => |e| return e,
    };
    if (r.seek == r.end) return error.EndOfStream;
    assert(r.buffer[r.seek] == delimiter);
    toss(r, 1);
    return n + 1;
}

/// Reads from the stream until specified byte is found, discarding all data,
/// excluding the delimiter.
///
/// Returns the number of bytes discarded.
///
/// Succeeds if stream ends before delimiter found. End of stream can be
/// detected by checking if the delimiter is buffered.
///
/// See also:
/// * `discardDelimiterInclusive`
/// * `discardDelimiterLimit`
pub fn discardDelimiterExclusive(r: *Reader, delimiter: u8) ShortError!usize {
    return discardDelimiterLimit(r, delimiter, .unlimited) catch |err| switch (err) {
        error.StreamTooLong => unreachable, // unlimited is passed
        else => |e| return e,
    };
}

pub const DiscardDelimiterLimitError = error{
    ReadFailed,
    /// The delimiter was not found within the limit.
    StreamTooLong,
};

/// Reads from the stream until specified byte is found, discarding all data,
/// excluding the delimiter.
///
/// Returns the number of bytes discarded.
///
/// Succeeds if stream ends before delimiter found. End of stream can be
/// detected by checking if the delimiter is buffered.
pub fn discardDelimiterLimit(r: *Reader, delimiter: u8, limit: Limit) DiscardDelimiterLimitError!usize {
    var remaining = @intFromEnum(limit);
    while (remaining != 0) {
        const available = Limit.limited(remaining).slice(r.peekGreedy(1) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => return @intFromEnum(limit) - remaining,
        });
        if (std.mem.indexOfScalar(u8, available, delimiter)) |delimiter_index| {
            r.toss(delimiter_index);
            remaining -= delimiter_index;
            return @intFromEnum(limit) - remaining;
        }
        r.toss(available.len);
        remaining -= available.len;
    }
    return error.StreamTooLong;
}

/// Fills the buffer such that it contains at least `n` bytes, without
/// advancing the seek position.
///
/// Returns `error.EndOfStream` if and only if there are fewer than `n` bytes
/// remaining.
///
/// Asserts buffer capacity is at least `n`.
pub fn fill(r: *Reader, n: usize) Error!void {
    assert(n <= r.buffer.len);
    if (r.seek + n <= r.end) {
        @branchHint(.likely);
        return;
    }
    if (r.seek + n <= r.buffer.len) while (true) {
        const end_cap = r.buffer[r.end..];
        var writer: Writer = .fixed(end_cap);
        r.end += r.vtable.stream(r, &writer, .limited(end_cap.len)) catch |err| switch (err) {
            error.WriteFailed => unreachable,
            else => |e| return e,
        };
        if (r.seek + n <= r.end) return;
    };
    if (r.vtable.stream == &endingStream) {
        // Protect the `@constCast` of `fixed`.
        return error.EndOfStream;
    }
    rebaseCapacity(r, n);
    var writer: Writer = .{
        .buffer = r.buffer,
        .vtable = &.{ .drain = Writer.fixedDrain },
    };
    while (r.end < r.seek + n) {
        writer.end = r.end;
        r.end += r.vtable.stream(r, &writer, .limited(r.buffer.len - r.end)) catch |err| switch (err) {
            error.WriteFailed => unreachable,
            error.ReadFailed, error.EndOfStream => |e| return e,
        };
    }
}

/// Without advancing the seek position, does exactly one underlying read, filling the buffer as
/// much as possible. This may result in zero bytes added to the buffer, which is not an end of
/// stream condition. End of stream is communicated via returning `error.EndOfStream`.
///
/// Asserts buffer capacity is at least 1.
pub fn fillMore(r: *Reader) Error!void {
    rebaseCapacity(r, 1);
    var writer: Writer = .{
        .buffer = r.buffer,
        .end = r.end,
        .vtable = &.{ .drain = Writer.fixedDrain },
    };
    r.end += r.vtable.stream(r, &writer, .limited(r.buffer.len - r.end)) catch |err| switch (err) {
        error.WriteFailed => unreachable,
        else => |e| return e,
    };
}

/// Returns the next byte from the stream or returns `error.EndOfStream`.
///
/// Does not advance the seek position.
///
/// Asserts the buffer capacity is nonzero.
pub fn peekByte(r: *Reader) Error!u8 {
    const buffer = r.buffer[0..r.end];
    const seek = r.seek;
    if (seek < buffer.len) {
        @branchHint(.likely);
        return buffer[seek];
    }
    try fill(r, 1);
    return r.buffer[r.seek];
}

/// Reads 1 byte from the stream or returns `error.EndOfStream`.
///
/// Asserts the buffer capacity is nonzero.
pub fn takeByte(r: *Reader) Error!u8 {
    const result = try peekByte(r);
    r.seek += 1;
    return result;
}

/// Same as `takeByte` except the returned byte is signed.
pub fn takeByteSigned(r: *Reader) Error!i8 {
    return @bitCast(try r.takeByte());
}

/// Asserts the buffer was initialized with a capacity at least `@bitSizeOf(T) / 8`.
pub inline fn takeInt(r: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    return std.mem.readInt(T, try r.takeArray(n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `n`.
pub fn takeVarInt(r: *Reader, comptime Int: type, endian: std.builtin.Endian, n: usize) Error!Int {
    assert(n <= @sizeOf(Int));
    return std.mem.readVarInt(Int, try r.take(n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// Advances the seek position.
///
/// See also:
/// * `peekStruct`
/// * `takeStructEndian`
pub fn takeStruct(r: *Reader, comptime T: type) Error!*align(1) T {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(T).@"struct".layout != .auto);
    return @ptrCast(try r.takeArray(@sizeOf(T)));
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// Does not advance the seek position.
///
/// See also:
/// * `takeStruct`
/// * `peekStructEndian`
pub fn peekStruct(r: *Reader, comptime T: type) Error!*align(1) T {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(T).@"struct".layout != .auto);
    return @ptrCast(try r.peekArray(@sizeOf(T)));
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// This function is inline to avoid referencing `std.mem.byteSwapAllFields`
/// when `endian` is comptime-known and matches the host endianness.
///
/// See also:
/// * `takeStruct`
/// * `peekStructEndian`
pub inline fn takeStructEndian(r: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
    var res = (try r.takeStruct(T)).*;
    if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
    return res;
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// This function is inline to avoid referencing `std.mem.byteSwapAllFields`
/// when `endian` is comptime-known and matches the host endianness.
///
/// See also:
/// * `takeStructEndian`
/// * `peekStruct`
pub inline fn peekStructEndian(r: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
    var res = (try r.peekStruct(T)).*;
    if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
    return res;
}

pub const TakeEnumError = Error || error{InvalidEnumTag};

/// Reads an integer with the same size as the given enum's tag type. If the
/// integer matches an enum tag, casts the integer to the enum tag and returns
/// it. Otherwise, returns `error.InvalidEnumTag`.
///
/// Asserts the buffer was initialized with a capacity at least `@sizeOf(Enum)`.
pub fn takeEnum(r: *Reader, comptime Enum: type, endian: std.builtin.Endian) TakeEnumError!Enum {
    const Tag = @typeInfo(Enum).@"enum".tag_type;
    const int = try r.takeInt(Tag, endian);
    return std.meta.intToEnum(Enum, int);
}

/// Reads an integer with the same size as the given nonexhaustive enum's tag type.
///
/// Asserts the buffer was initialized with a capacity at least `@sizeOf(Enum)`.
pub fn takeEnumNonexhaustive(r: *Reader, comptime Enum: type, endian: std.builtin.Endian) Error!Enum {
    const info = @typeInfo(Enum).@"enum";
    comptime assert(!info.is_exhaustive);
    comptime assert(@bitSizeOf(info.tag_type) == @sizeOf(info.tag_type) * 8);
    return takeEnum(r, Enum, endian) catch |err| switch (err) {
        error.InvalidEnumTag => unreachable,
        else => |e| return e,
    };
}

pub const TakeLeb128Error = Error || error{Overflow};

/// Read a single LEB128 value as type T, or `error.Overflow` if the value cannot fit.
pub fn takeLeb128(r: *Reader, comptime Result: type) TakeLeb128Error!Result {
    const result_info = @typeInfo(Result).int;
    return std.math.cast(Result, try r.takeMultipleOf7Leb128(@Type(.{ .int = .{
        .signedness = result_info.signedness,
        .bits = std.mem.alignForwardAnyAlign(u16, result_info.bits, 7),
    } }))) orelse error.Overflow;
}

pub fn expandTotalCapacity(r: *Reader, allocator: Allocator, n: usize) Allocator.Error!void {
    if (n <= r.buffer.len) return;
    if (r.seek > 0) rebase(r);
    var list: ArrayList(u8) = .{
        .items = r.buffer[0..r.end],
        .capacity = r.buffer.len,
    };
    defer r.buffer = list.allocatedSlice();
    try list.ensureTotalCapacity(allocator, n);
}

pub const FillAllocError = Error || Allocator.Error;

pub fn fillAlloc(r: *Reader, allocator: Allocator, n: usize) FillAllocError!void {
    try expandTotalCapacity(r, allocator, n);
    return fill(r, n);
}

/// Returns a slice into the unused capacity of `buffer` with at least
/// `min_len` bytes, extending `buffer` by resizing it with `gpa` as necessary.
///
/// After calling this function, typically the caller will follow up with a
/// call to `advanceBufferEnd` to report the actual number of bytes buffered.
pub fn writableSliceGreedyAlloc(r: *Reader, allocator: Allocator, min_len: usize) Allocator.Error![]u8 {
    {
        const unused = r.buffer[r.end..];
        if (unused.len >= min_len) return unused;
    }
    if (r.seek > 0) rebase(r);
    {
        var list: ArrayList(u8) = .{
            .items = r.buffer[0..r.end],
            .capacity = r.buffer.len,
        };
        defer r.buffer = list.allocatedSlice();
        try list.ensureUnusedCapacity(allocator, min_len);
    }
    const unused = r.buffer[r.end..];
    assert(unused.len >= min_len);
    return unused;
}

/// After writing directly into the unused capacity of `buffer`, this function
/// updates `end` so that users of `Reader` can receive the data.
pub fn advanceBufferEnd(r: *Reader, n: usize) void {
    assert(n <= r.buffer.len - r.end);
    r.end += n;
}

fn takeMultipleOf7Leb128(r: *Reader, comptime Result: type) TakeLeb128Error!Result {
    const result_info = @typeInfo(Result).int;
    comptime assert(result_info.bits % 7 == 0);
    var remaining_bits: std.math.Log2IntCeil(Result) = result_info.bits;
    const UnsignedResult = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = result_info.bits,
    } });
    var result: UnsignedResult = 0;
    var fits = true;
    while (true) {
        const buffer: []const packed struct(u8) { bits: u7, more: bool } = @ptrCast(try r.peekGreedy(1));
        for (buffer, 1..) |byte, len| {
            if (remaining_bits > 0) {
                result = @shlExact(@as(UnsignedResult, byte.bits), result_info.bits - 7) |
                    if (result_info.bits > 7) @shrExact(result, 7) else 0;
                remaining_bits -= 7;
            } else if (fits) fits = switch (result_info.signedness) {
                .signed => @as(i7, @bitCast(byte.bits)) ==
                    @as(i7, @truncate(@as(Result, @bitCast(result)) >> (result_info.bits - 1))),
                .unsigned => byte.bits == 0,
            };
            if (byte.more) continue;
            r.toss(len);
            return if (fits) @as(Result, @bitCast(result)) >> remaining_bits else error.Overflow;
        }
        r.toss(buffer.len);
    }
}

/// Left-aligns data such that `r.seek` becomes zero.
pub fn rebase(r: *Reader) void {
    if (r.seek == 0) return;
    const data = r.buffer[r.seek..r.end];
    @memmove(r.buffer[0..data.len], data);
    r.seek = 0;
    r.end = data.len;
}

/// Ensures `capacity` more data can be buffered without rebasing, by rebasing
/// if necessary.
///
/// Asserts `capacity` is within the buffer capacity.
pub fn rebaseCapacity(r: *Reader, capacity: usize) void {
    if (r.end > r.buffer.len - capacity) rebase(r);
}

/// Advances the stream and decreases the size of the storage buffer by `n`,
/// returning the range of bytes no longer accessible by `r`.
///
/// This action can be undone by `restitute`.
///
/// Asserts there are at least `n` buffered bytes already.
///
/// Asserts that `r.seek` is zero, i.e. the buffer is in a rebased state.
pub fn steal(r: *Reader, n: usize) []u8 {
    assert(r.seek == 0);
    assert(n <= r.end);
    const stolen = r.buffer[0..n];
    r.buffer = r.buffer[n..];
    r.end -= n;
    return stolen;
}

/// Expands the storage buffer, undoing the effects of `steal`
/// Assumes that `n` does not exceed the total number of stolen bytes.
pub fn restitute(r: *Reader, n: usize) void {
    r.buffer = (r.buffer.ptr - n)[0 .. r.buffer.len + n];
    r.end += n;
    r.seek += n;
}

test fixed {
    var r: Reader = .fixed("a\x02");
    try testing.expect((try r.takeByte()) == 'a');
    try testing.expect((try r.takeEnum(enum(u8) {
        a = 0,
        b = 99,
        c = 2,
        d = 3,
    }, builtin.cpu.arch.endian())) == .c);
    try testing.expectError(error.EndOfStream, r.takeByte());
}

test peek {
    var r: Reader = .fixed("abc");
    try testing.expectEqualStrings("ab", try r.peek(2));
    try testing.expectEqualStrings("a", try r.peek(1));
}

test peekGreedy {
    var r: Reader = .fixed("abc");
    try testing.expectEqualStrings("abc", try r.peekGreedy(1));
}

test toss {
    var r: Reader = .fixed("abc");
    r.toss(1);
    try testing.expectEqualStrings("bc", r.buffered());
}

test take {
    var r: Reader = .fixed("abc");
    try testing.expectEqualStrings("ab", try r.take(2));
    try testing.expectEqualStrings("c", try r.take(1));
}

test takeArray {
    var r: Reader = .fixed("abc");
    try testing.expectEqualStrings("ab", try r.takeArray(2));
    try testing.expectEqualStrings("c", try r.takeArray(1));
}

test peekArray {
    var r: Reader = .fixed("abc");
    try testing.expectEqualStrings("ab", try r.peekArray(2));
    try testing.expectEqualStrings("a", try r.peekArray(1));
}

test discardAll {
    var r: Reader = .fixed("foobar");
    try r.discardAll(3);
    try testing.expectEqualStrings("bar", try r.take(3));
    try r.discardAll(0);
    try testing.expectError(error.EndOfStream, r.discardAll(1));
}

test discardRemaining {
    var r: Reader = .fixed("foobar");
    r.toss(1);
    try testing.expectEqual(5, try r.discardRemaining());
    try testing.expectEqual(0, try r.discardRemaining());
}

test stream {
    var out_buffer: [10]u8 = undefined;
    var r: Reader = .fixed("foobar");
    var w: Writer = .fixed(&out_buffer);
    // Short streams are possible with this function but not with fixed.
    try testing.expectEqual(2, try r.stream(&w, .limited(2)));
    try testing.expectEqualStrings("fo", w.buffered());
    try testing.expectEqual(4, try r.stream(&w, .unlimited));
    try testing.expectEqualStrings("foobar", w.buffered());
}

test takeSentinel {
    var r: Reader = .fixed("ab\nc");
    try testing.expectEqualStrings("ab", try r.takeSentinel('\n'));
    try testing.expectError(error.EndOfStream, r.takeSentinel('\n'));
    try testing.expectEqualStrings("c", try r.peek(1));
}

test peekSentinel {
    var r: Reader = .fixed("ab\nc");
    try testing.expectEqualStrings("ab", try r.peekSentinel('\n'));
    try testing.expectEqualStrings("ab", try r.peekSentinel('\n'));
}

test takeDelimiterInclusive {
    var r: Reader = .fixed("ab\nc");
    try testing.expectEqualStrings("ab\n", try r.takeDelimiterInclusive('\n'));
    try testing.expectError(error.EndOfStream, r.takeDelimiterInclusive('\n'));
}

test peekDelimiterInclusive {
    var r: Reader = .fixed("ab\nc");
    try testing.expectEqualStrings("ab\n", try r.peekDelimiterInclusive('\n'));
    try testing.expectEqualStrings("ab\n", try r.peekDelimiterInclusive('\n'));
    r.toss(3);
    try testing.expectError(error.EndOfStream, r.peekDelimiterInclusive('\n'));
}

test takeDelimiterExclusive {
    var r: Reader = .fixed("ab\nc");
    try testing.expectEqualStrings("ab", try r.takeDelimiterExclusive('\n'));
    try testing.expectEqualStrings("c", try r.takeDelimiterExclusive('\n'));
    try testing.expectError(error.EndOfStream, r.takeDelimiterExclusive('\n'));
}

test peekDelimiterExclusive {
    var r: Reader = .fixed("ab\nc");
    try testing.expectEqualStrings("ab", try r.peekDelimiterExclusive('\n'));
    try testing.expectEqualStrings("ab", try r.peekDelimiterExclusive('\n'));
    r.toss(3);
    try testing.expectEqualStrings("c", try r.peekDelimiterExclusive('\n'));
}

test streamDelimiter {
    var out_buffer: [10]u8 = undefined;
    var r: Reader = .fixed("foo\nbars");
    var w: Writer = .fixed(&out_buffer);
    try testing.expectEqual(3, try r.streamDelimiter(&w, '\n'));
    try testing.expectEqualStrings("foo", w.buffered());
    try testing.expectEqual(0, try r.streamDelimiter(&w, '\n'));
    r.toss(1);
    try testing.expectError(error.EndOfStream, r.streamDelimiter(&w, '\n'));
}

test streamDelimiterEnding {
    var out_buffer: [10]u8 = undefined;
    var r: Reader = .fixed("foo\nbars");
    var w: Writer = .fixed(&out_buffer);
    try testing.expectEqual(3, try r.streamDelimiterEnding(&w, '\n'));
    try testing.expectEqualStrings("foo", w.buffered());
    r.toss(1);
    try testing.expectEqual(4, try r.streamDelimiterEnding(&w, '\n'));
    try testing.expectEqualStrings("foobars", w.buffered());
    try testing.expectEqual(0, try r.streamDelimiterEnding(&w, '\n'));
    try testing.expectEqual(0, try r.streamDelimiterEnding(&w, '\n'));
}

test streamDelimiterLimit {
    var out_buffer: [10]u8 = undefined;
    var r: Reader = .fixed("foo\nbars");
    var w: Writer = .fixed(&out_buffer);
    try testing.expectError(error.StreamTooLong, r.streamDelimiterLimit(&w, '\n', .limited(2)));
    try testing.expectEqual(1, try r.streamDelimiterLimit(&w, '\n', .limited(3)));
    try testing.expectEqualStrings("\n", try r.take(1));
    try testing.expectEqual(4, try r.streamDelimiterLimit(&w, '\n', .unlimited));
    try testing.expectEqualStrings("foobars", w.buffered());
}

test discardDelimiterExclusive {
    var r: Reader = .fixed("foob\nar");
    try testing.expectEqual(4, try r.discardDelimiterExclusive('\n'));
    try testing.expectEqualStrings("\n", try r.take(1));
    try testing.expectEqual(2, try r.discardDelimiterExclusive('\n'));
    try testing.expectEqual(0, try r.discardDelimiterExclusive('\n'));
}

test discardDelimiterInclusive {
    var r: Reader = .fixed("foob\nar");
    try testing.expectEqual(5, try r.discardDelimiterInclusive('\n'));
    try testing.expectError(error.EndOfStream, r.discardDelimiterInclusive('\n'));
}

test discardDelimiterLimit {
    var r: Reader = .fixed("foob\nar");
    try testing.expectError(error.StreamTooLong, r.discardDelimiterLimit('\n', .limited(4)));
    try testing.expectEqual(0, try r.discardDelimiterLimit('\n', .limited(2)));
    try testing.expectEqualStrings("\n", try r.take(1));
    try testing.expectEqual(2, try r.discardDelimiterLimit('\n', .unlimited));
    try testing.expectEqual(0, try r.discardDelimiterLimit('\n', .unlimited));
}

test fill {
    var r: Reader = .fixed("abc");
    try r.fill(1);
    try r.fill(3);
}

test takeByte {
    var r: Reader = .fixed("ab");
    try testing.expectEqual('a', try r.takeByte());
    try testing.expectEqual('b', try r.takeByte());
    try testing.expectError(error.EndOfStream, r.takeByte());
}

test takeByteSigned {
    var r: Reader = .fixed(&.{ 255, 5 });
    try testing.expectEqual(-1, try r.takeByteSigned());
    try testing.expectEqual(5, try r.takeByteSigned());
    try testing.expectError(error.EndOfStream, r.takeByteSigned());
}

test takeInt {
    var r: Reader = .fixed(&.{ 0x12, 0x34, 0x56 });
    try testing.expectEqual(0x1234, try r.takeInt(u16, .big));
    try testing.expectError(error.EndOfStream, r.takeInt(u16, .little));
}

test takeVarInt {
    var r: Reader = .fixed(&.{ 0x12, 0x34, 0x56 });
    try testing.expectEqual(0x123456, try r.takeVarInt(u64, .big, 3));
    try testing.expectError(error.EndOfStream, r.takeVarInt(u16, .little, 1));
}

test takeStruct {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    switch (native_endian) {
        .little => try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), (try r.takeStruct(S)).*),
        .big => try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), (try r.takeStruct(S)).*),
    }
    try testing.expectError(error.EndOfStream, r.takeStruct(S));
}

test peekStruct {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    switch (native_endian) {
        .little => {
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), (try r.peekStruct(S)).*);
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), (try r.peekStruct(S)).*);
        },
        .big => {
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), (try r.peekStruct(S)).*);
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), (try r.peekStruct(S)).*);
        },
    }
}

test takeStructEndian {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), try r.takeStructEndian(S, .big));
    try testing.expectError(error.EndOfStream, r.takeStructEndian(S, .little));
}

test peekStructEndian {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), try r.peekStructEndian(S, .big));
    try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), try r.peekStructEndian(S, .little));
}

test takeEnum {
    var r: Reader = .fixed(&.{ 2, 0, 1 });
    const E1 = enum(u8) { a, b, c };
    const E2 = enum(u16) { _ };
    try testing.expectEqual(E1.c, try r.takeEnum(E1, .little));
    try testing.expectEqual(@as(E2, @enumFromInt(0x0001)), try r.takeEnum(E2, .big));
}

test takeLeb128 {
    var r: Reader = .fixed("\xc7\x9f\x7f\x80");
    try testing.expectEqual(-12345, try r.takeLeb128(i64));
    try testing.expectEqual(0x80, try r.peekByte());
    try testing.expectError(error.EndOfStream, r.takeLeb128(i64));
}

test readSliceShort {
    var r: Reader = .fixed("HelloFren");
    var buf: [5]u8 = undefined;
    try testing.expectEqual(5, try r.readSliceShort(&buf));
    try testing.expectEqualStrings("Hello", buf[0..5]);
    try testing.expectEqual(4, try r.readSliceShort(&buf));
    try testing.expectEqualStrings("Fren", buf[0..4]);
    try testing.expectEqual(0, try r.readSliceShort(&buf));
}

test readVec {
    var r: Reader = .fixed(std.ascii.letters);
    var flat_buffer: [52]u8 = undefined;
    var bufs: [2][]u8 = .{
        flat_buffer[0..26],
        flat_buffer[26..],
    };
    // Short reads are possible with this function but not with fixed.
    try testing.expectEqual(26 * 2, try r.readVec(&bufs));
    try testing.expectEqualStrings(std.ascii.letters[0..26], bufs[0]);
    try testing.expectEqualStrings(std.ascii.letters[26..], bufs[1]);
}

test readVecLimit {
    var r: Reader = .fixed(std.ascii.letters);
    var flat_buffer: [52]u8 = undefined;
    var bufs: [2][]u8 = .{
        flat_buffer[0..26],
        flat_buffer[26..],
    };
    // Short reads are possible with this function but not with fixed.
    try testing.expectEqual(50, try r.readVecLimit(&bufs, .limited(50)));
    try testing.expectEqualStrings(std.ascii.letters[0..26], bufs[0]);
    try testing.expectEqualStrings(std.ascii.letters[26..50], bufs[1][0..24]);
}

test "expected error.EndOfStream" {
    // Unit test inspired by https://github.com/ziglang/zig/issues/17733
    var buffer: [3]u8 = undefined;
    var r: std.io.Reader = .fixed(&buffer);
    r.end = 0; // capacity 3, but empty
    try std.testing.expectError(error.EndOfStream, r.takeEnum(enum(u8) { a, b }, .little));
    try std.testing.expectError(error.EndOfStream, r.take(3));
}

fn endingStream(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
    _ = r;
    _ = w;
    _ = limit;
    return error.EndOfStream;
}

fn endingDiscard(r: *Reader, limit: Limit) Error!usize {
    _ = r;
    _ = limit;
    return error.EndOfStream;
}

fn failingStream(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
    _ = r;
    _ = w;
    _ = limit;
    return error.ReadFailed;
}

fn failingDiscard(r: *Reader, limit: Limit) Error!usize {
    _ = r;
    _ = limit;
    return error.ReadFailed;
}

test "readAlloc when the backing reader provides one byte at a time" {
    const OneByteReader = struct {
        str: []const u8,
        i: usize,
        reader: Reader,

        fn stream(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
            assert(@intFromEnum(limit) >= 1);
            const self: *@This() = @fieldParentPtr("reader", r);
            if (self.str.len - self.i == 0) return error.EndOfStream;
            try w.writeByte(self.str[self.i]);
            self.i += 1;
            return 1;
        }
    };
    const str = "This is a test";
    var one_byte_stream: OneByteReader = .{
        .str = str,
        .i = 0,
        .reader = .{
            .buffer = &.{},
            .vtable = &.{ .stream = OneByteReader.stream },
            .seek = 0,
            .end = 0,
        },
    };
    const res = try one_byte_stream.reader.allocRemaining(std.testing.allocator, .unlimited);
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
        in: *Reader,
        hasher: Hasher,
        interface: Reader,

        pub fn init(in: *Reader, hasher: Hasher, buffer: []u8) @This() {
            return .{
                .in = in,
                .hasher = hasher,
                .interface = .{
                    .vtable = &.{
                        .read = @This().read,
                        .discard = @This().discard,
                    },
                    .buffer = buffer,
                    .end = 0,
                    .seek = 0,
                },
            };
        }

        fn read(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("interface", r));
            const data = w.writableVector(limit);
            const n = try this.in.readVec(data);
            const result = w.advanceVector(n);
            var remaining: usize = n;
            for (data) |slice| {
                if (remaining < slice.len) {
                    this.hasher.update(slice[0..remaining]);
                    return result;
                } else {
                    remaining -= slice.len;
                    this.hasher.update(slice);
                }
            }
            assert(remaining == 0);
            return result;
        }

        fn discard(r: *Reader, limit: Limit) Error!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("interface", r));
            var w = this.hasher.writer(&.{});
            const n = this.in.stream(&w, limit) catch |err| switch (err) {
                error.WriteFailed => unreachable,
                else => |e| return e,
            };
            return n;
        }
    };
}
