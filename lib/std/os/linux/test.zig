const std = @import("../../std.zig");
const builtin = @import("builtin");
const linux = std.os.linux;
const mem = std.mem;
const elf = std.elf;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const fs = std.fs;

test "fallocate" {
    if (builtin.cpu.arch.isMIPS64() and (builtin.abi == .gnuabin32 or builtin.abi == .muslabin32)) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/23809

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const path = "test_fallocate";
    const file = try tmp.dir.createFile(path, .{ .truncate = true, .mode = 0o666 });
    defer file.close();

    try expect((try file.stat()).size == 0);

    const len: i64 = 65536;
    switch (linux.E.init(linux.fallocate(file.handle, 0, 0, len))) {
        .SUCCESS => {},
        .NOSYS => return error.SkipZigTest,
        .OPNOTSUPP => return error.SkipZigTest,
        else => |errno| std.debug.panic("unhandled errno: {}", .{errno}),
    }

    try expect((try file.stat()).size == len);
}

test "getpid" {
    try expect(linux.getpid() != 0);
}

test "getppid" {
    try expect(linux.getppid() != 0);
}

test "timer" {
    const epoll_fd = linux.epoll_create();
    var err: linux.E = linux.E.init(epoll_fd);
    try expect(err == .SUCCESS);

    const timer_fd = linux.timerfd_create(linux.TIMERFD_CLOCK.MONOTONIC, .{});
    try expect(linux.E.init(timer_fd) == .SUCCESS);

    const time_interval = linux.timespec{
        .sec = 0,
        .nsec = 2000000,
    };

    const new_time = linux.itimerspec{
        .it_interval = time_interval,
        .it_value = time_interval,
    };

    err = linux.E.init(linux.timerfd_settime(@as(i32, @intCast(timer_fd)), .{}, &new_time, null));
    try expect(err == .SUCCESS);

    var event = linux.epoll_event{
        .events = linux.EPOLL.IN | linux.EPOLL.OUT | linux.EPOLL.ET,
        .data = linux.epoll_data{ .ptr = 0 },
    };

    err = linux.E.init(linux.epoll_ctl(@as(i32, @intCast(epoll_fd)), linux.EPOLL.CTL_ADD, @as(i32, @intCast(timer_fd)), &event));
    try expect(err == .SUCCESS);

    const events_one: linux.epoll_event = undefined;
    var events = [_]linux.epoll_event{events_one} ** 8;

    err = linux.E.init(linux.epoll_wait(@as(i32, @intCast(epoll_fd)), &events, 8, -1));
    try expect(err == .SUCCESS);
}

test "statx" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_file_name = "just_a_temporary_file.txt";
    var file = try tmp.dir.createFile(tmp_file_name, .{});
    defer file.close();

    var statx_buf: linux.Statx = undefined;
    switch (linux.E.init(linux.statx(file.handle, "", linux.AT.EMPTY_PATH, linux.STATX_BASIC_STATS, &statx_buf))) {
        .SUCCESS => {},
        else => unreachable,
    }

    if (builtin.cpu.arch == .riscv32 or builtin.cpu.arch.isLoongArch()) return error.SkipZigTest; // No fstatat, so the rest of the test is meaningless.

    var stat_buf: linux.Stat = undefined;
    switch (linux.E.init(linux.fstatat(file.handle, "", &stat_buf, linux.AT.EMPTY_PATH))) {
        .SUCCESS => {},
        else => unreachable,
    }

    try expect(stat_buf.mode == statx_buf.mode);
    try expect(@as(u32, @bitCast(stat_buf.uid)) == statx_buf.uid);
    try expect(@as(u32, @bitCast(stat_buf.gid)) == statx_buf.gid);
    try expect(@as(u64, @bitCast(@as(i64, stat_buf.size))) == statx_buf.size);
    try expect(@as(u64, @bitCast(@as(i64, stat_buf.blksize))) == statx_buf.blksize);
    try expect(@as(u64, @bitCast(@as(i64, stat_buf.blocks))) == statx_buf.blocks);
}

