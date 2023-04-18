const std = @import("../std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const os = std.os;
const fs = std.fs;
const mem = std.mem;
const wasi = std.os.wasi;

const ArenaAllocator = std.heap.ArenaAllocator;
const Dir = std.fs.Dir;
const IterableDir = std.fs.IterableDir;
const File = std.fs.File;
const tmpDir = testing.tmpDir;
const tmpIterableDir = testing.tmpIterableDir;

test "Dir.readLink" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Create some targets
    try tmp.dir.writeFile("file.txt", "nonsense");
    try tmp.dir.makeDir("subdir");

    {
        // Create symbolic link by path
        tmp.dir.symLink("file.txt", "symlink1", .{}) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return error.SkipZigTest,
            else => return err,
        };
        try testReadLink(tmp.dir, "file.txt", "symlink1");
    }
    {
        // Create symbolic link by path
        tmp.dir.symLink("subdir", "symlink2", .{ .is_directory = true }) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return error.SkipZigTest,
            else => return err,
        };
        try testReadLink(tmp.dir, "subdir", "symlink2");
    }
}

fn testReadLink(dir: Dir, target_path: []const u8, symlink_path: []const u8) !void {
    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const given = try dir.readLink(symlink_path, buffer[0..]);
    try testing.expect(mem.eql(u8, target_path, given));
}

test "accessAbsolute" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ "zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    try fs.accessAbsolute(base_path, .{});
}

test "openDirAbsolute" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("subdir");
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ "zig-cache", "tmp", tmp.sub_path[0..], "subdir" });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    {
        var dir = try fs.openDirAbsolute(base_path, .{});
        defer dir.close();
    }

    for ([_][]const u8{ ".", ".." }) |sub_path| {
        const dir_path = try fs.path.join(allocator, &[_][]const u8{ base_path, sub_path });
        defer allocator.free(dir_path);
        var dir = try fs.openDirAbsolute(dir_path, .{});
        defer dir.close();
    }
}

test "openDir cwd parent .." {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var dir = try fs.cwd().openDir("..", .{});
    defer dir.close();
}

test "readLinkAbsolute" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Create some targets
    try tmp.dir.writeFile("file.txt", "nonsense");
    try tmp.dir.makeDir("subdir");

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ "zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    {
        const target_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "file.txt" });
        const symlink_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "symlink1" });

        // Create symbolic link by path
        fs.symLinkAbsolute(target_path, symlink_path, .{}) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return error.SkipZigTest,
            else => return err,
        };
        try testReadLinkAbsolute(target_path, symlink_path);
    }
    {
        const target_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "subdir" });
        const symlink_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "symlink2" });

        // Create symbolic link by path
        fs.symLinkAbsolute(target_path, symlink_path, .{ .is_directory = true }) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return error.SkipZigTest,
            else => return err,
        };
        try testReadLinkAbsolute(target_path, symlink_path);
    }
}

fn testReadLinkAbsolute(target_path: []const u8, symlink_path: []const u8) !void {
    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const given = try fs.readLinkAbsolute(symlink_path, buffer[0..]);
    try testing.expect(mem.eql(u8, target_path, given));
}

test "Dir.Iterator" {
    var tmp_dir = tmpIterableDir(.{});
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.iterable_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.iterable_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var entries = std.ArrayList(IterableDir.Entry).init(allocator);

    // Create iterator.
    var iter = tmp_dir.iterable_dir.iterate();
    while (try iter.next()) |entry| {
        // We cannot just store `entry` as on Windows, we're re-using the name buffer
        // which means we'll actually share the `name` pointer between entries!
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(.{ .name = name, .kind = entry.kind });
    }

    try testing.expect(entries.items.len == 2); // note that the Iterator skips '.' and '..'
    try testing.expect(contains(&entries, .{ .name = "some_file", .kind = .File }));
    try testing.expect(contains(&entries, .{ .name = "some_dir", .kind = .Directory }));
}

test "Dir.Iterator many entries" {
    var tmp_dir = tmpIterableDir(.{});
    defer tmp_dir.cleanup();

    const num = 1024;
    var i: usize = 0;
    var buf: [4]u8 = undefined; // Enough to store "1024".
    while (i < num) : (i += 1) {
        const name = try std.fmt.bufPrint(&buf, "{}", .{i});
        const file = try tmp_dir.iterable_dir.dir.createFile(name, .{});
        file.close();
    }

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var entries = std.ArrayList(IterableDir.Entry).init(allocator);

    // Create iterator.
    var iter = tmp_dir.iterable_dir.iterate();
    while (try iter.next()) |entry| {
        // We cannot just store `entry` as on Windows, we're re-using the name buffer
        // which means we'll actually share the `name` pointer between entries!
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(.{ .name = name, .kind = entry.kind });
    }

    i = 0;
    while (i < num) : (i += 1) {
        const name = try std.fmt.bufPrint(&buf, "{}", .{i});
        try testing.expect(contains(&entries, .{ .name = name, .kind = .File }));
    }
}

