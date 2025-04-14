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

pub fn init(br: *BufferedReader, r: Reader, buffer: []u8) void {
    br.* = .{
        .seek = 0,
        .storage = undefined,
        .unbuffered_reader = r,
    };
    br.storage.initFixed(buffer);
}

const eof_writer: std.io.Writer.VTable = .{
    .writeSplat = eof_writeSplat,
    .writeFile = eof_writeFile,
};
const eof_reader: std.io.Reader.VTable = .{
    .read = eof_read,
    .readv = eof_readv,
};

fn eof_writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) anyerror!usize {
    _ = context;
    _ = data;
    _ = splat;
    return error.NoSpaceLeft;
}

fn eof_writeFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: std.io.Writer.Offset,
    limit: std.io.Writer.Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    _ = context;
    _ = file;
    _ = offset;
    _ = limit;
    _ = headers_and_trailers;
    _ = headers_len;
    return error.NoSpaceLeft;
}

fn eof_read(ctx: ?*anyopaque, bw: *std.io.BufferedWriter, limit: Reader.Limit) anyerror!Reader.Status {
    _ = ctx;
    _ = bw;
    _ = limit;
    return error.EndOfStream;
}

fn eof_readv(ctx: ?*anyopaque, data: []const []u8) anyerror!Reader.Status {
    _ = ctx;
    _ = data;
    return error.EndOfStream;
}

/// Constructs `br` such that it will read from `buffer` and then end.
pub fn initFixed(br: *BufferedReader, buffer: []const u8) void {
    br.* = .{
        .seek = 0,
        .storage = .{
            .buffer = @constCast(buffer),
            .unbuffered_writer = .{
                .context = undefined,
                .vtable = &eof_writer,
            },
        },
        .unbuffered_reader = .{
            .context = undefined,
            .vtable = &eof_reader,
        },
    };
}

pub fn storageBuffer(br: *BufferedReader) []u8 {
    const storage = &br.storage;
    assert(storage.unbuffered_writer.vtable == &eof_writer);
    assert(br.unbuffered_reader.vtable == &eof_reader);
    return storage.buffer;
}

/// Although `BufferedReader` can easily satisfy the `Reader` interface, it's
/// generally more practical to pass a `BufferedReader` instance itself around,
/// since it will result in fewer calls across vtable boundaries.
pub fn reader(br: *BufferedReader) Reader {
    return .{
        .context = br,
        .vtable = &.{
            .read = passthru_read,
            .readv = passthru_readv,
        },
    };
}

fn passthru_read(ctx: ?*anyopaque, bw: *BufferedWriter, limit: Reader.Limit) anyerror!Reader.RwResult {
    const br: *BufferedReader = @alignCast(@ptrCast(ctx));
    const storage = &br.storage;
    const buffer = storage.buffer[0..storage.end];
    const buffered = buffer[br.seek..];
    const limited = buffered[0..limit.min(buffered.len)];
    if (limited.len > 0) {
        const result = bw.writeSplat(limited, 1);
        br.seek += result.len;
        return .{
            .len = result.len,
            .write_err = result.err,
            .write_end = result.end,
        };
    }
    return br.unbuffered_reader.read(bw, limit);
}

fn passthru_readv(ctx: ?*anyopaque, data: []const []u8) anyerror!Reader.Status {
    const br: *BufferedReader = @alignCast(@ptrCast(ctx));
    _ = br;
    _ = data;
    @panic("TODO");
}

pub fn seekBy(br: *BufferedReader, seek_by: i64) anyerror!void {
    if (seek_by < 0) try br.seekBackwardBy(@abs(seek_by)) else try br.seekForwardBy(@abs(seek_by));
}

pub fn seekBackwardBy(br: *BufferedReader, seek_by: u64) anyerror!void {
    if (seek_by > br.storage.end - br.seek) return error.Unseekable; // TODO
    br.seek += @abs(seek_by);
}

