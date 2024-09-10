const std = @import("../std.zig");
const posix = std.posix;
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
const linux = std.os.linux;

const a = std.testing.allocator;

const builtin = @import("builtin");
const AtomicRmwOp = std.builtin.AtomicRmwOp;
const AtomicOrder = std.builtin.AtomicOrder;
const native_os = builtin.target.os.tag;
const tmpDir = std.testing.tmpDir;
const Dir = std.fs.Dir;
const ArenaAllocator = std.heap.ArenaAllocator;

// https://github.com/ziglang/zig/issues/20288
test "WTF-8 to WTF-16 conversion buffer overflows" {
    if (native_os != .windows) return error.SkipZigTest;

    const input_wtf8 = "\u{10FFFF}" ** 16385;
    try expectError(error.NameTooLong, posix.chdir(input_wtf8));
    try expectError(error.NameTooLong, posix.chdirZ(input_wtf8));
}

test "chdir smoke test" {
    if (native_os == .wasi) return error.SkipZigTest;

    if (true) {
        // https://github.com/ziglang/zig/issues/14968
        return error.SkipZigTest;
    }

    // Get current working directory path
    var old_cwd_buf: [fs.max_path_bytes]u8 = undefined;
    const old_cwd = try posix.getcwd(old_cwd_buf[0..]);

    {
        // Firstly, changing to itself should have no effect
        try posix.chdir(old_cwd);
        var new_cwd_buf: [fs.max_path_bytes]u8 = undefined;
        const new_cwd = try posix.getcwd(new_cwd_buf[0..]);
        try expect(mem.eql(u8, old_cwd, new_cwd));
    }

    // Next, change current working directory to one level above
    if (native_os != .wasi) { // WASI does not support navigating outside of Preopens
        const parent = fs.path.dirname(old_cwd) orelse unreachable; // old_cwd should be absolute
        try posix.chdir(parent);

        // Restore cwd because process may have other tests that do not tolerate chdir.
        defer posix.chdir(old_cwd) catch unreachable;

        var new_cwd_buf: [fs.max_path_bytes]u8 = undefined;
        const new_cwd = try posix.getcwd(new_cwd_buf[0..]);
        try expect(mem.eql(u8, parent, new_cwd));
    }

    // Next, change current working directory to a temp directory one level below
    {
        // Create a tmp directory
        var tmp_dir_buf: [fs.max_path_bytes]u8 = undefined;
        const tmp_dir_path = path: {
            var allocator = std.heap.FixedBufferAllocator.init(&tmp_dir_buf);
            break :path try fs.path.resolve(allocator.allocator(), &[_][]const u8{ old_cwd, "zig-test-tmp" });
        };
        var tmp_dir = try fs.cwd().makeOpenPath("zig-test-tmp", .{});

        // Change current working directory to tmp directory
        try posix.chdir("zig-test-tmp");

        var new_cwd_buf: [fs.max_path_bytes]u8 = undefined;
        const new_cwd = try posix.getcwd(new_cwd_buf[0..]);

        // On Windows, fs.path.resolve returns an uppercase drive letter, but the drive letter returned by getcwd may be lowercase
        var resolved_cwd_buf: [fs.max_path_bytes]u8 = undefined;
        const resolved_cwd = path: {
            var allocator = std.heap.FixedBufferAllocator.init(&resolved_cwd_buf);
            break :path try fs.path.resolve(allocator.allocator(), &[_][]const u8{new_cwd});
        };
        try expect(mem.eql(u8, tmp_dir_path, resolved_cwd));

        // Restore cwd because process may have other tests that do not tolerate chdir.
        tmp_dir.close();
        posix.chdir(old_cwd) catch unreachable;
        try fs.cwd().deleteDir("zig-test-tmp");
    }
}

test "open smoke test" {
    if (native_os == .wasi) return error.SkipZigTest;
    if (native_os == .windows) return error.SkipZigTest;

    // TODO verify file attributes using `fstat`

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    var file_path: []u8 = undefined;
    var fd: posix.fd_t = undefined;
    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;

    // Create some file using `open`.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode);
    posix.close(fd);

    // Try this again with the same flags. This op should fail with error.PathAlreadyExists.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    try expectError(error.PathAlreadyExists, posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode));

    // Try opening without `EXCL` flag.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true }, mode);
    posix.close(fd);

    // Try opening as a directory which should fail.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    try expectError(error.NotDir, posix.open(file_path, .{ .ACCMODE = .RDWR, .DIRECTORY = true }, mode));

    // Create some directory
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    try posix.mkdir(file_path, mode);

    // Open dir using `open`
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, mode);
    posix.close(fd);

    // Try opening as file which should fail.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    try expectError(error.IsDir, posix.open(file_path, .{ .ACCMODE = .RDWR }, mode));
}

