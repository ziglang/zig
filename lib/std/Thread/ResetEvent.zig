//! ResetEvent is a thread-safe bool which can be set to true/false ("set"/"unset").
//! It can also block threads until the "bool" is set with cancellation via timed waits.
//! ResetEvent can be statically initialized and is at most `@sizeOf(u64)` large.

const std = @import("../std.zig");
const builtin = @import("builtin");
const ResetEvent = @This();

const os = std.os;
const assert = std.debug.assert;
const testing = std.testing;
const Futex = std.Thread.Futex;

impl: Impl = .{},

/// Returns if the ResetEvent was set().
/// Once reset() is called, this returns false until the next set().
/// The memory accesses before the set() can be said to happen before isSet() returns true.
pub fn isSet(self: *const ResetEvent) bool {
    return self.impl.isSet();
}

/// Block's the callers thread until the ResetEvent is set().
/// This is effectively a more efficient version of `while (!isSet()) {}`.
/// The memory accesses before the set() can be said to happen before wait() returns.
pub fn wait(self: *ResetEvent) void {
    self.impl.wait(null) catch |err| switch (err) {
        error.Timeout => unreachable, // no timeout provided so we shouldn't have timed-out
    };
}

/// Block's the callers thread until the ResetEvent is set(), or until the corresponding timeout expires.
/// If the timeout expires before the ResetEvent is set, `error.Timeout` is returned.
/// This is effectively a more efficient version of `while (!isSet()) {}`.
/// The memory accesses before the set() can be said to happen before timedWait() returns without error.
pub fn timedWait(self: *ResetEvent, timeout_ns: u64) error{Timeout}!void {
    return self.impl.wait(timeout_ns);
}

/// Marks the ResetEvent as "set" and unblocks any threads in `wait()` or `timedWait()` to observe the new state.
/// The ResetEvent says "set" until reset() is called, making future set() calls do nothing semantically.
/// The memory accesses before set() can be said to happen before isSet() returns true or wait()/timedWait() return successfully.
pub fn set(self: *ResetEvent) void {
    self.impl.set();
}

/// Unmarks the ResetEvent from its "set" state if set() was called previously.
/// It is undefined behavior is reset() is called while threads are blocked in wait() or timedWait().
/// Concurrent calls to set(), isSet() and reset() are allowed.
pub fn reset(self: *ResetEvent) void {
    self.impl.reset();
}

const Impl = if (builtin.single_threaded)
    SingleThreadedImpl
else
    FutexImpl;

const SingleThreadedImpl = struct {
    is_set: bool = false,

    fn isSet(self: *const Impl) bool {
        return self.is_set;
    }

    fn wait(self: *Impl, timeout: ?u64) error{Timeout}!void {
        if (self.isSet()) {
            return;
        }

        // There are no other threads to wake us up.
        // So if we wait without a timeout we would never wake up.
        const timeout_ns = timeout orelse {
            unreachable; // deadlock detected
        };

        std.time.sleep(timeout_ns);
        return error.Timeout;
    }

    fn set(self: *Impl) void {
        self.is_set = true;
    }

    fn reset(self: *Impl) void {
        self.is_set = false;
    }
};

