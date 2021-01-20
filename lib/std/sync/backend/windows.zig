// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const windows = std.os.windows;
const atomic = @import("../atomic.zig");
const Spin = @import("./spin.zig");
const EventLock = @import("../Lock.zig").Lock;

pub const Lock = extern struct {
    lock: Backend.OsLock = .{},

    pub fn tryAcquire(self: *Lock) bool {
        return self.lock.tryAcquire();
    }

    pub fn acquire(self: *Lock) void {
        self.lock.acquire();
    }

    pub fn release(self: *Lock) void {
        self.lock.release();
    }
};

pub const Event = extern struct {
    event: Backend.OsEvent,

    pub fn init(self: *Event) void {
        self.* = .{ .event = .{} };
    } 

    pub fn deinit(self: *Event) void {
        self.* = undefined;
    }

    pub fn wait(self: *Event, deadline: ?u64) error{TimedOut}!void {
        return self.event.wait(deadline);
    }

    pub fn set(self: *Event) void {
        self.event.set();
    }

    pub fn reset(self: *Event) void {
        self.event = .{};
    }

    pub fn yield(iteration: ?usize) bool {
        const iter = iteration orelse {
            Backend.OsEvent.yield();
            return true;
        };

        if (iter < 4000) {
            atomic.spinLoopHint();
            return true;
        }

        return false;
    }
};

const Backend = if (Kernel32.is_supported)
    Kernel32
else if (NtKeyedEvent.is_supported)
    NtKeyedEvent
else
    Spin;

fn isWindowsVersionSupported(comptime version: std.Target.Os.WindowsVersion) bool {
    return std.Target.current.os.version_range.windows.isAtLeast(version) orelse false;
}

const Kernel32 = struct {
    const is_supported = isWindowsVersionSupported(.vista);

    const OsLock = extern struct {
        srwlock: windows.SRWLOCK = windows.SRWLOCK_INIT,

        fn tryAcquire(self: *OsLock) bool {
            return windows.kernel32.TryAcquireSRWLockExclusive(&self.srwlock) != windows.FALSE;
        }

        fn acquire(self: *OsLock) void {
            windows.kernel32.AcquireSRWLockExclusive(&self.srwlock);
        }

        fn release(self: *OsLock) void {
            windows.kernel32.ReleaseSRWLockExclusive(&self.srwlock);
        }
    };

    const OsEvent = extern struct {
        is_set: bool = false,
        lock: windows.SRWLOCK = windows.SRWLOCK_INIT,
        cond: windows.CONDITION_VARIABLE = windows.CONDITION_VARIABLE_INIT,

        fn yield() void {
            _ = windows.kernel32.SwitchToThread();
        }

        fn wait(self: *OsEvent, deadline: ?u64) error{TimedOut}!void {
            windows.kernel32.AcquireSRWLockExclusive(&self.lock);
            defer windows.kernel32.ReleaseSRWLockExclusive(&self.lock);

            while (true) {
                if (self.is_set)
                    return;

                var timeout: windows.DWORD = windows.INFINITE;
                if (deadline) |deadline_ns| {
                    const now = std.time.now();
                    if (now > deadline_ns)
                        return error.TimedOut;

                    const timeout_ms = @divFloor(deadline_ns - now, std.time.ns_per_ms);
                    if (timeout_ms < @as(u64, timeout))
                        timeout = @intCast(windows.DWORD, timeout_ms);
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

        fn set(self: *OsEvent) void {
            windows.kernel32.AcquireSRWLockExclusive(&self.lock);
            defer windows.kernel32.ReleaseSRWLockExclusive(&self.lock);

            self.is_set = true;
            windows.kernel32.WakeConditionVariable(&self.cond);
        }
    };
};

const NtKeyedEvent = struct {
    const is_supported = isWindowsVersionSupported(.xp);

    const OsLock = EventLock(.{
        .Event = Event,
        .byte_swap = true,
    });

    const OsEvent = extern struct {
        state: State = .empty,

        const State = enum(u32) {
            empty,
            waiting,
            notified,
        };

        fn yield() void {
            _ = windows.ntdll.NtYieldExecution();
        }

        fn wait(self: *OsEvent, deadline: ?u64) error{TimedOut}!void {
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
                const now = shared.nanotime();
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

        fn set(self: *OsEvent) void {
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
    };
};