test "Dir.Iterator twice" {
    var tmp_dir = tmpIterableDir(.{});
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.iterable_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.iterable_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        var entries = std.ArrayList(IterableDir.Entry).init(allocator);

        // Create iterator.
        var iter = tmp_dir.iterable_dir.iterate();
        while (try iter.next()) |entry| {
            // We cannot just store `entry` as on Windows, we're re-using the name buffer
            // which means we'll actually share the `name` pointer between entries!
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(.{ .name = name, .kind = entry.kind });
        }

        try testing.expect(entries.items.len == 2); // note that the Iterator skips '.' and '..'
        try testing.expect(contains(&entries, .{ .name = "some_file", .kind = .File }));
        try testing.expect(contains(&entries, .{ .name = "some_dir", .kind = .Directory }));
    }
}

test "Dir.Iterator reset" {
    var tmp_dir = tmpIterableDir(.{});
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.iterable_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.iterable_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create iterator.
    var iter = tmp_dir.iterable_dir.iterate();

    var i: u8 = 0;
    while (i < 2) : (i += 1) {
        var entries = std.ArrayList(IterableDir.Entry).init(allocator);

        while (try iter.next()) |entry| {
            // We cannot just store `entry` as on Windows, we're re-using the name buffer
            // which means we'll actually share the `name` pointer between entries!
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(.{ .name = name, .kind = entry.kind });
        }

        try testing.expect(entries.items.len == 2); // note that the Iterator skips '.' and '..'
        try testing.expect(contains(&entries, .{ .name = "some_file", .kind = .File }));
        try testing.expect(contains(&entries, .{ .name = "some_dir", .kind = .Directory }));

        iter.reset();
    }
}

test "Dir.Iterator but dir is deleted during iteration" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create directory and setup an iterator for it
    var iterable_subdir = try tmp.dir.makeOpenPathIterable("subdir", .{});
    defer iterable_subdir.close();

    var iterator = iterable_subdir.iterate();

    // Create something to iterate over within the subdir
    try tmp.dir.makePath("subdir/b");

    // Then, before iterating, delete the directory that we're iterating.
    // This is a contrived reproduction, but this could happen outside of the program, in another thread, etc.
    // If we get an error while trying to delete, we can skip this test (this will happen on platforms
    // like Windows which will give FileBusy if the directory is currently open for iteration).
    tmp.dir.deleteTree("subdir") catch return error.SkipZigTest;

    // Now, when we try to iterate, the next call should return null immediately.
    const entry = try iterator.next();
    try std.testing.expect(entry == null);

    // On Linux, we can opt-in to receiving a more specific error by calling `nextLinux`
    if (builtin.os.tag == .linux) {
        try std.testing.expectError(error.DirNotFound, iterator.nextLinux());
    }
}

fn entryEql(lhs: IterableDir.Entry, rhs: IterableDir.Entry) bool {
    return mem.eql(u8, lhs.name, rhs.name) and lhs.kind == rhs.kind;
}

fn contains(entries: *const std.ArrayList(IterableDir.Entry), el: IterableDir.Entry) bool {
    for (entries.items) |entry| {
        if (entryEql(entry, el)) return true;
    }
    return false;
}

test "Dir.realpath smoke test" {
    switch (builtin.os.tag) {
        .linux, .windows, .macos, .ios, .watchos, .tvos, .solaris => {},
        else => return error.SkipZigTest,
    }

    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    var file = try tmp_dir.dir.createFile("test_file", .{ .lock = File.Lock.Shared });
    // We need to close the file immediately as otherwise on Windows we'll end up
    // with a sharing violation.
    file.close();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ "zig-cache", "tmp", tmp_dir.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    // First, test non-alloc version
    {
        var buf1: [fs.MAX_PATH_BYTES]u8 = undefined;
        const file_path = try tmp_dir.dir.realpath("test_file", buf1[0..]);
        const expected_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "test_file" });

        try testing.expect(mem.eql(u8, file_path, expected_path));
    }

    // Next, test alloc version
    {
        const file_path = try tmp_dir.dir.realpathAlloc(allocator, "test_file");
        const expected_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "test_file" });

        try testing.expect(mem.eql(u8, file_path, expected_path));
    }
}

test "readAllAlloc" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    var file = try tmp_dir.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const buf1 = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(buf1);
    try testing.expect(buf1.len == 0);

    const write_buf: []const u8 = "this is a test.\nthis is a test.\nthis is a test.\nthis is a test.\n";
    try file.writeAll(write_buf);
    try file.seekTo(0);

    // max_bytes > file_size
    const buf2 = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(buf2);
    try testing.expectEqual(write_buf.len, buf2.len);
    try testing.expect(std.mem.eql(u8, write_buf, buf2));
    try file.seekTo(0);

    // max_bytes == file_size
    const buf3 = try file.readToEndAlloc(testing.allocator, write_buf.len);
    defer testing.allocator.free(buf3);
    try testing.expectEqual(write_buf.len, buf3.len);
    try testing.expect(std.mem.eql(u8, write_buf, buf3));
    try file.seekTo(0);

    // max_bytes < file_size
    try testing.expectError(error.FileTooBig, file.readToEndAlloc(testing.allocator, write_buf.len - 1));
}

