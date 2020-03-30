const std = @import("../std.zig");
const os = std.os;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
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

test "makePath, put some files in it, deleteTree" {
    try fs.cwd().makePath("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "c");
    try fs.cwd().writeFile("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "c" ++ fs.path.sep_str ++ "file.txt", "nonsense");
    try fs.cwd().writeFile("os_test_tmp" ++ fs.path.sep_str ++ "b" ++ fs.path.sep_str ++ "file2.txt", "blah");
    try fs.cwd().deleteTree("os_test_tmp");
    if (fs.cwd().openDir("os_test_tmp", .{})) |dir| {
        @panic("expected error");
    } else |err| {
        expect(err == error.FileNotFound);
    }
}

test "access file" {
    try fs.cwd().makePath("os_test_tmp");
    if (fs.cwd().access("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", .{})) |ok| {
        @panic("expected error");
    } else |err| {
        expect(err == error.FileNotFound);
    }

    try fs.cwd().writeFile("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", "");
    try fs.cwd().access("os_test_tmp" ++ fs.path.sep_str ++ "file.txt", .{});
    try fs.cwd().deleteTree("os_test_tmp");
}

fn testThreadIdFn(thread_id: *Thread.Id) void {
    thread_id.* = Thread.getCurrentId();
}

test "sendfile" {
    try fs.cwd().makePath("os_test_tmp");
    defer fs.cwd().deleteTree("os_test_tmp") catch {};

    var dir = try fs.cwd().openDir("os_test_tmp", .{});
    defer dir.close();

    const line1 = "line1\n";
    const line2 = "second line\n";
    var vecs = [_]os.iovec_const{
        .{
            .iov_base = line1,
            .iov_len = line1.len,
        },
        .{
            .iov_base = line2,
            .iov_len = line2.len,
        },
    };

    var src_file = try dir.createFileZ("sendfile1.txt", .{ .read = true });
    defer src_file.close();

    try src_file.writevAll(&vecs);

    var dest_file = try dir.createFileZ("sendfile2.txt", .{ .read = true });
    defer dest_file.close();

    const header1 = "header1\n";
    const header2 = "second header\n";
    const trailer1 = "trailer1\n";
    const trailer2 = "second trailer\n";
    var hdtr = [_]os.iovec_const{
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
    expect(mem.eql(u8, written_buf[0..amt], "header1\nsecond header\nine1\nsecontrailer1\nsecond trailer\n"));
}

test "fs.copyFile" {
    const data = "u6wj+JmdF3qHsFPE BUlH2g4gJCmEz0PP";
    const src_file = "tmp_test_copy_file.txt";
    const dest_file = "tmp_test_copy_file2.txt";
    const dest_file2 = "tmp_test_copy_file3.txt";

    const cwd = fs.cwd();

    try cwd.writeFile(src_file, data);
    defer cwd.deleteFile(src_file) catch {};

    try cwd.copyFile(src_file, cwd, dest_file, .{});
    defer cwd.deleteFile(dest_file) catch {};

    try cwd.copyFile(src_file, cwd, dest_file2, .{ .override_mode = File.default_mode });
    defer cwd.deleteFile(dest_file2) catch {};

    try expectFileContents(dest_file, data);
    try expectFileContents(dest_file2, data);
}

fn expectFileContents(file_path: []const u8, data: []const u8) !void {
    const contents = try fs.cwd().readFileAlloc(testing.allocator, file_path, 1000);
    defer testing.allocator.free(contents);

    testing.expectEqualSlices(u8, data, contents);
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
    const cpu_count = try Thread.cpuCount();
    expect(cpu_count >= 1);
}

test "AtomicFile" {
    const test_out_file = "tmp_atomic_file_test_dest.txt";
    const test_content =
        \\ hello!
        \\ this is a test file
    ;
    {
        var af = try fs.cwd().atomicFile(test_out_file, .{});
        defer af.deinit();
        try af.file.writeAll(test_content);
        try af.finish();
    }
    const content = try fs.cwd().readFileAlloc(testing.allocator, test_out_file, 9999);
    defer testing.allocator.free(content);
    expect(mem.eql(u8, content, test_content));

    try fs.cwd().deleteFile(test_out_file);
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
    // at least call it so it gets compiled
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    _ = os.getcwd(&buf) catch undefined;
}

test "realpath" {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    testing.expectError(error.FileNotFound, fs.realpath("definitely_bogus_does_not_exist1234", &buf));
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
    if (builtin.os.tag == .windows or builtin.os.tag == .wasi or builtin.os.tag == .macosx)
        return error.SkipZigTest;

    var counter: usize = 0;
    try os.dl_iterate_phdr(&counter, IterFnError, iter_fn);
    expect(counter != 0);
}

test "gethostname" {
    if (builtin.os.tag == .windows)
        return error.SkipZigTest;

    var buf: [os.HOST_NAME_MAX]u8 = undefined;
    const hostname = try os.gethostname(&buf);
    expect(hostname.len != 0);
}

test "pipe" {
    if (builtin.os.tag == .windows)
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
    if (builtin.os.tag == .windows)
        return error.SkipZigTest;

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
        const file = try fs.cwd().createFile(test_out_file, .{});
        defer file.close();

        const stream = file.outStream();

        var i: u32 = 0;
        while (i < alloc_size / @sizeOf(u32)) : (i += 1) {
            try stream.writeIntNative(u32, i);
        }
    }

    // Map the whole file
    {
        const file = try fs.cwd().openFile(test_out_file, .{});
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
        const file = try fs.cwd().openFile(test_out_file, .{});
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

    try fs.cwd().deleteFile(test_out_file);
}

test "getenv" {
    if (builtin.os.tag == .windows) {
        expect(os.getenvW(&[_:0]u16{ 'B', 'O', 'G', 'U', 'S', 0x11, 0x22, 0x33, 0x44, 0x55 }) == null);
    } else {
        expect(os.getenvZ("BOGUSDOESNOTEXISTENVVAR") == null);
    }
}

test "fcntl" {
    if (builtin.os.tag == .windows)
        return error.SkipZigTest;

    const test_out_file = "os_tmp_test";

    const file = try fs.cwd().createFile(test_out_file, .{});
    defer {
        file.close();
        fs.cwd().deleteFile(test_out_file) catch {};
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
