// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const linux = std.os.linux;
const futex = @import("./futex.zig");
const atomic = @import("../atomic.zig");

pub usingnamespace futex.Backend(struct {
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
        if (iter > max_iter)
            return false;

        while (iter > 0) : (iter -= 1)
            atomic.spinLoopHint();

        return true;
    }
});