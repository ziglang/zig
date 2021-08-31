const std = @import("../std.zig");
const target = std.Target.current;
const assert = std.debug.assert;
const os = std.os;

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

pub const Impl = if (std.builtin.single_threaded)
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
    fn wait(self: *Impl, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
        @compileError("TODO: SleepConditionVariableSRW");
    }

    fn wake(self: *Impl, notify_all: bool) void {
        @compileError("TODO: Wake[All]ConditionVariable");
    }
};

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
            new_state.seq +%= 1;
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

const Futex32Impl = struct {
    seq: Atomic(u32) = Atomic(u32).init(0),
    waiters: Atomic(u32) = Atomic(u32).init(0),

    fn wait(self: *Impl, held: Mutex.Held, timeout: ?u64) error{TimedOut}!void {
        var waiters = self.waiters.fetchAdd(1, .Monotonic);
        assert(waiters != std.math.maxInt(u32));

        
    }

    fn wake(self: *Impl, notify_all: bool) void {
        
    }
};
