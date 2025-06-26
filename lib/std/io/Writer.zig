const builtin = @import("builtin");
const native_endian = builtin.target.cpu.arch.endian();

const Writer = @This();
const std = @import("../std.zig");
const assert = std.debug.assert;
const Limit = std.io.Limit;
const File = std.fs.File;
const testing = std.testing;
const Allocator = std.mem.Allocator;

vtable: *const VTable,
/// If this has length zero, the writer is unbuffered, and `flush` is a no-op.
buffer: []u8,
/// In `buffer` before this are buffered bytes, after this is `undefined`.
end: usize = 0,
/// Tracks total number of bytes written to this `Writer`. This value
/// only increases. In the case of fixed mode, this value always equals `end`.
///
/// This value is maintained by the interface; `VTable` function
/// implementations need not modify it.
count: usize = 0,

pub const VTable = struct {
    /// Sends bytes to the logical sink. A write will only be sent here if it
    /// could not fit into `buffer`.
    ///
    /// `buffer[0..end]` is consumed first, followed by each slice of `data` in
    /// order. Elements of `data` may alias each other but may not alias
    /// `buffer`.
    ///
    /// This function modifies `Writer.end` and `Writer.buffer`.
    ///
    /// If `data.len` is zero, it indicates this is a "flush" operation; all
    /// remaining buffered data must be logically consumed. Generally, this
    /// means that `end` will be set to zero before returning, however, it is
    /// legal for implementations to manage that data differently. There may be
    /// subsequent calls to `drain` and `sendFile` after a flush operation.
    ///
    /// The last element of `data` is special. It is repeated as necessary so
    /// that it is written `splat` number of times, which may be zero.
    ///
    /// Number of bytes actually written is returned, excluding bytes from
    /// `buffer`. Bytes from `buffer` are tracked by modifying `end`.
    ///
    /// Number of bytes returned may be zero, which does not mean
    /// end-of-stream. A subsequent call may return nonzero, or signal end of
    /// stream via `error.WriteFailed`.
    drain: *const fn (w: *Writer, data: []const []const u8, splat: usize) Error!usize,

    /// Copies contents from an open file to the logical sink. `buffer[0..end]`
    /// is consumed first, followed by `limit` bytes from `file_reader`.
    ///
    /// Number of bytes logically written is returned. This excludes bytes from
    /// `buffer` because they have already been logically written. Number of
    /// bytes consumed from `buffer` are tracked by modifying `end`.
    ///
    /// Number of bytes returned may be zero, which does not necessarily mean
    /// end-of-stream. A subsequent call may return nonzero, or signal end of
    /// stream via `error.WriteFailed`. Caller must check `file_reader` state
    /// (`File.Reader.atEnd`) to disambiguate between a zero-length read or
    /// write, and whether the file reached the end.
    ///
    /// `error.Unimplemented` indicates the callee cannot offer a more
    /// efficient implementation than the caller performing its own reads.
    sendFile: *const fn (
        w: *Writer,
        file_reader: *File.Reader,
        /// Maximum amount of bytes to read from the file. Implementations may
        /// assume that the file size does not exceed this amount. Data from
        /// `buffer` does not count towards this limit.
        limit: Limit,
    ) FileError!usize = unimplementedSendFile,
};

pub const Error = error{
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const FileAllError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const FileReadingError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// Reached the end of the file being read.
    EndOfStream,
};

pub const FileError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// Reached the end of the file being read.
    EndOfStream,
    /// Indicates the caller should do its own file reading; the callee cannot
    /// offer a more efficient implementation.
    Unimplemented,
};

/// Writes to `buffer` and returns `error.WriteFailed` when it is full. Unless
/// modified externally, `count` will always equal `end`.
pub fn fixed(buffer: []u8) Writer {
    return .{
        .vtable = &.{ .drain = fixedDrain },
        .buffer = buffer,
    };
}

pub fn hashed(w: *Writer, hasher: anytype) Hashed(@TypeOf(hasher)) {
    return .{ .out = w, .hasher = hasher };
}

pub const failing: Writer = .{
    .vtable = &.{
        .drain = failingDrain,
        .sendFile = failingSendFile,
    },
};

pub fn discarding(buffer: []u8) Writer {
    return .{
        .vtable = &.{
            .drain = discardingDrain,
            .sendFile = discardingSendFile,
        },
        .buffer = buffer,
    };
}

/// Returns the contents not yet drained.
pub fn buffered(w: *const Writer) []u8 {
    return w.buffer[0..w.end];
}

pub fn countSplat(n: usize, data: []const []const u8, splat: usize) usize {
    assert(data.len > 0);
    var total: usize = n;
    for (data[0 .. data.len - 1]) |buf| total += buf.len;
    total += data[data.len - 1].len * splat;
    return total;
}

pub fn countSendFileUpperBound(n: usize, file_reader: *File.Reader, limit: Limit) ?usize {
    const total: u64 = @min(@intFromEnum(limit), file_reader.getSize() orelse return null);
    return std.math.lossyCast(usize, total + n);
}

/// If the total number of bytes of `data` fits inside `unusedCapacitySlice`,
/// this function is guaranteed to not fail, not call into `VTable`, and return
/// the total bytes inside `data`.
pub fn writeVec(w: *Writer, data: []const []const u8) Error!usize {
    return writeSplat(w, data, 1);
}

/// If the number of bytes to write based on `data` and `splat` fits inside
/// `unusedCapacitySlice`, this function is guaranteed to not fail, not call
/// into `VTable`, and return the full number of bytes.
pub fn writeSplat(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    assert(data.len > 0);
    const buffer = w.buffer;
    const count = countSplat(0, data, splat);
    if (w.end + count > buffer.len) {
        const n = try w.vtable.drain(w, data, splat);
        w.count += n;
        return n;
    }
    w.count += count;
    for (data) |bytes| {
        @memcpy(buffer[w.end..][0..bytes.len], bytes);
        w.end += bytes.len;
    }
    const pattern = data[data.len - 1];
    if (splat == 0) {
        @branchHint(.unlikely);
        w.end -= pattern.len;
        return count;
    }
    const remaining_splat = splat - 1;
    switch (pattern.len) {
        0 => {},
        1 => {
            @memset(buffer[w.end..][0..remaining_splat], pattern[0]);
            w.end += remaining_splat;
        },
        else => {
            const new_end = w.end + pattern.len * remaining_splat;
            while (w.end < new_end) : (w.end += pattern.len) {
                @memcpy(buffer[w.end..][0..pattern.len], pattern);
            }
        },
    }
    return count;
}

/// Equivalent to `writeSplat` but writes at most `limit` bytes.
pub fn writeSplatLimit(
    w: *Writer,
    data: []const []const u8,
    splat: usize,
    limit: Limit,
) Error!usize {
    _ = w;
    _ = data;
    _ = splat;
    _ = limit;
    @panic("TODO");
}

/// Drains all remaining buffered data.
///
/// It is legal for `VTable.drain` implementations to refrain from modifying
/// `end`.
pub fn flush(w: *Writer) Error!void {
    assert(0 == try w.vtable.drain(w, &.{}, 0));
    if (w.end != 0) assert(w.vtable.drain == &fixedDrain);
}

/// Calls `VTable.drain` but hides the last `preserve_length` bytes from the
/// implementation, keeping them buffered.
pub fn drainPreserve(w: *Writer, preserve_length: usize) Error!void {
    const temp_end = w.end -| preserve_length;
    const preserved = w.buffer[temp_end..w.end];
    w.end = temp_end;
    defer w.end += preserved.len;
    assert(0 == try w.vtable.drain(w, &.{""}, 1));
    assert(w.end <= temp_end + preserved.len);
    @memmove(w.buffer[w.end..][0..preserved.len], preserved);
}

/// Forwards a `drain` to a second `Writer` instance. `w` is only used for its
/// buffer, but it has its `end` and `count` adjusted accordingly depending on
/// how much was consumed.
///
/// Returns how many bytes from `data` were consumed.
pub fn drainTo(noalias w: *Writer, noalias other: *Writer, data: []const []const u8, splat: usize) Error!usize {
    assert(w != other);
    const header = w.buffered();
    const new_end = other.end + header.len;
    if (new_end <= other.buffer.len) {
        @memcpy(other.buffer[other.end..][0..header.len], header);
        other.end = new_end;
        other.count += header.len;
        w.end = 0;
        const n = try other.vtable.drain(other, data, splat);
        other.count += n;
        return n;
    }
    if (other.vtable == &VectorWrapper.vtable) {
        const wrapper: *VectorWrapper = @fieldParentPtr("writer", w);
        while (wrapper.it.next()) |dest| {
            _ = dest;
            @panic("TODO");
        }
    }
    var vecs: [8][]const u8 = undefined; // Arbitrarily chosen size.
    var i: usize = 1;
    vecs[0] = header;
    for (data) |buf| {
        if (buf.len == 0) continue;
        vecs[i] = buf;
        i += 1;
        if (vecs.len - i == 0) break;
    }
    const new_splat = if (vecs[i - 1].ptr == data[data.len - 1].ptr) splat else 1;
    const n = try other.vtable.drain(other, vecs[0..i], new_splat);
    other.count += n;
    if (n < header.len) {
        const remaining = w.buffer[n..w.end];
        @memmove(w.buffer[0..remaining.len], remaining);
        w.end = remaining.len;
        return 0;
    }
    defer w.end = 0;
    return n - header.len;
}

pub fn drainToLimit(
    noalias w: *Writer,
    noalias other: *Writer,
    data: []const []const u8,
    splat: usize,
    limit: Limit,
) Error!usize {
    assert(w != other);
    _ = data;
    _ = splat;
    _ = limit;
    @panic("TODO");
}

pub fn unusedCapacitySlice(w: *const Writer) []u8 {
    return w.buffer[w.end..];
}

