const std = @import("../std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;

const builtin = @import("builtin");
const target = builtin.target;
const single_threaded = builtin.single_threaded;

const Atomic = std.atomic.Atomic;
const Futex = std.Thread.Futex;
const Mutex = std.Thread.Mutex;
const Condition = @This();

impl: Impl = .{},

pub fn wait(self: *Condition, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
    return self.impl.wait(held, timeout);
}

pub fn signal(self: *Condition) void {
    return self.impl.wake(false);
}

pub fn broadcast(self: *Condition) void {
    return self.impl.wake(true);
}

pub const Impl = if (single_threaded)
    SerialImpl
else if (target.os.tag == .windows)
    WindowsImpl
else if (target.cpu.arch.ptrBitWidth() >= 64)
    Futex64Impl
else
    Futex32Impl;

const SerialImpl = struct {
    fn wait(self: *Impl, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
        _ = self;
        _ = held;

        const timeout_ns = timeout orelse unreachable; // deadlock detected
        std.time.sleep(timeout_ns);
        return error.TimedOut;
    }

    fn wake(self: *Impl, notify_all: bool) void {
        _ = self;
        _ = notify_all;
    }
};

const WindowsImpl = struct {
    cond: os.windows.CONDITION_VARIABLE = os.windows.CONDITION_VARIABLE_INIT,

    fn wait(self: *Impl, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
        var timeout_ms: os.windows.DWORD = os.windows.INFINITE;
        var timeout_overflow = false;

        if (timeout) |timeout_ns| {
            timeout_ms = std.math.cast(os.windows.DWORD, timeout_ns / std.time.ns_per_ms) catch timeout_ms;
            timeout_overflow = timeout_ms == os.windows.INFINITE;
        }

        const rc = os.windows.kernel32.SleepConditionVariableSRW(
            &self.cond,
            &held.mutex.impl.srwlock,
            timeout_ms,
            0, // Mutex acquires the SRWLOCK exclusively
        );

        if (rc == os.windows.FALSE) {
            const err = os.windows.kernel32.GetLastError();
            assert(err == .TIMEOUT);

            if (!timeout_overflow) {
                return error.TimedOut;
            }
        }
    }

    fn wake(self: *Impl, notify_all: bool) void {
        switch (notify_all) {
            true => os.windows.kernel32.WakeAllConditionVariable(&self.cond),
            else => os.windows.kernel32.WakeConditionVariable(&self.cond),
        }
    }
};

/// Simplified implementation of pthread_cond_t ulock variant from darwin libpthread:
/// https://github.com/apple/darwin-libpthread/blob/main/src/pthread_cond.c
const Futex64Impl = struct {
    cond: extern union {
        qword: Atomic(u64),
        state: State,
    } = .{ .qword = Atomic(u64).init(0) },

    const State = extern struct {
        /// Sequence futex that a waiter waits on
        seq: Atomic(u32),
        /// The number of waiters on the Condition.
        /// Incremented and decremented by themselves.
        waiters: u16,
        /// Claims by `wake()` threads to notify each `waiters`.
        signals: u16,
    };

    fn wait(self: *Impl, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
        // Add a waiter atomically
        const one_waiter = 1 << @bitOffsetOf(State, "waiters");
        var cond = self.cond.qword.fetchAdd(one_waiter, .Monotonic);

        // Record the sequence to wait on
        var state = @bitCast(State, cond);
        const wait_seq = state.seq.loadUnchecked();
        assert(state.waiters != std.math.maxInt(u16));

        // After we wake up, remove our waiter and consume a signal atomically.
        defer {
            cond = self.cond.qword.load(.Monotonic);
            while (true) {
                state = @bitCast(State, cond);
                state.waiters -= 1;
                state.signals = std.math.sub(u16, state.signals, 1) catch 0;

                cond = self.cond.qword.tryCompareAndSwap(
                    cond,
                    @bitCast(u64, state),
                    .Acquire,
                    .Monotonic,
                ) orelse break;
            }
        }

        held.mutex.impl.release();
        defer held.mutex.impl.acquire();

        return Futex.wait(
            &self.cond.state.seq,
            wait_seq,
            timeout,
        );
    }

    fn wake(self: *Impl, notify_all: bool) void {
        var cond = self.cond.qword.load(.Monotonic);
        while (true) {
            // Bail if there's no one to wake up
            const old_state = @bitCast(State, cond);
            if (old_state.waiters == 0) {
                return;
            }

            // Bail if other wake() threads have already committed
            // to waking up the waiters on the Condition.
            assert(old_state.signals <= old_state.waiters);
            if (old_state.signals == old_state.waiters) {
                return;
            }

            // Claim to wake up either all waiters or one waiter.
            // A claim also bumps the sequence to actually wake on the Futex.
            var new_state = old_state;
            new_state.seq.value +%= 1;
            new_state.signals = switch (notify_all) {
                true => old_state.waiters,
                else => old_state.signals + 1,
            };

            cond = self.cond.qword.tryCompareAndSwap(
                cond,
                @bitCast(u64, new_state),
                .Release,
                .Monotonic,
            ) orelse return Futex.wake(
                &self.cond.state.seq,
                new_state.signals - old_state.signals, // the number of waiters we claimed to wake up
            );
        }
    }
};

/// 32 bit implementation of Futex64Impl
const Futex32Impl = struct {
    seq: Atomic(u32) = Atomic(u32).init(0),
    sync: Atomic(u32) = Atomic(u32).init(0),

    const State = extern struct {
        waiters: u16 = 0,
        signals: u16 = 0,
    };

    fn wait(self: *Impl, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
        const one_waiter = @bitCast(u32, State{ .waiters = 1 });
        var sync = self.sync.fetchAdd(one_waiter, .Monotonic);

        var state = @bitCast(State, sync);
        assert(state.waiters != std.math.maxInt(u16));

        // After waiting, unregister the waiter and consume a signal if there is any.
        // Acquire barrier to ensure wake() happens before wait() w.r.t to signaling.
        defer {
            sync = self.sync.load(.Monotonic);
            while (true) {
                state = @bitCast(State, sync);
                assert(state.waiters > 0);

                state.waiters -= 1;
                state.signals = std.math.sub(u16, state.signals, 1) catch 0;
                sync = self.sync.tryCompareAndSwap(
                    sync,
                    @bitCast(u32, state),
                    .Acquire,
                    .Monotonic,
                ) orelse break;
            }
        }

        // Load the sequence and wait on it
        // "atomically with respect to access by another thread to the mutex and then the condition variable".
        // This means that it's ok if a wake() (sequence increment) is missed while the mutex is still held.
        const sequence = self.seq.load(.Monotonic);
        held.mutex.impl.release();
        defer held.mutex.impl.acquire();

        return Futex.wait(
            &self.seq,
            sequence,
            timeout,
        );
    }

    fn wake(self: *Impl, notify_all: bool) void {
        var sync = self.sync.load(.Monotonic);
        while (true) {
            // Bail if there's nothing to wake up
            var state = @bitCast(State, sync);
            if (state.waiters == 0) {
                return;
            }

            // Bail if there's wake() threads that have already
            // reserved the intention to wake up the current waiters.
            assert(state.signals <= state.waiters);
            if (state.signals == state.waiters) {
                return;
            }

            // Bump the signals count to reserve waking up the waiters.
            const old_signals = state.signals;
            state.signals = switch (notify_all) {
                true => state.waiters,
                else => state.signals + 1,
            };

            // Release meomry ordering to synchronize with the end of wait().
            sync = self.sync.tryCompareAndSwap(
                sync,
                @bitCast(u32, state),
                .Release,
                .Monotonic,
            ) orelse {
                const notified = state.signals - old_signals;
                _ = self.seq.fetchAdd(1, .Monotonic);
                return Futex.wake(&self.seq, notified);
            };
        }
    }
};

test "Condition - basic" {
    var mutex: Mutex = .{};
    var cond: Condition = .{};

    // Test that mutex is exclusive
    var held = mutex.acquire();
    try testing.expectEqual(mutex.tryAcquire(), null);

    // Test conditional wait + that the mutex is still locked after
    try testing.expectError(error.TimedOut, cond.wait(held, 1));
    try testing.expectEqual(mutex.tryAcquire(), null);

    // Same thing but for a larger timeout (we can't test null timeout given nothing to wake us up).
    try testing.expectError(error.TimedOut, cond.wait(held, 10 * std.time.ns_per_ms));
    try testing.expectEqual(mutex.tryAcquire(), null);

    // Test again that the mutex can still be acquired after releasing following a wait
    held.release();
    held = mutex.tryAcquire() orelse return error.MutexTryAcquire;
    held.release();
}

test "Condition - wait/signal" {
    if (single_threaded) return error.SkipZigTest;

    const Context = struct {
        lock: Mutex = .{},
        cond: Condition = .{},
        signaled: bool = false,

        fn doWait(self: *@This()) void {
            const held = self.lock.acquire();
            defer held.release();

            while (!self.signaled) {
                self.cond.wait(held, null) catch unreachable;
            }
        }

        fn doSignal(self: *@This(), do_broadcast: bool) void {
            const held = self.lock.acquire();
            defer held.release();

            self.signaled = true;
            switch (do_broadcast) {
                true => self.cond.signal(),
                else => self.cond.broadcast(),
            }
        }
    };

    for ([_]bool{ false, true }) |do_broadcast| {
        var context = Context{};
        const wait_signal = try std.Thread.spawn(.{}, Context.doWait, .{&context});

        context.doSignal(do_broadcast);
        wait_signal.join();
    }
}

test "Condition - producer / consumer" {
    if (single_threaded) return error.SkipZigTest;

    const num_threads = 4;
    const Context = struct {
        lock: Mutex = .{},
        send: Condition = .{},
        recv: Condition = .{},
        value: usize = 0,

        fn doSend(self: *@This(), do_broadcast: bool) void {
            const held = self.lock.acquire();
            defer held.release();

            assert(self.value == 0);
            self.value = 1;
            switch (do_broadcast) {
                true => self.recv.broadcast(),
                else => self.recv.signal(),
            }

            while (self.value != 0) {
                self.send.wait(held, null) catch unreachable;
            }
        }

        fn doRecv(self: *@This(), do_broadcast: bool) void {
            const held = self.lock.acquire();
            defer held.release();

            while (self.value == 0) {
                self.recv.wait(held, null) catch unreachable;
            }

            self.value -= 1;
            switch (do_broadcast) {
                true => self.send.broadcast(),
                else => self.send.signal(),
            }
        }
    };

    for ([_]bool{ true, false }) |do_broadcast| {
        var context = Context{};
        var threads: [num_threads]std.Thread = undefined;
        for (threads) |*t| t.* = try std.Thread.spawn(.{}, Context.doRecv, .{ &context, do_broadcast });
        defer for (threads) |t| t.join();

        var i: usize = num_threads;
        while (i > 0) : (i -= 1) {
            context.doSend(do_broadcast);
        }
    }
}
