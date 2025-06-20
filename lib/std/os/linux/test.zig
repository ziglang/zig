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

// socket functions not tested:
// - send (these forward to sendto in the kernel, and Zig doesn't provide bindings for them)
// - recv (these forward to recvfrom in the kernel, and Zig doesn't provide bindings for them)
// - accept4 (accept forwards to accept4 in the kernel, and Zig's binding for accept forwards directly to accept4)

test "inet sockets" {
    // socket functions tested:
    // - [x] socket
    // - [x] bind
    // - [x] connect
    // - [x] listen
    // - [x] accept (and by extension accept4)
    // - [x] getsockname
    // - [x] getpeername
    // - [ ] socketpair
    // - [ ] send
    // - [ ] recv
    // - [x] sendto
    // - [x] recvfrom
    // - [x] shutdown
    // - [x] setsockopt
    // - [x] getsockopt
    // - [ ] sendmsg
    // - [ ] recvmsg
    // - [ ] accept4
    // - [ ] recvmmsg
    // - [ ] sendmmsg

    const AF = linux.AF;
    const SOCK = linux.SOCK;
    const SOL = linux.SOL;
    const SO = linux.SO;
    const E = linux.E;
    const fd_t = linux.fd_t;
    const sockaddr = linux.sockaddr;

    // create a socket "fd" to be the server
    var rc = linux.socket(AF.INET, SOCK.STREAM, 0);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    const fd: fd_t = @intCast(rc);

    const test_sndbuf: c_int = 4096;
    rc = linux.setsockopt(fd, SOL.SOCKET, SO.SNDBUF, std.mem.asBytes(&test_sndbuf).ptr, std.mem.asBytes(&test_sndbuf).len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    var sndbuf: c_int = undefined;
    var sndbuf_len: linux.socklen_t = std.mem.asBytes(&sndbuf).len;
    rc = linux.getsockopt(fd, SOL.SOCKET, SO.SNDBUF, std.mem.asBytes(&sndbuf).ptr, &sndbuf_len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
    try std.testing.expectEqual(test_sndbuf * 2, sndbuf);

    var addr: sockaddr.storage = undefined;
    var len: u32 = @sizeOf(@TypeOf(addr));
    rc = linux.getsockname(fd, @ptrCast(&addr), &len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
    try std.testing.expectEqual(@sizeOf(sockaddr.in), len);
    try std.testing.expectEqual(AF.INET, addr.family);
    const addr_in = @as(*sockaddr.in, @ptrCast(&addr));
    try std.testing.expectEqual(0, addr_in.addr);
    try std.testing.expectEqual(0, addr_in.port);

    // bind the socket to a random port
    const INADDR_LOOPBACK = std.mem.nativeToBig(u32, 0x7F_00_00_01);
    addr = undefined;
    addr_in.* = .{
        .addr = INADDR_LOOPBACK,
        .port = 0,
    };
    rc = linux.bind(fd, @ptrCast(&addr), @sizeOf(sockaddr.in));
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    // test getsockname
    addr = undefined;
    len = @sizeOf(@TypeOf(addr));
    rc = linux.getsockname(fd, @ptrCast(&addr), &len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
    try std.testing.expectEqual(@sizeOf(sockaddr.in), len);
    try std.testing.expectEqual(AF.INET, addr.family);
    try std.testing.expectEqual(INADDR_LOOPBACK, addr_in.addr);
    const bind_port = addr_in.port;

    // listen with a backlog of one so we can establish a connection and accept on the same thread
    rc = linux.listen(fd, 1);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    // create another socket "other_fd" to be the client
    rc = linux.socket(AF.INET, SOCK.STREAM, 0);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    const other_fd: fd_t = @intCast(rc);

    // connect to other_fd from fd
    addr = undefined;
    addr_in.* = .{
        .addr = INADDR_LOOPBACK,
        .port = bind_port,
    };
    rc = linux.connect(other_fd, @ptrCast(&addr), @sizeOf(sockaddr.in));
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    // check connection sock addr
    addr = undefined;
    len = @sizeOf(@TypeOf(addr));
    rc = linux.getsockname(other_fd, @ptrCast(&addr), &len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
    try std.testing.expectEqual(@sizeOf(sockaddr.in), len);
    try std.testing.expectEqual(AF.INET, addr.family);
    try std.testing.expectEqual(INADDR_LOOPBACK, addr_in.addr);
    const other_port = addr_in.port;

    // check connection peer addr
    addr = undefined;
    len = @sizeOf(@TypeOf(addr));
    rc = linux.getpeername(other_fd, @ptrCast(&addr), &len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
    try std.testing.expectEqual(@sizeOf(sockaddr.in), len);
    try std.testing.expectEqual(AF.INET, addr.family);
    try std.testing.expectEqual(INADDR_LOOPBACK, addr_in.addr);
    try std.testing.expectEqual(bind_port, addr_in.port);

    // accept the connection to fd from other_fd and check peer addr
    addr = undefined;
    len = @sizeOf(@TypeOf(addr));
    rc = linux.accept(fd, @ptrCast(&addr), &len);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(AF.INET, addr.family);
    try std.testing.expectEqual(INADDR_LOOPBACK, addr_in.addr);
    try std.testing.expectEqual(other_port, addr_in.port);
    const conn_fd: fd_t = @intCast(rc);

    const data = "foo";
    rc = linux.sendto(conn_fd, data, data.len, 0, null, 0);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(data.len, rc);

    rc = linux.shutdown(fd, linux.SHUT.RDWR);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    var recv_data: [data.len]u8 = undefined;
    rc = linux.recvfrom(other_fd, &recv_data, recv_data.len, 0, null, null);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(recv_data.len, rc);
    try std.testing.expectEqualSlices(u8, data, &recv_data);

    rc = linux.close(conn_fd);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    rc = linux.close(fd);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    rc = linux.close(other_fd);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
}

test "unix sockets sendmsg and recvmsg" {
    // socket functions tested:
    // - [ ] socket
    // - [ ] bind
    // - [ ] connect
    // - [ ] listen
    // - [ ] accept
    // - [ ] getsockname
    // - [ ] getpeername
    // - [x] socketpair
    // - [ ] send
    // - [ ] recv
    // - [ ] sendto
    // - [ ] recvfrom
    // - [ ] shutdown
    // - [ ] setsockopt
    // - [ ] getsockopt
    // - [x] sendmsg
    // - [x] recvmsg
    // - [ ] accept4
    // - [ ] recvmmsg
    // - [ ] sendmmsg

    const AF = linux.AF;
    const SOCK = linux.SOCK;
    const E = linux.E;
    const iovec = std.posix.iovec;
    const iovec_const = std.posix.iovec_const;

    // create a socket "fd" to be the server
    var socks: [2]linux.socket_t = undefined;
    var rc = linux.socketpair(AF.UNIX, SOCK.SEQPACKET, 0, &socks);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));

    // test sendmsg
    const data = "foo";
    const send_iov: [1]iovec_const = .{.{
        .base = data,
        .len = data.len,
    }};
    rc = linux.sendmsg(socks[0], &.{
        .name = null,
        .namelen = 0,
        .iov = &send_iov,
        .iovlen = send_iov.len,
        .control = null,
        .controllen = 0,
        .flags = 0,
    }, 0);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(data.len, rc);

    // test recvmsg
    var recv_data: [data.len]u8 = undefined;
    var recv_iov: [1]iovec = .{.{
        .base = &recv_data,
        .len = recv_data.len,
    }};
    var hdr: linux.msghdr = .{
        .name = null,
        .namelen = 0,
        .iov = &recv_iov,
        .iovlen = recv_iov.len,
        .control = null,
        .controllen = 0,
        .flags = 0,
    };
    rc = linux.recvmsg(socks[1], &hdr, 0);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(data.len, rc);
    try std.testing.expectEqual(data.len, recv_iov[0].len);
    try std.testing.expectEqualSlices(u8, data, &recv_data);

    rc = linux.close(socks[0]);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    rc = linux.close(socks[1]);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
}

test "unix sockets sendmmsg and recvmmsg" {
    // socket functions tested:
    // - [ ] socket
    // - [ ] bind
    // - [ ] connect
    // - [ ] listen
    // - [ ] accept
    // - [ ] getsockname
    // - [ ] getpeername
    // - [x] socketpair
    // - [ ] send
    // - [ ] recv
    // - [ ] sendto
    // - [ ] recvfrom
    // - [ ] shutdown
    // - [ ] setsockopt
    // - [ ] getsockopt
    // - [ ] sendmsg
    // - [ ] recvmsg
    // - [ ] accept4
    // - [x] recvmmsg
    // - [x] sendmmsg

    const AF = linux.AF;
    const SOCK = linux.SOCK;
    const E = linux.E;
    const iovec = std.posix.iovec;
    const iovec_const = std.posix.iovec_const;

    // create a socket "fd" to be the server
    var socks: [2]linux.socket_t = undefined;
    var rc = linux.socketpair(AF.UNIX, SOCK.SEQPACKET, 0, &socks);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));

    // test sendmmsg
    const data: [2][]const u8 = .{ "foo", "bar" };
    const send_iov: [2][1]iovec_const = .{
        .{.{
            .base = data[0].ptr,
            .len = data[0].len,
        }},
        .{.{
            .base = data[1].ptr,
            .len = data[1].len,
        }},
    };
    var send_hdr: [2]linux.mmsghdr_const = .{
        .{
            .hdr = .{
                .name = null,
                .namelen = 0,
                .iov = &send_iov[0],
                .iovlen = send_iov[0].len,
                .control = null,
                .controllen = 0,
                .flags = 0,
            },
            .len = 0,
        },
        .{
            .hdr = .{
                .name = null,
                .namelen = 0,
                .iov = &send_iov[1],
                .iovlen = send_iov[1].len,
                .control = null,
                .controllen = 0,
                .flags = 0,
            },
            .len = 0,
        },
    };
    rc = linux.sendmmsg(socks[0], &send_hdr, 2, 0);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(data.len, rc);
    for (data, send_hdr) |data_el, hdr| {
        try std.testing.expectEqual(data_el.len, hdr.len);
    }

    // test recvmmsg
    var recv_data: struct { [data[0].len]u8, [data[1].len]u8 } = undefined;
    var recv_iov: [2][1]iovec = .{
        .{.{
            .base = &recv_data[0],
            .len = recv_data[0].len,
        }},
        .{.{
            .base = &recv_data[1],
            .len = recv_data[1].len,
        }},
    };
    var recv_hdr: [2]linux.mmsghdr = .{
        .{
            .hdr = .{
                .name = null,
                .namelen = 0,
                .iov = &recv_iov[0],
                .iovlen = recv_iov[0].len,
                .control = null,
                .controllen = 0,
                .flags = 0,
            },
            .len = 0,
        },
        .{
            .hdr = .{
                .name = null,
                .namelen = 0,
                .iov = &recv_iov[1],
                .iovlen = recv_iov[1].len,
                .control = null,
                .controllen = 0,
                .flags = 0,
            },
            .len = 0,
        },
    };
    rc = linux.recvmmsg(socks[1], &recv_hdr, recv_hdr.len, 0, null);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(recv_hdr.len, rc);
    inline for (data, recv_iov, &recv_data) |data_el, iov, *recv_data_el| {
        try std.testing.expectEqual(data_el.len, iov[0].len);
        try std.testing.expectEqualSlices(u8, data_el, recv_data_el);
    }

    rc = linux.close(socks[0]);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);

    rc = linux.close(socks[1]);
    try std.testing.expectEqual(.SUCCESS, E.init(rc));
    try std.testing.expectEqual(0, rc);
}

test {
    _ = linux.IoUring;
}