pub fn unusedCapacityLen(w: *const Writer) usize {
    return w.buffer.len - w.end;
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
pub fn writableArray(w: *Writer, comptime len: usize) Error!*[len]u8 {
    const big_slice = try w.writableSliceGreedy(len);
    advance(w, len);
    return big_slice[0..len];
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
pub fn writableSlice(w: *Writer, len: usize) Error![]u8 {
    const big_slice = try w.writableSliceGreedy(len);
    advance(w, len);
    return big_slice[0..len];
}

/// Asserts the provided buffer has total capacity enough for `minimum_length`.
///
/// Does not `advance` the buffer end position.
///
/// If `minimum_length` is zero, this is equivalent to `unusedCapacitySlice`.
pub fn writableSliceGreedy(w: *Writer, minimum_length: usize) Error![]u8 {
    assert(w.buffer.len >= minimum_length);
    while (w.buffer.len - w.end < minimum_length) {
        assert(0 == try w.vtable.drain(w, &.{""}, 1));
    } else {
        @branchHint(.likely);
        return w.buffer[w.end..];
    }
}

/// Asserts the provided buffer has total capacity enough for `minimum_length`
/// and `preserve_length` combined.
///
/// Does not `advance` the buffer end position.
///
/// When draining the buffer, ensures that at least `preserve_length` bytes
/// remain buffered.
///
/// If `preserve_length` is zero, this is equivalent to `writableSliceGreedy`.
pub fn writableSliceGreedyPreserve(w: *Writer, preserve_length: usize, minimum_length: usize) Error![]u8 {
    assert(w.buffer.len >= preserve_length + minimum_length);
    while (w.buffer.len - w.end < minimum_length) {
        try drainPreserve(w, preserve_length);
    } else {
        @branchHint(.likely);
        return w.buffer[w.end..];
    }
}

pub const WritableVectorIterator = struct {
    first: []u8,
    middle: []const []u8 = &.{},
    last: []u8 = &.{},
    index: usize = 0,

    pub fn next(it: *WritableVectorIterator) ?[]u8 {
        while (true) {
            const i = it.index;
            it.index += 1;
            if (i == 0) {
                if (it.first.len == 0) continue;
                return it.first;
            }
            const middle_index = i - 1;
            if (middle_index < it.middle.len) {
                const middle = it.middle[middle_index];
                if (middle.len == 0) continue;
                return middle;
            }
            if (middle_index == it.middle.len) {
                if (it.last.len == 0) continue;
                return it.last;
            }
            return null;
        }
    }
};

pub const VectorWrapper = struct {
    writer: Writer,
    it: WritableVectorIterator,
    pub const vtable: VTable = .{ .drain = fixedDrain };
};

pub fn writableVectorIterator(w: *Writer) Error!WritableVectorIterator {
    if (w.vtable == &VectorWrapper.vtable) {
        const wrapper: *VectorWrapper = @fieldParentPtr("writer", w);
        return wrapper.it;
    }
    return .{ .first = try writableSliceGreedy(w, 1) };
}

pub fn writableVectorPosix(w: *Writer, buffer: []std.posix.iovec, limit: Limit) Error![]std.posix.iovec {
    var it = try writableVectorIterator(w);
    var i: usize = 0;
    var remaining = limit;
    while (it.next()) |full_buffer| {
        if (!remaining.nonzero()) break;
        if (buffer.len - i == 0) break;
        const buf = remaining.slice(full_buffer);
        if (buf.len == 0) continue;
        buffer[i] = .{ .base = buf.ptr, .len = buf.len };
        i += 1;
        remaining = remaining.subtract(buf.len).?;
    }
    return buffer[0..i];
}

pub fn ensureUnusedCapacity(w: *Writer, n: usize) Error!void {
    _ = try writableSliceGreedy(w, n);
}

pub fn undo(w: *Writer, n: usize) void {
    w.end -= n;
    w.count -= n;
}

/// After calling `writableSliceGreedy`, this function tracks how many bytes
/// were written to it.
///
/// This is not needed when using `writableSlice` or `writableArray`.
pub fn advance(w: *Writer, n: usize) void {
    const new_end = w.end + n;
    assert(new_end <= w.buffer.len);
    w.end = new_end;
    w.count += n;
}

/// After calling `writableVector`, this function tracks how many bytes were
/// written to it.
pub fn advanceVector(w: *Writer, n: usize) usize {
    w.count += n;
    return consume(w, n);
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `VTable.writeSplat`.
pub fn writeVecAll(w: *Writer, data: [][]const u8) Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    while (index < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try w.writeVec(data[index..]);
        }
        while (index < data.len and truncate >= data[index].len) {
            truncate -= data[index].len;
            index += 1;
        }
    }
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `VTable.writeSplat`.
pub fn writeSplatAll(w: *Writer, data: [][]const u8, splat: usize) Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    var remaining_splat = splat;
    while (index + 1 < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try w.writeSplat(data[index..], remaining_splat);
        }
        while (truncate >= data[index].len) {
            if (index + 1 < data.len) {
                truncate -= data[index].len;
                index += 1;
            } else {
                const last = data[data.len - 1];
                remaining_splat -= @divExact(truncate, last.len);
                while (remaining_splat > 0) {
                    const n = try w.writeSplat(data[data.len - 1 ..][0..1], remaining_splat);
                    remaining_splat -= @divExact(n, last.len);
                }
                return;
            }
        }
    }
}

pub fn write(w: *Writer, bytes: []const u8) Error!usize {
    if (w.end + bytes.len <= w.buffer.len) {
        @branchHint(.likely);
        @memcpy(w.buffer[w.end..][0..bytes.len], bytes);
        w.end += bytes.len;
        w.count += bytes.len;
        return bytes.len;
    }
    const n = try w.vtable.drain(w, &.{bytes}, 1);
    w.count += n;
    return n;
}

/// Asserts `buffer` capacity exceeds `preserve_length`.
pub fn writePreserve(w: *Writer, preserve_length: usize, bytes: []const u8) Error!usize {
    assert(preserve_length <= w.buffer.len);
    if (w.end + bytes.len <= w.buffer.len) {
        @branchHint(.likely);
        @memcpy(w.buffer[w.end..][0..bytes.len], bytes);
        w.end += bytes.len;
        w.count += bytes.len;
        return bytes.len;
    }
    const temp_end = w.end -| preserve_length;
    const preserved = w.buffer[temp_end..w.end];
    w.end = temp_end;
    defer w.end += preserved.len;
    const n = try w.vtable.drain(w, &.{bytes}, 1);
    w.count += n;
    assert(w.end <= temp_end + preserved.len);
    @memmove(w.buffer[w.end..][0..preserved.len], preserved);
    return n;
}

/// Calls `drain` as many times as necessary such that all of `bytes` are
/// transferred.
pub fn writeAll(w: *Writer, bytes: []const u8) Error!void {
    var index: usize = 0;
    while (index < bytes.len) index += try w.write(bytes[index..]);
}

/// Calls `drain` as many times as necessary such that all of `bytes` are
/// transferred.
///
/// When draining the buffer, ensures that at least `preserve_length` bytes
/// remain buffered.
///
/// Asserts `buffer` capacity exceeds `preserve_length`.
pub fn writeAllPreserve(w: *Writer, preserve_length: usize, bytes: []const u8) Error!void {
    var index: usize = 0;
    while (index < bytes.len) index += try w.writePreserve(preserve_length, bytes[index..]);
}

pub fn print(w: *Writer, comptime format: []const u8, args: anytype) Error!void {
    try std.fmt.format(w, format, args);
}

/// Calls `drain` as many times as necessary such that `byte` is transferred.
pub fn writeByte(w: *Writer, byte: u8) Error!void {
    while (w.buffer.len - w.end == 0) {
        const n = try w.vtable.drain(w, &.{&.{byte}}, 1);
        if (n > 0) {
            w.count += 1;
            return;
        }
    } else {
        @branchHint(.likely);
        w.buffer[w.end] = byte;
        w.end += 1;
        w.count += 1;
    }
}

/// When draining the buffer, ensures that at least `preserve_length` bytes
/// remain buffered.
pub fn writeBytePreserve(w: *Writer, preserve_length: usize, byte: u8) Error!void {
    while (w.buffer.len - w.end == 0) {
        try drainPreserve(w, preserve_length);
    } else {
        @branchHint(.likely);
        w.buffer[w.end] = byte;
        w.end += 1;
        w.count += 1;
    }
}

/// Writes the same byte many times, performing the underlying write call as
/// many times as necessary.
pub fn splatByteAll(w: *Writer, byte: u8, n: usize) Error!void {
    var remaining: usize = n;
    while (remaining > 0) remaining -= try w.splatByte(byte, remaining);
}

/// Writes the same byte many times, allowing short writes.
///
/// Does maximum of one underlying `VTable.drain`.
pub fn splatByte(w: *Writer, byte: u8, n: usize) Error!usize {
    return writeSplat(w, &.{&.{byte}}, n);
}

/// Writes the same slice many times, performing the underlying write call as
/// many times as necessary.
pub fn splatBytesAll(w: *Writer, bytes: []const u8, splat: usize) Error!void {
    var remaining_bytes: usize = bytes.len * splat;
    remaining_bytes -= try w.splatBytes(bytes, splat);
    while (remaining_bytes > 0) {
        const leftover = remaining_bytes % bytes.len;
        const buffers: [2][]const u8 = .{ bytes[bytes.len - leftover ..], bytes };
        remaining_bytes -= try w.splatBytes(&buffers, splat);
    }
}

/// Writes the same slice many times, allowing short writes.
///
/// Does maximum of one underlying `VTable.writeSplat`.
pub fn splatBytes(w: *Writer, bytes: []const u8, n: usize) Error!usize {
    return writeSplat(w, &.{bytes}, n);
}

/// Asserts the `buffer` was initialized with a capacity of at least `@sizeOf(T)` bytes.
pub inline fn writeInt(w: *Writer, comptime T: type, value: T, endian: std.builtin.Endian) Error!void {
    var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
    std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
    return w.writeAll(&bytes);
}

pub fn writeStruct(w: *Writer, value: anytype) Error!void {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(@TypeOf(value)).@"struct".layout != .auto);
    return w.writeAll(std.mem.asBytes(&value));
}

