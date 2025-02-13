const std = @import("../std.zig");
const BufferedWriter = @This();
const assert = std.debug.assert;
const native_endian = @import("builtin").target.cpu.arch.endian();
const Writer = std.io.Writer;

/// Underlying stream to send bytes to.
unbuffered_writer: Writer,
/// User-provided storage that must outlive this `BufferedWriter`.
///
/// If this has length zero, the writer is unbuffered, and `flush` is a no-op.
buffer: []u8,
/// Marks the end of `buffer` - before this are buffered bytes, after this is
/// undefined.
end: usize = 0,

/// Number of slices to store on the stack, when trying to send as many byte
/// vectors through the underlying write calls as possible.
pub const max_buffers_len = 8;

pub const vtable: Writer.VTable = .{
    .writev = writev,
    .writeFile = writeFile,
};

pub fn writer(bw: *BufferedWriter) Writer {
    return .{
        .context = bw,
        .vtable = &vtable,
    };
}

pub fn flush(bw: *BufferedWriter) anyerror!void {
    try bw.unbuffered_writer.writeAll(bw.buf[0..bw.end]);
    bw.end = 0;
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `Writer.VTable.writev`.
pub fn writevAll(bw: *BufferedWriter, data: []const []const u8) anyerror!void {
    var i: usize = 0;
    while (true) {
        var n = try writev(bw, data[i..]);
        while (n >= data[i].len) {
            n -= data[i].len;
            i += 1;
            if (i >= data.len) return;
        }
        data[i] = data[i][n..];
    }
}

pub fn writev(context: *anyopaque, data: []const []const u8) anyerror!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    const buffer = bw.buffer;
    const start_end = bw.end;
    var end = bw.end;
    for (data, 0..) |bytes, i| {
        const new_end = end + bytes.len;
        if (new_end <= buffer.len) {
            @branchHint(.likely);
            @memcpy(bw.buf[end..new_end], bytes);
            end = new_end;
            continue;
        }
        var buffers: [max_buffers_len][]const u8 = undefined;
        buffers[0] = buffer[0..end];
        const remaining_data = data[i..];
        const remaining_buffers = buffers[1..];
        const len: usize = @min(remaining_data.len, remaining_buffers.len);
        @memcpy(remaining_buffers[0..len], remaining_data[0..len]);
        const n = try bw.unbuffered_writer.writev(buffers[0 .. len + 1]);
        if (n < end) {
            @branchHint(.unlikely);
            const remainder = buffer[n..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return end - start_end;
        }
        bw.end = 0;
        return n - start_end;
    }
    bw.end = end;
    return end - start_end;
}

pub fn write(bw: *BufferedWriter, bytes: []const u8) anyerror!usize {
    const buffer = bw.buffer;
    const end = bw.end;
    const new_end = end + bytes.len;
    if (new_end > buffer.len) {
        var data: [2][]const u8 = .{ buffer[0..end], bytes };
        const n = try bw.unbuffered_writer.writev(&data);
        if (n < end) {
            @branchHint(.unlikely);
            const remainder = buffer[n..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return 0;
        }
        bw.end = 0;
        return n - end;
    }
    @memcpy(bw.buf[end..new_end], bytes);
    bw.end = new_end;
    return bytes.len;
}

/// This function is provided by the `Writer`, however it is
/// duplicated here so that `bw` can be passed to `std.fmt.format` directly,
/// avoiding one indirect function call.
pub fn writeAll(bw: *BufferedWriter, bytes: []const u8) anyerror!void {
    var index: usize = 0;
    while (index < bytes.len) index += try write(bw, bytes[index..]);
}

pub fn print(bw: *BufferedWriter, comptime format: []const u8, args: anytype) anyerror!void {
    return std.fmt.format(bw, format, args);
}

pub fn writeByte(bw: *BufferedWriter, byte: u8) anyerror!void {
    const buffer = bw.buffer;
    const end = bw.end;
    if (end == buffer.len) {
        @branchHint(.unlikely);
        var buffers: [2][]const u8 = .{ buffer, &.{byte} };
        while (true) {
            const n = try bw.unbuffered_writer.writev(&buffers);
            if (n == 0) {
                @branchHint(.unlikely);
                continue;
            } else if (n >= buffer.len) {
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
    buffer[end] = byte;
    bw.end = end + 1;
}

/// Writes the same byte many times, performing the underlying write call as
/// many times as necessary.
pub fn splatByteAll(bw: *BufferedWriter, byte: u8, n: usize) anyerror!void {
    var remaining: usize = n;
    while (remaining > 0) remaining -= try splatByte(bw, byte, remaining);
}

/// Writes the same byte many times, allowing short writes.
///
/// Does maximum of one underlying `Writer.VTable.writev`.
pub fn splatByte(bw: *BufferedWriter, byte: u8, n: usize) anyerror!usize {
    const buffer = bw.buffer;
    const end = bw.end;

    const new_end = end + n;
    if (new_end <= buffer.len) {
        @memset(buffer[end..][0..n], byte);
        bw.end = new_end;
        return n;
    }

    if (n <= buffer.len) {
        const written = try bw.unbuffered_writer.writev(buffer[0..end]);
        if (written < end) {
            @branchHint(.unlikely);
            const remainder = buffer[written..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return 0;
        }
        @memset(buffer[0..n], byte);
        bw.end = n;
        return n;
    }

    // First try to use only the unused buffer region, to make an attempt for a
    // single `writev`.
    const free_space = buffer[end..];
    var remaining = n - free_space.len;
    @memset(free_space, byte);
    var buffers: [max_buffers_len][]const u8 = undefined;
    buffers[0] = buffer;
    var buffer_i = 1;
    while (remaining > free_space.len and buffer_i < buffers.len) {
        buffers[buffer_i] = free_space;
        buffer_i += 1;
        remaining -= free_space.len;
    }
    if (remaining > 0 and buffer_i < buffers.len) {
        buffers[buffer_i] = free_space[0..remaining];
        buffer_i += 1;
        const written = try bw.unbuffered_writer.writev(buffers[0..buffer_i]);
        if (written < end) {
            @branchHint(.unlikely);
            const remainder = buffer[written..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return 0;
        }
        bw.end = 0;
        return written - end;
    }

    const written = try bw.unbuffered_writer.writev(buffers[0..buffer_i]);
    if (written < end) {
        @branchHint(.unlikely);
        const remainder = buffer[written..end];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        bw.end = remainder.len;
        return 0;
    }

    bw.end = 0;
    return written - end;
}

/// Writes the same slice many times, performing the underlying write call as
/// many times as necessary.
pub fn splatBytesAll(bw: *BufferedWriter, bytes: []const u8, n: usize) anyerror!void {
    var remaining: usize = n * bytes.len;
    while (remaining > 0) remaining -= try splatBytes(bw, bytes, remaining);
}

/// Writes the same slice many times, allowing short writes.
///
/// Does maximum of one underlying `Writer.VTable.writev`.
pub fn splatBytes(bw: *BufferedWriter, bytes: []const u8, n: usize) anyerror!usize {
    const buffer = bw.buffer;
    const start_end = bw.end;
    var end = start_end;
    var remaining = n;
    while (remaining > 0 and end + bytes.len <= buffer.len) {
        @memcpy(buffer[end..][0..bytes.len], bytes);
        end += bytes.len;
        remaining -= 1;
    }

    if (remaining == 0) {
        bw.end = end;
        return end - start_end;
    }

    var buffers: [max_buffers_len][]const u8 = undefined;
    var buffers_i: usize = 1;
    buffers[0] = buffer[0..end];
    const remaining_buffers = buffers[1..];
    const buffers_len: usize = @min(remaining, remaining_buffers.len);
    @memset(remaining_buffers[0..buffers_len], bytes);
    remaining -= buffers_len;
    buffers_i += buffers_len;

    const written = try bw.unbuffered_writer.writev(buffers[0..buffers_i]);
    if (written < end) {
        @branchHint(.unlikely);
        const remainder = buffer[written..end];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        bw.end = remainder.len;
        return end - start_end;
    }
    bw.end = 0;
    return written - start_end;
}

/// Asserts the `buffer` was initialized with a capacity of at least `@sizeOf(T)` bytes.
pub inline fn writeInt(bw: *BufferedWriter, comptime T: type, value: T, endian: std.builtin.Endian) anyerror!void {
    var bytes: [@divExact(@typeInfo(T).int.bits, 8)]u8 = undefined;
    std.mem.writeInt(std.math.ByteAlignedInt(@TypeOf(value)), &bytes, value, endian);
    return bw.writeAll(&bytes);
}

pub fn writeStruct(bw: *BufferedWriter, value: anytype) anyerror!void {
    // Only extern and packed structs have defined in-memory layout.
    comptime assert(@typeInfo(@TypeOf(value)).@"struct".layout != .auto);
    return bw.writeAll(std.mem.asBytes(&value));
}

pub fn writeStructEndian(bw: *BufferedWriter, value: anytype, endian: std.builtin.Endian) anyerror!void {
    // TODO: make sure this value is not a reference type
    if (native_endian == endian) {
        return bw.writeStruct(value);
    } else {
        var copy = value;
        std.mem.byteSwapAllFields(@TypeOf(value), &copy);
        return bw.writeStruct(copy);
    }
}

pub fn writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: Writer.VTable.FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    const buffer = bw.buffer;
    const start_end = bw.end;
    const headers = headers_and_trailers[0..headers_len];
    const trailers = headers_and_trailers[headers_len..];
    var buffers: [max_buffers_len][]const u8 = undefined;
    var end = start_end;
    for (headers, 0..) |header, i| {
        const new_end = end + header.len;
        if (new_end <= buffer.len) {
            @branchHint(.likely);
            @memcpy(bw.buf[end..new_end], header);
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
            const n = try bw.unbuffered_writer.writeFile(file, offset, len, send_buffers, send_headers_len);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return end - start_end;
            }
            bw.end = 0;
            return n - start_end;
        }
        // Have not made it past the headers yet; must call `writev`.
        const n = try bw.unbuffered_writer.writev(buffers[0 .. buffers_len + 1]);
        if (n < end) {
            @branchHint(.unlikely);
            const remainder = buffer[n..end];
            std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
            bw.end = remainder.len;
            return end - start_end;
        }
        bw.end = 0;
        return n - start_end;
    }
    // All headers written to buffer.
    buffers[0] = buffer[0..end];
    const remaining_buffers = buffers[1..];
    const send_trailers_len: usize = @min(trailers.len, remaining_buffers.len);
    @memcpy(remaining_buffers[0..send_trailers_len], trailers[0..send_trailers_len]);
    const send_headers_len = 1;
    const send_buffers = buffers[0 .. send_headers_len + send_trailers_len];
    const n = try bw.unbuffered_writer.writeFile(file, offset, len, send_buffers, send_headers_len);
    if (n < end) {
        @branchHint(.unlikely);
        const remainder = buffer[n..end];
        std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
        bw.end = remainder.len;
        return end - start_end;
    }
    bw.end = 0;
    return n - start_end;
}

pub const WriteFileOptions = struct {
    offset: u64 = 0,
    /// If the size of the source file is known, it is likely that passing the
    /// size here will save one syscall.
    len: Writer.VTable.FileLen = .entire_file,
    /// Headers and trailers must be passed together so that in case `len` is
    /// zero, they can be forwarded directly to `Writer.VTable.writev`.
    ///
    /// The parameter is mutable because this function needs to mutate the
    /// fields in order to handle partial writes from `Writer.VTable.writeFile`.
    headers_and_trailers: [][]const u8 = &.{},
    /// The number of trailers is inferred from `headers_and_trailers.len -
    /// headers_len`.
    headers_len: usize = 0,
};

pub fn writeFileAll(bw: *BufferedWriter, file: std.fs.File, options: WriteFileOptions) anyerror!void {
    const headers_and_trailers = options.headers_and_trailers;
    const headers = headers_and_trailers[0..options.headers_len];
    var len = options.len;
    var i: usize = 0;
    var offset = options.offset;
    if (len == .zero) return writevAll(bw, headers_and_trailers[i..]);
    while (i < headers_and_trailers.len) {
        var n = try writeFile(bw, file, offset, len, headers_and_trailers[i..], headers.len - i);
        while (i < headers.len and n >= headers[i].len) {
            n -= headers[i].len;
            i += 1;
        }
        if (i < headers.len) {
            headers[i] = headers[i][n..];
            continue;
        }
        if (n >= len.int()) {
            n -= len.int();
            while (n >= headers_and_trailers[i].len) {
                n -= headers_and_trailers[i].len;
                i += 1;
                if (i >= headers_and_trailers.len) return;
            }
            headers_and_trailers[i] = headers_and_trailers[i][n..];
            return writevAll(bw, headers_and_trailers[i..]);
        }
        offset += n;
        len = if (len == .entire_file) .entire_file else .init(len.int() - n);
    }
}

pub fn alignBuffer(
    bw: *std.io.BufferedWriter,
    buffer: []const u8,
    width: usize,
    alignment: std.fmt.Alignment,
    fill: u8,
) anyerror!void {
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

pub fn printAddress(bw: *std.io.BufferedWriter, value: anytype) anyerror!void {
    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .pointer => |info| {
            try bw.writeAll(@typeName(info.child) ++ "@");
            if (info.size == .slice)
                try formatInt(@intFromPtr(value.ptr), 16, .lower, Options{}, bw)
            else
                try formatInt(@intFromPtr(value), 16, .lower, Options{}, bw);
            return;
        },
        .optional => |info| {
            if (@typeInfo(info.child) == .pointer) {
                try bw.writeAll(@typeName(info.child) ++ "@");
                try formatInt(@intFromPtr(value), 16, .lower, Options{}, bw);
                return;
            }
        },
        else => {},
    }

    @compileError("cannot format non-pointer type " ++ @typeName(T) ++ " with * specifier");
}
