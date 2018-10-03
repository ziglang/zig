const std = @import("index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;
const SpinLock = std.SpinLock;
const linux = std.os.linux;

/// Lock may be held only once. If the same thread
/// tries to acquire the same mutex twice, it deadlocks.
pub const Mutex = struct {
    /// 0: unlocked
    /// 1: locked, no waiters
    /// 2: locked, one or more waiters
    linux_lock: @typeOf(linux_lock_init),

    /// TODO better implementation than spin lock
    spin_lock: @typeOf(spin_lock_init),

    const linux_lock_init = if (builtin.os == builtin.Os.linux) i32(0) else {};
    const spin_lock_init = if (builtin.os != builtin.Os.linux) SpinLock.init() else {};

    pub const Held = struct {
        mutex: *Mutex,

        pub fn release(self: Held) void {
            if (builtin.os == builtin.Os.linux) {
                // Always unlock. If the previous state was Locked-No-Waiters, then we're done.
                // Otherwise, wake a waiter up.
                const prev = @atomicRmw(i32, &self.mutex.linux_lock, AtomicRmwOp.Xchg, 0, AtomicOrder.Release);
                if (prev != 1) {
                    assert(prev == 2);
                    const rc = linux.futex_wake(&self.mutex.linux_lock, linux.FUTEX_WAKE, 1);
                    switch (linux.getErrno(rc)) {
                        0 => {},
                        linux.EINVAL => unreachable,
                        else => unreachable,
                    }
                }
            } else {
                SpinLock.Held.release(SpinLock.Held{ .spinlock = &self.mutex.spin_lock });
            }
        }
    };

    pub fn init() Mutex {
        return Mutex{
            .linux_lock = linux_lock_init,
            .spin_lock = spin_lock_init,
        };
    }

    pub fn acquire(self: *Mutex) Held {
        if (builtin.os == builtin.Os.linux) {
            // First try to go from Unlocked to Locked-No-Waiters. If this succeeds, no syscalls are needed.
            // Otherwise, we need to be in the Locked-With-Waiters state. If we are already in that state,
            // proceed to futex_wait. Otherwise, try to go from Locked-No-Waiters to Locked-With-Waiters.
            // If that succeeds, proceed to futex_wait. Otherwise start the whole loop over again.
            while (@cmpxchgWeak(i32, &self.linux_lock, 0, 1, AtomicOrder.Acquire, AtomicOrder.Monotonic)) |l| {
                if (l == 2 or
                    @cmpxchgWeak(i32, &self.linux_lock, 1, 2, AtomicOrder.Acquire, AtomicOrder.Monotonic) == null)
                {
                    const rc = linux.futex_wait(&self.linux_lock, linux.FUTEX_WAIT, 2, null);
                    switch (linux.getErrno(rc)) {
                        0, linux.EINTR, linux.EAGAIN => continue,
                        linux.EINVAL => unreachable,
                        else => unreachable,
                    }
                }
            }
        } else {
            _ = self.spin_lock.acquire();
        }
        return Held{ .mutex = self };
    }
};
