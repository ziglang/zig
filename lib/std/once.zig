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
    const info = @typeInfo(T);
    if (info != .Fn)
        @compileError("expected function type, found " ++ @typeName(T));

    const fn_info = info.Fn;
    if (fn_info.is_generic)
        @compileError("cannot instantiate Once with a generic function");
    if (fn_info.is_var_args)
        @compileError("cannot instantiate Once with a variadic function");

    if (@typeInfo(fn_info.return_type.?) != .Void)
        @compileError("expected function returning void, found " ++ @typeName(T));

    const Args = std.meta.ArgsTuple(T);

    return struct {
        done: bool = false,
        mutex: std.Thread.Mutex = std.Thread.Mutex{},

        /// Call the function `f` with the supplied arguments, use .{} if the
        /// function takes no arguments.
        /// If `call` is invoked multiple times `f` will be executed only the
        /// first time. The arguments are unused for every call but the first
        /// one.
        /// The invocations are thread-safe.
        pub fn call(self: *@This(), args: Args) void {
            if (@atomicLoad(bool, &self.done, .Acquire))
                return;

            return self.callSlow(args);
        }

        fn callSlow(self: *@This(), args: Args) void {
            @setCold(true);

            const mut = self.mutex.acquire();
            defer mut.release();

            // The first thread to acquire the mutex gets to run the initializer
            if (!self.done) {
                @call(.{}, f, args);
                @atomicStore(bool, &self.done, true, .Release);
            }
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
