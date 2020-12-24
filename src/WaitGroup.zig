// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const WaitGroup = @This();

lock: std.Mutex = .{},
counter: usize = 0,
event: std.ResetEvent,

pub fn init(self: *WaitGroup) !void {
    self.* = .{
        .lock = .{},
        .counter = 0,
        .event = undefined,
    };
    try self.event.init();
}

pub fn deinit(self: *WaitGroup) void {
    self.event.deinit();
    self.* = undefined;
}

pub fn start(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter += 1;
}

pub fn finish(self: *WaitGroup) void {
    const held = self.lock.acquire();
    defer held.release();

    self.counter -= 1;

    if (self.counter == 0) {
        self.event.set();
    }
}

pub fn wait(self: *WaitGroup) void {
    while (true) {
        const held = self.lock.acquire();

        if (self.counter == 0) {
            held.release();
            return;
        }

        held.release();
        self.event.wait();
    }
}

pub fn reset(self: *WaitGroup) void {
    self.event.reset();
}