test "openat smoke test" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;
    if (native_os == .windows) return error.SkipZigTest;

    // TODO verify file attributes using `fstatat`

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var fd: posix.fd_t = undefined;
    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;

    // Create some file using `openat`.
    fd = try posix.openat(tmp.dir.fd, "some_file", CommonOpenFlags.lower(.{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .EXCL = true,
    }), mode);
    posix.close(fd);

    // Try this again with the same flags. This op should fail with error.PathAlreadyExists.
    try expectError(error.PathAlreadyExists, posix.openat(tmp.dir.fd, "some_file", CommonOpenFlags.lower(.{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .EXCL = true,
    }), mode));

    // Try opening without `EXCL` flag.
    fd = try posix.openat(tmp.dir.fd, "some_file", CommonOpenFlags.lower(.{
        .ACCMODE = .RDWR,
        .CREAT = true,
    }), mode);
    posix.close(fd);

    // Try opening as a directory which should fail.
    try expectError(error.NotDir, posix.openat(tmp.dir.fd, "some_file", CommonOpenFlags.lower(.{
        .ACCMODE = .RDWR,
        .DIRECTORY = true,
    }), mode));

    // Create some directory
    try posix.mkdirat(tmp.dir.fd, "some_dir", mode);

    // Open dir using `open`
    fd = try posix.openat(tmp.dir.fd, "some_dir", CommonOpenFlags.lower(.{
        .ACCMODE = .RDONLY,
        .DIRECTORY = true,
    }), mode);
    posix.close(fd);

    // Try opening as file which should fail.
    try expectError(error.IsDir, posix.openat(tmp.dir.fd, "some_dir", CommonOpenFlags.lower(.{
        .ACCMODE = .RDWR,
    }), mode));
}

test "symlink with relative paths" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;

    if (true) {
        // https://github.com/ziglang/zig/issues/14968
        return error.SkipZigTest;
    }
    const cwd = fs.cwd();
    cwd.deleteFile("file.txt") catch {};
    cwd.deleteFile("symlinked") catch {};

    // First, try relative paths in cwd
    try cwd.writeFile(.{ .sub_path = "file.txt", .data = "nonsense" });

    if (native_os == .windows) {
        std.os.windows.CreateSymbolicLink(
            cwd.fd,
            &[_]u16{ 's', 'y', 'm', 'l', 'i', 'n', 'k', 'e', 'd' },
            &[_:0]u16{ 'f', 'i', 'l', 'e', '.', 't', 'x', 't' },
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
        try posix.symlink("file.txt", "symlinked");
    }

    var buffer: [fs.max_path_bytes]u8 = undefined;
    const given = try posix.readlink("symlinked", buffer[0..]);
    try expect(mem.eql(u8, "file.txt", given));

    try cwd.deleteFile("file.txt");
    try cwd.deleteFile("symlinked");
}

test "readlink on Windows" {
    if (native_os != .windows) return error.SkipZigTest;

    try testReadlink("C:\\ProgramData", "C:\\Users\\All Users");
    try testReadlink("C:\\Users\\Default", "C:\\Users\\Default User");
    try testReadlink("C:\\Users", "C:\\Documents and Settings");
}

fn testReadlink(target_path: []const u8, symlink_path: []const u8) !void {
    var buffer: [fs.max_path_bytes]u8 = undefined;
    const given = try posix.readlink(symlink_path, buffer[0..]);
    try expect(mem.eql(u8, target_path, given));
}

test "link with relative paths" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;

    switch (native_os) {
        .wasi, .linux, .solaris, .illumos => {},
        else => return error.SkipZigTest,
    }
    if (true) {
        // https://github.com/ziglang/zig/issues/14968
        return error.SkipZigTest;
    }
    var cwd = fs.cwd();

    cwd.deleteFile("example.txt") catch {};
    cwd.deleteFile("new.txt") catch {};

    try cwd.writeFile(.{ .sub_path = "example.txt", .data = "example" });
    try posix.link("example.txt", "new.txt");

    const efd = try cwd.openFile("example.txt", .{});
    defer efd.close();

    const nfd = try cwd.openFile("new.txt", .{});
    defer nfd.close();

    {
        const estat = try posix.fstat(efd.handle);
        const nstat = try posix.fstat(nfd.handle);

        try testing.expectEqual(estat.ino, nstat.ino);
        try testing.expectEqual(@as(@TypeOf(nstat.nlink), 2), nstat.nlink);
    }

    try posix.unlink("new.txt");

    {
        const estat = try posix.fstat(efd.handle);
        try testing.expectEqual(@as(@TypeOf(estat.nlink), 1), estat.nlink);
    }

    try cwd.deleteFile("example.txt");
}

