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

        pub const Mutex = @import("./Mutex.zig").Mutex(Futex);
        pub const Held = Mutex.Held;

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

pub const DebugCondvar = extern struct {

    const Self = @This();

    pub const Mutex = @import("./Mutex.zig").DebugMutex;
    pub const Held = Mutex.Held;

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

test "Condvar - Debug" {
    try testCondvar(DebugCondvar, null);
}

test "Condvar - Spin" {
    try testCondvar(Condvar(std.sync.futex.spin), std.Thread);
}

test "Condvar - Os" {
    try testCondvar(Condvar(std.sync.futex.os), std.Thread);
}

test "Condvar - Evented" {
    if (!std.io.is_async or std.builtin.single_threaded) return error.SkipZigTest;
    try testCondvar(
        Condvar(std.sync.futex.event),
        @import("../futex/event.zig").TestThread,
    );
}

fn testCondvar(
    comptime TestCondvar: type,
    comptime TestThread: ?type,
) !void {
    {
        var cond = TestCondvar{};
        defer cond.deinit();

        cond.notifyOne();
        cond.notifyAll();

        var mutex = TestCondvar.Mutex{};
        const held = mutex.acquire();
        defer held.release();

        const delay = 1 * std.time.ns_per_ms;
        testing.expectError(error.TimedOut, cond.tryWaitFor(held, delay));
        testing.expectError(error.TimedOut, cond.tryWaitUntil(held, std.time.now() + delay));
    }

    const Thread = TestThread orelse return;

    const ProduceConsumer = struct {
        input: Queue = .{},
        output: Queue = .{},
        exit: Queue = .{},
        
        const Self = @This();
        const Queue = struct {
            mutex: TestCondvar.Mutex = .{},
            cond: TestCondvar = .{},
            items: usize = 0,

            fn push(self: *Queue) void {
                const held = self.mutex.acquire();
                defer held.release();

                self.items += 1;
                self.cond.notifyOne();
            }

            fn pop(self: *Queue) void {
                const held = self.mutex.acquire();
                defer held.release();

                while (self.items == 0) {
                    self.cond.wait(held);
                }

                self.items -= 1;
            }
        };

        fn runThread(self: *Self) void {
            self.input.pop();
            self.output.push();
            self.exit.pop();
        }

        fn run(self: *Self) !void {
            const allocator = testing.allocator;
            const threads = try allocator.alloc(*Thread, 10);
            defer allocator.free(threads);

            for (threads) |*t| t.* = try Thread.spawn(self, runThread);
            for (threads) |_| {
                self.input.push();
                self.output.pop();
            }

            for (threads) |_| self.exit.push();
            for (threads) |t| t.wait();
        }
    };

    var pro_con = ProduceConsumer{};
    try pro_con.run();
}