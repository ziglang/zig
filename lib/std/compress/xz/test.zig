const std = @import("../../std.zig");
const testing = std.testing;
const xz = std.compress.xz;

fn decompress(data: []const u8) ![]u8 {
    var in_stream = std.io.fixedBufferStream(data);

    var xz_stream = try xz.decompress(testing.allocator, in_stream.reader());
    defer xz_stream.deinit();

    return xz_stream.reader().readAllAlloc(testing.allocator, std.math.maxInt(usize));
}

fn testReader(data: []const u8, comptime expected: []const u8) !void {
    const buf = try decompress(data);
    defer testing.allocator.free(buf);

    try testing.expectEqualSlices(u8, expected, buf);
}

test "compressed data" {
    try testReader(@embedFile("testdata/good-0-empty.xz"), "");

    inline for ([_][]const u8{
        "good-1-check-none.xz",
        "good-1-check-crc32.xz",
        "good-1-check-crc64.xz",
        "good-1-check-sha256.xz",
        "good-2-lzma2.xz",
        "good-1-block_header-1.xz",
        "good-1-block_header-2.xz",
        "good-1-block_header-3.xz",
    }) |filename| {
        try testReader(@embedFile("testdata/" ++ filename),
            \\Hello
            \\World!
            \\
        );
    }

    inline for ([_][]const u8{
        "good-1-lzma2-1.xz",
        "good-1-lzma2-2.xz",
        "good-1-lzma2-3.xz",
        "good-1-lzma2-4.xz",
    }) |filename| {
        try testReader(@embedFile("testdata/" ++ filename),
            \\Lorem ipsum dolor sit amet, consectetur adipisicing 
            \\elit, sed do eiusmod tempor incididunt ut 
            \\labore et dolore magna aliqua. Ut enim 
            \\ad minim veniam, quis nostrud exercitation ullamco 
            \\laboris nisi ut aliquip ex ea commodo 
            \\consequat. Duis aute irure dolor in reprehenderit 
            \\in voluptate velit esse cillum dolore eu 
            \\fugiat nulla pariatur. Excepteur sint occaecat cupidatat 
            \\non proident, sunt in culpa qui officia 
            \\deserunt mollit anim id est laborum. 
            \\
        );
    }

    try testReader(@embedFile("testdata/good-1-lzma2-5.xz"), "");
}

test "unsupported" {
    inline for ([_][]const u8{
        "good-1-delta-lzma2.tiff.xz",
        "good-1-x86-lzma2.xz",
        "good-1-sparc-lzma2.xz",
        "good-1-arm64-lzma2-1.xz",
        "good-1-arm64-lzma2-2.xz",
        "good-1-3delta-lzma2.xz",
        "good-1-empty-bcj-lzma2.xz",
    }) |filename| {
        try testing.expectError(
            error.Unsupported,
            decompress(@embedFile("testdata/" ++ filename)),
        );
    }
}

fn testDontPanic(data: []const u8) !void {
    const buf = decompress(data) catch |err| switch (err) {
        error.OutOfMemory => |e| return e,
        else => return,
    };
    defer testing.allocator.free(buf);
}

test "size fields: integer overflow avoidance" {
    // These cases were found via fuzz testing and each previously caused
    // an integer overflow when decoding. We just want to ensure they no longer
    // cause a panic
    const header_size_overflow = "\xfd7zXZ\x00\x00\x01i\"\xde6z";
    try testDontPanic(header_size_overflow);
    const lzma2_chunk_size_overflow = "\xfd7zXZ\x00\x00\x01i\"\xde6\x02\x00!\x01\x08\x00\x00\x00\xd8\x0f#\x13\x01\xff\xff";
    try testDontPanic(lzma2_chunk_size_overflow);
    const backward_size_overflow = "\xfd7zXZ\x00\x00\x01i\"\xde6\x00\x00\x00\x00\x1c\xdfD!\x90B\x99\r\x01\x00\x00\xff\xff\x10\x00\x00\x00\x01DD\xff\xff\xff\x01";
    try testDontPanic(backward_size_overflow);
}
