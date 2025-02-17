const std = @import("../std.zig");
const BufferedWriter = @This();
const assert = std.debug.assert;
const native_endian = @import("builtin").target.cpu.arch.endian();
const Writer = std.io.Writer;
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

/// Although `BufferedWriter` can easily satisfy the `Writer` interface, it's
/// generally more practical to pass a `BufferedWriter` instance itself around,
/// since it will result in fewer calls across vtable boundaries.
pub fn writer(bw: *BufferedWriter) Writer {
    return .{
        .context = bw,
        .vtable = &.{
            .writeSplat = passthru_writeSplat,
            .writeFile = passthru_writeFile,
        },
    };
}

const fixed_vtable: Writer.VTable = .{
    .writeSplat = fixed_writeSplat,
    .writeFile = fixed_writeFile,
};

/// Replaces the `BufferedWriter` with a new one that writes to `buffer` and
/// returns `error.NoSpaceLeft` when it is full.
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
}

pub fn flush(bw: *BufferedWriter) anyerror!void {
    const send_buffer = bw.buffer[0..bw.end];
    try bw.unbuffered_writer.writeAll(send_buffer);
    bw.end = 0;
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `Writer.VTable.writev`.
pub fn writevAll(bw: *BufferedWriter, data: [][]const u8) anyerror!void {
    var i: usize = 0;
    while (true) {
        var n = try passthru_writeSplat(bw, data[i..], 1);
        while (n >= data[i].len) {
            n -= data[i].len;
            i += 1;
            if (i >= data.len) return;
        }
        data[i] = data[i][n..];
    }
}

pub fn writeSplat(bw: *BufferedWriter, data: []const []const u8, splat: usize) anyerror!usize {
    return passthru_writeSplat(bw, data, splat);
}

fn passthru_writeSplat(context: *anyopaque, data: []const []const u8, splat: usize) anyerror!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    const buffer = bw.buffer;
    const start_end = bw.end;

    var buffers: [max_buffers_len][]const u8 = undefined;
    var end = bw.end;
    for (data, 0..) |bytes, i| {
        const new_end = end + bytes.len;
        if (new_end <= buffer.len) {
            @branchHint(.likely);
            @memcpy(buffer[end..new_end], bytes);
            end = new_end;
            continue;
        }
        if (end == 0) return bw.unbuffered_writer.writeSplat(data, splat);
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
                return end - start_end;
            }
            bw.end = 0;
            return n - start_end;
        }
        const n = try bw.unbuffered_writer.writeSplat(send_buffers, 1);
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

    const pattern = data[data.len - 1];

    if (splat == 0) {
        @branchHint(.unlikely);
        // It was added in the loop above; undo it here.
        end -= pattern.len;
        bw.end = end;
        return end - start_end;
    }

    const remaining_splat = splat - 1;

    switch (pattern.len) {
        0 => {
            bw.end = end;
            return end - start_end;
        },
        1 => {
            const new_end = end + remaining_splat;
            if (new_end <= buffer.len) {
                @branchHint(.likely);
                @memset(buffer[end..new_end], pattern[0]);
                bw.end = new_end;
                return new_end - start_end;
            }
            buffers[0] = buffer[0..end];
            buffers[1] = pattern;
            const n = try bw.unbuffered_writer.writeSplat(buffers[0..2], remaining_splat);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return end - start_end;
            }
            bw.end = 0;
            return n - start_end;
        },
        else => {
            const new_end = end + pattern.len * remaining_splat;
            if (new_end <= buffer.len) {
                @branchHint(.likely);
                while (end < new_end) : (end += pattern.len) {
                    @memcpy(buffer[end..][0..pattern.len], pattern);
                }
                bw.end = new_end;
                return new_end - start_end;
            }
            buffers[0] = buffer[0..end];
            buffers[1] = pattern;
            const n = try bw.unbuffered_writer.writeSplat(buffers[0..2], remaining_splat);
            if (n < end) {
                @branchHint(.unlikely);
                const remainder = buffer[n..end];
                std.mem.copyForwards(u8, buffer[0..remainder.len], remainder);
                bw.end = remainder.len;
                return end - start_end;
            }
            bw.end = 0;
            return n - start_end;
        },
    }
}

