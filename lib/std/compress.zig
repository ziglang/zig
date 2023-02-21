const std = @import("std.zig");

pub const deflate = @import("compress/deflate.zig");
pub const gzip = @import("compress/gzip.zig");
pub const lzma = @import("compress/lzma.zig");
pub const lzma2 = @import("compress/lzma2.zig");
pub const xz = @import("compress/xz.zig");
pub const zlib = @import("compress/zlib.zig");
pub const zstd = @import("compress/zstandard.zig");

pub fn HashedReader(
    comptime ReaderType: anytype,
    comptime HasherType: anytype,
) type {
    return struct {
        child_reader: ReaderType,
        hasher: HasherType,

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.Reader(*@This(), Error, read);

        pub fn read(self: *@This(), buf: []u8) Error!usize {
            const amt = try self.child_reader.read(buf);
            self.hasher.update(buf);
            return amt;
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

test {
    _ = deflate;
    _ = gzip;
    _ = lzma;
    _ = lzma2;
    _ = xz;
    _ = zlib;
    _ = zstd;
}
