const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
use @import("event_common.zig");

pub const EventMd = struct {
    fd: i32
};

const TimerData = struct {
    timeout: u64,
    closure: usize,
    handler: usize
};

const ManagedData = struct {
    closure: usize,
    handler: usize
};

const EventData = enum {
    Timer: TimerData,
    Socket,
    Managed: ManagedData
};

pub const Event = struct {
    md: EventMd,
    data: EventData
};

pub const Timer = struct {
    event: Event,

    const Self = this;

    pub fn init(timeout: u64, closure: usize, handler: usize) -> %Self {
        const fd = linux.timerfd_create(linux.CLOCK_MONOTONIC, 0);
        var err = linux.getErrno(fd);
        if (err != 0) {
            return switch (err) {
                linux.EMFILE => error.SystemResources,
                linux.ENOMEM => error.OutOfMemory,
                linux.ENODEV => error.NoDevice,
                else => error.Unexpected
            }
        }

        %defer {
            switch (linux.getErrno(linux.close(i32(fd)))) {
                0 => {},
                else => {}
            }
        }

        comptime const nsec_in_sec = 1000 * 1000 * 1000;
        const time_interval = linux.timespec {
            .tv_sec = isize(timeout / nsec_in_sec),
            .tv_nsec = isize(timeout % nsec_in_sec)
        };

        const new_time = linux.itimerspec {
            .it_interval = time_interval,
            .it_value = time_interval
        };

        err = linux.timerfd_settime(i32(fd), 0, &new_time, null);
        if (err != 0) {
            // XXX: return the appropriate error types here
            return error.Unexpected;
        }

        Self {
            .event = Event {
                .md = EventMd {
                    .fd = i32(fd)
                },
                .data = EventData.Timer {
                    TimerData {
                        .timeout = timeout,
                        .closure = closure,
                        .handler = handler
                    }
                }
            }
        }
    }

    pub fn deinit(timer: &Self) -> void {
        linux.close(timer.event.fd);
    }

    pub fn start(timer: &Self, loop: &Loop) -> %void {
        loop.register(&timer.event)
    }

    pub fn stop(timer: &Self, loop: &Loop) -> %void {
        loop.unregister(&timer.event)
    }
};

pub const ManagedEvent = struct {
    event: Event,

    const Self = this;

    pub fn init(closure: usize, handler: usize) -> %Self {
        const fd = linux.eventfd(0, linux.EFD_NONBLOCK);
        const err = linux.getErrno(fd);

        if (err != 0) {
            return switch(err) {
                linux.ENOMEM => error.OutOfMemory,
                linux.EMFILE, linux.ENFILE => error.SystemResources,
                linux.ENODEV => error.NoDevice,
                else => error.Unexpected
            }
        }

        const res = linux.fcntl_arg(i32(fd), linux.F_SETFL, linux.O_NONBLOCK);
        switch (linux.getErrno(res)) {
            0 => {},
            else => return error.Unexpected
        }

        Self {
            .event = Event {
                .md = EventMd {
                    .fd = i32(fd)
                },
                .data = EventData.Managed {
                    ManagedData {
                        .closure = closure,
                        .handler = handler
                    }
                }
            }
        }
    }

    pub fn register(event: &ManagedEvent, loop: &Loop) -> %void {
        loop.register(&event.event)
    }

    pub fn unregister(event: &ManagedEvent, loop: &Loop) -> %void {
        loop.unregister(&event.event)
    }

    pub fn trigger(event: &ManagedEvent) -> %void {
        comptime const buf = if (builtin.is_big_endian) {
            []u8{0, 0, 0, 0, 0, 0, 0, 1}
        } else {
            []u8{1, 0, 0, 0, 0, 0, 0, 0}
        };

        const res = linux.write(i32(event.event.md.fd), &buf[0], 8);
        const err = linux.getErrno(res);

        switch (err) {
            0 => {},
            else => error.Unexpected
        }
    }
};

