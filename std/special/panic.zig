// This file is the default panic handler if the root source file does not
// have a `pub fn panic`.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

const builtin = @import("builtin");
const std = @import("std");

pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    switch (builtin.os) {
        // TODO: fix panic in zen
        // TODO: fix panic in wasi
        builtin.Os.freestanding, builtin.Os.zen, builtin.Os.wasi => {
            while (true) {}
        },
        builtin.Os.uefi => {
            // TODO look into using the debug info and logging helpful messages
            std.os.abort();
        },
        else => {
            const first_trace_addr = @returnAddress();
            std.debug.panicExtra(error_return_trace, first_trace_addr, "{}", msg);
        },
    }
}
