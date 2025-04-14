const std = @import("../std.zig");
const assert = std.debug.assert;
const Writer = @This();

context: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Each slice in `data` is written in order.
    ///
    /// `data.len` must be greater than zero, and the last element of `data` is
    /// special. It is repeated as necessary so that it is written `splat`
    /// number of times.
    ///
    /// Number of bytes actually written is returned.
    ///
    /// Number of bytes returned may be zero, which does not mean
    /// end-of-stream. A subsequent call may return nonzero, or may signal end
    /// of stream via an error.
    writeSplat: *const fn (ctx: ?*anyopaque, data: []const []const u8, splat: usize) anyerror!usize,

    /// Writes contents from an open file. `headers` are written first, then `len`
    /// bytes of `file` starting from `offset`, then `trailers`.
    ///
    /// Number of bytes actually written is returned, which may lie within
    /// headers, the file, trailers, or anywhere in between.
    ///
    /// Number of bytes returned may be zero, which does not mean
    /// end-of-stream. A subsequent call may return nonzero, or may signal end
    /// of stream via an error.
    writeFile: *const fn (
        ctx: ?*anyopaque,
        file: std.fs.File,
        /// If this is `none`, `file` will be streamed. Otherwise, it will be
        /// read positionally without affecting the seek position.
        offset: Offset,
        /// Maximum amount of bytes to read from the file.
        limit: Limit,
        /// Headers and trailers must be passed together so that in case `len` is
        /// zero, they can be forwarded directly to `VTable.writev`.
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) anyerror!usize,
};

pub const Limit = std.io.Reader.Limit;

pub const Offset = enum(u64) {
    zero = 0,
    /// Indicates to read the file as a stream.
    none = std.math.maxInt(u64),
    _,

    pub fn init(integer: u64) Offset {
        const result: Offset = @enumFromInt(integer);
        assert(result != .none);
        return result;
    }

    pub fn toInt(o: Offset) ?u64 {
        return if (o == .none) null else @intFromEnum(o);
    }

    pub fn advance(o: Offset, amount: u64) Offset {
        return switch (o) {
            .none => .none,
            else => .init(@intFromEnum(o) + amount),
        };
    }
};

pub fn writev(w: Writer, data: []const []const u8) anyerror!usize {
    return w.vtable.writeSplat(w.context, data, 1);
}

pub fn writeSplat(w: Writer, data: []const []const u8, splat: usize) anyerror!usize {
    return w.vtable.writeSplat(w.context, data, splat);
}

pub fn writeFile(
    w: Writer,
    file: std.fs.File,
    offset: Offset,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    return w.vtable.writeFile(w.context, file, offset, limit, headers_and_trailers, headers_len);
}

pub fn unimplemented_writeFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: Offset,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    _ = context;
    _ = file;
    _ = offset;
    _ = limit;
    _ = headers_and_trailers;
    _ = headers_len;
    return error.Unimplemented;
}

pub fn buffered(w: Writer, buffer: []u8) std.io.BufferedWriter {
    return .{
        .buffer = buffer,
        .unbuffered_writer = w,
    };
}

pub fn unbuffered(w: Writer) std.io.BufferedWriter {
    return w.buffered(&.{});
}

/// A `Writer` that discards all data.
pub const @"null": Writer = .{
    .context = undefined,
    .vtable = &.{
        .writeSplat = null_writeSplat,
        .writeFile = null_writeFile,
    },
};

fn null_writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) anyerror!usize {
    _ = context;
    const headers = data[0 .. data.len - 1];
    const pattern = data[headers.len..];
    var written: usize = pattern.len * splat;
    for (headers) |bytes| written += bytes.len;
    return written;
}

fn null_writeFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: Offset,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    _ = context;
    var n: usize = 0;
    if (offset == .none) {
        @panic("TODO seek the file forwards");
    }
    const limit_int = limit.toInt() orelse {
        const headers = headers_and_trailers[0..headers_len];
        for (headers) |bytes| n += bytes.len;
        if (offset.toInt()) |off| {
            const stat = try file.stat();
            n += stat.size - off;
            for (headers_and_trailers[headers_len..]) |bytes| n += bytes.len;
            return n;
        }
        @panic("TODO stream from file until eof, counting");
    };
    for (headers_and_trailers) |bytes| n += bytes.len;
    return limit_int + n;
}

test @"null" {
    try @"null".writeAll("yay");
}
