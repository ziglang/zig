const std = @import("../std.zig");
const BufferedWriter = @This();
const assert = std.debug.assert;
const native_endian = @import("builtin").target.cpu.arch.endian();
const Writer = std.io.Writer;
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// Underlying stream to send bytes to.
///
/// A write will only be sent here if it could not fit into `buffer`, or if it
/// is a `writeFile`.
///
/// `unbuffered_writer` may modify `buffer` if the number of bytes returned
/// equals number of bytes provided. This property is exploited by
/// `std.io.AllocatingWriter` for example.
unbuffered_writer: Writer,
/// If this has length zero, the writer is unbuffered, and `flush` is a no-op.
buffer: []u8,
/// In `buffer` before this are buffered bytes, after this is `undefined`.
end: usize = 0,
/// Tracks total number of bytes written to this `BufferedWriter`. This value
/// only increases. In the case of fixed mode, this value always equals `end`.
count: usize = 0,

/// Number of slices to store on the stack, when trying to send as many byte
/// vectors through the underlying write calls as possible.
pub const max_buffers_len = 8;

/// Although `BufferedWriter` can easily satisfy the `Writer` interface, it's
/// generally more practical to pass a `BufferedWriter` instance itself around,
/// since it will result in fewer calls across vtable boundaries.
pub fn writer(bw: *BufferedWriter) Writer {
    return .{
        .context = bw,
        .vtable = &.{
            .writeSplat = passthruWriteSplat,
            .writeFile = passthruWriteFile,
        },
    };
}

const fixed_vtable: Writer.VTable = .{
    .writeSplat = fixedWriteSplat,
    .writeFile = Writer.failingWriteFile,
};

/// Replaces the `BufferedWriter` with one that writes to `buffer` and returns
/// `error.WriteFailed` when it is full. `end` and `count` will always be
/// equal.
pub fn initFixed(bw: *BufferedWriter, buffer: []u8) void {
    bw.* = .{
        .unbuffered_writer = .{
            .context = bw,
            .vtable = &fixed_vtable,
        },
        .buffer = buffer,
    };
}

/// This function is available when using `initFixed`.
pub fn getWritten(bw: *const BufferedWriter) []u8 {
    assert(bw.unbuffered_writer.vtable == &fixed_vtable);
    return bw.buffer[0..bw.end];
}

/// This function is available when using `initFixed`.
pub fn reset(bw: *BufferedWriter) void {
    assert(bw.unbuffered_writer.vtable == &fixed_vtable);
    bw.end = 0;
    bw.count = 0;
}

pub fn flush(bw: *BufferedWriter) Writer.Error!void {
    const send_buffer = bw.buffer[0..bw.end];
    var index: usize = 0;
    while (index < send_buffer.len) index += try bw.unbuffered_writer.writeVec(&.{send_buffer[index..]});
    bw.end = 0;
}

pub fn unusedCapacitySlice(bw: *const BufferedWriter) []u8 {
    return bw.buffer[bw.end..];
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
pub fn writableArray(bw: *BufferedWriter, comptime len: usize) Writer.Error!*[len]u8 {
    const big_slice = try bw.writableSliceGreedy(len);
    advance(bw, len);
    return big_slice[0..len];
}

/// Asserts the provided buffer has total capacity enough for `len`.
///
/// Advances the buffer end position by `len`.
pub fn writableSlice(bw: *BufferedWriter, len: usize) Writer.Error![]u8 {
    const big_slice = try bw.writableSliceGreedy(len);
    advance(bw, len);
    return big_slice[0..len];
}

/// Asserts the provided buffer has total capacity enough for `minimum_length`.
///
/// Does not `advance` the buffer end position.
///
/// If `minimum_length` is zero, this is equivalent to `unusedCapacitySlice`.
pub fn writableSliceGreedy(bw: *BufferedWriter, minimum_length: usize) Writer.Error![]u8 {
    assert(bw.buffer.len >= minimum_length);
    const cap_slice = bw.buffer[bw.end..];
    if (cap_slice.len >= minimum_length) {
        @branchHint(.likely);
        return cap_slice;
    }
    const buffer = bw.buffer[0..bw.end];
    const n = try bw.unbuffered_writer.writeVec(&.{buffer});
    if (n == buffer.len) {
        @branchHint(.likely);
        bw.end = 0;
        return bw.buffer;
    }
    if (n > 0) {
        const remainder = buffer[n..];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        bw.end = remainder.len;
    }
    return bw.buffer[bw.end..];
}

/// After calling `writableSliceGreedy`, this function tracks how many bytes
/// were written to it.
///
/// This is not needed when using `writableSlice` or `writableArray`.
pub fn advance(bw: *BufferedWriter, n: usize) void {
    const new_end = bw.end + n;
    assert(new_end <= bw.buffer.len);
    bw.end = new_end;
    bw.count += n;
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `Writer.VTable.writeVec`.
pub fn writeVecAll(bw: *BufferedWriter, data: [][]const u8) Writer.Error!void {
    var index: usize = 0;
    var truncate: usize = 0;
    while (index < data.len) {
        {
            const untruncated = data[index];
            data[index] = untruncated[truncate..];
            defer data[index] = untruncated;
            truncate += try bw.writeVec(data[index..]);
        }
        while (index < data.len and truncate <= data[index].len) {
            truncate -= data[index].len;
            index += 1;
        }
    }
}

/// If the number of bytes to write based on `data` and `splat` fits inside
/// `unusedCapacitySlice`, this function is guaranteed to not fail, not call
/// into the underlying writer, and return the full number of bytes.
pub fn writeSplat(bw: *BufferedWriter, data: []const []const u8, splat: usize) Writer.Error!usize {
    return passthruWriteSplat(bw, data, splat);
}

/// If the total number of bytes of `data` fits inside `unusedCapacitySlice`,
/// this function is guaranteed to not fail, not call into the underlying
/// writer, and return the total bytes inside `data`.
pub fn writeVec(bw: *BufferedWriter, data: []const []const u8) Writer.Error!usize {
    return passthruWriteSplat(bw, data, 1);
}

/// Equivalent to `writeSplat` but writes at most `limit` bytes.
pub fn writeSplatLimit(
    bw: *BufferedWriter,
    data: []const []const u8,
    splat: usize,
    limit: Writer.Limit,
) Writer.Error!usize {
    _ = bw;
    _ = data;
    _ = splat;
    _ = limit;
    @panic("TODO");
}

fn passthruWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) Writer.Error!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    const buffer = bw.buffer;
    const start_end = bw.end;

    var buffers: [max_buffers_len][]const u8 = undefined;
    var end = start_end;
    for (data, 0..) |bytes, i| {
        const new_end = end + bytes.len;
        if (new_end <= buffer.len) {
            @branchHint(.likely);
            @memcpy(buffer[end..new_end], bytes);
            end = new_end;
            continue;
        }
        if (end == 0) return track(&bw.count, try bw.unbuffered_writer.writeSplat(data, splat));
        buffers[0] = buffer[0..end];
        const remaining_data = data[i..];
        const remaining_buffers = buffers[1..];
        const len: usize = @min(remaining_data.len, remaining_buffers.len);
        @memcpy(remaining_buffers[0..len], remaining_data[0..len]);
        const send_buffers = buffers[0 .. len + 1];
        if (len >= remaining_data.len) {
            @branchHint(.likely);
            // Made it past the headers, so we can enable splatting.
            const n = try bw.unbuffered_writer.writeSplat(send_buffers, splat);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return track(&bw.count, end - start_end);
            }
            bw.end = 0;
            return track(&bw.count, n - start_end);
        }
        const n = try bw.unbuffered_writer.writeSplat(send_buffers, 1);
        if (n < end) {
            @branchHint(.unlikely);
            const remainder = buffer[n..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return track(&bw.count, end - start_end);
        }
        bw.end = 0;
        return track(&bw.count, n - start_end);
    }

    const pattern = data[data.len - 1];

    if (splat == 0) {
        @branchHint(.unlikely);
        // It was added in the loop above; undo it here.
        end -= pattern.len;
        bw.end = end;
        return track(&bw.count, end - start_end);
    }

    const remaining_splat = splat - 1;

    switch (pattern.len) {
        0 => {
            bw.end = end;
            return track(&bw.count, end - start_end);
        },
        1 => {
            const new_end = end + remaining_splat;
            if (new_end <= buffer.len) {
                @branchHint(.likely);
                @memset(buffer[end..new_end], pattern[0]);
                bw.end = new_end;
                return track(&bw.count, new_end - start_end);
            }
            buffers[0] = buffer[0..end];
            buffers[1] = pattern;
            const n = try bw.unbuffered_writer.writeSplat(buffers[0..2], remaining_splat);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return track(&bw.count, end - start_end);
            }
            bw.end = 0;
            return track(&bw.count, n - start_end);
        },
        else => {
            const new_end = end + pattern.len * remaining_splat;
            if (new_end <= buffer.len) {
                @branchHint(.likely);
                while (end < new_end) : (end += pattern.len) {
                    @memcpy(buffer[end..][0..pattern.len], pattern);
                }
                bw.end = new_end;
                return track(&bw.count, new_end - start_end);
            }
            buffers[0] = buffer[0..end];
            buffers[1] = pattern;
            const n = try bw.unbuffered_writer.writeSplat(buffers[0..2], remaining_splat);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return track(&bw.count, end - start_end);
            }
            bw.end = 0;
            return track(&bw.count, n - start_end);
        },
    }
}

