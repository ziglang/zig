// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

const testing = std.testing;
const builtin = std.builtin;
const assert = std.debug.assert;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub fn Condvar(comptime Futex: anytype) type {
    return extern struct {
        wakeups: u32 = 0,

        const Self = @This();
        const Held = @import("./Mutex.zig").Mutex(Futex).Held;

        pub const Dummy = DebugCondvar;

        pub fn deinit(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn wait(self: *Self, held: Held) void {
            return self.waitInner(held, null) catch unreachable;
        }

        pub fn tryWaitFor(self: *Self, held: Held, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(held, Futex.now() + duration);
        }

        pub fn tryWaitUntil(self: *Self, held: Held, deadline: u64) error{TimedOut}!void {
            return self.waitInner(held, deadline);
        }

        fn waitInner(self: *Self, held: Held, deadline: ?u64) error{TimedOut}!void {
            const wakeups = atomic.load(&self.wakeups, .SeqCst);

            held.release();
            defer _ = held.mutex.acquire();

            try Futex.wait(
                &self.wakeups,
                wakeups,
                deadline,
            );

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }
        }

        pub fn notifyOne(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            _ = atomic.fetchAdd(&self.wakeups, 1, .SeqCst);

            Futex.wake(&self.wakeups, 1);
        }

        pub fn notifyAll(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            _ = atomic.fetchAdd(&self.wakeups, 1, .SeqCst);

            Futex.wake(&self.wakeups, std.math.maxInt(u32));
        }
    };
}

pub const DebugCondvar = struct {

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn wait(self: *Self, held: Held) void {
        @panic("deadlock detected");
    }

    pub fn tryWaitFor(self: *Self, held: Held, duration: u64) error{TimedOut}!void {
        std.time.sleep(duration);
        return error.TimedOut;
    }

    pub fn tryWaitUntil(self: *Self, held: Held, deadline: u64) error{TimedOut}!void {
        const now = std.time.now();
        if (now < deadline) {
            std.time.sleep(deadline - now);
        }
        return error.TimedOut;
    }

    pub fn notifyOne(self: *Self) void {
        // no-op: no threads to wake
    }

    pub fn notifyAll(self: *Self) void {
        // no-op: no threads to wake
    }
};