// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! A condition provides a way for a kernel thread to block until it is signaled
//! to wake up. Spurious wakeups are possible.
//! This API supports static initialization and does not require deinitialization.

impl: Impl = .{},

const std = @import("../std.zig");
const Condition = @This();
const windows = std.os.windows;
const linux = std.os.linux;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

pub fn wait(cond: *Condition, held: Mutex.Held) void {
    cond.impl.wait(held);
}

pub fn signal(cond: *Condition) void {
    cond.impl.signal();
}

pub fn broadcast(cond: *Condition) void {
    cond.impl.broadcast();
}

const Impl = if (std.builtin.single_threaded)
    SingleThreadedCondition
else if (std.Target.current.os.tag == .windows)
    WindowsCondition
else if (std.Thread.use_pthreads)
    PthreadCondition
else
    AtomicCondition;

pub const SingleThreadedCondition = struct {
    pub fn wait(cond: *SingleThreadedCondition, held: Mutex.Held) void {
        unreachable; // deadlock detected
    }

    pub fn signal(cond: *SingleThreadedCondition) void {}

    pub fn broadcast(cond: *SingleThreadedCondition) void {}
};

pub const WindowsCondition = struct {
    cond: windows.CONDITION_VARIABLE = windows.CONDITION_VARIABLE_INIT,

    pub fn wait(cond: *WindowsCondition, held: Mutex.Held) void {
        const rc = windows.kernel32.SleepConditionVariableSRW(
            &cond.cond,
            &held.mutex.srwlock,
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

    pub fn wait(cond: *PthreadCondition, held: Mutex.Held) void {
        const rc = std.c.pthread_cond_wait(&cond.cond, &held.mutex.pthread_mutex);
        assert(rc == 0);
    }

    pub fn signal(cond: *PthreadCondition) void {
        const rc = std.c.pthread_cond_signal(&cond.cond);
        assert(rc == 0);
    }

    pub fn broadcast(cond: *PthreadCondition) void {
        const rc = std.c.pthread_cond_broadcast(&cond.cond);
        assert(rc == 0);
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
                switch (std.Target.current.os.tag) {
                    .linux => {
                        switch (linux.getErrno(linux.futex_wait(
                            &cond.futex,
                            linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAIT,
                            0,
                            null,
                        ))) {
                            0 => {},
                            std.os.EINTR => {},
                            std.os.EAGAIN => {},
                            else => unreachable,
                        }
                    },
                    else => spinLoopHint(),
                }
            }
        }

        fn notify(cond: *@This()) void {
            @atomicStore(i32, &cond.futex, 1, .Release);

            switch (std.Target.current.os.tag) {
                .linux => {
                    switch (linux.getErrno(linux.futex_wake(
                        &cond.futex,
                        linux.FUTEX_PRIVATE_FLAG | linux.FUTEX_WAKE,
                        1,
                    ))) {
                        0 => {},
                        std.os.EFAULT => {},
                        else => unreachable,
                    }
                },
                else => {},
            }
        }
    };

    pub fn wait(cond: *AtomicCondition, held: Mutex.Held) void {
        var waiter = QueueList.Node{ .data = .{} };

        {
            const h = cond.queue_mutex.acquire();
            defer h.release();

            cond.queue_list.prepend(&waiter);
            @atomicStore(bool, &cond.pending, true, .SeqCst);
        }

        held.release();
        waiter.data.wait();
        _ = held.mutex.acquire();
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

const TestContext = struct {
    mutex: *Mutex,
    state: bool,
    con: *Condition,
};

test "basic usage" {
    var mutex = Mutex{};
    var condition = Condition{};
    var context = TestContext{
        .mutex = &mutex,
        .state = false,
        .con = &condition,
    };

    var thread = try std.Thread.spawn(worker, &context);

    {
        var lock = context.mutex.acquire();
        defer lock.release();

        while (!context.state) {
            context.con.wait(lock);
        }
    }

    std.time.sleep(std.time.ns_per_ms * 2);
    {
        const lock = context.mutex.acquire();
        defer lock.release();

        context.state = false;
        context.con.broadcast();
    }

    thread.wait();
    std.testing.expectEqual(true, context.state);
}

fn worker(context: *TestContext) void {
    std.time.sleep(std.time.ns_per_ms * 2);

    // Update state and signal.
    {
        const lock = context.mutex.acquire();
        defer lock.release();
        context.state = true;
        context.con.signal();
    }

    // Wait for state to be switched back.
    {
        var lock = context.mutex.acquire();
        defer lock.release();
        while (context.state) {
            context.con.wait(lock);
        }
        context.state = true;
    }
}
