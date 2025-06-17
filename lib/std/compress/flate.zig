const builtin = @import("builtin");
const std = @import("../std.zig");
const testing = std.testing;
const Writer = std.io.Writer;

/// Container of the deflate bit stream body. Container adds header before
/// deflate bit stream and footer after. It can bi gzip, zlib or raw (no header,
/// no footer, raw bit stream).
///
/// Zlib format is defined in rfc 1950. Header has 2 bytes and footer 4 bytes
/// addler 32 checksum.
///
/// Gzip format is defined in rfc 1952. Header has 10+ bytes and footer 4 bytes
/// crc32 checksum and 4 bytes of uncompressed data length.
///
///
/// rfc 1950: https://datatracker.ietf.org/doc/html/rfc1950#page-4
/// rfc 1952: https://datatracker.ietf.org/doc/html/rfc1952#page-5
pub const Container = enum {
    raw, // no header or footer
    gzip, // gzip header and footer
    zlib, // zlib header and footer

    pub fn size(w: Container) usize {
        return headerSize(w) + footerSize(w);
    }

    pub fn headerSize(w: Container) usize {
        return header(w).len;
    }

    pub fn footerSize(w: Container) usize {
        return switch (w) {
            .gzip => 8,
            .zlib => 4,
            .raw => 0,
        };
    }

    pub const list = [_]Container{ .raw, .gzip, .zlib };

    pub const Error = error{
        BadGzipHeader,
        BadZlibHeader,
        WrongGzipChecksum,
        WrongGzipSize,
        WrongZlibChecksum,
    };

    pub fn header(container: Container) []const u8 {
        return switch (container) {
            // GZIP 10 byte header (https://datatracker.ietf.org/doc/html/rfc1952#page-5):
            //  - ID1 (IDentification 1), always 0x1f
            //  - ID2 (IDentification 2), always 0x8b
            //  - CM (Compression Method), always 8 = deflate
            //  - FLG (Flags), all set to 0
            //  - 4 bytes, MTIME (Modification time), not used, all set to zero
            //  - XFL (eXtra FLags), all set to zero
            //  - OS (Operating System), 03 = Unix
            .gzip => &[_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 },
            // ZLIB has a two-byte header (https://datatracker.ietf.org/doc/html/rfc1950#page-4):
            // 1st byte:
            //  - First four bits is the CINFO (compression info), which is 7 for the default deflate window size.
            //  - The next four bits is the CM (compression method), which is 8 for deflate.
            // 2nd byte:
            //  - Two bits is the FLEVEL (compression level). Values are: 0=fastest, 1=fast, 2=default, 3=best.
            //  - The next bit, FDICT, is set if a dictionary is given.
            //  - The final five FCHECK bits form a mod-31 checksum.
            //
            // CINFO = 7, CM = 8, FLEVEL = 0b10, FDICT = 0, FCHECK = 0b11100
            .zlib => &[_]u8{ 0x78, 0b10_0_11100 },
            .raw => &.{},
        };
    }

    pub const Hasher = union(Container) {
        raw: void,
        gzip: struct {
            crc: std.hash.Crc32 = .init(),
            count: usize = 0,
        },
        zlib: std.hash.Adler32,

        pub fn init(containter: Container) Hasher {
            return switch (containter) {
                .gzip => .{ .gzip = .{} },
                .zlib => .{ .zlib = .init() },
                .raw => .raw,
            };
        }

        pub fn container(h: Hasher) Container {
            return h;
        }

        pub fn update(h: *Hasher, buf: []const u8) void {
            switch (h.*) {
                .raw => {},
                .gzip => |*gzip| {
                    gzip.update(buf);
                    gzip.count += buf.len;
                },
                .zlib => |*zlib| {
                    zlib.update(buf);
                },
                inline .gzip, .zlib => |*x| x.update(buf),
            }
        }

        pub fn writeFooter(hasher: *Hasher, writer: *Writer) Writer.Error!void {
            var bits: [4]u8 = undefined;
            switch (hasher.*) {
                .gzip => |*gzip| {
                    // GZIP 8 bytes footer
                    //  - 4 bytes, CRC32 (CRC-32)
                    //  - 4 bytes, ISIZE (Input SIZE) - size of the original (uncompressed) input data modulo 2^32
                    std.mem.writeInt(u32, &bits, gzip.final(), .little);
                    try writer.writeAll(&bits);

                    std.mem.writeInt(u32, &bits, gzip.bytes_read, .little);
                    try writer.writeAll(&bits);
                },
                .zlib => |*zlib| {
                    // ZLIB (RFC 1950) is big-endian, unlike GZIP (RFC 1952).
                    // 4 bytes of ADLER32 (Adler-32 checksum)
                    // Checksum value of the uncompressed data (excluding any
                    // dictionary data) computed according to Adler-32
                    // algorithm.
                    std.mem.writeInt(u32, &bits, zlib.final, .big);
                    try writer.writeAll(&bits);
                },
                .raw => {},
            }
        }
    };
};

