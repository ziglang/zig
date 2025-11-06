const Reader = @This();

const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const std = @import("../std.zig");
const Writer = std.Io.Writer;
const Limit = std.Io.Limit;
const assert = std.debug.assert;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

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
    /// end of stream.
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
    ///
    /// In addition to, or instead of writing to `w`, the implementation may
    /// choose to store data in `buffer`, modifying `seek` and `end`
    /// accordingly. Implementations are encouraged to take advantage of
    /// this if it simplifies the logic.
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
    ///
    /// This function is only called when `buffer` is empty.
    discard: *const fn (r: *Reader, limit: Limit) Error!usize = defaultDiscard,

    /// Returns number of bytes written to `data`.
    ///
    /// `data` must have nonzero length. `data[0]` may have zero length, in
    /// which case the implementation must write to `Reader.buffer`.
    ///
    /// `data` may not contain an alias to `Reader.buffer`.
    ///
    /// `data` is mutable because the implementation may temporarily modify the
    /// fields in order to handle partial reads. Implementations must restore
    /// the original value before returning.
    ///
    /// Implementations may ignore `data`, writing directly to `Reader.buffer`,
    /// modifying `seek` and `end` accordingly, and returning 0 from this
    /// function. Implementations are encouraged to take advantage of this if
    /// it simplifies the logic.
    ///
    /// The default implementation calls `stream` with either `data[0]` or
    /// `Reader.buffer`, whichever is bigger.
    readVec: *const fn (r: *Reader, data: [][]u8) Error!usize = defaultReadVec,

    /// Ensures `capacity` data can be buffered without rebasing.
    ///
    /// Asserts `capacity` is within buffer capacity, or that the stream ends
    /// within `capacity` bytes.
    ///
    /// Only called when `capacity` cannot be satisfied by unused capacity of
    /// `buffer`.
    ///
    /// The default implementation moves buffered data to the start of
    /// `buffer`, setting `seek` to zero, and cannot fail.
    rebase: *const fn (r: *Reader, capacity: usize) RebaseError!void = defaultRebase,
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

pub const RebaseError = error{
    EndOfStream,
};

pub const failing: Reader = .{
    .vtable = &.{
        .stream = failingStream,
        .discard = failingDiscard,
    },
    .buffer = &.{},
    .seek = 0,
    .end = 0,
};

/// This is generally safe to `@constCast` because it has an empty buffer, so
/// there is not really a way to accidentally attempt mutation of these fields.
pub const ending_instance: Reader = .fixed(&.{});
pub const ending: *Reader = @constCast(&ending_instance);

pub fn limited(r: *Reader, limit: Limit, buffer: []u8) Limited {
    return .init(r, limit, buffer);
}