const FutexImpl = struct {
    state: std.atomic.Value(u32) = std.atomic.Value(u32).init(unset),

    const unset = 0;
    const waiting = 1;
    const is_set = 2;

    fn isSet(self: *const Impl) bool {
        // Acquire barrier ensures memory accesses before set() happen before we return true.
        return self.state.load(.acquire) == is_set;
    }

    fn wait(self: *Impl, timeout: ?u64) error{Timeout}!void {
        // Outline the slow path to allow isSet() to be inlined
        if (!self.isSet()) {
            return self.waitUntilSet(timeout);
        }
    }

    fn waitUntilSet(self: *Impl, timeout: ?u64) error{Timeout}!void {
        @setCold(true);

        // Try to set the state from `unset` to `waiting` to indicate
        // to the set() thread that others are blocked on the ResetEvent.
        // We avoid using any strict barriers until the end when we know the ResetEvent is set.
        var state = self.state.load(.monotonic);
        if (state == unset) {
            state = self.state.cmpxchgStrong(state, waiting, .monotonic, .monotonic) orelse waiting;
        }

        // Wait until the ResetEvent is set since the state is waiting.
        if (state == waiting) {
            var futex_deadline = Futex.Deadline.init(timeout);
            while (true) {
                const wait_result = futex_deadline.wait(&self.state, waiting);

                // Check if the ResetEvent was set before possibly reporting error.Timeout below.
                state = self.state.load(.monotonic);
                if (state != waiting) {
                    break;
                }

                try wait_result;
            }
        }

        // Acquire barrier ensures memory accesses before set() happen before we return.
        assert(state == is_set);
        self.state.fence(.acquire);
    }

    fn set(self: *Impl) void {
        // Quick check if the ResetEvent is already set before doing the atomic swap below.
        // set() could be getting called quite often and multiple threads calling swap() increases contention unnecessarily.
        if (self.state.load(.monotonic) == is_set) {
            return;
        }

        // Mark the ResetEvent as set and unblock all waiters waiting on it if any.
        // Release barrier ensures memory accesses before set() happen before the ResetEvent is observed to be "set".
        if (self.state.swap(is_set, .release) == waiting) {
            Futex.wake(&self.state, std.math.maxInt(u32));
        }
    }

    fn reset(self: *Impl) void {
        self.state.store(unset, .monotonic);
    }
};

test "smoke test" {
    // make sure the event is unset
    var event = ResetEvent{};
    try testing.expectEqual(false, event.isSet());

    // make sure the event gets set
    event.set();
    try testing.expectEqual(true, event.isSet());

    // make sure the event gets unset again
    event.reset();
    try testing.expectEqual(false, event.isSet());

    // waits should timeout as there's no other thread to set the event
    try testing.expectError(error.Timeout, event.timedWait(0));
    try testing.expectError(error.Timeout, event.timedWait(std.time.ns_per_ms));

    // set the event again and make sure waits complete
    event.set();
    event.wait();
    try event.timedWait(std.time.ns_per_ms);
    try testing.expectEqual(true, event.isSet());
}

test "signaling" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const Context = struct {
        in: ResetEvent = .{},
        out: ResetEvent = .{},
        value: usize = 0,

        fn input(self: *@This()) !void {
            // wait for the value to become 1
            self.in.wait();
            self.in.reset();
            try testing.expectEqual(self.value, 1);

            // bump the value and wake up output()
            self.value = 2;
            self.out.set();

            // wait for output to receive 2, bump the value and wake us up with 3
            self.in.wait();
            self.in.reset();
            try testing.expectEqual(self.value, 3);

            // bump the value and wake up output() for it to see 4
            self.value = 4;
            self.out.set();
        }

        fn output(self: *@This()) !void {
            // start with 0 and bump the value for input to see 1
            try testing.expectEqual(self.value, 0);
            self.value = 1;
            self.in.set();

            // wait for input to receive 1, bump the value to 2 and wake us up
            self.out.wait();
            self.out.reset();
            try testing.expectEqual(self.value, 2);

            // bump the value to 3 for input to see (rhymes)
            self.value = 3;
            self.in.set();

            // wait for input to bump the value to 4 and receive no more (rhymes)
            self.out.wait();
            self.out.reset();
            try testing.expectEqual(self.value, 4);
        }
    };

    var ctx = Context{};

    const thread = try std.Thread.spawn(.{}, Context.output, .{&ctx});
    defer thread.join();

    try ctx.input();
}

test "broadcast" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const num_threads = 10;
    const Barrier = struct {
        event: ResetEvent = .{},
        counter: std.atomic.Value(usize) = std.atomic.Value(usize).init(num_threads),

        fn wait(self: *@This()) void {
            if (self.counter.fetchSub(1, .acq_rel) == 1) {
                self.event.set();
            }
        }
    };

    const Context = struct {
        start_barrier: Barrier = .{},
        finish_barrier: Barrier = .{},

        fn run(self: *@This()) void {
            self.start_barrier.wait();
            self.finish_barrier.wait();
        }
    };

    var ctx = Context{};
    var threads: [num_threads - 1]std.Thread = undefined;

    for (&threads) |*t| t.* = try std.Thread.spawn(.{}, Context.run, .{&ctx});
    defer for (threads) |t| t.join();

    ctx.run();
}
