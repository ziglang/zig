// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");

pub fn now() u64 {
    return 0;
}

pub fn wait(ptr: *const u32, expect: u32, deadline: ?u64) error{TimedOut}!void {
    while (atomic.load(ptr, .SeqCst) == expect) {
        atomic.spinLoopHint();
    }
}

pub fn notifyOne(ptr: *const u32) void {
    // no-op
}

pub fn notifyAll(ptr: *const u32) void {
    // no-op
}
