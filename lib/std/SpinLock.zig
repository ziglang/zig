// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//! A mutually exclusive lock that grinds the CPU rather than interacting with
//! the operating system. It does however yield to the OS scheduler while
//! spinning, when targeting an OS that supports it.
//! This struct can be initialized directly and statically initialized. The
//! default state is unlocked.

state: State = State.Unlocked,

const std = @import("std.zig");
const builtin = @import("builtin");
const SpinLock = @This();

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

test "basic usage" {
    var lock: SpinLock = .{};

    const held = lock.acquire();
    defer held.release();
}