fn fixed_writev(context: *anyopaque, data: []const []const u8) anyerror!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    // When this function is called it means the buffer got full, so it's time
    // to return an error. However, we still need to make sure all of the
    // available buffer has been used.
    const first = data[0];
    const dest = bw.buffer[bw.end..];
    @memcpy(dest, first[0..dest.len]);
    return error.NoSpaceLeft;
}

/// When this function is called it means the buffer got full, so it's time
/// to return an error. However, we still need to make sure all of the
/// available buffer has been filled.
fn fixed_writeSplat(context: *anyopaque, data: []const []const u8, splat: usize) anyerror!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    for (data) |bytes| {
        const dest = bw.buffer[bw.end..];
        if (dest.len == 0) return error.NoSpaceLeft;
        const len = @min(bytes.len, dest.len);
        @memcpy(dest[0..len], bytes[0..len]);
        bw.end += len;
    }
    const pattern = data[data.len - 1];
    const dest = bw.buffer[bw.end..];
    switch (pattern.len) {
        0 => unreachable,
        1 => @memset(dest, pattern[0]),
        else => for (0..splat - 1) |i| @memcpy(dest[i * pattern.len ..][0..pattern.len], pattern),
    }
    return error.NoSpaceLeft;
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
    @memcpy(buffer[end..new_end], bytes);
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
    return passthru_writeSplat(bw, &.{&.{byte}}, n);
}

/// Writes the same slice many times, performing the underlying write call as
/// many times as necessary.
pub fn splatBytesAll(bw: *BufferedWriter, bytes: []const u8, splat: usize) anyerror!void {
    var remaining_bytes: usize = bytes.len * splat;
    remaining_bytes -= try splatBytes(bw, bytes, splat);
    while (remaining_bytes > 0) {
        const leftover = remaining_bytes % bytes.len;
        const buffers: [2][]const u8 = .{ bytes[bytes.len - leftover ..], bytes };
        remaining_bytes -= try splatBytes(bw, &buffers, splat);
    }
}

/// Writes the same slice many times, allowing short writes.
///
/// Does maximum of one underlying `Writer.VTable.writev`.
pub fn splatBytes(bw: *BufferedWriter, bytes: []const u8, n: usize) anyerror!usize {
    return passthru_writeSplat(bw, &.{bytes}, n);
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
    bw: *BufferedWriter,
    file: std.fs.File,
    offset: u64,
    len: Writer.VTable.FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    return passthru_writeFile(bw, file, offset, len, headers_and_trailers, headers_len);
}

fn passthru_writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: Writer.VTable.FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    const bw: *BufferedWriter = @alignCast(@ptrCast(context));
    const buffer = bw.buffer;
    if (buffer.len == 0) return bw.unbuffered_writer.writeFile(file, offset, len, headers_and_trailers, headers_len);
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
    if (options.len == .zero) return writevAll(bw, headers_and_trailers);
    if (options.len == .entire_file) {
        // When reading the whole file, we cannot include the trailers in the
        // call that reads from the file handle, because we have no way to
        // determine whether a partial write is past the end of the file or
        // not.
        var i: usize = 0;
        var offset = options.offset;
        while (true) {
            var n = try writeFile(bw, file, offset, .entire_file, headers[i..], headers.len - i);
            while (i < headers.len and n >= headers[i].len) {
                n -= headers[i].len;
                i += 1;
            }
            if (i < headers.len) {
                headers[i] = headers[i][n..];
                continue;
            }
            if (n == 0) break;
            offset += n;
        }
    } else {
        var len = options.len.int();
        var i: usize = 0;
        var offset = options.offset;
        while (true) {
            var n = try writeFile(bw, file, offset, .init(len), headers_and_trailers[i..], headers.len - i);
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
                return writevAll(bw, headers_and_trailers[i..]);
            }
            offset += n;
            len -= n;
        }
    }
}

