const std = @import("std.zig");

pub const deflate = @import("compress/deflate.zig");
pub const gzip = @import("compress/gzip.zig");
pub const zlib = @import("compress/zlib.zig");

test {
    if (@import("builtin").zig_backend != .stage1) return error.SkipZigTest;
    _ = deflate;
    _ = gzip;
    _ = zlib;
}