/// The function is inline to avoid the dead code in case `endian` is
/// comptime-known and matches host endianness.
/// TODO: make sure this value is not a reference type
pub inline fn writeStructEndian(w: *Writer, value: anytype, endian: std.builtin.Endian) Error!void {
    if (native_endian == endian) {
        return w.writeStruct(value);
    } else {
        var copy = value;
        std.mem.byteSwapAllFields(@TypeOf(value), &copy);
        return w.writeStruct(copy);
    }
}

pub inline fn writeSliceEndian(
    w: *Writer,
    Elem: type,
    slice: []const Elem,
    endian: std.builtin.Endian,
) Error!void {
    if (native_endian == endian) {
        return writeAll(w, @ptrCast(slice));
    } else {
        return w.writeArraySwap(w, Elem, slice);
    }
}

/// Asserts that the buffer storage capacity is at least enough to store `@sizeOf(Elem)`
pub fn writeSliceSwap(w: *Writer, Elem: type, slice: []const Elem) Error!void {
    // copy to storage first, then swap in place
    _ = w;
    _ = slice;
    @panic("TODO");
}

/// Unlike `writeSplat` and `writeVec`, this function will call into `VTable`
/// even if there is enough buffer capacity for the file contents.
///
/// Although it would be possible to eliminate `error.Unimplemented` from the
/// error set by reading directly into the buffer in such case, this is not
/// done because it is more efficient to do it higher up the call stack so that
/// the error does not occur with each write.
///
/// See `sendFileReading` for an alternative that does not have
/// `error.Unimplemented` in the error set.
pub fn sendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    return w.vtable.sendFile(w, file_reader, limit);
}

/// Forwards a `sendFile` to a second `Writer` instance. `w` is only used for
/// its buffer, but it has its `end` and `count` adjusted accordingly depending
/// on how much was consumed.
///
/// Returns how many bytes from `file_reader` were consumed.
pub fn sendFileTo(
    noalias w: *Writer,
    noalias other: *Writer,
    file_reader: *File.Reader,
    limit: Limit,
) FileError!usize {
    assert(w != other);
    const header = w.buffered();
    const new_end = other.end + header.len;
    if (new_end <= other.buffer.len) {
        @memcpy(other.buffer[other.end..][0..header.len], header);
        other.end = new_end;
        other.count += header.len;
        w.end = 0;
        return other.vtable.sendFile(other, file_reader, limit);
    }
    assert(header.len > 0);
    var vec_buf: [2][]const u8 = .{ header, undefined };
    var vec_i: usize = 1;
    const buffered_contents = limit.slice(file_reader.interface.buffered());
    if (buffered_contents.len > 0) {
        vec_buf[vec_i] = buffered_contents;
        vec_i += 1;
    }
    const n = try other.vtable.drain(other, vec_buf[0..vec_i], 1);
    other.count += n;
    if (n < header.len) {
        const remaining = w.buffer[n..w.end];
        @memmove(w.buffer[0..remaining.len], remaining);
        w.end = remaining.len;
        return 0;
    }
    w.end = 0;
    const tossed = n - header.len;
    file_reader.interface.toss(tossed);
    return tossed;
}

/// Asserts nonzero buffer capacity.
pub fn sendFileReading(w: *Writer, file_reader: *File.Reader, limit: Limit) FileReadingError!usize {
    const dest = limit.slice(try w.writableSliceGreedy(1));
    const n = try file_reader.read(dest);
    w.advance(n);
    return n;
}

pub fn sendFileAll(w: *Writer, file_reader: *File.Reader, limit: Limit) FileAllError!usize {
    var remaining = @intFromEnum(limit);
    while (remaining > 0) {
        const n = sendFile(w, file_reader, .limited(remaining)) catch |err| switch (err) {
            error.EndOfStream => break,
            error.Unimplemented => {
                file_reader.mode = file_reader.mode.toReading();
                remaining -= try w.sendFileReadingAll(file_reader, .limited(remaining));
                break;
            },
            else => |e| return e,
        };
        remaining -= n;
    }
    return @intFromEnum(limit) - remaining;
}

/// Equivalent to `sendFileAll` but uses direct `pread` and `read` calls on
/// `file` rather than `sendFile`. This is generally used as a fallback when
/// the underlying implementation returns `error.Unimplemented`, which is why
/// that error code does not appear in this function's error set.
///
/// Asserts nonzero buffer capacity.
pub fn sendFileReadingAll(w: *Writer, file_reader: *File.Reader, limit: Limit) FileAllError!usize {
    var remaining = @intFromEnum(limit);
    while (remaining > 0) {
        remaining -= sendFileReading(w, file_reader, .limited(remaining)) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
    }
    return @intFromEnum(limit) - remaining;
}

pub fn alignBuffer(
    w: *Writer,
    buffer: []const u8,
    width: usize,
    alignment: std.fmt.Alignment,
    fill: u8,
) Error!void {
    const padding = if (buffer.len < width) width - buffer.len else 0;
    if (padding == 0) {
        @branchHint(.likely);
        return w.writeAll(buffer);
    }
    switch (alignment) {
        .left => {
            try w.writeAll(buffer);
            try w.splatByteAll(fill, padding);
        },
        .center => {
            const left_padding = padding / 2;
            const right_padding = (padding + 1) / 2;
            try w.splatByteAll(fill, left_padding);
            try w.writeAll(buffer);
            try w.splatByteAll(fill, right_padding);
        },
        .right => {
            try w.splatByteAll(fill, padding);
            try w.writeAll(buffer);
        },
    }
}

pub fn alignBufferOptions(w: *Writer, buffer: []const u8, options: std.fmt.Options) Error!void {
    return w.alignBuffer(buffer, options.width orelse buffer.len, options.alignment, options.fill);
}

pub fn printAddress(w: *Writer, value: anytype) Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .pointer => |info| {
            try w.writeAll(@typeName(info.child) ++ "@");
            if (info.size == .slice)
                try w.printIntOptions(@intFromPtr(value.ptr), 16, .lower, .{})
            else
                try w.printIntOptions(@intFromPtr(value), 16, .lower, .{});
            return;
        },
        .optional => |info| {
            if (@typeInfo(info.child) == .pointer) {
                try w.writeAll(@typeName(info.child) ++ "@");
                try w.printIntOptions(@intFromPtr(value), 16, .lower, .{});
                return;
            }
        },
        else => {},
    }

    @compileError("cannot format non-pointer type " ++ @typeName(T) ++ " with * specifier");
}

