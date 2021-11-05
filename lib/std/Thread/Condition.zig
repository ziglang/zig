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

pub fn wait(cond: *Condition, mutex: *Mutex) void {
    cond.impl.wait(mutex);
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
            const held = cond.queue_mutex.acquire();
            defer held.release();

            cond.queue_list.prepend(&waiter);
            @atomicStore(bool, &cond.pending, true, .SeqCst);
        }

        mutex.releaseDirect();
        waiter.data.wait();
        _ = mutex.acquire();
    }

    pub fn signal(cond: *AtomicCondition) void {
        if (@atomicLoad(bool, &cond.pending, .SeqCst) == false)
            return;

        const maybe_waiter = blk: {
            const held = cond.queue_mutex.acquire();
            defer held.release();

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
            const held = cond.queue_mutex.acquire();
            defer held.release();

            const waiters = cond.queue_list;
            cond.queue_list = .{};
            break :blk waiters;
        };

        while (waiters.popFirst()) |waiter|
            waiter.data.notify();
    }
};

// verify that the condition variable unblocks when signalled
test "AtomicCondition" {
    var wait_thread_alive = std.atomic.Atomic(bool).init(false);
    var wait_thread_finished = std.atomic.Atomic(bool).init(false);
    var run_condition = std.atomic.Atomic(bool).init(false);
    var condvar = Condition{};
    const test_thread = try std.Thread.spawn(.{}, conditionWaitThread, .{ &wait_thread_alive, &wait_thread_finished, &run_condition, &condvar });
    test_thread.detach();

    // we give the waiting thread generous time to become alive, but
    // in case it does not, we fail here rather than hang indefinitely
    try waitUntilTrue(&wait_thread_alive,10);

    // this does not really tell us much, but we might as well check it
    try std.testing.expect(!wait_thread_finished.load(.SeqCst));

    run_condition.store(true, .SeqCst);
    condvar.signal();
    
    // similar as above we let the thread indicate it is finished or fail
    try waitUntilTrue(&wait_thread_finished,10);
}

/// a primitive helper method that blocks until an atomic boolean becomes true
/// if the bool does not become true within the given amount of max seconds, this function failes
fn waitUntilTrue(boolean: *std.atomic.Atomic(bool), max_wait_time_seconds: u32) !void {
    var current_time : std.os.timespec = undefined;
    try std.os.clock_gettime(std.os.CLOCK.REALTIME, &current_time);
    const start_time = current_time;
    while (!boolean.load(.SeqCst)) {
        std.os.nanosleep(1, 250 * 1000);
        try std.os.clock_gettime(std.os.CLOCK.REALTIME, &current_time);
        if(current_time.tv_sec - start_time.tv_sec > max_wait_time_seconds) {
            return error.Timeout;
        }
    }
}

/// a helper thread for testing the condition variable. Both wait_... variables must be false when passed to the thread.
/// when the thread starts it 
fn conditionWaitThread(wait_thread_alive: *std.atomic.Atomic(bool), wait_thread_finished: *std.atomic.Atomic(bool), run_condition: *std.atomic.Atomic(bool), condvar: *Condition) void {
    std.debug.assert(!wait_thread_alive.load(.SeqCst));
    std.debug.assert(!wait_thread_finished.load(.SeqCst));

    // indicate this thread has started up
    wait_thread_alive.store(true, .SeqCst);
    var mutex = std.Thread.Mutex{};
    const held = mutex.acquire();
    defer held.release();
    // wait for the condition variable
    while (!run_condition.load(.SeqCst)) {
        condvar.wait(&mutex);
    }
    // and indicate that this thread has completed
    wait_thread_finished.store(true, .SeqCst);
}