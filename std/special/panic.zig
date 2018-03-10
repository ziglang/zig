// This file is the default panic handler if the root source file does not
// have a `pub fn panic`.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

const builtin = @import("builtin");
const std = @import("std");

pub fn panic(msg: []const u8, error_return_trace: ?&builtin.StackTrace) noreturn {
    @setCold(true);
    switch (builtin.os) {
        // TODO: fix panic in zen.
        builtin.Os.freestanding, builtin.Os.zen => {
            while (true) {}
        },
        else => {
            std.debug.stack_trace_start_address = @ptrToInt(@returnAddress());
            if (error_return_trace) |trace| {
                std.debug.panicWithTrace(trace, "{}", msg);
            }
            std.debug.panic("{}", msg);
        },
    }
}
