// This file is the default panic handler if the root source file does not
// have a `pub fn panic`.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

const builtin = @import("builtin");
const std = @import("std");

pub coldcc fn panic(msg: []const u8, error_return_trace: ?&builtin.StackTrace) -> noreturn {
    switch (builtin.os) {
        // TODO: fix panic in zen.
        builtin.Os.freestanding, builtin.Os.zen => {
            while (true) {}
        },
        else => {
            if (builtin.have_error_return_tracing) {
                if (error_return_trace) |trace| {
                    std.debug.warn("{}\n", msg);
                    std.debug.dumpStackTrace(trace);
                    @import("std").debug.panic("");
                }
            }
            @import("std").debug.panic("{}", msg);
        },
    }
}
