// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const os = std.os;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const elf = std.elf;
const File = std.fs.File;
const Thread = std.Thread;

const a = std.testing.allocator;

const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const tmpDir = std.testing.tmpDir;
const Dir = std.fs.Dir;
const ArenaAllocator = std.heap.ArenaAllocator;

test "chdir smoke test" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    // Get current working directory path
    var old_cwd_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const old_cwd = try os.getcwd(old_cwd_buf[0..]);

    {
        // Firstly, changing to itself should have no effect
        try os.chdir(old_cwd);
        var new_cwd_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
        const new_cwd = try os.getcwd(new_cwd_buf[0..]);
        expect(mem.eql(u8, old_cwd, new_cwd));
    }
    {
        // Next, change current working directory to one level above
        const parent = fs.path.dirname(old_cwd) orelse unreachable; // old_cwd should be absolute
        try os.chdir(parent);
        var new_cwd_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
        const new_cwd = try os.getcwd(new_cwd_buf[0..]);
        expect(mem.eql(u8, parent, new_cwd));
    }
}

test "open smoke test" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    // TODO verify file attributes using `fstat`

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const base_path = blk: {
        const relative_path = try fs.path.join(&arena.allocator, &[_][]const u8{ "zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(&arena.allocator, relative_path);
    };

    var file_path: []u8 = undefined;
    var fd: os.fd_t = undefined;
    const mode: os.mode_t = if (builtin.os.tag == .windows) 0 else 0o666;

    // Create some file using `open`.
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_file" });
    fd = try os.open(file_path, os.O_RDWR | os.O_CREAT | os.O_EXCL, mode);
    os.close(fd);

    // Try this again with the same flags. This op should fail with error.PathAlreadyExists.
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_file" });
    expectError(error.PathAlreadyExists, os.open(file_path, os.O_RDWR | os.O_CREAT | os.O_EXCL, mode));

    // Try opening without `O_EXCL` flag.
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_file" });
    fd = try os.open(file_path, os.O_RDWR | os.O_CREAT, mode);
    os.close(fd);

    // Try opening as a directory which should fail.
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_file" });
    expectError(error.NotDir, os.open(file_path, os.O_RDWR | os.O_DIRECTORY, mode));

    // Create some directory
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_dir" });
    try os.mkdir(file_path, mode);

    // Open dir using `open`
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_dir" });
    fd = try os.open(file_path, os.O_RDONLY | os.O_DIRECTORY, mode);
    os.close(fd);

    // Try opening as file which should fail.
    file_path = try fs.path.join(&arena.allocator, &[_][]const u8{ base_path, "some_dir" });
    expectError(error.IsDir, os.open(file_path, os.O_RDWR, mode));
}

test "openat smoke test" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    // TODO verify file attributes using `fstatat`

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var fd: os.fd_t = undefined;
    const mode: os.mode_t = if (builtin.os.tag == .windows) 0 else 0o666;

    // Create some file using `openat`.
    fd = try os.openat(tmp.dir.fd, "some_file", os.O_RDWR | os.O_CREAT | os.O_EXCL, mode);
    os.close(fd);

    // Try this again with the same flags. This op should fail with error.PathAlreadyExists.
    expectError(error.PathAlreadyExists, os.openat(tmp.dir.fd, "some_file", os.O_RDWR | os.O_CREAT | os.O_EXCL, mode));

    // Try opening without `O_EXCL` flag.
    fd = try os.openat(tmp.dir.fd, "some_file", os.O_RDWR | os.O_CREAT, mode);
    os.close(fd);

    // Try opening as a directory which should fail.
    expectError(error.NotDir, os.openat(tmp.dir.fd, "some_file", os.O_RDWR | os.O_DIRECTORY, mode));

    // Create some directory
    try os.mkdirat(tmp.dir.fd, "some_dir", mode);

    // Open dir using `open`
    fd = try os.openat(tmp.dir.fd, "some_dir", os.O_RDONLY | os.O_DIRECTORY, mode);
    os.close(fd);

    // Try opening as file which should fail.
    expectError(error.IsDir, os.openat(tmp.dir.fd, "some_dir", os.O_RDWR, mode));
}

