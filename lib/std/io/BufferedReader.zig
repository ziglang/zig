const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const BufferedWriter = std.io.BufferedWriter;
const Reader = std.io.Reader;
const Allocator = std.mem.Allocator;

const BufferedReader = @This();

unbuffered_reader: Reader,
buffer: []u8,
/// In `buffer` before this are buffered bytes, after this is `undefined`.
end: usize,
/// Number of bytes which have been consumed from `buffer`.
seek: usize,

/// Constructs `br` such that it will read from `buffer` and then end.
///
/// Most methods do not require mutating `buffer`. Those that do are marked,
/// and if they are avoided then `buffer` can be safely used with `@constCast`.
pub fn initFixed(br: *BufferedReader, buffer: []u8) void {
    br.* = .{
        .unbuffered_reader = .ending,
        .buffer = buffer,
        .end = buffer.len,
        .seek = 0,
    };
}

pub fn bufferContents(br: *BufferedReader) []u8 {
    return br.buffer[br.seek..br.end];
}

/// Although `BufferedReader` can easily satisfy the `Reader` interface, it's
/// generally more practical to pass a `BufferedReader` instance itself around,
/// since it will result in fewer calls across vtable boundaries.
pub fn reader(br: *BufferedReader) Reader {
    return .{
        .context = br,
        .vtable = &.{
            .read = passthruRead,
            .readVec = passthruReadVec,
            .discard = passthruDiscard,
        },
    };
}

/// Equivalent semantics to `std.io.Reader.VTable.readVec`.
pub fn readVec(br: *BufferedReader, data: []const []u8) Reader.Error!usize {
    return passthruReadVec(br, data);
}

/// Equivalent semantics to `std.io.Reader.VTable.read`.
pub fn read(br: *BufferedReader, bw: *BufferedWriter, limit: Reader.Limit) Reader.RwError!usize {
    return passthruRead(br, bw, limit);
}

/// Equivalent semantics to `std.io.Reader.VTable.discard`.
pub fn discard(br: *BufferedReader, limit: Reader.Limit) Reader.Error!usize {
    return passthruDiscard(br, limit);
}

pub fn readVecAll(br: *BufferedReader, data: [][]u8) Reader.Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    while (index < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try br.readVec(data[index..]);
        }
        while (index < data.len and truncate >= data[index].len) {
            truncate -= data[index].len;
            index += 1;
        }
    }
}

/// "Pump" data from the reader to the writer.
pub fn readAll(br: *BufferedReader, bw: *BufferedWriter, limit: Reader.Limit) Reader.RwError!void {
    var remaining = limit;
    while (remaining.nonzero()) {
        const n = try br.read(bw, remaining);
        remaining = remaining.subtract(n).?;
    }
}

/// Equivalent to `readVec` but reads at most `limit` bytes.
pub fn readVecLimit(br: *BufferedReader, data: []const []u8, limit: Reader.Limit) Reader.Error!usize {
    _ = br;
    _ = data;
    _ = limit;
    @panic("TODO");
}

fn passthruRead(context: ?*anyopaque, bw: *BufferedWriter, limit: Reader.Limit) Reader.RwError!usize {
    const br: *BufferedReader = @alignCast(@ptrCast(context));
    const buffer = limit.slice(br.buffer[br.seek..br.end]);
    if (buffer.len > 0) {
        const n = try bw.write(buffer);
        br.seek += n;
        return n;
    }
    return br.unbuffered_reader.read(bw, limit);
}

fn passthruDiscard(context: ?*anyopaque, limit: Reader.Limit) Reader.Error!usize {
    const br: *BufferedReader = @alignCast(@ptrCast(context));
    const buffered_len = br.end - br.seek;
    if (limit.toInt()) |n| {
        if (buffered_len >= n) {
            br.seek += n;
            return n;
        }
        br.seek = 0;
        br.end = 0;
        const additional = try br.unbuffered_reader.discard(.limited(n - buffered_len));
        return n + additional;
    }
    const n = try br.unbuffered_reader.discard(.unlimited);
    br.seek = 0;
    br.end = 0;
    return buffered_len + n;
}

