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

pub fn Semaphore(comptime Futex: anytype) type {
    return extern struct {
        permits: usize = 0,
        state: State = .empty,

        const Self = @This();
        const State = enum(u32) {
            empty,
            waiting,
        };

        pub fn init(permits: usize) Self {
            return .{ .permits = permits };
        }

        pub fn deinit(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn tryWait(self: *Self) bool {
            var permits = atomic.load(&self.permits, .Relaxed);
            while (true) {
                if (permits == 0) {
                    return false;
                }

                if (atomic.tryCompareAndSwap(
                    &self.permits,
                    permits,
                    permits - 1,
                    .Acquire,
                    .Relaxed,
                )) |updated| {
                    permits = updated;
                    continue;
                }

                if (helgrind) |hg| {
                    hg.annotateHappensAfter(@ptrToInt(self));
                }

                return true;
            }
        }

        pub inline fn wait(self: *Self) void {
            return self.waitInner(held, null) catch unreachable;
        }

        pub inline fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
            return self.tryWaitUntil(Futex.now() + duration);
        }

        pub inline fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
            return self.waitInner(deadline);
        }

        fn waitInner(self: *Self, deadline: ?u64) error{TimedOut}!void {
            while (true) {
                if (self.tryWait()) {
                    return;
                }    

                var state = atomic.load(&self.state, .Relaxed);
                if (state != .waiting) {
                    if (atomic.tryCompareAndSwap(
                        &self.state,
                        state,
                        .waiting,
                        .Relaxed,
                        .Relaxed,
                    )) |failed| {
                        atomic.spinLoopHint();
                        continue;
                    }

                    if (self.tryWait()) {
                        return;
                    }
                }

                try Futex.wait(
                    @ptrCast(*const u32, &self.state),
                    @enumToInt(State.waiting),
                    deadline,
                );
            }
        }

        pub fn post(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            const permits = atomic.fetchAdd(&self.permits, 1, .Release);
            assert(permits != std.mem.maxInt(usize));

            if (permits == 0) {
                self.notify();
            }
        }

        fn notify(self: *Self) void {
            @setCold(true);

            const state = atomic.swap(&self.state, .empty, .Relaxed);
            if (state == .waiting) {
                Futex.wake(
                    @ptrCast(*const u32, &self.state),
                    std.math.maxInt(u32),
                );
            }
        }
    };
}

pub const DebugSemaphore = extern struct {
    permits: usize = 0,

    const Self = @This();

    pub fn init(permits: usize) Self {
        return .{ .permits = permits };
    }

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn tryWait(self: *Self) bool {
        if (self.permits == 0) {
            return false;
        }

        self.permits -= 1;
        return true;
    }

    pub inline fn wait(self: *Self) void {
        return self.tryWait() or @panic("deadlock detected");
    }

    pub inline fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
        return self.tryWait() or {
            std.time.sleep(duration);
            return error.TimedOut;
        };
    }

    pub inline fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
        return self.tryWait() or {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        };
    }

    pub fn post(self: *Self) void {
        var new_permits: usize = undefined;
        if (@addWithOverflow(usize, self.permits, 1, &new_permits)) {
            unreachable;
        } else {
            self.permits = new_permits;
        }
    }
};
