//! Recursive Mutex is a mutex that can be blocked multiple times from the same thread.
//! This can be useful when you want to guard functions that lock and unlock a mutex internally.
//! The maximum amont of recursion supported is maxInt(usize)
const RecursiveMutex = @This();
const std = @import("../std.zig");
const builtin = @import("builtin");
const Atomic = std.atomic.Atomic;
const Thread = std.Thread;
const Futex = Thread.Futex;

const assert = std.debug.assert;
const testing = std.testing;

const Impl = if (builtin.single_threaded)
    SingleThreadedImpl
else
    FutexImpl;

impl: Impl = .{},

/// Tries to acquire the mutex without blocking the caller's thread.
/// Returns `false` if the calling thread would have to block to acquire it.
/// Otherwise, returns `true` and the caller should `unlock()` the Mutex to release it.
/// Can be called consecutively by the same thread, in which case always returns true.
pub fn tryLock(self: *RecursiveMutex) bool {
    return self.impl.tryLock();
}

/// Acquires the mutex, blocking the caller's thread until it can.
/// Can be called up to maxInt(usize) times consequtively on the same thread.
/// Once acquired, call `unlock()` on the Mutex to release it.
/// unlock() must be called the same number of times as lock() to release the mutex to other threads.
pub fn lock(self: *RecursiveMutex) void {
    self.impl.lock();
}

/// Releases the mutex which was previously acquired with `lock()` or `tryLock()`.
/// It is undefined behavior if the mutex is unlocked from a different thread that it was locked from.
pub fn unlock(self: *RecursiveMutex) void {
    self.impl.unlock();
}

const SingleThreadedImpl = struct {
    is_locked: bool = false,
    recursion_depth: usize = 0,

    fn tryLock(self: *Impl) bool {
        self.recursion_depth += 1;
        return true;
    }

    fn lock(self: *Impl) void {
        if (self.recursion_depth == 0) {
            self.is_locked = true;
        }
        self.recursion_depth += 1;
    }

    fn unlock(self: *Impl) void {
        assert(self.is_locked);
        const depth =
            self.recursion_depth - 1;
        if (depth == 0) {
            self.is_locked = false;
        }
        self.recursion_depth = depth;
    }
};

const FutexImpl = struct {
    // Technically, there are only 2 states, but we use a whole u32 here
    // because this value is awaited by a Futex
    const State = enum(u32) { unlocked, locked };
    state: Atomic(u32) =
        Atomic(u32).init(0),
    owning_thread_id: Atomic(Thread.Id) =
        Atomic(Thread.Id).init(0),
    recursion_depth: Atomic(usize) =
        Atomic(usize).init(0),

    pub fn tryLock(self: *Impl) bool {
        const current_thread_id =
            Thread.getCurrentId();
        // != null <=> was locked before
        if (self.state.compareAndSwap(@enumToInt(State.unlocked), @enumToInt(State.locked), .AcqRel, .Acquire) != null) {
            const owning_thread = self.owning_thread_id.load(.SeqCst);
            if (owning_thread != current_thread_id) {
                return false;
            }
        }
        // record thread id & break early: no need for blocking
        self.owning_thread_id.store(current_thread_id, .SeqCst);
        _ =
            self.recursion_depth.fetchAdd(1, .SeqCst);
        return true;
    }

    pub fn lock(self: *Impl) void {
        const current_thread_id =
            Thread.getCurrentId();
        var state_result: ?u32 = undefined;
        outer: while (true) {
            state_result =
                self.state.compareAndSwap(@enumToInt(State.unlocked), @enumToInt(State.locked), .AcqRel, .Acquire);
            // was unlocked & this thread made it locked
            if (state_result == null) {
                // record thread id & break early: no need for blocking
                self.owning_thread_id.store(current_thread_id, .SeqCst);
                break :outer;
            } else {
                const owning_thread =
                    self.owning_thread_id.load(.SeqCst);
                if (owning_thread == current_thread_id) {
                    break :outer;
                }
                Futex.wait(&self.state, @enumToInt(State.locked));
            }
        }
        _ = self.recursion_depth.fetchAdd(1, .SeqCst);
    }

    pub fn unlock(self: *Impl) void {
        const current_thread_id =
            Thread.getCurrentId();
        const owning_thread_id =
            self.owning_thread_id.load(.Acquire);
        assert(current_thread_id ==
            owning_thread_id);
        if (self.recursion_depth.fetchSub(1, .SeqCst) == 1) {
            self.owning_thread_id.store(0, .SeqCst);
            self.state.store(@enumToInt(State.unlocked), .SeqCst);
            Futex.wake(&self.state, 1);
        }
    }
};

