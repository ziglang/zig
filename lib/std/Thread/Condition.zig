//! A condition provides a way for a kernel thread to block until it is signaled
//! to wake up. Spurious wakeups are possible.
//! This API supports static initialization and does not require deinitialization.

impl: Impl = .{},

const std = @import("../std.zig");
const builtin = @import("builtin");
const Condition = @This();
const windows = std.os.windows;
const linux = std.os.linux;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;
const testing = std.testing;

pub fn wait(cond: *Condition, mutex: *Mutex) void {
    cond.impl.wait(mutex);
}

pub fn timedWait(cond: *Condition, mutex: *Mutex, timeout_ns: u64) error{TimedOut}!void {
    try cond.impl.timedWait(mutex, timeout_ns);
}

pub fn signal(cond: *Condition) void {
    cond.impl.signal();
}

pub fn broadcast(cond: *Condition) void {
    cond.impl.broadcast();
}

const Impl = if (builtin.single_threaded)
    SingleThreadedCondition
else if (builtin.os.tag == .windows)
    WindowsCondition
else if (std.Thread.use_pthreads)
    PthreadCondition
else
    AtomicCondition;

pub const SingleThreadedCondition = struct {
    pub fn wait(cond: *SingleThreadedCondition, mutex: *Mutex) void {
        _ = cond;
        _ = mutex;
        unreachable; // deadlock detected
    }

    pub fn timedWait(cond: *SingleThreadedCondition, mutex: *Mutex, timeout_ns: u64) error{TimedOut}!void {
        _ = cond;
        _ = mutex;
        _ = timeout_ns;
        unreachable; // deadlock detected
    }

    pub fn signal(cond: *SingleThreadedCondition) void {
        _ = cond;
    }

    pub fn broadcast(cond: *SingleThreadedCondition) void {
        _ = cond;
    }
};

pub const WindowsCondition = struct {
    cond: windows.CONDITION_VARIABLE = windows.CONDITION_VARIABLE_INIT,

    pub fn wait(cond: *WindowsCondition, mutex: *Mutex) void {
        const rc = windows.kernel32.SleepConditionVariableSRW(
            &cond.cond,
            &mutex.impl.srwlock,
            windows.INFINITE,
            @as(windows.ULONG, 0),
        );
        assert(rc != windows.FALSE);
    }

    pub fn timedWait(cond: *WindowsCondition, mutex: *Mutex, timeout_ns: u64) error{TimedOut}!void {
        const rc = windows.kernel32.SleepConditionVariableSRW(
            &cond.cond,
            &mutex.impl.srwlock,
            @truncate(windows.DWORD, timeout_ns / std.time.ns_per_ms),
            @as(windows.ULONG, 0),
        );
        if (rc == windows.FALSE and windows.kernel32.GetLastError() == windows.Win32Error.TIMEOUT) return error.TimedOut;
        assert(rc != windows.FALSE);
    }

    pub fn signal(cond: *WindowsCondition) void {
        windows.kernel32.WakeConditionVariable(&cond.cond);
    }

    pub fn broadcast(cond: *WindowsCondition) void {
        windows.kernel32.WakeAllConditionVariable(&cond.cond);
    }
};

pub const PthreadCondition = struct {
    cond: std.c.pthread_cond_t = .{},

    pub fn wait(cond: *PthreadCondition, mutex: *Mutex) void {
        const rc = std.c.pthread_cond_wait(&cond.cond, &mutex.impl.pthread_mutex);
        assert(rc == .SUCCESS);
    }

    pub fn timedWait(cond: *PthreadCondition, mutex: *Mutex, timeout_ns: u64) error{TimedOut}!void {
        var ts: std.os.timespec = undefined;
        std.os.clock_gettime(std.os.CLOCK.REALTIME, &ts) catch unreachable;
        ts.tv_sec += @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
        ts.tv_nsec += @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);
        if (ts.tv_nsec >= std.time.ns_per_s) {
            ts.tv_sec += 1;
            ts.tv_nsec -= std.time.ns_per_s;
        }

        const rc = std.c.pthread_cond_timedwait(&cond.cond, &mutex.impl.pthread_mutex, &ts);
        return switch (rc) {
            .SUCCESS => {},
            .TIMEDOUT => error.TimedOut,
            else => unreachable,
        };
    }

    pub fn signal(cond: *PthreadCondition) void {
        const rc = std.c.pthread_cond_signal(&cond.cond);
        assert(rc == .SUCCESS);
    }

    pub fn broadcast(cond: *PthreadCondition) void {
        const rc = std.c.pthread_cond_broadcast(&cond.cond);
        assert(rc == .SUCCESS);
    }
};