fn track(count: *usize, n: usize) usize {
    count.* += n;
    return n;
}

/// When this function is called it means the buffer got full, so it's time
/// to return an error. However, we still need to make sure all of the
/// available buffer has been filled.
fn fixedWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) Writer.Error!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    for (data) |bytes| {
        const dest = bw.buffer[bw.end..];
        if (dest.len == 0) return error.WriteFailed;
        const len = @min(bytes.len, dest.len);
        @memcpy(dest[0..len], bytes[0..len]);
        bw.end += len;
        bw.count = bw.end;
    }
    const pattern = data[data.len - 1];
    const dest = bw.buffer[bw.end..];
    switch (pattern.len) {
        0 => unreachable,
        1 => @memset(dest, pattern[0]),
        else => for (0..splat - 1) |i| @memcpy(dest[i * pattern.len ..][0..pattern.len], pattern),
    }
    bw.end = bw.buffer.len;
    bw.count = bw.end;
    return error.WriteFailed;
}

pub fn write(bw: *BufferedWriter, bytes: []const u8) Writer.Error!usize {
    const buffer = bw.buffer;
    const end = bw.end;
    const new_end = end + bytes.len;
    if (new_end > buffer.len) {
        var data: [2][]const u8 = .{ buffer[0..end], bytes };
        const n = try bw.unbuffered_writer.writeVec(&data);
        if (n < end) {
            @branchHint(.unlikely);
            const remainder = buffer[n..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return 0;
        }
        bw.end = 0;
        return track(&bw.count, n - end);
    }
    @memcpy(buffer[end..new_end], bytes);
    bw.end = new_end;
    return track(&bw.count, bytes.len);
}

/// Calls `write` as many times as necessary such that all of `bytes` are
/// transferred.
pub fn writeAll(bw: *BufferedWriter, bytes: []const u8) Writer.Error!void {
    var index: usize = 0;
    while (index < bytes.len) index += try bw.write(bytes[index..]);
}

pub fn print(bw: *BufferedWriter, comptime format: []const u8, args: anytype) Writer.Error!void {
    try std.fmt.format(bw, format, args);
}

pub fn writeByte(bw: *BufferedWriter, byte: u8) Writer.Error!void {
    const buffer = bw.buffer[0..bw.end];
    if (buffer.len < bw.buffer.len) {
        @branchHint(.likely);
        buffer.ptr[buffer.len] = byte;
        bw.end = buffer.len + 1;
        bw.count += 1;
        return;
    }
    var buffers: [2][]const u8 = .{ buffer, &.{byte} };
    while (true) {
        const n = try bw.unbuffered_writer.writeVec(&buffers);
        if (n == 0) {
            @branchHint(.unlikely);
            continue;
        }
        bw.count += 1;
        if (n >= buffer.len) {
            @branchHint(.likely);
            if (n > buffer.len) {
                @branchHint(.likely);
                bw.end = 0;
                return;
            } else {
                buffer[0] = byte;
                bw.end = 1;
                return;
            }
        }
        const remainder = buffer[n..];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        buffer[remainder.len] = byte;
        bw.end = remainder.len + 1;
        return;
    }
}

/// Writes the same byte many times, performing the underlying write call as
/// many times as necessary.
pub fn splatByteAll(bw: *BufferedWriter, byte: u8, n: usize) Writer.Error!void {
    var remaining: usize = n;
    while (remaining > 0) remaining -= try bw.splatByte(byte, remaining);
}

/// Writes the same byte many times, allowing short writes.
///
/// Does maximum of one underlying `Writer.VTable.writeSplat`.
pub fn splatByte(bw: *BufferedWriter, byte: u8, n: usize) Writer.Error!usize {
    return passthruWriteSplat(bw, &.{&.{byte}}, n);
}

/// Writes the same slice many times, performing the underlying write call as
/// many times as necessary.
pub fn splatBytesAll(bw: *BufferedWriter, bytes: []const u8, splat: usize) Writer.Error!void {
    var remaining_bytes: usize = bytes.len * splat;
    remaining_bytes -= try bw.splatBytes(bytes, splat);
    while (remaining_bytes > 0) {
        const leftover = remaining_bytes % bytes.len;
        const buffers: [2][]const u8 = .{ bytes[bytes.len - leftover ..], bytes };
        remaining_bytes -= try bw.splatBytes(&buffers, splat);
    }
}

/// Writes the same slice many times, allowing short writes.
///
/// Does maximum of one underlying `Writer.VTable.writeVec`.
pub fn splatBytes(bw: *BufferedWriter, bytes: []const u8, n: usize) Writer.Error!usize {
    return passthruWriteSplat(bw, &.{bytes}, n);
}

/// Asserts the `buffer` was initialized with a capacity of at least `@sizeOf(T)` bytes.
pub inline fn writeInt(bw: *BufferedWriter, comptime T: type, value: T, endian: std.builtin.Endian) Writer.Error!void {
    var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
    std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
    return bw.writeAll(&bytes);
}

pub fn writeStruct(bw: *BufferedWriter, value: anytype) Writer.Error!void {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(@TypeOf(value)).@"struct".layout != .auto);
    return bw.writeAll(std.mem.asBytes(&value));
}

