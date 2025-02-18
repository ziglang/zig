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
    writeSplat: *const fn (context: *anyopaque, data: []const []const u8, splat: usize) anyerror!usize,

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
        context: *anyopaque,
        file: std.fs.File,
        offset: u64,
        /// When zero, it means copy until the end of the file is reached.
        len: FileLen,
        /// Headers and trailers must be passed together so that in case `len` is
        /// zero, they can be forwarded directly to `VTable.writev`.
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) anyerror!usize,

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
    len: VTable.FileLen,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) anyerror!usize {
    return w.vtable.writeFile(w.context, file, offset, len, headers_and_trailers, headers_len);
}

pub fn unimplemented_writeFile(
    context: *anyopaque,
    file: std.fs.File,
    offset: u64,
    len: VTable.FileLen,
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

pub fn write(w: Writer, bytes: []const u8) anyerror!usize {
    const single: [1][]const u8 = .{bytes};
    return w.vtable.writeSplat(w.context, &single, 1);
}

pub fn writeAll(w: Writer, bytes: []const u8) anyerror!void {
    var index: usize = 0;
    while (index < bytes.len) index += try w.vtable.writeSplat(w.context, &.{bytes[index..]}, 1);
}

/// The `data` parameter is mutable because this function needs to mutate the
/// fields in order to handle partial writes from `VTable.writev`.
pub fn writevAll(w: Writer, data: [][]const u8) anyerror!void {
    var i: usize = 0;
    while (true) {
        var n = try w.vtable.writeSplat(w.context, data[i..], 1);
        while (n >= data[i].len) {
            n -= data[i].len;
            i += 1;
            if (i >= data.len) return;
        }
        data[i] = data[i][n..];
    }
}

pub fn unbuffered(w: Writer) std.io.BufferedWriter {
    return .{
        .buffer = &.{},
        .unbuffered_writer = w,
    };
}
