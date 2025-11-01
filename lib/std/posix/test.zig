const std = @import("../std.zig");
const posix = std.posix;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;
const fs = std.fs;
const mem = std.mem;
const elf = std.elf;
const linux = std.os.linux;

const a = std.testing.allocator;

const builtin = @import("builtin");
const AtomicRmwOp = std.builtin.AtomicRmwOp;
const AtomicOrder = std.builtin.AtomicOrder;
const native_os = builtin.target.os.tag;
const tmpDir = std.testing.tmpDir;

// NOTE: several additional tests are in test/standalone/posix/.  Any tests that mutate
// process-wide POSIX state (cwd, signals, etc) cannot be Zig unit tests and should be over there.

// https://github.com/ziglang/zig/issues/20288
test "WTF-8 to WTF-16 conversion buffer overflows" {
    if (native_os != .windows) return error.SkipZigTest;

    const input_wtf8 = "\u{10FFFF}" ** 16385;
    try expectError(error.NameTooLong, posix.chdir(input_wtf8));
    try expectError(error.NameTooLong, posix.chdirZ(input_wtf8));
}

test "check WASI CWD" {
    if (native_os == .wasi) {
        if (std.options.wasiCwd() != 3) {
            @panic("WASI code that uses cwd (like this test) needs a preopen for cwd (add '--dir=.' to wasmtime)");
        }

        if (!builtin.link_libc) {
            // WASI without-libc hardcodes fd 3 as the FDCWD token so it can be passed directly to WASI calls
            try expectEqual(3, posix.AT.FDCWD);
        }
    }
}

test "open smoke test" {
    if (native_os == .wasi) return error.SkipZigTest;
    if (native_os == .windows) return error.SkipZigTest;

    // TODO verify file attributes using `fstat`

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const base_path = try tmp.dir.realpathAlloc(a, ".");
    defer a.free(base_path);

    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;

    {
        // Create some file using `open`.
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode);
        posix.close(fd);
    }

    {
        // Try this again with the same flags. This op should fail with error.PathAlreadyExists.
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        try expectError(error.PathAlreadyExists, posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode));
    }

    {
        // Try opening without `EXCL` flag.
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true }, mode);
        posix.close(fd);
    }

    {
        // Try opening as a directory which should fail.
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        try expectError(error.NotDir, posix.open(file_path, .{ .ACCMODE = .RDWR, .DIRECTORY = true }, mode));
    }

    {
        // Create some directory
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);
        try posix.mkdir(file_path, mode);
    }

    {
        // Open dir using `open`
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, mode);
        posix.close(fd);
    }

    {
        // Try opening as file which should fail.
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);
        try expectError(error.IsDir, posix.open(file_path, .{ .ACCMODE = .RDWR }, mode));
    }
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