/// The function is inline to avoid the dead code in case `endian` is
/// comptime-known and matches host endianness.
/// TODO: make sure this value is not a reference type
pub inline fn writeStructEndian(bw: *BufferedWriter, value: anytype, endian: std.builtin.Endian) Writer.Error!void {
    if (native_endian == endian) {
        return bw.writeStruct(value);
    } else {
        var copy = value;
        std.mem.byteSwapAllFields(@TypeOf(value), &copy);
        return bw.writeStruct(copy);
    }
}

pub inline fn writeSliceEndian(
    bw: *BufferedWriter,
    Elem: type,
    slice: []const Elem,
    endian: std.builtin.Endian,
) Writer.Error!void {
    if (native_endian == endian) {
        return writeAll(bw, @ptrCast(slice));
    } else {
        return bw.writeArraySwap(bw, Elem, slice);
    }
}

/// Asserts that the buffer storage capacity is at least enough to store `@sizeOf(Elem)`
pub fn writeSliceSwap(bw: *BufferedWriter, Elem: type, slice: []const Elem) Writer.Error!void {
    // copy to storage first, then swap in place
    _ = bw;
    _ = slice;
    @panic("TODO");
}

/// Unlike `writeSplat` and `writeVec`, this function will call into the
/// underlying writer even if there is enough buffer capacity for the file
/// contents.
pub fn writeFile(
    bw: *BufferedWriter,
    file: std.fs.File,
    offset: Writer.Offset,
    limit: Writer.Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) Writer.FileError!usize {
    return passthruWriteFile(bw, file, offset, limit, headers_and_trailers, headers_len);
}

fn passthruWriteFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: Writer.Offset,
    limit: Writer.Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) Writer.FileError!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    const buffer = bw.buffer;
    if (buffer.len == 0) return track(
        &bw.count,
        try bw.unbuffered_writer.writeFile(file, offset, limit, headers_and_trailers, headers_len),
    );
    const start_end = bw.end;
    const headers = headers_and_trailers[0..headers_len];
    const trailers = headers_and_trailers[headers_len..];
    var buffers: [max_buffers_len][]const u8 = undefined;
    var end = start_end;
    for (headers, 0..) |header, i| {
        const new_end = end + header.len;
        if (new_end <= buffer.len) {
            @branchHint(.likely);
            @memcpy(buffer[end..new_end], header);
            end = new_end;
            continue;
        }
        buffers[0] = buffer[0..end];
        const remaining_headers = headers[i..];
        const remaining_buffers = buffers[1..];
        const buffers_len: usize = @min(remaining_headers.len, remaining_buffers.len);
        @memcpy(remaining_buffers[0..buffers_len], remaining_headers[0..buffers_len]);
        if (buffers_len >= remaining_headers.len) {
            // Made it past the headers, so we can call `writeFile`.
            const remaining_buffers_for_trailers = remaining_buffers[buffers_len..];
            const send_trailers_len: usize = @min(trailers.len, remaining_buffers_for_trailers.len);
            @memcpy(remaining_buffers_for_trailers[0..send_trailers_len], trailers[0..send_trailers_len]);
            const send_headers_len = 1 + buffers_len;
            const send_buffers = buffers[0 .. send_headers_len + send_trailers_len];
            const n = try bw.unbuffered_writer.writeFile(file, offset, limit, send_buffers, send_headers_len);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return track(&bw.count, end - start_end);
            }
            bw.end = 0;
            return track(&bw.count, n - start_end);
        }
        // Have not made it past the headers yet; must call `writeVec`.
        const n = try bw.unbuffered_writer.writeVec(buffers[0 .. buffers_len + 1]);
        if (n < end) {
            @branchHint(.unlikely);
            const remainder = buffer[n..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return track(&bw.count, end - start_end);
        }
        bw.end = 0;
        return track(&bw.count, n - start_end);
    }
    // All headers written to buffer.
    buffers[0] = buffer[0..end];
    const remaining_buffers = buffers[1..];
    const send_trailers_len: usize = @min(trailers.len, remaining_buffers.len);
    @memcpy(remaining_buffers[0..send_trailers_len], trailers[0..send_trailers_len]);
    const send_headers_len = @intFromBool(end != 0);
    const send_buffers = buffers[1 - send_headers_len .. 1 + send_trailers_len];
    const n = try bw.unbuffered_writer.writeFile(file, offset, limit, send_buffers, send_headers_len);
    if (n < end) {
        @branchHint(.unlikely);
        const remainder = buffer[n..end];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        bw.end = remainder.len;
        return track(&bw.count, end - start_end);
    }
    bw.end = 0;
    return track(&bw.count, n - start_end);
}