test "linkat with different directories" {
    if (native_os == .wasi and builtin.link_libc) return error.SkipZigTest;

    switch (native_os) {
        .wasi, .linux, .solaris, .illumos => {},
        else => return error.SkipZigTest,
    }
    if (true) {
        // https://github.com/ziglang/zig/issues/14968
        return error.SkipZigTest;
    }
    var cwd = fs.cwd();
    var tmp = tmpDir(.{});

    cwd.deleteFile("example.txt") catch {};
    tmp.dir.deleteFile("new.txt") catch {};

    try cwd.writeFile(.{ .sub_path = "example.txt", .data = "example" });
    try posix.linkat(cwd.fd, "example.txt", tmp.dir.fd, "new.txt", 0);

    const efd = try cwd.openFile("example.txt", .{});
    defer efd.close();

    const nfd = try tmp.dir.openFile("new.txt", .{});

    {
        defer nfd.close();
        const estat = try posix.fstat(efd.handle);
        const nstat = try posix.fstat(nfd.handle);

        try testing.expectEqual(estat.ino, nstat.ino);
        try testing.expectEqual(@as(@TypeOf(nstat.nlink), 2), nstat.nlink);
    }

    try posix.unlinkat(tmp.dir.fd, "new.txt", 0);

    {
        const estat = try posix.fstat(efd.handle);
        try testing.expectEqual(@as(@TypeOf(estat.nlink), 1), estat.nlink);
    }

    try cwd.deleteFile("example.txt");
}

test "fstatat" {
    if (builtin.cpu.arch == .riscv32 and builtin.os.tag == .linux and !builtin.link_libc) return error.SkipZigTest; // No `fstatat()`.
    // enable when `fstat` and `fstatat` are implemented on Windows
    if (native_os == .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // create dummy file
    const contents = "nonsense";
    try tmp.dir.writeFile(.{ .sub_path = "file.txt", .data = contents });

    // fetch file's info on the opened fd directly
    const file = try tmp.dir.openFile("file.txt", .{});
    const stat = try posix.fstat(file.handle);
    defer file.close();

    // now repeat but using `fstatat` instead
    const flags = if (native_os == .wasi) 0x0 else posix.AT.SYMLINK_NOFOLLOW;
    const statat = try posix.fstatat(tmp.dir.fd, "file.txt", flags);
    try expectEqual(stat, statat);
}

test "readlinkat" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // create file
    try tmp.dir.writeFile(.{ .sub_path = "file.txt", .data = "nonsense" });

    // create a symbolic link
    if (native_os == .windows) {
        std.os.windows.CreateSymbolicLink(
            tmp.dir.fd,
            &[_]u16{ 'l', 'i', 'n', 'k' },
            &[_:0]u16{ 'f', 'i', 'l', 'e', '.', 't', 'x', 't' },
            false,
        ) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return error.SkipZigTest,
            else => return err,
        };
    } else {
        try posix.symlinkat("file.txt", tmp.dir.fd, "link");
    }

    // read the link
    var buffer: [fs.max_path_bytes]u8 = undefined;
    const read_link = try posix.readlinkat(tmp.dir.fd, "link", buffer[0..]);
    try expect(mem.eql(u8, "file.txt", read_link));
}

fn testThreadIdFn(thread_id: *Thread.Id) void {
    thread_id.* = Thread.getCurrentId();
}

test "Thread.getCurrentId" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var thread_current_id: Thread.Id = undefined;
    const thread = try Thread.spawn(.{}, testThreadIdFn, .{&thread_current_id});
    thread.join();
    try expect(Thread.getCurrentId() != thread_current_id);
}

test "spawn threads" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var shared_ctx: i32 = 1;

    const thread1 = try Thread.spawn(.{}, start1, .{});
    const thread2 = try Thread.spawn(.{}, start2, .{&shared_ctx});
    const thread3 = try Thread.spawn(.{}, start2, .{&shared_ctx});
    const thread4 = try Thread.spawn(.{}, start2, .{&shared_ctx});

    thread1.join();
    thread2.join();
    thread3.join();
    thread4.join();

    try expect(shared_ctx == 4);
}

fn start1() u8 {
    return 0;
}

fn start2(ctx: *i32) u8 {
    _ = @atomicRmw(i32, ctx, AtomicRmwOp.Add, 1, AtomicOrder.seq_cst);
    return 0;
}

test "cpu count" {
    if (native_os == .wasi) return error.SkipZigTest;

    const cpu_count = try Thread.getCpuCount();
    try expect(cpu_count >= 1);
}

test "thread local storage" {
    if (builtin.single_threaded) return error.SkipZigTest;

    const thread1 = try Thread.spawn(.{}, testTls, .{});
    const thread2 = try Thread.spawn(.{}, testTls, .{});
    try testTls();
    thread1.join();
    thread2.join();
}

threadlocal var x: i32 = 1234;
fn testTls() !void {
    if (x != 1234) return error.TlsBadStartValue;
    x += 1;
    if (x != 1235) return error.TlsBadEndValue;
}

test "getrandom" {
    var buf_a: [50]u8 = undefined;
    var buf_b: [50]u8 = undefined;
    try posix.getrandom(&buf_a);
    try posix.getrandom(&buf_b);
    // If this test fails the chance is significantly higher that there is a bug than
    // that two sets of 50 bytes were equal.
    try expect(!mem.eql(u8, &buf_a, &buf_b));
}

test "getcwd" {
    // at least call it so it gets compiled
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    _ = posix.getcwd(&buf) catch undefined;
}

