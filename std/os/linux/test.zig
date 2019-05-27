const std = @import("../../std.zig");
const builtin = @import("builtin");
const linux = std.os.linux;
const mem = std.mem;
const elf = std.elf;
const expect = std.testing.expect;

test "getpid" {
    expect(linux.getpid() != 0);
}

test "timer" {
    const epoll_fd = linux.epoll_create();
    var err: usize = linux.getErrno(epoll_fd);
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

export fn iter_fn(info: *linux.dl_phdr_info, size: usize, data: ?*usize) i32 {
    var counter = data.?;
    // Count how many libraries are loaded
    counter.* += usize(1);

    // The image should contain at least a PT_LOAD segment
    if (info.dlpi_phnum < 1) return -1;

    // Quick & dirty validation of the phdr pointers, make sure we're not
    // pointing to some random gibberish
    var i: usize = 0;
    var found_load = false;
    while (i < info.dlpi_phnum) : (i += 1) {
        const phdr = info.dlpi_phdr[i];

        if (phdr.p_type != elf.PT_LOAD) continue;

        // Find the ELF header
        const elf_header = @intToPtr(*elf.Ehdr, phdr.p_vaddr - phdr.p_offset);
        // Validate the magic
        if (!mem.eql(u8, elf_header.e_ident[0..], "\x7fELF")) return -1;
        // Consistency check
        if (elf_header.e_phnum != info.dlpi_phnum) return -1;

        found_load = true;
        break;
    }

    if (!found_load) return -1;

    return 42;
}

test "dl_iterate_phdr" {
    var counter: usize = 0;
    expect(linux.dl_iterate_phdr(usize, iter_fn, &counter) != 0);
    expect(counter != 0);
}
