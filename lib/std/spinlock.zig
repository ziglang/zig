const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const time = std.time;
const os = std.os;

pub const SpinLock = struct {
    lock: u8, // TODO use a bool or enum

    pub const Held = struct {
        spinlock: *SpinLock,

        pub fn release(self: Held) void {
            @atomicStore(u8, &self.spinlock.lock, 0, .Release);
        }
    };

    pub fn init() SpinLock {
        return SpinLock{ .lock = 0 };
    }

    pub fn acquire(self: *SpinLock) Held {
        var backoff = Backoff.init();
        while (@atomicRmw(u8, &self.lock, .Xchg, 1, .Acquire) != 0)
            backoff.yield();
        return Held{ .spinlock = self };
    }

    pub fn yield(iterations: usize) void {
        var i = iterations;
        while (i != 0) : (i -= 1) {
            switch (builtin.arch) {
                .i386, .x86_64 => asm volatile ("pause"),
                .arm, .aarch64 => asm volatile ("yield"),
                else => time.sleep(0),
            }
        }
    }

    /// Provides a method to incrementally yield longer each time its called.
    pub const Backoff = struct {
        iteration: usize,

        pub fn init() @This() {
            return @This(){ .iteration = 0 };
        }

        /// Modified hybrid yielding from
        /// http://www.1024cores.net/home/lock-free-algorithms/tricks/spinning
        pub fn yield(self: *@This()) void {
            defer self.iteration +%= 1;
            if (self.iteration < 20) {
                SpinLock.yield(self.iteration);
            } else if (self.iteration < 24) {
                os.sched_yield() catch time.sleep(1);
            } else if (self.iteration < 26) {
                time.sleep(1 * time.millisecond);
            } else {
                time.sleep(10 * time.millisecond);
            }
        }
    };
};

test "spinlock" {
    var lock = SpinLock.init();
    const held = lock.acquire();
    defer held.release();
}
