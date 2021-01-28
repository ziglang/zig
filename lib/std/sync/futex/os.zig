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
                else => |errno| {
                    const err = std.os.unexpectedErrno(errno);
                    unreachable;
                },
            }
        }
    }

    pub fn wake(ptr: *const u32, num_waiters: u32) void {
        switch (linux.getErrno(linux.futex_wake(
            @ptrCast(*const i32, ptr),
            linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAKE,
            std.math.cast(i32, num_waiters) catch std.math.maxInt(i32),
        ))) {
            0 => {},
            std.os.EACCES => {},
            std.os.EFAULT => {},
            std.os.EINVAL => {},
            else => |errno| {
                const err = std.os.unexpectedErrno(errno);
                unreachable;
            },
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
                        else => |errno| {
                            const err = std.os.unexpectedErrno(@intCast(usize, errno));
                            unreachable;
                        },
                    }
                }
            }
        }

        pub fn wake(ptr: *const u32, num_waiters: u32) void {
            var flags: u32 = darwin.UL_COMPARE_AND_WAIT | darwin.ULF_NO_ERRNO;
            if (num_waiters > 1) {
                flags |= darwin.ULF_WAKE_ALL;
            }

            while (true) {
                const ret = darwin.__ulock_wake(
                    flags,
                    @ptrCast(*const c_void, ptr),
                    @as(u64, 0),
                );

                if (ret < 0) {
                    switch (-ret) {
                        darwin.ENOENT => {},
                        darwin.EINTR => continue,
                        else => |errno| {
                            const err = std.os.unexpectedErrno(@intCast(usize, errno));
                            unreachable;
                        },
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

const WindowsFutex = struct {
    pub fn now() u64 {
        return std.time.now();
    }

    pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
        return switch (Backend.get()) {
            .wait_on_address => WaitOnAddress.wait(ptr, expect, deadline),
            .keyed_event => KeyedEvent.wait(ptr, expect, deadline),
        };
    }

    pub fn wake(ptr: *const u32, num_waiters: u32) void {
        return switch (Backend.get()) {
            .wait_on_address => WaitOnAddress.wake(ptr, num_waiters),
            .keyed_event => KeyedEvent.wake(ptr, num_waiters),
        };
    }

    const windows = std.os.windows;
    const Backend = enum {
        wait_on_address,
        keyed_event,

        var default: Backend = undefined;
        var default_state: enum(u8) {
            uninit,
            searching,
            init,
        } = .uninit;

        fn get() Backend {
            return switch (atomic.load(&default_state, .Acquire)) {
                .init => default,
                else => getSlow(),
            };
        }

        fn getSlow() Backend {
            @setCold(true);

            var state = atomic.load(&default_state, .Acquire);
            while (true) {
                switch (state) {
                    .uninit => {
                        state = atomic.tryCompareAndSwap(
                            &default_state,
                            .uninit,
                            .searching,
                            .Acquire,
                            .Acquire,
                        ) orelse blk: {
                            default = Backend.find();
                            atomic.store(&default_state, .init, .Release);
                            break :blk .init;
                        };
                    },
                    .searching => {
                        windows.kernel32.Sleep(0);
                        state = atomic.load(&default_state, .Acquire);
                    },
                    .init => {
                        return default;
                    },
                }
            }
        }

        fn find() Backend {
            if (WaitOnAddress.initialize()) {
                return .wait_on_address;
            } else if (KeyedEvent.initialize()) {
                return .keyed_event;
            } else {
                unreachable;
            }
        }
    };
    
    const WaitOnAddress = struct {
        var wake_by_address_single_ptr: WakeOnAddressFn = undefined;
        var wake_by_address_all_ptr: WakeOnAddressFn = undefined;
        var wait_on_address_ptr: WaitOnAddressFn = undefined;

        const WakeOnAddressFn = fn (
            address: ?*const c_void,
        ) callconv(windows.WINAPI) void;
        const WaitOnAddressFn = fn (
            address: ?*const volatile c_void,
            compare_address: ?*const c_void,
            address_size: windows.SIZE_T,
            timeout_ms: windows.DWORD,
        ) callconv(windows.WINAPI) windows.BOOL;

        fn initialize() bool {
            // MSDN says that the functions are in kernel32.dll, but apparently they aren't...
            const synch_dll = windows.kernel32.GetModuleHandleW(blk: {
                const dll = "api-ms-win-core-synch-l1-2-0.dll";
                comptime var wdll = [_]windows.WCHAR{0} ** (dll.len + 1);
                inline for (dll) |char, index| {
                    wdll[index] = @as(windows.WCHAR, char);
                }
                break :blk @ptrCast([*:0]const windows.WCHAR, &wdll);
            }) orelse return false;

            const wait_ptr = windows.kernel32.GetProcAddress(
                synch_dll,
                "WaitOnAddress\x00",
            ) orelse return false;
            wait_on_address_ptr = @ptrCast(WaitOnAddressFn, wait_ptr);

            const wake_ptr = windows.kernel32.GetProcAddress(
                synch_dll,
                "WakeByAddressAll\x00",
            ) orelse return false;
            wake_by_address_all_ptr = @ptrCast(WakeOnAddressFn, wake_ptr);

            const wake_one_ptr = windows.kernel32.GetProcAddress(
                synch_dll,
                "WakeByAddressSingle\x00",
            ) orelse return false;
            wake_by_address_single_ptr = @ptrCast(WakeOnAddressFn, wake_one_ptr);

            return true;
        }

        fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
            while (true) {
                if (atomic.load(ptr, .SeqCst) != expect) {
                    return;
                }

                var timeout_ms: windows.DWORD = windows.INFINITE;
                if (deadline) |deadline_ns| {
                    const now_ns = now();
                    if (now_ns > deadline_ns) {
                        return error.TimedOut;
                    } else {
                        const timeout = @divFloor(deadline_ns - now_ns, std.time.ns_per_ms);
                        timeout_ms = std.math.cast(windows.DWORD, timeout) catch timeout_ms;
                    }
                }

                const status = (wait_on_address_ptr)(
                    @ptrCast(*const volatile c_void, ptr),
                    @ptrCast(*const c_void, &expect),
                    @sizeOf(@TypeOf(expect)),
                    timeout_ms,
                );

                if (status == windows.FALSE) {
                    switch (windows.kernel32.GetLastError()) {
                        .TIMEOUT => {},
                        else => |errno| {
                            const result = windows.unexpectedError(errno);
                            unreachable;
                        },
                    }
                }
            }
        }

        fn wake(ptr: *const u32, num_waiters: u32) void {
            const address = @ptrCast(*const c_void, ptr);
            switch (num_waiters) {
                0 => {},
                1 => (wake_by_address_single_ptr)(address),
                else => (wake_by_address_all_ptr)(address),
            }
        }
    };

    const KeyedEvent = struct {
        var event_handle: ?windows.HANDLE = undefined;

        fn initialize() bool {
            var handle: windows.HANDLE = undefined;
            const status = windows.ntdll.NtCreateKeyedEvent(
                &handle,
                windows.GENERIC_READ | windows.GENERIC_WRITE,
                null,
                @as(windows.ULONG, 0),
            );

            event_handle = switch (status) {
                .SUCCESS => handle,
                else => null,
            };

            return true;
        }

        pub usingnamespace generic.Futex(struct {
            state: State,

            pub const bucket_count = 128;
            pub const Lock = if (SRWLock.is_supported) SRWLock else NtLock;

            const Self = @This();
            const State = enum(usize) {
                empty,
                waiting,
                notified,
            };

            pub fn now() u64 {
                return std.time.now();
            }

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
                )) |state| {
                    assert(state == .notified);
                    return;
                }

                var timed_out = false;
                var timeout: windows.LARGE_INTEGER = undefined;
                var timeout_ptr: ?*const windows.LARGE_INTEGER = null;

                if (deadline) |deadline_ns| {
                    const now_ns = now();
                    timed_out = now_ns > deadline_ns;

                    if (!timed_out) {
                        timeout_ptr = &timeout;
                        timeout = std.math.cast(
                            windows.LARGE_INTEGER,
                            @divFloor(deadline_ns - now_ns, 100),
                        ) catch std.math.maxInt(windows.LARGE_INTEGER);
                        timeout = -(timeout);
                    }
                }

                if (!timed_out) {
                    switch (windows.ntdll.NtWaitForKeyedEvent(
                        event_handle,
                        @ptrCast(*const c_void, &self.state),
                        windows.FALSE,
                        timeout_ptr,
                    )) {
                        .SUCCESS => {},
                        .TIMEOUT => timed_out = true,
                        else => |status| {
                            const err = windows.unexpectedStatus(status);
                            unreachable;
                        },
                    }
                }

                if (timed_out) {
                    if (atomic.compareAndSwap(
                        &self.state,
                        .waiting,
                        .empty,
                        .SeqCst,
                        .SeqCst,
                    )) |state| {
                        assert(state == .notified);
                        switch (windows.ntdll.NtWaitForKeyedEvent(
                            event_handle,
                            @ptrCast(*const c_void, &self.state),
                            windows.FALSE,
                            null,
                        )) {
                            .SUCCESS => timed_out = false,
                            else => |status| {
                                const err = windows.unexpectedStatus(status);
                                unreachable;
                            },
                        }
                    }
                }

                if (timed_out) {
                    return error.TimedOut;
                }
            }

            pub fn set(self: *Self) void {
                switch (atomic.swap(&self.state, .notified, .SeqCst)) {
                    .empty => return,
                    .waiting => {},
                    .notified => unreachable, // multiple sets() on the same Event
                }

                switch (windows.ntdll.NtReleaseKeyedEvent(
                    event_handle,
                    @ptrCast(*const c_void, &self.state),
                    windows.FALSE,
                    null,
                )) {
                    .SUCCESS => {},
                    else => |status| {
                        const err = windows.unexpectedStatus(status);
                        unreachable;
                    },
                }
            }

            pub fn reset(self: *Self) void {
                self.state = .empty;
            }
        });

        const SRWLock = struct {
            srwlock: windows.SRWLOCK = windows.SRWLOCK_INIT,

            const is_supported = std.Target.current.os.version_range.windows.isAtLeast(.vista) orelse false;

            pub fn acquire(self: *SRWLock) Held {
                windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
                return Held{ .srwlock = &self.srwlock };
            }

            pub const Held = struct {
                srwlock: *windows.SRWLOCK,

                pub fn release(self: Held) void {
                    windows.kernel32.ReleaseSRWLockExclusive(self.srwlock);
                }
            };
        };

        const NtLock = struct {
            state: u32 = UNLOCKED,

            const UNLOCKED = 0;
            const LOCKED = 1;
            const WAKING = 1 << 8;
            const WAITING = 1 << 9;

            inline fn tryAcquire(self: *NtLock) bool {
                return switch (builtin.arch) {
                    .i386, .x86_64 => atomic.bitSet(
                        &self.state,
                        @ctz(std.math.Log2Int(u32), LOCKED),
                        .Acquire,
                    ) == UNLOCKED,
                    else => atomic.swap(
                        @ptrCast(*u8, &self.state),
                        LOCKED,
                        .Acquire,
                    ) == 0,
                };
            }

            pub fn acquire(self: *NtLock) Held {
                if (!self.tryAcquire()) {
                    self.acquireSlow();
                }

                return Held{ .lock = self };
            }

            fn acquireSlow(self: *NtLock) void {
                @setCold(true);

                var adaptive_spin: usize = 0;
                var state = atomic.load(&self.state, .Relaxed);

                while (true) {
                    if (state & LOCKED == 0) {
                        if (self.tryAcquire()) {
                            return;
                        }

                        windows.kernel32.Sleep(0);
                        state = atomic.load(&self.state, .Relaxed);
                        continue;
                    }

                    if ((state < WAITING) and (adaptive_spin < 4000)) {
                        if (adaptive_spin < 3900) {
                            atomic.spinLoopHint();
                        } else {
                            _ = windows.kernel32.SwitchToThread();
                        }

                        adaptive_spin += 1;
                        state = atomic.load(&self.state, .Relaxed);
                        continue;
                    }

                    var new_state: u32 = undefined;
                    if (@addWithOverflow(u32, state, WAITING, &new_state)) {
                        std.debug.panic("Too many waiters on the same NtLock", .{});
                    }

                    if (atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        new_state,
                        .Relaxed,
                        .Relaxed,
                    )) |updated| {
                        state = updated;
                        continue;
                    }

                    switch (windows.ntdll.NtWaitForKeyedEvent(
                        event_handle,
                        @ptrCast(*const c_void, &self.state),
                        windows.FALSE,
                        null,
                    )) {
                        .SUCCESS => {},
                        else => |status| {
                            const err = windows.unexpectedStatus(status);
                            unreachable;
                        },
                    }

                    adaptive_spin = 0;
                    state = switch (builtin.arch) {
                        .i386, .x86_64 => atomic.fetchSub(&self.state, WAKING, .Relaxed),
                        else => atomic.fetchAnd(&self.state, ~@as(u32, WAKING), .Relaxed),
                    };

                    assert(state & WAKING != 0);
                    state &= ~@as(u32, WAKING);
                }
            }

            pub const Held = struct {
                lock: *NtLock,

                pub fn release(self: Held) void {
                    self.lock.release();
                }
            };

            fn release(self: *NtLock) void {
                atomic.store(
                    @ptrCast(*u8, &self.state),
                    UNLOCKED,
                    .Release,
                );

                const state = atomic.load(&self.state, .Relaxed);
                if ((state >= WAITING) and (state & (LOCKED | WAKING) == 0)) {
                    self.releaseSlow();
                }
            }

            fn releaseSlow(self: *NtLock) void {
                @setCold(true);

                var state = atomic.load(&self.state, .Relaxed);
                while (true) {
                    if ((state < WAITING) or (state & (LOCKED | WAKING) != 0)) {
                        return;
                    }

                    state = atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        (state - WAITING) | WAKING,
                        .Relaxed,
                        .Relaxed,
                    ) orelse break;
                }

                switch (windows.ntdll.NtReleaseKeyedEvent(
                    event_handle,
                    @ptrCast(*const c_void, &self.state),
                    windows.FALSE,
                    null,
                )) {
                    .SUCCESS => {},
                    else => |status| {
                        const err = windows.unexpectedStatus(status);
                        unreachable;
                    },
                }
            }
        };
    };
};
