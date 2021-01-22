// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const generic = @import("./generic.zig");

pub usingnamespace generic.Futex(struct {
    const Self = @This();

    pub fn init(self: *Self) void {
        @compileError("TODO");
    }

    pub fn deinit(self: *Self) void {
        @compileError("TODO");
    }

    pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
        @compileError("TODO");
    }

    pub fn set(self: *Self) void {
        @compileError("TODO");
    }

    pub fn reset(self: *Self) void {
        @compileError("TODO");
    }

    pub fn nanotime() u64 {
        @compileError("TODO");
    }

    pub fn yield(iteration: ?usize) bool {
        @compileError("TODO");
    }
});