test "sigaltstack" {
    if (native_os == .windows or native_os == .wasi) return error.SkipZigTest;

    var st: posix.stack_t = undefined;
    try posix.sigaltstack(null, &st);
    // Setting a stack size less than MINSIGSTKSZ returns ENOMEM
    st.flags = 0;
    st.size = 1;
    try testing.expectError(error.SizeTooSmall, posix.sigaltstack(&st, null));
}

// If the type is not available use void to avoid erroring out when `iter_fn` is
// analyzed
const have_dl_phdr_info = posix.system.dl_phdr_info != void;
const dl_phdr_info = if (have_dl_phdr_info) posix.dl_phdr_info else anyopaque;

const IterFnError = error{
    MissingPtLoadSegment,
    MissingLoad,
    BadElfMagic,
    FailedConsistencyCheck,
};

fn iter_fn(info: *dl_phdr_info, size: usize, counter: *usize) IterFnError!void {
    _ = size;
    // Count how many libraries are loaded
    counter.* += @as(usize, 1);

    // The image should contain at least a PT_LOAD segment
    if (info.phnum < 1) return error.MissingPtLoadSegment;

    // Quick & dirty validation of the phdr pointers, make sure we're not
    // pointing to some random gibberish
    var i: usize = 0;
    var found_load = false;
    while (i < info.phnum) : (i += 1) {
        const phdr = info.phdr[i];

        if (phdr.p_type != elf.PT_LOAD) continue;

        const reloc_addr = info.addr + phdr.p_vaddr;
        // Find the ELF header
        const elf_header = @as(*elf.Ehdr, @ptrFromInt(reloc_addr - phdr.p_offset));
        // Validate the magic
        if (!mem.eql(u8, elf_header.e_ident[0..4], elf.MAGIC)) return error.BadElfMagic;
        // Consistency check
        if (elf_header.e_phnum != info.phnum) return error.FailedConsistencyCheck;

        found_load = true;
        break;
    }

    if (!found_load) return error.MissingLoad;
}

test "dl_iterate_phdr" {
    if (builtin.object_format != .elf) return error.SkipZigTest;

    var counter: usize = 0;
    try posix.dl_iterate_phdr(&counter, IterFnError, iter_fn);
    try expect(counter != 0);
}

test "gethostname" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var buf: [posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try posix.gethostname(&buf);
    try expect(hostname.len != 0);
}

test "pipe" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    const fds = try posix.pipe();
    try expect((try posix.write(fds[1], "hello")) == 5);
    var buf: [16]u8 = undefined;
    try expect((try posix.read(fds[0], buf[0..])) == 5);
    try testing.expectEqualSlices(u8, buf[0..5], "hello");
    posix.close(fds[1]);
    posix.close(fds[0]);
}

test "argsAlloc" {
    const args = try std.process.argsAlloc(std.testing.allocator);
    std.process.argsFree(std.testing.allocator, args);
}

test "memfd_create" {
    // memfd_create is only supported by linux and freebsd.
    switch (native_os) {
        .linux => {},
        .freebsd => {
            if (comptime builtin.os.version_range.semver.max.order(.{ .major = 13, .minor = 0, .patch = 0 }) == .lt)
                return error.SkipZigTest;
        },
        else => return error.SkipZigTest,
    }

    const fd = try posix.memfd_create("test", 0);
    defer posix.close(fd);
    try expect((try posix.write(fd, "test")) == 4);
    try posix.lseek_SET(fd, 0);

    var buf: [10]u8 = undefined;
    const bytes_read = try posix.read(fd, &buf);
    try expect(bytes_read == 4);
    try expect(mem.eql(u8, buf[0..4], "test"));
}

test "mmap" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Simple mmap() call with non page-aligned size
    {
        const data = try posix.mmap(
            null,
            1234,
            posix.PROT.READ | posix.PROT.WRITE,
            .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
            -1,
            0,
        );
        defer posix.munmap(data);

        try testing.expectEqual(@as(usize, 1234), data.len);

        // By definition the data returned by mmap is zero-filled
        try testing.expect(mem.eql(u8, data, &[_]u8{0x00} ** 1234));

        // Make sure the memory is writeable as requested
        @memset(data, 0x55);
        try testing.expect(mem.eql(u8, data, &[_]u8{0x55} ** 1234));
    }

    const test_out_file = "os_tmp_test";
    // Must be a multiple of 4096 so that the test works with mmap2
    const alloc_size = 8 * 4096;

    // Create a file used for testing mmap() calls with a file descriptor
    {
        const file = try tmp.dir.createFile(test_out_file, .{});
        defer file.close();

        const stream = file.writer();

        var i: u32 = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try stream.writeInt(u32, i, .little);
        }
    }

    // Map the whole file
    {
        const file = try tmp.dir.openFile(test_out_file, .{});
        defer file.close();

        const data = try posix.mmap(
            null,
            alloc_size,
            posix.PROT.READ,
            .{ .TYPE = .PRIVATE },
            file.handle,
            0,
        );
        defer posix.munmap(data);

        var mem_stream = io.fixedBufferStream(data);
        const stream = mem_stream.reader();

        var i: u32 = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try testing.expectEqual(i, try stream.readInt(u32, .little));
        }
    }

    // Map the upper half of the file
    {
        const file = try tmp.dir.openFile(test_out_file, .{});
        defer file.close();

        const data = try posix.mmap(
            null,
            alloc_size / 2,
            posix.PROT.READ,
            .{ .TYPE = .PRIVATE },
            file.handle,
            alloc_size / 2,
        );
        defer posix.munmap(data);

        var mem_stream = io.fixedBufferStream(data);
        const stream = mem_stream.reader();

        var i: u32 = alloc_size / 2 / @sizeOf(u32);
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try testing.expectEqual(i, try stream.readInt(u32, .little));
        }
    }

    try tmp.dir.deleteFile(test_out_file);
}