test "symlink with relative paths" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const cwd = fs.cwd();
    cwd.deleteFile("file.txt") catch {};
    cwd.deleteFile("symlinked") catch {};

    // First, try relative paths in cwd
    try cwd.writeFile("file.txt", "nonsense");

    if (builtin.os.tag == .windows) {
        os.windows.CreateSymbolicLink(
            cwd.fd,
            &[_]u16{ 's', 'y', 'm', 'l', 'i', 'n', 'k', 'e', 'd' },
            &[_]u16{ 'f', 'i', 'l', 'e', '.', 't', 'x', 't' },
            false,
        ) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => {
                try cwd.deleteFile("file.txt");
                try cwd.deleteFile("symlinked");
                return error.SkipZigTest;
            },
            else => return err,
        };
    } else {
        try os.symlink("file.txt", "symlinked");
    }

    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const given = try os.readlink("symlinked", buffer[0..]);
    expect(mem.eql(u8, "file.txt", given));

    try cwd.deleteFile("file.txt");
    try cwd.deleteFile("symlinked");
}

test "readlink on Windows" {
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    try testReadlink("C:\\ProgramData", "C:\\Users\\All Users");
    try testReadlink("C:\\Users\\Default", "C:\\Users\\Default User");
    try testReadlink("C:\\Users", "C:\\Documents and Settings");
}

fn testReadlink(target_path: []const u8, symlink_path: []const u8) !void {
    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const given = try os.readlink(symlink_path, buffer[0..]);
    expect(mem.eql(u8, target_path, given));
}

test "fstatat" {
    // enable when `fstat` and `fstatat` are implemented on Windows
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // create dummy file
    const contents = "nonsense";
    try tmp.dir.writeFile("file.txt", contents);

    // fetch file's info on the opened fd directly
    const file = try tmp.dir.openFile("file.txt", .{});
    const stat = try os.fstat(file.handle);
    defer file.close();

    // now repeat but using `fstatat` instead
    const flags = if (builtin.os.tag == .wasi) 0x0 else os.AT_SYMLINK_NOFOLLOW;
    const statat = try os.fstatat(tmp.dir.fd, "file.txt", flags);
    expectEqual(stat, statat);
}

test "readlinkat" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // create file
    try tmp.dir.writeFile("file.txt", "nonsense");

    // create a symbolic link
    if (builtin.os.tag == .windows) {
        os.windows.CreateSymbolicLink(
            tmp.dir.fd,
            &[_]u16{ 'l', 'i', 'n', 'k' },
            &[_]u16{ 'f', 'i', 'l', 'e', '.', 't', 'x', 't' },
            false,
        ) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return error.SkipZigTest,
            else => return err,
        };
    } else {
        try os.symlinkat("file.txt", tmp.dir.fd, "link");
    }

    // read the link
    var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
    const read_link = try os.readlinkat(tmp.dir.fd, "link", buffer[0..]);
    expect(mem.eql(u8, "file.txt", read_link));
}

fn testThreadIdFn(thread_id: *Thread.Id) void {
    thread_id.* = Thread.getCurrentId();
}

test "std.Thread.getCurrentId" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var thread_current_id: Thread.Id = undefined;
    const thread = try Thread.spawn(&thread_current_id, testThreadIdFn);
    const thread_id = thread.handle();
    thread.wait();
    if (Thread.use_pthreads) {
        expect(thread_current_id == thread_id);
    } else if (builtin.os.tag == .windows) {
        expect(Thread.getCurrentId() != thread_current_id);
    } else {
        // If the thread completes very quickly, then thread_id can be 0. See the
        // documentation comments for `std.Thread.handle`.
        expect(thread_id == 0 or thread_current_id == thread_id);
    }
}

test "spawn threads" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var shared_ctx: i32 = 1;

    const thread1 = try Thread.spawn({}, start1);
    const thread2 = try Thread.spawn(&shared_ctx, start2);
    const thread3 = try Thread.spawn(&shared_ctx, start2);
    const thread4 = try Thread.spawn(&shared_ctx, start2);

    thread1.wait();
    thread2.wait();
    thread3.wait();
    thread4.wait();

    expect(shared_ctx == 4);
}

fn start1(ctx: void) u8 {
    return 0;
}

fn start2(ctx: *i32) u8 {
    _ = @atomicRmw(i32, ctx, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
    return 0;
}

test "cpu count" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const cpu_count = try Thread.cpuCount();
    expect(cpu_count >= 1);
}

test "thread local storage" {
    if (builtin.single_threaded) return error.SkipZigTest;
    const thread1 = try Thread.spawn({}, testTls);
    const thread2 = try Thread.spawn({}, testTls);
    testTls({});
    thread1.wait();
    thread2.wait();
}

threadlocal var x: i32 = 1234;
fn testTls(context: void) void {
    if (x != 1234) @panic("bad start value");
    x += 1;
    if (x != 1235) @panic("bad end value");
}

