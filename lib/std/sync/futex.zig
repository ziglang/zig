// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../std.zig");
const atomic = @import("./atomic.zig");

const builtin = std.builtin;
const testing = std.testing;
const helgrind: ?type = if (builtin.valgrind_support) std.valgrind.helgrind else null;

pub const os = @import("./futex/os.zig");
pub const spin = @import("./futex/spin.zig");
pub const event = @import("./futex/event.zig");
pub const Generic = @import("./futex/generic.zig").Futex;

test "futex" {
    const generic = struct {
        fn forFutex(comptime Futex: type) type {
            return Generic(struct {
                state: State,

                const Self = @This();
                const State = enum(u32){ unset, set };
                
                pub fn init(self: *Self) void {
                    self.state = .unset;
                }

                pub fn deinit(self: *Self) void {
                    if (helgrind) |hg| {
                        hg.annotateHappensBeforeForgetAll(@ptrToInt(self));
                    }

                    self.* = undefined;
                }

                pub fn wait(self: *Self, deadline: ?u64) error{TimedOut}!void {
                    defer if (helgrind) |hg| {
                        hg.annotateHappensAfter(@ptrToInt(self));
                    };

                    while (atomic.load(&self.state, .SeqCst) == .unset) {
                        try Futex.wait(
                            @ptrCast(*const u32, &self.state),
                            @enumToInt(State.unset),
                            deadline,
                        );
                    }
                }

                pub fn set(self: *Self) void {
                    if (helgrind) |hg| {
                        hg.annotateHappensBefore(@ptrToInt(self));
                    }

                    atomic.store(&self.state, .set, .SeqCst);
                    Futex.notifyOne(@ptrCast(*const u32, &self.state));
                }

                pub fn reset(self: *Self) void {
                    self.state = .unset;
                }
            });
        }
    };

    inline for (.{
        .{os},
        .{spin},
        .{event},
        .{generic.forFutex(os)},
        .{generic.forFutex(spin)},
    }) |futex| {
        // @compileError("TODO: test wait/wake/nanotime");
    }
}
