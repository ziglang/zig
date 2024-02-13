pub const flate = @import("flate.zig");
pub const gzip = @import("gzip.zig");
pub const zlib = @import("zlib.zig");

test "flate" {
    _ = @import("deflate.zig");
    _ = @import("inflate.zig");
}

test "flate public interface" {
    const plain_data = [_]u8{ 'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a };

    // deflate final stored block, header + plain (stored) data
    const deflate_block = [_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
    } ++ plain_data;

    // gzip header/footer + deflate block
    const gzip_data =
        [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 } ++ // gzip header (10 bytes)
        deflate_block ++
        [_]u8{ 0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00 }; // gzip footer checksum (4 byte), size (4 bytes)

    // zlib header/footer + deflate block
    const zlib_data = [_]u8{ 0x78, 0b10_0_11100 } ++ // zlib header (2 bytes)}
        deflate_block ++
        [_]u8{ 0x1c, 0xf2, 0x04, 0x47 }; // zlib footer: checksum

    try testInterface(gzip, &gzip_data, &plain_data);
    try testInterface(zlib, &zlib_data, &plain_data);
    try testInterface(flate, &deflate_block, &plain_data);
}

fn testInterface(comptime pkg: type, gzip_data: []const u8, plain_data: []const u8) !void {
    const std = @import("std");
    const testing = std.testing;
    const fixedBufferStream = std.io.fixedBufferStream;

    var buffer1: [64]u8 = undefined;
    var buffer2: [64]u8 = undefined;

    var compressed = fixedBufferStream(&buffer1);
    var plain = fixedBufferStream(&buffer2);

    // decompress
    {
        var in = fixedBufferStream(gzip_data);
        try pkg.decompress(in.reader(), plain.writer());
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }
    plain.reset();
    compressed.reset();

    // compress/decompress
    {
        var in = fixedBufferStream(plain_data);
        try pkg.compress(in.reader(), compressed.writer(), .{});
        compressed.reset();
        try pkg.decompress(compressed.reader(), plain.writer());
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }
    plain.reset();
    compressed.reset();

    // compressor/decompressor
    {
        var in = fixedBufferStream(plain_data);
        var cmp = try pkg.compressor(compressed.writer(), .{});
        try cmp.compress(in.reader());
        try cmp.finish();

        compressed.reset();
        var dcp = pkg.decompressor(compressed.reader());
        try dcp.decompress(plain.writer());
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }
    plain.reset();
    compressed.reset();

    // huffman
    {
        // huffman compress/decompress
        {
            var in = fixedBufferStream(plain_data);
            try pkg.huffman.compress(in.reader(), compressed.writer());
            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
        plain.reset();
        compressed.reset();

        // huffman compressor/decompressor
        {
            var in = fixedBufferStream(plain_data);
            var cmp = try pkg.huffman.compressor(compressed.writer());
            try cmp.compress(in.reader());
            try cmp.finish();

            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
    }
    plain.reset();
    compressed.reset();

    // store
    {
        // store compress/decompress
        {
            var in = fixedBufferStream(plain_data);
            try pkg.store.compress(in.reader(), compressed.writer());
            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
        plain.reset();
        compressed.reset();

        // store compressor/decompressor
        {
            var in = fixedBufferStream(plain_data);
            var cmp = try pkg.store.compressor(compressed.writer());
            try cmp.compress(in.reader());
            try cmp.finish();

            compressed.reset();
            try pkg.decompress(compressed.reader(), plain.writer());
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
    }
}
