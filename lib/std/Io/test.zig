const std = @import("std");
const io = std.io;
const DefaultPrng = std.Random.DefaultPrng;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const mem = std.mem;
const fs = std.fs;
const File = std.fs.File;
const native_endian = @import("builtin").target.cpu.arch.endian();

const tmpDir = std.testing.tmpDir;

test "write a file, read it, then delete it" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var data: [1024]u8 = undefined;
    var prng = DefaultPrng.init(std.testing.random_seed);
    const random = prng.random();
    random.bytes(data[0..]);
    const tmp_file_name = "temp_test_file.txt";
    {
        var file = try tmp.dir.createFile(tmp_file_name, .{});
        defer file.close();

        var file_writer = file.writer(&.{});
        const st = &file_writer.interface;
        try st.print("begin", .{});
        try st.writeAll(&data);
        try st.print("end", .{});
        try st.flush();
    }

    {
        // Make sure the exclusive flag is honored.
        try expectError(File.OpenError.PathAlreadyExists, tmp.dir.createFile(tmp_file_name, .{ .exclusive = true }));
    }

    {
        var file = try tmp.dir.openFile(tmp_file_name, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const expected_file_size: u64 = "begin".len + data.len + "end".len;
        try expectEqual(expected_file_size, file_size);

        var file_buffer: [1024]u8 = undefined;
        var file_reader = file.reader(&file_buffer);
        const contents = try file_reader.interface.allocRemaining(std.testing.allocator, .limited(2 * 1024));
        defer std.testing.allocator.free(contents);

        try expect(mem.eql(u8, contents[0.."begin".len], "begin"));
        try expect(mem.eql(u8, contents["begin".len .. contents.len - "end".len], &data));
        try expect(mem.eql(u8, contents[contents.len - "end".len ..], "end"));
    }
    try tmp.dir.deleteFile(tmp_file_name);
}

test "File seek ops" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const tmp_file_name = "temp_test_file.txt";
    var file = try tmp.dir.createFile(tmp_file_name, .{});
    defer file.close();

    try file.writeAll(&([_]u8{0x55} ** 8192));

    // Seek to the end
    try file.seekFromEnd(0);
    try expect((try file.getPos()) == try file.getEndPos());
    // Negative delta
    try file.seekBy(-4096);
    try expect((try file.getPos()) == 4096);
    // Positive delta
    try file.seekBy(10);
    try expect((try file.getPos()) == 4106);
    // Absolute position
    try file.seekTo(1234);
    try expect((try file.getPos()) == 1234);
}

test "setEndPos" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const tmp_file_name = "temp_test_file.txt";
    var file = try tmp.dir.createFile(tmp_file_name, .{});
    defer file.close();

    // Verify that the file size changes and the file offset is not moved
    try std.testing.expect((try file.getEndPos()) == 0);
    try std.testing.expect((try file.getPos()) == 0);
    try file.setEndPos(8192);
    try std.testing.expect((try file.getEndPos()) == 8192);
    try std.testing.expect((try file.getPos()) == 0);
    try file.seekTo(100);
    try file.setEndPos(4096);
    try std.testing.expect((try file.getEndPos()) == 4096);
    try std.testing.expect((try file.getPos()) == 100);
    try file.setEndPos(0);
    try std.testing.expect((try file.getEndPos()) == 0);
    try std.testing.expect((try file.getPos()) == 100);
}

test "updateTimes" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const tmp_file_name = "just_a_temporary_file.txt";
    var file = try tmp.dir.createFile(tmp_file_name, .{ .read = true });
    defer file.close();

    const stat_old = try file.stat();
    // Set atime and mtime to 5s before
    try file.updateTimes(
        stat_old.atime - 5 * std.time.ns_per_s,
        stat_old.mtime - 5 * std.time.ns_per_s,
    );
    const stat_new = try file.stat();
    try expect(stat_new.atime < stat_old.atime);
    try expect(stat_new.mtime < stat_old.mtime);
}

test "GenericReader methods can return error.EndOfStream" {
    // https://github.com/ziglang/zig/issues/17733
    var fbs = std.io.fixedBufferStream("");
    try std.testing.expectError(
        error.EndOfStream,
        fbs.reader().readEnum(enum(u8) { a, b }, .little),
    );
    try std.testing.expectError(
        error.EndOfStream,
        fbs.reader().isBytes("foo"),
    );
}

test "Adapted DeprecatedReader EndOfStream" {
    var fbs: io.FixedBufferStream([]const u8) = .{ .buffer = &.{}, .pos = 0 };
    const reader = fbs.reader();
    var buf: [1]u8 = undefined;
    var adapted = reader.adaptToNewApi(&buf);
    try std.testing.expectError(error.EndOfStream, adapted.new_interface.takeByte());
}
