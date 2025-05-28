const std = @import("../std.zig");
const assert = std.debug.assert;
const Writer = @This();
const Limit = std.io.Limit;
const File = std.fs.File;

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
        file_reader: *File.Reader,
        /// Maximum amount of bytes to read from the file. Implementations may
        /// assume that the file size does not exceed this amount.
        ///
        /// `headers_and_trailers` do not count towards this limit.
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

pub const FileError = error{
    /// Detailed diagnostics are found on the `File.Reader` struct.
    ReadFailed,
    /// See the `Writer` implementation for detailed diagnostics.
    WriteFailed,
    /// Indicates the caller should do its own file reading; the callee cannot
    /// offer a more efficient implementation.
    Unimplemented,
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
    file_reader: *File.Reader,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) FileError!usize {
    return w.vtable.writeFile(w.context, file_reader, limit, headers_and_trailers, headers_len);
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
    file_reader: *File.Reader,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) FileError!usize {
    _ = context;
    _ = file_reader;
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

pub fn discardingWriteSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) Error!usize {
    _ = context;
    const headers = data[0 .. data.len - 1];
    const pattern = data[headers.len..];
    var written: usize = pattern.len * splat;
    for (headers) |bytes| written += bytes.len;
    return written;
}

pub fn discardingWriteFile(
    context: ?*anyopaque,
    file_reader: *std.fs.File.Reader,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) Writer.FileError!usize {
    _ = context;
    if (file_reader.getSize()) |size| {
        const remaining = size - file_reader.pos;
        const seek_amt = limit.minInt(remaining);
        // Error is observable on `file_reader` instance, and is safe to ignore
        // depending on the caller's needs. Caller can make that decision.
        file_reader.seekForward(seek_amt) catch {};
        var n: usize = seek_amt;
        for (headers_and_trailers[0..headers_len]) |bytes| n += bytes.len;
        if (seek_amt == remaining) {
            // Since we made it all the way through the file, the trailers are
            // also included.
            for (headers_and_trailers[headers_len..]) |bytes| n += bytes.len;
        }
        return n;
    } else |_| {
        // Error is observable on `file_reader` instance, and it is better to
        // treat the file as a pipe.
        return error.Unimplemented;
    }
}

pub const discarding: Writer = .{
    .context = undefined,
    .vtable = &.{
        .writeSplat = discardingWriteSplat,
        .writeFile = discardingWriteFile,
    },
};

/// For use when the `Writer` implementation can cannot offer a more efficient
/// implementation than a basic read/write loop on the file.
pub fn unimplementedWriteFile(
    context: ?*anyopaque,
    file_reader: *File.Reader,
    limit: Limit,
    headers_and_trailers: []const []const u8,
    headers_len: usize,
) FileError!usize {
    _ = context;
    _ = file_reader;
    _ = limit;
    _ = headers_and_trailers;
    _ = headers_len;
    return error.Unimplemented;
}

/// Provides a `Writer` implementation based on calling `Hasher.update`, sending
/// all data also to an underlying `std.io.BufferedWriter`.
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
        out: *std.io.BufferedWriter,
        hasher: Hasher,

        pub fn writable(this: *@This(), buffer: []u8) std.io.BufferedWriter {
            return .{
                .unbuffered_writer = .{
                    .context = this,
                    .vtable = &.{
                        .writeSplat = @This().writeSplat,
                        .writeFile = Writer.unimplementedWriteFile,
                    },
                },
                .buffer = buffer,
            };
        }

        fn writeSplat(context: ?*anyopaque, data: []const []const u8, splat: usize) Writer.Error!usize {
            const this: *@This() = @alignCast(@ptrCast(context));
            const n = try this.out.writeSplat(data, splat);
            const short_data = data[0 .. data.len - @intFromBool(splat == 0)];
            var remaining: usize = n;
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
            const last = data[data.len - 1];
            assert(remaining == remaining_splat * last.len);
            switch (last.len) {
                0 => {
                    assert(remaining == 0);
                    return n;
                },
                1 => {
                    var buffer: [64]u8 = undefined;
                    @memset(&buffer, last[0]);
                    while (remaining > 0) {
                        const update_len = @min(remaining, buffer.len);
                        this.hasher.update(buffer[0..update_len]);
                        remaining -= update_len;
                    }
                    return n;
                },
                else => {},
            }
            while (remaining > 0) {
                const update_len = @min(remaining, last.len);
                this.hasher.update(last[0..update_len]);
                remaining -= update_len;
            }
            return n;
        }
    };
}
