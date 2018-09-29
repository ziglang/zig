const std = @import("index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;

/// TODO use syscalls instead of a spinlock
pub const Mutex = struct {
    lock: u8, // TODO use a bool

    pub const Held = struct {
        mutex: *Mutex,

        pub fn release(self: Held) void {
            assert(@atomicRmw(u8, &self.mutex.lock, builtin.AtomicRmwOp.Xchg, 0, AtomicOrder.SeqCst) == 1);
        }
    };

    pub fn init() Mutex {
        return Mutex{ .lock = 0 };
    }

    pub fn acquire(self: *Mutex) Held {
        while (@atomicRmw(u8, &self.lock, builtin.AtomicRmwOp.Xchg, 1, AtomicOrder.SeqCst) != 0) {}
        return Held{ .mutex = self };
    }
};
