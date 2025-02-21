const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const BufferedWriter = std.io.BufferedWriter;
const Reader = std.io.Reader;

const BufferedReader = @This();

/// Number of bytes which have been consumed from `storage`.
seek: usize,
storage: BufferedWriter,
unbuffered_reader: Reader,

pub fn initFixed(br: *BufferedReader, buffer: []const u8) void {
    br.* = .{
        .seek = 0,
        .storage = .{
            .buffer = buffer,
            .mode = .fixed,
        },
        .reader = .{
            .context = br,
            .vtable = &.{
                .streamRead = null,
                .seekRead = null,
            },
        },
    };
}

pub fn deinit(br: *BufferedReader) void {
    br.storage.deinit();
    br.* = undefined;
}

/// Although `BufferedReader` can easily satisfy the `Reader` interface, it's
/// generally more practical to pass a `BufferedReader` instance itself around,
/// since it will result in fewer calls across vtable boundaries.
pub fn reader(br: *BufferedReader) Reader {
    return .{
        .context = br,
        .vtable = &.{
            .streamRead = passthru_streamRead,
            .seekRead = passthru_seekRead,
        },
    };
}

fn passthru_streamRead(ctx: *anyopaque, bw: *BufferedWriter, limit: Reader.Limit) anyerror!Reader.Status {
    const br: *BufferedReader = @alignCast(@ptrCast(ctx));
    const buffer = br.storage.buffer.items;
    const buffered = buffer[br.seek..];
    const limited = buffered[0..limit.min(buffered.len)];
    if (limited.len > 0) {
        const n = try bw.writeSplat(limited, 1);
        br.seek += n;
        return .{
            .end = false,
            .len = @intCast(n),
        };
    }
    return br.unbuffered_reader.streamRead(bw, limit);
}

fn passthru_seekRead(ctx: *anyopaque, bw: *BufferedWriter, limit: Reader.Limit, off: u64) anyerror!Reader.Status {
    const br: *BufferedReader = @alignCast(@ptrCast(ctx));
    const buffer = br.storage.buffer.items;
    if (off < buffer.len) {
        const send = buffer[off..limit.min(buffer.len)];
        return bw.writeSplat(send, 1);
    }
    return br.unbuffered_reader.seekRead(bw, limit, off - buffer.len);
}

/// Returns the next `n` bytes from `unbuffered_reader`, filling the buffer as
/// necessary.
///
/// Invalidates previously returned values from `peek`.
///
/// Asserts that the `BufferedReader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `toss`
pub fn peek(br: *BufferedReader, n: usize) anyerror![]u8 {
    const list = &br.storage.buffer;
    assert(n <= list.capacity);
    try fill(br, n);
    return list.items[br.seek..][0..n];
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
    assert(br.seek <= br.storage.buffer.items.len);
}

/// Equivalent to `peek` + `toss`.
pub fn take(br: *BufferedReader, n: usize) anyerror![]u8 {
    const result = try peek(br, n);
    toss(br, n);
    return result;
}

/// Returns the next `n` bytes from `unbuffered_reader` as an array, filling
/// the buffer as necessary.
///
/// Asserts that the `BufferedReader` was initialized with a buffer capacity at
/// least as big as `n`.
///
/// If there are fewer than `n` bytes left in the stream, `error.EndOfStream`
/// is returned instead.
///
/// See also:
/// * `take`
pub fn takeArray(br: *BufferedReader, comptime n: usize) anyerror!*[n]u8 {
    return (try take(br, n))[0..n];
}

/// Skips the next `n` bytes from the stream, advancing the seek position.
///
/// Unlike `toss` which is infallible, in this function `n` can be any amount.
///
/// Returns `error.EndOfStream` if fewer than `n` bytes could be discarded.
///
/// See also:
/// * `toss`
/// * `discardAll`
pub fn discard(br: *BufferedReader, n: usize) anyerror!void {
    const list = &br.storage.buffer;
    var remaining = n;
    while (remaining > 0) {
        const proposed_seek = br.seek + remaining;
        if (proposed_seek <= list.items.len) {
            br.seek = proposed_seek;
            return;
        }
        remaining -= (list.items.len - br.seek);
        list.items.len = 0;
        br.seek = 0;
        const status = try br.unbuffered_reader.streamRead(&br.storage, .none);
        if (remaining <= list.items.len) continue;
        if (status.end) return error.EndOfStream;
    }
}