/// Constructs a `Reader` such that it will read from `buffer` and then end.
pub fn fixed(buffer: []const u8) Reader {
    return .{
        .vtable = &.{
            .stream = endingStream,
            .discard = endingDiscard,
            .readVec = endingReadVec,
            .rebase = endingRebase,
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
    const n = try r.vtable.stream(r, w, limit);
    assert(n <= @intFromEnum(limit));
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
    r.seek = r.end;
    const n = try r.vtable.discard(r, remaining);
    assert(n <= @intFromEnum(remaining));
    return buffered_len + n;
}

pub fn defaultDiscard(r: *Reader, limit: Limit) Error!usize {
    assert(r.seek == r.end);
    r.seek = 0;
    r.end = 0;
    var d: Writer.Discarding = .init(r.buffer);
    const n = r.stream(&d.writer, limit) catch |err| switch (err) {
        error.WriteFailed => unreachable,
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => return error.EndOfStream,
    };
    assert(n <= @intFromEnum(limit));
    return n;
}

/// "Pump" exactly `n` bytes from the reader to the writer.
pub fn streamExact(r: *Reader, w: *Writer, n: usize) StreamError!void {
    var remaining = n;
    while (remaining != 0) remaining -= try r.stream(w, .limited(remaining));
}

/// "Pump" exactly `n` bytes from the reader to the writer.
pub fn streamExact64(r: *Reader, w: *Writer, n: u64) StreamError!void {
    var remaining = n;
    while (remaining != 0) remaining -= try r.stream(w, .limited64(remaining));
}

/// "Pump" exactly `n` bytes from the reader to the writer.
///
/// When draining `w`, ensures that at least `preserve_len` bytes remain
/// buffered.
///
/// Asserts `Writer.buffer` capacity exceeds `preserve_len`.
pub fn streamExactPreserve(r: *Reader, w: *Writer, preserve_len: usize, n: usize) StreamError!void {
    if (w.end + n <= w.buffer.len) {
        @branchHint(.likely);
        return streamExact(r, w, n);
    }
    // If `n` is large, we can ignore `preserve_len` up to a point.
    var remaining = n;
    while (remaining > preserve_len) {
        assert(remaining != 0);
        remaining -= try r.stream(w, .limited(remaining - preserve_len));
        if (w.end + remaining <= w.buffer.len) return streamExact(r, w, remaining);
    }
    // All the next bytes received must be preserved.
    if (preserve_len < w.end) {
        @memmove(w.buffer[0..preserve_len], w.buffer[w.end - preserve_len ..][0..preserve_len]);
        w.end = preserve_len;
    }
    return streamExact(r, w, remaining);
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
    r.seek = r.end;
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
/// See also:
/// * `appendRemaining`
pub fn allocRemaining(r: *Reader, gpa: Allocator, limit: Limit) LimitedAllocError![]u8 {
    var buffer: ArrayList(u8) = .empty;
    defer buffer.deinit(gpa);
    try appendRemaining(r, gpa, &buffer, limit);
    return buffer.toOwnedSlice(gpa);
}

pub fn allocRemainingAlignedSentinel(
    r: *Reader,
    gpa: Allocator,
    limit: Limit,
    comptime alignment: std.mem.Alignment,
    comptime sentinel: ?u8,
) LimitedAllocError!(if (sentinel) |s| [:s]align(alignment.toByteUnits()) u8 else []align(alignment.toByteUnits()) u8) {
    var buffer: std.array_list.Aligned(u8, alignment) = .empty;
    defer buffer.deinit(gpa);
    try appendRemainingAligned(r, gpa, alignment, &buffer, limit);
    if (sentinel) |s| {
        return buffer.toOwnedSliceSentinel(gpa, s);
    } else {
        return buffer.toOwnedSlice(gpa);
    }
}

/// Transfers all bytes from the current position to the end of the stream, up
/// to `limit`, appending them to `list`.
///
/// If `limit` is reached or exceeded, `error.StreamTooLong` is returned
/// instead. In such case, the next byte that would be read will be the first
/// one to exceed `limit`, and all preceeding bytes have been appended to
/// `list`.
///
/// See also:
/// * `allocRemaining`
pub fn appendRemaining(
    r: *Reader,
    gpa: Allocator,
    list: *ArrayList(u8),
    limit: Limit,
) LimitedAllocError!void {
    return appendRemainingAligned(r, gpa, .of(u8), list, limit);
}

/// Transfers all bytes from the current position to the end of the stream, up
/// to `limit`, appending them to `list`.
///
/// If `limit` is reached or exceeded, `error.StreamTooLong` is returned
/// instead. In such case, the next byte that would be read will be the first
/// one to exceed `limit`, and all preceeding bytes have been appended to
/// `list`.
///
/// See also:
/// * `appendRemaining`
/// * `allocRemainingAligned`
pub fn appendRemainingAligned(
    r: *Reader,
    gpa: Allocator,
    comptime alignment: std.mem.Alignment,
    list: *std.array_list.Aligned(u8, alignment),
    limit: Limit,
) LimitedAllocError!void {
    var a = std.Io.Writer.Allocating.fromArrayListAligned(gpa, alignment, list);
    defer list.* = a.toArrayListAligned(alignment);

    var remaining = limit;
    while (remaining.nonzero()) {
        const n = stream(r, &a.writer, remaining) catch |err| switch (err) {
            error.EndOfStream => return,
            error.WriteFailed => return error.OutOfMemory,
            error.ReadFailed => return error.ReadFailed,
        };
        remaining = remaining.subtract(n).?;
    }
    return error.StreamTooLong;
}

pub const UnlimitedAllocError = Allocator.Error || ShortError;

pub fn appendRemainingUnlimited(r: *Reader, gpa: Allocator, list: *ArrayList(u8)) UnlimitedAllocError!void {
    var a: std.Io.Writer.Allocating = .initOwnedSlice(gpa, list.allocatedSlice());
    a.writer.end = list.items.len;
    list.* = .empty;
    defer {
        list.* = .{
            .items = a.writer.buffer[0..a.writer.end],
            .capacity = a.writer.buffer.len,
        };
    }
    _ = streamRemaining(r, &a.writer) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        error.ReadFailed => return error.ReadFailed,
    };
}

/// Writes bytes from the internally tracked stream position to `data`.
///
/// Returns the number of bytes written, which will be at minimum `0` and
/// at most the sum of each data slice length. The number of bytes read,
/// including zero, does not indicate end of stream.
///
/// The reader's internal logical seek position moves forward in accordance
/// with the number of bytes returned from this function.
pub fn readVec(r: *Reader, data: [][]u8) Error!usize {
    var seek = r.seek;
    for (data, 0..) |buf, i| {
        const contents = r.buffer[seek..r.end];
        const copy_len = @min(contents.len, buf.len);
        @memcpy(buf[0..copy_len], contents[0..copy_len]);
        seek += copy_len;
        if (buf.len - copy_len == 0) continue;

        // All of `buffer` has been copied to `data`.
        const n = seek - r.seek;
        r.seek = seek;
        data[i] = buf[copy_len..];
        defer data[i] = buf;
        return n + (r.vtable.readVec(r, data[i..]) catch |err| switch (err) {
            error.EndOfStream => if (n == 0) return error.EndOfStream else 0,
            error.ReadFailed => return error.ReadFailed,
        });
    }
    const n = seek - r.seek;
    r.seek = seek;
    return n;
}

/// Writes to `Reader.buffer` or `data`, whichever has larger capacity.
pub fn defaultReadVec(r: *Reader, data: [][]u8) Error!usize {
    const first = data[0];
    if (first.len >= r.buffer.len - r.end) {
        var writer: Writer = .{
            .buffer = first,
            .end = 0,
            .vtable = &.{ .drain = Writer.fixedDrain },
        };
        const limit: Limit = .limited(writer.buffer.len - writer.end);
        return r.vtable.stream(r, &writer, limit) catch |err| switch (err) {
            error.WriteFailed => unreachable,
            else => |e| return e,
        };
    }
    var writer: Writer = .{
        .buffer = r.buffer,
        .end = r.end,
        .vtable = &.{ .drain = Writer.fixedDrain },
    };
    const limit: Limit = .limited(writer.buffer.len - writer.end);
    const n = r.vtable.stream(r, &writer, limit) catch |err| switch (err) {
        error.WriteFailed => unreachable,
        else => |e| return e,
    };
    r.end += n;
    return 0;
}

pub fn buffered(r: *Reader) []u8 {
    return r.buffer[r.seek..r.end];
}

pub fn bufferedLen(r: *const Reader) usize {
    return r.end - r.seek;
}

pub fn hashed(r: *Reader, hasher: anytype, buffer: []u8) Hashed(@TypeOf(hasher)) {
    return .init(r, hasher, buffer);
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

/// Returns the next `n` bytes from the stream, filling the buffer as
/// necessary.
///
/// Invalidates previously returned values from `peek`.
///
/// Asserts that the `Reader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
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
    r.seek = r.end;
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
    r.seek = r.end;
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
    const contents = r.buffer[r.seek..r.end];
    const copy_len = @min(buffer.len, contents.len);
    @memcpy(buffer[0..copy_len], contents[0..copy_len]);
    r.seek += copy_len;
    if (buffer.len - copy_len == 0) {
        @branchHint(.likely);
        return buffer.len;
    }
    var i: usize = copy_len;
    var data: [1][]u8 = undefined;
    while (true) {
        data[0] = buffer[i..];
        i += readVec(r, &data) catch |err| switch (err) {
            error.EndOfStream => return i,
            error.ReadFailed => return error.ReadFailed,
        };
        if (buffer.len - i == 0) return buffer.len;
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
/// `sentinel` is found, advancing the seek position past the sentinel.
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
/// `delimiter` is found, advancing the seek position past the delimiter.
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
    {
        const contents = r.buffer[0..r.end];
        const seek = r.seek;
        if (std.mem.findScalarPos(u8, contents, seek, delimiter)) |end| {
            @branchHint(.likely);
            return contents[seek .. end + 1];
        }
    }
    while (true) {
        const content_len = r.end - r.seek;
        if (r.buffer.len - content_len == 0) break;
        try fillMore(r);
        const seek = r.seek;
        const contents = r.buffer[0..r.end];
        if (std.mem.findScalarPos(u8, contents, seek + content_len, delimiter)) |end| {
            return contents[seek .. end + 1];
        }
    }
    // It might or might not be end of stream. There is no more buffer space
    // left to disambiguate. If `StreamTooLong` was added to `RebaseError` then
    // this logic could be replaced by removing the exit condition from the
    // above while loop. That error code would represent when `buffer` capacity
    // is too small for an operation, replacing the current use of asserts.
    var failing_writer = Writer.failing;
    while (r.vtable.stream(r, &failing_writer, .limited(1))) |n| {
        assert(n == 0);
    } else |err| switch (err) {
        error.WriteFailed => return error.StreamTooLong,
        error.ReadFailed => |e| return e,
        error.EndOfStream => |e| return e,
    }
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position up to (but not past)
/// the delimiter.
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
/// * `takeDelimiter`
/// * `takeDelimiterInclusive`
/// * `peekDelimiterExclusive`
pub fn takeDelimiterExclusive(r: *Reader, delimiter: u8) DelimiterError![]u8 {
    const result = try r.peekDelimiterExclusive(delimiter);
    r.toss(result.len);
    return result;
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position past the delimiter.
///
/// Returned slice excludes the delimiter. End-of-stream is treated equivalent
/// to a delimiter, unless it would result in a length 0 return value, in which
/// case `null` is returned instead.
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
/// * `takeDelimiterExclusive`
pub fn takeDelimiter(r: *Reader, delimiter: u8) error{ ReadFailed, StreamTooLong }!?[]u8 {
    const inclusive = r.peekDelimiterInclusive(delimiter) catch |err| switch (err) {
        error.EndOfStream => {
            const remaining = r.buffer[r.seek..r.end];
            if (remaining.len == 0) return null;
            r.toss(remaining.len);
            return remaining;
        },
        else => |e| return e,
    };
    r.toss(inclusive.len);
    return inclusive[0 .. inclusive.len - 1];
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
            return remaining;
        },
        else => |e| return e,
    };
    return result[0 .. result.len - 1];
}

/// Appends to `w` contents by reading from the stream until `delimiter` is
/// found. Does not write the delimiter itself.
///
/// Does not discard the delimiter from the `Reader`.
///
/// Returns number of bytes streamed, which may be zero, or error.EndOfStream
/// if the delimiter was not found.
///
/// Asserts buffer capacity of at least one. This function performs better with
/// larger buffers.
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
/// Returns number of bytes streamed, which may be zero. If the stream reaches
/// the end, the reader buffer will be empty when this function returns.
/// Otherwise, it will have at least one byte buffered, starting with the
/// delimiter.
///
/// Asserts buffer capacity of at least one. This function performs better with
/// larger buffers.
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
/// Does not discard the delimiter from the `Reader`.
///
/// Returns number of bytes streamed, which may be zero. End of stream can be
/// detected by checking if the next byte in the stream is the delimiter.
///
/// Asserts buffer capacity of at least one. This function performs better with
/// larger buffers.
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
/// If the end of stream is not encountered, asserts buffer capacity is at
/// least `n`.
pub fn fill(r: *Reader, n: usize) Error!void {
    if (r.seek + n <= r.end) {
        @branchHint(.likely);
        return;
    }
    return fillUnbuffered(r, n);
}

/// This internal function is separated from `fill` to encourage optimizers to inline `fill`, hence
/// propagating its `@branchHint` to usage sites. If these functions are combined, `fill` is large
/// enough that LLVM is reluctant to inline it, forcing usages of APIs like `takeInt` to go through
/// an expensive runtime function call just to figure out that the data is, in fact, already in the
/// buffer.
///
/// Missing this optimization can result in wall-clock time for the most affected benchmarks
/// increasing by a factor of 5 or more.
fn fillUnbuffered(r: *Reader, n: usize) Error!void {
    try rebase(r, n);
    var bufs: [1][]u8 = .{""};
    while (r.end < r.seek + n) _ = try r.vtable.readVec(r, &bufs);
}

/// Without advancing the seek position, does exactly one underlying read, filling the buffer as
/// much as possible. This may result in zero bytes added to the buffer, which is not an end of
/// stream condition. End of stream is communicated via returning `error.EndOfStream`.
///
/// Asserts buffer capacity is at least 1.
pub fn fillMore(r: *Reader) Error!void {
    try rebase(r, r.end - r.seek + 1);
    var bufs: [1][]u8 = .{""};
    _ = try r.vtable.readVec(r, &bufs);
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

/// Asserts the buffer was initialized with a capacity at least `@bitSizeOf(T) / 8`.
pub inline fn peekInt(r: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    return std.mem.readInt(T, try r.peekArray(n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `n`.
pub fn takeVarInt(r: *Reader, comptime Int: type, endian: std.builtin.Endian, n: usize) Error!Int {
    assert(n <= @sizeOf(Int));
    return std.mem.readVarInt(Int, try r.take(n), endian);
}

/// Obtains an unaligned pointer to the beginning of the stream, reinterpreted
/// as a pointer to the provided type, advancing the seek position.
///
/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// See also:
/// * `peekStructPointer`
/// * `takeStruct`
pub fn takeStructPointer(r: *Reader, comptime T: type) Error!*align(1) T {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(T).@"struct".layout != .auto);
    return @ptrCast(try r.takeArray(@sizeOf(T)));
}

/// Obtains an unaligned pointer to the beginning of the stream, reinterpreted
/// as a pointer to the provided type, without advancing the seek position.
///
/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// See also:
/// * `takeStructPointer`
/// * `peekStruct`
pub fn peekStructPointer(r: *Reader, comptime T: type) Error!*align(1) T {
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
/// * `takeStructPointer`
/// * `peekStruct`
pub inline fn takeStruct(r: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
    switch (@typeInfo(T)) {
        .@"struct" => |info| switch (info.layout) {
            .auto => @compileError("ill-defined memory layout"),
            .@"extern" => {
                var res = (try r.takeStructPointer(T)).*;
                if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
                return res;
            },
            .@"packed" => {
                return @bitCast(try takeInt(r, info.backing_integer.?, endian));
            },
        },
        else => @compileError("not a struct"),
    }
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// This function is inline to avoid referencing `std.mem.byteSwapAllFields`
/// when `endian` is comptime-known and matches the host endianness.
///
/// See also:
/// * `takeStruct`
/// * `peekStructPointer`
pub inline fn peekStruct(r: *Reader, comptime T: type, endian: std.builtin.Endian) Error!T {
    switch (@typeInfo(T)) {
        .@"struct" => |info| switch (info.layout) {
            .auto => @compileError("ill-defined memory layout"),
            .@"extern" => {
                var res = (try r.peekStructPointer(T)).*;
                if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
                return res;
            },
            .@"packed" => {
                return @bitCast(try peekInt(r, info.backing_integer.?, endian));
            },
        },
        else => @compileError("not a struct"),
    }
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

/// Ensures `capacity` data can be buffered without rebasing.
pub fn rebase(r: *Reader, capacity: usize) RebaseError!void {
    if (r.buffer.len - r.seek >= capacity) {
        @branchHint(.likely);
        return;
    }
    return r.vtable.rebase(r, capacity);
}

pub fn defaultRebase(r: *Reader, capacity: usize) RebaseError!void {
    assert(r.buffer.len - r.seek < capacity);
    const data = r.buffer[r.seek..r.end];
    @memmove(r.buffer[0..data.len], data);
    r.seek = 0;
    r.end = data.len;
    assert(r.buffer.len - r.seek >= capacity);
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
    r.toss(3);
    try testing.expectError(error.EndOfStream, r.peekSentinel('\n'));
    try testing.expectEqualStrings("c", try r.peek(1));
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
    try testing.expectEqualStrings("c", try r.peek(1));
}

test takeDelimiterExclusive {
    var r: Reader = .fixed("ab\nc");

    try testing.expectEqualStrings("ab", try r.takeDelimiterExclusive('\n'));
    try testing.expectEqualStrings("", try r.takeDelimiterExclusive('\n'));
    try testing.expectEqualStrings("", try r.takeDelimiterExclusive('\n'));
    try testing.expectEqualStrings("\n", try r.take(1));

    try testing.expectEqualStrings("c", try r.takeDelimiterExclusive('\n'));
    try testing.expectError(error.EndOfStream, r.takeDelimiterExclusive('\n'));
}

test peekDelimiterExclusive {
    var r: Reader = .fixed("ab\nc");

    try testing.expectEqualStrings("ab", try r.peekDelimiterExclusive('\n'));
    try testing.expectEqualStrings("ab", try r.peekDelimiterExclusive('\n'));
    r.toss(2);
    try testing.expectEqualStrings("", try r.peekDelimiterExclusive('\n'));
    try testing.expectEqualStrings("\n", try r.take(1));

    try testing.expectEqualStrings("c", try r.peekDelimiterExclusive('\n'));
    try testing.expectEqualStrings("c", try r.peekDelimiterExclusive('\n'));
    r.toss(1);
    try testing.expectError(error.EndOfStream, r.peekDelimiterExclusive('\n'));
}

test takeDelimiter {
    var r: Reader = .fixed("ab\nc\n\nd");
    try testing.expectEqualStrings("ab", (try r.takeDelimiter('\n')).?);
    try testing.expectEqualStrings("c", (try r.takeDelimiter('\n')).?);
    try testing.expectEqualStrings("", (try r.takeDelimiter('\n')).?);
    try testing.expectEqualStrings("d", (try r.takeDelimiter('\n')).?);
    try testing.expectEqual(null, try r.takeDelimiter('\n'));
    try testing.expectEqual(null, try r.takeDelimiter('\n'));

    r = .fixed("ab\nc\n\nd\n"); // one trailing newline does not affect behavior
    try testing.expectEqualStrings("ab", (try r.takeDelimiter('\n')).?);
    try testing.expectEqualStrings("c", (try r.takeDelimiter('\n')).?);
    try testing.expectEqualStrings("", (try r.takeDelimiter('\n')).?);
    try testing.expectEqualStrings("d", (try r.takeDelimiter('\n')).?);
    try testing.expectEqual(null, try r.takeDelimiter('\n'));
    try testing.expectEqual(null, try r.takeDelimiter('\n'));
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

test takeStructPointer {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    switch (native_endian) {
        .little => try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), (try r.takeStructPointer(S)).*),
        .big => try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), (try r.takeStructPointer(S)).*),
    }
    try testing.expectError(error.EndOfStream, r.takeStructPointer(S));
}

test peekStructPointer {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    switch (native_endian) {
        .little => {
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), (try r.peekStructPointer(S)).*);
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), (try r.peekStructPointer(S)).*);
        },
        .big => {
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), (try r.peekStructPointer(S)).*);
            try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), (try r.peekStructPointer(S)).*);
        },
    }
}

