// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const futex = @import("./futex.zig");
const atomic = @import("../atomic.zig");

pub usingnamespace futex.Backend(struct {
    pub fn wait(ptr: *const u32, expect: u32, timeout: ?u64) void {
        atomic.spinLoopHint();
    }

    pub fn wake(ptr: *const u32) void {
        // nothing to wake
    }

    pub fn yield(iteration: ?usize) bool {
        atomic.spinLoopHint();
        return true;
    }
});