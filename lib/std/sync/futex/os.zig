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
else if (builtin.link_libc)
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
                0 => return,
                std.os.EINTR => continue,
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

const DarwinFutex = @compileError("TODO: __ulock_wait -> fallback to PosixFutex");

const WindowsFutex = @compileError("TODO: WaitOnAddress -> fallback to Generic(NtKeyedEvent)");

const PosixFutex = @compileError("TODO: Generic(pthread_mutex + pthread_cond)");