test "directory operations on files" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    const test_file_name = "test_file";

    var file = try tmp_dir.dir.createFile(test_file_name, .{ .read = true });
    file.close();

    try testing.expectError(error.PathAlreadyExists, tmp_dir.dir.makeDir(test_file_name));
    try testing.expectError(error.NotDir, tmp_dir.dir.openDir(test_file_name, .{}));
    try testing.expectError(error.NotDir, tmp_dir.dir.deleteDir(test_file_name));

    switch (builtin.os.tag) {
        .wasi, .freebsd, .netbsd, .openbsd, .dragonfly => {},
        else => {
            const absolute_path = try tmp_dir.dir.realpathAlloc(testing.allocator, test_file_name);
            defer testing.allocator.free(absolute_path);

            try testing.expectError(error.PathAlreadyExists, fs.makeDirAbsolute(absolute_path));
            try testing.expectError(error.NotDir, fs.deleteDirAbsolute(absolute_path));
        },
    }

    // ensure the file still exists and is a file as a sanity check
    file = try tmp_dir.dir.openFile(test_file_name, .{});
    const stat = try file.stat();
    try testing.expect(stat.kind == .File);
    file.close();
}

test "file operations on directories" {
    // TODO: fix this test on FreeBSD. https://github.com/ziglang/zig/issues/1759
    if (builtin.os.tag == .freebsd) return error.SkipZigTest;

    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    const test_dir_name = "test_dir";

    try tmp_dir.dir.makeDir(test_dir_name);

    try testing.expectError(error.IsDir, tmp_dir.dir.createFile(test_dir_name, .{}));
    try testing.expectError(error.IsDir, tmp_dir.dir.deleteFile(test_dir_name));
    switch (builtin.os.tag) {
        // no error when reading a directory.
        .dragonfly, .netbsd => {},
        // Currently, WASI will return error.Unexpected (via ENOTCAPABLE) when attempting fd_read on a directory handle.
        // TODO: Re-enable on WASI once https://github.com/bytecodealliance/wasmtime/issues/1935 is resolved.
        .wasi => {},
        else => {
            try testing.expectError(error.IsDir, tmp_dir.dir.readFileAlloc(testing.allocator, test_dir_name, std.math.maxInt(usize)));
        },
    }
    // Note: The `.mode = .read_write` is necessary to ensure the error occurs on all platforms.
    // TODO: Add a read-only test as well, see https://github.com/ziglang/zig/issues/5732
    try testing.expectError(error.IsDir, tmp_dir.dir.openFile(test_dir_name, .{ .mode = .read_write }));

    switch (builtin.os.tag) {
        .wasi, .freebsd, .netbsd, .openbsd, .dragonfly => {},
        else => {
            const absolute_path = try tmp_dir.dir.realpathAlloc(testing.allocator, test_dir_name);
            defer testing.allocator.free(absolute_path);

            try testing.expectError(error.IsDir, fs.createFileAbsolute(absolute_path, .{}));
            try testing.expectError(error.IsDir, fs.deleteFileAbsolute(absolute_path));
        },
    }

    // ensure the directory still exists as a sanity check
    var dir = try tmp_dir.dir.openDir(test_dir_name, .{});
    dir.close();
}

test "deleteDir" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    // deleting a non-existent directory
    try testing.expectError(error.FileNotFound, tmp_dir.dir.deleteDir("test_dir"));

    var dir = try tmp_dir.dir.makeOpenPath("test_dir", .{});
    var file = try dir.createFile("test_file", .{});
    file.close();
    dir.close();

    // deleting a non-empty directory
    try testing.expectError(error.DirNotEmpty, tmp_dir.dir.deleteDir("test_dir"));

    dir = try tmp_dir.dir.openDir("test_dir", .{});
    try dir.deleteFile("test_file");
    dir.close();

    // deleting an empty directory
    try tmp_dir.dir.deleteDir("test_dir");
}

test "Dir.rename files" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    try testing.expectError(error.FileNotFound, tmp_dir.dir.rename("missing_file_name", "something_else"));

    // Renaming files
    const test_file_name = "test_file";
    const renamed_test_file_name = "test_file_renamed";
    var file = try tmp_dir.dir.createFile(test_file_name, .{ .read = true });
    file.close();
    try tmp_dir.dir.rename(test_file_name, renamed_test_file_name);

    // Ensure the file was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openFile(test_file_name, .{}));
    file = try tmp_dir.dir.openFile(renamed_test_file_name, .{});
    file.close();

    // Rename to self succeeds
    try tmp_dir.dir.rename(renamed_test_file_name, renamed_test_file_name);

    // Rename to existing file succeeds
    var existing_file = try tmp_dir.dir.createFile("existing_file", .{ .read = true });
    existing_file.close();
    try tmp_dir.dir.rename(renamed_test_file_name, "existing_file");

    try testing.expectError(error.FileNotFound, tmp_dir.dir.openFile(renamed_test_file_name, .{}));
    file = try tmp_dir.dir.openFile("existing_file", .{});
    file.close();
}

test "Dir.rename directories" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    // Renaming directories
    try tmp_dir.dir.makeDir("test_dir");
    try tmp_dir.dir.rename("test_dir", "test_dir_renamed");

    // Ensure the directory was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openDir("test_dir", .{}));
    var dir = try tmp_dir.dir.openDir("test_dir_renamed", .{});

    // Put a file in the directory
    var file = try dir.createFile("test_file", .{ .read = true });
    file.close();
    dir.close();

    try tmp_dir.dir.rename("test_dir_renamed", "test_dir_renamed_again");

    // Ensure the directory was renamed and the file still exists in it
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openDir("test_dir_renamed", .{}));
    dir = try tmp_dir.dir.openDir("test_dir_renamed_again", .{});
    file = try dir.openFile("test_file", .{});
    file.close();
    dir.close();
}

