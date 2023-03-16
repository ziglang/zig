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
    switch (linux.getErrno(linux.fallocate(file.handle, 0, 0, len))) {
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

test "timer" {
    const epoll_fd = linux.epoll_create();
    var err: linux.E = linux.getErrno(epoll_fd);
    try expect(err == .SUCCESS);

    const timer_fd = linux.timerfd_create(linux.CLOCK.MONOTONIC, 0);
    try expect(linux.getErrno(timer_fd) == .SUCCESS);

    const time_interval = linux.timespec{
        .tv_sec = 0,
        .tv_nsec = 2000000,
    };

    const new_time = linux.itimerspec{
        .it_interval = time_interval,
        .it_value = time_interval,
    };

    err = linux.getErrno(linux.timerfd_settime(@intCast(i32, timer_fd), 0, &new_time, null));
    try expect(err == .SUCCESS);

    var event = linux.epoll_event{
        .events = linux.EPOLL.IN | linux.EPOLL.OUT | linux.EPOLL.ET,
        .data = linux.epoll_data{ .ptr = 0 },
    };

    err = linux.getErrno(linux.epoll_ctl(@intCast(i32, epoll_fd), linux.EPOLL.CTL_ADD, @intCast(i32, timer_fd), &event));
    try expect(err == .SUCCESS);

    const events_one: linux.epoll_event = undefined;
    var events = [_]linux.epoll_event{events_one} ** 8;

    err = linux.getErrno(linux.epoll_wait(@intCast(i32, epoll_fd), &events, 8, -1));
    try expect(err == .SUCCESS);
}

test "statx" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_file_name = "just_a_temporary_file.txt";
    var file = try tmp.dir.createFile(tmp_file_name, .{});
    defer file.close();

    var statx_buf: linux.Statx = undefined;
    switch (linux.getErrno(linux.statx(file.handle, "", linux.AT.EMPTY_PATH, linux.STATX_BASIC_STATS, &statx_buf))) {
        .SUCCESS => {},
        // The statx syscall was only introduced in linux 4.11
        .NOSYS => return error.SkipZigTest,
        else => unreachable,
    }

    var stat_buf: linux.Stat = undefined;
    switch (linux.getErrno(linux.fstatat(file.handle, "", &stat_buf, linux.AT.EMPTY_PATH))) {
        .SUCCESS => {},
        else => unreachable,
    }

    try expect(stat_buf.mode == statx_buf.mode);
    try expect(@bitCast(u32, stat_buf.uid) == statx_buf.uid);
    try expect(@bitCast(u32, stat_buf.gid) == statx_buf.gid);
    try expect(@bitCast(u64, @as(i64, stat_buf.size)) == statx_buf.size);
    try expect(@bitCast(u64, @as(i64, stat_buf.blksize)) == statx_buf.blksize);
    try expect(@bitCast(u64, @as(i64, stat_buf.blocks)) == statx_buf.blocks);
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
