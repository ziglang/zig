// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const Event = @This();

lock: std.Mutex = .{},
event: std.ResetEvent = undefined,
state: enum { empty, waiting, notified } = .empty,

pub fn wait(self: *Event) void {
    const held = self.lock.acquire();

    switch (self.state) {
        .empty => {
            self.state = .waiting;
            self.event = @TypeOf(self.event).init();
            held.release();
            self.event.wait();
            self.event.deinit();
        },
        .waiting => unreachable,
        .notified => held.release(),
    }
}

pub fn set(self: *Event) void {
    const held = self.lock.acquire();

    switch (self.state) {
        .empty => {
            self.state = .notified;
            held.release();
        },
        .waiting => {
            held.release();
            self.event.set();
        },
        .notified => unreachable,
    }
}
