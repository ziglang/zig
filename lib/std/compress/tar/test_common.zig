const std = @import("std");
/// testing helper for decompressing a .gz file. returns an io.fixedBufferStream
/// with the decompressed data.  caller owns the returned FixedBufferStream.buffer
pub fn decompressGz(
    comptime file_name: []const u8,
    alloc: std.mem.Allocator,
) !std.io.FixedBufferStream([]u8) {
    var fbs = std.io.fixedBufferStream(@embedFile(file_name));
    var decompressor = try std.compress.gzip.decompress(alloc, fbs.reader());
    defer decompressor.deinit();
    const decompressed = try decompressor.reader().readAllAlloc(alloc, 1024 * 32);
    return std.io.fixedBufferStream(decompressed);
}
