// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const futex = @import("./futex.zig");
const SpinBackend = @import("./spin.zig");
const EventLock = @import("../core/Lock.zig").Lock;

const builtin = std.builtin;
const assert = std.debug.assert;
const target = std.Target.current;

pub usingnamespace if (target.os.tag == .windows)
    WindowsBackend
else if (target.os.tag == .linux)
    LinuxBackend
else if (target.isDarwin())
    DarwinBackend
else if (builtin.link_libc)
    PosixBackend
else
    SpinBackend;

const LinuxBackend = futex.Backend(struct {
    const linux = std.os.linux;

    pub fn wait(ptr: *const u32, expect: u32, timeout: ?u64) void {
        var ts: linux.timespec = undefined;
        var ts_ptr: ?*const linux.timespec = null;

        if (timeout) |timeout_ns| {
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
            std.os.EAGAIN => {},
            std.os.ETIMEDOUT => {},
            else => unreachable,
        }
    }

    pub fn wake(ptr: *const u32) void {
        switch (linux.getErrno(linux.futex_wake(
            @ptrCast(*const i32, ptr),
            linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAKE,
            @as(i32, 1),
        ))) {
            0 => {},
            std.os.EFAULT => {},
            else => unreachable,
        }
    }

    pub fn yield(iteration: ?usize) bool {
        const max_iter = 100;

        var iter = iteration orelse max_iter;
        if (iter > max_iter) {
            return false;
        }

        while (iter > 0) : (iter -= 1) {
            atomic.spinLoopHint();
        }

        return true;
    }
});

const DarwinBackend = struct {
    const darwin = std.os.darwin;

    pub usingnamespace if (ULockBackend.is_supported)
        ULockBackend
    else if (builtin.link_libc)
        PosixBackend
    else
        SpinBackend;

    const ULockBackend = struct {
        const version = target.os.tag.version_range.semver;
        const is_supported = switch (target.os.tag) {
            .macos => version.major >= 10 and version.minor >= 12,
            .ios => version.major >= 10 and version.minor >= 0,
            .tvos => version.major >= 10 and version.minor >= 0,
            .watchos => version.major >= 3 and version.minor >= 0,
            else => false,
        };

        pub usingnamespace futex.Backend(struct {
            pub fn wait(ptr: *const u32, expect: u32, timeout: ?u64) void {
                var timeout_us = std.math.maxInt(u32);
                if (timeout) |timeout_ns| {
                    const micros = @divFloor(timeout_ns, std.time.ns_per_us);
                    timeout_us = std.math.cast(u32, micros) catch timeout_us;
                }

                const ret = darwin.__ulock_wait(
                    darwin.UL_COMPARE_AND_WAIT | darwin.ULF_NO_ERRNO,
                    @ptrCast(*c_void, ptr),
                    @as(u64, expect),
                    timeout_us,
                );

                if (ret < 0) {
                    switch (-ret) {
                        darwin.EINTR => {},
                        darwin.EFAULT => {},
                        darwin.ETIMEDOUT => {},
                        else => unreachable,
                    }
                }
            }

            pub fn wake(ptr: *const u32) void {
                while (true) {
                    const ret = __ulock_wake(
                        darwin.UL_COMPARE_AND_WAIT,
                        @ptrCast(*c_void, ptr),
                        @as(u64, 0),
                    );

                    if (ret < 0) {
                        switch (-ret) {
                            system.ENOENT => {},
                            system.EINTR => continue,
                            else => unreachable,
                        }
                    }

                    return;
                }
            }

            pub fn yield(iteration: ?usize) bool {
                const max_iter = 100;

                var iter = iteration orelse max_iter;
                if (iter > max_iter) {
                    return false;
                }

                while (iter > 0) : (iter -= 1) {
                    atomic.spinLoopHint();
                }

                return true;
            }
        });
    };
};