test "linkat with different directories" {
    if ((builtin.cpu.arch == .riscv32 or builtin.cpu.arch.isLoongArch()) and builtin.os.tag == .linux and !builtin.link_libc) return error.SkipZigTest; // No `fstatat()`.
    if (builtin.cpu.arch.isMIPS64()) return error.SkipZigTest; // `nstat.nlink` assertion is failing with LLVM 20+ for unclear reasons.

    switch (native_os) {
        .wasi, .linux, .illumos => {},
        else => return error.SkipZigTest,
    }

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const target_name = "link-target";
    const link_name = "newlink";

    const subdir = try tmp.dir.makeOpenPath("subdir", .{});

    defer tmp.dir.deleteFile(target_name) catch {};
    try tmp.dir.writeFile(.{ .sub_path = target_name, .data = "example" });

    // Test 1: link from file in subdir back up to target in parent directory
    try posix.linkat(tmp.dir.fd, target_name, subdir.fd, link_name, 0);

    const efd = try tmp.dir.openFile(target_name, .{});
    defer efd.close();

    const nfd = try subdir.openFile(link_name, .{});
    defer nfd.close();

    {
        const estat = try posix.fstat(efd.handle);
        const nstat = try posix.fstat(nfd.handle);
        try testing.expectEqual(estat.ino, nstat.ino);
        try testing.expectEqual(@as(@TypeOf(nstat.nlink), 2), nstat.nlink);
    }

    // Test 2: remove link
    try posix.unlinkat(subdir.fd, link_name, 0);

    {
        const estat = try posix.fstat(efd.handle);
        try testing.expectEqual(@as(@TypeOf(estat.nlink), 1), estat.nlink);
    }
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

test "getrandom" {
    var buf_a: [50]u8 = undefined;
    var buf_b: [50]u8 = undefined;
    try posix.getrandom(&buf_a);
    try posix.getrandom(&buf_b);
    // If this test fails the chance is significantly higher that there is a bug than
    // that two sets of 50 bytes were equal.
    try expect(!mem.eql(u8, &buf_a, &buf_b));
}

test "getuid" {
    if (native_os == .windows or native_os == .wasi) return error.SkipZigTest;
    _ = posix.getuid();
    _ = posix.geteuid();
}

test "getgid" {
    if (native_os == .windows or native_os == .wasi) return error.SkipZigTest;
    _ = posix.getgid();
    _ = posix.getegid();
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
    // Must be a multiple of the page size so that the test works with mmap2
    const alloc_size = 8 * std.heap.pageSize();

    // Create a file used for testing mmap() calls with a file descriptor
    {
        const file = try tmp.dir.createFile(test_out_file, .{});
        defer file.close();

        var stream = file.writer(&.{});

        var i: usize = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try stream.interface.writeInt(u32, @intCast(i), .little);
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

        var stream: std.Io.Reader = .fixed(data);

        var i: usize = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try testing.expectEqual(i, try stream.takeInt(u32, .little));
        }
    }

    if (builtin.cpu.arch == .hexagon) return error.SkipZigTest;

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

        var stream: std.Io.Reader = .fixed(data);

        var i: usize = alloc_size / 2 / @sizeOf(u32);
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try testing.expectEqual(i, try stream.takeInt(u32, .little));
        }
    }
}

test "fcntl" {
    if (native_os == .windows or native_os == .wasi)
        return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";

    const file = try tmp.dir.createFile(test_out_file, .{});
    defer file.close();

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
        .linux, .illumos => {},
        else => return error.SkipZigTest,
    }
    _ = &posix.signalfd;
}

test "sync" {
    if (native_os != .linux)
        return error.SkipZigTest;

    // Unfortunately, we cannot safely call `sync` or `syncfs`, because if file IO is happening
    // than the system can commit the results to disk, such calls could block indefinitely.

    _ = &posix.sync;
    _ = &posix.syncfs;
}

test "fsync" {
    switch (native_os) {
        .linux, .windows, .illumos => {},
        else => return error.SkipZigTest,
    }

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const test_out_file = "os_tmp_test";
    const file = try tmp.dir.createFile(test_out_file, .{});
    defer file.close();

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
        if (builtin.cpu.arch.isMIPS() and builtin.link_libc) {
            if (limit.cur != linux.RLIM.INFINITY) {
                try posix.setrlimit(resource, limit);
            }
        } else {
            try posix.setrlimit(resource, limit);
        }
    }
}

test "sigrtmin/max" {
    if (native_os == .wasi or native_os == .windows or native_os == .macos) {
        return error.SkipZigTest;
    }

    try std.testing.expect(posix.sigrtmin() >= 32);
    try std.testing.expect(posix.sigrtmin() >= posix.system.sigrtmin());
    try std.testing.expect(posix.sigrtmin() < posix.system.sigrtmax());
}