test "getenv" {
    if (native_os == .wasi and !builtin.link_libc) {
        // std.posix.getenv is not supported on WASI due to the need of allocation
        return error.SkipZigTest;
    }

    if (native_os == .windows) {
        try expect(std.process.getenvW(&[_:0]u16{ 'B', 'O', 'G', 'U', 'S', 0x11, 0x22, 0x33, 0x44, 0x55 }) == null);
    } else {
        try expect(posix.getenvZ("BOGUSDOESNOTEXISTENVVAR") == null);
    }
}

test "fcntl" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";

    const file = try tmp.dir.createFile(test_out_file, .{});
    defer {
        file.close();
        tmp.dir.deleteFile(test_out_file) catch {};
    }

    // Note: The test assumes createFile opens the file with CLOEXEC
    {
        const flags = try posix.fcntl(file.handle, posix.F.GETFD, 0);
        try expect((flags & posix.FD_CLOEXEC) != 0);
    }
    {
        _ = try posix.fcntl(file.handle, posix.F.SETFD, 0);
        const flags = try posix.fcntl(file.handle, posix.F.GETFD, 0);
        try expect((flags & posix.FD_CLOEXEC) == 0);
    }
    {
        _ = try posix.fcntl(file.handle, posix.F.SETFD, posix.FD_CLOEXEC);
        const flags = try posix.fcntl(file.handle, posix.F.GETFD, 0);
        try expect((flags & posix.FD_CLOEXEC) != 0);
    }
}

test "signalfd" {
    switch (native_os) {
        .linux, .solaris, .illumos => {},
        else => return error.SkipZigTest,
    }
    _ = &posix.signalfd;
}

test "sync" {
    if (native_os != .linux)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";
    const file = try tmp.dir.createFile(test_out_file, .{});
    defer {
        file.close();
        tmp.dir.deleteFile(test_out_file) catch {};
    }

    posix.sync();
    try posix.syncfs(file.handle);
}

test "fsync" {
    switch (native_os) {
        .linux, .windows, .solaris, .illumos => {},
        else => return error.SkipZigTest,
    }

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";
    const file = try tmp.dir.createFile(test_out_file, .{});
    defer {
        file.close();
        tmp.dir.deleteFile(test_out_file) catch {};
    }

    try posix.fsync(file.handle);
    try posix.fdatasync(file.handle);
}

test "getrlimit and setrlimit" {
    if (posix.system.rlimit_resource == void) return error.SkipZigTest;

    inline for (@typeInfo(posix.rlimit_resource).@"enum".fields) |field| {
        const resource: posix.rlimit_resource = @enumFromInt(field.value);
        const limit = try posix.getrlimit(resource);

        // XNU kernel does not support RLIMIT_STACK if a custom stack is active,
        // which looks to always be the case. EINVAL is returned.
        // See https://github.com/apple-oss-distributions/xnu/blob/5e3eaea39dcf651e66cb99ba7d70e32cc4a99587/bsd/kern/kern_resource.c#L1173
        if (native_os.isDarwin() and resource == .STACK) {
            continue;
        }

        // On 32 bit MIPS musl includes a fix which changes limits greater than -1UL/2 to RLIM_INFINITY.
        // See http://git.musl-libc.org/cgit/musl/commit/src/misc/getrlimit.c?id=8258014fd1e34e942a549c88c7e022a00445c352
        //
        // This happens for example if RLIMIT_MEMLOCK is bigger than ~2GiB.
        // In that case the following the limit would be RLIM_INFINITY and the following setrlimit fails with EPERM.
        if (comptime builtin.cpu.arch.isMIPS() and builtin.link_libc) {
            if (limit.cur != linux.RLIM.INFINITY) {
                try posix.setrlimit(resource, limit);
            }
        } else {
            try posix.setrlimit(resource, limit);
        }
    }
}