fn fixed_writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: Writer.VTable.FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    _ = context;
    _ = file;
    _ = offset;
    _ = len;
    _ = headers_and_trailers;
    _ = headers_len;
    return error.Unimplemented;
}

pub fn alignBuffer(
    bw: *BufferedWriter,
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

pub fn alignBufferOptions(bw: *BufferedWriter, buffer: []const u8, options: std.fmt.Options) anyerror!void {
    return alignBuffer(bw, buffer, options.width orelse buffer.len, options.alignment, options.fill);
}

pub fn printAddress(bw: *BufferedWriter, value: anytype) anyerror!void {
    const T = @TypeOf(value);

    switch (@typeInfo(T)) {
        .pointer => |info| {
            try bw.writeAll(@typeName(info.child) ++ "@");
            if (info.size == .slice)
                try printIntOptions(bw, @intFromPtr(value.ptr), 16, .lower, .{})
            else
                try printIntOptions(bw, @intFromPtr(value), 16, .lower, .{});
            return;
        },
        .optional => |info| {
            if (@typeInfo(info.child) == .pointer) {
                try bw.writeAll(@typeName(info.child) ++ "@");
                try printIntOptions(bw, @intFromPtr(value), 16, .lower, .{});
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
) anyerror!void {
    const T = @TypeOf(value);
    const actual_fmt = comptime if (std.mem.eql(u8, fmt, ANY))
        defaultFormatString(T)
    else if (fmt.len != 0 and (fmt[0] == '?' or fmt[0] == '!')) switch (@typeInfo(T)) {
        .optional, .error_union => fmt,
        else => stripOptionalOrErrorUnionSpec(fmt),
    } else fmt;

    if (comptime std.mem.eql(u8, actual_fmt, "*")) {
        return printAddress(bw, value);
    }

    if (std.meta.hasMethod(T, "format")) {
        if (fmt.len > 0 and fmt[0] == 'f') {
            return value.format(fmt[1..], options, bw);
        } else {
            //@deprecated();
            // After 0.14.0 is tagged, uncomment this next line:
            //@compileError("ambiguous format string; specify {f} to call format method, or {any} to skip it");
            //and then delete the `hasMethod` condition
            return value.format(fmt, options, bw);
        }
    }

    switch (@typeInfo(T)) {
        .float, .comptime_float => return printFloat(bw, actual_fmt, options, value),
        .int, .comptime_int => return printInt(bw, actual_fmt, options, value),
        .bool => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return alignBufferOptions(bw, if (value) "true" else "false", options);
        },
        .void => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return alignBufferOptions(bw, "void", options);
        },
        .optional => {
            if (actual_fmt.len == 0 or actual_fmt[0] != '?')
                @compileError("cannot print optional without a specifier (i.e. {?} or {any})");
            const remaining_fmt = comptime stripOptionalOrErrorUnionSpec(actual_fmt);
            if (value) |payload| {
                return printValue(bw, remaining_fmt, options, payload, max_depth);
            } else {
                return alignBufferOptions(bw, "null", options);
            }
        },
        .error_union => {
            if (actual_fmt.len == 0 or actual_fmt[0] != '!')
                @compileError("cannot format error union without a specifier (i.e. {!} or {any})");
            const remaining_fmt = comptime stripOptionalOrErrorUnionSpec(actual_fmt);
            if (value) |payload| {
                return printValue(bw, remaining_fmt, options, payload, max_depth);
            } else |err| {
                return printValue(bw, "", options, err, max_depth);
            }
        },
        .error_set => {
            if (actual_fmt.len > 0 and actual_fmt.len[0] == 's') {
                return bw.writeAll(@errorName(value));
            } else if (actual_fmt.len != 0) {
                invalidFmtError(fmt, value);
            } else {
                try bw.writeAll("error.");
                return bw.writeAll(@errorName(value));
            }
        },
        .@"enum" => |enumInfo| {
            try bw.writeAll(@typeName(T));
            if (enumInfo.is_exhaustive) {
                if (actual_fmt.len != 0) invalidFmtError(fmt, value);
                try bw.writeAll(".");
                try bw.writeAll(@tagName(value));
                return;
            }

            // Use @tagName only if value is one of known fields
            @setEvalBranchQuota(3 * enumInfo.fields.len);
            inline for (enumInfo.fields) |enumField| {
                if (@intFromEnum(value) == enumField.value) {
                    try bw.writeAll(".");
                    try bw.writeAll(@tagName(value));
                    return;
                }
            }

            try bw.writeByte('(');
            try printValue(bw, actual_fmt, options, @intFromEnum(value), max_depth);
            try bw.writeByte(')');
        },
        .@"union" => |info| {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            try bw.writeAll(@typeName(T));
            if (max_depth == 0) {
                return bw.writeAll("{ ... }");
            }
            if (info.tag_type) |UnionTagType| {
                try bw.writeAll("{ .");
                try bw.writeAll(@tagName(@as(UnionTagType, value)));
                try bw.writeAll(" = ");
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        try printValue(bw, ANY, options, @field(value, u_field.name), max_depth - 1);
                    }
                }
                try bw.writeAll(" }");
            } else {
                try bw.writeByte('@');
                try bw.printIntOptions(@intFromPtr(&value), 16, .lower);
            }
        },
        .@"struct" => |info| {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            if (info.is_tuple) {
                // Skip the type and field names when formatting tuples.
                if (max_depth == 0) {
                    return bw.writeAll("{ ... }");
                }
                try bw.writeAll("{");
                inline for (info.fields, 0..) |f, i| {
                    if (i == 0) {
                        try bw.writeAll(" ");
                    } else {
                        try bw.writeAll(", ");
                    }
                    try printValue(bw, ANY, options, @field(value, f.name), max_depth - 1);
                }
                return bw.writeAll(" }");
            }
            try bw.writeAll(@typeName(T));
            if (max_depth == 0) {
                return bw.writeAll("{ ... }");
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
                try printValue(bw, ANY, options, @field(value, f.name), max_depth - 1);
            }
            try bw.writeAll(" }");
        },
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array, .@"enum", .@"union", .@"struct" => {
                    return printValue(bw, actual_fmt, options, value.*, max_depth);
                },
                else => {
                    const buffers: [2][]const u8 = .{ @typeName(ptr_info.child), "@" };
                    try writevAll(bw, &buffers);
                    try printIntOptions(bw, @intFromPtr(value), 16, .lower);
                },
            },
            .many, .c => {
                if (actual_fmt.len == 0)
                    @compileError("cannot format pointer without a specifier (i.e. {s} or {*})");
                if (ptr_info.sentinel() != null) {
                    return printValue(bw, actual_fmt, options, std.mem.span(value), max_depth);
                }
                if (actual_fmt[0] == 's' and ptr_info.child == u8) {
                    return alignBufferOptions(bw, std.mem.span(value), options);
                }
                invalidFmtError(fmt, value);
            },
            .slice => {
                if (actual_fmt.len == 0)
                    @compileError("cannot format slice without a specifier (i.e. {s}, {x}, or {any})");
                if (max_depth == 0) {
                    return bw.writeAll("{ ... }");
                }
                if (ptr_info.child == u8) {
                    if (actual_fmt[0] == 's') {
                        return alignBufferOptions(bw, value, options);
                    } else if (actual_fmt[0] == 'x') {
                        return printHex(bw, value, .lower);
                    } else if (actual_fmt[0] == 'X') {
                        return printHex(bw, value, .upper);
                    }
                }
                try bw.writeAll("{ ");
                for (value, 0..) |elem, i| {
                    try printValue(bw, actual_fmt, options, elem, max_depth - 1);
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
                    return alignBufferOptions(bw, &value, options);
                } else if (actual_fmt[0] == 'x') {
                    return printHex(bw, &value, .lower);
                } else if (actual_fmt[0] == 'X') {
                    return printHex(bw, &value, .upper);
                }
            }
            try bw.writeAll("{ ");
            for (value, 0..) |elem, i| {
                try printValue(bw, actual_fmt, options, elem, max_depth - 1);
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
                try printValue(bw, actual_fmt, options, value[i], max_depth - 1);
                if (i < info.len - 1) {
                    try bw.writeAll(", ");
                }
            }
            try bw.writeAll(" }");
        },
        .@"fn" => @compileError("unable to format function body type, use '*const " ++ @typeName(T) ++ "' for a function pointer type"),
        .type => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return alignBufferOptions(bw, @typeName(value), options);
        },
        .enum_literal => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            const buffer = [_]u8{'.'} ++ @tagName(value);
            return alignBufferOptions(bw, buffer, options);
        },
        .null => {
            if (actual_fmt.len != 0) invalidFmtError(fmt, value);
            return alignBufferOptions(bw, "null", options);
        },
        else => @compileError("unable to format type '" ++ @typeName(T) ++ "'"),
    }
}

