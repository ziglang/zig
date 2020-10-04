// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = @import("builtin");
const os = std.os;
const assert = std.debug.assert;
const windows = os.windows;
const testing = std.testing;
const SpinLock = std.SpinLock;
const ResetEvent = std.ResetEvent;

/// Lock may be held only once. If the same thread tries to acquire
/// the same mutex twice, it deadlocks.  This type supports static
/// initialization and is at most `@sizeOf(usize)` in size.  When an
/// application is built in single threaded release mode, all the
/// functions are no-ops. In single threaded debug mode, there is
/// deadlock detection.
///
/// Example usage:
/// var m = Mutex{};
///
/// const lock = m.acquire();
/// defer lock.release();
/// ... critical code
///
/// Non-blocking:
/// if (m.tryAcquire) |lock| {
///     defer lock.release();
///     // ... critical section
/// } else {
///     // ... lock not acquired
/// }
pub const Mutex = if (builtin.single_threaded)
    Dummy
else if (builtin.os.tag == .windows)
    WindowsMutex
else if (builtin.link_libc or builtin.os.tag == .linux)
// stack-based version of https://github.com/Amanieu/parking_lot/blob/master/core/src/word_lock.rs
    struct {
        state: usize = 0,

        /// number of times to spin trying to acquire the lock.
        /// https://webkit.org/blog/6161/locking-in-webkit/
        const SPIN_COUNT = 40;

        const MUTEX_LOCK: usize = 1 << 0;
        const QUEUE_LOCK: usize = 1 << 1;
        const QUEUE_MASK: usize = ~(MUTEX_LOCK | QUEUE_LOCK);

        const Node = struct {
            next: ?*Node,
            event: ResetEvent,
        };

        pub fn tryAcquire(self: *Mutex) ?Held {
            if (@cmpxchgWeak(usize, &self.state, 0, MUTEX_LOCK, .Acquire, .Monotonic) != null)
                return null;
            return Held{ .mutex = self };
        }

        pub fn acquire(self: *Mutex) Held {
            return self.tryAcquire() orelse {
                self.acquireSlow();
                return Held{ .mutex = self };
            };
        }

        fn acquireSlow(self: *Mutex) void {
            // inlining the fast path and hiding *Slow()
            // calls behind a @setCold(true) appears to
            // improve performance in release builds.
            @setCold(true);
            while (true) {

                // try and spin for a bit to acquire the mutex if theres currently no queue
                var spin_count: u32 = SPIN_COUNT;
                var state = @atomicLoad(usize, &self.state, .Monotonic);
                while (spin_count != 0) : (spin_count -= 1) {
                    if (state & MUTEX_LOCK == 0) {
                        _ = @cmpxchgWeak(usize, &self.state, state, state | MUTEX_LOCK, .Acquire, .Monotonic) orelse return;
                    } else if (state & QUEUE_MASK == 0) {
                        break;
                    }
                    SpinLock.yield();
                    state = @atomicLoad(usize, &self.state, .Monotonic);
                }

                // create the ResetEvent node on the stack
                // (faster than threadlocal on platforms like OSX)
                var node: Node = undefined;
                node.event = ResetEvent.init();
                defer node.event.deinit();

                // we've spun too long, try and add our node to the LIFO queue.
                // if the mutex becomes available in the process, try and grab it instead.
                while (true) {
                    if (state & MUTEX_LOCK == 0) {
                        _ = @cmpxchgWeak(usize, &self.state, state, state | MUTEX_LOCK, .Acquire, .Monotonic) orelse return;
                    } else {
                        node.next = @intToPtr(?*Node, state & QUEUE_MASK);
                        const new_state = @ptrToInt(&node) | (state & ~QUEUE_MASK);
                        _ = @cmpxchgWeak(usize, &self.state, state, new_state, .Release, .Monotonic) orelse {
                            node.event.wait();
                            break;
                        };
                    }
                    SpinLock.yield();
                    state = @atomicLoad(usize, &self.state, .Monotonic);
                }
            }
        }

        /// Returned when the lock is acquired. Call release to
        /// release.
        pub const Held = struct {
            mutex: *Mutex,

            /// Release the held lock.
            pub fn release(self: Held) void {
                // first, remove the lock bit so another possibly parallel acquire() can succeed.
                // use .Sub since it can be usually compiled down more efficiency
                // (`lock sub` on x86) vs .And ~MUTEX_LOCK (`lock cmpxchg` loop on x86)
                const state = @atomicRmw(usize, &self.mutex.state, .Sub, MUTEX_LOCK, .Release);

                // if the LIFO queue isnt locked and it has a node, try and wake up the node.
                if ((state & QUEUE_LOCK) == 0 and (state & QUEUE_MASK) != 0)
                    self.mutex.releaseSlow();
            }
        };

        fn releaseSlow(self: *Mutex) void {
            @setCold(true);

            // try and lock the LFIO queue to pop a node off,
            // stopping altogether if its already locked or the queue is empty
            var state = @atomicLoad(usize, &self.state, .Monotonic);
            while (true) : (SpinLock.loopHint(1)) {
                if (state & QUEUE_LOCK != 0 or state & QUEUE_MASK == 0)
                    return;
                state = @cmpxchgWeak(usize, &self.state, state, state | QUEUE_LOCK, .Acquire, .Monotonic) orelse break;
            }

            // acquired the QUEUE_LOCK, try and pop a node to wake it.
            // if the mutex is locked, then unset QUEUE_LOCK and let
            // the thread who holds the mutex do the wake-up on unlock()
            while (true) : (SpinLock.loopHint(1)) {
                if ((state & MUTEX_LOCK) != 0) {
                    state = @cmpxchgWeak(usize, &self.state, state, state & ~QUEUE_LOCK, .Release, .Acquire) orelse return;
                } else {
                    const node = @intToPtr(*Node, state & QUEUE_MASK);
                    const new_state = @ptrToInt(node.next);
                    state = @cmpxchgWeak(usize, &self.state, state, new_state, .Release, .Acquire) orelse {
                        node.event.set();
                        return;
                    };
                }
            }
        }
    }

    // for platforms without a known OS blocking
    // primitive, default to SpinLock for correctness
