const std = @import("../std.zig");
const builtin = std.builtin;
const fs = std.fs;
const Dir = std.fs.Dir;
const File = std.fs.File;
const tmpDir = std.testing.tmpDir;

test "openSelfExe" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const self_exe_file = try std.fs.openSelfExe();
    self_exe_file.close();
}

const FILE_LOCK_TEST_SLEEP_TIME = 5 * std.time.millisecond;

test "open file with exclusive nonblocking lock twice" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const filename = "file_nonblocking_lock_test.txt";

    const file1 = try tmp.dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    defer file1.close();

    const file2 = tmp.dir.createFile(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    std.debug.assert(std.meta.eql(file2, error.WouldBlock));

    tmp.dir.deleteFile(filename) catch |err| switch (err) {
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

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var contexts = [_]FileLockTestContext{
        .{ .dir = tmp.dir, .filename = filename, .create = true, .lock = .Exclusive },
        .{ .dir = tmp.dir, .filename = filename, .create = true, .lock = .Exclusive },
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

    tmp.dir.deleteFile(filename) catch |err| switch (err) {
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

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(filename, filedata);

    var contexts = [_]FileLockTestContext{
        .{ .dir = tmp.dir, .filename = filename, .create = false, .lock = .Shared },
        .{ .dir = tmp.dir, .filename = filename, .create = false, .lock = .Shared },
        .{ .dir = tmp.dir, .filename = filename, .create = false, .lock = .Exclusive },
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

    tmp.dir.deleteFile(filename) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
}

test "open file with exclusive nonblocking lock twice (absolute paths)" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = std.testing.allocator;

    const file_paths: [1][]const u8 = .{"zig-test-absolute-paths.txt"};
    const filename = try fs.path.resolve(allocator, &file_paths);
    defer allocator.free(filename);

    const file1 = try fs.createFileAbsolute(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });

    const file2 = fs.createFileAbsolute(filename, .{ .lock = .Exclusive, .lock_nonblocking = true });
    file1.close();
    std.testing.expectError(error.WouldBlock, file2);

    try fs.deleteFileAbsolute(filename);
}

const FileLockTestContext = struct {
    dir: Dir,
    filename: []const u8,
    pid: if (builtin.os.tag == .windows) ?void else ?std.os.pid_t = null,

    // use file.createFile
    create: bool,
    // the type of lock to use
    lock: File.Lock,

    // Output variables
    err: ?(File.OpenError || std.os.ReadError) = null,
    start_time: u64 = 0,
    end_time: u64 = 0,
    bytes_read: ?usize = null,

    fn overlaps(self: *const @This(), other: *const @This()) bool {
        return (self.start_time < other.end_time) and (self.end_time > other.start_time);
    }

    fn run(ctx: *@This()) void {
        var file: File = undefined;
        if (ctx.create) {
            file = ctx.dir.createFile(ctx.filename, .{ .lock = ctx.lock }) catch |err| {
                ctx.err = err;
                return;
            };
        } else {
            file = ctx.dir.openFile(ctx.filename, .{ .lock = ctx.lock }) catch |err| {
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
    var threads = std.ArrayList(*std.Thread).init(std.testing.allocator);
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