test "Dir.rename directory onto empty dir" {
    // TODO: Fix on Windows, see https://github.com/ziglang/zig/issues/6364
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.makeDir("test_dir");
    try tmp_dir.dir.makeDir("target_dir");
    try tmp_dir.dir.rename("test_dir", "target_dir");

    // Ensure the directory was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openDir("test_dir", .{}));
    var dir = try tmp_dir.dir.openDir("target_dir", .{});
    dir.close();
}

test "Dir.rename directory onto non-empty dir" {
    // TODO: Fix on Windows, see https://github.com/ziglang/zig/issues/6364
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.makeDir("test_dir");

    var target_dir = try tmp_dir.dir.makeOpenPath("target_dir", .{});
    var file = try target_dir.createFile("test_file", .{ .read = true });
    file.close();
    target_dir.close();

    // Rename should fail with PathAlreadyExists if target_dir is non-empty
    try testing.expectError(error.PathAlreadyExists, tmp_dir.dir.rename("test_dir", "target_dir"));

    // Ensure the directory was not renamed
    var dir = try tmp_dir.dir.openDir("test_dir", .{});
    dir.close();
}

test "Dir.rename file <-> dir" {
    // TODO: Fix on Windows, see https://github.com/ziglang/zig/issues/6364
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    var file = try tmp_dir.dir.createFile("test_file", .{ .read = true });
    file.close();
    try tmp_dir.dir.makeDir("test_dir");
    try testing.expectError(error.IsDir, tmp_dir.dir.rename("test_file", "test_dir"));
    try testing.expectError(error.NotDir, tmp_dir.dir.rename("test_dir", "test_file"));
}

test "rename" {
    var tmp_dir1 = tmpDir(.{});
    defer tmp_dir1.cleanup();

    var tmp_dir2 = tmpDir(.{});
    defer tmp_dir2.cleanup();

    // Renaming files
    const test_file_name = "test_file";
    const renamed_test_file_name = "test_file_renamed";
    var file = try tmp_dir1.dir.createFile(test_file_name, .{ .read = true });
    file.close();
    try fs.rename(tmp_dir1.dir, test_file_name, tmp_dir2.dir, renamed_test_file_name);

    // ensure the file was renamed
    try testing.expectError(error.FileNotFound, tmp_dir1.dir.openFile(test_file_name, .{}));
    file = try tmp_dir2.dir.openFile(renamed_test_file_name, .{});
    file.close();
}

test "renameAbsolute" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ "zig-cache", "tmp", tmp_dir.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    try testing.expectError(error.FileNotFound, fs.renameAbsolute(
        try fs.path.join(allocator, &[_][]const u8{ base_path, "missing_file_name" }),
        try fs.path.join(allocator, &[_][]const u8{ base_path, "something_else" }),
    ));

    // Renaming files
    const test_file_name = "test_file";
    const renamed_test_file_name = "test_file_renamed";
    var file = try tmp_dir.dir.createFile(test_file_name, .{ .read = true });
    file.close();
    try fs.renameAbsolute(
        try fs.path.join(allocator, &[_][]const u8{ base_path, test_file_name }),
        try fs.path.join(allocator, &[_][]const u8{ base_path, renamed_test_file_name }),
    );

    // ensure the file was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openFile(test_file_name, .{}));
    file = try tmp_dir.dir.openFile(renamed_test_file_name, .{});
    const stat = try file.stat();
    try testing.expect(stat.kind == .File);
    file.close();

    // Renaming directories
    const test_dir_name = "test_dir";
    const renamed_test_dir_name = "test_dir_renamed";
    try tmp_dir.dir.makeDir(test_dir_name);
    try fs.renameAbsolute(
        try fs.path.join(allocator, &[_][]const u8{ base_path, test_dir_name }),
        try fs.path.join(allocator, &[_][]const u8{ base_path, renamed_test_dir_name }),
    );

    // ensure the directory was renamed
    try testing.expectError(error.FileNotFound, tmp_dir.dir.openDir(test_dir_name, .{}));
    var dir = try tmp_dir.dir.openDir(renamed_test_dir_name, .{});
    dir.close();
}

test "openSelfExe" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const self_exe_file = try std.fs.openSelfExe(.{});
    self_exe_file.close();
}