pub fn printValue(
    w: *Writer,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
    max_depth: usize,
) Error!void {
    const T = @TypeOf(value);

    if (comptime std.mem.eql(u8, fmt, "*")) {
        return w.printAddress(value);
    }

    const is_any = comptime std.mem.eql(u8, fmt, ANY);
    if (!is_any and std.meta.hasMethod(T, "format")) {
        if (fmt.len > 0 and fmt[0] == 'f') {
            return value.format(w, fmt[1..]);
        } else if (fmt.len == 0) {
            // after 0.15.0 is tagged, delete the hasMethod condition and this compile error
            @compileError("ambiguous format string; specify {f} to call format method, or {any} to skip it");
        }
    }

    switch (@typeInfo(T)) {
        .float, .comptime_float => return w.printFloat(if (is_any) "d" else fmt, options, value),
        .int, .comptime_int => return w.printInt(if (is_any) "d" else fmt, options, value),
        .bool => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions(if (value) "true" else "false", options);
        },
        .void => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions("void", options);
        },
        .optional => {
            const remaining_fmt = comptime if (fmt.len > 0 and fmt[0] == '?')
                stripOptionalOrErrorUnionSpec(fmt)
            else if (is_any)
                ANY
            else
                @compileError("cannot print optional without a specifier (i.e. {?} or {any})");
            if (value) |payload| {
                return w.printValue(remaining_fmt, options, payload, max_depth);
            } else {
                return w.alignBufferOptions("null", options);
            }
        },
        .error_union => {
            const remaining_fmt = comptime if (fmt.len > 0 and fmt[0] == '!')
                stripOptionalOrErrorUnionSpec(fmt)
            else if (is_any)
                ANY
            else
                @compileError("cannot print error union without a specifier (i.e. {!} or {any})");
            if (value) |payload| {
                return w.printValue(remaining_fmt, options, payload, max_depth);
            } else |err| {
                return w.printValue("", options, err, max_depth);
            }
        },
        .error_set => {
            if (fmt.len == 1 and fmt[0] == 's') return w.writeAll(@errorName(value));
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            try printErrorSet(w, value);
        },
        .@"enum" => {
            if (fmt.len == 1 and fmt[0] == 's') {
                try w.writeAll(@tagName(value));
                return;
            }
            if (!is_any) {
                if (fmt.len != 0) return printValue(w, fmt, options, @intFromEnum(value), max_depth);
                return printValue(w, ANY, options, value, max_depth);
            }
            const enum_info = @typeInfo(T).@"enum";
            if (enum_info.is_exhaustive) {
                var vecs: [3][]const u8 = .{ @typeName(T), ".", @tagName(value) };
                try w.writeVecAll(&vecs);
                return;
            }
            try w.writeAll(@typeName(T));
            @setEvalBranchQuota(3 * enum_info.fields.len);
            inline for (enum_info.fields) |field| {
                if (@intFromEnum(value) == field.value) {
                    try w.writeAll(".");
                    try w.writeAll(@tagName(value));
                    return;
                }
            }
            try w.writeByte('(');
            try w.printValue(ANY, options, @intFromEnum(value), max_depth);
            try w.writeByte(')');
        },
        .@"union" => |info| {
            if (!is_any) {
                if (fmt.len != 0) invalidFmtError(fmt, value);
                return printValue(w, ANY, options, value, max_depth);
            }
            try w.writeAll(@typeName(T));
            if (max_depth == 0) {
                try w.writeAll("{ ... }");
                return;
            }
            if (info.tag_type) |UnionTagType| {
                try w.writeAll("{ .");
                try w.writeAll(@tagName(@as(UnionTagType, value)));
                try w.writeAll(" = ");
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        try w.printValue(ANY, options, @field(value, u_field.name), max_depth - 1);
                    }
                }
                try w.writeAll(" }");
            } else {
                try w.writeByte('@');
                try w.printIntOptions(@intFromPtr(&value), 16, .lower, options);
            }
        },
        .@"struct" => |info| {
            if (!is_any) {
                if (fmt.len != 0) invalidFmtError(fmt, value);
                return printValue(w, ANY, options, value, max_depth);
            }
            if (info.is_tuple) {
                // Skip the type and field names when formatting tuples.
                if (max_depth == 0) {
                    try w.writeAll("{ ... }");
                    return;
                }
                try w.writeAll("{");
                inline for (info.fields, 0..) |f, i| {
                    if (i == 0) {
                        try w.writeAll(" ");
                    } else {
                        try w.writeAll(", ");
                    }
                    try w.printValue(ANY, options, @field(value, f.name), max_depth - 1);
                }
                try w.writeAll(" }");
                return;
            }
            try w.writeAll(@typeName(T));
            if (max_depth == 0) {
                try w.writeAll("{ ... }");
                return;
            }
            try w.writeAll("{");
            inline for (info.fields, 0..) |f, i| {
                if (i == 0) {
                    try w.writeAll(" .");
                } else {
                    try w.writeAll(", .");
                }
                try w.writeAll(f.name);
                try w.writeAll(" = ");
                try w.printValue(ANY, options, @field(value, f.name), max_depth - 1);
            }
            try w.writeAll(" }");
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array, .@"enum", .@"union", .@"struct" => {
                    return w.printValue(fmt, options, value.*, max_depth);
                },
                else => {
                    var buffers: [2][]const u8 = .{ @typeName(ptr_info.child), "@" };
                    try w.writeVecAll(&buffers);
                    try w.printIntOptions(@intFromPtr(value), 16, .lower, options);
                    return;
                },
            },
            .many, .c => {
                if (ptr_info.sentinel() != null)
                    return w.printValue(fmt, options, std.mem.span(value), max_depth);
                if (fmt.len == 1 and fmt[0] == 's' and ptr_info.child == u8)
                    return w.alignBufferOptions(std.mem.span(value), options);
                if (!is_any and fmt.len == 0)
                    @compileError("cannot format pointer without a specifier (i.e. {s} or {*})");
                if (!is_any and fmt.len != 0)
                    invalidFmtError(fmt, value);
                try w.printAddress(value);
            },
            .slice => {
                if (!is_any and fmt.len == 0)
                    @compileError("cannot format slice without a specifier (i.e. {s}, {x}, {b64}, or {any})");
                if (max_depth == 0)
                    return w.writeAll("{ ... }");
                if (ptr_info.child == u8) switch (fmt.len) {
                    1 => switch (fmt[0]) {
                        's' => return w.alignBufferOptions(value, options),
                        'x' => return w.printHex(value, .lower),
                        'X' => return w.printHex(value, .upper),
                        else => {},
                    },
                    3 => if (fmt[0] == 'b' and fmt[1] == '6' and fmt[2] == '4') {
                        return w.printBase64(value);
                    },
                    else => {},
                };
                try w.writeAll("{ ");
                for (value, 0..) |elem, i| {
                    try w.printValue(fmt, options, elem, max_depth - 1);
                    if (i != value.len - 1) {
                        try w.writeAll(", ");
                    }
                }
                try w.writeAll(" }");
            },
        },
        .array => |info| {
            if (fmt.len == 0)
                @compileError("cannot format array without a specifier (i.e. {s} or {any})");
            if (max_depth == 0) {
                return w.writeAll("{ ... }");
            }
            if (info.child == u8) {
                if (fmt[0] == 's') {
                    return w.alignBufferOptions(&value, options);
                } else if (fmt[0] == 'x') {
                    return w.printHex(&value, .lower);
                } else if (fmt[0] == 'X') {
                    return w.printHex(&value, .upper);
                }
            }
            try w.writeAll("{ ");
            for (value, 0..) |elem, i| {
                try w.printValue(fmt, options, elem, max_depth - 1);
                if (i < value.len - 1) {
                    try w.writeAll(", ");
                }
            }
            try w.writeAll(" }");
        },
        .vector => |info| {
            if (max_depth == 0) {
                return w.writeAll("{ ... }");
            }
            try w.writeAll("{ ");
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                try w.printValue(fmt, options, value[i], max_depth - 1);
                if (i < info.len - 1) {
                    try w.writeAll(", ");
                }
            }
            try w.writeAll(" }");
        },
        .@"fn" => @compileError("unable to format function body type, use '*const " ++ @typeName(T) ++ "' for a function pointer type"),
        .type => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions(@typeName(value), options);
        },
        .enum_literal => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            const buffer = [_]u8{'.'} ++ @tagName(value);
            return w.alignBufferOptions(buffer, options);
        },
        .null => {
            if (!is_any and fmt.len != 0) invalidFmtError(fmt, value);
            return w.alignBufferOptions("null", options);
        },
        else => @compileError("unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

fn printErrorSet(w: *Writer, error_set: anyerror) Error!void {
    var vecs: [2][]const u8 = .{ "error.", @errorName(error_set) };
    try w.writeVecAll(&vecs);
}

pub fn printInt(
    w: *Writer,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
) Error!void {
    const int_value = if (@TypeOf(value) == comptime_int) blk: {
        const Int = std.math.IntFittingRange(value, value);
        break :blk @as(Int, value);
    } else value;

    switch (fmt.len) {
        0 => return w.printIntOptions(int_value, 10, .lower, options),
        1 => switch (fmt[0]) {
            'd' => return w.printIntOptions(int_value, 10, .lower, options),
            'c' => {
                if (@typeInfo(@TypeOf(int_value)).int.bits <= 8) {
                    return w.printAsciiChar(@as(u8, int_value), options);
                } else {
                    @compileError("cannot print integer that is larger than 8 bits as an ASCII character");
                }
            },
            'u' => {
                if (@typeInfo(@TypeOf(int_value)).int.bits <= 21) {
                    return w.printUnicodeCodepoint(@as(u21, int_value), options);
                } else {
                    @compileError("cannot print integer that is larger than 21 bits as an UTF-8 sequence");
                }
            },
            'b' => return w.printIntOptions(int_value, 2, .lower, options),
            'x' => return w.printIntOptions(int_value, 16, .lower, options),
            'X' => return w.printIntOptions(int_value, 16, .upper, options),
            'o' => return w.printIntOptions(int_value, 8, .lower, options),
            'B' => return w.printByteSize(int_value, .decimal, options),
            'D' => return w.printDuration(int_value, options),
            else => invalidFmtError(fmt, value),
        },
        2 => {
            if (fmt[0] == 'B' and fmt[1] == 'i') {
                return w.printByteSize(int_value, .binary, options);
            } else {
                invalidFmtError(fmt, value);
            }
        },
        else => invalidFmtError(fmt, value),
    }
    comptime unreachable;
}

pub fn printAsciiChar(w: *Writer, c: u8, options: std.fmt.Options) Error!void {
    return w.alignBufferOptions(@as(*const [1]u8, &c), options);
}

pub fn printAscii(w: *Writer, bytes: []const u8, options: std.fmt.Options) Error!void {
    return w.alignBufferOptions(bytes, options);
}

pub fn printUnicodeCodepoint(w: *Writer, c: u21, options: std.fmt.Options) Error!void {
    var buf: [4]u8 = undefined;
    const len = try std.unicode.utf8Encode(c, &buf);
    return w.alignBufferOptions(buf[0..len], options);
}

pub fn printIntOptions(
    w: *Writer,
    value: anytype,
    base: u8,
    case: std.fmt.Case,
    options: std.fmt.Options,
) Error!void {
    assert(base >= 2);

    const int_value = if (@TypeOf(value) == comptime_int) blk: {
        const Int = std.math.IntFittingRange(value, value);
        break :blk @as(Int, value);
    } else value;

    const value_info = @typeInfo(@TypeOf(int_value)).int;

    // The type must have the same size as `base` or be wider in order for the
    // division to work
    const min_int_bits = comptime @max(value_info.bits, 8);
    const MinInt = std.meta.Int(.unsigned, min_int_bits);

    const abs_value = @abs(int_value);
    // The worst case in terms of space needed is base 2, plus 1 for the sign
    var buf: [1 + @max(@as(comptime_int, value_info.bits), 1)]u8 = undefined;

    var a: MinInt = abs_value;
    var index: usize = buf.len;

    if (base == 10) {
        while (a >= 100) : (a = @divTrunc(a, 100)) {
            index -= 2;
            buf[index..][0..2].* = std.fmt.digits2(@intCast(a % 100));
        }

        if (a < 10) {
            index -= 1;
            buf[index] = '0' + @as(u8, @intCast(a));
        } else {
            index -= 2;
            buf[index..][0..2].* = std.fmt.digits2(@intCast(a));
        }
    } else {
        while (true) {
            const digit = a % base;
            index -= 1;
            buf[index] = std.fmt.digitToChar(@intCast(digit), case);
            a /= base;
            if (a == 0) break;
        }
    }

    if (value_info.signedness == .signed) {
        if (value < 0) {
            // Negative integer
            index -= 1;
            buf[index] = '-';
        } else if (options.width == null or options.width.? == 0) {
            // Positive integer, omit the plus sign
        } else {
            // Positive integer
            index -= 1;
            buf[index] = '+';
        }
    }

    return w.alignBufferOptions(buf[index..], options);
}

pub fn printFloat(
    w: *Writer,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
) Error!void {
    var buf: [std.fmt.float.bufferSize(.decimal, f64)]u8 = undefined;

    if (fmt.len > 1) invalidFmtError(fmt, value);
    switch (if (fmt.len == 0) 'e' else fmt[0]) {
        'e' => {
            const s = std.fmt.float.render(&buf, value, .{ .mode = .scientific, .precision = options.precision }) catch |err| switch (err) {
                error.BufferTooSmall => "(float)",
            };
            return w.alignBufferOptions(s, options);
        },
        'd' => {
            const s = std.fmt.float.render(&buf, value, .{ .mode = .decimal, .precision = options.precision }) catch |err| switch (err) {
                error.BufferTooSmall => "(float)",
            };
            return w.alignBufferOptions(s, options);
        },
        'x' => {
            var sub_bw: Writer = .fixed(&buf);
            sub_bw.printFloatHexadecimal(value, options.precision) catch unreachable;
            return w.alignBufferOptions(sub_bw.buffered(), options);
        },
        else => invalidFmtError(fmt, value),
    }
}

pub fn printFloatHexadecimal(w: *Writer, value: anytype, opt_precision: ?usize) Error!void {
    if (std.math.signbit(value)) try w.writeByte('-');
    if (std.math.isNan(value)) return w.writeAll("nan");
    if (std.math.isInf(value)) return w.writeAll("inf");

    const T = @TypeOf(value);
    const TU = std.meta.Int(.unsigned, @bitSizeOf(T));

    const mantissa_bits = std.math.floatMantissaBits(T);
    const fractional_bits = std.math.floatFractionalBits(T);
    const exponent_bits = std.math.floatExponentBits(T);
    const mantissa_mask = (1 << mantissa_bits) - 1;
    const exponent_mask = (1 << exponent_bits) - 1;
    const exponent_bias = (1 << (exponent_bits - 1)) - 1;

    const as_bits: TU = @bitCast(value);
    var mantissa = as_bits & mantissa_mask;
    var exponent: i32 = @as(u16, @truncate((as_bits >> mantissa_bits) & exponent_mask));

    const is_denormal = exponent == 0 and mantissa != 0;
    const is_zero = exponent == 0 and mantissa == 0;

    if (is_zero) {
        // Handle this case here to simplify the logic below.
        try w.writeAll("0x0");
        if (opt_precision) |precision| {
            if (precision > 0) {
                try w.writeAll(".");
                try w.splatByteAll('0', precision);
            }
        } else {
            try w.writeAll(".0");
        }
        try w.writeAll("p0");
        return;
    }

    if (is_denormal) {
        // Adjust the exponent for printing.
        exponent += 1;
    } else {
        if (fractional_bits == mantissa_bits)
            mantissa |= 1 << fractional_bits; // Add the implicit integer bit.
    }

    const mantissa_digits = (fractional_bits + 3) / 4;
    // Fill in zeroes to round the fraction width to a multiple of 4.
    mantissa <<= mantissa_digits * 4 - fractional_bits;

    if (opt_precision) |precision| {
        // Round if needed.
        if (precision < mantissa_digits) {
            // We always have at least 4 extra bits.
            var extra_bits = (mantissa_digits - precision) * 4;
            // The result LSB is the Guard bit, we need two more (Round and
            // Sticky) to round the value.
            while (extra_bits > 2) {
                mantissa = (mantissa >> 1) | (mantissa & 1);
                extra_bits -= 1;
            }
            // Round to nearest, tie to even.
            mantissa |= @intFromBool(mantissa & 0b100 != 0);
            mantissa += 1;
            // Drop the excess bits.
            mantissa >>= 2;
            // Restore the alignment.
            mantissa <<= @as(std.math.Log2Int(TU), @intCast((mantissa_digits - precision) * 4));

            const overflow = mantissa & (1 << 1 + mantissa_digits * 4) != 0;
            // Prefer a normalized result in case of overflow.
            if (overflow) {
                mantissa >>= 1;
                exponent += 1;
            }
        }
    }

    // +1 for the decimal part.
    var buf: [1 + mantissa_digits]u8 = undefined;
    assert(std.fmt.printInt(&buf, mantissa, 16, .lower, .{ .fill = '0', .width = 1 + mantissa_digits }) == buf.len);

    try w.writeAll("0x");
    try w.writeByte(buf[0]);
    const trimmed = std.mem.trimRight(u8, buf[1..], "0");
    if (opt_precision) |precision| {
        if (precision > 0) try w.writeAll(".");
    } else if (trimmed.len > 0) {
        try w.writeAll(".");
    }
    try w.writeAll(trimmed);
    // Add trailing zeros if explicitly requested.
    if (opt_precision) |precision| if (precision > 0) {
        if (precision > trimmed.len)
            try w.splatByteAll('0', precision - trimmed.len);
    };
    try w.writeAll("p");
    try w.printIntOptions(exponent - exponent_bias, 10, .lower, .{});
}

pub const ByteSizeUnits = enum {
    /// This formatter represents the number as multiple of 1000 and uses the SI
    /// measurement units (kB, MB, GB, ...).
    decimal,
    /// This formatter represents the number as multiple of 1024 and uses the IEC
    /// measurement units (KiB, MiB, GiB, ...).
    binary,
};

/// Format option `precision` is ignored when `value` is less than 1kB
pub fn printByteSize(
    w: *std.io.Writer,
    value: u64,
    comptime units: ByteSizeUnits,
    options: std.fmt.Options,
) Error!void {
    if (value == 0) return w.alignBufferOptions("0B", options);
    // The worst case in terms of space needed is 32 bytes + 3 for the suffix.
    var buf: [std.fmt.float.min_buffer_size + 3]u8 = undefined;

    const mags_si = " kMGTPEZY";
    const mags_iec = " KMGTPEZY";

    const log2 = std.math.log2(value);
    const base = switch (units) {
        .decimal => 1000,
        .binary => 1024,
    };
    const magnitude = switch (units) {
        .decimal => @min(log2 / comptime std.math.log2(1000), mags_si.len - 1),
        .binary => @min(log2 / 10, mags_iec.len - 1),
    };
    const new_value = std.math.lossyCast(f64, value) / std.math.pow(f64, std.math.lossyCast(f64, base), std.math.lossyCast(f64, magnitude));
    const suffix = switch (units) {
        .decimal => mags_si[magnitude],
        .binary => mags_iec[magnitude],
    };

    const s = switch (magnitude) {
        0 => buf[0..std.fmt.printInt(&buf, value, 10, .lower, .{})],
        else => std.fmt.float.render(&buf, new_value, .{ .mode = .decimal, .precision = options.precision }) catch |err| switch (err) {
            error.BufferTooSmall => unreachable,
        },
    };

    var i: usize = s.len;
    if (suffix == ' ') {
        buf[i] = 'B';
        i += 1;
    } else switch (units) {
        .decimal => {
            buf[i..][0..2].* = [_]u8{ suffix, 'B' };
            i += 2;
        },
        .binary => {
            buf[i..][0..3].* = [_]u8{ suffix, 'i', 'B' };
            i += 3;
        },
    }

    return w.alignBufferOptions(buf[0..i], options);
}

// This ANY const is a workaround for: https://github.com/ziglang/zig/issues/7948
const ANY = "any";

fn stripOptionalOrErrorUnionSpec(comptime fmt: []const u8) []const u8 {
    return if (std.mem.eql(u8, fmt[1..], ANY))
        ANY
    else
        fmt[1..];
}

pub fn invalidFmtError(comptime fmt: []const u8, value: anytype) noreturn {
    @compileError("invalid format string '" ++ fmt ++ "' for type '" ++ @typeName(@TypeOf(value)) ++ "'");
}

pub fn printDurationSigned(w: *Writer, ns: i64) Error!void {
    if (ns < 0) try w.writeByte('-');
    return w.printDurationUnsigned(@abs(ns));
}

pub fn printDurationUnsigned(w: *Writer, ns: u64) Error!void {
    var ns_remaining = ns;
    inline for (.{
        .{ .ns = 365 * std.time.ns_per_day, .sep = 'y' },
        .{ .ns = std.time.ns_per_week, .sep = 'w' },
        .{ .ns = std.time.ns_per_day, .sep = 'd' },
        .{ .ns = std.time.ns_per_hour, .sep = 'h' },
        .{ .ns = std.time.ns_per_min, .sep = 'm' },
    }) |unit| {
        if (ns_remaining >= unit.ns) {
            const units = ns_remaining / unit.ns;
            try w.printIntOptions(units, 10, .lower, .{});
            try w.writeByte(unit.sep);
            ns_remaining -= units * unit.ns;
            if (ns_remaining == 0) return;
        }
    }

    inline for (.{
        .{ .ns = std.time.ns_per_s, .sep = "s" },
        .{ .ns = std.time.ns_per_ms, .sep = "ms" },
        .{ .ns = std.time.ns_per_us, .sep = "us" },
    }) |unit| {
        const kunits = ns_remaining * 1000 / unit.ns;
        if (kunits >= 1000) {
            try w.printIntOptions(kunits / 1000, 10, .lower, .{});
            const frac = kunits % 1000;
            if (frac > 0) {
                // Write up to 3 decimal places
                var decimal_buf = [_]u8{ '.', 0, 0, 0 };
                var inner: Writer = .fixed(decimal_buf[1..]);
                inner.printIntOptions(frac, 10, .lower, .{ .fill = '0', .width = 3 }) catch unreachable;
                var end: usize = 4;
                while (end > 1) : (end -= 1) {
                    if (decimal_buf[end - 1] != '0') break;
                }
                try w.writeAll(decimal_buf[0..end]);
            }
            return w.writeAll(unit.sep);
        }
    }

    try w.printIntOptions(ns_remaining, 10, .lower, .{});
    try w.writeAll("ns");
}

/// Writes number of nanoseconds according to its signed magnitude:
/// `[#y][#w][#d][#h][#m]#[.###][n|u|m]s`
/// `nanoseconds` must be an integer that coerces into `u64` or `i64`.
pub fn printDuration(w: *Writer, nanoseconds: anytype, options: std.fmt.Options) Error!void {
    // worst case: "-XXXyXXwXXdXXhXXmXX.XXXs".len = 24
    var buf: [24]u8 = undefined;
    var sub_bw: Writer = .fixed(&buf);
    switch (@typeInfo(@TypeOf(nanoseconds)).int.signedness) {
        .signed => sub_bw.printDurationSigned(nanoseconds) catch unreachable,
        .unsigned => sub_bw.printDurationUnsigned(nanoseconds) catch unreachable,
    }
    return w.alignBufferOptions(sub_bw.buffered(), options);
}

pub fn printHex(w: *Writer, bytes: []const u8, case: std.fmt.Case) Error!void {
    const charset = switch (case) {
        .upper => "0123456789ABCDEF",
        .lower => "0123456789abcdef",
    };
    for (bytes) |c| {
        try w.writeByte(charset[c >> 4]);
        try w.writeByte(charset[c & 15]);
    }
}

pub fn printBase64(w: *Writer, bytes: []const u8) Error!void {
    var chunker = std.mem.window(u8, bytes, 3, 3);
    var temp: [5]u8 = undefined;
    while (chunker.next()) |chunk| {
        try w.writeAll(std.base64.standard.Encoder.encode(&temp, chunk));
    }
}

/// Write a single unsigned integer as LEB128 to the given writer.
pub fn writeUleb128(w: *Writer, value: anytype) Error!void {
    try w.writeLeb128(switch (@typeInfo(@TypeOf(value))) {
        .comptime_int => @as(std.math.IntFittingRange(0, @abs(value)), value),
        .int => |value_info| switch (value_info.signedness) {
            .signed => @as(@Type(.{ .int = .{ .signedness = .unsigned, .bits = value_info.bits -| 1 } }), @intCast(value)),
            .unsigned => value,
        },
        else => comptime unreachable,
    });
}

/// Write a single signed integer as LEB128 to the given writer.
pub fn writeSleb128(w: *Writer, value: anytype) Error!void {
    try w.writeLeb128(switch (@typeInfo(@TypeOf(value))) {
        .comptime_int => @as(std.math.IntFittingRange(@min(value, -1), @max(0, value)), value),
        .int => |value_info| switch (value_info.signedness) {
            .signed => value,
            .unsigned => @as(@Type(.{ .int = .{ .signedness = .signed, .bits = value_info.bits + 1 } }), value),
        },
        else => comptime unreachable,
    });
}

/// Write a single integer as LEB128 to the given writer.
pub fn writeLeb128(w: *Writer, value: anytype) Error!void {
    const value_info = @typeInfo(@TypeOf(value)).int;
    try w.writeMultipleOf7Leb128(@as(@Type(.{ .int = .{
        .signedness = value_info.signedness,
        .bits = std.mem.alignForwardAnyAlign(u16, value_info.bits, 7),
    } }), value));
}

fn writeMultipleOf7Leb128(w: *Writer, value: anytype) Error!void {
    const value_info = @typeInfo(@TypeOf(value)).int;
    comptime assert(value_info.bits % 7 == 0);
    var remaining = value;
    while (true) {
        const buffer: []packed struct(u8) { bits: u7, more: bool } = @ptrCast(try w.writableSliceGreedy(1));
        for (buffer, 1..) |*byte, len| {
            const more = switch (value_info.signedness) {
                .signed => remaining >> 6 != remaining >> (value_info.bits - 1),
                .unsigned => remaining > std.math.maxInt(u7),
            };
            byte.* = if (@inComptime()) @typeInfo(@TypeOf(buffer)).pointer.child{
                .bits = @bitCast(@as(@Type(.{ .int = .{
                    .signedness = value_info.signedness,
                    .bits = 7,
                } }), @truncate(remaining))),
                .more = more,
            } else .{
                .bits = @bitCast(@as(@Type(.{ .int = .{
                    .signedness = value_info.signedness,
                    .bits = 7,
                } }), @truncate(remaining))),
                .more = more,
            };
            if (value_info.bits > 7) remaining >>= 7;
            if (!more) return w.advance(len);
        }
        w.advance(buffer.len);
    }
}

test "formatValue max_depth" {
    const Vec2 = struct {
        const SelfType = @This();
        x: f32,
        y: f32,

        pub fn format(
            self: SelfType,
            comptime fmt: []const u8,
            options: std.fmt.Options,
            w: *Writer,
        ) Error!void {
            _ = options;
            if (fmt.len == 0) {
                return w.print("({d:.3},{d:.3})", .{ self.x, self.y });
            } else {
                @compileError("unknown format string: '" ++ fmt ++ "'");
            }
        }
    };
    const E = enum {
        One,
        Two,
        Three,
    };
    const TU = union(enum) {
        const SelfType = @This();
        float: f32,
        int: u32,
        ptr: ?*SelfType,
    };
    const S = struct {
        const SelfType = @This();
        a: ?*SelfType,
        tu: TU,
        e: E,
        vec: Vec2,
    };

    var inst = S{
        .a = null,
        .tu = TU{ .ptr = null },
        .e = E.Two,
        .vec = Vec2{ .x = 10.2, .y = 2.22 },
    };
    inst.a = &inst;
    inst.tu.ptr = &inst.tu;

    var buf: [1000]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printValue("", .{}, inst, 0);
    try testing.expectEqualStrings("io.Writer.test.printValue max_depth.S{ ... }", w.buffered());

    w.reset();
    try w.printValue("", .{}, inst, 1);
    try testing.expectEqualStrings("io.Writer.test.printValue max_depth.S{ .a = io.Writer.test.printValue max_depth.S{ ... }, .tu = io.Writer.test.printValue max_depth.TU{ ... }, .e = io.Writer.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }", w.buffered());

    w.reset();
    try w.printValue("", .{}, inst, 2);
    try testing.expectEqualStrings("io.Writer.test.printValue max_depth.S{ .a = io.Writer.test.printValue max_depth.S{ .a = io.Writer.test.printValue max_depth.S{ ... }, .tu = io.Writer.test.printValue max_depth.TU{ ... }, .e = io.Writer.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }, .tu = io.Writer.test.printValue max_depth.TU{ .ptr = io.Writer.test.printValue max_depth.TU{ ... } }, .e = io.Writer.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }", w.buffered());

    w.reset();
    try w.printValue("", .{}, inst, 3);
    try testing.expectEqualStrings("io.Writer.test.printValue max_depth.S{ .a = io.Writer.test.printValue max_depth.S{ .a = io.Writer.test.printValue max_depth.S{ .a = io.Writer.test.printValue max_depth.S{ ... }, .tu = io.Writer.test.printValue max_depth.TU{ ... }, .e = io.Writer.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }, .tu = io.Writer.test.printValue max_depth.TU{ .ptr = io.Writer.test.printValue max_depth.TU{ ... } }, .e = io.Writer.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }, .tu = io.Writer.test.printValue max_depth.TU{ .ptr = io.Writer.test.printValue max_depth.TU{ .ptr = io.Writer.test.printValue max_depth.TU{ ... } } }, .e = io.Writer.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }", w.buffered());

    const vec: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    w.reset();
    try w.printValue("", .{}, vec, 0);
    try testing.expectEqualStrings("{ ... }", w.buffered());

    w.reset();
    try w.printValue("", .{}, vec, 1);
    try testing.expectEqualStrings("{ 1, 2, 3, 4 }", w.buffered());
}

test printDuration {
    testDurationCase("0ns", 0);
    testDurationCase("1ns", 1);
    testDurationCase("999ns", std.time.ns_per_us - 1);
    testDurationCase("1us", std.time.ns_per_us);
    testDurationCase("1.45us", 1450);
    testDurationCase("1.5us", 3 * std.time.ns_per_us / 2);
    testDurationCase("14.5us", 14500);
    testDurationCase("145us", 145000);
    testDurationCase("999.999us", std.time.ns_per_ms - 1);
    testDurationCase("1ms", std.time.ns_per_ms + 1);
    testDurationCase("1.5ms", 3 * std.time.ns_per_ms / 2);
    testDurationCase("1.11ms", 1110000);
    testDurationCase("1.111ms", 1111000);
    testDurationCase("1.111ms", 1111100);
    testDurationCase("999.999ms", std.time.ns_per_s - 1);
    testDurationCase("1s", std.time.ns_per_s);
    testDurationCase("59.999s", std.time.ns_per_min - 1);
    testDurationCase("1m", std.time.ns_per_min);
    testDurationCase("1h", std.time.ns_per_hour);
    testDurationCase("1d", std.time.ns_per_day);
    testDurationCase("1w", std.time.ns_per_week);
    testDurationCase("1y", 365 * std.time.ns_per_day);
    testDurationCase("1y52w23h59m59.999s", 730 * std.time.ns_per_day - 1); // 365d = 52w1
    testDurationCase("1y1h1.001s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + std.time.ns_per_ms);
    testDurationCase("1y1h1s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + 999 * std.time.ns_per_us);
    testDurationCase("1y1h999.999us", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms - 1);
    testDurationCase("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms);
    testDurationCase("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms + 1);
    testDurationCase("1y1m999ns", 365 * std.time.ns_per_day + std.time.ns_per_min + 999);
    testDurationCase("584y49w23h34m33.709s", std.math.maxInt(u64));

    testing.expectFmt("=======0ns", "{D:=>10}", .{0});
    testing.expectFmt("1ns=======", "{D:=<10}", .{1});
    testing.expectFmt("  999ns   ", "{D:^10}", .{std.time.ns_per_us - 1});
}

test printDurationSigned {
    testDurationCaseSigned("0ns", 0);
    testDurationCaseSigned("1ns", 1);
    testDurationCaseSigned("-1ns", -(1));
    testDurationCaseSigned("999ns", std.time.ns_per_us - 1);
    testDurationCaseSigned("-999ns", -(std.time.ns_per_us - 1));
    testDurationCaseSigned("1us", std.time.ns_per_us);
    testDurationCaseSigned("-1us", -(std.time.ns_per_us));
    testDurationCaseSigned("1.45us", 1450);
    testDurationCaseSigned("-1.45us", -(1450));
    testDurationCaseSigned("1.5us", 3 * std.time.ns_per_us / 2);
    testDurationCaseSigned("-1.5us", -(3 * std.time.ns_per_us / 2));
    testDurationCaseSigned("14.5us", 14500);
    testDurationCaseSigned("-14.5us", -(14500));
    testDurationCaseSigned("145us", 145000);
    testDurationCaseSigned("-145us", -(145000));
    testDurationCaseSigned("999.999us", std.time.ns_per_ms - 1);
    testDurationCaseSigned("-999.999us", -(std.time.ns_per_ms - 1));
    testDurationCaseSigned("1ms", std.time.ns_per_ms + 1);
    testDurationCaseSigned("-1ms", -(std.time.ns_per_ms + 1));
    testDurationCaseSigned("1.5ms", 3 * std.time.ns_per_ms / 2);
    testDurationCaseSigned("-1.5ms", -(3 * std.time.ns_per_ms / 2));
    testDurationCaseSigned("1.11ms", 1110000);
    testDurationCaseSigned("-1.11ms", -(1110000));
    testDurationCaseSigned("1.111ms", 1111000);
    testDurationCaseSigned("-1.111ms", -(1111000));
    testDurationCaseSigned("1.111ms", 1111100);
    testDurationCaseSigned("-1.111ms", -(1111100));
    testDurationCaseSigned("999.999ms", std.time.ns_per_s - 1);
    testDurationCaseSigned("-999.999ms", -(std.time.ns_per_s - 1));
    testDurationCaseSigned("1s", std.time.ns_per_s);
    testDurationCaseSigned("-1s", -(std.time.ns_per_s));
    testDurationCaseSigned("59.999s", std.time.ns_per_min - 1);
    testDurationCaseSigned("-59.999s", -(std.time.ns_per_min - 1));
    testDurationCaseSigned("1m", std.time.ns_per_min);
    testDurationCaseSigned("-1m", -(std.time.ns_per_min));
    testDurationCaseSigned("1h", std.time.ns_per_hour);
    testDurationCaseSigned("-1h", -(std.time.ns_per_hour));
    testDurationCaseSigned("1d", std.time.ns_per_day);
    testDurationCaseSigned("-1d", -(std.time.ns_per_day));
    testDurationCaseSigned("1w", std.time.ns_per_week);
    testDurationCaseSigned("-1w", -(std.time.ns_per_week));
    testDurationCaseSigned("1y", 365 * std.time.ns_per_day);
    testDurationCaseSigned("-1y", -(365 * std.time.ns_per_day));
    testDurationCaseSigned("1y52w23h59m59.999s", 730 * std.time.ns_per_day - 1); // 365d = 52w1d
    testDurationCaseSigned("-1y52w23h59m59.999s", -(730 * std.time.ns_per_day - 1)); // 365d = 52w1d
    testDurationCaseSigned("1y1h1.001s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + std.time.ns_per_ms);
    testDurationCaseSigned("-1y1h1.001s", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + std.time.ns_per_ms));
    testDurationCaseSigned("1y1h1s", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + 999 * std.time.ns_per_us);
    testDurationCaseSigned("-1y1h1s", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_s + 999 * std.time.ns_per_us));
    testDurationCaseSigned("1y1h999.999us", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms - 1);
    testDurationCaseSigned("-1y1h999.999us", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms - 1));
    testDurationCaseSigned("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms);
    testDurationCaseSigned("-1y1h1ms", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms));
    testDurationCaseSigned("1y1h1ms", 365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms + 1);
    testDurationCaseSigned("-1y1h1ms", -(365 * std.time.ns_per_day + std.time.ns_per_hour + std.time.ns_per_ms + 1));
    testDurationCaseSigned("1y1m999ns", 365 * std.time.ns_per_day + std.time.ns_per_min + 999);
    testDurationCaseSigned("-1y1m999ns", -(365 * std.time.ns_per_day + std.time.ns_per_min + 999));
    testDurationCaseSigned("292y24w3d23h47m16.854s", std.math.maxInt(i64));
    testDurationCaseSigned("-292y24w3d23h47m16.854s", std.math.minInt(i64) + 1);
    testDurationCaseSigned("-292y24w3d23h47m16.854s", std.math.minInt(i64));

    testing.expectFmt("=======0ns", "{s:=>10}", .{0});
    testing.expectFmt("1ns=======", "{s:=<10}", .{1});
    testing.expectFmt("-1ns======", "{s:=<10}", .{-(1)});
    testing.expectFmt("  -999ns  ", "{s:^10}", .{-(std.time.ns_per_us - 1)});
}

fn testDurationCase(expected: []const u8, input: u64) !void {
    var buf: [24]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printDurationUnsigned(input);
    try testing.expectEqualStrings(expected, w.buffered());
}

fn testDurationCaseSigned(expected: []const u8, input: i64) !void {
    var buf: [24]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printDurationSigned(input);
    try testing.expectEqualStrings(expected, w.buffered());
}

test printIntOptions {
    try testPrintIntCase("-1", @as(i1, -1), 10, .lower, .{});

    try testPrintIntCase("-101111000110000101001110", @as(i32, -12345678), 2, .lower, .{});
    try testPrintIntCase("-12345678", @as(i32, -12345678), 10, .lower, .{});
    try testPrintIntCase("-bc614e", @as(i32, -12345678), 16, .lower, .{});
    try testPrintIntCase("-BC614E", @as(i32, -12345678), 16, .upper, .{});

    try testPrintIntCase("12345678", @as(u32, 12345678), 10, .upper, .{});

    try testPrintIntCase("   666", @as(u32, 666), 10, .lower, .{ .width = 6 });
    try testPrintIntCase("  1234", @as(u32, 0x1234), 16, .lower, .{ .width = 6 });
    try testPrintIntCase("1234", @as(u32, 0x1234), 16, .lower, .{ .width = 1 });

    try testPrintIntCase("+42", @as(i32, 42), 10, .lower, .{ .width = 3 });
    try testPrintIntCase("-42", @as(i32, -42), 10, .lower, .{ .width = 3 });
}

test "printInt with comptime_int" {
    var buf: [20]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printInt(@as(comptime_int, 123456789123456789), "", .{});
    try std.testing.expectEqualStrings("123456789123456789", w.buffered());
}

test "printFloat with comptime_float" {
    var buf: [20]u8 = undefined;
    var w: Writer = .fixed(&buf);
    try w.printFloat("", .{}, @as(comptime_float, 1.0));
    try std.testing.expectEqualStrings(w.buffered(), "1e0");
    try std.testing.expectFmt("1e0", "{}", .{1.0});
}

fn testPrintIntCase(expected: []const u8, value: anytype, base: u8, case: std.fmt.Case, options: std.fmt.Options) !void {
    var buffer: [100]u8 = undefined;
    var w: Writer = .fixed(&buffer);
    w.printIntOptions(value, base, case, options);
    try testing.expectEqualStrings(expected, w.buffered());
}

test printByteSize {
    try testing.expectFmt("file size: 42B\n", "file size: {B}\n", .{42});
    try testing.expectFmt("file size: 42B\n", "file size: {Bi}\n", .{42});
    try testing.expectFmt("file size: 63MB\n", "file size: {B}\n", .{63 * 1000 * 1000});
    try testing.expectFmt("file size: 63MiB\n", "file size: {Bi}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 42B\n", "file size: {B:.2}\n", .{42});
    try testing.expectFmt("file size:       42B\n", "file size: {B:>9.2}\n", .{42});
    try testing.expectFmt("file size: 66.06MB\n", "file size: {B:.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 60.08MiB\n", "file size: {Bi:.2}\n", .{63 * 1000 * 1000});
    try testing.expectFmt("file size: =66.06MB=\n", "file size: {B:=^9.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size:   66.06MB\n", "file size: {B: >9.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 66.06MB  \n", "file size: {B: <9.2}\n", .{63 * 1024 * 1024});
    try testing.expectFmt("file size: 0.01844674407370955ZB\n", "file size: {B}\n", .{std.math.maxInt(u64)});
}

test "bytes.hex" {
    const some_bytes = "\xCA\xFE\xBA\xBE";
    try std.testing.expectFmt("lowercase: cafebabe\n", "lowercase: {x}\n", .{some_bytes});
    try std.testing.expectFmt("uppercase: CAFEBABE\n", "uppercase: {X}\n", .{some_bytes});
    try std.testing.expectFmt("uppercase: CAFE\n", "uppercase: {X}\n", .{some_bytes[0..2]});
    try std.testing.expectFmt("lowercase: babe\n", "lowercase: {x}\n", .{some_bytes[2..]});
    const bytes_with_zeros = "\x00\x0E\xBA\xBE";
    try std.testing.expectFmt("lowercase: 000ebabe\n", "lowercase: {x}\n", .{bytes_with_zeros});
}

test fixed {
    {
        var buf: [255]u8 = undefined;
        var w: Writer = .fixed(&buf);
        try w.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualStrings("HelloWorld!", w.buffered());
    }

    comptime {
        var buf: [255]u8 = undefined;
        var w: Writer = .fixed(&buf);
        try w.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualStrings("HelloWorld!", w.buffered());
    }
}

test "fixed output" {
    var buffer: [10]u8 = undefined;
    var w: Writer = .fixed(&buffer);

    try w.writeAll("Hello");
    try testing.expect(std.mem.eql(u8, w.buffered(), "Hello"));

    try w.writeAll("world");
    try testing.expect(std.mem.eql(u8, w.buffered(), "Helloworld"));

    try testing.expectError(error.WriteStreamEnd, w.writeAll("!"));
    try testing.expect(std.mem.eql(u8, w.buffered(), "Helloworld"));

    w.reset();
    try testing.expect(w.buffered().len == 0);

    try testing.expectError(error.WriteStreamEnd, w.writeAll("Hello world!"));
    try testing.expect(std.mem.eql(u8, w.buffered(), "Hello worl"));

    try w.seekTo((try w.getEndPos()) + 1);
    try testing.expectError(error.WriteStreamEnd, w.writeAll("H"));
}

pub fn failingDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    _ = w;
    _ = data;
    _ = splat;
    return error.WriteFailed;
}

pub fn failingSendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    _ = w;
    _ = file_reader;
    _ = limit;
    return error.WriteFailed;
}

pub fn discardingDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    const slice = data[0 .. data.len - 1];
    const pattern = data[slice.len..];
    var written: usize = pattern.len * splat;
    for (slice) |bytes| written += bytes.len;
    w.end = 0;
    return written;
}