test "shutdown socket" {
    if (native_os == .wasi)
        return error.SkipZigTest;
    if (native_os == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (native_os == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }
    const sock = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
    posix.shutdown(sock, .both) catch |err| switch (err) {
        error.SocketNotConnected => {},
        else => |e| return e,
    };
    std.net.Stream.close(.{ .handle = sock });
}

test "sigaction" {
    if (native_os == .wasi or native_os == .windows)
        return error.SkipZigTest;

    // https://github.com/ziglang/zig/issues/7427
    if (native_os == .linux and builtin.target.cpu.arch == .x86)
        return error.SkipZigTest;

    // https://github.com/ziglang/zig/issues/15381
    if (native_os == .macos and builtin.target.cpu.arch == .x86_64) {
        return error.SkipZigTest;
    }

    const S = struct {
        var handler_called_count: u32 = 0;

        fn handler(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) void {
            _ = ctx_ptr;
            // Check that we received the correct signal.
            switch (native_os) {
                .netbsd => {
                    if (sig == posix.SIG.USR1 and sig == info.info.signo)
                        handler_called_count += 1;
                },
                else => {
                    if (sig == posix.SIG.USR1 and sig == info.signo)
                        handler_called_count += 1;
                },
            }
        }
    };

    var sa: posix.Sigaction = .{
        .handler = .{ .sigaction = &S.handler },
        .mask = posix.empty_sigset,
        .flags = posix.SA.SIGINFO | posix.SA.RESETHAND,
    };
    var old_sa: posix.Sigaction = undefined;

    // Install the new signal handler.
    posix.sigaction(posix.SIG.USR1, &sa, null);

    // Check that we can read it back correctly.
    posix.sigaction(posix.SIG.USR1, null, &old_sa);
    try testing.expectEqual(&S.handler, old_sa.handler.sigaction.?);
    try testing.expect((old_sa.flags & posix.SA.SIGINFO) != 0);

    // Invoke the handler.
    try posix.raise(posix.SIG.USR1);
    try testing.expect(S.handler_called_count == 1);

    // Check if passing RESETHAND correctly reset the handler to SIG_DFL
    posix.sigaction(posix.SIG.USR1, null, &old_sa);
    try testing.expectEqual(posix.SIG.DFL, old_sa.handler.handler);

    // Reinstall the signal w/o RESETHAND and re-raise
    sa.flags = posix.SA.SIGINFO;
    posix.sigaction(posix.SIG.USR1, &sa, null);
    try posix.raise(posix.SIG.USR1);
    try testing.expect(S.handler_called_count == 2);

    // Now set the signal to ignored
    sa.handler = .{ .handler = posix.SIG.IGN };
    sa.flags = 0;
    posix.sigaction(posix.SIG.USR1, &sa, null);

    // Re-raise to ensure handler is actually ignored
    try posix.raise(posix.SIG.USR1);
    try testing.expect(S.handler_called_count == 2);

    // Ensure that ignored state is returned when querying
    posix.sigaction(posix.SIG.USR1, null, &old_sa);
    try testing.expectEqual(posix.SIG.IGN, old_sa.handler.handler.?);
}

test "dup & dup2" {
    switch (native_os) {
        .linux, .solaris, .illumos => {},
        else => return error.SkipZigTest,
    }

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    {
        var file = try tmp.dir.createFile("os_dup_test", .{});
        defer file.close();

        var duped = std.fs.File{ .handle = try posix.dup(file.handle) };
        defer duped.close();
        try duped.writeAll("dup");

        // Tests aren't run in parallel so using the next fd shouldn't be an issue.
        const new_fd = duped.handle + 1;
        try posix.dup2(file.handle, new_fd);
        var dup2ed = std.fs.File{ .handle = new_fd };
        defer dup2ed.close();
        try dup2ed.writeAll("dup2");
    }

    var file = try tmp.dir.openFile("os_dup_test", .{});
    defer file.close();

    var buf: [7]u8 = undefined;
    try testing.expectEqualStrings("dupdup2", buf[0..try file.readAll(&buf)]);
}

test "writev longer than IOV_MAX" {
    if (native_os == .windows or native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("pwritev", .{});
    defer file.close();

    const iovecs = [_]posix.iovec_const{.{ .base = "a", .len = 1 }} ** (posix.IOV_MAX + 1);
    const amt = try file.writev(&iovecs);
    try testing.expectEqual(@as(usize, posix.IOV_MAX), amt);
}

test "POSIX file locking with fcntl" {
    if (native_os == .windows or native_os == .wasi) {
        // Not POSIX.
        return error.SkipZigTest;
    }

    if (true) {
        // https://github.com/ziglang/zig/issues/11074
        return error.SkipZigTest;
    }

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create a temporary lock file
    var file = try tmp.dir.createFile("lock", .{ .read = true });
    defer file.close();
    try file.setEndPos(2);
    const fd = file.handle;

    // Place an exclusive lock on the first byte, and a shared lock on the second byte:
    var struct_flock = std.mem.zeroInit(posix.Flock, .{ .type = posix.F.WRLCK });
    _ = try posix.fcntl(fd, posix.F.SETLK, @intFromPtr(&struct_flock));
    struct_flock.start = 1;
    struct_flock.type = posix.F.RDLCK;
    _ = try posix.fcntl(fd, posix.F.SETLK, @intFromPtr(&struct_flock));

    // Check the locks in a child process:
    const pid = try posix.fork();
    if (pid == 0) {
        // child expects be denied the exclusive lock:
        struct_flock.start = 0;
        struct_flock.type = posix.F.WRLCK;
        try expectError(error.Locked, posix.fcntl(fd, posix.F.SETLK, @intFromPtr(&struct_flock)));
        // child expects to get the shared lock:
        struct_flock.start = 1;
        struct_flock.type = posix.F.RDLCK;
        _ = try posix.fcntl(fd, posix.F.SETLK, @intFromPtr(&struct_flock));
        // child waits for the exclusive lock in order to test deadlock:
        struct_flock.start = 0;
        struct_flock.type = posix.F.WRLCK;
        _ = try posix.fcntl(fd, posix.F.SETLKW, @intFromPtr(&struct_flock));
        // child exits without continuing:
        posix.exit(0);
    } else {
        // parent waits for child to get shared lock:
        std.time.sleep(1 * std.time.ns_per_ms);
        // parent expects deadlock when attempting to upgrade the shared lock to exclusive:
        struct_flock.start = 1;
        struct_flock.type = posix.F.WRLCK;
        try expectError(error.DeadLock, posix.fcntl(fd, posix.F.SETLKW, @intFromPtr(&struct_flock)));
        // parent releases exclusive lock:
        struct_flock.start = 0;
        struct_flock.type = posix.F.UNLCK;
        _ = try posix.fcntl(fd, posix.F.SETLK, @intFromPtr(&struct_flock));
        // parent releases shared lock:
        struct_flock.start = 1;
        struct_flock.type = posix.F.UNLCK;
        _ = try posix.fcntl(fd, posix.F.SETLK, @intFromPtr(&struct_flock));
        // parent waits for child:
        const result = posix.waitpid(pid, 0);
        try expect(result.status == 0 * 256);
    }
}

test "rename smoke test" {
    if (native_os == .wasi) return error.SkipZigTest;
    if (native_os == .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    var file_path: []u8 = undefined;
    var fd: posix.fd_t = undefined;
    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;

    // Create some file using `open`.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode);
    posix.close(fd);

    // Rename the file
    var new_file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_other_file" });
    try posix.rename(file_path, new_file_path);

    // Try opening renamed file
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_other_file" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDWR }, mode);
    posix.close(fd);

    // Try opening original file - should fail with error.FileNotFound
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    try expectError(error.FileNotFound, posix.open(file_path, .{ .ACCMODE = .RDWR }, mode));

    // Create some directory
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    try posix.mkdir(file_path, mode);

    // Rename the directory
    new_file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_other_dir" });
    try posix.rename(file_path, new_file_path);

    // Try opening renamed directory
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_other_dir" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, mode);
    posix.close(fd);

    // Try opening original directory - should fail with error.FileNotFound
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    try expectError(error.FileNotFound, posix.open(file_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, mode));
}

test "access smoke test" {
    if (native_os == .wasi) return error.SkipZigTest;
    if (native_os == .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    // Get base abs path
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    var file_path: []u8 = undefined;
    var fd: posix.fd_t = undefined;
    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;

    // Create some file using `open`.
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode);
    posix.close(fd);

    // Try to access() the file
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    if (native_os == .windows) {
        try posix.access(file_path, posix.F_OK);
    } else {
        try posix.access(file_path, posix.F_OK | posix.W_OK | posix.R_OK);
    }

    // Try to access() a non-existent file - should fail with error.FileNotFound
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_other_file" });
    try expectError(error.FileNotFound, posix.access(file_path, posix.F_OK));

    // Create some directory
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    try posix.mkdir(file_path, mode);

    // Try to access() the directory
    file_path = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_dir" });
    try posix.access(file_path, posix.F_OK);
}

test "timerfd" {
    if (native_os != .linux) return error.SkipZigTest;

    const tfd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true });
    defer posix.close(tfd);

    // Fire event 10_000_000ns = 10ms after the posix.timerfd_settime call.
    var sit: linux.itimerspec = .{ .it_interval = .{ .sec = 0, .nsec = 0 }, .it_value = .{ .sec = 0, .nsec = 10 * (1000 * 1000) } };
    try posix.timerfd_settime(tfd, .{}, &sit, null);

    var fds: [1]posix.pollfd = .{.{ .fd = tfd, .events = linux.POLL.IN, .revents = 0 }};
    try expectEqual(@as(usize, 1), try posix.poll(&fds, -1)); // -1 => infinite waiting

    const git = try posix.timerfd_gettime(tfd);
    const expect_disarmed_timer: linux.itimerspec = .{ .it_interval = .{ .sec = 0, .nsec = 0 }, .it_value = .{ .sec = 0, .nsec = 0 } };
    try expectEqual(expect_disarmed_timer, git);
}

test "isatty" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("foo", .{});
    defer file.close();

    try expectEqual(posix.isatty(file.handle), false);
}

