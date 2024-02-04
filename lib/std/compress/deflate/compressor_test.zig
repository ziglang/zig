const std = @import("std");
const expect = std.testing.expect;
const fifo = std.fifo;
const io = std.io;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const ArrayList = std.ArrayList;

const deflate = @import("compressor.zig");
const inflate = @import("decompressor.zig");

const compressor = deflate.compressor;
const decompressor = inflate.decompressor;
const huffman_only = deflate.huffman_only;

fn testSync(level: deflate.Compression, input: []const u8) !void {
    if (input.len == 0) {
        return;
    }

    var divided_buf = fifo
        .LinearFifo(u8, fifo.LinearFifoBufferType.Dynamic)
        .init(testing.allocator);
    defer divided_buf.deinit();
    var whole_buf = std.ArrayList(u8).init(testing.allocator);
    defer whole_buf.deinit();

    const multi_writer = io.multiWriter(.{
        divided_buf.writer(),
        whole_buf.writer(),
    }).writer();

    var comp = try compressor(
        testing.allocator,
        multi_writer,
        .{ .level = level },
    );
    defer comp.deinit();

    {
        var decomp = try decompressor(
            testing.allocator,
            divided_buf.reader(),
            null,
        );
        defer decomp.deinit();

        // Write first half of the input and flush()
        const half: usize = (input.len + 1) / 2;
        var half_len: usize = half - 0;
        {
            _ = try comp.writer().writeAll(input[0..half]);

            // Flush
            try comp.flush();

            // Read back
            const decompressed = try testing.allocator.alloc(u8, half_len);
            defer testing.allocator.free(decompressed);

            const read = try decomp.reader().readAll(decompressed); // read at least half
            try testing.expectEqual(half_len, read);
            try testing.expectEqualSlices(u8, input[0..half], decompressed);
        }

        // Write last half of the input and close()
        half_len = input.len - half;
        {
            _ = try comp.writer().writeAll(input[half..]);

            // Close
            try comp.close();

            // Read back
            const decompressed = try testing.allocator.alloc(u8, half_len);
            defer testing.allocator.free(decompressed);

            var read = try decomp.reader().readAll(decompressed);
            try testing.expectEqual(half_len, read);
            try testing.expectEqualSlices(u8, input[half..], decompressed);

            // Extra read
            var final: [10]u8 = undefined;
            read = try decomp.reader().readAll(&final);
            try testing.expectEqual(@as(usize, 0), read); // expect ended stream to return 0 bytes

            try decomp.close();
        }
    }

    _ = try comp.writer().writeAll(input);
    try comp.close();

    // stream should work for ordinary reader too (reading whole_buf in one go)
    const whole_buf_reader = io.fixedBufferStream(whole_buf.items).reader();
    var decomp = try decompressor(testing.allocator, whole_buf_reader, null);
    defer decomp.deinit();

    const decompressed = try testing.allocator.alloc(u8, input.len);
    defer testing.allocator.free(decompressed);

    _ = try decomp.reader().readAll(decompressed);
    try decomp.close();

    try testing.expectEqualSlices(u8, input, decompressed);
}

fn testToFromWithLevelAndLimit(level: deflate.Compression, input: []const u8, limit: u32) !void {
    var compressed = std.ArrayList(u8).init(testing.allocator);
    defer compressed.deinit();

    var comp = try compressor(testing.allocator, compressed.writer(), .{ .level = level });
    defer comp.deinit();

    try comp.writer().writeAll(input);
    try comp.close();

    if (limit > 0) {
        try expect(compressed.items.len <= limit);
    }

    var fib = io.fixedBufferStream(compressed.items);
    var decomp = try decompressor(testing.allocator, fib.reader(), null);
    defer decomp.deinit();

    const decompressed = try testing.allocator.alloc(u8, input.len);
    defer testing.allocator.free(decompressed);

    const read: usize = try decomp.reader().readAll(decompressed);
    try testing.expectEqual(input.len, read);
    try testing.expectEqualSlices(u8, input, decompressed);

    if (false) {
        // TODO: this test has regressed
        try testSync(level, input);
    }
}