pub const WriteFileOptions = struct {
    offset: Writer.Offset = .none,
    /// If the size of the source file is known, it is likely that passing the
    /// size here will save one syscall.
    limit: Writer.Limit = .unlimited,
    /// Headers and trailers must be passed together so that in case `len` is
    /// zero, they can be forwarded directly to `Writer.VTable.writeVec`.
    ///
    /// The parameter is mutable because this function needs to mutate the
    /// fields in order to handle partial writes from `Writer.VTable.writeFile`.
    headers_and_trailers: [][]const u8 = &.{},
    /// The number of trailers is inferred from
    /// `headers_and_trailers.len - headers_len`.
    headers_len: usize = 0,
};

pub fn writeFileAll(bw: *BufferedWriter, file: std.fs.File, options: WriteFileOptions) Writer.FileError!void {
    const headers_and_trailers = options.headers_and_trailers;
    const headers = headers_and_trailers[0..options.headers_len];
    switch (options.limit) {
        .nothing => return bw.writeVecAll(headers_and_trailers),
        .unlimited => {
            // When reading the whole file, we cannot include the trailers in the
            // call that reads from the file handle, because we have no way to
            // determine whether a partial write is past the end of the file or
            // not.
            var i: usize = 0;
            var offset = options.offset;
            while (true) {
                var n = try bw.writeFile(file, offset, .unlimited, headers[i..], headers.len - i);
                while (i < headers.len and n >= headers[i].len) {
                    n -= headers[i].len;
                    i += 1;
                }
                if (i < headers.len) {
                    headers[i] = headers[i][n..];
                    continue;
                }
                if (n == 0) break;
                offset = offset.advance(n);
            }
        },
        else => {
            var len = options.limit.toInt().?;
            var i: usize = 0;
            var offset = options.offset;
            while (true) {
                var n = try bw.writeFile(file, offset, .limited(len), headers_and_trailers[i..], headers.len - i);
                while (i < headers.len and n >= headers[i].len) {
                    n -= headers[i].len;
                    i += 1;
                }
                if (i < headers.len) {
                    headers[i] = headers[i][n..];
                    continue;
                }
                if (n >= len) {
                    n -= len;
                    if (i >= headers_and_trailers.len) return;
                    while (n >= headers_and_trailers[i].len) {
                        n -= headers_and_trailers[i].len;
                        i += 1;
                        if (i >= headers_and_trailers.len) return;
                    }
                    headers_and_trailers[i] = headers_and_trailers[i][n..];
                    return bw.writeVecAll(headers_and_trailers[i..]);
                }
                offset = offset.advance(n);
                len -= n;
            }
        },
    }
}

pub fn alignBuffer(
    bw: *BufferedWriter,
    buffer: []const u8,
    width: usize,
    alignment: std.fmt.Alignment,
    fill: u8,
) Writer.Error!void {
    const padding = if (buffer.len < width) width - buffer.len else 0;
    if (padding == 0) {
        @branchHint(.likely);
        return bw.writeAll(buffer);
    }
    switch (alignment) {
        .left => {
            try bw.writeAll(buffer);
            try bw.splatByteAll(fill, padding);
        },
        .center => {
            const left_padding = padding / 2;
            const right_padding = (padding + 1) / 2;
            try bw.splatByteAll(fill, left_padding);
            try bw.writeAll(buffer);
            try bw.splatByteAll(fill, right_padding);
        },
        .right => {
            try bw.splatByteAll(fill, padding);
            try bw.writeAll(buffer);
        },
    }
}

pub fn alignBufferOptions(bw: *BufferedWriter, buffer: []const u8, options: std.fmt.Options) Writer.Error!void {
    return bw.alignBuffer(buffer, options.width orelse buffer.len, options.alignment, options.fill);
}

pub fn printAddress(bw: *BufferedWriter, value: anytype) Writer.Error!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .pointer => |info| {
            try bw.writeAll(@typeName(info.child) ++ "@");
            if (info.size == .slice)
                try bw.printIntOptions(@intFromPtr(value.ptr), 16, .lower, .{})
            else
                try bw.printIntOptions(@intFromPtr(value), 16, .lower, .{});
            return;
        },
        .optional => |info| {
            if (@typeInfo(info.child) == .pointer) {
                try bw.writeAll(@typeName(info.child) ++ "@");
                try bw.printIntOptions(@intFromPtr(value), 16, .lower, .{});
                return;
            }
        },
        else => {},
    }

    @compileError("cannot format non-pointer type " ++ @typeName(T) ++ " with * specifier");
}

