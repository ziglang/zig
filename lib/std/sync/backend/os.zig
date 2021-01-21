// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const futex = @import("./futex.zig");
const SpinBackend = @import("./spin.zig");
const EventLock = @import("../Lock.zig").Lock;

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

    pub usingnamespace if (Kernel32Backend.is_supported)
        Kernel32Backend
    else if (NtKeyedEventBackend.is_supported)
        NtKeyedEventBackend
    else
        SpinBackend;

    fn isWindowsVersionSupported(comptime version: std.Target.Os.WindowsVersion) bool {
        return target.os.version_range.windows.isAtLeast(version) orelse false;
    }

    const Kernel32Backend = struct {
        const is_supported = isWindowsVersionSupported(.vista);

        pub const Lock = extern struct {
            srwlock: windows.SRWLOCK = windows.SRWLOCK_INIT,

            pub fn tryAcquire(self: *Lock) ?Held {
                if (windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != windows.FALSE) {
                    return Held{ .lock = self };
                }

                return null;
            }

            pub fn acquire(self: *Lock) Held {
                windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
                return Held{ .lock = self };
            }

            pub const Held = extern struct {
                lock: *Lock,

                pub fn release(self: Held) void {
                    windows.kernel32.ReleaseSRWLockExclusive(&self.lock.srwlock);
                }
            };
        };

        pub const Event = extern struct {
            is_set: bool,
            lock: windows.SRWLOCK,
            cond: windows.CONDITION_VARIABLE,

            pub fn init(self: *Event) void {
                self.* = .{
                    .is_set = false,
                    .lock = windows.SRWLOCK_INIT,
                    .cond = windows.CONDITION_VARIABLE_INIT,
                };
            }

            pub fn deinit(self: *Event) void {
                self.* = undefined;
            }

            pub fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void {
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
                        }

                        const timeout_ms = @divFloor(deadline_ns - now, std.time.ns_per_ms);
                        if (timeout_ms < @as(u64, timeout)) {
                            timeout = @intCast(windows.DWORD, timeout_ms);
                        }
                    }

                    const status = windows.kernel32.SleepConditionVariableSRW(
                        &self.cond,
                        &self.lock,
                        timeout,
                        0,
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

            pub fn reset(self: *Event) void {
                self.is_set = false;
            }

            pub fn yield(iteration: ?usize) bool {
                const iter = iteration orelse {
                    _ = windows.kernel32.SwitchToThread();
                    return false;
                };

                if (iter < 4000) {
                    atomic.spinLoopHint();
                    return true;
                }

                return false;
            }
        };
    };

    const NtKeyedEventBackend = struct {
        const is_supported = isWindowsVersionSupported(.xp);

        pub const Lock = EventLock(.{
            .Event = Event,
            .byte_swap = true,
        });

        pub const Event = extern struct {
            state: State = .empty,

            const State = enum(u32) {
                empty,
                waiting,
                notified,
            };

            pub fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void {
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

            pub fn set(self: *Event) void {
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

            pub fn reset(self: *Event) void {
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
};

const PosixBackend = struct {
    const c = std.c;

    pub const Lock = EventLock(.{
        .Event = Event,
        .byte_swap = true,
    });

    pub const Event = extern struct {
        pub fn init(self: *Event) void {
            @compileError("TODO");
        }

        pub fn deinit(self: *Event) void {
            @compileError("TODO");
        }

        pub fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void {
            @compileError("TODO");
        }

        pub fn set(self: *Event) void {
            @compileError("TODO");
        }

        pub fn reset(self: *Event) void {
            @compileError("TODO");
        }

        pub fn yield(iteration: ?usize) bool {
            @compileError("TODO");
        }
    };
};