/// When decompressing, the output buffer is used as the history window, so
/// less than this may result in failure to decompress streams that were
/// compressed with a larger window.
pub const max_window_len = 1 << 16;

/// Deflate is a lossless data compression file format that uses a combination
/// of LZ77 and Huffman coding.
pub const Compress = @import("flate/Compress.zig");

/// Inflate is the decoding process that takes a Deflate bitstream for
/// decompression and correctly produces the original full-size data or file.
pub const Decompress = @import("flate/Decompress.zig");

/// Huffman only compression. Without Lempel-Ziv match searching. Faster
/// compression, less memory requirements but bigger compressed sizes.
pub const huffman = struct {
    // The odd order in which the codegen code sizes are written.
    pub const codegen_order = [_]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
    // The number of codegen codes.
    pub const codegen_code_count = 19;

    // The largest distance code.
    pub const distance_code_count = 30;

    // Maximum number of literals.
    pub const max_num_lit = 286;

    // Max number of frequencies used for a Huffman Code
    // Possible lengths are codegen_code_count (19), distance_code_count (30) and max_num_lit (286).
    // The largest of these is max_num_lit.
    pub const max_num_frequencies = max_num_lit;

    // Biggest block size for uncompressed block.
    pub const max_store_block_size = 65535;
    // The special code used to mark the end of a block.
    pub const end_block_marker = 256;
};

test {
    _ = Compress;
    _ = Decompress;
}