pub const AtomicCondition = struct {
    pending: bool = false,
    queue_mutex: Mutex = .{},
    queue_list: QueueList = .{},

    pub const QueueList = std.SinglyLinkedList(QueueItem);

    pub const QueueItem = struct {
        futex: i32 = 0,

        fn wait(cond: *@This()) void {
            while (@atomicLoad(i32, &cond.futex, .Acquire) == 0) {
                switch (builtin.os.tag) {
                    .linux => {
                        switch (linux.getErrno(linux.futex_wait(
                            &cond.futex,
                            linux.FUTEX.PRIVATE_FLAG | linux.FUTEX.WAIT,
                            0,
                            null,
                        ))) {
                            .SUCCESS => {},
                            .INTR => {},
                            .AGAIN => {},
                            else => unreachable,
                        }
                    },
                    else => std.atomic.spinLoopHint(),
                }
            }
        }

        pub fn timedWait(cond: *@This(), timeout_ns: u64) error{TimedOut}!void {
            const start_time = std.time.nanoTimestamp();
            while (@atomicLoad(i32, &cond.futex, .Acquire) == 0) {
                switch (builtin.os.tag) {
                    .linux => {
                        var ts: std.os.timespec = undefined;
                        ts.tv_sec = @intCast(@TypeOf(ts.tv_sec), timeout_ns / std.time.ns_per_s);
                        ts.tv_nsec = @intCast(@TypeOf(ts.tv_nsec), timeout_ns % std.time.ns_per_s);
                        switch (linux.getErrno(linux.futex_wait(
                            &cond.futex,
                            linux.FUTEX.PRIVATE_FLAG | linux.FUTEX.WAIT,
                            0,
                            &ts,
                        ))) {
                            .SUCCESS => {},
                            .INTR => {},
                            .AGAIN => {},
                            .TIMEDOUT => return error.TimedOut,
                            .INVAL => {}, // possibly timeout overflow
                            .FAULT => unreachable,
                            else => unreachable,
                        }
                    },
                    else => {
                        if (std.time.nanoTimestamp() - start_time >= timeout_ns) {
                            return error.TimedOut;
                        }
                        std.atomic.spinLoopHint();
                    },
                }
            }
        }

        fn notify(cond: *@This()) void {
            @atomicStore(i32, &cond.futex, 1, .Release);

            switch (builtin.os.tag) {
                .linux => {
                    switch (linux.getErrno(linux.futex_wake(
                        &cond.futex,
                        linux.FUTEX.PRIVATE_FLAG | linux.FUTEX.WAKE,
                        1,
                    ))) {
                        .SUCCESS => {},
                        .FAULT => {},
                        else => unreachable,
                    }
                },
                else => {},
            }
        }
    };

    pub fn wait(cond: *AtomicCondition, mutex: *Mutex) void {
        var waiter = QueueList.Node{ .data = .{} };

        {
            cond.queue_mutex.lock();
            defer cond.queue_mutex.unlock();

            cond.queue_list.prepend(&waiter);
            @atomicStore(bool, &cond.pending, true, .SeqCst);
        }

        mutex.unlock();
        waiter.data.wait();
        mutex.lock();
    }

    pub fn timedWait(cond: *AtomicCondition, mutex: *Mutex, timeout_ns: u64) error{TimedOut}!void {
        var waiter = QueueList.Node{ .data = .{} };

        {
            cond.queue_mutex.lock();
            defer cond.queue_mutex.unlock();

            cond.queue_list.prepend(&waiter);
            @atomicStore(bool, &cond.pending, true, .SeqCst);
        }

        mutex.unlock();
        defer mutex.lock();
        try waiter.data.timedWait(timeout_ns);
    }

    pub fn signal(cond: *AtomicCondition) void {
        if (@atomicLoad(bool, &cond.pending, .SeqCst) == false)
            return;

        const maybe_waiter = blk: {
            cond.queue_mutex.lock();
            defer cond.queue_mutex.unlock();

            const maybe_waiter = cond.queue_list.popFirst();
            @atomicStore(bool, &cond.pending, cond.queue_list.first != null, .SeqCst);
            break :blk maybe_waiter;
        };

        if (maybe_waiter) |waiter|
            waiter.data.notify();
    }

    pub fn broadcast(cond: *AtomicCondition) void {
        if (@atomicLoad(bool, &cond.pending, .SeqCst) == false)
            return;

        @atomicStore(bool, &cond.pending, false, .SeqCst);

        var waiters = blk: {
            cond.queue_mutex.lock();
            defer cond.queue_mutex.unlock();

            const waiters = cond.queue_list;
            cond.queue_list = .{};
            break :blk waiters;
        };

        while (waiters.popFirst()) |waiter|
            waiter.data.notify();
    }
};

