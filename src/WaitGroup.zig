// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const WaitGroup = @This();
const Event = @import("Event.zig");

lock: std.Mutex = .{},
counter: usize = 0,
event: Event = .{},

pub fn start(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter += 1;
}

pub fn stop(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter -= 1;
    if (self.counter == 0)
        self.event.set();
}

pub fn wait(self: *WaitGroup) void {
    while (true) {
        {
            const held = self.lock.acquire();
            defer held.release();

            if (self.counter == 0)
                return;
        }

        self.event.wait();
    }
}