pub fn printInt(
    bw: *BufferedWriter,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
) anyerror!void {
    comptime var base = 10;
    comptime var case: std.fmt.Case = .lower;

    const int_value = if (@TypeOf(value) == comptime_int) blk: {
        const Int = std.math.IntFittingRange(value, value);
        break :blk @as(Int, value);
    } else value;

    if (fmt.len == 0 or comptime std.mem.eql(u8, fmt, "d")) {
        base = 10;
        case = .lower;
    } else if (comptime std.mem.eql(u8, fmt, "c")) {
        if (@typeInfo(@TypeOf(int_value)).int.bits <= 8) {
            return printAsciiChar(bw, @as(u8, int_value), options);
        } else {
            @compileError("cannot print integer that is larger than 8 bits as an ASCII character");
        }
    } else if (comptime std.mem.eql(u8, fmt, "u")) {
        if (@typeInfo(@TypeOf(int_value)).int.bits <= 21) {
            return printUnicodeCodepoint(bw, @as(u21, int_value), options);
        } else {
            @compileError("cannot print integer that is larger than 21 bits as an UTF-8 sequence");
        }
    } else if (comptime std.mem.eql(u8, fmt, "b")) {
        base = 2;
        case = .lower;
    } else if (comptime std.mem.eql(u8, fmt, "x")) {
        base = 16;
        case = .lower;
    } else if (comptime std.mem.eql(u8, fmt, "X")) {
        base = 16;
        case = .upper;
    } else if (comptime std.mem.eql(u8, fmt, "o")) {
        base = 8;
        case = .lower;
    } else {
        invalidFmtError(fmt, value);
    }

    return printIntOptions(bw, int_value, base, case, options);
}