fn passthruReadVec(context: ?*anyopaque, data: []const []u8) Reader.Error!usize {
    const br: *BufferedReader = @alignCast(@ptrCast(context));
    var total: usize = 0;
    for (data, 0..) |buf, i| {
        const buffered = br.buffer[br.seek..br.end];
        const copy_len = @min(buffered.len, buf.len);
        @memcpy(buf[0..copy_len], buffered[0..copy_len]);
        total += copy_len;
        br.seek += copy_len;
        if (copy_len < buf.len) {
            br.seek = 0;
            br.end = 0;
            var vecs: [8][]u8 = undefined; // Arbitrarily chosen value.
            vecs[0] = buf[copy_len..];
            const vecs_len: usize = @min(vecs.len, data.len - i);
            var vec_data_len: usize = vecs[0].len;
            for (vecs[1..vecs_len], data[i + 1 ..][0 .. vecs_len - 1]) |*v, d| {
                vec_data_len += d.len;
                v.* = d;
            }
            if (vecs_len < vecs.len) {
                vecs[vecs_len] = br.buffer;
                const n = try br.unbuffered_reader.readVec(vecs[0 .. vecs_len + 1]);
                total += @min(n, vec_data_len);
                br.end = n -| vec_data_len;
                return total;
            }
            if (vecs[vecs.len - 1].len >= br.buffer.len) {
                total += try br.unbuffered_reader.readVec(&vecs);
                return total;
            }
            vec_data_len -= vecs[vecs.len - 1].len;
            vecs[vecs.len - 1] = br.buffer;
            const n = try br.unbuffered_reader.readVec(&vecs);
            total += @min(n, vec_data_len);
            br.end = n -| vec_data_len;
            return total;
        }
    }
    return total;
}

pub fn seekBy(br: *BufferedReader, seek_by: i64) !void {
    if (seek_by < 0) try br.seekBackwardBy(@abs(seek_by)) else try br.seekForwardBy(@abs(seek_by));
}

pub fn seekBackwardBy(br: *BufferedReader, seek_by: u64) !void {
    if (seek_by > br.end - br.seek) return error.Unseekable; // TODO
    br.seek += @abs(seek_by);
}

pub fn seekForwardBy(br: *BufferedReader, seek_by: u64) !void {
    const seek, const need_unbuffered_seek = @subWithOverflow(br.seek, @abs(seek_by));
    if (need_unbuffered_seek > 0) return error.Unseekable; // TODO
    br.seek = seek;
}

/// Returns the next `len` bytes from `unbuffered_reader`, filling the buffer as
/// necessary.
///
/// Invalidates previously returned values from `peek`.
///
/// Asserts that the `BufferedReader` was initialized with a buffer capacity at
/// least as big as `len`.
///
/// If there are fewer than `len` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `peek`
/// * `toss`
pub fn peek(br: *BufferedReader, n: usize) Reader.Error![]u8 {
    try br.fill(n);
    return br.buffer[br.seek..][0..n];
}

/// Returns all the next buffered bytes from `unbuffered_reader`, after filling
/// the buffer to ensure it contains at least `n` bytes.
///
/// Invalidates previously returned values from `peek` and `peekGreedy`.
///
/// Asserts that the `BufferedReader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `peek`
/// * `toss`
pub fn peekGreedy(br: *BufferedReader, n: usize) Reader.Error![]u8 {
    try br.fill(n);
    return br.buffer[br.seek..br.end];
}

/// Skips the next `n` bytes from the stream, advancing the seek position. This
/// is typically and safely used after `peek`.
///
/// Asserts that the number of bytes buffered is at least as many as `n`.
///
/// See also:
/// * `peek`.
/// * `discard`.
pub fn toss(br: *BufferedReader, n: usize) void {
    br.seek += n;
    assert(br.seek <= br.end);
}