pub fn discardingSendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    if (File.Handle == void) return error.Unimplemented;
    w.end = 0;
    if (file_reader.getSize()) |size| {
        const n = limit.minInt(size - file_reader.pos);
        file_reader.seekBy(@intCast(n)) catch return error.Unimplemented;
        w.end = 0;
        return n;
    } else |_| {
        // Error is observable on `file_reader` instance, and it is better to
        // treat the file as a pipe.
        return error.Unimplemented;
    }
}

/// Removes the first `n` bytes from `buffer` by shifting buffer contents,
/// returning how many bytes are left after consuming the entire buffer, or
/// zero if the entire buffer was not consumed.
///
/// Useful for `VTable.drain` function implementations to implement partial
/// drains.
pub fn consume(w: *Writer, n: usize) usize {
    if (n < w.end) {
        const remaining = w.buffer[n..w.end];
        @memmove(w.buffer[0..remaining.len], remaining);
        w.end = remaining.len;
        return 0;
    }
    defer w.end = 0;
    return n - w.end;
}

/// Shortcut for setting `end` to zero and returning zero. Equivalent to
/// calling `consume` with `end`.
pub fn consumeAll(w: *Writer) usize {
    w.end = 0;
    return 0;
}

/// For use when the `Writer` implementation can cannot offer a more efficient
/// implementation than a basic read/write loop on the file.
pub fn unimplementedSendFile(w: *Writer, file_reader: *File.Reader, limit: Limit) FileError!usize {
    _ = w;
    _ = file_reader;
    _ = limit;
    return error.Unimplemented;
}

