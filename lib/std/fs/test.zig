const std = @import("../std.zig");
const testing = std.testing;
const builtin = std.builtin;
const fs = std.fs;
const mem = std.mem;
const wasi = std.os.wasi;

const ArenaAllocator = std.heap.ArenaAllocator;
const Dir = std.fs.Dir;
const File = std.fs.File;
const tmpDir = testing.tmpDir;

test "Dir.Iterator" {
    var tmp_dir = tmpDir(.{ .iterate = true });
    defer tmp_dir.cleanup();

    // First, create a couple of entries to iterate over.
    const file = try tmp_dir.dir.createFile("some_file", .{});
    file.close();

    try tmp_dir.dir.makeDir("some_dir");

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var entries = std.ArrayList(Dir.Entry).init(&arena.allocator);

    // Create iterator.
    var iter = tmp_dir.dir.iterate();
    while (try iter.next()) |entry| {
        // We cannot just store `entry` as on Windows, we're re-using the name buffer
        // which means we'll actually share the `name` pointer between entries!
        const name = try arena.allocator.dupe(u8, entry.name);
        try entries.append(Dir.Entry{ .name = name, .kind = entry.kind });
    }

    testing.expect(entries.items.len == 2); // note that the Iterator skips '.' and '..'
    testing.expect(contains(&entries, Dir.Entry{ .name = "some_file", .kind = Dir.Entry.Kind.File }));
    testing.expect(contains(&entries, Dir.Entry{ .name = "some_dir", .kind = Dir.Entry.Kind.Directory }));
}

fn entry_eql(lhs: Dir.Entry, rhs: Dir.Entry) bool {
    return mem.eql(u8, lhs.name, rhs.name) and lhs.kind == rhs.kind;
}

fn contains(entries: *const std.ArrayList(Dir.Entry), el: Dir.Entry) bool {
    for (entries.items) |entry| {
        if (entry_eql(entry, el)) return true;
    }
    return false;
}

test "readAllAlloc" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    var file = try tmp_dir.dir.createFile("test_file", .{ .read = true });
    defer file.close();

    const buf1 = try file.readAllAlloc(testing.allocator, 0, 1024);
    defer testing.allocator.free(buf1);
    testing.expect(buf1.len == 0);

    const write_buf: []const u8 = "this is a test.\nthis is a test.\nthis is a test.\nthis is a test.\n";
    try file.writeAll(write_buf);
    try file.seekTo(0);
    const file_size = try file.getEndPos();

    // max_bytes > file_size
    const buf2 = try file.readAllAlloc(testing.allocator, file_size, 1024);
    defer testing.allocator.free(buf2);
    testing.expectEqual(write_buf.len, buf2.len);
    testing.expect(std.mem.eql(u8, write_buf, buf2));
    try file.seekTo(0);

    // max_bytes == file_size
    const buf3 = try file.readAllAlloc(testing.allocator, file_size, write_buf.len);
    defer testing.allocator.free(buf3);
    testing.expectEqual(write_buf.len, buf3.len);
    testing.expect(std.mem.eql(u8, write_buf, buf3));

    // max_bytes < file_size
    testing.expectError(error.FileTooBig, file.readAllAlloc(testing.allocator, file_size, write_buf.len - 1));
}

test "directory operations on files" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    const test_file_name = "test_file";

    var file = try tmp_dir.dir.createFile(test_file_name, .{ .read = true });
    file.close();

    testing.expectError(error.PathAlreadyExists, tmp_dir.dir.makeDir(test_file_name));
    testing.expectError(error.NotDir, tmp_dir.dir.openDir(test_file_name, .{}));
    testing.expectError(error.NotDir, tmp_dir.dir.deleteDir(test_file_name));

    if (builtin.os.tag != .wasi) {
        // TODO: use Dir's realpath function once that exists
        const absolute_path = blk: {
            const relative_path = try fs.path.join(testing.allocator, &[_][]const u8{ "zig-cache", "tmp", tmp_dir.sub_path[0..], test_file_name });
            defer testing.allocator.free(relative_path);
            break :blk try fs.realpathAlloc(testing.allocator, relative_path);
        };
        defer testing.allocator.free(absolute_path);

        testing.expectError(error.PathAlreadyExists, fs.makeDirAbsolute(absolute_path));
        testing.expectError(error.NotDir, fs.deleteDirAbsolute(absolute_path));
    }

    // ensure the file still exists and is a file as a sanity check
    file = try tmp_dir.dir.openFile(test_file_name, .{});
    const stat = try file.stat();
    testing.expect(stat.kind == .File);
    file.close();
}

