const std = @import("../std.zig");
const assert = std.debug.assert;
const Writer = @This();

context: *anyopaque,
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
    writeSplat: *const fn (ctx: *anyopaque, data: []const []const u8, splat: usize) anyerror!usize,

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
        ctx: *anyopaque,
        file: std.fs.File,
        offset: Offset,
        /// When zero, it means copy until the end of the file is reached.
        len: FileLen,
        /// Headers and trailers must be passed together so that in case `len` is
        /// zero, they can be forwarded directly to `VTable.writev`.
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) anyerror!usize,
};

pub const Offset = enum(u64) {
    none = std.math.maxInt(u64),
    _,

    pub fn init(integer: u64) Offset {
        const result: Offset = @enumFromInt(integer);
        assert(result != .none);
        return result;
    }
};

pub const FileLen = enum(u64) {
    zero = 0,
    entire_file = std.math.maxInt(u64),
    _,

    pub fn init(integer: u64) FileLen {
        const result: FileLen = @enumFromInt(integer);
        assert(result != .entire_file);
        return result;
    }

    pub fn int(len: FileLen) u64 {
        return @intFromEnum(len);
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
    offset: u64,
    len: FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    return w.vtable.writeFile(w.context, file, offset, len, headers_and_trailers, headers_len);
}

pub fn unimplemented_writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: FileLen,
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

pub fn buffered(w: Writer, buffer: []u8) std.io.BufferedWriter {
    return .{
        .buffer = .initBuffer(buffer),
        .unbuffered_writer = w,
    };
}

pub fn unbuffered(w: Writer) std.io.BufferedWriter {
    return buffered(w, &.{});
}
