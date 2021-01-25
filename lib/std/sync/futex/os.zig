// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const generic = @import("./generic.zig");
const SpinFutex = @import("./spin.zig");

const testing = std.testing;
const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub usingnamespace if (builtin.os.tag == .windows)
    WindowsFutex
else if (comptime std.Target.current.isDarwin())
    DarwinFutex
else if (builtin.os.tag == .linux)
    LinuxFutex
else if (std.Thread.use_pthreads)
    PosixFutex
else
    SpinFutex;

const LinuxFutex = struct {
    const linux = std.os.linux;

    pub fn now() u64 {
        return std.time.now();
    }

    pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
        while (true) {
            if (atomic.load(ptr, .SeqCst) != expect) {
                return;
            }

            var ts: linux.timespec = undefined;
            var ts_ptr: ?*const linux.timespec = null;

            if (deadline) |deadline_ns| {
                const now_ns = now();
                if (now_ns > deadline_ns) {
                    return error.TimedOut;
                }

                const timeout_ns = deadline_ns - now_ns;
                ts_ptr = &ts;
                ts.tv_sec = @intCast(@TypeOf(ts.tv_sec), @divFloor(timeout_ns, std.time.ns_per_s));
                ts.tv_nsec = @intCast(@TypeOf(ts.tv_nsec), @mod(timeout_ns, std.time.ns_per_s));
            }

            switch (linux.getErrno(linux.futex_wait(
                @ptrCast(*const i32, ptr),
                linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAIT,
                @bitCast(i32, expect),
                ts_ptr,
            ))) {
                0 => {},
                std.os.EINTR => {},
                std.os.EAGAIN => return,
                std.os.ETIMEDOUT => return error.TimedOut,
                else => unreachable,
            }
        }
    }

    pub fn notifyOne(ptr: *const u32) void {
        return wake(ptr, 1);
    }

    pub fn notifyAll(ptr: *const u32) void {
        return wake(ptr, std.math.maxInt(i32));
    }

    fn wake(ptr: *const u32, max_threads_to_wake: i32) void {
        switch (linux.getErrno(linux.futex_wake(
            @ptrCast(*const i32, ptr),
            linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAKE,
            max_threads_to_wake,
        ))) {
            0 => {},
            std.os.EFAULT => {},
            else => unreachable,
        }
    }
};

const DarwinFutex = struct {
    pub usingnamespace if (ULockFutex.is_supported) ULockFutex else PosixFutex;

    const ULockFutex = struct {
        const darwin = std.os.darwin;
        const version = std.Target.current.os.version_range.semver.min;
        const is_supported = switch (builtin.os.tag) {
            .macos => (version.major >= 10) and (version.minor >= 12),
            .ios => (version.major >= 10) and (version.minor >= 0),
            .tvos => (version.major >= 10) and (version.minor >= 0),
            .watchos => (version.major >= 3) and (version.minor >= 0),
            else => unreachable,
        };
        
        pub fn now() u64 {
            return std.time.now();
        }

        pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
            while (true) {
                if (atomic.load(ptr, .SeqCst) != expect) {
                    return;
                }

                var timeout_us: u32 = std.math.maxInt(u32);
                if (deadline) |deadline_ns| {
                    const now_ns = now();
                    if (now_ns > deadline_ns) {
                        return error.TimedOut;
                    }

                    const timeout_ns = deadline_ns - now_ns;
                    const micros = @divFloor(timeout_ns, std.time.ns_per_us);
                    timeout_us = std.math.cast(u32, micros) catch timeout_us;
                }

                const ret = darwin.__ulock_wait(
                    darwin.UL_COMPARE_AND_WAIT | darwin.ULF_NO_ERRNO,
                    @ptrCast(*const c_void, ptr),
                    @as(u64, expect),
                    timeout_us,
                );

                if (ret < 0) {
                    switch (-ret) {
                        darwin.EINTR => continue,
                        darwin.EFAULT => unreachable,
                        darwin.ETIMEDOUT => return error.TimedOut,
                        else => unreachable,
                    }
                }
            }
        }

        pub fn notifyOne(ptr: *const u32) void {
            return wake(ptr, 0);
        }

        pub fn notifyAll(ptr: *const u32) void {
            return wake(ptr, darwin.ULF_WAKE_ALL);
        }

        fn wake(ptr: *const u32, flags: u32) void {
            while (true) {
                const ret = darwin.__ulock_wake(
                    darwin.UL_COMPARE_AND_WAIT | flags,
                    @ptrCast(*const c_void, ptr),
                    @as(u64, 0),
                );

                if (ret < 0) {
                    switch (-ret) {
                        darwin.ENOENT => {},
                        darwin.EINTR => continue,
                        else => unreachable,
                    }
                }

                return;
            }
        }
    };
};

