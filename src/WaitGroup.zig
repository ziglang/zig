// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const WaitGroup = @This();

lock: std.Thread.Mutex = .{},
cond: std.Thread.Condition = .{},
counter: usize = 0,

pub fn start(self: *WaitGroup) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.counter += 1;
}

pub fn finish(self: *WaitGroup) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.counter -= 1;

    if (self.counter == 0) {
        self.cond.broadcast();
    }
}

pub fn wait(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    while (self.counter == 0) {
        self.cond.wait(held, null) catch unreachable;
    }
}

pub fn reset(self: *WaitGroup) void {
    self.* = .{};
}