else
    SpinLock;

/// This has the sematics as `Mutex`, however it does not actually do any
/// synchronization. Operations are safety-checked no-ops.
pub const Dummy = struct {
    lock: @TypeOf(lock_init) = lock_init,

    const lock_init = if (std.debug.runtime_safety) false else {};

    pub const Held = struct {
        mutex: *Dummy,

        pub fn release(self: Held) void {
            if (std.debug.runtime_safety) {
                self.mutex.lock = false;
            }
        }
    };

    /// Create a new mutex in unlocked state.
    pub const init = Dummy{};

    /// Try to acquire the mutex without blocking. Returns null if
    /// the mutex is unavailable. Otherwise returns Held. Call
    /// release on Held.
    pub fn tryAcquire(self: *Dummy) ?Held {
        if (std.debug.runtime_safety) {
            if (self.lock) return null;
            self.lock = true;
        }
        return Held{ .mutex = self };
    }

    /// Acquire the mutex. Will deadlock if the mutex is already
    /// held by the calling thread.
    pub fn acquire(self: *Dummy) Held {
        return self.tryAcquire() orelse @panic("deadlock detected");
    }
};

// https://locklessinc.com/articles/keyed_events/
const WindowsMutex = struct {
    state: State = State{ .waiters = 0 },

    const State = extern union {
        locked: u8,
        waiters: u32,
    };

    const WAKE = 1 << 8;
    const WAIT = 1 << 9;

    pub fn tryAcquire(self: *WindowsMutex) ?Held {
        if (@atomicRmw(u8, &self.state.locked, .Xchg, 1, .Acquire) != 0)
            return null;
        return Held{ .mutex = self };
    }

    pub fn acquire(self: *WindowsMutex) Held {
        return self.tryAcquire() orelse self.acquireSlow();
    }

    fn acquireSpinning(self: *WindowsMutex) Held {
        @setCold(true);
        while (true) : (SpinLock.yield()) {
            return self.tryAcquire() orelse continue;
        }
    }

    fn acquireSlow(self: *WindowsMutex) Held {
        // try to use NT keyed events for blocking, falling back to spinlock if unavailable
        @setCold(true);
        const handle = ResetEvent.OsEvent.Futex.getEventHandle() orelse return self.acquireSpinning();
        const key = @ptrCast(*const c_void, &self.state.waiters);

        while (true) : (SpinLock.loopHint(1)) {
            const waiters = @atomicLoad(u32, &self.state.waiters, .Monotonic);

            // try and take lock if unlocked
            if ((waiters & 1) == 0) {
                if (@atomicRmw(u8, &self.state.locked, .Xchg, 1, .Acquire) == 0) {
                    return Held{ .mutex = self };
                }

                // otherwise, try and update the waiting count.
                // then unset the WAKE bit so that another unlocker can wake up a thread.
            } else if (@cmpxchgWeak(u32, &self.state.waiters, waiters, (waiters + WAIT) | 1, .Monotonic, .Monotonic) == null) {
                const rc = windows.ntdll.NtWaitForKeyedEvent(handle, key, windows.FALSE, null);
                assert(rc == .SUCCESS);
                _ = @atomicRmw(u32, &self.state.waiters, .Sub, WAKE, .Monotonic);
            }
        }
    }

    pub const Held = struct {
        mutex: *WindowsMutex,

        pub fn release(self: Held) void {
            // unlock without a rmw/cmpxchg instruction
            @atomicStore(u8, @ptrCast(*u8, &self.mutex.state.locked), 0, .Release);
            const handle = ResetEvent.OsEvent.Futex.getEventHandle() orelse return;
            const key = @ptrCast(*const c_void, &self.mutex.state.waiters);

            while (true) : (SpinLock.loopHint(1)) {
                const waiters = @atomicLoad(u32, &self.mutex.state.waiters, .Monotonic);

                // no one is waiting
                if (waiters < WAIT) return;
                // someone grabbed the lock and will do the wake instead
                if (waiters & 1 != 0) return;
                // someone else is currently waking up
                if (waiters & WAKE != 0) return;

                // try to decrease the waiter count & set the WAKE bit meaning a thread is waking up
                if (@cmpxchgWeak(u32, &self.mutex.state.waiters, waiters, waiters - WAIT + WAKE, .Release, .Monotonic) == null) {
                    const rc = windows.ntdll.NtReleaseKeyedEvent(handle, key, windows.FALSE, null);
                    assert(rc == .SUCCESS);
                    return;
                }
            }
        }
    };
};

const TestContext = struct {
    mutex: *Mutex,
    data: i128,

    const incr_count = 10000;
};

test "std.Mutex" {
    var mutex = Mutex{};

    var context = TestContext{
        .mutex = &mutex,
        .data = 0,
    };

    if (builtin.single_threaded) {
        worker(&context);
        testing.expect(context.data == TestContext.incr_count);
    } else {
        const thread_count = 10;
        var threads: [thread_count]*std.Thread = undefined;
        for (threads) |*t| {
            t.* = try std.Thread.spawn(&context, worker);
        }
        for (threads) |t|
            t.wait();

        testing.expect(context.data == thread_count * TestContext.incr_count);
    }
}

fn worker(ctx: *TestContext) void {
    var i: usize = 0;
    while (i != TestContext.incr_count) : (i += 1) {
        const held = ctx.mutex.acquire();
        defer held.release();

        ctx.data += 1;
    }
}