const PosixFutex = generic.Futex(struct {
    state: enum { empty, waiting, notified },
    cond: c.pthread_cond_t,
    mutex: c.pthread_mutex_t,

    const c = std.c;
    const Self = @This();

    pub const bucket_count = std.meta.bitCount(usize) << 2;
    pub const Lock = struct {
        mutex: c.pthread_mutex_t = c.PTHREAD_MUTEX_INITIALIZER,

        pub fn acquire(self: *Lock) Held {
            assert(c.pthread_mutex_lock(&self.mutex) == 0);
            return Held{ .mutex = &self.mutex };
        }

        pub const Held = struct {
            mutex: *c.pthread_mutex_t,

            pub fn release(self: Held) void {
                assert(c.pthread_mutex_unlock(self.mutex) == 0);
            }
        };
    };

    pub fn now() u64 {
        return std.time.now();
    }

    pub fn init(self: *Self) void {
        self.* = Self{
            .state = .empty,
            .cond = c.PTHREAD_COND_INITIALIZER,
            .mutex = c.PTHREAD_MUTEX_INITIALIZER,
        };
    }

    pub fn deinit(self: *Self) void {
        // On some BSD's like DragonFly, a statically initialized mutex can return EINVAL on deinit.
        const cond_rc = c.pthread_cond_destroy(&self.cond);
        assert(cond_rc == 0 or cond_rc == std.os.EINVAL);

        const mutex_rc = c.pthread_mutex_destroy(&self.mutex);
        assert(mutex_rc == 0 or mutex_rc == std.os.EINVAL);

        self.* = undefined;
    }

    pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        // Trasition to waiting if not already.
        // There must not be multiple threads waiting on the same event (its SPSC).
        // It could be notified at this point if the set() thread won the mutex race.
        switch (self.state) {
            .empty => self.state = .waiting,
            .waiting => unreachable,
            .notified => return,
        }

        while (true) {
            switch (self.state) {
                .empty => unreachable,
                .waiting => {},
                .notified => return,
            }

            var ts: std.os.timespec = undefined;
            const has_ts = blk: {
                // Timeout is based on the now() (monotonic timer)
                // instead of pthread as cond_wait/timed_wait() use calender time
                // which is affected by the system and can be set forwards/backwards.
                const deadline_ns = deadline orelse break :blk false;
                const now_ns = now();
                if (now_ns > deadline_ns) {
                    self.state = .empty;
                    return error.TimedOut;
                }

                const Sec = @TypeOf(ts.tv_sec);
                const Nano = @TypeOf(ts.tv_nsec);
                const timeout = deadline_ns - now_ns;
                std.os.clock_gettime(std.os.CLOCK_REALTIME, &ts) catch break :blk false;

                const timeout_nsec = std.math.cast(Nano, timeout % std.time.ns_per_s) catch break :blk false;
                if (@addWithOverflow(Nano, ts.tv_nsec, timeout_nsec, &ts.tv_nsec)) {
                    break :blk false;
                }

                const timeout_sec = std.math.cast(Sec, timeout / std.time.ns_per_s) catch break :blk false;
                if (@addWithOverflow(Sec, ts.tv_sec, timeout_sec, &ts.tv_sec)) {
                    break :blk false;
                }

                while (ts.tv_nsec > std.time.ns_per_s) {
                    ts.tv_nsec -= std.time.ns_per_s;
                    if (@addWithOverflow(Sec, ts.tv_sec, 1, &ts.tv_sec)) {
                        break :blk false;
                    }
                }

                break :blk true;
            };

            const rc = switch (has_ts) {
                true => c.pthread_cond_timedwait(&self.cond, &self.mutex, &ts),
                else => c.pthread_cond_wait(&self.cond, &self.mutex),
            };

            switch (rc) {
                0 => {},
                std.os.ETIMEDOUT => {},
                else => unreachable,
            }
        }
    }

    pub fn set(self: *Self) void {
        assert(c.pthread_mutex_lock(&self.mutex) == 0);
        defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

        switch (self.state) {
            .empty => {
                self.state = .notified;
            },
            .waiting => {
                self.state = .notified;
                assert(c.pthread_cond_signal(&self.cond) == 0);
            },
            .notified => {
                unreachable; // PosixEvent was set twice
            },
        }
    }

    pub fn reset(self: *Self) void {
        self.state = .empty;
    }
});

const WindowsFutex = @compileError("TODO: WaitOnAddress -> fallback to Generic(NtKeyedEvent)");