const WindowsBackend = struct {
    const windows = std.os.windows;
    
    pub const Lock = if (SRWLock.is_supported)
        SRWLock
    else if (NtKeyedLock.is_supported)
        NtKeyedLock
    else
        SpinBackend.Lock;

    pub const Event = if (SRWEvent.is_supported)
        SRWEvent
    else if (NtKeyedEvent.is_supported)
        NtKeyedEvent
    else
        SpinBackend.Event;

    fn isWindowsVersionSupported(comptime version: std.Target.Os.WindowsVersion) bool {
        return target.os.version_range.windows.isAtLeast(version) orelse false;
    }

    const SRWLock = extern struct {
        srwlock: windows.SRWLOCK = windows.SRWLOCK_INIT,

        const Self = @This();
        const is_supported = isWindowsVersionSupported(.vista);

        pub fn deinit(self: *Self) void {
            self.* = undefined;
        }

        pub fn tryAcquire(self: *Self) ?Held {
            if (windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != windows.FALSE) {
                return Held{ .lock = self };
            }

            return null;
        }

        pub fn acquire(self: *Self) Held {
            windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
            return Held{ .lock = self };
        }

        pub const Held = extern struct {
            lock: *Self,

            pub fn release(self: Held) void {
                windows.kernel32.ReleaseSRWLockExclusive(&self.lock.srwlock);
            }
        };
    };

    const SRWEvent = extern struct {
        is_set: bool,
        lock: windows.SRWLOCK,
        cond: windows.CONDITION_VARIABLE,

        const Self = @This();
        const is_supported = isWindowsVersionSupported(.vista);

        pub fn init(self: *Self) void {
            self.* = .{
                .is_set = false,
                .lock = windows.SRWLOCK_INIT,
                .cond = windows.CONDITION_VARIABLE_INIT,
            };
        }

        pub fn deinit(self: *Self) void {
            self.* = undefined;
        }

        pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
            windows.kernel32.AcquireSRWLockExclusive(&self.lock);
            defer windows.kernel32.ReleaseSRWLockExclusive(&self.lock);

            while (true) {
                if (self.is_set) {
                    return;
                }

                var timeout: windows.DWORD = windows.INFINITE;
                if (deadline) |deadline_ns| {
                    const now = std.time.now();
                    if (now > deadline_ns) {
                        return error.TimedOut;
                    } else {
                        const timeout_ms = @divFloor(deadline_ns - now, std.time.ns_per_ms);
                        timeout = std.math.cast(windows.DWORD, timeout_ms) catch timeout;
                    }
                }

                const status = windows.kernel32.SleepConditionVariableSRW(
                    &self.cond,
                    &self.lock,
                    timeout,
                    @as(windows.ULONG, 0),
                );

                if (status != windows.TRUE) {
                    switch (windows.kernel32.GetLastError()) {
                        .TIMEOUT => {},
                        else => |err| {
                            const ignored = windows.unexpectedError(err);
                            std.debug.panic("SleepConditionVariableSRW", .{});
                        },
                    }
                }
            }
        } 

        pub fn set(self: *Event) void {
            windows.kernel32.AcquireSRWLockExclusive(&self.lock);
            defer windows.kernel32.ReleaseSRWLockExclusive(&self.lock);

            self.is_set = true;
            windows.kernel32.WakeConditionVariable(&self.cond);
        }

        pub fn reset(self: *Self) void {
            self.is_set = false;
        }

        pub fn yield(iteration: ?usize) bool {
            const iter = iteration orelse {
                windows.kernel32.Sleep(0);
                return false;
            };

            const max_spin = 4000;
            if (iter < max_spin) {
                if (iter < max_spin - 100) {
                    atomic.spinLoopHint();
                } else if (iter < max_spin - 50) {
                    _ = windows.kernel32.SwitchToThread();
                } else {
                    windows.kernel32.Sleep(0);
                }
                return true;
            }

            return false;
        }
    };

    const NtKeyedLock = extern struct {
        inner: InnerLock = .{},

        const Self = @This();
        const is_supported = isWindowsVersionSupported(.xp);
        const InnerLock = EventLock(.{
            .Event = Event,
            .byte_swap = true,
        });

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }

        pub fn tryAcquire(self: *Self) ?Held {
            return self.inner.tryAcquire();
        }

        pub fn acquire(self: *Self) Held {
            return self.inner.acquire();
        }

        pub const Held = InnerLock.Held;
    };

    const NtKeyedEvent = extern struct {
        state: State,
        
        const Self = @This();
        const State = enum(u32) {
            empty,
            waiting,
            notified,
        };

        pub fn init(self: *Self) void {
            self.state = .empty;
        }

        pub fn deinit(self: *Self) void {
            self.* = undefined;
        }

        pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
            if (atomic.compareAndSwap(
                &self.state,
                .empty,
                .waiting,
                .SeqCst,
                .SeqCst,
            )) |updated| {
                assert(updated == .notified);
                return;
            }

            var timed_out = false;
            var timeout: windows.LARGE_INTEGER = undefined;
            var timeout_ptr: ?*const windows.LARGE_INTEGER = null;

            if (deadline) |deadline_ns| {
                const now = std.time.now();
                timed_out = now > deadline_ns;

                if (!timed_out) {
                    timeout_ptr = &timeout;
                    timeout = -(@intCast(windows.LARGE_INTEGER, @divFloor(deadline_ns - now, 100)));
                }
            }

            if (!timed_out) {
                switch (windows.ntdll.NtWaitForKeyedEvent(
                    null, // use global keyed event
                    @ptrCast(*align(4) const c_void, &self.state),
                    windows.FALSE, // non-alertable wait
                    timeout_ptr,
                )) {
                    .SUCCESS => {
                        return;
                    },
                    .TIMEOUT => {
                        assert(timeout_ptr != null);
                        timed_out = true;
                    },
                    else => |status| {
                        const ignored = windows.unexpectedStatus(status);
                        std.debug.panic("NtWaitForKeyedEvent", .{});
                    },
                }
            }

            assert(timed_out);
            if (atomic.compareAndSwap(
                &self.state,
                .waiting,
                .empty,
                .SeqCst,
                .SeqCst,
            )) |updated| {
                assert(updated == .notified);
            } else {
                return error.TimedOut;
            }

            switch (windows.ntdll.NtWaitForKeyedEvent(
                null, // use global keyed event
                @ptrCast(*align(4) const c_void, &self.state),
                windows.FALSE, // non-alertable wait
                null, // wait forever
            )) {
                .SUCCESS => {
                    return;
                },
                else => |status| {
                    const ignored = windows.unexpectedStatus(status);
                    std.debug.panic("NtWaitForKeyedEvent", .{});
                },
            }
        } 

        pub fn set(self: *Self) void {
            switch (atomic.swap(
                &self.state,
                .notified,
                .SeqCst,
            )) {
                .empty => return,
                .waiting => {},
                .notified => unreachable,
            }

            switch (windows.ntdll.NtReleaseKeyedEvent(
                null, // use global keyed event
                @ptrCast(*align(4) const c_void, &self.state),
                windows.FALSE, // non-alertable wait
                null, // wait forever
            )) {
                .SUCCESS => {},
                else => |status| {
                    const ignored = windows.unexpectedStatus(status);
                    std.debug.panic("NtReleaseKeyedEvent", .{});
                },
            }
        }

        pub fn reset(self: *Self) void {
            self.state = .empty;
        }

        pub fn yield(iteration: ?usize) bool {
            const iter = iteration orelse {
                _ = windows.ntdll.NtYieldExecution();
                return false;
            };

            if (iter < 1000) {
                atomic.spinLoopHint();
                return true;
            }

            return false;
        }
    };
};