fn testToFromWithLimit(input: []const u8, limit: [11]u32) !void {
    try testToFromWithLevelAndLimit(.no_compression, input, limit[0]);
    try testToFromWithLevelAndLimit(.best_speed, input, limit[1]);
    try testToFromWithLevelAndLimit(.level_2, input, limit[2]);
    try testToFromWithLevelAndLimit(.level_3, input, limit[3]);
    try testToFromWithLevelAndLimit(.level_4, input, limit[4]);
    try testToFromWithLevelAndLimit(.level_5, input, limit[5]);
    try testToFromWithLevelAndLimit(.level_6, input, limit[6]);
    try testToFromWithLevelAndLimit(.level_7, input, limit[7]);
    try testToFromWithLevelAndLimit(.level_8, input, limit[8]);
    try testToFromWithLevelAndLimit(.best_compression, input, limit[9]);
    try testToFromWithLevelAndLimit(.huffman_only, input, limit[10]);
}

test "deflate/inflate" {
    const limits = [_]u32{0} ** 11;

    var test0 = [_]u8{};
    var test1 = [_]u8{0x11};
    var test2 = [_]u8{ 0x11, 0x12 };
    var test3 = [_]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 };
    var test4 = [_]u8{ 0x11, 0x10, 0x13, 0x41, 0x21, 0x21, 0x41, 0x13, 0x87, 0x78, 0x13 };

    try testToFromWithLimit(&test0, limits);
    try testToFromWithLimit(&test1, limits);
    try testToFromWithLimit(&test2, limits);
    try testToFromWithLimit(&test3, limits);
    try testToFromWithLimit(&test4, limits);

    var large_data_chunk = try testing.allocator.alloc(u8, 100_000);
    defer testing.allocator.free(large_data_chunk);
    // fill with random data
    for (large_data_chunk, 0..) |_, i| {
        large_data_chunk[i] = @as(u8, @truncate(i)) *% @as(u8, @truncate(i));
    }
    try testToFromWithLimit(large_data_chunk, limits);
}

test "very long sparse chunk" {
    // A SparseReader returns a stream consisting of 0s ending with 65,536 (1<<16) 1s.
    // This tests missing hash references in a very large input.
    const SparseReader = struct {
        l: usize, // length
        cur: usize, // current position

        const Self = @This();
        const Error = error{};

        pub const Reader = io.Reader(*Self, Error, read);

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        fn read(s: *Self, b: []u8) Error!usize {
            var n: usize = 0; // amount read

            if (s.cur >= s.l) {
                return 0;
            }
            n = b.len;
            var cur = s.cur + n;
            if (cur > s.l) {
                n -= cur - s.l;
                cur = s.l;
            }
            for (b[0..n], 0..) |_, i| {
                if (s.cur + i >= s.l -| (1 << 16)) {
                    b[i] = 1;
                } else {
                    b[i] = 0;
                }
            }
            s.cur = cur;
            return n;
        }
    };

    var comp = try compressor(
        testing.allocator,
        io.null_writer,
        .{ .level = .best_speed },
    );
    defer comp.deinit();
    var writer = comp.writer();

    var sparse = SparseReader{ .l = 0x23e8, .cur = 0 };
    var reader = sparse.reader();

    var read: usize = 1;
    var written: usize = 0;
    while (read > 0) {
        var buf: [1 << 15]u8 = undefined; // 32,768 bytes buffer
        read = try reader.read(&buf);
        written += try writer.write(buf[0..read]);
    }
    try testing.expectEqual(@as(usize, 0x23e8), written);
}

test "compressor reset" {
    for (std.enums.values(deflate.Compression)) |c| {
        try testWriterReset(c, null);
        try testWriterReset(c, "dict");
        try testWriterReset(c, "hello");
    }
}

