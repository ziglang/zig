// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const condvar = @import("./primitives/Condvar.zig");
const mutex = @import("./primitives/Mutex.zig");
const once = @import("./primitives/Once.zig");
const reset_event = @import("./primitives/ResetEvent.zig");
const rwlock = @import("./primitives/RwLock.zig");
const semaphore = @import("./primitives/Semaphore.zig");
const wait_group = @import("./primitives/WaitGroup.zig");

pub const core = withPrefix("");
pub const debug = withPrefix("Debug");

fn withPrefix(comptime prefix: []const u8) type {
    return struct {
        pub const Condvar = @field(condvar, prefix ++ "Condvar");
        pub const Mutex = @field(mutex, prefix ++ "Mutex");
        pub const Once = @field(once, prefix ++ "Once");
        pub const ResetEvent = @field(reset_event, prefix ++ "ResetEvent");
        // pub const RwLock = @field(rwlock, prefix ++ "RwLock");
        // pub const Semaphore = @field(semaphore, prefix ++ "Semaphore");
        pub const WaitGroup = @field(wait_group, prefix ++ "WaitGroup");
    };
}

pub fn with(comptime Futex: type) type {
    return struct {
        pub const Futex = Futex;
        pub const Condvar = core.Condvar(Futex);
        pub const Mutex = core.Mutex(Futex);
        pub const Once = core.Once(Futex);
        pub const ResetEvent = core.ResetEvent(Futex);
        // pub const RwLock = core.RwLock(Futex);
        // pub const Semaphore = core.Semaphore(Futex);
        pub const WaitGroup = core.WaitGroup(Futex);
    };
}

test "primitives" {
    _ = condvar;
    _ = mutex;
    _ = once;
    _ = reset_event;
    _ = rwlock;
    _ = semaphore;
    _ = wait_group;
}
