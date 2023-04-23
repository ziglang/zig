const std = @import("std");
const mem = std.mem;
const tar = std.tar;
const testing = std.testing;
const talloc = testing.allocator;
const builtin = @import("builtin");
const test_common = @import("test_common.zig");

test "std.tar decompress testdata" {
    // skip due to 'incorrect alignment', maybe the same as
    // https://github.com/ziglang/zig/issues/14036
    if (builtin.os.tag == .windows and builtin.mode == .Debug)
        return error.SkipZigTest;

    const test_files = [_][]const u8{
        "xattrs.tar",
        "gnu-long-nul.tar",
        "v7.tar",
        "pax-bad-hdr-file.tar",
        "pax-global-records.tar",
        "star.tar",
        "pax-multi-hdrs.tar",
        "gnu.tar",
        "gnu-utf8.tar",
        "trailing-slash.tar",
        "pax.tar",
        "nil-uid.tar",
        "ustar-file-devs.tar",
        "pax-pos-size-file.tar",
        "hardlink.tar",
        "pax-records.tar",
        "gnu-multi-hdrs.tar",
        "hardlink.tar",
        "dir-symlink.tar",
    };

    inline for (test_files) |test_file| {
        var fbs = try test_common.decompressGz("testdata/" ++ test_file ++ ".gz", talloc);
        defer talloc.free(fbs.buffer);
        try testDecompressTarToTmp(&fbs, .{ .mode_mode = .ignore });
        fbs.reset();
        try testDecompressTarToTmp(&fbs, .{ .mode_mode = .executable_bit_only });
    }
}

fn testDecompressTarToTmp(fbs: *std.io.FixedBufferStream([]u8), options: tar.Options) !void {
    var tmpdir = testing.tmpDir(.{});
    defer tmpdir.cleanup();
    try tar.pipeToFileSystem(talloc, tmpdir.dir, fbs.reader(), options);
}
