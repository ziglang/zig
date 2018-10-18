const std = @import("index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;

pub const SpinLock = struct.{
    lock: u8, // TODO use a bool or enum

    pub const Held = struct.{
        spinlock: *SpinLock,

        pub fn release(self: Held) void {
            assert(@atomicRmw(u8, &self.spinlock.lock, builtin.AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst) == 1);
        }
    };

    pub fn init() SpinLock {
        return SpinLock.{ .lock = 0 };
    }

    pub fn acquire(self: *SpinLock) Held {
        while (@atomicRmw(u8, &self.lock, builtin.AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst) != 0) {}
        return Held.{ .spinlock = self };
    }
};

test "spinlock" {
    var lock = SpinLock.init();
    const held = lock.acquire();
    defer held.release();
}
