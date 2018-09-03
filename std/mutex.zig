const std = @import("index.zig");
const builtin = @import("builtin");
const AtomicOrder = builtin.AtomicOrder;
const AtomicRmwOp = builtin.AtomicRmwOp;
const assert = std.debug.assert;
const linux = std.os.linux;

// Reading: Futexes Are Tricky by Ulrich Drepper https://www.akkadia.org/drepper/futex.pdf

// TODO robust mutexes https://www.kernel.org/doc/Documentation/robust-futexes.txt

pub const Mutex = struct {
    // TODO: Windows and OSX with futex equivilents
    // 0: unlocked
    // 1: locked, no waiters
    // 2: locked: one or more waiters
    lock: u32, // futexs are 32-bits on all architectures

    pub const Held = struct {
        mutex: *Mutex,

        pub fn release(self: Held) void {
            if (@atomicRmw(u32, &self.mutex.lock, AtomicRmwOp.Sub, 1, AtomicOrder.Release) != 1) {
                self.mutex.lock = 0;
                if (builtin.os == builtin.Os.linux) {
                    _ = linux.futex_wake(@ptrToInt(&self.mutex.lock), linux.FUTEX_WAKE | linux.FUTEX_PRIVATE_FLAG, 1);
                } else {
                    // spin-lock
                }
            }
        }
    };

    pub fn init() Mutex {
        return Mutex{ .lock = 0 };
    }

    pub fn acquire(self: *Mutex) Held {
        var c: u32 = undefined;
        // This need not be strong because of the loop that follows.
        // TODO implement mutex3 from https://www.akkadia.org/drepper/futex.pdf in x86 assembly.
        if (@cmpxchgWeak(u32, &self.lock, 0, 1, AtomicOrder.Acquire, AtomicOrder.Monotonic)) |value1| {
            c = value1;
            while (true) {
                if (c == 2 or
                    @cmpxchgWeak(u32, &self.lock, 1, 2, AtomicOrder.Acquire, AtomicOrder.Monotonic) == null)
                {
                    if (builtin.os == builtin.Os.linux) {
                        _ = linux.futex_wait(@ptrToInt(&self.lock), linux.FUTEX_WAIT | linux.FUTEX_PRIVATE_FLAG, 2, null);
                    } else {
                        // spin-lock
                    }
                }
                if (@cmpxchgWeak(u32, &self.lock, 0, 2, AtomicOrder.Acquire, AtomicOrder.Monotonic)) |value2| {
                    c = value2;
                } else {
                    break;
                }
            }
        }
        return Held{ .mutex = self };
    }
};
