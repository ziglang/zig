// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = @import("builtin");

pub const SpinLock = struct {
    state: State,

    const State = enum(u8) {
        Unlocked,
        Locked,
    };

    pub const Held = struct {
        spinlock: *SpinLock,

        pub fn release(self: Held) void {
            @atomicStore(State, &self.spinlock.state, .Unlocked, .Release);
        }
    };

    pub fn init() SpinLock {
        return SpinLock{ .state = .Unlocked };
    }

    pub fn deinit(self: *SpinLock) void {
        self.* = undefined;
    }

    pub fn tryAcquire(self: *SpinLock) ?Held {
        return switch (@atomicRmw(State, &self.state, .Xchg, .Locked, .Acquire)) {
            .Unlocked => Held{ .spinlock = self },
            .Locked => null,
        };
    }

    pub fn acquire(self: *SpinLock) Held {
        while (true) {
            return self.tryAcquire() orelse {
                yield();
                continue;
            };
        }
    }

    pub fn yield() void {
        // On native windows, SwitchToThread is too expensive,
        // and yielding for 380-410 iterations was found to be
        // a nice sweet spot. Posix systems on the other hand,
        // especially linux, perform better by yielding the thread.
        switch (builtin.os.tag) {
            .windows => loopHint(400),
            else => std.os.sched_yield() catch loopHint(1),
        }
    }

    /// Hint to the cpu that execution is spinning
    /// for the given amount of iterations.
    pub fn loopHint(iterations: usize) void {
        var i = iterations;
        while (i != 0) : (i -= 1) {
            switch (builtin.arch) {
                // these instructions use a memory clobber as they
                // flush the pipeline of any speculated reads/writes.
                .i386, .x86_64 => asm volatile ("pause"
                    :
                    :
                    : "memory"
                ),
                .arm, .aarch64 => asm volatile ("yield"
                    :
                    :
                    : "memory"
                ),
                else => std.os.sched_yield() catch {},
            }
        }
    }
};

test "spinlock" {
    var lock = SpinLock.init();
    defer lock.deinit();

    const held = lock.acquire();
    defer held.release();
}