pub fn printAsciiChar(bw: *BufferedWriter, c: u8, options: std.fmt.Options) anyerror!void {
    return alignBufferOptions(bw, @as(*const [1]u8, &c), options);
}

pub fn printAscii(bw: *BufferedWriter, bytes: []const u8, options: std.fmt.Options) anyerror!void {
    return alignBufferOptions(bw, bytes, options);
}

pub fn printUnicodeCodepoint(bw: *BufferedWriter, c: u21, options: std.fmt.Options) anyerror!void {
    var buf: [4]u8 = undefined;
    const len = try std.unicode.utf8Encode(c, &buf);
    return alignBufferOptions(bw, buf[0..len], options);
}

pub fn printIntOptions(
    bw: *BufferedWriter,
    value: anytype,
    base: u8,
    case: std.fmt.Case,
    options: std.fmt.Options,
) anyerror!void {
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

    return alignBufferOptions(bw, buf[index..], options);
}

pub fn printFloat(
    bw: *BufferedWriter,
    comptime fmt: []const u8,
    options: std.fmt.Options,
    value: anytype,
) anyerror!void {
    var buf: [std.fmt.float.bufferSize(.decimal, f64)]u8 = undefined;

    if (fmt.len > 1) invalidFmtError(fmt, value);
    switch (if (fmt.len == 0) 'e' else fmt[0]) {
        'e' => {
            const s = std.fmt.float.render(&buf, value, .{ .mode = .scientific, .precision = options.precision }) catch |err| switch (err) {
                error.BufferTooSmall => "(float)",
            };
            return alignBufferOptions(bw, s, options);
        },
        'd' => {
            const s = std.fmt.float.render(&buf, value, .{ .mode = .decimal, .precision = options.precision }) catch |err| switch (err) {
                error.BufferTooSmall => "(float)",
            };
            return alignBufferOptions(bw, s, options);
        },
        'x' => {
            var sub_bw: BufferedWriter = undefined;
            sub_bw.initFixed(&buf);
            sub_bw.printFloatHexadecimal(value, options.precision) catch unreachable;
            return alignBufferOptions(bw, sub_bw.getWritten(), options);
        },
        else => invalidFmtError(fmt, value),
    }
}