test takeStruct {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), try r.takeStruct(S, .big));
    try testing.expectError(error.EndOfStream, r.takeStruct(S, .little));
}

test peekStruct {
    var r: Reader = .fixed(&.{ 0x12, 0x00, 0x34, 0x56 });
    const S = extern struct { a: u8, b: u16 };
    try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x3456 }), try r.peekStruct(S, .big));
    try testing.expectEqual(@as(S, .{ .a = 0x12, .b = 0x5634 }), try r.peekStruct(S, .little));
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

test "readSliceShort with smaller buffer than Reader" {
    var reader_buf: [15]u8 = undefined;
    const str = "This is a test";
    var one_byte_stream: testing.Reader = .init(&reader_buf, &.{
        .{ .buffer = str },
    });
    one_byte_stream.artificial_limit = .limited(1);

    var buf: [14]u8 = undefined;
    try testing.expectEqual(14, try one_byte_stream.interface.readSliceShort(&buf));
    try testing.expectEqualStrings(str, &buf);
}

test "readSliceShort with indirect reader" {
    var r: Reader = .fixed("HelloFren");
    var ri_buf: [3]u8 = undefined;
    var ri: std.testing.ReaderIndirect = .init(&r, &ri_buf);
    var buf: [5]u8 = undefined;
    try testing.expectEqual(5, try ri.interface.readSliceShort(&buf));
    try testing.expectEqualStrings("Hello", buf[0..5]);
    try testing.expectEqual(4, try ri.interface.readSliceShort(&buf));
    try testing.expectEqualStrings("Fren", buf[0..4]);
    try testing.expectEqual(0, try ri.interface.readSliceShort(&buf));
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

test "expected error.EndOfStream" {
    // Unit test inspired by https://github.com/ziglang/zig/issues/17733
    var buffer: [3]u8 = undefined;
    var r: std.Io.Reader = .fixed(&buffer);
    r.end = 0; // capacity 3, but empty
    try std.testing.expectError(error.EndOfStream, r.takeEnum(enum(u8) { a, b }, .little));
    try std.testing.expectError(error.EndOfStream, r.take(3));
}

test "readVec at end" {
    var reader_buffer: [8]u8 = "abcd1234".*;
    var reader: testing.Reader = .init(&reader_buffer, &.{});
    reader.interface.end = reader_buffer.len;

    var out: [16]u8 = undefined;
    var vecs: [1][]u8 = .{&out};
    try testing.expectEqual(8, try reader.interface.readVec(&vecs));
    try testing.expectEqualStrings("abcd1234", vecs[0][0..8]);
}

fn endingStream(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
    _ = r;
    _ = w;
    _ = limit;
    return error.EndOfStream;
}

fn endingReadVec(r: *Reader, data: [][]u8) Error!usize {
    _ = r;
    _ = data;
    return error.EndOfStream;
}

fn endingDiscard(r: *Reader, limit: Limit) Error!usize {
    _ = r;
    _ = limit;
    return error.EndOfStream;
}

fn endingRebase(r: *Reader, capacity: usize) RebaseError!void {
    _ = r;
    _ = capacity;
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
    const str = "This is a test";
    var tiny_buffer: [1]u8 = undefined;
    var one_byte_stream: testing.Reader = .init(&tiny_buffer, &.{
        .{ .buffer = str },
    });
    one_byte_stream.artificial_limit = .limited(1);
    const res = try one_byte_stream.interface.allocRemaining(std.testing.allocator, .unlimited);
    defer std.testing.allocator.free(res);
    try std.testing.expectEqualStrings(str, res);
}

test "takeDelimiterInclusive when it rebases" {
    const written_line = "ABCDEFGHIJKLMNOPQRSTUVWXYZ\n";
    var buffer: [128]u8 = undefined;
    var tr: std.testing.Reader = .init(&buffer, &.{
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
    });
    const r = &tr.interface;
    for (0..6) |_| {
        try std.testing.expectEqualStrings(written_line, try r.takeDelimiterInclusive('\n'));
    }
}

test "takeDelimiterInclusive on an indirect reader when it rebases" {
    const written_line = "ABCDEFGHIJKLMNOPQRSTUVWXYZ\n";
    var buffer: [128]u8 = undefined;
    var tr: std.testing.Reader = .init(&buffer, &.{
        .{ .buffer = written_line[0..4] },
        .{ .buffer = written_line[4..] },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
        .{ .buffer = written_line },
    });
    var indirect_buffer: [128]u8 = undefined;
    var tri: std.testing.ReaderIndirect = .init(&tr.interface, &indirect_buffer);
    const r = &tri.interface;
    for (0..6) |_| {
        try std.testing.expectEqualStrings(written_line, try r.takeDelimiterInclusive('\n'));
    }
}

test "takeStruct and peekStruct packed" {
    var r: Reader = .fixed(&.{ 0b11110000, 0b00110011 });
    const S = packed struct(u16) { a: u2, b: u6, c: u7, d: u1 };

    try testing.expectEqual(@as(S, .{
        .a = 0b11,
        .b = 0b001100,
        .c = 0b1110000,
        .d = 0b1,
    }), try r.peekStruct(S, .big));

    try testing.expectEqual(@as(S, .{
        .a = 0b11,
        .b = 0b001100,
        .c = 0b1110000,
        .d = 0b1,
    }), try r.takeStruct(S, .big));

    try testing.expectError(error.EndOfStream, r.takeStruct(S, .little));
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
        reader: Reader,

        pub fn init(in: *Reader, hasher: Hasher, buffer: []u8) @This() {
            return .{
                .in = in,
                .hasher = hasher,
                .reader = .{
                    .vtable = &.{
                        .stream = @This().stream,
                        .readVec = @This().readVec,
                        .discard = @This().discard,
                    },
                    .buffer = buffer,
                    .end = 0,
                    .seek = 0,
                },
            };
        }

        fn stream(r: *Reader, w: *Writer, limit: Limit) StreamError!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("reader", r));
            const data = limit.slice(try w.writableSliceGreedy(1));
            var vec: [1][]u8 = .{data};
            const n = try this.in.readVec(&vec);
            this.hasher.update(data[0..n]);
            w.advance(n);
            return n;
        }

        fn readVec(r: *Reader, data: [][]u8) Error!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("reader", r));
            var vecs: [8][]u8 = undefined; // Arbitrarily chosen amount.
            const dest_n, const data_size = try r.writableVector(&vecs, data);
            const dest = vecs[0..dest_n];
            const n = try this.in.readVec(dest);
            var remaining: usize = n;
            for (dest) |slice| {
                if (remaining < slice.len) {
                    this.hasher.update(slice[0..remaining]);
                    remaining = 0;
                    break;
                } else {
                    remaining -= slice.len;
                    this.hasher.update(slice);
                }
            }
            assert(remaining == 0);
            if (n > data_size) {
                r.end += n - data_size;
                return data_size;
            }
            return n;
        }

        fn discard(r: *Reader, limit: Limit) Error!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("reader", r));
            const peeked = limit.slice(try this.in.peekGreedy(1));
            this.hasher.update(peeked);
            this.in.toss(peeked.len);
            return peeked.len;
        }
    };
}

