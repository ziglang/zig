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

pub fn Mutex(comptime Futex: anytype) type {
    return extern struct {
        state: State = .unlocked,

        const Self = @This();
        const State = enum(u32) {
            unlocked,
            locked,
            contended,
        };

        pub const Dummy = DebugMutex;

        pub fn deinit(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
            }

            self.* = undefined;
        }

        pub fn tryAcquire(self: *Self) ?Held {
            if (atomic.tryCompareAndSwap(
                &self.state,
                .unlocked,
                .locked,
                .Acquire,
                .Relaxed,
            )) |failed| {
                return null;
            }

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }

            return Held{ .mutex = self };
        }

        pub inline fn tryAcquireFor(self: *Self, duration: u64) error{TimedOut}!Held {
            return self.acquireInner(Futex.now() + duration);
        }

        pub inline fn tryAcquireUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
            return self.acquireInner(deadline);
        }

        pub inline fn acquire(self: *Self) Held {
            return self.acquireInner(null) catch unreachable;
        }

        inline fn acquireInner(self: *Self, deadline: ?u64) error{TimedOut}!Held {
            const state = atomic.swap(&self.state, .locked, .Acquire);
            if (state != .unlocked) {
                try self.acquireSlow(state, deadline);
            }

            if (helgrind) |hg| {
                hg.annotateHappensAfter(@ptrToInt(self));
            }

            return Held{ .mutex = self };
        }

        fn acquireSlow(self: *Self, current_state: State, deadline: ?u64) error{TimedOut}!void {
            @setCold(true);

            var new_state = current_state;
            while (true) {

                var spin_iter: std.math.Log2Int(usize) = 0;
                while (spin_iter < 10) : (spin_iter += 1) {
                    switch (atomic.load(&self.state, .Relaxed)) {
                        .unlocked => _ = atomic.tryCompareAndSwap(
                            &self.state,
                            .unlocked,
                            new_state,
                            .Acquire,
                            .Relaxed,
                        ) orelse return,
                        .locked => {},
                        .contended => break,
                    }

                    var spin = std.math.max(100, @as(usize, 1) << spin_iter);
                    while (spin > 0) : (spin -= 1) {
                        atomic.spinLoopHint();
                    }
                }

                new_state = .contended;
                if (atomic.swap(&self.state, .contended, .Acquire) == .unlocked) {
                    return;
                }

                try Futex.wait(
                    @ptrCast(*const u32, &self.state),
                    @enumToInt(State.contended),
                    deadline,
                );
            }
        }

        pub const Held = extern struct {
            mutex: *Self,

            pub fn release(self: Held) void {
                self.mutex.release();
            }
        };

        fn release(self: *Self) void {
            if (helgrind) |hg| {
                hg.annotateHappensBefore(@ptrToInt(self));
            }

            switch (atomic.swap(&self.state, .unlocked, .Release)) {
                .unlocked => unreachable,
                .locked => {},
                .contended => self.releaseSlow(),
            }
        }

        fn releaseSlow(self: *Self) void {
            @setCold(true);

            Futex.wake(
                @ptrCast(*const u32, &self.state),
                @as(u32, 1),
            );
        }
    };
}

/// This has the sematics as `Mutex`, however it does not actually do any
/// synchronization. Operations are safety-checked no-ops.
pub const DebugMutex = extern struct {
    is_locked: @TypeOf(init) = init,

    const Self = @This();
    const init = if (std.debug.runtime_safety) false else {};

    pub fn deinit(self: *Self) void {
        self.* = undefined;
    }

    pub fn tryAcquire(self: *Self) ?Held {
        if (std.debug.runtime_safety) {
            if (self.is_locked) return null;
            self.is_locked = true;
        }

        return Held{ .mutex = self };
    }

    pub fn tryAcquireFor(self: *Self, duration: u64) error{TimedOut}!Held {
        return self.tryAcquire() orelse {
            std.time.sleep(duration);
            return error.TimedOut;
        };
    }

    pub fn tryAcquireUntil(self: *Self, deadline: u64) error{TimedOut}!Held {
        return self.tryAcquire() orelse {
            const now = std.time.now();
            if (now < deadline) {
                std.time.sleep(deadline - now);
            }
            return error.TimedOut;
        };
    }

    pub fn acquire(self: *Self) Held {
        return self.tryAcquire() orelse @panic("deadlock detected");
    }

    pub const Held = extern struct {
        mutex: *Self,

        pub fn release(self: Held) void {
            if (std.debug.runtime_safety) {
                assert(self.mutex.is_locked);
                self.mutex.is_locked = false;
            }
        }
    };
};

test "Mutex - Debug" {
    // TODO: loop.zig:766
    if (builtin.single_threaded and std.io.is_async) return error.SkipZigTest;
    try testMutex(DebugMutex, null);
}

test "Mutex - Evented" {
    if (!std.io.is_async or std.builtin.single_threaded) return error.SkipZigTest;
    try testMutex(
        Mutex(std.sync.futex.event),
        @import("../futex/event.zig").TestThread,
    );
}

test "Mutex - Spin" {
    try testMutex(Mutex(std.sync.futex.spin), std.Thread);
}

test "Mutex - Os" {
    try testMutex(Mutex(std.sync.futex.os), std.Thread);
}

