// This file is the default panic handler if the root source file does not
// have a `pub fn panic`.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

const builtin = @import("builtin");
const std = @import("std");

pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    switch (builtin.os) {
        .freestanding => {
            while (true) {
                @breakpoint();
            }
        },
        .wasi => {
            std.debug.warn("{}", msg);
            _ = std.os.wasi.proc_raise(std.os.wasi.SIGABRT);
            unreachable;
        },
        .uefi => {
            // TODO look into using the debug info and logging helpful messages
            std.os.abort();
        },
        else => {
            const first_trace_addr = @returnAddress();
            std.debug.panicExtra(error_return_trace, first_trace_addr, "{}", msg);
        },
    }
}