test "getrandom" {
    var buf_a: [50]u8 = undefined;
    var buf_b: [50]u8 = undefined;
    try os.getrandom(&buf_a);
    try os.getrandom(&buf_b);
    // If this test fails the chance is significantly higher that there is a bug than
    // that two sets of 50 bytes were equal.
    expect(!mem.eql(u8, &buf_a, &buf_b));
}

test "getcwd" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    // at least call it so it gets compiled
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    _ = os.getcwd(&buf) catch undefined;
}

test "sigaltstack" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi) return error.SkipZigTest;

    var st: os.stack_t = undefined;
    try os.sigaltstack(null, &st);
    // Setting a stack size less than MINSIGSTKSZ returns ENOMEM
    st.ss_flags = 0;
    st.ss_size = 1;
    testing.expectError(error.SizeTooSmall, os.sigaltstack(&st, null));
}

// If the type is not available use void to avoid erroring out when `iter_fn` is
// analyzed
const dl_phdr_info = if (@hasDecl(os, "dl_phdr_info")) os.dl_phdr_info else c_void;

const IterFnError = error{
    MissingPtLoadSegment,
    MissingLoad,
    BadElfMagic,
    FailedConsistencyCheck,
};

fn iter_fn(info: *dl_phdr_info, size: usize, counter: *usize) IterFnError!void {
    // Count how many libraries are loaded
    counter.* += @as(usize, 1);

    // The image should contain at least a PT_LOAD segment
    if (info.dlpi_phnum < 1) return error.MissingPtLoadSegment;

    // Quick & dirty validation of the phdr pointers, make sure we're not
    // pointing to some random gibberish
    var i: usize = 0;
    var found_load = false;
    while (i < info.dlpi_phnum) : (i += 1) {
        const phdr = info.dlpi_phdr[i];

        if (phdr.p_type != elf.PT_LOAD) continue;

        const reloc_addr = info.dlpi_addr + phdr.p_vaddr;
        // Find the ELF header
        const elf_header = @intToPtr(*elf.Ehdr, reloc_addr - phdr.p_offset);
        // Validate the magic
        if (!mem.eql(u8, elf_header.e_ident[0..4], "\x7fELF")) return error.BadElfMagic;
        // Consistency check
        if (elf_header.e_phnum != info.dlpi_phnum) return error.FailedConsistencyCheck;

        found_load = true;
        break;
    }

    if (!found_load) return error.MissingLoad;
}

test "dl_iterate_phdr" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi or builtin.os.tag == .macos)
        return error.SkipZigTest;

    var counter: usize = 0;
    try os.dl_iterate_phdr(&counter, IterFnError, iter_fn);
    expect(counter != 0);
}

test "gethostname" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var buf: [os.HOST_NAME_MAX]u8 = undefined;
    const hostname = try os.gethostname(&buf);
    expect(hostname.len != 0);
}

test "pipe" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var fds = try os.pipe();
    expect((try os.write(fds[1], "hello")) == 5);
    var buf: [16]u8 = undefined;
    expect((try os.read(fds[0], buf[0..])) == 5);
    testing.expectEqualSlices(u8, buf[0..5], "hello");
    os.close(fds[1]);
    os.close(fds[0]);
}

test "argsAlloc" {
    var args = try std.process.argsAlloc(std.testing.allocator);
    std.process.argsFree(std.testing.allocator, args);
}

test "memfd_create" {
    // memfd_create is linux specific.
    if (builtin.os.tag != .linux) return error.SkipZigTest;
    const fd = std.os.memfd_create("test", 0) catch |err| switch (err) {
        // Related: https://github.com/ziglang/zig/issues/4019
        error.SystemOutdated => return error.SkipZigTest,
        else => |e| return e,
    };
    defer std.os.close(fd);
    expect((try std.os.write(fd, "test")) == 4);
    try std.os.lseek_SET(fd, 0);

    var buf: [10]u8 = undefined;
    const bytes_read = try std.os.read(fd, &buf);
    expect(bytes_read == 4);
    expect(mem.eql(u8, buf[0..4], "test"));
}

