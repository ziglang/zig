const std = @import("../../std.zig");
const builtin = @import("builtin");
const linux = std.os.linux;
const expect = std.testing.expect;

test "getpid" {
    expect(linux.getpid() != 0);
}

test "timer" {
    const epoll_fd = linux.epoll_create();
    var err = linux.getErrno(epoll_fd);
    expect(err == 0);

    const timer_fd = linux.timerfd_create(linux.CLOCK_MONOTONIC, 0);
    expect(linux.getErrno(timer_fd) == 0);

    const time_interval = linux.timespec{
        .tv_sec = 0,
        .tv_nsec = 2000000,
    };

    const new_time = linux.itimerspec{
        .it_interval = time_interval,
        .it_value = time_interval,
    };

    err = linux.timerfd_settime(@intCast(i32, timer_fd), 0, &new_time, null);
    expect(err == 0);

    var event = linux.epoll_event{
        .events = linux.EPOLLIN | linux.EPOLLOUT | linux.EPOLLET,
        .data = linux.epoll_data{ .ptr = 0 },
    };

    err = linux.epoll_ctl(@intCast(i32, epoll_fd), linux.EPOLL_CTL_ADD, @intCast(i32, timer_fd), &event);
    expect(err == 0);

    const events_one: linux.epoll_event = undefined;
    var events = []linux.epoll_event{events_one} ** 8;

    // TODO implicit cast from *[N]T to [*]T
    err = linux.epoll_wait(@intCast(i32, epoll_fd), @ptrCast([*]linux.epoll_event, &events), 8, -1);
}
