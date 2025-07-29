//! Compression algorithms.

pub const flate = @import("compress/flate.zig");
pub const gzip = @import("compress/gzip.zig");
pub const zlib = @import("compress/zlib.zig");
pub const lzma = @import("compress/lzma.zig");
pub const lzma2 = @import("compress/lzma2.zig");
pub const xz = @import("compress/xz.zig");
pub const zstd = @import("compress/zstd.zig");

test {
    _ = flate;
    _ = lzma;
    _ = lzma2;
    _ = xz;
    _ = zstd;
    _ = gzip;
    _ = zlib;
}
