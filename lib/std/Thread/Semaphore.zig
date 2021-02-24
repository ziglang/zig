// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! A semaphore is an unsigned integer that blocks the kernel thread if
//! the number would become negative.
//! This API supports static initialization and does not require deinitialization.

mutex: Mutex = .{},
cond: Condition = .{},
//! It is OK to initialize this field to any value.
permits: usize = 0,

const Semaphore = @This();
const std = @import("../std.zig");
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;

pub fn wait(sem: *Semaphore) void {
    const held = sem.mutex.acquire();
    defer held.release();

    while (sem.permits == 0)
        sem.cond.wait(&sem.mutex);

    sem.permits -= 1;
    if (sem.permits > 0)
        sem.cond.signal();
}

pub fn post(sem: *Semaphore) void {
    const held = sem.mutex.acquire();
    defer held.release();

    sem.permits += 1;
    sem.cond.signal();
}
