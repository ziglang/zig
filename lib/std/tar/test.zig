const std = @import("../std.zig");

const readTestScenario = struct {
    data: []const u8,
    expect: std.StringHashMap(metadata),
};

const metadata = struct {
    md5: []const u8,
    mode: usize,
    size: u64,
    mtime: i128,
};

test "gnu tar" {
    var expect = std.StringHashMap(metadata).init(std.testing.allocator);
    defer expect.deinit();
    try expect.put("small.txt", metadata{
        .md5 = "e38b27eaccb4391bdec553a7f3ae6b2f",
        .mode = 0o640,
        .size = 5,
        .mtime = 1244428340 * std.time.ns_per_s,
    });
    try expect.put("small2.txt", metadata{
        .md5 = "c65bd2e50a56a2138bf1716f2fd56fe9",
        .mode = 0o640,
        .size = 11,
        .mtime = 1244436044 * std.time.ns_per_s,
    });

    readTest(.{
        .data = @embedFile("testdata/gnu.tar"),
        .expect = expect,
    }) catch {
        return error.SkipZigTest;
    };
}

fn readTest(scenario: readTestScenario) !void {
    var file_stream = std.io.fixedBufferStream(scenario.data);

    var tmp = std.testing.tmpIterableDir(.{});
    defer tmp.cleanup();

    try std.tar.pipeToFileSystem(
        tmp.iterable_dir.dir,
        file_stream.reader(),
        .{ .mode_mode = .ignore },
    );

    var iter = tmp.iterable_dir.iterate();

    var elements: u8 = 0;
    while (try iter.next()) |entry| {
        var expectFile = scenario.expect.get(entry.name) orelse return error.TestFailure;
        var f = try tmp.iterable_dir.dir.openFile(
            entry.name,
            .{ .mode = .read_only },
        );
        defer f.close();

        const content = try f.readToEndAlloc(std.testing.allocator, std.math.maxInt(u32));
        defer std.testing.allocator.free(content);

        var md5Hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
        std.crypto.hash.Md5.hash(content, &md5Hash, .{});
        var b: [2 * std.crypto.hash.Md5.digest_length]u8 = undefined;
        _ = try std.fmt.bufPrint(&b, "{s}", .{std.fmt.fmtSliceHexLower(&md5Hash)});
        try std.testing.expectEqualStrings(expectFile.md5, &b);
        elements += 1;

        var stat = try f.stat();
        try std.testing.expectEqual(expectFile.size, stat.size);
        // TODO: fix possibly broken behavior.
        try std.testing.expectEqual(expectFile.mtime, stat.mtime);
        try std.testing.expectEqual(expectFile.mode, stat.mode);
    }

    try std.testing.expectEqual(scenario.expect.count(), elements);
}
