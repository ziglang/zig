// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

pub fn Futex(comptime BaseFutex: type) type {
    return struct {
        pub fn now() u64 {
            return BaseFutex.nanotime();
        }

        pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
            if (!BaseFutex.wait(ptr, expect, deadline)) {
                return error.TimedOut;
            }
        }

        pub fn notifyOne(ptr: *const u32) void {
            BaseFutex.wake(ptr, false);
        }

        pub fn notifyAll(ptr: *const u32) void {
            BaseFutex.wake(ptr, true);
        }
    };
}