test "file operations on directories" {
    var tmp_dir = tmpDir(.{});
    defer tmp_dir.cleanup();

    const test_dir_name = "test_dir";

    try tmp_dir.dir.makeDir(test_dir_name);

    testing.expectError(error.IsDir, tmp_dir.dir.createFile(test_dir_name, .{}));
    testing.expectError(error.IsDir, tmp_dir.dir.deleteFile(test_dir_name));
    // Currently, WASI will return error.Unexpected (via ENOTCAPABLE) when attempting fd_read on a directory handle.
    // TODO: Re-enable on WASI once https://github.com/bytecodealliance/wasmtime/issues/1935 is resolved.
    if (builtin.os.tag != .wasi) {
        testing.expectError(error.IsDir, tmp_dir.dir.readFileAlloc(testing.allocator, test_dir_name, std.math.maxInt(usize)));
    }
    // Note: The `.write = true` is necessary to ensure the error occurs on all platforms.
    // TODO: Add a read-only test as well, see https://github.com/ziglang/zig/issues/5732
    testing.expectError(error.IsDir, tmp_dir.dir.openFile(test_dir_name, .{ .write = true }));

    if (builtin.os.tag != .wasi) {
        // TODO: use Dir's realpath function once that exists
        const absolute_path = blk: {
            const relative_path = try fs.path.join(testing.allocator, &[_][]const u8{ "zig-cache", "tmp", tmp_dir.sub_path[0..], test_dir_name });
            defer testing.allocator.free(relative_path);
            break :blk try fs.realpathAlloc(testing.allocator, relative_path);
        };
        defer testing.allocator.free(absolute_path);

        testing.expectError(error.IsDir, fs.createFileAbsolute(absolute_path, .{}));
        testing.expectError(error.IsDir, fs.deleteFileAbsolute(absolute_path));
    }

    // ensure the directory still exists as a sanity check
    var dir = try tmp_dir.dir.openDir(test_dir_name, .{});
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
        @panic("expected error");
    } else |err| {
        testing.expect(err == error.FileNotFound);
    }
}

test "access file" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("os_test_tmp");
    if (tmp.dir.access("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", .{})) |ok| {
        @panic("expected error");
    } else |err| {
        testing.expect(err == error.FileNotFound);
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
    testing.expect(mem.eql(u8, written_buf[0..amt], "header1\nsecond header\nine1\nsecontrailer1\nsecond trailer\n"));
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

    testing.expectEqualSlices(u8, data, contents);
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
    testing.expect(mem.eql(u8, content, test_content));

    try tmp.dir.deleteFile(test_out_file);
}

test "realpath" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    testing.expectError(error.FileNotFound, fs.realpath("definitely_bogus_does_not_exist1234", &buf));
}

const FILE_LOCK_TEST_SLEEP_TIME = 5 * std.time.ns_per_ms;

test "open file with exclusive nonblocking lock twice" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const dir = fs.cwd();
    const filename = "file_nonblocking_lock_test.txt";

    const file1 = try dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    defer file1.close();

    const file2 = dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    std.debug.assert(std.meta.eql(file2, error.WouldBlock));

    dir.deleteFile(filename) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