test "makePath, put some files in it, deleteTree" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "c");
    try tmp.dir.writeFile("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "c" ++ fs.path.sep_str ++ "file.txt", "nonsense");
    try tmp.dir.writeFile("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "file2.txt", "blah");
    try tmp.dir.deleteTree("os_test_tmp");
    if (tmp.dir.openDir("os_test_tmp", .{})) |dir| {
        _ = dir;
        @panic("expected error");
    } else |err| {
        try testing.expect(err == error.FileNotFound);
    }
}

test "makePath, put some files in it, deleteTreeMinStackSize" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "c");
    try tmp.dir.writeFile("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "c" ++ fs.path.sep_str ++ "file.txt", "nonsense");
    try tmp.dir.writeFile("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "file2.txt", "blah");
    try tmp.dir.deleteTreeMinStackSize("os_test_tmp");
    if (tmp.dir.openDir("os_test_tmp", .{})) |dir| {
        _ = dir;
        @panic("expected error");
    } else |err| {
        try testing.expect(err == error.FileNotFound);
    }
}

test "makePath in a directory that no longer exists" {
    if (builtin.os.tag == .windows) return error.SkipZigTest; // Windows returns FileBusy if attempting to remove an open dir

    var tmp = tmpDir(.{});
    defer tmp.cleanup();
    try tmp.parent_dir.deleteTree(&tmp.sub_path);

    try testing.expectError(error.FileNotFound, tmp.dir.makePath("sub-path"));
}

fn testFilenameLimits(iterable_dir: IterableDir, maxed_filename: []const u8) !void {
    // setup, create a dir and a nested file both with maxed filenames, and walk the dir
    {
        var maxed_dir = try iterable_dir.dir.makeOpenPath(maxed_filename, .{});
        defer maxed_dir.close();

        try maxed_dir.writeFile(maxed_filename, "");

        var walker = try iterable_dir.walk(testing.allocator);
        defer walker.deinit();

        var count: usize = 0;
        while (try walker.next()) |entry| {
            try testing.expectEqualStrings(maxed_filename, entry.basename);
            count += 1;
        }
        try testing.expectEqual(@as(usize, 2), count);
    }

    // ensure that we can delete the tree
    try iterable_dir.dir.deleteTree(maxed_filename);
}

test "max file name component lengths" {
    var tmp = tmpIterableDir(.{});
    defer tmp.cleanup();

    if (builtin.os.tag == .windows) {
        // € is the character with the largest codepoint that is encoded as a single u16 in UTF-16,
        // so Windows allows for NAME_MAX of them
        const maxed_windows_filename = ("€".*) ** std.os.windows.NAME_MAX;
        try testFilenameLimits(tmp.iterable_dir, &maxed_windows_filename);
    } else if (builtin.os.tag == .wasi) {
        // On WASI, the maxed filename depends on the host OS, so in order for this test to
        // work on any host, we need to use a length that will work for all platforms
        // (i.e. the minimum MAX_NAME_BYTES of all supported platforms).
        const maxed_wasi_filename = [_]u8{'1'} ** 255;
        try testFilenameLimits(tmp.iterable_dir, &maxed_wasi_filename);
    } else {
        const maxed_ascii_filename = [_]u8{'1'} ** std.fs.MAX_NAME_BYTES;
        try testFilenameLimits(tmp.iterable_dir, &maxed_ascii_filename);
    }
}

test "writev, readv" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const line1 = "line1\n";
    const line2 = "line2\n";

    var buf1: [line1.len]u8 = undefined;
    var buf2: [line2.len]u8 = undefined;
    var write_vecs = [_]std.os.iovec_const{
        .{
            .iov_base = line1,
            .iov_len = line1.len,
        },
        .{
            .iov_base = line2,
            .iov_len = line2.len,
        },
    };
    var read_vecs = [_]std.os.iovec{
        .{
            .iov_base = &buf2,
            .iov_len = buf2.len,
        },
        .{
            .iov_base = &buf1,
            .iov_len = buf1.len,
        },
    };

    var src_file = try tmp.dir.createFile("test.txt", .{ .read = true });
    defer src_file.close();

    try src_file.writevAll(&write_vecs);
    try testing.expectEqual(@as(u64, line1.len + line2.len), try src_file.getEndPos());
    try src_file.seekTo(0);
    const read = try src_file.readvAll(&read_vecs);
    try testing.expectEqual(@as(usize, line1.len + line2.len), read);
    try testing.expectEqualStrings(&buf1, "line2\n");
    try testing.expectEqualStrings(&buf2, "line1\n");
}

test "pwritev, preadv" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const line1 = "line1\n";
    const line2 = "line2\n";

    var buf1: [line1.len]u8 = undefined;
    var buf2: [line2.len]u8 = undefined;
    var write_vecs = [_]std.os.iovec_const{
        .{
            .iov_base = line1,
            .iov_len = line1.len,
        },
        .{
            .iov_base = line2,
            .iov_len = line2.len,
        },
    };
    var read_vecs = [_]std.os.iovec{
        .{
            .iov_base = &buf2,
            .iov_len = buf2.len,
        },
        .{
            .iov_base = &buf1,
            .iov_len = buf1.len,
        },
    };

    var src_file = try tmp.dir.createFile("test.txt", .{ .read = true });
    defer src_file.close();

    try src_file.pwritevAll(&write_vecs, 16);
    try testing.expectEqual(@as(u64, 16 + line1.len + line2.len), try src_file.getEndPos());
    const read = try src_file.preadvAll(&read_vecs, 16);
    try testing.expectEqual(@as(usize, line1.len + line2.len), read);
    try testing.expectEqualStrings(&buf1, "line2\n");
    try testing.expectEqualStrings(&buf2, "line1\n");
}

test "access file" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp");
    if (tmp.dir.access("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", .{})) |ok| {
        _ = ok;
        @panic("expected error");
    } else |err| {
        try testing.expect(err == error.FileNotFound);
    }

    try tmp.dir.writeFile("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", "");
    try tmp.dir.access("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", .{});
    try tmp.dir.deleteTree("os_test_tmp");
}