fn testWriterReset(level: deflate.Compression, dict: ?[]const u8) !void {
    const filler = struct {
        fn writeData(c: anytype) !void {
            const msg = "all your base are belong to us";
            try c.writer().writeAll(msg);
            try c.flush();

            const hello = "hello world";
            var i: usize = 0;
            while (i < 1024) : (i += 1) {
                try c.writer().writeAll(hello);
            }

            i = 0;
            while (i < 65000) : (i += 1) {
                try c.writer().writeAll("x");
            }
        }
    };

    var buf1 = ArrayList(u8).init(testing.allocator);
    defer buf1.deinit();
    var buf2 = ArrayList(u8).init(testing.allocator);
    defer buf2.deinit();

    var comp = try compressor(
        testing.allocator,
        buf1.writer(),
        .{ .level = level, .dictionary = dict },
    );
    defer comp.deinit();

    try filler.writeData(&comp);
    try comp.close();

    comp.reset(buf2.writer());
    try filler.writeData(&comp);
    try comp.close();

    try testing.expectEqualSlices(u8, buf1.items, buf2.items);
}

test "decompressor dictionary" {
    const dict = "hello world"; // dictionary
    const text = "hello again world";

    var compressed = fifo
        .LinearFifo(u8, fifo.LinearFifoBufferType.Dynamic)
        .init(testing.allocator);
    defer compressed.deinit();

    var comp = try compressor(
        testing.allocator,
        compressed.writer(),
        .{
            .level = .level_5,
            .dictionary = null, // no dictionary
        },
    );
    defer comp.deinit();

    // imitate a compressor with a dictionary
    try comp.writer().writeAll(dict);
    try comp.flush();
    compressed.discard(compressed.readableLength()); // empty the output
    try comp.writer().writeAll(text);
    try comp.close();

    const decompressed = try testing.allocator.alloc(u8, text.len);
    defer testing.allocator.free(decompressed);

    var decomp = try decompressor(
        testing.allocator,
        compressed.reader(),
        dict,
    );
    defer decomp.deinit();

    _ = try decomp.reader().readAll(decompressed);
    try testing.expectEqualSlices(u8, "hello again world", decompressed);
}

test "compressor dictionary" {
    const dict = "hello world";
    const text = "hello again world";

    var compressed_nd = fifo
        .LinearFifo(u8, fifo.LinearFifoBufferType.Dynamic)
        .init(testing.allocator); // compressed with no dictionary
    defer compressed_nd.deinit();

    var compressed_d = ArrayList(u8).init(testing.allocator); // compressed with a dictionary
    defer compressed_d.deinit();

    // imitate a compressor with a dictionary
    var comp_nd = try compressor(
        testing.allocator,
        compressed_nd.writer(),
        .{
            .level = .level_5,
            .dictionary = null, // no dictionary
        },
    );
    defer comp_nd.deinit();
    try comp_nd.writer().writeAll(dict);
    try comp_nd.flush();
    compressed_nd.discard(compressed_nd.readableLength()); // empty the output
    try comp_nd.writer().writeAll(text);
    try comp_nd.close();

    // use a compressor with a dictionary
    var comp_d = try compressor(
        testing.allocator,
        compressed_d.writer(),
        .{
            .level = .level_5,
            .dictionary = dict, // with a dictionary
        },
    );
    defer comp_d.deinit();
    try comp_d.writer().writeAll(text);
    try comp_d.close();

    try testing.expectEqualSlices(u8, compressed_d.items, compressed_nd.readableSlice(0));
}

// Update the hash for best_speed only if d.index < d.maxInsertIndex
// See https://golang.org/issue/2508
test "Go non-regression test for 2508" {
    var comp = try compressor(
        testing.allocator,
        io.null_writer,
        .{ .level = .best_speed },
    );
    defer comp.deinit();

    var buf = [_]u8{0} ** 1024;

    var i: usize = 0;
    while (i < 131_072) : (i += 1) {
        try comp.writer().writeAll(&buf);
        try comp.close();
    }
}

