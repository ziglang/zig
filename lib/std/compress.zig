//! Compression algorithms.

const std = @import("std.zig");

pub const flate = @import("compress/flate.zig");
pub const gzip = @import("compress/gzip.zig");
pub const zlib = @import("compress/zlib.zig");
pub const lzma = @import("compress/lzma.zig");
pub const lzma2 = @import("compress/lzma2.zig");
pub const xz = @import("compress/xz.zig");
pub const zstd = @import("compress/zstandard.zig");

pub fn HashedReader(
    comptime ReaderType: anytype,
    comptime HasherType: anytype,
) type {
    return struct {
        child_reader: ReaderType,
        hasher: HasherType,

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.Reader(*@This(), Error, readv);

        pub fn readv(self: *@This(), iov: []std.posix.iovec) Error!usize {
            const n_read = try self.child_reader.readv(iov);
            var hashed_amt: usize = 0;
            for (iov) |v| {
                const to_hash = @min(n_read - hashed_amt, v.len);
                if (to_hash == 0) break;
                self.hasher.update(v.ptr[0..to_hash]);
                hashed_amt += to_hash;
            }
            return n_read;
        }

        pub fn reader(self: *@This()) Reader {
            return .{ .context = self };
        }
    };
}

pub fn hashedReader(
    reader: anytype,
    hasher: anytype,
) HashedReader(@TypeOf(reader), @TypeOf(hasher)) {
    return .{ .child_reader = reader, .hasher = hasher };
}

pub fn HashedWriter(
    comptime WriterType: anytype,
    comptime HasherType: anytype,
) type {
    return struct {
        child_writer: WriterType,
        hasher: HasherType,

        pub const Error = WriterType.Error;
        pub const Writer = std.io.Writer(*@This(), Error, write);

        pub fn write(self: *@This(), iov: []std.posix.iovec_const) Error!usize {
            const n_written = try self.child_writer.writev(iov);
            var hashed_amt: usize = 0;
            for (iov) |v| {
                const to_hash = @min(n_written - hashed_amt, v.len);
                if (to_hash == 0) break;
                self.hasher.update(v.ptr[0..to_hash]);
                hashed_amt += to_hash;
            }
            return n_written;
        }

        pub fn writer(self: *@This()) Writer {
            return .{ .context = self };
        }
    };
}

pub fn hashedWriter(
    writer: anytype,
    hasher: anytype,
) HashedWriter(@TypeOf(writer), @TypeOf(hasher)) {
    return .{ .child_writer = writer, .hasher = hasher };
}

test {
    _ = lzma;
    _ = lzma2;
    _ = xz;
    _ = zstd;
    _ = flate;
    _ = gzip;
    _ = zlib;
}