test "sendfile" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp");
    defer tmp.dir.deleteTree("os_test_tmp") catch {};

    var dir = try tmp.dir.openDir("os_test_tmp", .{});
    defer dir.close();

    const line1 = "line1\n";
    const line2 = "second line\n";
    var vecs = [_]std.os.iovec_const{
        .{
            .iov_base = line1,
            .iov_len = line1.len,
        },
        .{
            .iov_base = line2,
            .iov_len = line2.len,
        },
    };

    var src_file = try dir.createFile("sendfile1.txt", .{ .read = true });
    defer src_file.close();

    try src_file.writevAll(&vecs);

    var dest_file = try dir.createFile("sendfile2.txt", .{ .read = true });
    defer dest_file.close();

    const header1 = "header1\n";
    const header2 = "second header\n";
    const trailer1 = "trailer1\n";
    const trailer2 = "second trailer\n";
    var hdtr = [_]std.os.iovec_const{
        .{
            .iov_base = header1,
            .iov_len = header1.len,
        },
        .{
            .iov_base = header2,
            .iov_len = header2.len,
        },
        .{
            .iov_base = trailer1,
            .iov_len = trailer1.len,
        },
        .{
            .iov_base = trailer2,
            .iov_len = trailer2.len,
        },
    };

    var written_buf: [100]u8 = undefined;
    try dest_file.writeFileAll(src_file, .{
        .in_offset = 1,
        .in_len = 10,
        .headers_and_trailers = &hdtr,
        .header_count = 2,
    });
    const amt = try dest_file.preadAll(&written_buf, 0);
    try testing.expect(mem.eql(u8, written_buf[0..amt], "header1\nsecond header\nine1\nsecontrailer1\nsecond trailer\n"));
}

test "copyRangeAll" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp");
    defer tmp.dir.deleteTree("os_test_tmp") catch {};

    var dir = try tmp.dir.openDir("os_test_tmp", .{});
    defer dir.close();

    var src_file = try dir.createFile("file1.txt", .{ .read = true });
    defer src_file.close();

    const data = "u6wj+JmdF3qHsFPE BUlH2g4gJCmEz0PP";
    try src_file.writeAll(data);

    var dest_file = try dir.createFile("file2.txt", .{ .read = true });
    defer dest_file.close();

    var written_buf: [100]u8 = undefined;
    _ = try src_file.copyRangeAll(0, dest_file, 0, data.len);

    const amt = try dest_file.preadAll(&written_buf, 0);
    try testing.expect(mem.eql(u8, written_buf[0..amt], data));
}

test "fs.copyFile" {
    const data = "u6wj+JmdF3qHsFPE BUlH2g4gJCmEz0PP";
    const src_file = "tmp_test_copy_file.txt";
    const dest_file = "tmp_test_copy_file2.txt";
    const dest_file2 = "tmp_test_copy_file3.txt";

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(src_file, data);
    defer tmp.dir.deleteFile(src_file) catch {};

    try tmp.dir.copyFile(src_file, tmp.dir, dest_file, .{});
    defer tmp.dir.deleteFile(dest_file) catch {};

    try tmp.dir.copyFile(src_file, tmp.dir, dest_file2, .{ .override_mode = File.default_mode });
    defer tmp.dir.deleteFile(dest_file2) catch {};

    try expectFileContents(tmp.dir, dest_file, data);
    try expectFileContents(tmp.dir, dest_file2, data);
}

fn expectFileContents(dir: Dir, file_path: []const u8, data: []const u8) !void {
    const contents = try dir.readFileAlloc(testing.allocator, file_path, 1000);
    defer testing.allocator.free(contents);

    try testing.expectEqualSlices(u8, data, contents);
}

test "AtomicFile" {
    const test_out_file = "tmp_atomic_file_test_dest.txt";
    const test_content =
        \\ hello!
        \\ this is a test file
    ;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    {
        var af = try tmp.dir.atomicFile(test_out_file, .{});
        defer af.deinit();
        try af.file.writeAll(test_content);
        try af.finish();
    }
    const content = try tmp.dir.readFileAlloc(testing.allocator, test_out_file, 9999);
    defer testing.allocator.free(content);
    try testing.expect(mem.eql(u8, content, test_content));

    try tmp.dir.deleteFile(test_out_file);
}

test "realpath" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    try testing.expectError(error.FileNotFound, fs.realpath("definitely_bogus_does_not_exist1234", &buf));
}

test "open file with exclusive nonblocking lock twice" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const filename = "file_nonblocking_lock_test.txt";

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file1 = try tmp.dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    defer file1.close();

    const file2 = tmp.dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    try testing.expectError(error.WouldBlock, file2);
}

test "open file with shared and exclusive nonblocking lock" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const filename = "file_nonblocking_lock_test.txt";

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file1 = try tmp.dir.createFile(filename, .{ .lock = .Shared, .lock_nonblocking = true });
    defer file1.close();

    const file2 = tmp.dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    try testing.expectError(error.WouldBlock, file2);
}

test "open file with exclusive and shared nonblocking lock" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const filename = "file_nonblocking_lock_test.txt";

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file1 = try tmp.dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    defer file1.close();

    const file2 = tmp.dir.createFile(filename, .{ .lock = .Shared, .lock_nonblocking = true });
    try testing.expectError(error.WouldBlock, file2);
}

