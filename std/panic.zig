// This file is included if and only if the user's main source file does not
// include a public panic function.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

pub coldcc fn panic(message: []const u8) -> unreachable {
    if (@compileVar("os") == Os.freestanding) {
        while (true) {}
    } else {
        @import("std").debug.panic(message);
    }
}