test "Recursive Mutex - Smoke Test" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }
    const TestContext = struct {
        num_iterations: usize,
        initial_value: u32,
        expected_values: [5]u32,
        protected_data: u32 = 0,
        rm: RecursiveMutex,

        fn worker(context: *@This()) !void {
            var i: u32 = 0;
            var protected_data = &context.protected_data;
            const num_iterations = context.num_iterations;
            while (i < num_iterations) : (i += 1) {
                context.rm.lock();
                testing.expectEqual(@as(usize, 1), context.rm.impl.recursion_depth.load(.Acquire)) catch |e| {
                    @panic(@errorName(e));
                };
                protected_data.* = context.initial_value;
                testing.expectEqual(context.initial_value, protected_data.*) catch |e| {
                    @panic(@errorName(e));
                };
                @This().innerFunction(context) catch |e| {
                    @panic(@errorName(e));
                };
                testing.expectEqual(@as(usize, 1), context.rm.impl.recursion_depth.value) catch |e| {
                    @panic(@errorName((e)));
                };
                testing.expectEqual(context.expected_values[4], protected_data.*) catch |e| {
                    @panic(@errorName(e));
                };
                context.rm.unlock();
            }
        }

        fn innerFunction(context: *@This()) !void {
            var protected_data =
                &context.protected_data;
            const expected =
                context.expected_values;
            try testing.expectEqual(@as(usize, 1), context.rm.impl.recursion_depth.load(.SeqCst));
            context.rm.lock();
            try testing.expectEqual(@as(usize, 2), context.rm.impl.recursion_depth.load(.SeqCst));
            try testing.expectEqual(expected[0], protected_data.*);
            protected_data.* += 1;
            try testing.expectEqual(expected[1], protected_data.*);
            protected_data.* *= 2;
            try testing.expectEqual(expected[2], protected_data.*);
            protected_data.* += 13;
            try testing.expectEqual(@as(usize, 2), context.rm.impl.recursion_depth.load(.SeqCst));
            context.rm.unlock();
            try testing.expectEqual(@as(usize, 1), context.rm.impl.recursion_depth.load(.SeqCst));
            try testing.expectEqual(expected[3], protected_data.*);
        }
    };
    var ctx: TestContext = .{
        .initial_value = 1,
        .expected_values = .{ 1, 2, 4, 17, 17 },
        .num_iterations = 1000,
        .rm = .{},
    };
    const num_threads =
        10;
    var threads: [num_threads]Thread = undefined;
    for (threads) |*t| t.* = try std.Thread.spawn(.{}, TestContext.worker, .{&ctx});
    for (threads) |thread| {
        std.Thread.join(thread);
    }
}

test "Recursive Mutex - lock() Sanity" {
    var rm: RecursiveMutex = .{};
    const depth = 100;
    var i: usize = 0;
    while (i < depth) : (i += 1) {
        rm.lock();
    }
    i = 0;
    while (i < depth) : (i += 1) {
        rm.unlock();
    }
    rm.lock();
    try testing.expectEqual(@as(usize, 1), rm.impl.recursion_depth.load(.Acquire));
}

test "Recursive Mutex - tryLock() Sanity" {
    var rm: RecursiveMutex =
        .{};
    try testing.expectEqual(true, rm.tryLock());
    try testing.expectEqual(true, rm.tryLock());
    rm.unlock();
    rm.unlock();
    try testing.expectEqual(true, rm.tryLock());
}

test "Recursive Mutex - tryLock() Smoke" {
    // This test requires spawning threads
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }
    const TestContext = struct {
        rm: RecursiveMutex,
        semaA: Thread.Semaphore,
        semaB: Thread.Semaphore,

        fn workerA(context: *@This()) !void {
            try testing.expectEqual(true, context.rm.tryLock());
            try testing.expectEqual(true, context.rm.tryLock());
            context.semaB.post();
            context.semaA.wait();
            context.rm.unlock();
            context.semaB.post();
            context.semaA.wait();
            context.rm.unlock();
            context.semaB.post();
            context.semaA.wait();
        }

        fn workerB(context: *@This()) !void {
            context.semaB.wait();
            try testing.expectEqual(false, context.rm.tryLock());
            context.semaA.post();
            context.semaB.wait();
            try testing.expectEqual(false, context.rm.tryLock());
            context.semaA.post();
            context.semaB.wait();
            try testing.expectEqual(true, context.rm.tryLock());
            context.semaA.post();
        }
    };
    var ctx: TestContext = .{
        .rm = .{},
        .semaA = .{ .permits = 0 },
        .semaB = .{ .permits = 0 },
    };
    const thread_a = try std.Thread.spawn(.{}, TestContext.workerA, .{&ctx});
    const thread_b = try std.Thread.spawn(.{}, TestContext.workerB, .{&ctx});
    Thread.join(thread_a);
    Thread.join(thread_b);
}