test "sigset empty/full" {
    if (native_os == .wasi or native_os == .windows)
        return error.SkipZigTest;

    var set: posix.sigset_t = posix.sigemptyset();
    for (1..posix.NSIG) |i| {
        const sig = std.meta.intToEnum(posix.SIG, i) catch continue;
        try expectEqual(false, posix.sigismember(&set, sig));
    }

    // The C library can reserve some (unnamed) signals, so can't check the full
    // NSIG set is defined, but just test a couple:
    set = posix.sigfillset();
    try expectEqual(true, posix.sigismember(&set, .CHLD));
    try expectEqual(true, posix.sigismember(&set, .INT));
}

// Some signals (i.e., 32 - 34 on glibc/musl) are not allowed to be added to a
// sigset by the C library, so avoid testing them.
fn reserved_signo(i: usize) bool {
    if (native_os == .macos) return false;
    if (!builtin.link_libc) return false;
    const max = if (native_os == .netbsd) 32 else 31;
    return i > max and i < posix.sigrtmin();
}

test "sigset add/del" {
    if (native_os == .wasi or native_os == .windows)
        return error.SkipZigTest;

    var sigset: posix.sigset_t = posix.sigemptyset();

    // See that none are set, then set each one, see that they're all set, then
    // remove them all, and then see that none are set.
    for (1..posix.NSIG) |i| {
        const sig = std.meta.intToEnum(posix.SIG, i) catch continue;
        try expectEqual(false, posix.sigismember(&sigset, sig));
    }
    for (1..posix.NSIG) |i| {
        if (!reserved_signo(i)) {
            const sig = std.meta.intToEnum(posix.SIG, i) catch continue;
            posix.sigaddset(&sigset, sig);
        }
    }
    for (1..posix.NSIG) |i| {
        if (!reserved_signo(i)) {
            const sig = std.meta.intToEnum(posix.SIG, i) catch continue;
            try expectEqual(true, posix.sigismember(&sigset, sig));
        }
    }
    for (1..posix.NSIG) |i| {
        if (!reserved_signo(i)) {
            const sig = std.meta.intToEnum(posix.SIG, i) catch continue;
            posix.sigdelset(&sigset, sig);
        }
    }
    for (1..posix.NSIG) |i| {
        const sig = std.meta.intToEnum(posix.SIG, i) catch continue;
        try expectEqual(false, posix.sigismember(&sigset, sig));
    }
}

test "dup & dup2" {
    switch (native_os) {
        .linux, .illumos => {},
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

    var buffer: [8]u8 = undefined;
    try testing.expectEqualStrings("dupdup2", try tmp.dir.readFile("os_dup_test", &buffer));
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

    var tmp = tmpDir(.{});
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
        std.Thread.sleep(1 * std.time.ns_per_ms);
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

    const base_path = try tmp.dir.realpathAlloc(a, ".");
    defer a.free(base_path);

    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;

    {
        // Create some file using `open`.
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode);
        posix.close(fd);

        // Rename the file
        const new_file_path = try fs.path.join(a, &.{ base_path, "some_other_file" });
        defer a.free(new_file_path);
        try posix.rename(file_path, new_file_path);
    }

    {
        // Try opening renamed file
        const file_path = try fs.path.join(a, &.{ base_path, "some_other_file" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDWR }, mode);
        posix.close(fd);
    }

    {
        // Try opening original file - should fail with error.FileNotFound
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        try expectError(error.FileNotFound, posix.open(file_path, .{ .ACCMODE = .RDWR }, mode));
    }

    {
        // Create some directory
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);
        try posix.mkdir(file_path, mode);

        // Rename the directory
        const new_file_path = try fs.path.join(a, &.{ base_path, "some_other_dir" });
        defer a.free(new_file_path);
        try posix.rename(file_path, new_file_path);
    }

    {
        // Try opening renamed directory
        const file_path = try fs.path.join(a, &.{ base_path, "some_other_dir" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, mode);
        posix.close(fd);
    }

    {
        // Try opening original directory - should fail with error.FileNotFound
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);
        try expectError(error.FileNotFound, posix.open(file_path, .{ .ACCMODE = .RDONLY, .DIRECTORY = true }, mode));
    }
}

