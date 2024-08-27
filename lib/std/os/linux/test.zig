const std = @import("../../std.zig");
const builtin = @import("builtin");
const linux = std.os.linux;
const mem = std.mem;
const elf = std.elf;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const fs = std.fs;

test "fallocate" {
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

    const timer_fd = linux.timerfd_create(linux.CLOCK.MONOTONIC, .{});
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

    if (builtin.cpu.arch == .riscv32) return error.SkipZigTest; // No fstatat, so the rest of the test is meaningless.

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
    var sigset = linux.empty_sigset;

    try expectEqual(linux.sigismember(&sigset, linux.SIG.USR1), false);
    try expectEqual(linux.sigismember(&sigset, linux.SIG.USR2), false);

    linux.sigaddset(&sigset, linux.SIG.USR1);

    try expectEqual(linux.sigismember(&sigset, linux.SIG.USR1), true);
    try expectEqual(linux.sigismember(&sigset, linux.SIG.USR2), false);

    linux.sigaddset(&sigset, linux.SIG.USR2);

    try expectEqual(linux.sigismember(&sigset, linux.SIG.USR1), true);
    try expectEqual(linux.sigismember(&sigset, linux.SIG.USR2), true);
}

test {
    _ = linux.IoUring;
}
