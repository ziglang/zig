const std = @import("std.zig");
const builtin = @import("builtin");
const testing = std.testing;
const ResetEvent = std.ResetEvent;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
/// This type supports static initialization and is based off of Webkit's WTF Lock (via rust parking_lot)
/// https://github.com/Amanieu/parking_lot/blob/master/core/src/word_lock.rs
/// When an application is built in single threaded release mode, all the functions are
/// no-ops. In single threaded debug mode, there is deadlock detection.
pub const Mutex = if (builtin.single_threaded)
    struct {
        lock: @TypeOf(lock_init),

        const lock_init = if (std.debug.runtime_safety) false else {};

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                if (std.debug.runtime_safety) {
                    self.mutex.lock = false;
                }
            }
        };
        pub fn init() Mutex {
            return Mutex{ .lock = lock_init };
        }
        pub fn deinit(self: *Mutex) void {}

        pub fn acquire(self: *Mutex) Held {
            if (std.debug.runtime_safety and self.lock) {
                @panic("deadlock detected");
            }
            return Held{ .mutex = self };
        }
    }
else
    struct {
        state: usize,

        const MUTEX_LOCK: usize = 1 << 0;
        const QUEUE_LOCK: usize = 1 << 1;
        const QUEUE_MASK: usize = ~(MUTEX_LOCK | QUEUE_LOCK);
        const QueueNode = std.atomic.Stack(ResetEvent).Node;

        /// number of iterations to spin yielding the cpu
        const SPIN_CPU = 4;

        /// number of iterations to spin in the cpu yield loop
        const SPIN_CPU_COUNT = 30;

        /// number of iterations to spin yielding the thread
        const SPIN_THREAD = 1;

        pub fn init() Mutex {
            return Mutex{ .state = 0 };
        }

        pub fn deinit(self: *Mutex) void {
            self.* = undefined;
        }

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                // since MUTEX_LOCK is the first bit, we can use (.Sub) instead of (.And, ~MUTEX_LOCK).
                // this is because .Sub may be implemented more efficiently than the latter
                // (e.g. `lock xadd` vs `cmpxchg` loop on x86)
                const state = @atomicRmw(usize, &self.mutex.state, .Sub, MUTEX_LOCK, .Release);
                if ((state & QUEUE_MASK) != 0 and (state & QUEUE_LOCK) == 0) {
                    self.mutex.releaseSlow(state);
                }
            }
        };

        pub fn acquire(self: *Mutex) Held {
            // fast path close to SpinLock fast path
            if (@cmpxchgWeak(usize, &self.state, 0, MUTEX_LOCK, .Acquire, .Monotonic)) |current_state| {
                self.acquireSlow(current_state);
            }
            return Held{ .mutex = self };
        }

        fn acquireSlow(self: *Mutex, current_state: usize) void {
            var spin: usize = 0;
            var state = current_state;
            while (true) {

                // try and acquire the lock if unlocked
                if ((state & MUTEX_LOCK) == 0) {
                    state = @cmpxchgWeak(usize, &self.state, state, state | MUTEX_LOCK, .Acquire, .Monotonic) orelse return;
                    continue;
                }

                // spin only if the waiting queue isn't empty and when it hasn't spun too much already
                if ((state & QUEUE_MASK) == 0 and spin < SPIN_CPU + SPIN_THREAD) {
                    if (spin < SPIN_CPU) {
                        std.SpinLock.yield(SPIN_CPU_COUNT);
                    } else {
                        std.os.sched_yield() catch std.time.sleep(0);
                    }
                    state = @atomicLoad(usize, &self.state, .Monotonic);
                    continue;
                }

                // thread should block, try and add this event to the waiting queue
                var node = QueueNode{
                    .next = @intToPtr(?*QueueNode, state & QUEUE_MASK),
                    .data = ResetEvent.init(),
                };
                defer node.data.deinit();
                const new_state = @ptrToInt(&node) | (state & ~QUEUE_MASK);
                state = @cmpxchgWeak(usize, &self.state, state, new_state, .Release, .Monotonic) orelse {
                    // node is in the queue, wait until a `held.release()` wakes us up.
                    _ = node.data.wait(null) catch unreachable;
                    spin = 0;
                    state = @atomicLoad(usize, &self.state, .Monotonic);
                    continue;
                };
            }
        }

        fn releaseSlow(self: *Mutex, current_state: usize) void {
            // grab the QUEUE_LOCK in order to signal a waiting queue node's event.
            var state = current_state;
            while (true) {
                if ((state & QUEUE_LOCK) != 0 or (state & QUEUE_MASK) == 0)
                    return;
                state = @cmpxchgWeak(usize, &self.state, state, state | QUEUE_LOCK, .Acquire, .Monotonic) orelse break;
            }

            while (true) {
                // barrier needed to observe incoming state changes
                defer @fence(.Acquire);

                // the mutex is currently locked. try to unset the QUEUE_LOCK and let the locker wake up the next node.
                // avoids waking up multiple sleeping threads which try to acquire the lock again which increases contention.
                if ((state & MUTEX_LOCK) != 0) {
                    state = @cmpxchgWeak(usize, &self.state, state, state & ~QUEUE_LOCK, .Release, .Monotonic) orelse return;
                    continue;
                }

                // try to pop the top node on the waiting queue stack to wake it up
                // while at the same time unsetting the QUEUE_LOCK.
                const node = @intToPtr(*QueueNode, state & QUEUE_MASK);
                const new_state = @ptrToInt(node.next) | (state & MUTEX_LOCK);
                state = @cmpxchgWeak(usize, &self.state, state, new_state, .Release, .Monotonic) orelse {
                    _ = node.data.set(false);
                    return;
                };
            }
        }
    };

const TestContext = struct {
    mutex: *Mutex,
    data: i128,

    const incr_count = 10000;
};

test "std.Mutex" {
    var plenty_of_memory = try std.heap.page_allocator.alloc(u8, 300 * 1024);
    defer std.heap.page_allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var mutex = Mutex.init();
    defer mutex.deinit();

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