test "user and group ids" {
    if (builtin.link_libc) return error.SkipZigTest;
    try expectEqual(linux.getauxval(elf.AT_UID), linux.getuid());
    try expectEqual(linux.getauxval(elf.AT_GID), linux.getgid());
    try expectEqual(linux.getauxval(elf.AT_EUID), linux.geteuid());
    try expectEqual(linux.getauxval(elf.AT_EGID), linux.getegid());
}

test "fadvise" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_file_name = "temp_posix_fadvise.txt";
    var file = try tmp.dir.createFile(tmp_file_name, .{});
    defer file.close();

    var buf: [2048]u8 = undefined;
    try file.writeAll(&buf);

    const ret = linux.fadvise(file.handle, 0, 0, linux.POSIX_FADV.SEQUENTIAL);
    try expectEqual(@as(usize, 0), ret);
}

test "sigset_t" {
    std.debug.assert(@sizeOf(linux.sigset_t) == (linux.NSIG / 8));

    var sigset = linux.sigemptyset();

    // See that none are set, then set each one, see that they're all set, then
    // remove them all, and then see that none are set.
    for (1..linux.NSIG) |i| {
        try expectEqual(linux.sigismember(&sigset, @truncate(i)), false);
    }
    for (1..linux.NSIG) |i| {
        linux.sigaddset(&sigset, @truncate(i));
    }
    for (1..linux.NSIG) |i| {
        try expectEqual(linux.sigismember(&sigset, @truncate(i)), true);
    }
    for (1..linux.NSIG) |i| {
        linux.sigdelset(&sigset, @truncate(i));
    }
    for (1..linux.NSIG) |i| {
        try expectEqual(linux.sigismember(&sigset, @truncate(i)), false);
    }

    // Kernel sigset_t is either 2+ 32-bit values or 1+ 64-bit value(s).
    const sigset_len = @typeInfo(linux.sigset_t).array.len;
    const sigset_elemis64 = 64 == @bitSizeOf(@typeInfo(linux.sigset_t).array.child);

    linux.sigaddset(&sigset, 1);
    try expectEqual(sigset[0], 1);
    if (sigset_len > 1) {
        try expectEqual(sigset[1], 0);
    }

    linux.sigaddset(&sigset, 31);
    try expectEqual(sigset[0], 0x4000_0001);
    if (sigset_len > 1) {
        try expectEqual(sigset[1], 0);
    }

    linux.sigaddset(&sigset, 36);
    if (sigset_elemis64) {
        try expectEqual(sigset[0], 0x8_4000_0001);
    } else {
        try expectEqual(sigset[0], 0x4000_0001);
        try expectEqual(sigset[1], 0x8);
    }

    linux.sigaddset(&sigset, 64);
    if (sigset_elemis64) {
        try expectEqual(sigset[0], 0x8000_0008_4000_0001);
    } else {
        try expectEqual(sigset[0], 0x4000_0001);
        try expectEqual(sigset[1], 0x8000_0008);
    }
}

test "sigfillset" {
    // unlike the C library, all the signals are set in the kernel-level fillset
    const sigset = linux.sigfillset();
    for (1..linux.NSIG) |i| {
        try expectEqual(linux.sigismember(&sigset, @truncate(i)), true);
    }
}

test "sigemptyset" {
    const sigset = linux.sigemptyset();
    for (1..linux.NSIG) |i| {
        try expectEqual(linux.sigismember(&sigset, @truncate(i)), false);
    }
}

test "sysinfo" {
    var info: linux.Sysinfo = undefined;
    const result: usize = linux.sysinfo(&info);
    try expect(std.os.linux.E.init(result) == .SUCCESS);

    try expect(info.mem_unit > 0);
    try expect(info.mem_unit <= std.heap.page_size_max);
}

test {
    _ = linux.IoUring;
}
