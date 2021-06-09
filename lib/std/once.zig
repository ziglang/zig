// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = std.builtin;
const testing = std.testing;

pub fn once(comptime f: anytype) Once(f) {
    return Once(f){};
}

/// An object that executes the function `f` just once.
pub fn Once(comptime f: anytype) type {
    const T = @TypeOf(f);
    const ty_info = @typeInfo(T);
    if (ty_info != .Fn)
        @compileError("expected function type, found " ++ @typeName(T));

    const fn_info = ty_info.Fn;
    if (fn_info.is_generic)
        @compileError("cannot instantiate Once with a generic function");
    if (fn_info.is_var_args)
        @compileError("cannot instantiate Once with a variadic function");

    // The return type must be void or !void.
    const Return = fn_info.return_type.?;
    if (!switch (@typeInfo(Return)) {
        .Void => true,
        .ErrorUnion => |info| info.payload == void,
        else => false,
    }) {
        @compileError("expected function returning void or !void, found " ++ @typeName(T));
    }

    const Args = std.meta.ArgsTuple(T);

    // The field order minimizes the amount of space wasted to padding.
    return struct {
        mutex: std.Thread.Mutex = std.Thread.Mutex{},
        done: std.atomic.Atomic(bool) = std.atomic.Atomic(bool).init(false),
        err_val: Return = undefined,

        /// Call the function `f` with the supplied arguments, use .{} if the
        /// function takes no arguments.
        /// If `call` is invoked multiple times `f` will be executed only the
        /// first time. The arguments are unused for every call but the first
        /// one.
        /// If `f` returns an error the initialization is marked as done and,
        /// for every following call, the same error value is returned.
        /// The invocations are thread-safe.
        pub fn call(self: *@This(), args: Args) Return {
            if (self.done.load(.Acquire))
                return self.err_val;

            return self.callSlow(args);
        }

        fn callSlow(self: *@This(), args: Args) Return {
            @setCold(true);

            const mut = self.mutex.acquire();
            defer mut.release();

            // The first thread to acquire the mutex gets to run the initializer
            if (!self.done.loadUnchecked()) {
                self.err_val = @call(.{}, f, args);
                self.done.store(true, .Release);
            }

            return self.err_val;
        }
    };
}

var global_number: i32 = 0;
var global_once = once(incr);

fn incr(x: i32) void {
    global_number += x;
}

test "Once executes its function just once" {
    if (builtin.single_threaded) {
        global_once.call(.{1});
        global_once.call(.{1});
    } else {
        var threads: [4]*std.Thread = undefined;
        defer for (threads) |handle| handle.wait();

        for (threads) |*handle| {
            handle.* = try std.Thread.spawn(struct {
                fn thread_fn(x: u8) void {
                    global_once.call(.{x});
                }
            }.thread_fn, 1);
        }
    }

    try testing.expectEqual(@as(i32, 1), global_number);
}

fn fn_fail() !void {
    return error.OhNo;
}

var fail_once = once(fn_fail);

test "Once executes its function just once" {
    if (builtin.single_threaded) {
        try testing.expectError(error.OhNo, fail_once.call(.{}));
        try testing.expectError(error.OhNo, fail_once.call(.{}));
    } else {
        var threads: [4]*std.Thread = undefined;
        defer for (threads) |handle| handle.wait();

        for (threads) |*handle| {
            handle.* = try std.Thread.spawn(struct {
                fn thread_fn(x: u8) !void {
                    try testing.expectError(error.OhNo, fail_once.call(.{}));
                }
            }.thread_fn, 1);
        }
    }
}