pub fn printFloatHexadecimal(bw: *BufferedWriter, value: anytype, opt_precision: ?usize) anyerror!void {
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
    try printIntOptions(bw, exponent - exponent_bias, 10, .lower, .{});
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
    units: ByteSizeUnits,
    options: std.fmt.Options,
) anyerror!void {
    if (value == 0) return alignBufferOptions(bw, "0B", options);
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
        else => unreachable,
    };
    const new_value = std.math.lossyCast(f64, value) / std.math.pow(f64, std.math.lossyCast(f64, base), std.math.lossyCast(f64, magnitude));
    const suffix = switch (units) {
        .decimal => mags_si[magnitude],
        .binary => mags_iec[magnitude],
        else => unreachable,
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
        else => unreachable,
    }

    return alignBufferOptions(buf[0..i], options, bw);
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

pub fn printDurationSigned(bw: *BufferedWriter, ns: i64) anyerror!void {
    if (ns < 0) try bw.writeByte('-');
    const unsigned_ns: u64 = @intCast(if (ns == std.math.minInt(i64)) ns + 1 else ns);
    return printDurationUnsigned(bw, unsigned_ns);
}

pub fn printDurationUnsigned(bw: *BufferedWriter, ns: u64) anyerror!void {
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
                assert(printInt(decimal_buf[1..], frac, 10, .lower, .{ .fill = '0', .width = 3 }) == 3);
                var end: usize = 4;
                while (end > 1) : (end -= 1) {
                    if (decimal_buf[end - 1] != '0') break;
                }
                try bw.writeAll(decimal_buf[0..end]);
            }
            return bw.writeAll(unit.sep);
        }
    }

    try printIntOptions(bw, ns_remaining, 10, .lower, .{});
    try bw.writeAll("ns");
}

/// Writes number of nanoseconds according to its signed magnitude:
/// `[#y][#w][#d][#h][#m]#[.###][n|u|m]s`
/// `nanoseconds` must be an integer that coerces into `u64` or `i64`.
pub fn printDuration(bw: *BufferedWriter, nanoseconds: anytype, options: std.fmt.Options) anyerror!void {
    // worst case: "-XXXyXXwXXdXXhXXmXX.XXXs".len = 24
    var buf: [24]u8 = undefined;
    var sub_bw: BufferedWriter = undefined;
    sub_bw.initFixed(&buf);
    switch (@typeInfo(@TypeOf(nanoseconds)).int.signedness) {
        .signed => sub_bw.printDurationSigned(nanoseconds, options) catch unreachable,
        .unsigned => sub_bw.printDurationUnsigned(nanoseconds, options) catch unreachable,
    }
    return alignBufferOptions(bw, sub_bw.getWritten(), options);
}

pub fn printHex(bw: *BufferedWriter, bytes: []const u8, case: std.fmt.Case) anyerror!void {
    const charset = switch (case) {
        .upper => "0123456789ABCDEF",
        .lower => "0123456789abcdef",
    };
    for (bytes) |c| {
        try writeByte(bw, charset[c >> 4]);
        try writeByte(bw, charset[c & 15]);
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
        ) anyerror!void {
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