pub fn writableVectorPosix(r: *Reader, buffer: []std.posix.iovec, data: []const []u8) Error!struct { usize, usize } {
    var i: usize = 0;
    var n: usize = 0;
    if (r.seek == r.end) {
        for (data) |buf| {
            if (buffer.len - i == 0) return .{ i, n };
            if (buf.len != 0) {
                buffer[i] = .{ .base = buf.ptr, .len = buf.len };
                i += 1;
                n += buf.len;
            }
        }
        const buf = r.buffer;
        if (buf.len != 0) {
            r.seek = 0;
            r.end = 0;
            buffer[i] = .{ .base = buf.ptr, .len = buf.len };
            i += 1;
        }
    } else {
        const buf = r.buffer[r.end..];
        buffer[i] = .{ .base = buf.ptr, .len = buf.len };
        i += 1;
    }
    return .{ i, n };
}

pub fn writableVectorWsa(
    r: *Reader,
    buffer: []std.os.windows.ws2_32.WSABUF,
    data: []const []u8,
) Error!struct { usize, usize } {
    var i: usize = 0;
    var n: usize = 0;
    if (r.seek == r.end) {
        for (data) |buf| {
            if (buffer.len - i == 0) return .{ i, n };
            if (buf.len == 0) continue;
            if (std.math.cast(u32, buf.len)) |len| {
                buffer[i] = .{ .buf = buf.ptr, .len = len };
                i += 1;
                n += len;
                continue;
            }
            buffer[i] = .{ .buf = buf.ptr, .len = std.math.maxInt(u32) };
            i += 1;
            n += std.math.maxInt(u32);
            return .{ i, n };
        }
        const buf = r.buffer;
        if (buf.len != 0) {
            r.seek = 0;
            r.end = 0;
            if (std.math.cast(u32, buf.len)) |len| {
                buffer[i] = .{ .buf = buf.ptr, .len = len };
            } else {
                buffer[i] = .{ .buf = buf.ptr, .len = std.math.maxInt(u32) };
            }
            i += 1;
        }
    } else {
        buffer[i] = .{
            .buf = r.buffer.ptr + r.end,
            .len = @min(std.math.maxInt(u32), r.buffer.len - r.end),
        };
        i += 1;
    }
    return .{ i, n };
}