test "read with empty buffer" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get base abs path
    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const file_path: []u8 = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    var file = try fs.cwd().createFile(file_path, .{ .read = true });
    defer file.close();

    const bytes = try allocator.alloc(u8, 0);

    _ = try posix.read(file.handle, bytes);
}

test "pread with empty buffer" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get base abs path
    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const file_path: []u8 = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    var file = try fs.cwd().createFile(file_path, .{ .read = true });
    defer file.close();

    const bytes = try allocator.alloc(u8, 0);

    _ = try posix.pread(file.handle, bytes, 0);
}

test "write with empty buffer" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get base abs path
    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const file_path: []u8 = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    var file = try fs.cwd().createFile(file_path, .{});
    defer file.close();

    const bytes = try allocator.alloc(u8, 0);

    _ = try posix.write(file.handle, bytes);
}

test "pwrite with empty buffer" {
    if (native_os == .wasi) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get base abs path
    const base_path = blk: {
        const relative_path = try fs.path.join(allocator, &[_][]const u8{ ".zig-cache", "tmp", tmp.sub_path[0..] });
        break :blk try fs.realpathAlloc(allocator, relative_path);
    };

    const file_path: []u8 = try fs.path.join(allocator, &[_][]const u8{ base_path, "some_file" });
    var file = try fs.cwd().createFile(file_path, .{});
    defer file.close();

    const bytes = try allocator.alloc(u8, 0);

    _ = try posix.pwrite(file.handle, bytes, 0);
}

