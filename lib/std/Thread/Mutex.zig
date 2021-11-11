//! Lock may be held only once. If the same thread tries to acquire
//! the same mutex twice, it deadlocks.  This type supports static
//! initialization and is at most `@sizeOf(usize)` in size.  When an
//! application is built in single threaded release mode, all the
//! functions are no-ops. In single threaded debug mode, there is
//! deadlock detection.
//!
//! Example usage:
//! var m = Mutex{};
//!
//! m.lock();
//! defer m.release();
//! ... critical code
//!
//! Non-blocking:
//! if (m.tryLock()) {
//!     defer m.unlock();
//!     // ... critical section
//! } else {
//!     // ... lock not acquired
//! }

impl: Impl = .{},

const Mutex = @This();
const std = @import("../std.zig");
const builtin = @import("builtin");
const os = std.os;
const assert = std.debug.assert;
const windows = os.windows;
const linux = os.linux;
const testing = std.testing;
const StaticResetEvent = std.thread.StaticResetEvent;

/// Try to acquire the mutex without blocking. Returns `false` if the mutex is
/// unavailable. Otherwise returns `true`. Call `unlock` on the mutex to release.
pub fn tryLock(m: *Mutex) bool {
    return m.impl.tryLock();
}

/// Acquire the mutex. Deadlocks if the mutex is already
/// held by the calling thread.
pub fn lock(m: *Mutex) void {
    m.impl.lock();
}

pub fn unlock(m: *Mutex) void {
    m.impl.unlock();
}

const Impl = if (builtin.single_threaded)
    Dummy
else if (builtin.os.tag == .windows)
    WindowsMutex
else if (std.Thread.use_pthreads)
    PthreadMutex
else
    AtomicMutex;

