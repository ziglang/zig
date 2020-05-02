const std = @import("../std.zig");
const builtin = std.builtin;
const fs = std.fs;
const File = std.fs.File;

test "openSelfExe" {
    const self_exe_file = try std.fs.openSelfExe();
    self_exe_file.close();
}

const FILE_LOCK_TEST_SLEEP_TIME = 5 * std.time.millisecond;

test "open file with exclusive nonblocking lock twice" {
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