fn expectMode(dir: posix.fd_t, file: []const u8, mode: posix.mode_t) !void {
    const st = try posix.fstatat(dir, file, posix.AT.SYMLINK_NOFOLLOW);
    try expectEqual(mode, st.mode & 0b111_111_111);
}

test "fchmodat smoke test" {
    if (!std.fs.has_executable_bit) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    try expectError(error.FileNotFound, posix.fchmodat(tmp.dir.fd, "regfile", 0o666, 0));
    const fd = try posix.openat(
        tmp.dir.fd,
        "regfile",
        .{ .ACCMODE = .WRONLY, .CREAT = true, .EXCL = true, .TRUNC = true },
        0o644,
    );
    posix.close(fd);

    if (builtin.cpu.arch == .riscv32 and builtin.os.tag == .linux and !builtin.link_libc) return error.SkipZigTest; // No `fstatat()`.

    try posix.symlinkat("regfile", tmp.dir.fd, "symlink");
    const sym_mode = blk: {
        const st = try posix.fstatat(tmp.dir.fd, "symlink", posix.AT.SYMLINK_NOFOLLOW);
        break :blk st.mode & 0b111_111_111;
    };

    try posix.fchmodat(tmp.dir.fd, "regfile", 0o640, 0);
    try expectMode(tmp.dir.fd, "regfile", 0o640);
    try posix.fchmodat(tmp.dir.fd, "regfile", 0o600, posix.AT.SYMLINK_NOFOLLOW);
    try expectMode(tmp.dir.fd, "regfile", 0o600);

    try posix.fchmodat(tmp.dir.fd, "symlink", 0o640, 0);
    try expectMode(tmp.dir.fd, "regfile", 0o640);
    try expectMode(tmp.dir.fd, "symlink", sym_mode);

    var test_link = true;
    posix.fchmodat(tmp.dir.fd, "symlink", 0o600, posix.AT.SYMLINK_NOFOLLOW) catch |err| switch (err) {
        error.OperationNotSupported => test_link = false,
        else => |e| return e,
    };
    if (test_link)
        try expectMode(tmp.dir.fd, "symlink", 0o600);
    try expectMode(tmp.dir.fd, "regfile", 0o640);
}

const CommonOpenFlags = packed struct {
    ACCMODE: posix.ACCMODE = .RDONLY,
    CREAT: bool = false,
    EXCL: bool = false,
    LARGEFILE: bool = false,
    DIRECTORY: bool = false,
    CLOEXEC: bool = false,
    NONBLOCK: bool = false,

    pub fn lower(cof: CommonOpenFlags) posix.O {
        if (native_os == .wasi) return .{
            .read = cof.ACCMODE != .WRONLY,
            .write = cof.ACCMODE != .RDONLY,
            .CREAT = cof.CREAT,
            .EXCL = cof.EXCL,
            .DIRECTORY = cof.DIRECTORY,
            .NONBLOCK = cof.NONBLOCK,
        };
        var result: posix.O = .{
            .ACCMODE = cof.ACCMODE,
            .CREAT = cof.CREAT,
            .EXCL = cof.EXCL,
            .DIRECTORY = cof.DIRECTORY,
            .NONBLOCK = cof.NONBLOCK,
            .CLOEXEC = cof.CLOEXEC,
        };
        if (@hasField(posix.O, "LARGEFILE")) result.LARGEFILE = cof.LARGEFILE;
        return result;
    }
};
