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

        pub const Dummy = DebugSemaphore;

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

                if (permits > 0) {
                    self.notify();
                }

                return true;
            }
        }

        pub inline fn wait(self: *Self) void {
            return self.waitInner(null) catch unreachable;
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
            assert(permits != std.math.maxInt(usize));

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

    pub fn wait(self: *Self) void {
        if (!self.tryWait()) {
            @panic("deadlock detected");
        }
    }

    pub fn tryWaitFor(self: *Self, duration: u64) error{TimedOut}!void {
        if (!self.tryWait()) {
            std.time.sleep(duration);
            return error.TimedOut;
        }
    }

    pub fn tryWaitUntil(self: *Self, deadline: u64) error{TimedOut}!void {
        if (!self.tryWait()) {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        }
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

test "Semaphore - Debug" {
    try testSemaphore(DebugSemaphore, null);
}

test "Semaphore - Spin" {
    try testSemaphore(Semaphore(std.sync.futex.spin), std.Thread);
}

test "Semaphore - Os" {
    try testSemaphore(Semaphore(std.sync.futex.os), std.Thread);
}

test "Semaphore - Evented" {
    if (!std.io.is_async or std.builtin.single_threaded) return error.SkipZigTest;
    try testSemaphore(
        Semaphore(std.sync.futex.event),
        @import("../futex/event.zig").TestThread,
    );
}

fn testSemaphore(
    comptime TestSemaphore: anytype,
    comptime TestThread: ?type,
) !void {
    {
        var sem = TestSemaphore{};
        defer sem.deinit();

        var permits: usize = 10;
        while (permits > 0) : (permits -= 1) {
            var posts: usize = permits;
            while (posts > 0) : (posts -= 1) {
                sem.post();
            }

            var waits: usize = permits;
            while (waits > 0) : (waits -= 1) {
                sem.wait();
            }
        }

        sem.post();
        testing.expect(sem.tryWait());
        testing.expect(!sem.tryWait());
        testing.expect(!sem.tryWait());

        sem.post();
        try sem.tryWaitFor(1);
        testing.expectError(error.TimedOut, sem.tryWaitFor(1));

        sem.post();
        try sem.tryWaitUntil(std.time.now() + 1);
        testing.expectError(error.TimedOut, sem.tryWaitUntil(std.time.now() + 1));
    }

    const Thread = TestThread orelse return;

    const Cycle = struct {
        input: TestSemaphore = .{},
        output: TestSemaphore = .{},
        
        const Self = @This();
        const cycles = 100;

        fn runProducer(self: *Self) void {
            var iters: usize = cycles;
            while (iters > 0) : (iters -= 1) {
                self.input.wait();
                self.output.post();
            }
        }

        fn runConsumer(self: *Self) void {
            var iters: usize = cycles;
            while (iters > 0) : (iters -= 1) {
                self.output.wait();
                self.input.post();
            }
        }

        fn run(self: *Self) !void {
            const allocator = testing.allocator;
            const threads = try allocator.alloc(*Thread, 10);
            defer allocator.free(threads);
            
            var producers = threads.len / 2;
            for (threads) |*t| {
                if (producers > 0) {
                    producers -= 1;
                    t.* = try Thread.spawn(self, runProducer);
                } else {
                    t.* = try Thread.spawn(self, runConsumer);
                }
            }

            self.input.post();
            for (threads) |t| t.wait();
        }
    };

    var cycle = Cycle{};
    try cycle.run();
}