test "deflate/inflate string" {
    const StringTest = struct {
        filename: []const u8,
        limit: [11]u32,
    };

    const deflate_inflate_string_tests = [_]StringTest{
        .{
            .filename = "compress-e.txt",
            .limit = [11]u32{
                100_018, // no_compression
                50_650, // best_speed
                50_960, // 2
                51_150, // 3
                50_930, // 4
                50_790, // 5
                50_790, // 6
                50_790, // 7
                50_790, // 8
                50_790, // best_compression
                43_683, // huffman_only
            },
        },
        .{
            .filename = "rfc1951.txt",
            .limit = [11]u32{
                36_954, // no_compression
                12_952, // best_speed
                12_228, // 2
                12_016, // 3
                11_466, // 4
                11_191, // 5
                11_129, // 6
                11_120, // 7
                11_112, // 8
                11_109, // best_compression
                20_273, // huffman_only
            },
        },
    };

    inline for (deflate_inflate_string_tests) |t| {
        const golden = @embedFile("testdata/" ++ t.filename);
        try testToFromWithLimit(golden, t.limit);
    }
}

test "inflate reset" {
    const strings = [_][]const u8{
        "lorem ipsum izzle fo rizzle",
        "the quick brown fox jumped over",
    };

    var compressed_strings = [_]ArrayList(u8){
        ArrayList(u8).init(testing.allocator),
        ArrayList(u8).init(testing.allocator),
    };
    defer compressed_strings[0].deinit();
    defer compressed_strings[1].deinit();

    for (strings, 0..) |s, i| {
        var comp = try compressor(
            testing.allocator,
            compressed_strings[i].writer(),
            .{ .level = .level_6 },
        );
        defer comp.deinit();

        try comp.writer().writeAll(s);
        try comp.close();
    }

    var fib = io.fixedBufferStream(compressed_strings[0].items);
    var decomp = try decompressor(testing.allocator, fib.reader(), null);
    defer decomp.deinit();

    const decompressed_0: []u8 = try decomp.reader()
        .readAllAlloc(testing.allocator, math.maxInt(usize));
    defer testing.allocator.free(decompressed_0);

    fib = io.fixedBufferStream(compressed_strings[1].items);
    try decomp.reset(fib.reader(), null);

    const decompressed_1: []u8 = try decomp.reader()
        .readAllAlloc(testing.allocator, math.maxInt(usize));
    defer testing.allocator.free(decompressed_1);

    try decomp.close();

    try testing.expectEqualSlices(u8, strings[0], decompressed_0);
    try testing.expectEqualSlices(u8, strings[1], decompressed_1);
}

test "inflate reset dictionary" {
    const dict = "the lorem fox";
    const strings = [_][]const u8{
        "lorem ipsum izzle fo rizzle",
        "the quick brown fox jumped over",
    };

    var compressed_strings = [_]ArrayList(u8){
        ArrayList(u8).init(testing.allocator),
        ArrayList(u8).init(testing.allocator),
    };
    defer compressed_strings[0].deinit();
    defer compressed_strings[1].deinit();

    for (strings, 0..) |s, i| {
        var comp = try compressor(
            testing.allocator,
            compressed_strings[i].writer(),
            .{ .level = .level_6 },
        );
        defer comp.deinit();

        try comp.writer().writeAll(s);
        try comp.close();
    }

    var fib = io.fixedBufferStream(compressed_strings[0].items);
    var decomp = try decompressor(testing.allocator, fib.reader(), dict);
    defer decomp.deinit();

    const decompressed_0: []u8 = try decomp.reader()
        .readAllAlloc(testing.allocator, math.maxInt(usize));
    defer testing.allocator.free(decompressed_0);

    fib = io.fixedBufferStream(compressed_strings[1].items);
    try decomp.reset(fib.reader(), dict);

    const decompressed_1: []u8 = try decomp.reader()
        .readAllAlloc(testing.allocator, math.maxInt(usize));
    defer testing.allocator.free(decompressed_1);

    try decomp.close();

    try testing.expectEqualSlices(u8, strings[0], decompressed_0);
    try testing.expectEqualSlices(u8, strings[1], decompressed_1);
}