test "Thread.Condition" {
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const TestContext = struct {
        cond: *Condition,
        cond_main: *Condition,
        mutex: *Mutex,
        n: *i32,
        fn worker(ctx: *@This()) void {
            ctx.mutex.lock();
            ctx.n.* += 1;
            ctx.cond_main.signal();
            ctx.cond.wait(ctx.mutex);
            ctx.n.* -= 1;
            ctx.cond_main.signal();
            ctx.mutex.unlock();
        }
    };
    const num_threads = 3;
    var threads: [num_threads]std.Thread = undefined;
    var cond = Condition{};
    var cond_main = Condition{};
    var mut = Mutex{};
    var n: i32 = 0;
    var ctx = TestContext{ .cond = &cond, .cond_main = &cond_main, .mutex = &mut, .n = &n };

    mut.lock();
    for (threads) |*t| t.* = try std.Thread.spawn(.{}, TestContext.worker, .{&ctx});
    cond_main.wait(&mut);
    while (n < num_threads) cond_main.wait(&mut);

    cond.signal();
    cond_main.wait(&mut);
    try testing.expect(n == (num_threads - 1));

    cond.broadcast();
    while (n > 0) cond_main.wait(&mut);
    try testing.expect(n == 0);

    for (threads) |t| t.join();
}

test "Thread.Condition.timedWait" {
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    var cond = Condition{};
    var mut = Mutex{};

    // Expect a timeout, as the condition variable is never signaled
    {
        mut.lock();
        defer mut.unlock();
        try testing.expectError(error.TimedOut, cond.timedWait(&mut, 10 * std.time.ns_per_ms));
    }

    // Expect a signal before timeout
    {
        const TestContext = struct {
            cond: *Condition,
            mutex: *Mutex,
            n: *u32,
            fn worker(ctx: *@This()) void {
                ctx.mutex.lock();
                defer ctx.mutex.unlock();
                ctx.n.* = 1;
                ctx.cond.signal();
            }
        };

        var n: u32 = 0;

        var ctx = TestContext{ .cond = &cond, .mutex = &mut, .n = &n };
        mut.lock();
        var thread = try std.Thread.spawn(.{}, TestContext.worker, .{&ctx});
        // Looped check to handle spurious wakeups
        while (n != 1) try cond.timedWait(&mut, 500 * std.time.ns_per_ms);
        mut.unlock();
        try testing.expect(n == 1);
        thread.join();
    }
}