pub fn printValue(
    bw: *BufferedWriter,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
    max_depth: usize,
) Writer.Error!void {
    const T = @TypeOf(value);
    const actual_fmt = comptime if (std.mem.eql(u8, fmt, ANY))
        defaultFormatString(T)
    else if (fmt.len != 0 and (fmt[0] == '?' or fmt[0] == '!')) switch (@typeInfo(T)) {
        .optional, .error_union => fmt,
        else => stripOptionalOrErrorUnionSpec(fmt),
    } else fmt;

    if (comptime std.mem.eql(u8, actual_fmt, "*")) {
        return bw.printAddress(value);
    }

    if (std.meta.hasMethod(T, "format")) {
        if (fmt.len > 0 and fmt[0] == 'f') {
            return value.format(bw, fmt[1..]);
        } else if (fmt.len == 0) {
            // after 0.15.0 is tagged, delete the hasMethod condition and this compile error
            @compileError("ambiguous format string; specify {f} to call format method, or {any} to skip it");
        }
    }

    switch (@typeInfo(T)) {
        .float, .comptime_float => return bw.printFloat(actual_fmt, options, value),
        .int, .comptime_int => return bw.printInt(actual_fmt, options, value),
        .bool => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return bw.alignBufferOptions(if (value) "true" else "false", options);
        },
        .void => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return bw.alignBufferOptions("void", options);
        },
        .optional => {
            if (actual_fmt.len == 0 or actual_fmt[0] != '?')
                @compileError("cannot print optional without a specifier (i.e. {?} or {any})");
            const remaining_fmt = comptime stripOptionalOrErrorUnionSpec(actual_fmt);
            if (value) |payload| {
                return bw.printValue(remaining_fmt, options, payload, max_depth);
            } else {
                return bw.alignBufferOptions("null", options);
            }
        },
        .error_union => {
            if (actual_fmt.len == 0 or actual_fmt[0] != '!')
                @compileError("cannot format error union without a specifier (i.e. {!} or {any})");
            const remaining_fmt = comptime stripOptionalOrErrorUnionSpec(actual_fmt);
            if (value) |payload| {
                return bw.printValue(remaining_fmt, options, payload, max_depth);
            } else |err| {
                return bw.printValue("", options, err, max_depth);
            }
        },
        .error_set => {
            if (actual_fmt.len > 0 and actual_fmt[0] == 's') {
                return bw.writeAll(@errorName(value));
            } else if (actual_fmt.len != 0) {
                invalidFmtError(fmt, value);
            } else {
                try bw.writeAll("error.");
                try bw.writeAll(@errorName(value));
            }
        },
        .@"enum" => |enum_info| {
            try bw.writeAll(@typeName(T));
            if (enum_info.is_exhaustive) {
                if (actual_fmt.len != 0) invalidFmtError(fmt, value);
                try bw.writeAll(".");
                try bw.writeAll(@tagName(value));
                return;
            }

            // Use @tagName only if value is one of known fields
            @setEvalBranchQuota(3 * enum_info.fields.len);
            inline for (enum_info.fields) |enumField| {
                if (@intFromEnum(value) == enumField.value) {
                    try bw.writeAll(".");
                    try bw.writeAll(@tagName(value));
                    return;
                }
            }

            try bw.writeByte('(');
            try bw.printValue(actual_fmt, options, @intFromEnum(value), max_depth);
            try bw.writeByte(')');
        },
        .@"union" => |info| {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            try bw.writeAll(@typeName(T));
            if (max_depth == 0) {
                try bw.writeAll("{ ... }");
                return;
            }
            if (info.tag_type) |UnionTagType| {
                try bw.writeAll("{ .");
                try bw.writeAll(@tagName(@as(UnionTagType, value)));
                try bw.writeAll(" = ");
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        try bw.printValue(ANY, options, @field(value, u_field.name), max_depth - 1);
                    }
                }
                try bw.writeAll(" }");
            } else {
                try bw.writeByte('@');
                try bw.printIntOptions(@intFromPtr(&value), 16, .lower, options);
            }
        },
        .@"struct" => |info| {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            if (info.is_tuple) {
                // Skip the type and field names when formatting tuples.
                if (max_depth == 0) {
                    try bw.writeAll("{ ... }");
                    return;
                }
                try bw.writeAll("{");
                inline for (info.fields, 0..) |f, i| {
                    if (i == 0) {
                        try bw.writeAll(" ");
                    } else {
                        try bw.writeAll(", ");
                    }
                    try bw.printValue(ANY, options, @field(value, f.name), max_depth - 1);
                }
                try bw.writeAll(" }");
                return;
            }
            try bw.writeAll(@typeName(T));
            if (max_depth == 0) {
                try bw.writeAll("{ ... }");
                return;
            }
            try bw.writeAll("{");
            inline for (info.fields, 0..) |f, i| {
                if (i == 0) {
                    try bw.writeAll(" .");
                } else {
                    try bw.writeAll(", .");
                }
                try bw.writeAll(f.name);
                try bw.writeAll(" = ");
                try bw.printValue(ANY, options, @field(value, f.name), max_depth - 1);
            }
            try bw.writeAll(" }");
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array, .@"enum", .@"union", .@"struct" => {
                    return bw.printValue(actual_fmt, options, value.*, max_depth);
                },
                else => {
                    var buffers: [2][]const u8 = .{ @typeName(ptr_info.child), "@" };
                    try bw.writeVecAll(&buffers);
                    try bw.printIntOptions(@intFromPtr(value), 16, .lower, options);
                    return;
                },
            },
            .many, .c => {
                if (actual_fmt.len == 0)
                    @compileError("cannot format pointer without a specifier (i.e. {s} or {*})");
                if (ptr_info.sentinel() != null) {
                    return bw.printValue(actual_fmt, options, std.mem.span(value), max_depth);
                }
                if (actual_fmt[0] == 's' and ptr_info.child == u8) {
                    return bw.alignBufferOptions(std.mem.span(value), options);
                }
                invalidFmtError(fmt, value);
            },
            .slice => {
                if (actual_fmt.len == 0)
                    @compileError("cannot format slice without a specifier (i.e. {s}, {x}, {b64}, or {any})");
                if (max_depth == 0) {
                    return bw.writeAll("{ ... }");
                }
                if (ptr_info.child == u8) switch (actual_fmt.len) {
                    1 => switch (actual_fmt[0]) {
                        's' => return bw.alignBufferOptions(value, options),
                        'x' => return bw.printHex(value, .lower),
                        'X' => return bw.printHex(value, .upper),
                        else => {},
                    },
                    3 => if (actual_fmt[0] == 'b' and actual_fmt[1] == '6' and actual_fmt[2] == '4') {
                        return bw.printBase64(value);
                    },
                    else => {},
                };
                try bw.writeAll("{ ");
                for (value, 0..) |elem, i| {
                    try bw.printValue(actual_fmt, options, elem, max_depth - 1);
                    if (i != value.len - 1) {
                        try bw.writeAll(", ");
                    }
                }
                try bw.writeAll(" }");
            },
        },
        .array => |info| {
            if (actual_fmt.len == 0)
                @compileError("cannot format array without a specifier (i.e. {s} or {any})");
            if (max_depth == 0) {
                return bw.writeAll("{ ... }");
            }
            if (info.child == u8) {
                if (actual_fmt[0] == 's') {
                    return bw.alignBufferOptions(&value, options);
                } else if (actual_fmt[0] == 'x') {
                    return bw.printHex(&value, .lower);
                } else if (actual_fmt[0] == 'X') {
                    return bw.printHex(&value, .upper);
                }
            }
            try bw.writeAll("{ ");
            for (value, 0..) |elem, i| {
                try bw.printValue(actual_fmt, options, elem, max_depth - 1);
                if (i < value.len - 1) {
                    try bw.writeAll(", ");
                }
            }
            try bw.writeAll(" }");
        },
        .vector => |info| {
            if (max_depth == 0) {
                return bw.writeAll("{ ... }");
            }
            try bw.writeAll("{ ");
            var i: usize = 0;
            while (i < info.len) : (i += 1) {
                try bw.printValue(actual_fmt, options, value[i], max_depth - 1);
                if (i < info.len - 1) {
                    try bw.writeAll(", ");
                }
            }
            try bw.writeAll(" }");
        },
        .@"fn" => @compileError("unable to format function body type, use '*const " ++ @typeName(T) ++ "' for a function pointer type"),
        .type => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return bw.alignBufferOptions(@typeName(value), options);
        },
        .enum_literal => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            const buffer = [_]u8{'.'} ++ @tagName(value);
            return bw.alignBufferOptions(buffer, options);
        },
        .null => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return bw.alignBufferOptions("null", options);
        },
        else => @compileError("unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

pub fn printInt(
    bw: *BufferedWriter,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
) Writer.Error!void {
    const int_value = if (@TypeOf(value) == comptime_int) blk: {
        const Int = std.math.IntFittingRange(value, value);
        break :blk @as(Int, value);
    } else value;

    switch (fmt.len) {
        0 => return bw.printIntOptions(int_value, 10, .lower, options),
        1 => switch (fmt[0]) {
            'd' => return bw.printIntOptions(int_value, 10, .lower, options),
            'c' => {
                if (@typeInfo(@TypeOf(int_value)).int.bits <= 8) {
                    return bw.printAsciiChar(@as(u8, int_value), options);
                } else {
                    @compileError("cannot print integer that is larger than 8 bits as an ASCII character");
                }
            },
            'u' => {
                if (@typeInfo(@TypeOf(int_value)).int.bits <= 21) {
                    return bw.printUnicodeCodepoint(@as(u21, int_value), options);
                } else {
                    @compileError("cannot print integer that is larger than 21 bits as an UTF-8 sequence");
                }
            },
            'b' => return bw.printIntOptions(int_value, 2, .lower, options),
            'x' => return bw.printIntOptions(int_value, 16, .lower, options),
            'X' => return bw.printIntOptions(int_value, 16, .upper, options),
            'o' => return bw.printIntOptions(int_value, 8, .lower, options),
            'B' => return bw.printByteSize(int_value, .decimal, options),
            'D' => return bw.printDuration(int_value, options),
            else => invalidFmtError(fmt, value),
        },
        2 => {
            if (fmt[0] == 'B' and fmt[1] == 'i') {
                return bw.printByteSize(int_value, .binary, options);
            } else {
                invalidFmtError(fmt, value);
            }
        },
        else => invalidFmtError(fmt, value),
    }
    comptime unreachable;
}

pub fn printAsciiChar(bw: *BufferedWriter, c: u8, options: std.fmt.Options) Writer.Error!void {
    return bw.alignBufferOptions(@as(*const [1]u8, &c), options);
}

pub fn printAscii(bw: *BufferedWriter, bytes: []const u8, options: std.fmt.Options) Writer.Error!void {
    return bw.alignBufferOptions(bytes, options);
}

pub fn printUnicodeCodepoint(bw: *BufferedWriter, c: u21, options: std.fmt.Options) Writer.Error!void {
    var buf: [4]u8 = undefined;
    const len = try std.unicode.utf8Encode(c, &buf);
    return bw.alignBufferOptions(buf[0..len], options);
}

pub fn printIntOptions(
    bw: *BufferedWriter,
    value: anytype,
    base: u8,
    case: std.fmt.Case,
    options: std.fmt.Options,
) Writer.Error!void {
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

    return bw.alignBufferOptions(buf[index..], options);
}

pub fn printFloat(
    bw: *BufferedWriter,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
) Writer.Error!void {
    var buf: [std.fmt.float.bufferSize(.decimal, f64)]u8 = undefined;

    if (fmt.len > 1) invalidFmtError(fmt, value);
    switch (if (fmt.len == 0) 'e' else fmt[0]) {
        'e' => {
            const s = std.fmt.float.render(&buf, value, .{ .mode = .scientific, .precision = options.precision }) catch |err| switch (err) {
                error.BufferTooSmall => "(float)",
            };
            return bw.alignBufferOptions(s, options);
        },
        'd' => {
            const s = std.fmt.float.render(&buf, value, .{ .mode = .decimal, .precision = options.precision }) catch |err| switch (err) {
                error.BufferTooSmall => "(float)",
            };
            return bw.alignBufferOptions(s, options);
        },
        'x' => {
            var sub_bw: BufferedWriter = undefined;
            sub_bw.initFixed(&buf);
            sub_bw.printFloatHexadecimal(value, options.precision) catch unreachable;
            return bw.alignBufferOptions(sub_bw.getWritten(), options);
        },
        else => invalidFmtError(fmt, value),
    }
}

pub fn printFloatHexadecimal(bw: *BufferedWriter, value: anytype, opt_precision: ?usize) Writer.Error!void {
    if (std.math.signbit(value)) try bw.writeByte('-');
    if (std.math.isNan(value)) return bw.writeAll("nan");
    if (std.math.isInf(value)) return bw.writeAll("inf");

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
        try bw.writeAll("0x0");
        if (opt_precision) |precision| {
            if (precision > 0) {
                try bw.writeAll(".");
                try bw.splatByteAll('0', precision);
            }
        } else {
            try bw.writeAll(".0");
        }
        try bw.writeAll("p0");
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

    try bw.writeAll("0x");
    try bw.writeByte(buf[0]);
    const trimmed = std.mem.trimRight(u8, buf[1..], "0");
    if (opt_precision) |precision| {
        if (precision > 0) try bw.writeAll(".");
    } else if (trimmed.len > 0) {
        try bw.writeAll(".");
    }
    try bw.writeAll(trimmed);
    // Add trailing zeros if explicitly requested.
    if (opt_precision) |precision| if (precision > 0) {
        if (precision > trimmed.len)
            try bw.splatByteAll('0', precision - trimmed.len);
    };
    try bw.writeAll("p");
    try bw.printIntOptions(exponent - exponent_bias, 10, .lower, .{});
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
    bw: *std.io.BufferedWriter,
    value: u64,
    comptime units: ByteSizeUnits,
    options: std.fmt.Options,
) Writer.Error!void {
    if (value == 0) return bw.alignBufferOptions("0B", options);
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

    return bw.alignBufferOptions(buf[0..i], options);
}

// This ANY const is a workaround for: https://github.com/ziglang/zig/issues/7948
const ANY = "any";

fn defaultFormatString(comptime T: type) [:0]const u8 {
    switch (@typeInfo(T)) {
        .array, .vector => return ANY,
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array => return ANY,
                else => {},
            },
            .many, .c => return "*",
            .slice => return ANY,
        },
        .optional => |info| return "?" ++ defaultFormatString(info.child),
        .error_union => |info| return "!" ++ defaultFormatString(info.payload),
        else => {},
    }
    return "";
}