fn testMutex(
    comptime TestMutex: type,
    comptime TestThread: ?type,
) !void {
    {
        var mutex = TestMutex{};
        defer mutex.deinit();

        var held = mutex.tryAcquire() orelse unreachable;
        testing.expectEqual(mutex.tryAcquire(), null);
        held.release();

        held = mutex.acquire();
        defer held.release();

        const delay = 1 * std.time.ns_per_ms;
        testing.expectError(error.TimedOut, mutex.tryAcquireFor(delay));
        testing.expectError(error.TimedOut, mutex.tryAcquireUntil(std.time.now() + delay));
    }

    const Thread = TestThread orelse return;

    const Contention = struct {
        index: usize = 0,
        case: Case = undefined,
        start_event: Thread.ResetEvent = .{},
        counters: [num_counters]Counter = undefined,

        const Self = @This();
        const num_counters = 10;

        const Counter = struct {
            mutex: TestMutex = .{},
            remaining: u128,

            fn tryDecr(self: *Counter) bool {
                const held = self.mutex.acquire();
                defer held.release();

                if (self.remaining == 0) {
                    return false;
                }

                self.remaining -= 1;
                return true;
            }
        };

        const Case = union(enum) {
            random: Random,
            high: High,
            forced: Forced,
            low: Low,

            /// The common case of many threads generally not touching other thread's Mutexes
            const Low = struct {
                fn setup(_: @This(), self: *Self) void {
                    self.index = 0;
                    self.counters = [_]Counter{Counter{ .remaining = 10_000 }} ** num_counters;
                }

                fn run(_: @This(), self: *Self) void {
                    const local_index = atomic.fetchAdd(&self.index, 1, .SeqCst);
                    const local_counter = &self.counters[local_index];
                    const check_remote_every = 100;

                    var iter: usize = 0;
                    var seed: usize = undefined;
                    var prng = std.rand.DefaultPrng.init(@ptrToInt(&seed));

                    while (local_counter.tryDecr()) : (iter += 1) {
                        if (iter % check_remote_every == 0) {
                            const remote_index = prng.random.uintLessThan(usize, self.counters.len);
                            const remote_counter = &self.counters[remote_index];
                            _ = remote_counter.tryDecr();
                        }
                    }
                }
            };

            /// The extreme case of many threads fighting over the same Mutex.
            const High = struct {
                fn setup(_: @This(), self: *Self) void {
                    self.counters[0] = Counter{
                        .remaining = 100_000,
                    };
                }

                fn run(_: @This(), self: *Self) void {
                    while (self.counters[0].tryDecr()) {
                        atomic.spinLoopHint();
                    }
                }
            };

            /// The slightly-less extreme case of many threads fighting over the same Mutex.
            /// But they all eventually do an equal amount of work.
            const Forced = struct {
                const local_iters = 50_000;

                fn setup(_: @This(), self: *Self) void {
                    self.counters[0] = Counter{
                        .remaining = local_iters * num_counters,
                    };
                }

                fn run(_: @This(), self: *Self) void {
                    var iters: usize = local_iters;
                    while (iters > 0) : (iters -= 1) {
                        _ = self.counters[0].tryDecr();
                    }
                }
            };

            /// Stresses the common use-case of random Mutex contention.
            const Random = struct {
                fn setup(_: @This(), self: *Self) void {
                    self.counters = [_]Counter{Counter{ .remaining = 10_000 }} ** num_counters;
                }

                /// Each thread iterates the counters array starting from a random position.
                /// On each iteration, it tries to lock & decrement the value of each counter is comes across.
                /// When it is unable to decrement on any counter, it terminates (seeing that they've all reached 0).
                fn run(_: @This(), self: *Self) void {
                    var seed: usize = undefined;
                    var prng = std.rand.DefaultPrng.init(@ptrToInt(&seed));

                    while (true) {
                        var did_decr = false;
                        var iter = self.counters.len;
                        var index = prng.random.int(usize) % iter;

                        while (iter > 0) : (iter -= 1) {
                            const counter = &self.counters[index];
                            index = (index + 1) % self.counters.len;
                            if (counter.tryDecr()) {
                                did_decr = true;
                            }
                        }

                        if (!did_decr) {
                            break;
                        }
                    }
                }
            };
        };

        fn run(self: *Self) void {
            self.start_event.wait();

            switch (self.case) {
                .random => |case| case.run(self),
                .high => |case| case.run(self),
                .forced => |case| case.run(self),
                .low => |case| case.run(self),
            }
        }

        fn execute(self: *Self) !void {
            const allocator = testing.allocator;
            const threads = try allocator.alloc(*Thread, num_counters);
            defer allocator.free(threads);

            defer {
                self.start_event.deinit();
                for (self.counters) |*counter| {
                    counter.mutex.deinit();
                }
            }

            for ([_]Case{ .high, .random, .forced }) |contention_case| {
                self.case = contention_case;
                switch (self.case) {
                    .random => |case| case.setup(self),
                    .high => |case| case.setup(self),
                    .forced => |case| case.setup(self),
                    .low => |case| case.setup(self),
                }

                self.start_event.reset();
                for (threads) |*t| {
                    t.* = try Thread.spawn(self, Self.run);
                }

                self.start_event.set();
                for (threads) |t| {
                    t.wait();
                }

                for (self.counters) |counter| {
                    testing.expectEqual(counter.remaining, 0);
                }
            }
        }
    };

    var contention = Contention{};
    try contention.execute();
}
