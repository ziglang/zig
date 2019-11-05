const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const time = std.time;
const linux = std.os.linux;
const windows = std.os.windows;

pub const SpinLock = struct {
    lock: u8, // TODO use a bool or enum

    pub const Held = struct {
        spinlock: *SpinLock,

        pub fn release(self: Held) void {
            // TODO: @atomicStore() https://github.com/ziglang/zig/issues/2995
            assert(@atomicRmw(u8, &self.spinlock.lock, .Xchg, 0, .Release) == 1);
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

    pub fn yieldCpu() void {
        switch (builtin.arch) {
            .i386, .x86_64 => asm volatile("pause" ::: "memory"),
            .arm, .aarch64 => asm volatile("yield"),
            else => time.sleep(0),
        }
    }

    pub fn yieldThread() void {
        switch (builtin.os) {
            .linux => assert(linux.syscall0(linux.SYS_sched_yield) == 0),
            .windows => _ = windows.kernel32.SwitchToThread(),
            else => time.sleep(1 * time.microsecond),
        }
    }

    /// Provides a method to incrementally yield longer each time its called.
    pub const Backoff = struct {
        iteration: usize,

        pub fn init() @This() {
            return @This(){ .iteration = 0 };
        }

        /// Hybrid yielding from
        /// http://www.1024cores.net/home/lock-free-algorithms/tricks/spinning
        pub fn yield(self: *@This()) void {
            defer self.iteration +%= 1;
            if (self.iteration < 10) {
                yieldCpu();
            } else if (self.iteration < 20) {
                for (([30]void)(undefined)) |_| yieldCpu();
            } else if (self.iteration < 24) {
                yieldThread();
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