test "open file with exclusive lock twice, make sure second lock waits" {
    if (builtin.single_threaded) return error.SkipZigTest;

    if (std.io.is_async) {
        // This test starts its own threads and is not compatible with async I/O.
        return error.SkipZigTest;
    }

    const filename = "file_lock_test.txt";

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(filename, .{ .lock = .Exclusive });
    errdefer file.close();

    const S = struct {
        fn checkFn(dir: *fs.Dir, started: *std.Thread.ResetEvent, locked: *std.Thread.ResetEvent) !void {
            started.set();
            const file1 = try dir.createFile(filename, .{ .lock = .Exclusive });

            locked.set();
            file1.close();
        }
    };

    var started = std.Thread.ResetEvent{};
    var locked = std.Thread.ResetEvent{};

    const t = try std.Thread.spawn(.{}, S.checkFn, .{
        &tmp.dir,
        &started,
        &locked,
    });
    defer t.join();

    // Wait for the spawned thread to start trying to acquire the exclusive file lock.
    // Then wait a bit to make sure that can't acquire it since we currently hold the file lock.
    started.wait();
    try testing.expectError(error.Timeout, locked.timedWait(10 * std.time.ns_per_ms));

    // Release the file lock which should unlock the thread to lock it and set the locked event.
    file.close();
    locked.wait();
}

test "open file with exclusive nonblocking lock twice (absolute paths)" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var random_bytes: [12]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);

    var random_b64: [fs.base64_encoder.calcSize(random_bytes.len)]u8 = undefined;
    _ = fs.base64_encoder.encode(&random_b64, &random_bytes);

    const sub_path = random_b64 ++ "-zig-test-absolute-paths.txt";

    const gpa = testing.allocator;

    const cwd = try std.process.getCwdAlloc(gpa);
    defer gpa.free(cwd);

    const filename = try fs.path.resolve(gpa, &[_][]const u8{ cwd, sub_path });
    defer gpa.free(filename);

    const file1 = try fs.createFileAbsolute(filename, .{
        .lock = .Exclusive,
        .lock_nonblocking = true,
    });

    const file2 = fs.createFileAbsolute(filename, .{
        .lock = .Exclusive,
        .lock_nonblocking = true,
    });
    file1.close();
    try testing.expectError(error.WouldBlock, file2);

    try fs.deleteFileAbsolute(filename);
}

test "walker" {
    if (builtin.os.tag == .wasi and builtin.link_libc) return error.SkipZigTest;

    var tmp = tmpIterableDir(.{});
    defer tmp.cleanup();

    // iteration order of walker is undefined, so need lookup maps to check against

    const expected_paths = std.ComptimeStringMap(void, .{
        .{"dir1"},
        .{"dir2"},
        .{"dir3"},
        .{"dir4"},
        .{"dir3" ++ std.fs.path.sep_str ++ "sub1"},
        .{"dir3" ++ std.fs.path.sep_str ++ "sub2"},
        .{"dir3" ++ std.fs.path.sep_str ++ "sub2" ++ std.fs.path.sep_str ++ "subsub1"},
    });

    const expected_basenames = std.ComptimeStringMap(void, .{
        .{"dir1"},
        .{"dir2"},
        .{"dir3"},
        .{"dir4"},
        .{"sub1"},
        .{"sub2"},
        .{"subsub1"},
    });

    for (expected_paths.kvs) |kv| {
        try tmp.iterable_dir.dir.makePath(kv.key);
    }

    var walker = try tmp.iterable_dir.walk(testing.allocator);
    defer walker.deinit();

    var num_walked: usize = 0;
    while (try walker.next()) |entry| {
        testing.expect(expected_basenames.has(entry.basename)) catch |err| {
            std.debug.print("found unexpected basename: {s}\n", .{std.fmt.fmtSliceEscapeLower(entry.basename)});
            return err;
        };
        testing.expect(expected_paths.has(entry.path)) catch |err| {
            std.debug.print("found unexpected path: {s}\n", .{std.fmt.fmtSliceEscapeLower(entry.path)});
            return err;
        };
        // make sure that the entry.dir is the containing dir
        var entry_dir = try entry.dir.openDir(entry.basename, .{});
        defer entry_dir.close();
        num_walked += 1;
    }
    try testing.expectEqual(expected_paths.kvs.len, num_walked);
}

test "walker without fully iterating" {
    if (builtin.os.tag == .wasi and builtin.link_libc) return error.SkipZigTest;

    var tmp = tmpIterableDir(.{});
    defer tmp.cleanup();

    var walker = try tmp.iterable_dir.walk(testing.allocator);
    defer walker.deinit();

    // Create 2 directories inside the tmp directory, but then only iterate once before breaking.
    // This ensures that walker doesn't try to close the initial directory when not fully iterating.

    try tmp.iterable_dir.dir.makePath("a");
    try tmp.iterable_dir.dir.makePath("b");

    var num_walked: usize = 0;
    while (try walker.next()) |_| {
        num_walked += 1;
        break;
    }
    try testing.expectEqual(@as(usize, 1), num_walked);
}

test ". and .. in fs.Dir functions" {
    if (builtin.os.tag == .wasi and builtin.link_libc) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makeDir("./subdir");
    try tmp.dir.access("./subdir", .{});
    var created_subdir = try tmp.dir.openDir("./subdir", .{});
    created_subdir.close();

    const created_file = try tmp.dir.createFile("./subdir/../file", .{});
    created_file.close();
    try tmp.dir.access("./subdir/../file", .{});

    try tmp.dir.copyFile("./subdir/../file", tmp.dir, "./subdir/../copy", .{});
    try tmp.dir.rename("./subdir/../copy", "./subdir/../rename");
    const renamed_file = try tmp.dir.openFile("./subdir/../rename", .{});
    renamed_file.close();
    try tmp.dir.deleteFile("./subdir/../rename");

    try tmp.dir.writeFile("./subdir/../update", "something");
    const prev_status = try tmp.dir.updateFile("./subdir/../file", tmp.dir, "./subdir/../update", .{});
    try testing.expectEqual(fs.PrevStatus.stale, prev_status);

    try tmp.dir.deleteDir("./subdir");
}