/// Equivalent to `peek` followed by `toss`.
///
/// The data returned is invalidated by the next call to `take`, `peek`,
/// `fill`, and functions with those prefixes.
pub fn take(br: *BufferedReader, n: usize) Reader.Error![]u8 {
    const result = try br.peek(n);
    br.toss(n);
    return result;
}

/// Returns the next `n` bytes from `unbuffered_reader` as an array, filling
/// the buffer as necessary and advancing the seek position `n` bytes.
///
/// Asserts that the `BufferedReader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `take`
pub fn takeArray(br: *BufferedReader, comptime n: usize) Reader.Error!*[n]u8 {
    return (try br.take(n))[0..n];
}

/// Returns the next `n` bytes from `unbuffered_reader` as an array, filling
/// the buffer as necessary, without advancing the seek position.
///
/// Asserts that the `BufferedReader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `peek`
/// * `takeArray`
pub fn peekArray(br: *BufferedReader, comptime n: usize) Reader.Error!*[n]u8 {
    return (try br.peek(n))[0..n];
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
pub fn discardAll(br: *BufferedReader, n: usize) Reader.Error!void {
    if ((try br.discardShort(n)) != n) return error.EndOfStream;
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
pub fn discardShort(br: *BufferedReader, n: usize) Reader.ShortError!usize {
    const proposed_seek = br.seek + n;
    if (proposed_seek <= br.end) {
        @branchHint(.likely);
        br.seek = proposed_seek;
        return n;
    }
    var remaining = n - (br.end - br.seek);
    br.end = 0;
    br.seek = 0;
    while (true) {
        const discard_len = br.unbuffered_reader.discard(.limited(remaining)) catch |err| switch (err) {
            error.EndOfStream => return n - remaining,
            error.ReadFailed => return error.ReadFailed,
        };
        remaining -= discard_len;
        if (remaining == 0) return n;
    }
}

/// Reads the stream until the end, ignoring all the data.
/// Returns the number of bytes discarded.
pub fn discardRemaining(br: *BufferedReader) Reader.ShortError!usize {
    const buffered_len = br.end;
    br.end = 0;
    return buffered_len + try br.unbuffered_reader.discardRemaining();
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
pub fn readSlice(br: *BufferedReader, buffer: []u8) Reader.Error!void {
    const in_buffer = br.buffer[br.seek..br.end];
    const copy_len = @min(buffer.len, in_buffer.len);
    @memcpy(buffer[0..copy_len], in_buffer[0..copy_len]);
    if (copy_len == buffer.len) {
        br.seek += copy_len;
        return;
    }
    var i: usize = copy_len;
    br.end = 0;
    br.seek = 0;
    while (true) {
        const remaining = buffer[i..];
        const n = try br.unbuffered_reader.readVec(&.{ remaining, br.buffer });
        if (n < remaining.len) {
            i += n;
            continue;
        }
        br.end = n - remaining.len;
        return;
    }
}

/// Returns the number of bytes read, which is less than `buffer.len` if and
/// only if the stream reached the end.
pub fn readShort(br: *BufferedReader, buffer: []u8) Reader.ShortError!usize {
    _ = br;
    _ = buffer;
    @panic("TODO");
}

/// The function is inline to avoid the dead code in case `endian` is
/// comptime-known and matches host endianness.
pub inline fn readSliceEndianAlloc(
    br: *BufferedReader,
    allocator: Allocator,
    Elem: type,
    len: usize,
    endian: std.builtin.Endian,
) ReadAllocError![]Elem {
    const dest = try allocator.alloc(Elem, len);
    errdefer allocator.free(dest);
    try readSlice(br, @ptrCast(dest));
    if (native_endian != endian) std.mem.byteSwapAllFields(Elem, dest);
    return dest;
}

pub const ReadAllocError = Reader.Error || Allocator.Error;

pub fn readSliceAlloc(br: *BufferedReader, allocator: Allocator, len: usize) ReadAllocError![]u8 {
    const dest = try allocator.alloc(u8, len);
    errdefer allocator.free(dest);
    try readSlice(br, dest);
    return dest;
}

pub const DelimiterInclusiveError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// Stream ended before the delimiter was found.
    EndOfStream,
    /// The delimiter was not found within a number of bytes matching the
    /// capacity of the `BufferedReader`.
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
pub fn takeSentinel(br: *BufferedReader, comptime sentinel: u8) DelimiterInclusiveError![:sentinel]u8 {
    const result = try br.peekSentinel(sentinel);
    br.toss(result.len + 1);
    return result;
}

pub fn peekSentinel(br: *BufferedReader, comptime sentinel: u8) DelimiterInclusiveError![:sentinel]u8 {
    const result = try br.takeDelimiterInclusive(sentinel);
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
pub fn takeDelimiterInclusive(br: *BufferedReader, delimiter: u8) DelimiterInclusiveError![]u8 {
    const result = try br.peekDelimiterInclusive(delimiter);
    br.toss(result.len);
    return result;
}

pub fn peekDelimiterInclusive(br: *BufferedReader, delimiter: u8) DelimiterInclusiveError![]u8 {
    return (try br.peekDelimiterInclusiveUnlessEnd(delimiter)) orelse error.EndOfStream;
}

pub const DelimiterExclusiveError = error{
    /// See the `Reader` implementation for detailed diagnostics.
    ReadFailed,
    /// The delimiter was not found within a number of bytes matching the
    /// capacity of the `BufferedReader`.
    StreamTooLong,
};

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position.
///
/// Returned slice excludes the delimiter.
///
/// End-of-stream is treated equivalent to a delimiter.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `takeSentinel`
/// * `takeDelimiterInclusive`
/// * `peekDelimiterExclusive`
pub fn takeDelimiterExclusive(br: *BufferedReader, delimiter: u8) DelimiterExclusiveError![]u8 {
    const result = br.peekDelimiterInclusiveUnlessEnd(delimiter) catch |err| switch (err) {
        error.EndOfStream => {
            br.toss(br.end);
            return br.buffer[0..br.end];
        },
        else => |e| return e,
    };
    br.toss(result.len);
    return result[0 .. result.len - 1];
}

pub fn peekDelimiterExclusive(br: *BufferedReader, delimiter: u8) DelimiterExclusiveError![]u8 {
    const result = br.peekDelimiterInclusiveUnlessEnd(delimiter) catch |err| switch (err) {
        error.EndOfStream => return br.buffer[0..br.end],
        else => |e| return e,
    };
    return result[0 .. result.len - 1];
}

fn peekDelimiterInclusiveUnlessEnd(br: *BufferedReader, delimiter: u8) DelimiterInclusiveError!?[]u8 {
    const buffer = br.buffer[0..br.end];
    const seek = br.seek;
    if (std.mem.indexOfScalarPos(u8, buffer, seek, delimiter)) |end| {
        @branchHint(.likely);
        return buffer[seek .. end + 1];
    }
    if (seek > 0) {
        const remainder = buffer[seek..];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        br.end = remainder.len;
        br.seek = 0;
    }
    while (br.end < br.buffer.len) {
        const n = try br.unbuffered_reader.readVec(&.{br.buffer[br.end..]});
        const prev_end = br.end;
        br.end = prev_end + n;
        if (std.mem.indexOfScalarPos(u8, br.buffer[0..br.end], prev_end, delimiter)) |end| {
            return br.buffer[0 .. end + 1];
        }
    }
    return error.StreamTooLong;
}

/// Appends to `bw` contents by reading from the stream until `delimiter` is
/// found. Does not write the delimiter itself.
///
/// Returns number of bytes streamed.
pub fn streamToDelimiter(br: *BufferedReader, bw: *BufferedWriter, delimiter: u8) Reader.RwError!usize {
    const amount, const to = try br.streamToAny(bw, delimiter, .unlimited);
    return switch (to) {
        .delimiter => amount,
        .limit => unreachable,
        .end => error.EndOfStream,
    };
}

/// Appends to `bw` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// Succeeds if stream ends before delimiter found.
///
/// Returns number of bytes streamed. The end is not signaled to the writer.
pub fn streamToDelimiterOrEnd(
    br: *BufferedReader,
    bw: *BufferedWriter,
    delimiter: u8,
) Reader.RwAllError!usize {
    const amount, const to = try br.streamToAny(bw, delimiter, .unlimited);
    return switch (to) {
        .delimiter, .end => amount,
        .limit => unreachable,
    };
}

pub const StreamDelimiterLimitedError = Reader.RwAllError || error{
    /// Stream ended before the delimiter was found.
    EndOfStream,
    /// The delimiter was not found within the limit.
    StreamTooLong,
};

/// Appends to `bw` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// Returns number of bytes streamed.
pub fn streamToDelimiterOrLimit(
    br: *BufferedReader,
    bw: *BufferedWriter,
    delimiter: u8,
    limit: Reader.Limit,
) StreamDelimiterLimitedError!usize {
    const amount, const to = try br.streamToAny(bw, delimiter, limit);
    return switch (to) {
        .delimiter => amount,
        .limit => error.StreamTooLong,
        .end => error.EndOfStream,
    };
}

fn streamToAny(
    br: *BufferedReader,
    bw: *BufferedWriter,
    delimiter: ?u8,
    limit: Reader.Limit,
) Reader.RwAllError!struct { usize, enum { delimiter, limit, end } } {
    var amount: usize = 0;
    var remaining = limit;
    while (remaining.nonzero()) {
        const available = remaining.slice(br.peekGreedy(1) catch |err| switch (err) {
            error.ReadFailed => |e| return e,
            error.EndOfStream => return .{ amount, .end },
        });
        if (delimiter) |d| if (std.mem.indexOfScalar(u8, available, d)) |delimiter_index| {
            try bw.writeAll(available[0..delimiter_index]);
            br.toss(delimiter_index + 1);
            return .{ amount + delimiter_index, .delimiter };
        };
        try bw.writeAll(available);
        br.toss(available.len);
        amount += available.len;
        remaining = remaining.subtract(available.len).?;
    }
    return .{ amount, .limit };
}

/// Reads from the stream until specified byte is found, discarding all data,
/// including the delimiter.
///
/// If end of stream is found, this function succeeds.
pub fn discardDelimiterInclusive(br: *BufferedReader, delimiter: u8) Reader.Error!void {
    _ = br;
    _ = delimiter;
    @panic("TODO");
}

/// Reads from the stream until specified byte is found, discarding all data,
/// excluding the delimiter.
///
/// Succeeds if stream ends before delimiter found.
pub fn discardDelimiterExclusive(br: *BufferedReader, delimiter: u8) Reader.ShortError!void {
    _ = br;
    _ = delimiter;
    @panic("TODO");
}

/// Fills the buffer such that it contains at least `n` bytes, without
/// advancing the seek position.
///
/// Returns `error.EndOfStream` if and only if there are fewer than `n` bytes
/// remaining.
///
/// Asserts buffer capacity is at least `n`.
pub fn fill(br: *BufferedReader, n: usize) Reader.Error!void {
    assert(n <= br.buffer.len);
    const buffer = br.buffer[0..br.end];
    const seek = br.seek;
    if (seek + n <= buffer.len) {
        @branchHint(.likely);
        return;
    }
    if (seek > 0) {
        const remainder = buffer[seek..];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        br.end = remainder.len;
        br.seek = 0;
    }
    while (true) {
        br.end += try br.unbuffered_reader.readVec(&.{br.buffer[br.end..]});
        if (n <= br.end) return;
    }
}

/// Returns the next byte from the stream or returns `error.EndOfStream`.
///
/// Does not advance the seek position.
///
/// Asserts the buffer capacity is nonzero.
pub fn peekByte(br: *BufferedReader) Reader.Error!u8 {
    const buffer = br.buffer[0..br.end];
    const seek = br.seek;
    if (seek >= buffer.len) {
        @branchHint(.unlikely);
        try fill(br, 1);
    }
    return buffer[seek];
}

/// Reads 1 byte from the stream or returns `error.EndOfStream`.
///
/// Asserts the buffer capacity is nonzero.
pub fn takeByte(br: *BufferedReader) Reader.Error!u8 {
    const result = try peekByte(br);
    br.seek += 1;
    return result;
}

/// Same as `takeByte` except the returned byte is signed.
pub fn takeByteSigned(br: *BufferedReader) Reader.Error!i8 {
    return @bitCast(try br.takeByte());
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
pub inline fn takeInt(br: *BufferedReader, comptime T: type, endian: std.builtin.Endian) Reader.Error!T {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    return std.mem.readInt(T, try br.takeArray(n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `n`.
pub fn takeVarInt(br: *BufferedReader, comptime Int: type, endian: std.builtin.Endian, n: usize) Reader.Error!Int {
    assert(n <= @sizeOf(Int));
    return std.mem.readVarInt(Int, try br.take(n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// Advances the seek position.
///
/// See also:
/// * `peekStruct`
pub fn takeStruct(br: *BufferedReader, comptime T: type) Reader.Error!*align(1) T {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(T).@"struct".layout != .auto);
    return @ptrCast(try br.takeArray(@sizeOf(T)));
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// Does not advance the seek position.
///
/// See also:
/// * `takeStruct`
pub fn peekStruct(br: *BufferedReader, comptime T: type) Reader.Error!*align(1) T {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(T).@"struct".layout != .auto);
    return @ptrCast(try br.peekArray(@sizeOf(T)));
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// This function is inline to avoid referencing `std.mem.byteSwapAllFields`
/// when `endian` is comptime-known and matches the host endianness.
pub inline fn takeStructEndian(br: *BufferedReader, comptime T: type, endian: std.builtin.Endian) Reader.Error!T {
    var res = (try br.takeStruct(T)).*;
    if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
    return res;
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
///
/// This function is inline to avoid referencing `std.mem.byteSwapAllFields`
/// when `endian` is comptime-known and matches the host endianness.
pub inline fn peekStructEndian(br: *BufferedReader, comptime T: type, endian: std.builtin.Endian) Reader.Error!T {
    var res = (try br.peekStruct(T)).*;
    if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
    return res;
}

/// Reads an integer with the same size as the given enum's tag type. If the
/// integer matches an enum tag, casts the integer to the enum tag and returns
/// it. Otherwise, returns `error.InvalidEnumTag`.
///
/// Asserts the buffer was initialized with a capacity at least `@sizeOf(Enum)`.
pub fn takeEnum(br: *BufferedReader, comptime Enum: type, endian: std.builtin.Endian) (Reader.Error || std.meta.IntToEnumError)!Enum {
    const Tag = @typeInfo(Enum).@"enum".tag_type;
    const int = try br.takeInt(Tag, endian);
    return std.meta.intToEnum(Enum, int);
}

pub const TakeLeb128Error = Reader.Error || error{Overflow};

/// Read a single LEB128 value as type T, or `error.Overflow` if the value cannot fit.
pub fn takeLeb128(br: *BufferedReader, comptime Result: type) TakeLeb128Error!Result {
    const result_info = @typeInfo(Result).int;
    return std.math.cast(Result, try br.takeMultipleOf7Leb128(@Type(.{ .int = .{
        .signedness = result_info.signedness,
        .bits = std.mem.alignForwardAnyAlign(u16, result_info.bits, 7),
    } }))) orelse error.Overflow;
}

/// Returns a slice into the unused capacity of `buffer` with at least
/// `min_len` bytes, extending `buffer` by resizing it with `gpa` as necessary.
///
/// After calling this function, typically the caller will follow up with a
/// call to `advanceBufferEnd` to report the actual number of bytes buffered.
pub fn writableSliceGreedyAlloc(
    br: *BufferedReader,
    allocator: Allocator,
    min_len: usize,
) error{OutOfMemory}![]u8 {
    {
        const unused = br.buffer[br.end..];
        if (unused.len >= min_len) return unused;
    }
    const seek = br.seek;
    if (seek > 0) {
        const buffer = br.buffer[0..br.end];
        const remainder = buffer[seek..];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        br.end = remainder.len;
        br.seek = 0;
    }
    {
        var list: std.ArrayListUnmanaged(u8) = .{
            .items = br.buffer[0..br.end],
            .capacity = br.buffer.len,
        };
        defer br.buffer = list.allocatedSlice();
        try list.ensureUnusedCapacity(allocator, min_len);
    }
    const unused = br.buffer[br.end..];
    assert(unused.len >= min_len);
    return unused;
}

/// After writing directly into the unused capacity of `buffer`, this function
/// updates `end` so that users of `BufferedReader` can receive the data.
pub fn advanceBufferEnd(br: *BufferedReader, n: usize) void {
    assert(n <= br.buffer.len - br.end);
    br.end += n;
}

fn takeMultipleOf7Leb128(br: *BufferedReader, comptime Result: type) TakeLeb128Error!Result {
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
        const buffer: []const packed struct(u8) { bits: u7, more: bool } = @ptrCast(try br.peekGreedy(1));
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
            br.toss(len);
            return if (fits) @as(Result, @bitCast(result)) >> remaining_bits else error.Overflow;
        }
        br.toss(buffer.len);
    }
}

test initFixed {
    var br: BufferedReader = undefined;
    br.initFixed("a\x02");
    try testing.expect((try br.takeByte()) == 'a');
    try testing.expect((try br.takeEnum(enum(u8) {
        a = 0,
        b = 99,
        c = 2,
        d = 3,
    }, builtin.cpu.arch.endian())) == .c);
    try testing.expectError(error.EndOfStream, br.takeByte());
}

test peek {
    return error.Unimplemented;
}

test peekGreedy {
    return error.Unimplemented;
}

test toss {
    return error.Unimplemented;
}

test take {
    return error.Unimplemented;
}

test takeArray {
    return error.Unimplemented;
}

test peekArray {
    return error.Unimplemented;
}

test discardAll {
    var br: BufferedReader = undefined;
    br.initFixed("foobar");
    try br.discard(3);
    try testing.expectEqualStrings("bar", try br.take(3));
    try br.discard(0);
    try testing.expectError(error.EndOfStream, br.discard(1));
}

test discardRemaining {
    return error.Unimplemented;
}

test read {
    return error.Unimplemented;
}

test takeSentinel {
    return error.Unimplemented;
}

test peekSentinel {
    return error.Unimplemented;
}

test takeDelimiterInclusive {
    return error.Unimplemented;
}

test peekDelimiterInclusive {
    return error.Unimplemented;
}

test takeDelimiterExclusive {
    return error.Unimplemented;
}

test peekDelimiterExclusive {
    return error.Unimplemented;
}

test streamToDelimiter {
    return error.Unimplemented;
}

test streamToDelimiterOrEnd {
    return error.Unimplemented;
}

test streamToDelimiterOrLimit {
    return error.Unimplemented;
}

test discardDelimiterExclusive {
    return error.Unimplemented;
}

test discardDelimiterInclusive {
    return error.Unimplemented;
}

test fill {
    return error.Unimplemented;
}

test takeByte {
    return error.Unimplemented;
}

test takeByteSigned {
    return error.Unimplemented;
}

test takeInt {
    return error.Unimplemented;
}

test takeVarInt {
    return error.Unimplemented;
}

test takeStruct {
    return error.Unimplemented;
}

test peekStruct {
    return error.Unimplemented;
}

test takeStructEndian {
    return error.Unimplemented;
}

test peekStructEndian {
    return error.Unimplemented;
}

test takeEnum {
    return error.Unimplemented;
}

test takeLeb128 {
    return error.Unimplemented;
}

test readShort {
    return error.Unimplemented;
}

test readVec {
    return error.Unimplemented;
}