/// When this function is called it usually means the buffer got full, so it's
/// time to return an error. However, we still need to make sure all of the
/// available buffer has been filled. Also, it may be called from `flush` in
/// which case it should return successfully.
pub fn fixedDrain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
    if (data.len == 0) return 0;
    for (data[0 .. data.len - 1]) |bytes| {
        const dest = w.buffer[w.end..];
        const len = @min(bytes.len, dest.len);
        @memcpy(dest[0..len], bytes[0..len]);
        w.end += len;
        if (bytes.len > dest.len) return error.WriteFailed;
    }
    const pattern = data[data.len - 1];
    const dest = w.buffer[w.end..];
    switch (pattern.len) {
        0 => return w.end,
        1 => {
            assert(splat >= dest.len);
            @memset(dest, pattern[0]);
            w.end += dest.len;
            return error.WriteFailed;
        },
        else => {
            for (0..splat) |i| {
                const remaining = dest[i * pattern.len ..];
                const len = @min(pattern.len, remaining.len);
                @memcpy(remaining[0..len], pattern[0..len]);
                w.end += len;
                if (pattern.len > remaining.len) return error.WriteFailed;
            }
            unreachable;
        },
    }
}

/// Provides a `Writer` implementation based on calling `Hasher.update`, sending
/// all data also to an underlying `Writer`.
///
/// When using this, the underlying writer is best unbuffered because all
/// writes are passed on directly to it.
///
/// This implementation makes suboptimal buffering decisions due to being
/// generic. A better solution will involve creating a writer for each hash
/// function, where the splat buffer can be tailored to the hash implementation
/// details.
pub fn Hashed(comptime Hasher: type) type {
    return struct {
        out: *Writer,
        hasher: Hasher,
        interface: Writer,

        pub fn init(out: *Writer) @This() {
            return .{
                .out = out,
                .hasher = .{},
                .interface = .{
                    .vtable = &.{@This().drain},
                },
            };
        }

        fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
            const this: *@This() = @alignCast(@fieldParentPtr("interface", w));
            if (data.len == 0) {
                const buf = w.buffered();
                try this.out.writeAll(buf);
                this.hasher.update(buf);
                w.end = 0;
                return buf.len;
            }
            const aux_n = try this.out.writeSplatAux(w.buffered(), data, splat);
            if (aux_n < w.end) {
                this.hasher.update(w.buffer[0..aux_n]);
                const remaining = w.buffer[aux_n..w.end];
                @memmove(w.buffer[0..remaining.len], remaining);
                w.end = remaining.len;
                return 0;
            }
            this.hasher.update(w.buffered());
            const n = aux_n - w.end;
            w.end = 0;
            var remaining: usize = n;
            const short_data = data[0 .. data.len - @intFromBool(splat == 0)];
            for (short_data) |slice| {
                if (remaining < slice.len) {
                    this.hasher.update(slice[0..remaining]);
                    return n;
                } else {
                    remaining -= slice.len;
                    this.hasher.update(slice);
                }
            }
            const remaining_splat = switch (splat) {
                0, 1 => {
                    assert(remaining == 0);
                    return n;
                },
                else => splat - 1,
            };
            const pattern = data[data.len - 1];
            assert(remaining == remaining_splat * pattern.len);
            switch (pattern.len) {
                0 => {
                    assert(remaining == 0);
                },
                1 => {
                    var buffer: [64]u8 = undefined;
                    @memset(&buffer, pattern[0]);
                    while (remaining > 0) {
                        const update_len = @min(remaining, buffer.len);
                        this.hasher.update(buffer[0..update_len]);
                        remaining -= update_len;
                    }
                },
                else => {
                    while (remaining > 0) {
                        const update_len = @min(remaining, pattern.len);
                        this.hasher.update(pattern[0..update_len]);
                        remaining -= update_len;
                    }
                },
            }
            return n;
        }
    };
}