test ". and .. in absolute functions" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ "zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const subdir_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "./subdir" });
    try fs.makeDirAbsolute(subdir_path);
    try fs.accessAbsolute(subdir_path, .{});
    var created_subdir = try fs.openDirAbsolute(subdir_path, .{});
    created_subdir.close();

    const created_file_path = try fs.path.join(allocator, &[_][]const u8{ subdir_path, "../file" });
    const created_file = try fs.createFileAbsolute(created_file_path, .{});
    created_file.close();
    try fs.accessAbsolute(created_file_path, .{});

    const copied_file_path = try fs.path.join(allocator, &[_][]const u8{ subdir_path, "../copy" });
    try fs.copyFileAbsolute(created_file_path, copied_file_path, .{});
    const renamed_file_path = try fs.path.join(allocator, &[_][]const u8{ subdir_path, "../rename" });
    try fs.renameAbsolute(copied_file_path, renamed_file_path);
    const renamed_file = try fs.openFileAbsolute(renamed_file_path, .{});
    renamed_file.close();
    try fs.deleteFileAbsolute(renamed_file_path);

    const update_file_path = try fs.path.join(allocator, &[_][]const u8{ subdir_path, "../update" });
    const update_file = try fs.createFileAbsolute(update_file_path, .{});
    try update_file.writeAll("something");
    update_file.close();
    const prev_status = try fs.updateFileAbsolute(created_file_path, update_file_path, .{});
    try testing.expectEqual(fs.PrevStatus.stale, prev_status);

    try fs.deleteDirAbsolute(subdir_path);
}

test "chmod" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .mode = 0o600 });
    defer file.close();
    try testing.expect((try file.stat()).mode & 0o7777 == 0o600);

    try file.chmod(0o644);
    try testing.expect((try file.stat()).mode & 0o7777 == 0o644);

    try tmp.dir.makeDir("test_dir");
    var iterable_dir = try tmp.dir.openIterableDir("test_dir", .{});
    defer iterable_dir.close();

    try iterable_dir.chmod(0o700);
    try testing.expect((try iterable_dir.dir.stat()).mode & 0o7777 == 0o700);
}

test "chown" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{});
    defer file.close();
    try file.chown(null, null);

    try tmp.dir.makeDir("test_dir");

    var iterable_dir = try tmp.dir.openIterableDir("test_dir", .{});
    defer iterable_dir.close();
    try iterable_dir.chown(null, null);
}

test "File.Metadata" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const metadata = try file.metadata();
    try testing.expect(metadata.kind() == .File);
    try testing.expect(metadata.size() == 0);
    _ = metadata.accessed();
    _ = metadata.modified();
    _ = metadata.created();
}

test "File.Permissions" {
    if (builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const metadata = try file.metadata();
    var permissions = metadata.permissions();

    try testing.expect(!permissions.readOnly());
    permissions.setReadOnly(true);
    try testing.expect(permissions.readOnly());

    try file.setPermissions(permissions);
    const new_permissions = (try file.metadata()).permissions();
    try testing.expect(new_permissions.readOnly());

    // Must be set to non-read-only to delete
    permissions.setReadOnly(false);
    try file.setPermissions(permissions);
}

test "File.PermissionsUnix" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test_file", .{ .mode = 0o666, .read = true });
    defer file.close();

    const metadata = try file.metadata();
    var permissions = metadata.permissions();

    permissions.setReadOnly(true);
    try testing.expect(permissions.readOnly());
    try testing.expect(!permissions.inner.unixHas(.user, .write));
    permissions.inner.unixSet(.user, .{ .write = true });
    try testing.expect(!permissions.readOnly());
    try testing.expect(permissions.inner.unixHas(.user, .write));
    try testing.expect(permissions.inner.mode & 0o400 != 0);

    permissions.setReadOnly(true);
    try file.setPermissions(permissions);
    permissions = (try file.metadata()).permissions();
    try testing.expect(permissions.readOnly());

    // Must be set to non-read-only to delete
    permissions.setReadOnly(false);
    try file.setPermissions(permissions);

    const permissions_unix = File.PermissionsUnix.unixNew(0o754);
    try testing.expect(permissions_unix.unixHas(.user, .execute));
    try testing.expect(!permissions_unix.unixHas(.other, .execute));
}

test "delete a read-only file on windows" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();
    const file = try tmp.dir.createFile("test_file", .{ .read = true });
    // Create a file and make it read-only
    const metadata = try file.metadata();
    var permissions = metadata.permissions();
    permissions.setReadOnly(true);
    try file.setPermissions(permissions);
    try testing.expectError(error.AccessDenied, tmp.dir.deleteFile("test_file"));
    // Now make the file not read-only
    permissions.setReadOnly(false);
    try file.setPermissions(permissions);
    file.close();
    try tmp.dir.deleteFile("test_file");
}
