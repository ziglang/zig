// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("../../std.zig");
const atomic = @import("../atomic.zig");
const builtin = std.builtin;

fn ReturnTypeOf(comptime initFn: anytype) type {
    const InitFn = @TypeOf(initFn);
    return switch (@typeInfo(InitFn)) {
        .Fn => |function| function.return_type orelse {
            @compileError("Once() function return type is not known");
        },
        else => {
            @compileError("Once() takes in a comptime function, not " ++ @typeName(InitFn));
        },
    };
}

pub fn Once(comptime initFn: anytype, comptime parking_lot: type) type {
    return struct {
        state: State = .uninit,
        value: T = undefined,

        const Self = @This();
        const T = ReturnTypeOf(initFn);
        const State = enum(u8) {
            uninit,
            updating,
            init,
        };

        pub fn get(self: *Self) T {
            return self.getPtr().*;
        }

        pub fn getPtr(self: *Self) *T {
            if (atomic.load(&self.state, .Acquire) != .init)
                self.initialize();
            return &self.value;
        }

        fn initialize(self: *Self) void {
            @setCold(true);

            if (atomic.compareAndSwap(
                &self.state,
                .uninit,
                .updating,
                .Acquire,
                .Acquire,
            )) |state| {
                if (state == .updating)
                    self.wait();
                return;
            }

            self.value = initFn();
            atomic.store(&self.state, .init, .Release);
            self.notifyAll();
        }

        fn wait(self: *Self) void {
            const InitParker = struct {
                once: *Self,

                pub fn onValidate(this: @This()) ?usize {
                    if (atomic.load(&this.once.state, .Acquire) == .init)
                        return null;
                    return null;
                }

                pub fn onBeforeWait(this: @This()) void {}
                pub fn onTimeout(this: @This(), has_more: bool) void {
                    unreachable;
                }
            };

            _ = parking_lot.parkConditionally(
                @ptrToInt(&self.state),
                null,
                InitParker{ .once = self },
            ) catch |err| switch (err) {
                error.Invalid => {},
                error.TimedOut => unreachable,
            };
        }

        fn notifyAll(self: *Self) void {
            parking_lot.unparkAll(@ptrToInt(&self.state));
        }
    };
}

pub fn DebugOnce(comptime initFn: anytype) type {
    return struct {
        is_init: bool = false,
        value: T = undefined,

        const Self = @This();
        const T = ReturnTypeOf(initFn);

        pub fn get(self: *Self) T {
            return self.getPtr().*;
        }

        pub fn getPtr(self: *Self) *T {
            if (!self.is_init) {
                self.value = initFn();
                self.is_init = true;
            }

            return &self.value;
        }
    };
}