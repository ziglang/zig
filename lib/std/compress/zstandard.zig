const std = @import("std");

pub const decompress = @import("zstandard/decompress.zig");
pub usingnamespace @import("zstandard/types.zig");

test "decompression" {
    const uncompressed = @embedFile("testdata/rfc8478.txt");
    const compressed3 = @embedFile("testdata/rfc8478.txt.zst.3");
    const compressed19 = @embedFile("testdata/rfc8478.txt.zst.19");

    var buffer = try std.testing.allocator.alloc(u8, uncompressed.len);
    defer std.testing.allocator.free(buffer);

    const res3 = try decompress.decodeFrame(buffer, compressed3, true);
    try std.testing.expectEqual(compressed3.len, res3.read_count);
    try std.testing.expectEqual(uncompressed.len, res3.write_count);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);

    const res19 = try decompress.decodeFrame(buffer, compressed19, true);
    try std.testing.expectEqual(compressed19.len, res19.read_count);
    try std.testing.expectEqual(uncompressed.len, res19.write_count);
    try std.testing.expectEqualSlices(u8, uncompressed, buffer);
}
