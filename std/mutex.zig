const std = @import("std.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const testing = std.testing;
const SpinLock = std.SpinLock;
const linux = std.os.linux;
const windows = std.os.windows;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
/// This type must be initialized at runtime, and then deinitialized when no
/// longer needed, to free resources.
/// If you need static initialization, use std.StaticallyInitializedMutex.
/// The Linux implementation is based on mutex3 from
/// https://www.akkadia.org/drepper/futex.pdf
/// When an application is built in single threaded release mode, all the functions are
/// no-ops. In single threaded debug mode, there is deadlock detection.
pub const Mutex = if (builtin.single_threaded)
    struct {
        lock: @typeOf(lock_init),

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
else switch (builtin.os) {
    builtin.Os.linux => struct {
        /// 0: unlocked
        /// 1: locked, no waiters
        /// 2: locked, one or more waiters
        lock: i32,

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                const c = @atomicRmw(i32, &self.mutex.lock, AtomicRmwOp.Sub, 1, AtomicOrder.Release);
                if (c != 1) {
                    _ = @atomicRmw(i32, &self.mutex.lock, AtomicRmwOp.Xchg, 0, AtomicOrder.Release);
                    const rc = linux.futex_wake(&self.mutex.lock, linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
                    switch (linux.getErrno(rc)) {
                        0 => {},
                        linux.EINVAL => unreachable,
                        else => unreachable,
                    }
                }
            }
        };

        pub fn init() Mutex {
            return Mutex{ .lock = 0 };
        }

        pub fn deinit(self: *Mutex) void {}

        pub fn acquire(self: *Mutex) Held {
            var c = @cmpxchgWeak(i32, &self.lock, 0, 1, AtomicOrder.Acquire, AtomicOrder.Monotonic) orelse
                return Held{ .mutex = self };
            if (c != 2)
                c = @atomicRmw(i32, &self.lock, AtomicRmwOp.Xchg, 2, AtomicOrder.Acquire);
            while (c != 0) {
                const rc = linux.futex_wait(&self.lock, linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, 2, null);
                switch (linux.getErrno(rc)) {
                    0, linux.EINTR, linux.EAGAIN => {},
                    linux.EINVAL => unreachable,
                    else => unreachable,
                }
                c = @atomicRmw(i32, &self.lock, AtomicRmwOp.Xchg, 2, AtomicOrder.Acquire);
            }
            return Held{ .mutex = self };
        }
    },
    // TODO once https://github.com/ziglang/zig/issues/287 (copy elision) is solved, we can make a
    // better implementation of this. The problem is we need the init() function to have access to
    // the address of the CRITICAL_SECTION, and then have it not move.
    builtin.Os.windows => std.StaticallyInitializedMutex,
    else => struct {
        /// TODO better implementation than spin lock.
        /// When changing this, one must also change the corresponding
        /// std.StaticallyInitializedMutex code, since it aliases this type,
        /// under the assumption that it works both statically and at runtime.
        lock: SpinLock,

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                SpinLock.Held.release(SpinLock.Held{ .spinlock = &self.mutex.lock });
            }
        };

        pub fn init() Mutex {
            return Mutex{ .lock = SpinLock.init() };
        }

        pub fn deinit(self: *Mutex) void {}

        pub fn acquire(self: *Mutex) Held {
            _ = self.lock.acquire();
            return Held{ .mutex = self };
        }
    },
};

const TestContext = struct {
    mutex: *Mutex,
    data: i128,

    const incr_count = 10000;
};

test "std.Mutex" {
    var plenty_of_memory = try std.heap.direct_allocator.alloc(u8, 300 * 1024);
    defer std.heap.direct_allocator.free(plenty_of_memory);

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