pub const Loop = struct {
    fd: i32,

    const Self = this;

    pub fn init() -> %Self {
        const fd = linux.epoll_create();
        switch (linux.getErrno(fd)) {
            0 => Self {
                .fd = i32(fd)
            },
            linux.EMFILE => error.SystemResources,
            linux.ENOMEM => error.OutOfMemory,
            else => error.Unexpected
        }
    }

    fn register(loop: &Self, event: &Event) -> %void {
        var ep_event = linux.epoll_event {
            // XXX: make flags configurable
            .events = linux.EPOLLIN | linux.EPOLLOUT | linux.EPOLLET,
            .data = @ptrToInt(event)
        };

        const res = linux.epoll_ctl(i32(loop.fd), linux.EPOLL_CTL_ADD, i32(event.md.fd), &ep_event);
        const err = linux.getErrno(res);

        switch (err) {
            0 => {},
            linux.ENOSPC => return error.SystemResources,
            // XXX: handle other errors
            else => return error.Unexpected
        }
    }

    fn unregister(loop: &Self, event: &Event) -> %void {
        const res = linux.epoll_ctl(i32(loop.fd), linux.EPOLL_CTL_DEL, i32(event.md.fd), null);
        const err = linux.getErrno(res);

        switch (err) {
            0 => {},
            // XXX: handle other errors
            else => return error.Unexpected
        }
    }

    fn handle_timer(loop: &Self, timer: &TimerData) -> void {
        var handler = @intToPtr(&TimerHandler, timer.handler);
        (*handler)(timer.closure);
    }

    fn handle_managed(loop: &Self, data: &ManagedData) -> void {
        var handler = @intToPtr(&ManagedHandler, data.handler);
        (*handler)(data.closure);
    }

    fn handle_event(loop: &Self, data:u64) -> void {
        var context = @intToPtr(&Event, data);
        switch (context.data) {
            EventData.Timer => |*timer| {
                loop.handle_timer(timer);

                var buf = []u8{0} ** 8;
                var r = linux.read(i32(context.md.fd), &buf[0], 8);

                // XXX: don't care about number of expirations for now
                switch (linux.getErrno(r)) {
                    0 => {},
                    linux.EAGAIN => {},
                    // XXX: what should we do in this case?
                    else => @panic("timerfd read failed")
                }
            },
            EventData.Managed => |*managed| {
                var buf = []u8{0} ** 8;
                var r = linux.read(i32(context.md.fd), &buf[0], 8);

                // XXX: don't care about number of expirations for now
                const have_trigger = switch (linux.getErrno(r)) {
                    0 => true,
                    linux.EAGAIN => false,
                    // XXX: what should we do in this case?
                    else => @panic("eventfd read failed")
                };

                if (have_trigger) {
                    loop.handle_managed(managed);
                }
            },
            else => @panic("unused event type")
        }
    }

    pub fn step(loop: &Self, blocking: LoopStepBehavior) -> %void {
        comptime const events_count = 1024;
        const events_one: linux.epoll_event = undefined;

        // TODO: Make events buffer configurable or based on number of
        // registered events
        var events = []linux.epoll_event{events_one} ** events_count;
        var ready: usize = 0;

        while (true) {
            const timeout = switch (blocking) {
                LoopStepBehavior.Blocking => i32(-1),
                LoopStepBehavior.Nonblocking => i32(0),
            };
            ready = linux.epoll_wait(i32(loop.fd), &events[0], events_count, timeout);
            switch (linux.getErrno(ready)) {
                0 => break,
                linux.EINTR => continue,
                linux.EBADF => return error.BadFd,
                else => return error.Unexpected
            }
        }

        for (events[0..ready]) |*e| {
            loop.handle_event(e.data);
        }
    }

    pub fn run(loop: &Self) -> %void {
        while (true) {
            %return loop.step(LoopStepBehavior.Blocking);
        }
    }

};