fn stripOptionalOrErrorUnionSpec(comptime fmt: []const u8) []const u8 {
    return if (std.mem.eql(u8, fmt[1..], ANY))
        ANY
    else
        fmt[1..];
}

pub fn invalidFmtError(comptime fmt: []const u8, value: anytype) noreturn {
    @compileError("invalid format string '" ++ fmt ++ "' for type '" ++ @typeName(@TypeOf(value)) ++ "'");
}

pub fn printDurationSigned(bw: *BufferedWriter, ns: i64) Writer.Error!void {
    if (ns < 0) try bw.writeByte('-');
    return bw.printDurationUnsigned(@abs(ns));
}

pub fn printDurationUnsigned(bw: *BufferedWriter, ns: u64) Writer.Error!void {
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
            try bw.printIntOptions(units, 10, .lower, .{});
            try bw.writeByte(unit.sep);
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
            try bw.printIntOptions(kunits / 1000, 10, .lower, .{});
            const frac = kunits % 1000;
            if (frac > 0) {
                // Write up to 3 decimal places
                var decimal_buf = [_]u8{ '.', 0, 0, 0 };
                var inner: BufferedWriter = undefined;
                inner.initFixed(decimal_buf[1..]);
                inner.printIntOptions(frac, 10, .lower, .{ .fill = '0', .width = 3 }) catch unreachable;
                var end: usize = 4;
                while (end > 1) : (end -= 1) {
                    if (decimal_buf[end - 1] != '0') break;
                }
                try bw.writeAll(decimal_buf[0..end]);
            }
            return bw.writeAll(unit.sep);
        }
    }

    try bw.printIntOptions(ns_remaining, 10, .lower, .{});
    try bw.writeAll("ns");
}