pub const AtomicMutex = struct {
    state: State = .unlocked,

    const State = enum(i32) {
        unlocked,
        locked,
        waiting,
    };

    pub fn tryLock(m: *AtomicMutex) bool {
        return @cmpxchgStrong(
            State,
            &m.state,
            .unlocked,
            .locked,
            .Acquire,
            .Monotonic,
        ) == null;
    }

    pub fn lock(m: *AtomicMutex) void {
        switch (@atomicRmw(State, &m.state, .Xchg, .locked, .Acquire)) {
            .unlocked => {},
            else => |s| m.lockSlow(s),
        }
    }

    pub fn unlock(m: *AtomicMutex) void {
        switch (@atomicRmw(State, &m.state, .Xchg, .unlocked, .Release)) {
            .unlocked => unreachable,
            .locked => {},
            .waiting => m.unlockSlow(),
        }
    }

    fn lockSlow(m: *AtomicMutex, current_state: State) void {
        @setCold(true);
        var new_state = current_state;

        var spin: u8 = 0;
        while (spin < 100) : (spin += 1) {
            const state = @cmpxchgWeak(
                State,
                &m.state,
                .unlocked,
                new_state,
                .Acquire,
                .Monotonic,
            ) orelse return;

            switch (state) {
                .unlocked => {},
                .locked => {},
                .waiting => break,
            }

            var iter = std.math.min(32, spin + 1);
            while (iter > 0) : (iter -= 1)
                std.atomic.spinLoopHint();
        }

        new_state = .waiting;
        while (true) {
            switch (@atomicRmw(State, &m.state, .Xchg, new_state, .Acquire)) {
                .unlocked => return,
                else => {},
            }
            switch (builtin.os.tag) {
                .linux => {
                    switch (linux.getErrno(linux.futex_wait(
                        @ptrCast(*const i32, &m.state),
                        linux.FUTEX.PRIVATE_FLAG | linux.FUTEX.WAIT,
                        @enumToInt(new_state),
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

    fn unlockSlow(m: *AtomicMutex) void {
        @setCold(true);

        switch (builtin.os.tag) {
            .linux => {
                switch (linux.getErrno(linux.futex_wake(
                    @ptrCast(*const i32, &m.state),
                    linux.FUTEX.PRIVATE_FLAG | linux.FUTEX.WAKE,
                    1,
                ))) {
                    .SUCCESS => {},
                    .FAULT => unreachable, // invalid pointer passed to futex_wake
                    else => unreachable,
                }
            },
            else => {},
        }
    }
};

pub const PthreadMutex = struct {
    pthread_mutex: std.c.pthread_mutex_t = .{},

    /// Try to acquire the mutex without blocking. Returns true if
    /// the mutex is unavailable. Otherwise returns false. Call
    /// release when done.
    pub fn tryLock(m: *PthreadMutex) bool {
        return std.c.pthread_mutex_trylock(&m.pthread_mutex) == .SUCCESS;
    }

    /// Acquire the mutex. Will deadlock if the mutex is already
    /// held by the calling thread.
    pub fn lock(m: *PthreadMutex) void {
        switch (std.c.pthread_mutex_lock(&m.pthread_mutex)) {
            .SUCCESS => {},
            .INVAL => unreachable,
            .BUSY => unreachable,
            .AGAIN => unreachable,
            .DEADLK => unreachable,
            .PERM => unreachable,
            else => unreachable,
        }
    }

    pub fn unlock(m: *PthreadMutex) void {
        switch (std.c.pthread_mutex_unlock(&m.pthread_mutex)) {
            .SUCCESS => return,
            .INVAL => unreachable,
            .AGAIN => unreachable,
            .PERM => unreachable,
            else => unreachable,
        }
    }
};

/// This has the sematics as `Mutex`, however it does not actually do any
/// synchronization. Operations are safety-checked no-ops.
pub const Dummy = struct {
    locked: @TypeOf(lock_init) = lock_init,

    const lock_init = if (std.debug.runtime_safety) false else {};

    /// Try to acquire the mutex without blocking. Returns false if
    /// the mutex is unavailable. Otherwise returns true.
    pub fn tryLock(m: *Dummy) bool {
        if (std.debug.runtime_safety) {
            if (m.locked) return false;
            m.locked = true;
        }
        return true;
    }

    /// Acquire the mutex. Will deadlock if the mutex is already
    /// held by the calling thread.
    pub fn lock(m: *Dummy) void {
        if (!m.tryLock()) {
            @panic("deadlock detected");
        }
    }

    pub fn unlock(m: *Dummy) void {
        if (std.debug.runtime_safety) {
            m.locked = false;
        }
    }
};

pub const WindowsMutex = struct {
    srwlock: windows.SRWLOCK = windows.SRWLOCK_INIT,

    pub fn tryLock(m: *WindowsMutex) bool {
        return windows.kernel32.TryAcquireSRWLockExclusive(&m.srwlock) != windows.FALSE;
    }

    pub fn lock(m: *WindowsMutex) void {
        windows.kernel32.AcquireSRWLockExclusive(&m.srwlock);
    }

    pub fn unlock(m: *WindowsMutex) void {
        windows.kernel32.ReleaseSRWLockExclusive(&m.srwlock);
    }
};

const TestContext = struct {
    mutex: *Mutex,
    data: i128,

    const incr_count = 10000;
};

test "basic usage" {
    var mutex = Mutex{};

    var context = TestContext{
        .mutex = &mutex,
        .data = 0,
    };

    if (builtin.single_threaded) {
        worker(&context);
        try testing.expect(context.data == TestContext.incr_count);
    } else {
        const thread_count = 10;
        var threads: [thread_count]std.Thread = undefined;
        for (threads) |*t| {
            t.* = try std.Thread.spawn(.{}, worker, .{&context});
        }
        for (threads) |t|
            t.join();

        try testing.expect(context.data == thread_count * TestContext.incr_count);
    }
}

fn worker(ctx: *TestContext) void {
    var i: usize = 0;
    while (i != TestContext.incr_count) : (i += 1) {
        ctx.mutex.lock();
        defer ctx.mutex.unlock();

        ctx.data += 1;
    }
}