test "compress/decompress" {
    const print = std.debug.print;
    var cmp_buf: [64 * 1024]u8 = undefined; // compressed data buffer
    var dcm_buf: [64 * 1024]u8 = undefined; // decompressed data buffer

    const levels = [_]Compress.Level{ .level_4, .level_5, .level_6, .level_7, .level_8, .level_9 };
    const cases = [_]struct {
        data: []const u8, // uncompressed content
        // compressed data sizes per level 4-9
        gzip_sizes: [levels.len]usize = [_]usize{0} ** levels.len,
        huffman_only_size: usize = 0,
        store_size: usize = 0,
    }{
        .{
            .data = @embedFile("flate/testdata/rfc1951.txt"),
            .gzip_sizes = [_]usize{ 11513, 11217, 11139, 11126, 11122, 11119 },
            .huffman_only_size = 20287,
            .store_size = 36967,
        },
        .{
            .data = @embedFile("flate/testdata/fuzz/roundtrip1.input"),
            .gzip_sizes = [_]usize{ 373, 370, 370, 370, 370, 370 },
            .huffman_only_size = 393,
            .store_size = 393,
        },
        .{
            .data = @embedFile("flate/testdata/fuzz/roundtrip2.input"),
            .gzip_sizes = [_]usize{ 373, 373, 373, 373, 373, 373 },
            .huffman_only_size = 394,
            .store_size = 394,
        },
        .{
            .data = @embedFile("flate/testdata/fuzz/deflate-stream.expect"),
            .gzip_sizes = [_]usize{ 351, 347, 347, 347, 347, 347 },
            .huffman_only_size = 498,
            .store_size = 747,
        },
    };

    for (cases, 0..) |case, case_no| { // for each case
        const data = case.data;

        for (levels, 0..) |level, i| { // for each compression level

            inline for (Container.list) |container| { // for each wrapping
                var compressed_size: usize = if (case.gzip_sizes[i] > 0)
                    case.gzip_sizes[i] - Container.gzip.size() + container.size()
                else
                    0;

                // compress original stream to compressed stream
                {
                    var original: std.io.Reader = .fixed(data);
                    var compressed: Writer = .fixed(&cmp_buf);
                    var compress: Compress = .init(&original, .raw);
                    var compress_br = compress.readable(&.{});
                    const n = try compress_br.readRemaining(&compressed, .{ .level = level });
                    if (compressed_size == 0) {
                        if (container == .gzip)
                            print("case {d} gzip level {} compressed size: {d}\n", .{ case_no, level, compressed.pos });
                        compressed_size = compressed.pos;
                    }
                    try testing.expectEqual(compressed_size, n);
                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompress compressed stream to decompressed stream
                {
                    var compressed: std.io.Reader = .fixed(cmp_buf[0..compressed_size]);
                    var decompressed: Writer = .fixed(&dcm_buf);
                    try Decompress.pump(container, &compressed, &decompressed);
                    try testing.expectEqualSlices(u8, data, decompressed.getWritten());
                }

                // compressor writer interface
                {
                    var compressed: Writer = .fixed(&cmp_buf);
                    var cmp = try Compress.init(container, &compressed, .{ .level = level });
                    var cmp_wrt = cmp.writer();
                    try cmp_wrt.writeAll(data);
                    try cmp.finish();

                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompressor reader interface
                {
                    var compressed: std.io.Reader = .fixed(cmp_buf[0..compressed_size]);
                    var dcm = Decompress.pump(container, &compressed);
                    var dcm_rdr = dcm.reader();
                    const n = try dcm_rdr.readAll(&dcm_buf);
                    try testing.expectEqual(data.len, n);
                    try testing.expectEqualSlices(u8, data, dcm_buf[0..n]);
                }
            }
        }
        // huffman only compression
        {
            inline for (Container.list) |container| { // for each wrapping
                var compressed_size: usize = if (case.huffman_only_size > 0)
                    case.huffman_only_size - Container.gzip.size() + container.size()
                else
                    0;

                // compress original stream to compressed stream
                {
                    var original: std.io.Reader = .fixed(data);
                    var compressed: Writer = .fixed(&cmp_buf);
                    var cmp = try Compress.Huffman.init(container, &compressed);
                    try cmp.compress(original.reader());
                    try cmp.finish();
                    if (compressed_size == 0) {
                        if (container == .gzip)
                            print("case {d} huffman only compressed size: {d}\n", .{ case_no, compressed.pos });
                        compressed_size = compressed.pos;
                    }
                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompress compressed stream to decompressed stream
                {
                    var compressed: std.io.Reader = .fixed(cmp_buf[0..compressed_size]);
                    var decompressed: Writer = .fixed(&dcm_buf);
                    try Decompress.pump(container, &compressed, &decompressed);
                    try testing.expectEqualSlices(u8, data, decompressed.getWritten());
                }
            }
        }

        // store only
        {
            inline for (Container.list) |container| { // for each wrapping
                var compressed_size: usize = if (case.store_size > 0)
                    case.store_size - Container.gzip.size() + container.size()
                else
                    0;

                // compress original stream to compressed stream
                {
                    var original: std.io.Reader = .fixed(data);
                    var compressed: Writer = .fixed(&cmp_buf);
                    var cmp = try Compress.SimpleCompressor(.store, container).init(&compressed);
                    try cmp.compress(original.reader());
                    try cmp.finish();
                    if (compressed_size == 0) {
                        if (container == .gzip)
                            print("case {d} store only compressed size: {d}\n", .{ case_no, compressed.pos });
                        compressed_size = compressed.pos;
                    }

                    try testing.expectEqual(compressed_size, compressed.pos);
                }
                // decompress compressed stream to decompressed stream
                {
                    var compressed: std.io.Reader = .fixed(cmp_buf[0..compressed_size]);
                    var decompressed: Writer = .fixed(&dcm_buf);
                    try Decompress.pump(container, &compressed, &decompressed);
                    try testing.expectEqualSlices(u8, data, decompressed.getWritten());
                }
            }
        }
    }
}

fn testDecompress(comptime container: Container, compressed: []const u8, expected_plain: []const u8) !void {
    var in: std.io.Reader = .fixed(compressed);
    var out: std.io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();

    try Decompress.pump(container, &in, &out.interface);
    try testing.expectEqualSlices(u8, expected_plain, out.items);
}

test "don't read past deflate stream's end" {
    try testDecompress(.zlib, &[_]u8{
        0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0xc0, 0x00, 0xc1, 0xff,
        0xff, 0x43, 0x30, 0x03, 0x03, 0xc3, 0xff, 0xff, 0xff, 0x01,
        0x83, 0x95, 0x0b, 0xf5,
    }, &[_]u8{
        0x00, 0xff, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0xff,
        0x00, 0xff, 0xff, 0xff, 0x00, 0xff, 0xff, 0xff, 0x00, 0x00,
        0x00, 0x00, 0xff, 0xff, 0xff,
    });
}

test "zlib header" {
    // Truncated header
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.zlib, &[_]u8{0x78}, ""),
    );
    // Wrong CM
    try testing.expectError(
        error.BadZlibHeader,
        testDecompress(.zlib, &[_]u8{ 0x79, 0x94 }, ""),
    );
    // Wrong CINFO
    try testing.expectError(
        error.BadZlibHeader,
        testDecompress(.zlib, &[_]u8{ 0x88, 0x98 }, ""),
    );
    // Wrong checksum
    try testing.expectError(
        error.WrongZlibChecksum,
        testDecompress(.zlib, &[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 }, ""),
    );
    // Truncated checksum
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.zlib, &[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00 }, ""),
    );
}