/// Reads the stream until the end, ignoring all the data.
/// Returns the number of bytes discarded.
pub fn discardAll(br: *BufferedReader) anyerror!usize {
    const list = &br.storage.buffer;
    var total: usize = list.items.len;
    list.items.len = 0;
    total += try br.unbuffered_reader.discardAll();
    return total;
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
pub fn read(br: *BufferedReader, buffer: []u8) anyerror!void {
    const list = &br.storage.buffer;
    const in_buffer = list.items;
    const seek = br.seek;
    const proposed_seek = seek + in_buffer.len;
    if (proposed_seek <= in_buffer.len) {
        @memcpy(buffer, in_buffer[seek..proposed_seek]);
        br.seek = proposed_seek;
        return;
    }
    @memcpy(buffer[0..in_buffer.len], in_buffer);
    list.items.len = 0;
    br.seek = 0;
    var i: usize = in_buffer.len;
    while (true) {
        const status = try br.unbuffered_reader.streamRead(&br.storage, .none);
        const next_i = i + list.items.len;
        if (next_i >= buffer.len) {
            const remaining = buffer[i..];
            @memcpy(remaining, list.items[0..remaining.len]);
            br.seek = remaining.len;
            return;
        }
        if (status.end) return error.EndOfStream;
        @memcpy(buffer[i..next_i], list.items);
        list.items.len = 0;
        i = next_i;
    }
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position.
///
/// Returned slice includes the delimiter as the last byte.
///
/// If the stream ends before the delimiter is found, `error.EndOfStream` is
/// returned.
///
/// If the delimiter is not found within a number of bytes matching the
/// capacity of the `BufferedReader`, `error.StreamTooLong` is returned.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `takeDelimiterConclusive`
/// * `peekDelimiterInclusive`
pub fn takeDelimiterInclusive(br: *BufferedReader, delimiter: u8) anyerror![]u8 {
    const result = try peekDelimiterInclusive(br, delimiter);
    toss(result.len);
    return result;
}

pub fn peekDelimiterInclusive(br: *BufferedReader, delimiter: u8) anyerror![]u8 {
    const list = &br.storage.buffer;
    const buffer = list.items;
    const seek = br.seek;
    if (std.mem.indexOfScalarPos(u8, buffer, seek, delimiter)) |end| {
        @branchHint(.likely);
        return buffer[seek .. end + 1];
    }
    const remainder = buffer[seek..];
    std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
    var i = remainder.len;
    list.items.len = i;
    br.seek = 0;
    while (i < list.capacity) {
        const status = try br.unbuffered_reader.streamRead(&br.storage, .none);
        if (std.mem.indexOfScalarPos(u8, list.items, i, delimiter)) |end| {
            return list.items[0 .. end + 1];
        }
        if (status.end) return error.EndOfStream;
        i = list.items.len;
    }
    return error.StreamTooLong;
}

/// Returns a slice of the next bytes of buffered data from the stream until
/// `delimiter` is found, advancing the seek position.
///
/// Returned slice excludes the delimiter.
///
/// End-of-stream is treated equivalent to a delimiter.
///
/// If the delimiter is not found within a number of bytes matching the
/// capacity of the `BufferedReader`, `error.StreamTooLong` is returned.
///
/// Invalidates previously returned values from `peek`.
///
/// See also:
/// * `takeDelimiterInclusive`
/// * `peekDelimiterConclusive`
pub fn takeDelimiterConclusive(br: *BufferedReader, delimiter: u8) anyerror![]u8 {
    const result = try peekDelimiterConclusive(br, delimiter);
    toss(result.len);
    return result;
}

pub fn peekDelimiterConclusive(br: *BufferedReader, delimiter: u8) anyerror![]u8 {
    const list = &br.storage.buffer;
    const buffer = list.items;
    const seek = br.seek;
    if (std.mem.indexOfScalarPos(u8, buffer, seek, delimiter)) |end| {
        @branchHint(.likely);
        return buffer[seek..end];
    }
    const remainder = buffer[seek..];
    std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
    var i = remainder.len;
    list.items.len = i;
    br.seek = 0;
    while (i < list.capacity) {
        const status = try br.unbuffered_reader.streamRead(&br.storage, .none);
        if (std.mem.indexOfScalarPos(u8, list.items, i, delimiter)) |end| {
            return list.items[0 .. end + 1];
        }
        if (status.end) return list.items;
        i = list.items.len;
    }
    return error.StreamTooLong;
}

/// Appends to `bw` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// If stream ends before delimiter found, returns `error.EndOfStream`.
///
/// Returns number of bytes streamed.
pub fn streamReadDelimiter(br: *BufferedReader, bw: *std.io.BufferedWriter, delimiter: u8) anyerror!usize {
    _ = br;
    _ = bw;
    _ = delimiter;
    @panic("TODO");
}

/// Appends to `bw` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// Succeeds if stream ends before delimiter found.
///
/// Returns number of bytes streamed as well as whether the input reached the end.
/// The end is not signaled to the writer.
pub fn streamReadDelimiterConclusive(
    br: *BufferedReader,
    bw: *std.io.BufferedWriter,
    delimiter: u8,
) anyerror!Reader.Status {
    _ = br;
    _ = bw;
    _ = delimiter;
    @panic("TODO");
}

/// Appends to `bw` contents by reading from the stream until `delimiter` is found.
/// Does not write the delimiter itself.
///
/// If `limit` is exceeded, returns `error.StreamTooLong`.
pub fn streamReadDelimiterLimited(
    br: *BufferedReader,
    bw: *BufferedWriter,
    delimiter: u8,
    limit: usize,
) anyerror!void {
    _ = br;
    _ = bw;
    _ = delimiter;
    _ = limit;
    @panic("TODO");
}

/// Reads from the stream until specified byte is found, discarding all data,
/// including the delimiter.
///
/// If end of stream is found, this function succeeds.
pub fn discardDelimiterConclusive(br: *BufferedReader, delimiter: u8) anyerror!void {
    _ = br;
    _ = delimiter;
    @panic("TODO");
}

/// Reads from the stream until specified byte is found, discarding all data,
/// excluding the delimiter.
///
/// If end of stream is found, `error.EndOfStream` is returned.
pub fn discardDelimiterInclusive(br: *BufferedReader, delimiter: u8) anyerror!void {
    _ = br;
    _ = delimiter;
    @panic("TODO");
}

/// Fills the buffer such that it contains at least `n` bytes, without
/// advancing the seek position.
///
/// Returns `error.EndOfStream` if there are fewer than `n` bytes remaining.
///
/// Asserts buffer capacity is at least `n`.
pub fn fill(br: *BufferedReader, n: usize) anyerror!void {
    assert(n <= br.storage.buffer.capacity);
    const list = &br.storage.buffer;
    const buffer = list.items;
    const seek = br.seek;
    if (seek + n <= buffer.len) {
        @branchHint(.likely);
        return;
    }
    const remainder = buffer[seek..];
    std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
    list.items.len = remainder.len;
    br.seek = 0;
    while (true) {
        const status = try br.unbuffered_reader.streamRead(&br.storage, .none);
        if (n <= list.items.len) return;
        if (status.end) return error.EndOfStream;
    }
}

/// Reads 1 byte from the stream or returns `error.EndOfStream`.
pub fn takeByte(br: *BufferedReader) anyerror!u8 {
    const buffer = br.storage.buffer.items;
    const seek = br.seek;
    if (seek >= buffer.len) {
        @branchHint(.unlikely);
        try fill(br, 1);
    }
    br.seek = seek + 1;
    return buffer[seek];
}

/// Same as `readByte` except the returned byte is signed.
pub fn takeByteSigned(br: *BufferedReader) anyerror!i8 {
    return @bitCast(try br.readByte());
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
pub inline fn takeInt(br: *BufferedReader, comptime T: type, endian: std.builtin.Endian) anyerror!T {
    const n = @divExact(@typeInfo(T).int.bits, 8);
    return std.mem.readInt(T, try takeArray(br, n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `n`.
pub fn takeVarInt(br: *BufferedReader, comptime Int: type, endian: std.builtin.Endian, n: usize) anyerror!Int {
    assert(n <= @sizeOf(Int));
    return std.mem.readVarInt(Int, try take(br, n), endian);
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
pub fn takeStruct(br: *BufferedReader, comptime T: type) anyerror!*align(1) T {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(T).@"struct".layout != .auto);
    return @ptrCast(try takeArray(br, @sizeOf(T)));
}

/// Asserts the buffer was initialized with a capacity at least `@sizeOf(T)`.
pub fn takeStructEndian(br: *BufferedReader, comptime T: type, endian: std.builtin.Endian) anyerror!T {
    var res = (try br.takeStruct(T)).*;
    if (native_endian != endian) std.mem.byteSwapAllFields(T, &res);
    return res;
}

/// Reads an integer with the same size as the given enum's tag type. If the
/// integer matches an enum tag, casts the integer to the enum tag and returns
/// it. Otherwise, returns `error.InvalidEnumTag`.
///
/// Asserts the buffer was initialized with a capacity at least `@sizeOf(Enum)`.
pub fn takeEnum(br: *BufferedReader, comptime Enum: type, endian: std.builtin.Endian) anyerror!Enum {
    const Tag = @typeInfo(Enum).@"enum".tag_type;
    const int = try takeInt(br, Tag, endian);
    return std.meta.intToEnum(Enum, int);
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

test toss {
    return error.Unimplemented;
}

test take {
    return error.Unimplemented;
}

test takeArray {
    return error.Unimplemented;
}

test discard {
    var br: BufferedReader = undefined;
    br.initFixed("foobar");
    try br.discard(3);
    try testing.expectEqualStrings("bar", try br.take(3));
    try br.discard(0);
    try testing.expectError(error.EndOfStream, br.discard(1));
}

test discardAll {
    return error.Unimplemented;
}

test read {
    return error.Unimplemented;
}

test takeDelimiterInclusive {
    return error.Unimplemented;
}

test peekDelimiterInclusive {
    return error.Unimplemented;
}

test takeDelimiterConclusive {
    return error.Unimplemented;
}

test peekDelimiterConclusive {
    return error.Unimplemented;
}

test streamReadDelimiter {
    return error.Unimplemented;
}

test streamReadDelimiterConclusive {
    return error.Unimplemented;
}

test streamReadDelimiterLimited {
    return error.Unimplemented;
}

test discardDelimiterConclusive {
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

test takeStructEndian {
    return error.Unimplemented;
}

test takeEnum {
    return error.Unimplemented;
}
