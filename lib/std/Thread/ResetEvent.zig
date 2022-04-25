//! TODO

const std = @import("../std.zig");
const builtin = @import("builtin");
const ResetEvent = @This();

const os = std.os;
const assert = std.debug.assert;
const testing = std.testing;
const Atomic = std.atomic.Atomic;
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
    state: Atomic(u32) = Atomic(u32).init(unset),

    const unset = 0;
    const waiting = 1;
    const is_set = 2;

    fn isSet(self: *const Impl) bool {
        // Acquire barrier ensures memory accesses before set() happen before we return true.
        return self.state.load(.Acquire) == is_set;
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
        var state = self.state.load(.Monotonic);
        if (state == unset) {
            state = self.state.compareAndSwap(state, waiting, .Monotonic, .Monotonic) orelse waiting;
        }

        // Wait until the ResetEvent is set since the state is waiting.
        if (state == waiting) {
            var futex_deadline = Futex.Deadline.init(timeout);
            while (true) {
                const wait_result = futex_deadline.wait(&self.state, waiting);

                // Check if the ResetEvent was set before possibly reporting error.Timeout below.
                state = self.state.load(.Monotonic);
                if (state != waiting) {
                    break;
                }

                try wait_result;
            }
        }

        // Acquire barrier ensures memory accesses before set() happen before we return.
        assert(state == is_set);
        self.state.fence(.Acquire);
    }

    fn set(self: *Impl) void {
        // Quick check if the ResetEvent is already set before doing the atomic swap below.
        // set() could be getting called quite often and multiple threads calling swap() increases contention unnecessarily.
        if (self.state.load(.Monotonic) == is_set) {
            return;
        }

        // Mark the ResetEvent as set and unblock all waiters waiting on it if any.
        // Release barrier ensures memory accesses before set() happen before the ResetEvent is observed to be "set".
        if (self.state.swap(is_set, .Release) == waiting) {
            Futex.wake(&self.state, std.math.maxInt(u32));
        }
    }

    fn reset(self: *Impl) void {
        self.state.store(unset, .Monotonic);
    }
};
