// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const WaitGroup = @This();

lock: std.Mutex = .{},
counter: usize = 0,
event: ?*std.ResetEvent = null,

pub fn start(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter += 1;
}

pub fn stop(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter -= 1;

    if (self.counter == 0) {
        if (self.event) |event| {
            self.event = null;
            event.set();
        }
    }
}

pub fn wait(self: *WaitGroup) void {
    const held = self.lock.acquire();

    if (self.counter == 0) {
        held.release();
        return;
    }

    var event = std.ResetEvent.init();
    defer event.deinit();

    std.debug.assert(self.event == null);
    self.event = &event;

    held.release();
    event.wait();
}
