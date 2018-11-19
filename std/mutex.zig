const std = @import("index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;
const SpinLock = std.SpinLock;
const linux = std.os.linux;
const windows = std.os.windows;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
/// The Linux implementation is based on mutex3 from
/// https://www.akkadia.org/drepper/futex.pdf
pub const Mutex = switch(builtin.os) {
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
            return Mutex {
                .lock = 0,
            };
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
            return Held { .mutex = self };
        }
    },
    builtin.Os.windows => struct {
        lock: ?*windows.RTL_CRITICAL_SECTION,

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                windows.LeaveCriticalSection(self.mutex.lock);
            }
        };

        pub fn init() Mutex {
            var lock: ?*windows.RTL_CRITICAL_SECTION = null;
            windows.InitializeCriticalSection(lock);
            return Mutex { .lock = lock };
        }

        pub fn deinit(self: *Mutex) void {
            if (self.lock != null) {
                windows.DeleteCriticalSection(self.lock);
                self.lock = null;
            }
        }

        pub fn acquire(self: *Mutex) Held {
            windows.EnterCriticalSection(self.lock);
            return Held { .mutex = self };
        }
    },
    else => struct {
        /// TODO better implementation than spin lock
        lock: SpinLock,

        pub const Held = struct {
            mutex: *Mutex,

            pub fn release(self: Held) void {
                SpinLock.Held.release(SpinLock.Held { .spinlock = &self.mutex.lock });
            }
        };

        pub fn init() Mutex {
            return Mutex {
                .lock = SpinLock.init(),
            };
        }

        pub fn deinit(self: *Mutex) void {}

        pub fn acquire(self: *Mutex) Held {
            _ = self.lock.acquire();
            return Held { .mutex = self };
        }
    },
};

const Context = struct {
    mutex: *Mutex,
    data: i128,

    const incr_count = 10000;
};

test "std.Mutex" {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var plenty_of_memory = try direct_allocator.allocator.alloc(u8, 300 * 1024);
    defer direct_allocator.allocator.free(plenty_of_memory);

    var fixed_buffer_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(plenty_of_memory);
    var a = &fixed_buffer_allocator.allocator;

    var mutex = Mutex.init();
    defer mutex.deinit();

    var context = Context{
        .mutex = &mutex,
        .data = 0,
    };

    const thread_count = 10;
    var threads: [thread_count]*std.os.Thread = undefined;
    for (threads) |*t| {
        t.* = try std.os.spawnThread(&context, worker);
    }
    for (threads) |t|
        t.wait();

    std.debug.assertOrPanic(context.data == thread_count * Context.incr_count);
}

fn worker(ctx: *Context) void {
    var i: usize = 0;
    while (i != Context.incr_count) : (i += 1) {
        const held = ctx.mutex.acquire();
        defer held.release();

        ctx.data += 1;
    }
}