test "access smoke test" {
    if (native_os == .wasi) return error.SkipZigTest;
    if (native_os == .windows) return error.SkipZigTest;

    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    const base_path = try tmp.dir.realpathAlloc(a, ".");
    defer a.free(base_path);

    const mode: posix.mode_t = if (native_os == .windows) 0 else 0o666;
    {
        // Create some file using `open`.
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        const fd = try posix.open(file_path, .{ .ACCMODE = .RDWR, .CREAT = true, .EXCL = true }, mode);
        posix.close(fd);
    }

    {
        // Try to access() the file
        const file_path = try fs.path.join(a, &.{ base_path, "some_file" });
        defer a.free(file_path);
        if (native_os == .windows) {
            try posix.access(file_path, posix.F_OK);
        } else {
            try posix.access(file_path, posix.F_OK | posix.W_OK | posix.R_OK);
        }
    }

    {
        // Try to access() a non-existent file - should fail with error.FileNotFound
        const file_path = try fs.path.join(a, &.{ base_path, "some_other_file" });
        defer a.free(file_path);
        try expectError(error.FileNotFound, posix.access(file_path, posix.F_OK));
    }

    {
        // Create some directory
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);
        try posix.mkdir(file_path, mode);
    }

    {
        // Try to access() the directory
        const file_path = try fs.path.join(a, &.{ base_path, "some_dir" });
        defer a.free(file_path);

        try posix.access(file_path, posix.F_OK);
    }
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

test "pread with empty buffer" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("pread_empty", .{ .read = true });
    defer file.close();

    const bytes = try a.alloc(u8, 0);
    defer a.free(bytes);

    const rc = try posix.pread(file.handle, bytes, 0);
    try expectEqual(rc, 0);
}

test "write with empty buffer" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("write_empty", .{});
    defer file.close();

    const bytes = try a.alloc(u8, 0);
    defer a.free(bytes);

    const rc = try posix.write(file.handle, bytes);
    try expectEqual(rc, 0);
}

test "pwrite with empty buffer" {
    var tmp = tmpDir(.{});
    defer tmp.cleanup();

    var file = try tmp.dir.createFile("pwrite_empty", .{});
    defer file.close();

    const bytes = try a.alloc(u8, 0);
    defer a.free(bytes);

    const rc = try posix.pwrite(file.handle, bytes, 0);
    try expectEqual(rc, 0);
}

fn expectMode(dir: posix.fd_t, file: []const u8, mode: posix.mode_t) !void {
    const st = try posix.fstatat(dir, file, posix.AT.SYMLINK_NOFOLLOW);
    try expectEqual(mode, st.mode & 0b111_111_111);
}

test "fchmodat smoke test" {
    if (builtin.cpu.arch.isMIPS64() and (builtin.abi == .gnuabin32 or builtin.abi == .muslabin32)) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23808

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

    if ((builtin.cpu.arch == .riscv32 or builtin.cpu.arch.isLoongArch()) and builtin.os.tag == .linux and !builtin.link_libc) return error.SkipZigTest; // No `fstatat()`.

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
        var result: posix.O = if (native_os == .wasi) .{
            .read = cof.ACCMODE != .WRONLY,
            .write = cof.ACCMODE != .RDONLY,
        } else .{
            .ACCMODE = cof.ACCMODE,
        };
        result.CREAT = cof.CREAT;
        result.EXCL = cof.EXCL;
        result.DIRECTORY = cof.DIRECTORY;
        result.NONBLOCK = cof.NONBLOCK;
        if (@hasField(posix.O, "CLOEXEC")) result.CLOEXEC = cof.CLOEXEC;
        if (@hasField(posix.O, "LARGEFILE")) result.LARGEFILE = cof.LARGEFILE;
        return result;
    }
};
