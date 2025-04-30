const std = @import("../std.zig");
const assert = std.debug.assert;
const Writer = @This();

pub const Null = @import("Writer/Null.zig");

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
    /// of stream via `error.WriteFailed`.
    writeSplat: *const fn (ctx: ?*anyopaque, data: []const []const u8, splat: usize) Error!usize,

    /// Writes contents from an open file. `headers` are written first, then `len`
    /// bytes of `file` starting from `offset`, then `trailers`.
    ///
    /// Number of bytes actually written is returned, which may lie within
    /// headers, the file, trailers, or anywhere in between.
    ///
    /// Number of bytes returned may be zero, which does not mean
    /// end-of-stream. A subsequent call may return nonzero, or may signal end
    /// of stream via `error.WriteFailed`.
    ///
    /// If `error.Unimplemented` is returned, the caller should do its own
    /// reads from the file. The callee indicates it cannot offer a more
    /// efficient implementation.
    writeFile: *const fn (
        ctx: ?*anyopaque,
        file: std.fs.File,
        /// If this is `Offset.none`, `file` will be streamed, affecting the
        /// seek position. Otherwise, it will be read positionally without
        /// affecting the seek position. `error.Unseekable` is only possible
        /// when reading positionally.
        ///
        /// An offset past the end of the file is treated the same as an offset
        /// equal to the end of the file.
        offset: Offset,
        /// Maximum amount of bytes to read from the file. Implementations may
        /// assume that the file size does not exceed this amount.
        limit: Limit,
        /// Headers and trailers must be passed together so that in case `len` is
        /// zero, they can be forwarded directly to `VTable.writeVec`.
        headers_and_trailers: []const []const u8,
        headers_len: usize,
    ) FileError!usize,
};

pub const Error = error{
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
};

pub const FileError = std.fs.File.PReadError || error{
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// Indicates the caller should do its own file reading; the callee cannot
    /// offer a more efficient implementation.
    Unimplemented,
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

pub fn writeVec(w: Writer, data: []const []const u8) Error!usize {
    assert(data.len > 0);
    return w.vtable.writeSplat(w.context, data, 1);
}

pub fn writeSplat(w: Writer, data: []const []const u8, splat: usize) Error!usize {
    assert(data.len > 0);
    return w.vtable.writeSplat(w.context, data, splat);
}

pub fn writeFile(
    w: Writer,
    file: std.fs.File,
    offset: Offset,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) FileError!usize {
    return w.vtable.writeFile(w.context, file, offset, limit, headers_and_trailers, headers_len);
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

pub fn failingWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) Error!usize {
    _ = context;
    _ = data;
    _ = splat;
    return error.WriteFailed;
}

pub fn failingWriteFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: std.io.Writer.Offset,
    limit: std.io.Writer.Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) Error!usize {
    _ = context;
    _ = file;
    _ = offset;
    _ = limit;
    _ = headers_and_trailers;
    _ = headers_len;
    return error.WriteFailed;
}

pub const failing: Writer = .{
    .context = undefined,
    .vtable = &.{
        .writeSplat = failingWriteSplat,
        .writeFile = failingWriteFile,
    },
};

pub fn unimplementedWriteFile(
    context: ?*anyopaque,
    file: std.fs.File,
    offset: std.io.Writer.Offset,
    limit: std.io.Writer.Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) Error!usize {
    _ = context;
    _ = file;
    _ = offset;
    _ = limit;
    _ = headers_and_trailers;
    _ = headers_len;
    return error.Unimplemented;
}

test {
    _ = Null;
}
