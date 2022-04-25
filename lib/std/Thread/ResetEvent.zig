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

pub fn isSet(self: *const ResetEvent) bool {
    return self.impl.isSet();
}

pub fn wait(self: *ResetEvent) void {
    self.impl.wait(null) catch |err| switch (err) {
        error.Timeout => unreachable, // no timeout provided so we shouldn't have timed-out 
    };
}

pub fn timedWait(self: *ResetEvent, timeout_ns: u64) error{Timeout}!void {
    return self.impl.wait(timeout_ns);
}

pub fn set(self: *ResetEvent) void {
    self.impl.set();
}

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
    state: Atomic(u32) = Atomic(u32).init(empty),

    const unset = 0;
    const waiting = 1;
    const is_set = 2;

    fn isSet(self: *const Impl) bool {
        return self.state.load(.Acquire) == is_set;
    }

    fn wait(self: *Impl, timeout: ?u64) error{Timeout}!void {
        if (!self.isSet()) {
            try self.waitUntilSet(timeout);
        }
    }

    fn waitUntilSet(self: *Impl, timeout: ?u64) error{Timeout}!void {
        @setCold(true);

        var state = self.state.load(.Monotonic);
        if (state == empty) {
            state = self.state.compareAndSwap(state, waiting, .Monotonic, .Monotonic) orelse waiting;
        }

        if (state == waiting) {
            var futex_deadline = Futex.Deadline.init(timeout);
            while (true) {
                const wait_result = futex_deadline.wait(&self.state, waiting);

                state = self.state.load(.Monotonic);
                if (state != waiting) {
                    break;
                }

                try wait_result;
            }
        }

        assert(state == is_set);
        self.state.fence(.Acquire);
    }

    fn set(self: *Impl) void {
        if (self.state.load(.Monotonic) == is_set) {
            return;
        }

        if (self.state.swap(is_set, .Release) == waiting) {
            Futex.wake(&self.state, std.math.maxInt(u32));
        }
    }

    fn reset(self: *Impl) void {
        self.state.store(unset, .Monotonic);
    }
};