const PosixBackend = struct {
    const c = std.c;

    pub const Lock = EventLock(.{
        .Event = Event,
        .byte_swap = true,
    });

    pub const Event = extern struct {
        tls: ?*PosixEvent,
        local: PosixEvent,

        pub fn init(self: *Event) void {
            if (PosixEvent.get()) |event| {
                self.tls = event;
            } else {
                self.local = .{};
            }
        }

        pub fn deinit(self: *Event) void {
            if (self.tls == null) {
                self.local.deinit();
            }

            self.* = undefined;
        }

        pub fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void {
            return (self.tls orelse &self.local).wait(deadline);
        }

        pub fn set(self: *Event) void {
            return (self.tls orelse &self.local).set();
        }

        pub fn reset(self: *Event) void {
            return (self.tls orelse &self.local).reset();
        }

        pub fn yield(iteration: ?usize) bool {
            const iter = iteration orelse {
                std.os.sched_yield() catch atomic.spinLoopHint();
                return false;
            };

            if (iter <= 3) {
                var spin = @as(usize, 1) << @intCast(std.math.Log2Int(usize), iter);
                while (spin > 0) : (spin -= 1) {
                    atomic.spinLoopHint();
                }
                return true;
            }

            if (iter < 10) {
                std.os.sched_yield() catch atomic.spinLoopHint();
                return true;
            }

            return false;
        }
    };

    const PosixEvent = extern struct {
        state: extern enum{ empty, waiting, notified } = .empty,
        cond: c.pthread_cond_t = c.PTHREAD_COND_INITIALIZER,
        mutex: c.pthread_mutex_t = c.PTHREAD_MUTEX_INITIALIZER,

        fn deinit(self: *PosixEvent) void {
            // On some BSD's like DragonFly, a statically initialized mutex can return EINVAL on deinit.
            const cond_rc = c.pthread_cond_destroy(&self.cond);
            assert(cond_rc == 0 or cond_rc == std.os.EINVAL);

            const mutex_rc = c.pthread_mutex_destroy(&self.mutex);
            assert(mutex_rc == 0 or mutex_rc == std.os.EINVAL);

            self.* = undefined;
        }

        fn get() ?*PosixEvent {
            const Static = struct {
                var key_state: usize = STATE_UNINIT;
                var maybe_key: ?c.pthread_key_t = undefined;

                const STATE_UNINIT = 0;
                const STATE_CREATING = 1;
                const STATE_INIT = 2;
                
                const Waiter = struct {
                    next: ?*Waiter align(std.math.max(@alignOf(usize), 4)) = null,
                    event: PosixEvent = .{},
                };

                fn getKey() ?c.pthread_key_t {
                    return switch (atomic.load(&key_state, .Acquire)) {
                        1 => maybe_key,
                        else => getKeySlow(),
                    };
                }

                fn getKeySlow() ?c.pthread_key_t {
                    @setCold(true);

                    var waiter: Waiter = undefined;
                    var has_event = false;
                    defer if (has_event) {
                        waiter.event.deinit();
                    };

                    var state = atomic.load(&key_state, .Acquire);
                    while (true) {
                        if (state == STATE_INIT) {
                            break;
                        }

                        var new_state: usize = undefined;
                        if (state == STATE_UNINIT) {
                            new_state = STATE_CREATING;
                        } else {
                            new_state = @ptrToInt(&waiter);
                            waiter.next = @intToPtr(?*Waiter, state & ~@as(usize, 0b11));
                            if (!has_event) {
                                has_event = true;
                                waiter.event = .{};
                            }
                        }

                        state = atomic.tryCompareAndSwap(
                            &key_state,
                            state,
                            new_state,
                            .Release,
                            .Acquire,
                        ) orelse break;
                    }

                    switch (state) {
                        STATE_UNINIT => {
                            var key: c.pthread_key_t = undefined;
                            if (c.pthread_key_create(&key, deinitKey) != 0) {
                                maybe_key = key;
                            } else {
                                maybe_key = null;
                            }

                            state = atomic.swap(&key_state, STATE_INIT, .AcqRel);
                            defer state = STATE_INIT;

                            var waiters = @intToPtr(?*Waiter, state & ~@as(usize, 0b11));
                            while (waiters) |idle_waiter| {
                                waiters = idle_waiter.next;
                                idle_waiter.event.set();
                            }
                        },
                        STATE_CREATING => {
                            waiter.event.wait(null) catch unreachable;
                            state = atomic.load(&key_state, .Acquire);
                        },
                        STATE_INIT => {},
                        else => unreachable,
                    }

                    assert(state == STATE_INIT);
                    return maybe_key;
                }

                fn deinitKey(ptr: *c_void) callconv(.C) void {
                    const event = @ptrCast(*PosixEvent, @alignCast(@alignOf(PosixEvent), ptr));
                    event.deinit();
                    c.free(ptr);
                }
            };

            const key = Static.getKey() orelse return null;
            if (c.pthread_getspecific(key)) |ptr| {
                return @ptrCast(*PosixEvent, @alignCast(@alignOf(PosixEvent), ptr));
            }

            const ptr = c.malloc(@sizeOf(PosixEvent)) orelse return null;
            if (c.pthread_setspecific(key, ptr) != 0) {
                c.free(ptr);
                return null;
            }

            const event = @ptrCast(*PosixEvent, @alignCast(@alignOf(PosixEvent), ptr));
            event.* = .{};
            return event;
        }

        fn wait(self: *PosixEvent, deadline: ?u64) error{TimedOut}!void {
            assert(c.pthread_mutex_lock(&self.mutex) == 0);
            defer assert(c.pthread_mutex_unlock(&self.mutex) == 0);

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
                    const deadline_ns = deadline orelse break :blk false;
                    const now = std.time.now();
                    if (now > deadline_ns) {
                        self.state = .empty;
                        return error.TimedOut;
                    }

                    const Sec = @TypeOf(ts.tv_sec);
                    const Nano = @TypeOf(ts.tv_nsec);
                    const timeout = deadline_ns - now;
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

        fn set(self: *PosixEvent) void {
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

        fn reset(self: *PosixEvent) void {
            self.state = .empty;
        }
    };
};