/// Maintains `Writer` state such that it writes to the unused capacity of an
/// array list, filling it up completely before making a call through the
/// vtable, causing a resize. Consequently, the same, optimized, non-generic
/// machine code that uses `std.io.Reader`, such as formatted printing, takes
/// the hot paths when using this API.
///
/// When using this API, it is not necessary to call `flush`.
pub const Allocating = struct {
    allocator: Allocator,
    interface: Writer,

    pub fn init(allocator: Allocator) Allocating {
        return .{
            .allocator = allocator,
            .interface = .{
                .buffer = &.{},
                .vtable = &vtable,
            },
        };
    }

    pub fn initCapacity(allocator: Allocator, capacity: usize) error{OutOfMemory}!Allocating {
        return .{
            .allocator = allocator,
            .interface = .{
                .buffer = try allocator.alloc(u8, capacity),
                .vtable = &vtable,
            },
        };
    }

    pub fn initOwnedSlice(allocator: Allocator, slice: []u8) Allocating {
        return .{
            .allocator = allocator,
            .interface = .{
                .buffer = slice,
                .vtable = &vtable,
            },
        };
    }

    /// Replaces `array_list` with empty, taking ownership of the memory.
    pub fn fromArrayList(allocator: Allocator, array_list: *std.ArrayListUnmanaged(u8)) Allocating {
        defer array_list.* = .empty;
        return .{
            .allocator = allocator,
            .interface = .{
                .vtable = &vtable,
                .buffer = array_list.allocatedSlice(),
                .end = array_list.items.len,
            },
        };
    }

    const vtable: VTable = .{
        .drain = Allocating.drain,
        .sendFile = Allocating.sendFile,
    };

    pub fn deinit(a: *Allocating) void {
        a.allocator.free(a.interface.buffer);
        a.* = undefined;
    }

    /// Returns an array list that takes ownership of the allocated memory.
    /// Resets the `Allocating` to an empty state.
    pub fn toArrayList(a: *Allocating) std.ArrayListUnmanaged(u8) {
        const w = &a.interface;
        const result: std.ArrayListUnmanaged(u8) = .{
            .items = w.buffer[0..w.end],
            .capacity = w.buffer.len,
        };
        w.buffer = &.{};
        w.end = 0;
        return result;
    }

    pub fn toOwnedSlice(a: *Allocating) error{OutOfMemory}![]u8 {
        var list = a.toArrayList();
        return list.toOwnedSlice(a.allocator);
    }

    pub fn toOwnedSliceSentinel(a: *Allocating, comptime sentinel: u8) error{OutOfMemory}![:sentinel]u8 {
        const gpa = a.allocator;
        var list = toArrayList(a);
        return list.toOwnedSliceSentinel(gpa, sentinel);
    }

    pub fn getWritten(a: *Allocating) []u8 {
        return a.interface.buffered();
    }

    pub fn shrinkRetainingCapacity(a: *Allocating, new_len: usize) void {
        const shrink_by = a.interface.end - new_len;
        a.interface.end = new_len;
        a.interface.count -= shrink_by;
    }

    pub fn clearRetainingCapacity(a: *Allocating) void {
        a.shrinkRetainingCapacity(0);
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Error!usize {
        const a: *Allocating = @fieldParentPtr("interface", w);
        const gpa = a.allocator;
        const pattern = data[data.len - 1];
        const splat_len = pattern.len * splat;
        var list = a.toArrayList();
        defer setArrayList(a, list);
        const start_len = list.items.len;
        for (data[0 .. data.len - 1]) |bytes| {
            list.ensureUnusedCapacity(gpa, bytes.len + splat_len) catch return error.WriteFailed;
            list.appendSliceAssumeCapacity(bytes);
        }
        switch (pattern.len) {
            0 => {},
            1 => list.appendNTimesAssumeCapacity(pattern[0], splat),
            else => for (0..splat) |_| list.appendSliceAssumeCapacity(pattern),
        }
        return list.items.len - start_len;
    }

    fn sendFile(w: *Writer, file_reader: *File.Reader, limit: std.io.Limit) FileError!usize {
        if (File.Handle == void) return error.Unimplemented;
        const a: *Allocating = @fieldParentPtr("interface", w);
        const gpa = a.allocator;
        var list = a.toArrayList();
        defer setArrayList(a, list);
        const pos = file_reader.pos;
        const additional = if (file_reader.getSize()) |size| size - pos else |_| std.atomic.cache_line;
        list.ensureUnusedCapacity(gpa, limit.minInt(additional)) catch return error.WriteFailed;
        const dest = limit.slice(list.unusedCapacitySlice());
        const n = file_reader.read(dest) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => 0,
        };
        list.items.len += n;
        return n;
    }

    fn setArrayList(a: *Allocating, list: std.ArrayListUnmanaged(u8)) void {
        a.interface.buffer = list.allocatedSlice();
        a.interface.end = list.items.len;
    }

    test Allocating {
        var a: Allocating = .init(std.testing.allocator);
        defer a.deinit();
        const w = &a.interface;

        const x: i32 = 42;
        const y: i32 = 1234;
        try w.print("x: {}\ny: {}\n", .{ x, y });

        try testing.expectEqualSlices(u8, "x: 42\ny: 1234\n", a.getWritten());
    }
};