pub fn writableVector(r: *Reader, buffer: [][]u8, data: []const []u8) Error!struct { usize, usize } {
    var i: usize = 0;
    var n: usize = 0;
    if (r.seek == r.end) {
        for (data) |buf| {
            if (buffer.len - i == 0) return .{ i, n };
            if (buf.len != 0) {
                buffer[i] = buf;
                i += 1;
                n += buf.len;
            }
        }
        if (r.buffer.len != 0) {
            r.seek = 0;
            r.end = 0;
            buffer[i] = r.buffer;
            i += 1;
        }
    } else {
        buffer[i] = r.buffer[r.end..];
        i += 1;
    }
    return .{ i, n };
}

test "deserialize signed LEB128" {
    // Truncated
    try testing.expectError(error.EndOfStream, testLeb128(i64, "\x80"));

    // Overflow
    try testing.expectError(error.Overflow, testLeb128(i8, "\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(i16, "\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(i32, "\x80\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(i8, "\xff\x7e"));
    try testing.expectError(error.Overflow, testLeb128(i32, "\x80\x80\x80\x80\x08"));
    try testing.expectError(error.Overflow, testLeb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01"));

    // Decode SLEB128
    try testing.expect((try testLeb128(i64, "\x00")) == 0);
    try testing.expect((try testLeb128(i64, "\x01")) == 1);
    try testing.expect((try testLeb128(i64, "\x3f")) == 63);
    try testing.expect((try testLeb128(i64, "\x40")) == -64);
    try testing.expect((try testLeb128(i64, "\x41")) == -63);
    try testing.expect((try testLeb128(i64, "\x7f")) == -1);
    try testing.expect((try testLeb128(i64, "\x80\x01")) == 128);
    try testing.expect((try testLeb128(i64, "\x81\x01")) == 129);
    try testing.expect((try testLeb128(i64, "\xff\x7e")) == -129);
    try testing.expect((try testLeb128(i64, "\x80\x7f")) == -128);
    try testing.expect((try testLeb128(i64, "\x81\x7f")) == -127);
    try testing.expect((try testLeb128(i64, "\xc0\x00")) == 64);
    try testing.expect((try testLeb128(i64, "\xc7\x9f\x7f")) == -12345);
    try testing.expect((try testLeb128(i8, "\xff\x7f")) == -1);
    try testing.expect((try testLeb128(i16, "\xff\xff\x7f")) == -1);
    try testing.expect((try testLeb128(i32, "\xff\xff\xff\xff\x7f")) == -1);
    try testing.expect((try testLeb128(i32, "\x80\x80\x80\x80\x78")) == -0x80000000);
    try testing.expect((try testLeb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f")) == @as(i64, @bitCast(@as(u64, @intCast(0x8000000000000000)))));
    try testing.expect((try testLeb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x40")) == -0x4000000000000000);
    try testing.expect((try testLeb128(i64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f")) == -0x8000000000000000);

    // Decode unnormalized SLEB128 with extra padding bytes.
    try testing.expect((try testLeb128(i64, "\x80\x00")) == 0);
    try testing.expect((try testLeb128(i64, "\x80\x80\x00")) == 0);
    try testing.expect((try testLeb128(i64, "\xff\x00")) == 0x7f);
    try testing.expect((try testLeb128(i64, "\xff\x80\x00")) == 0x7f);
    try testing.expect((try testLeb128(i64, "\x80\x81\x00")) == 0x80);
    try testing.expect((try testLeb128(i64, "\x80\x81\x80\x00")) == 0x80);
}

test "deserialize unsigned LEB128" {
    // Truncated
    try testing.expectError(error.EndOfStream, testLeb128(u64, "\x80"));
    try testing.expectError(error.EndOfStream, testLeb128(u16, "\x80\x80\x84"));
    try testing.expectError(error.EndOfStream, testLeb128(u32, "\x80\x80\x80\x80\x90"));

    // Overflow
    try testing.expectError(error.Overflow, testLeb128(u8, "\x80\x02"));
    try testing.expectError(error.Overflow, testLeb128(u8, "\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(u16, "\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(u32, "\x80\x80\x80\x80\x40"));
    try testing.expectError(error.Overflow, testLeb128(u64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x40"));

    // Decode ULEB128
    try testing.expect((try testLeb128(u64, "\x00")) == 0);
    try testing.expect((try testLeb128(u64, "\x01")) == 1);
    try testing.expect((try testLeb128(u64, "\x3f")) == 63);
    try testing.expect((try testLeb128(u64, "\x40")) == 64);
    try testing.expect((try testLeb128(u64, "\x7f")) == 0x7f);
    try testing.expect((try testLeb128(u64, "\x80\x01")) == 0x80);
    try testing.expect((try testLeb128(u64, "\x81\x01")) == 0x81);
    try testing.expect((try testLeb128(u64, "\x90\x01")) == 0x90);
    try testing.expect((try testLeb128(u64, "\xff\x01")) == 0xff);
    try testing.expect((try testLeb128(u64, "\x80\x02")) == 0x100);
    try testing.expect((try testLeb128(u64, "\x81\x02")) == 0x101);
    try testing.expect((try testLeb128(u64, "\x80\xc1\x80\x80\x10")) == 4294975616);
    try testing.expect((try testLeb128(u64, "\x80\x80\x80\x80\x80\x80\x80\x80\x80\x01")) == 0x8000000000000000);

    // Decode ULEB128 with extra padding bytes
    try testing.expect((try testLeb128(u64, "\x80\x00")) == 0);
    try testing.expect((try testLeb128(u64, "\x80\x80\x00")) == 0);
    try testing.expect((try testLeb128(u64, "\xff\x00")) == 0x7f);
    try testing.expect((try testLeb128(u64, "\xff\x80\x00")) == 0x7f);
    try testing.expect((try testLeb128(u64, "\x80\x81\x00")) == 0x80);
    try testing.expect((try testLeb128(u64, "\x80\x81\x80\x00")) == 0x80);
}

fn testLeb128(comptime T: type, encoded: []const u8) !T {
    var reader: std.Io.Reader = .fixed(encoded);
    const result = try reader.takeLeb128(T);
    try testing.expect(reader.seek == reader.end);
    return result;
}

test {
    _ = Limited;
}