pub fn seekForwardBy(br: *BufferedReader, seek_by: u64) anyerror!void {
    const seek, const need_unbuffered_seek = @subWithOverflow(br.seek, @abs(seek_by));
    if (need_unbuffered_seek > 0) return error.Unseekable; // TODO
    br.seek = seek;
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
/// * `peekAll`
/// * `toss`
pub fn peek(br: *BufferedReader, n: usize) anyerror![]u8 {
    return (try br.peekAll(n))[0..n];
}

/// Returns the next buffered bytes from `unbuffered_reader`, after filling the buffer
/// with at least `n` bytes.
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
/// * `peek`
/// * `toss`
pub fn peekAll(br: *BufferedReader, n: usize) anyerror![]u8 {
    const storage = &br.storage;
    assert(n <= storage.buffer.len);
    try br.fill(n);
    return storage.buffer[br.seek..storage.end];
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
    assert(br.seek <= br.storage.end);
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
/// * `discardUntilEnd`
/// * `discardUpTo`
pub fn discard(br: *BufferedReader, n: usize) anyerror!void {
    if ((try discardUpTo(br, n)) != n) return error.EndOfStream;
}

/// Skips the next `n` bytes from the stream, advancing the seek position.
///
/// Unlike `toss` which is infallible, in this function `n` can be any amount.
///
/// Returns the number of bytes discarded, which is less than `n` if and only
/// if the stream reached the end.
///
/// See also:
/// * `discard`
/// * `toss`
/// * `discardUntilEnd`
pub fn discardUpTo(br: *BufferedReader, n: usize) anyerror!usize {
    const storage = &br.storage;
    var remaining = n;
    while (remaining > 0) {
        const proposed_seek = br.seek + remaining;
        if (proposed_seek <= storage.end) {
            br.seek = proposed_seek;
            return n;
        }
        remaining -= (storage.end - br.seek);
        storage.end = 0;
        br.seek = 0;
        const result = try br.unbuffered_reader.read(storage, .unlimited);
        assert(result.len == storage.end);
        if (remaining <= storage.end) continue;
        if (result.end) return n - remaining;
    }
    return n;
}

/// Reads the stream until the end, ignoring all the data.
/// Returns the number of bytes discarded.
pub fn discardUntilEnd(br: *BufferedReader) anyerror!usize {
    const storage = &br.storage;
    var total: usize = storage.end;
    storage.end = 0;
    total += try br.unbuffered_reader.discardUntilEnd();
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
    const storage = &br.storage;
    const in_buffer = storage.buffer[0..storage.end];
    const seek = br.seek;
    const proposed_seek = seek + in_buffer.len;
    if (proposed_seek <= in_buffer.len) {
        @memcpy(buffer, in_buffer[seek..proposed_seek]);
        br.seek = proposed_seek;
        return;
    }
    @memcpy(buffer[0..in_buffer.len], in_buffer);
    storage.end = 0;
    br.seek = 0;
    var i: usize = in_buffer.len;
    while (true) {
        const status = try br.unbuffered_reader.read(storage, .unlimited);
        const next_i = i + storage.end;
        if (next_i >= buffer.len) {
            const remaining = buffer[i..];
            @memcpy(remaining, storage.buffer[0..remaining.len]);
            br.seek = remaining.len;
            return;
        }
        if (status.end) return error.EndOfStream;
        @memcpy(buffer[i..next_i], storage.buffer[0..storage.end]);
        storage.end = 0;
        i = next_i;
    }
}

/// Returns the number of bytes read. If the number read is smaller than `buffer.len`, it
/// means the stream reached the end. Reaching the end of a stream is not an error
/// condition.
pub fn partialRead(br: *BufferedReader, buffer: []u8) anyerror!usize {
    _ = br;
    _ = buffer;
    @panic("TODO");
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
    const storage = &br.storage;
    const buffer = storage.buffer[0..storage.end];
    const seek = br.seek;
    if (std.mem.indexOfScalarPos(u8, buffer, seek, delimiter)) |end| {
        @branchHint(.likely);
        return buffer[seek .. end + 1];
    }
    const remainder = buffer[seek..];
    std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
    var i = remainder.len;
    storage.end = i;
    br.seek = 0;
    while (i < storage.buffer.len) {
        const status = try br.unbuffered_reader.read(storage, .none);
        if (std.mem.indexOfScalarPos(u8, storage.buffer[0..storage.end], i, delimiter)) |end| {
            return storage.buffer[0 .. end + 1];
        }
        if (status.end) return error.EndOfStream;
        i = storage.end;
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
    br.toss(result.len);
    return result;
}

pub fn peekDelimiterConclusive(br: *BufferedReader, delimiter: u8) anyerror![]u8 {
    const storage = &br.storage;
    const buffer = storage.buffer[0..storage.end];
    const seek = br.seek;
    if (std.mem.indexOfScalarPos(u8, buffer, seek, delimiter)) |end| {
        @branchHint(.likely);
        return buffer[seek..end];
    }
    const remainder = buffer[seek..];
    std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
    var i = remainder.len;
    storage.end = i;
    br.seek = 0;
    while (i < storage.buffer.len) {
        const status = try br.unbuffered_reader.read(storage, .unlimited);
        if (std.mem.indexOfScalarPos(u8, storage.buffer[0..storage.end], i, delimiter)) |end| {
            return storage.buffer[0 .. end + 1];
        }
        if (status.end) return storage.buffer[0..storage.end];
        i = storage.end;
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
    const storage = &br.storage;
    assert(n <= storage.buffer.len);
    const buffer = storage.buffer[0..storage.end];
    const seek = br.seek;
    if (seek + n <= buffer.len) {
        @branchHint(.likely);
        return;
    }
    const remainder = buffer[seek..];
    std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
    storage.end = remainder.len;
    br.seek = 0;
    while (true) {
        const status = try br.unbuffered_reader.read(storage, .unlimited);
        if (n <= storage.end) return;
        if (status.end) return error.EndOfStream;
    }
}

/// Reads 1 byte from the stream or returns `error.EndOfStream`.
pub fn takeByte(br: *BufferedReader) anyerror!u8 {
    const storage = &br.storage;
    const buffer = storage.buffer[0..storage.end];
    const seek = br.seek;
    if (seek >= buffer.len) {
        @branchHint(.unlikely);
        try fill(br, 1);
    }
    br.seek = seek + 1;
    return buffer[seek];
}

/// Same as `takeByte` except the returned byte is signed.
pub fn takeByteSigned(br: *BufferedReader) anyerror!i8 {
    return @bitCast(try br.takeByte());
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

/// Read a single LEB128 value as type T, or `error.Overflow` if the value cannot fit.
pub fn takeLeb128(br: *BufferedReader, comptime Result: type) anyerror!Result {
    const result_info = @typeInfo(Result).int;
    return std.math.cast(Result, try br.takeMultipleOf7Leb128(@Type(.{ .int = .{
        .signedness = result_info.signedness,
        .bits = std.mem.alignForwardAnyAlign(u16, result_info.bits, 7),
    } }))) orelse error.Overflow;
}

fn takeMultipleOf7Leb128(br: *BufferedReader, comptime Result: type) anyerror!Result {
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
        const buffer: []const packed struct(u8) { bits: u7, more: bool } = @ptrCast(try br.peekAll(1));
        for (buffer, 1..) |byte, len| {
            if (remaining_bits > 0) {
                result = @shlExact(@as(UnsignedResult, byte.bits), result_info.bits - 7) | if (result_info.bits > 7) @shrExact(result, 7) else 0;
                remaining_bits -= 7;
            } else if (fits) fits = switch (result_info.signedness) {
                .signed => @as(i7, @bitCast(byte.bits)) == @as(i7, @truncate(@as(Result, @bitCast(result)) >> (result_info.bits - 1))),
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

test peekAll {
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

test discardUntilEnd {
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

test takeLeb128 {
    return error.Unimplemented;
}
