const std = @import("std.zig");

pub const deflate = @import("compress/deflate.zig");
pub const gzip = @import("compress/gzip.zig");
pub const zlib = @import("compress/zlib.zig");

test {
    _ = gzip;
    _ = zlib;
}
