// This file is the default panic handler if the root source file does not
// have a `pub fn panic`.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

const builtin = @import("builtin");
const std = @import("std");

pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    const stderr = std.io.getStdErr() catch std.process.abort();
    stderr.write("panic: ") catch std.process.abort();
    stderr.write(msg) catch std.process.abort();
    std.process.abort();
}