/// Writes number of nanoseconds according to its signed magnitude:
/// `[#y][#w][#d][#h][#m]#[.###][n|u|m]s`
/// `nanoseconds` must be an integer that coerces into `u64` or `i64`.
pub fn printDuration(bw: *BufferedWriter, nanoseconds: anytype, options: std.fmt.Options) Writer.Error!void {
    // worst case: "-XXXyXXwXXdXXhXXmXX.XXXs".len = 24
    var buf: [24]u8 = undefined;
    var sub_bw: BufferedWriter = undefined;
    sub_bw.initFixed(&buf);
    switch (@typeInfo(@TypeOf(nanoseconds)).int.signedness) {
        .signed => sub_bw.printDurationSigned(nanoseconds) catch unreachable,
        .unsigned => sub_bw.printDurationUnsigned(nanoseconds) catch unreachable,
    }
    return bw.alignBufferOptions(sub_bw.getWritten(), options);
}

pub fn printHex(bw: *BufferedWriter, bytes: []const u8, case: std.fmt.Case) Writer.Error!void {
    const charset = switch (case) {
        .upper => "0123456789ABCDEF",
        .lower => "0123456789abcdef",
    };
    for (bytes) |c| {
        try bw.writeByte(charset[c >> 4]);
        try bw.writeByte(charset[c & 15]);
    }
}

pub fn printBase64(bw: *BufferedWriter, bytes: []const u8) Writer.Error!void {
    var chunker = std.mem.window(u8, bytes, 3, 3);
    var temp: [5]u8 = undefined;
    while (chunker.next()) |chunk| {
        try bw.writeAll(std.base64.standard.Encoder.encode(&temp, chunk));
    }
}

/// Write a single unsigned integer as LEB128 to the given writer.
pub fn writeUleb128(bw: *BufferedWriter, value: anytype) Writer.Error!void {
    try bw.writeLeb128(switch (@typeInfo(@TypeOf(value))) {
        .comptime_int => @as(std.math.IntFittingRange(0, @abs(value)), value),
        .int => |value_info| switch (value_info.signedness) {
            .signed => @as(@Type(.{ .int = .{ .signedness = .unsigned, .bits = value_info.bits -| 1 } }), @intCast(value)),
            .unsigned => value,
        },
        else => comptime unreachable,
    });
}

/// Write a single signed integer as LEB128 to the given writer.
pub fn writeSleb128(bw: *BufferedWriter, value: anytype) Writer.Error!void {
    try bw.writeLeb128(switch (@typeInfo(@TypeOf(value))) {
        .comptime_int => @as(std.math.IntFittingRange(@min(value, -1), @max(0, value)), value),
        .int => |value_info| switch (value_info.signedness) {
            .signed => value,
            .unsigned => @as(@Type(.{ .int = .{ .signedness = .signed, .bits = value_info.bits + 1 } }), value),
        },
        else => comptime unreachable,
    });
}