test "open file with lock twice, make sure it wasn't open at the same time" {
    if (builtin.single_threaded) return error.SkipZigTest;

    if (std.io.is_async) {
        // This test starts its own threads and is not compatible with async I/O.
        return error.SkipZigTest;
    }

    const filename = "file_lock_test.txt";
    var contexts = [_]FileLockTestContext{
        .{ .filename = filename, .create = true, .lock = .Exclusive },
        .{ .filename = filename, .create = true, .lock = .Exclusive },
    };
    try run_lock_file_test(&contexts);

    // Check for an error
    var was_error = false;
    for (contexts) |context, idx| {
        if (context.err) |err| {
            was_error = true;
            std.debug.warn("\nError in context {}: {}\n", .{ idx, err });
        }
    }
    if (was_error) builtin.panic("There was an error in contexts", null);

    std.debug.assert(!contexts[0].overlaps(&contexts[1]));

    fs.cwd().deleteFile(filename) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

test "create file, lock and read from multiple process at once" {
    if (builtin.single_threaded) return error.SkipZigTest;

    if (std.io.is_async) {
        // This test starts its own threads and is not compatible with async I/O.
        return error.SkipZigTest;
    }

    if (true) {
        // https://github.com/ziglang/zig/issues/5006
        return error.SkipZigTest;
    }

    const filename = "file_read_lock_test.txt";
    const filedata = "Hello, world!\n";

    try fs.cwd().writeFile(filename, filedata);

    var contexts = [_]FileLockTestContext{
        .{ .filename = filename, .create = false, .lock = .Shared },
        .{ .filename = filename, .create = false, .lock = .Shared },
        .{ .filename = filename, .create = false, .lock = .Exclusive },
    };

    try run_lock_file_test(&contexts);

    var was_error = false;
    for (contexts) |context, idx| {
        if (context.err) |err| {
            was_error = true;
            std.debug.warn("\nError in context {}: {}\n", .{ idx, err });
        }
    }
    if (was_error) builtin.panic("There was an error in contexts", null);

    std.debug.assert(contexts[0].overlaps(&contexts[1]));
    std.debug.assert(!contexts[2].overlaps(&contexts[0]));
    std.debug.assert(!contexts[2].overlaps(&contexts[1]));
    if (contexts[0].bytes_read.? != filedata.len) {
        std.debug.warn("\n bytes_read: {}, expected: {} \n", .{ contexts[0].bytes_read, filedata.len });
    }
    std.debug.assert(contexts[0].bytes_read.? == filedata.len);
    std.debug.assert(contexts[1].bytes_read.? == filedata.len);

    fs.cwd().deleteFile(filename) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

test "open file with exclusive nonblocking lock twice (absolute paths)" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = testing.allocator;

    const file_paths: [1][]const u8 = .{"zig-test-absolute-paths.txt"};
    const filename = try fs.path.resolve(allocator, &file_paths);
    defer allocator.free(filename);

    const file1 = try fs.createFileAbsolute(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });

    const file2 = fs.createFileAbsolute(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    file1.close();
    testing.expectError(error.WouldBlock, file2);

    try fs.deleteFileAbsolute(filename);
}

const FileLockTestContext = struct {
    filename: []const u8,
    pid: if (builtin.os.tag == .windows) ?void else ?std.os.pid_t = null,

    // use file.createFile
    create: bool,
    // the type of lock to use
    lock: File.Lock,

    // Output variables
    err: ?(File.OpenError || std.os.ReadError) = null,
    start_time: i64 = 0,
    end_time: i64 = 0,
    bytes_read: ?usize = null,

    fn overlaps(self: *const @This(), other: *const @This()) bool {
        return (self.start_time < other.end_time) and (self.end_time > other.start_time);
    }

    fn run(ctx: *@This()) void {
        var file: File = undefined;
        if (ctx.create) {
            file = fs.cwd().createFile(ctx.filename, .{ .lock = ctx.lock }) catch |err| {
                ctx.err = err;
                return;
            };
        } else {
            file = fs.cwd().openFile(ctx.filename, .{ .lock = ctx.lock }) catch |err| {
                ctx.err = err;
                return;
            };
        }
        defer file.close();

        ctx.start_time = std.time.milliTimestamp();

        if (!ctx.create) {
            var buffer: [100]u8 = undefined;
            ctx.bytes_read = 0;
            while (true) {
                const amt = file.read(buffer[0..]) catch |err| {
                    ctx.err = err;
                    return;
                };
                if (amt == 0) break;
                ctx.bytes_read.? += amt;
            }
        }

        std.time.sleep(FILE_LOCK_TEST_SLEEP_TIME);

        ctx.end_time = std.time.milliTimestamp();
    }
};

fn run_lock_file_test(contexts: []FileLockTestContext) !void {
    var threads = std.ArrayList(*std.Thread).init(testing.allocator);
    defer {
        for (threads.items) |thread| {
            thread.wait();
        }
        threads.deinit();
    }
    for (contexts) |*ctx, idx| {
        try threads.append(try std.Thread.spawn(ctx, FileLockTestContext.run));
    }
}
