const std = @import("index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;
const SpinLock = std.SpinLock;
const linux = std.os.linux;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
/// The Linux implementation is based on mutex3 from
/// https://www.akkadia.org/drepper/futex.pdf
pub const Mutex = struct.{
    /// 0: unlocked
    /// 1: locked, no waiters
    /// 2: locked, one or more waiters
    linux_lock: @typeOf(linux_lock_init),

    /// TODO better implementation than spin lock
    spin_lock: @typeOf(spin_lock_init),

    const linux_lock_init = if (builtin.os == builtin.Os.linux) i32(0) else {};
    const spin_lock_init = if (builtin.os != builtin.Os.linux) SpinLock.init() else {};

    pub const Held = struct.{
        mutex: *Mutex,

        pub fn release(self: Held) void {
            if (builtin.os == builtin.Os.linux) {
                const c = @atomicRmw(i32, &self.mutex.linux_lock, AtomicRmwOp.Sub, 1, AtomicOrder.Release);
                if (c != 1) {
                    _ = @atomicRmw(i32, &self.mutex.linux_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.Release);
                    const rc = linux.futex_wake(&self.mutex.linux_lock, linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
                    switch (linux.getErrno(rc)) {
                        0 => {},
                        linux.EINVAL => unreachable,
                        else => unreachable,
                    }
                }
            } else {
                SpinLock.Held.release(SpinLock.Held.{ .spinlock = &self.mutex.spin_lock });
            }
        }
    };

    pub fn init() Mutex {
        return Mutex.{
            .linux_lock = linux_lock_init,
            .spin_lock = spin_lock_init,
        };
    }

    pub fn acquire(self: *Mutex) Held {
        if (builtin.os == builtin.Os.linux) {
            var c = @cmpxchgWeak(i32, &self.linux_lock, 0, 1, AtomicOrder.Acquire, AtomicOrder.Monotonic) orelse
                return Held.{ .mutex = self };
            if (c != 2)
                c = @atomicRmw(i32, &self.linux_lock, AtomicRmwOp.Xchg, 2, AtomicOrder.Acquire);
            while (c != 0) {
                const rc = linux.futex_wait(&self.linux_lock, linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, 2, null);
                switch (linux.getErrno(rc)) {
                    0, linux.EINTR, linux.EAGAIN => {},
                    linux.EINVAL => unreachable,
                    else => unreachable,
                }
                c = @atomicRmw(i32, &self.linux_lock, AtomicRmwOp.Xchg, 2, AtomicOrder.Acquire);
            }
        } else {
            _ = self.spin_lock.acquire();
        }
        return Held.{ .mutex = self };
    }
};

const Context = struct.{
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
    var context = Context.{
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