/// Write a single integer as LEB128 to the given writer.
pub fn writeLeb128(bw: *BufferedWriter, value: anytype) Writer.Error!void {
    const value_info = @typeInfo(@TypeOf(value)).int;
    try bw.writeMultipleOf7Leb128(@as(@Type(.{ .int = .{
        .signedness = value_info.signedness,
        .bits = std.mem.alignForwardAnyAlign(u16, value_info.bits, 7),
    } }), value));
}

fn writeMultipleOf7Leb128(bw: *BufferedWriter, value: anytype) Writer.Error!void {
    const value_info = @typeInfo(@TypeOf(value)).int;
    comptime assert(value_info.bits % 7 == 0);
    var remaining = value;
    while (true) {
        const buffer: []packed struct(u8) { bits: u7, more: bool } = @ptrCast(try bw.writableSliceGreedy(1));
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
            if (!more) return bw.advance(len);
        }
        bw.advance(buffer.len);
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
            bw: *BufferedWriter,
        ) Writer.Error!void {
            _ = options;
            if (fmt.len == 0) {
                return bw.print("({d:.3},{d:.3})", .{ self.x, self.y });
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
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buf);
    try bw.printValue("", .{}, inst, 0);
    try testing.expectEqualStrings("io.BufferedWriter.test.printValue max_depth.S{ ... }", bw.getWritten());

    bw.reset();
    try bw.printValue("", .{}, inst, 1);
    try testing.expectEqualStrings("io.BufferedWriter.test.printValue max_depth.S{ .a = io.BufferedWriter.test.printValue max_depth.S{ ... }, .tu = io.BufferedWriter.test.printValue max_depth.TU{ ... }, .e = io.BufferedWriter.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }", bw.getWritten());

    bw.reset();
    try bw.printValue("", .{}, inst, 2);
    try testing.expectEqualStrings("io.BufferedWriter.test.printValue max_depth.S{ .a = io.BufferedWriter.test.printValue max_depth.S{ .a = io.BufferedWriter.test.printValue max_depth.S{ ... }, .tu = io.BufferedWriter.test.printValue max_depth.TU{ ... }, .e = io.BufferedWriter.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }, .tu = io.BufferedWriter.test.printValue max_depth.TU{ .ptr = io.BufferedWriter.test.printValue max_depth.TU{ ... } }, .e = io.BufferedWriter.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }", bw.getWritten());

    bw.reset();
    try bw.printValue("", .{}, inst, 3);
    try testing.expectEqualStrings("io.BufferedWriter.test.printValue max_depth.S{ .a = io.BufferedWriter.test.printValue max_depth.S{ .a = io.BufferedWriter.test.printValue max_depth.S{ .a = io.BufferedWriter.test.printValue max_depth.S{ ... }, .tu = io.BufferedWriter.test.printValue max_depth.TU{ ... }, .e = io.BufferedWriter.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }, .tu = io.BufferedWriter.test.printValue max_depth.TU{ .ptr = io.BufferedWriter.test.printValue max_depth.TU{ ... } }, .e = io.BufferedWriter.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }, .tu = io.BufferedWriter.test.printValue max_depth.TU{ .ptr = io.BufferedWriter.test.printValue max_depth.TU{ .ptr = io.BufferedWriter.test.printValue max_depth.TU{ ... } } }, .e = io.BufferedWriter.test.printValue max_depth.E.Two, .vec = (10.200,2.220) }", bw.getWritten());

    const vec: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    bw.reset();
    try bw.printValue("", .{}, vec, 0);
    try testing.expectEqualStrings("{ ... }", bw.getWritten());

    bw.reset();
    try bw.printValue("", .{}, vec, 1);
    try testing.expectEqualStrings("{ 1, 2, 3, 4 }", bw.getWritten());
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
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buf);
    try bw.printDurationUnsigned(input);
    try testing.expectEqualStrings(expected, bw.getWritten());
}

fn testDurationCaseSigned(expected: []const u8, input: i64) !void {
    var buf: [24]u8 = undefined;
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buf);
    try bw.printDurationSigned(input);
    try testing.expectEqualStrings(expected, bw.getWritten());
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
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buf);
    try bw.printInt(@as(comptime_int, 123456789123456789), "", .{});
    try std.testing.expectEqualStrings("123456789123456789", bw.getWritten());
}

test "printFloat with comptime_float" {
    var buf: [20]u8 = undefined;
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buf);
    try bw.printFloat("", .{}, @as(comptime_float, 1.0));
    try std.testing.expectEqualStrings(bw.getWritten(), "1e0");
    try std.testing.expectFmt("1e0", "{}", .{1.0});
}

fn testPrintIntCase(expected: []const u8, value: anytype, base: u8, case: std.fmt.Case, options: std.fmt.Options) !void {
    var buffer: [100]u8 = undefined;
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buffer);
    bw.printIntOptions(value, base, case, options);
    try testing.expectEqualStrings(expected, bw.getWritten());
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

test initFixed {
    {
        var buf: [255]u8 = undefined;
        var bw: BufferedWriter = undefined;
        bw.initFixed(&buf);
        try bw.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualStrings("HelloWorld!", bw.getWritten());
    }

    comptime {
        var buf: [255]u8 = undefined;
        var bw: BufferedWriter = undefined;
        bw.initFixed(&buf);
        try bw.print("{s}{s}!", .{ "Hello", "World" });
        try testing.expectEqualStrings("HelloWorld!", bw.getWritten());
    }
}

test "fixed output" {
    var buffer: [10]u8 = undefined;
    var bw: BufferedWriter = undefined;
    bw.initFixed(&buffer);

    try bw.writeAll("Hello");
    try testing.expect(std.mem.eql(u8, bw.getWritten(), "Hello"));

    try bw.writeAll("world");
    try testing.expect(std.mem.eql(u8, bw.getWritten(), "Helloworld"));

    try testing.expectError(error.WriteStreamEnd, bw.writeAll("!"));
    try testing.expect(std.mem.eql(u8, bw.getWritten(), "Helloworld"));

    bw.reset();
    try testing.expect(bw.getWritten().len == 0);

    try testing.expectError(error.WriteStreamEnd, bw.writeAll("Hello world!"));
    try testing.expect(std.mem.eql(u8, bw.getWritten(), "Hello worl"));

    try bw.seekTo((try bw.getEndPos()) + 1);
    try testing.expectError(error.WriteStreamEnd, bw.writeAll("H"));
}