test "mmap" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Simple mmap() call with non page-aligned size
    {
        const data = try os.mmap(
            null,
            1234,
            os.PROT_READ | os.PROT_WRITE,
            os.MAP_ANONYMOUS | os.MAP_PRIVATE,
            -1,
            0,
        );
        defer os.munmap(data);

        testing.expectEqual(@as(usize, 1234), data.len);

        // By definition the data returned by mmap is zero-filled
        testing.expect(mem.eql(u8, data, &[_]u8{0x00} ** 1234));

        // Make sure the memory is writeable as requested
        std.mem.set(u8, data, 0x55);
        testing.expect(mem.eql(u8, data, &[_]u8{0x55} ** 1234));
    }

    const test_out_file = "os_tmp_test";
    // Must be a multiple of 4096 so that the test works with mmap2
    const alloc_size = 8 * 4096;

    // Create a file used for testing mmap() calls with a file descriptor
    {
        const file = try tmp.dir.createFile(test_out_file, .{});
        defer file.close();

        const stream = file.outStream();

        var i: u32 = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try stream.writeIntNative(u32, i);
        }
    }

    // Map the whole file
    {
        const file = try tmp.dir.openFile(test_out_file, .{});
        defer file.close();

        const data = try os.mmap(
            null,
            alloc_size,
            os.PROT_READ,
            os.MAP_PRIVATE,
            file.handle,
            0,
        );
        defer os.munmap(data);

        var mem_stream = io.fixedBufferStream(data);
        const stream = mem_stream.inStream();

        var i: u32 = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            testing.expectEqual(i, try stream.readIntNative(u32));
        }
    }

    // Map the upper half of the file
    {
        const file = try tmp.dir.openFile(test_out_file, .{});
        defer file.close();

        const data = try os.mmap(
            null,
            alloc_size / 2,
            os.PROT_READ,
            os.MAP_PRIVATE,
            file.handle,
            alloc_size / 2,
        );
        defer os.munmap(data);

        var mem_stream = io.fixedBufferStream(data);
        const stream = mem_stream.inStream();

        var i: u32 = alloc_size / 2 / @sizeOf(u32);
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            testing.expectEqual(i, try stream.readIntNative(u32));
        }
    }

    try tmp.dir.deleteFile(test_out_file);
}

test "getenv" {
    if (builtin.os.tag == .windows) {
        expect(os.getenvW(&[_:0]u16{ 'B', 'O', 'G', 'U', 'S', 0x11, 0x22, 0x33, 0x44, 0x55 }) == null);
    } else {
        expect(os.getenvZ("BOGUSDOESNOTEXISTENVVAR") == null);
    }
}

test "fcntl" {
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";

    const file = try tmp.dir.createFile(test_out_file, .{});
    defer {
        file.close();
        tmp.dir.deleteFile(test_out_file) catch {};
    }

    // Note: The test assumes createFile opens the file with O_CLOEXEC
    {
        const flags = try os.fcntl(file.handle, os.F_GETFD, 0);
        expect((flags & os.FD_CLOEXEC) != 0);
    }
    {
        _ = try os.fcntl(file.handle, os.F_SETFD, 0);
        const flags = try os.fcntl(file.handle, os.F_GETFD, 0);
        expect((flags & os.FD_CLOEXEC) == 0);
    }
    {
        _ = try os.fcntl(file.handle, os.F_SETFD, os.FD_CLOEXEC);
        const flags = try os.fcntl(file.handle, os.F_GETFD, 0);
        expect((flags & os.FD_CLOEXEC) != 0);
    }
}

test "signalfd" {
    if (builtin.os.tag != .linux)
        return error.SkipZigTest;
    _ = std.os.signalfd;
}

test "sync" {
    if (builtin.os.tag != .linux)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";
    const file = try tmp.dir.createFile(test_out_file, .{});
    defer {
        file.close();
        tmp.dir.deleteFile(test_out_file) catch {};
    }

    os.sync();
    try os.syncfs(file.handle);
}

test "fsync" {
    if (builtin.os.tag != .linux and builtin.os.tag != .windows)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";
    const file = try tmp.dir.createFile(test_out_file, .{});
    defer {
        file.close();
        tmp.dir.deleteFile(test_out_file) catch {};
    }

    try os.fsync(file.handle);
    try os.fdatasync(file.handle);
}

test "getrlimit and setrlimit" {
    if (!@hasDecl(os, "rlimit")) {
        return error.SkipZigTest;
    }

    inline for (std.meta.fields(os.rlimit_resource)) |field| {
        const resource = @intToEnum(os.rlimit_resource, field.value);
        const limit = try os.getrlimit(resource);
        try os.setrlimit(resource, limit);
    }
}

test "shutdown socket" {
    if (builtin.os.tag == .wasi)
        return error.SkipZigTest;
    if (builtin.os.tag == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (builtin.os.tag == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }
    const sock = try os.socket(os.AF_INET, os.SOCK_STREAM, 0);
    os.shutdown(sock, .both) catch |err| switch (err) {
        error.SocketNotConnected => {},
        else => |e| return e,
    };
    os.closeSocket(sock);
}