test "gzip header" {
    // Truncated header
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.gzip, &[_]u8{ 0x1f, 0x8B }, undefined),
    );
    // Wrong CM
    try testing.expectError(
        error.BadGzipHeader,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03,
        }, undefined),
    );

    // Wrong checksum
    try testing.expectError(
        error.WrongGzipChecksum,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00,
        }, undefined),
    );
    // Truncated checksum
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00,
        }, undefined),
    );
    // Wrong initial size
    try testing.expectError(
        error.WrongGzipSize,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x01,
        }, undefined),
    );
    // Truncated initial size field
    try testing.expectError(
        error.EndOfStream,
        testDecompress(.gzip, &[_]u8{
            0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00,
        }, undefined),
    );

    try testDecompress(.gzip, &[_]u8{
        // GZIP header
        0x1f, 0x8b, 0x08, 0x12, 0x00, 0x09, 0x6e, 0x88, 0x00, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00,
        // header.FHCRC (should cover entire header)
        0x99, 0xd6,
        // GZIP data
        0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }, "");
}

test "public interface" {
    const plain_data = [_]u8{ 'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a };

    // deflate final stored block, header + plain (stored) data
    const deflate_block = [_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
    } ++ plain_data;

    //// gzip header/footer + deflate block
    //const gzip_data =
    //    [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03 } ++ // gzip header (10 bytes)
    //    deflate_block ++
    //    [_]u8{ 0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00 }; // gzip footer checksum (4 byte), size (4 bytes)

    //// zlib header/footer + deflate block
    //const zlib_data = [_]u8{ 0x78, 0b10_0_11100 } ++ // zlib header (2 bytes)}
    //    deflate_block ++
    //    [_]u8{ 0x1c, 0xf2, 0x04, 0x47 }; // zlib footer: checksum

    // TODO
    //const gzip = @import("gzip.zig");
    //const zlib = @import("zlib.zig");
    const flate = @This();

    //try testInterface(gzip, &gzip_data, &plain_data);
    //try testInterface(zlib, &zlib_data, &plain_data);
    try testInterface(flate, &deflate_block, &plain_data);
}

fn testInterface(comptime pkg: type, gzip_data: []const u8, plain_data: []const u8) !void {
    var buffer1: [64]u8 = undefined;
    var buffer2: [64]u8 = undefined;

    // decompress
    {
        var plain: Writer = .fixed(&buffer2);

        var in: std.io.Reader = .fixed(gzip_data);
        try pkg.decompress(&in, &plain);
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }

    // compress/decompress
    {
        var plain: Writer = .fixed(&buffer2);
        var compressed: Writer = .fixed(&buffer1);

        var in: std.io.Reader = .fixed(plain_data);
        try pkg.compress(&in, &compressed, .{});

        var compressed_br: std.io.Reader = .fixed(&buffer1);
        try pkg.decompress(&compressed_br, &plain);
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }

    // compressor/decompressor
    {
        var plain: Writer = .fixed(&buffer2);
        var compressed: Writer = .fixed(&buffer1);

        var in: std.io.Reader = .fixed(plain_data);
        var cmp = try pkg.compressor(&compressed, .{});
        try cmp.compress(&in);
        try cmp.finish();

        var compressed_br: std.io.Reader = .fixed(&buffer1);
        var dcp = pkg.decompressor(&compressed_br);
        try dcp.decompress(&plain);
        try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
    }

    // huffman
    {
        // huffman compress/decompress
        {
            var plain: Writer = .fixed(&buffer2);
            var compressed: Writer = .fixed(&buffer1);

            var in: std.io.Reader = .fixed(plain_data);
            try pkg.huffman.compress(&in, &compressed);

            var compressed_br: std.io.Reader = .fixed(&buffer1);
            try pkg.decompress(&compressed_br, &plain);
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }

        // huffman compressor/decompressor
        {
            var plain: Writer = .fixed(&buffer2);
            var compressed: Writer = .fixed(&buffer1);

            var in: std.io.Reader = .fixed(plain_data);
            var cmp = try pkg.huffman.compressor(&compressed);
            try cmp.compress(&in);
            try cmp.finish();

            var compressed_br: std.io.Reader = .fixed(&buffer1);
            try pkg.decompress(&compressed_br, &plain);
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
    }

    // store
    {
        // store compress/decompress
        {
            var plain: Writer = .fixed(&buffer2);
            var compressed: Writer = .fixed(&buffer1);

            var in: std.io.Reader = .fixed(plain_data);
            try pkg.store.compress(&in, &compressed);

            var compressed_br: std.io.Reader = .fixed(&buffer1);
            try pkg.decompress(&compressed_br, &plain);
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }

        // store compressor/decompressor
        {
            var plain: Writer = .fixed(&buffer2);
            var compressed: Writer = .fixed(&buffer1);

            var in: std.io.Reader = .fixed(plain_data);
            var cmp = try pkg.store.compressor(&compressed);
            try cmp.compress(&in);
            try cmp.finish();

            var compressed_br: std.io.Reader = .fixed(&buffer1);
            try pkg.decompress(&compressed_br, &plain);
            try testing.expectEqualSlices(u8, plain_data, plain.getWritten());
        }
    }
}

pub const match = struct {
    pub const base_length = 3; // smallest match length per the RFC section 3.2.5
    pub const min_length = 4; // min length used in this algorithm
    pub const max_length = 258;

    pub const min_distance = 1;
    pub const max_distance = 32768;
};

pub const history_len = match.max_distance;

pub const lookup = struct {
    pub const bits = 15;
    pub const len = 1 << bits;
    pub const shift = 32 - bits;
};

test "zlib should not overshoot" {
    // Compressed zlib data with extra 4 bytes at the end.
    const data = [_]u8{
        0x78, 0x9c, 0x73, 0xce, 0x2f, 0xa8, 0x2c, 0xca, 0x4c, 0xcf, 0x28, 0x51, 0x08, 0xcf, 0xcc, 0xc9,
        0x49, 0xcd, 0x55, 0x28, 0x4b, 0xcc, 0x53, 0x08, 0x4e, 0xce, 0x48, 0xcc, 0xcc, 0xd6, 0x51, 0x08,
        0xce, 0xcc, 0x4b, 0x4f, 0x2c, 0xc8, 0x2f, 0x4a, 0x55, 0x30, 0xb4, 0xb4, 0x34, 0xd5, 0xb5, 0x34,
        0x03, 0x00, 0x8b, 0x61, 0x0f, 0xa4, 0x52, 0x5a, 0x94, 0x12,
    };

    var stream: std.io.Reader = .fixed(&data);
    const reader = stream.reader();

    var dcp = Decompress.init(reader);
    var out: [128]u8 = undefined;

    // Decompress
    var n = try dcp.reader().readAll(out[0..]);

    // Expected decompressed data
    try std.testing.expectEqual(46, n);
    try std.testing.expectEqualStrings("Copyright Willem van Schaik, Singapore 1995-96", out[0..n]);

    // Decompressor don't overshoot underlying reader.
    // It is leaving it at the end of compressed data chunk.
    try std.testing.expectEqual(data.len - 4, stream.getPos());
    try std.testing.expectEqual(0, dcp.unreadBytes());

    // 4 bytes after compressed chunk are available in reader.
    n = try reader.readAll(out[0..]);
    try std.testing.expectEqual(n, 4);
    try std.testing.expectEqualSlices(u8, data[data.len - 4 .. data.len], out[0..n]);
}
