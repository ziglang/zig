const std = @import("../std.zig");
const assert = std.debug.assert;

/// Recommended amount by the standard. Lower than this may result in inability
/// to decompress common streams.
pub const default_window_len = 8 * 1024 * 1024;

pub const Decompress = @import("zstd/Decompress.zig");

pub const block_size_max = 1 << 17;

pub const literals_length_default_distribution = [36]i16{
    4,  3,  2,  2,  2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1,
    2,  2,  2,  2,  2, 2, 2, 2, 2, 3, 2, 1, 1, 1, 1, 1,
    -1, -1, -1, -1,
};

pub const match_lengths_default_distribution = [53]i16{
    1,  4,  3,  2,  2,  2, 2, 2, 2, 1, 1, 1, 1, 1, 1,  1,
    1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  1,
    1,  1,  1,  1,  1,  1, 1, 1, 1, 1, 1, 1, 1, 1, -1, -1,
    -1, -1, -1, -1, -1,
};

pub const offset_codes_default_distribution = [29]i16{
    1, 1, 1, 1, 1, 1, 2, 2, 2,  1,  1,  1,  1,  1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1,
};

pub const start_repeated_offset_1 = 1;
pub const start_repeated_offset_2 = 4;
pub const start_repeated_offset_3 = 8;

pub const literals_length_code_table = [36]struct { u32, u5 }{
    .{ 0, 0 },     .{ 1, 0 },      .{ 2, 0 },      .{ 3, 0 },
    .{ 4, 0 },     .{ 5, 0 },      .{ 6, 0 },      .{ 7, 0 },
    .{ 8, 0 },     .{ 9, 0 },      .{ 10, 0 },     .{ 11, 0 },
    .{ 12, 0 },    .{ 13, 0 },     .{ 14, 0 },     .{ 15, 0 },
    .{ 16, 1 },    .{ 18, 1 },     .{ 20, 1 },     .{ 22, 1 },
    .{ 24, 2 },    .{ 28, 2 },     .{ 32, 3 },     .{ 40, 3 },
    .{ 48, 4 },    .{ 64, 6 },     .{ 128, 7 },    .{ 256, 8 },
    .{ 512, 9 },   .{ 1024, 10 },  .{ 2048, 11 },  .{ 4096, 12 },
    .{ 8192, 13 }, .{ 16384, 14 }, .{ 32768, 15 }, .{ 65536, 16 },
};

pub const match_length_code_table = [53]struct { u32, u5 }{
    .{ 3, 0 },     .{ 4, 0 },     .{ 5, 0 },      .{ 6, 0 },      .{ 7, 0 },      .{ 8, 0 },
    .{ 9, 0 },     .{ 10, 0 },    .{ 11, 0 },     .{ 12, 0 },     .{ 13, 0 },     .{ 14, 0 },
    .{ 15, 0 },    .{ 16, 0 },    .{ 17, 0 },     .{ 18, 0 },     .{ 19, 0 },     .{ 20, 0 },
    .{ 21, 0 },    .{ 22, 0 },    .{ 23, 0 },     .{ 24, 0 },     .{ 25, 0 },     .{ 26, 0 },
    .{ 27, 0 },    .{ 28, 0 },    .{ 29, 0 },     .{ 30, 0 },     .{ 31, 0 },     .{ 32, 0 },
    .{ 33, 0 },    .{ 34, 0 },    .{ 35, 1 },     .{ 37, 1 },     .{ 39, 1 },     .{ 41, 1 },
    .{ 43, 2 },    .{ 47, 2 },    .{ 51, 3 },     .{ 59, 3 },     .{ 67, 4 },     .{ 83, 4 },
    .{ 99, 5 },    .{ 131, 7 },   .{ 259, 8 },    .{ 515, 9 },    .{ 1027, 10 },  .{ 2051, 11 },
    .{ 4099, 12 }, .{ 8195, 13 }, .{ 16387, 14 }, .{ 32771, 15 }, .{ 65539, 16 },
};

pub const table_accuracy_log_max = struct {
    pub const literal = 9;
    pub const match = 9;
    pub const offset = 8;
};

pub const table_symbol_count_max = struct {
    pub const literal = 36;
    pub const match = 53;
    pub const offset = 32;
};

pub const default_accuracy_log = struct {
    pub const literal = 6;
    pub const match = 6;
    pub const offset = 5;
};
pub const table_size_max = struct {
    pub const literal = 1 << table_accuracy_log_max.literal;
    pub const match = 1 << table_accuracy_log_max.match;
    pub const offset = 1 << table_accuracy_log_max.offset;
};

fn testDecompress(gpa: std.mem.Allocator, compressed: []const u8) ![]u8 {
    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(gpa);

    var in: std.io.Reader = .fixed(compressed);
    var zstd_stream: Decompress = .init(&in, .{});
    try zstd_stream.reader().readRemainingArrayList(gpa, null, &out, .unlimited, default_window_len);

    return out.toOwnedSlice(gpa);
}

fn testExpectDecompress(uncompressed: []const u8, compressed: []const u8) !void {
    const gpa = std.testing.allocator;
    const result = try testDecompress(gpa, compressed);
    defer gpa.free(result);
    try std.testing.expectEqualSlices(u8, uncompressed, result);
}

fn testExpectDecompressError(err: anyerror, compressed: []const u8) !void {
    const gpa = std.testing.allocator;

    var out: std.ArrayListUnmanaged(u8) = .empty;
    defer out.deinit(gpa);

    var in: std.io.Reader = .fixed(compressed);
    var zstd_stream: Decompress = .init(&in, .{});
    try std.testing.expectError(
        error.ReadFailed,
        zstd_stream.reader().readRemainingArrayList(gpa, null, &out, .unlimited, default_window_len),
    );
    try std.testing.expectError(err, zstd_stream.err orelse {});
}

test Decompress {
    const uncompressed = @embedFile("testdata/rfc8478.txt");
    const compressed3 = @embedFile("testdata/rfc8478.txt.zst.3");
    const compressed19 = @embedFile("testdata/rfc8478.txt.zst.19");

    try testExpectDecompress(uncompressed, compressed3);
    try testExpectDecompress(uncompressed, compressed19);
}

test "zero sized raw block" {
    const input_raw =
        "\x28\xb5\x2f\xfd" ++ // zstandard frame magic number
        "\x20\x00" ++ // frame header: only single_segment_flag set, frame_content_size zero
        "\x01\x00\x00"; // block header with: last_block set, block_type raw, block_size zero
    try testExpectDecompress("", input_raw);
}

test "zero sized rle block" {
    const input_rle =
        "\x28\xb5\x2f\xfd" ++ // zstandard frame magic number
        "\x20\x00" ++ // frame header: only single_segment_flag set, frame_content_size zero
        "\x03\x00\x00" ++ // block header with: last_block set, block_type rle, block_size zero
        "\xaa"; // block_content
    try testExpectDecompress("", input_rle);
}

test "declared raw literals size too large" {
    const input_raw =
        "\x28\xb5\x2f\xfd" ++ // zstandard frame magic number
        "\x00\x00" ++ // frame header: everything unset, window descriptor zero
        "\x95\x00\x00" ++ // block header with: last_block set, block_type compressed, block_size 18
        "\xbc\xf3\xae" ++ // literals section header with: type raw, size_format 3, regenerated_size 716603
        "\xa5\x9f\xe3"; // some bytes of literal content - the content is shorter than regenerated_size

    // Note that the regenerated_size in the above input is larger than block maximum size, so the
    // block can't be valid as it is a raw literals block.
    try testExpectDecompressError(error.MalformedLiteralsSection, input_raw);
}
