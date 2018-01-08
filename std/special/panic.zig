// This file is the default panic handler if the root source file does not
// have a `pub fn panic`.
// If this file wants to import other files *by name*, support for that would
// have to be added in the compiler.

const builtin = @import("builtin");

pub coldcc fn panic(msg: []const u8) -> noreturn {
    switch (builtin.os) {
        // TODO: fix panic in zen.
        builtin.Os.freestanding, builtin.Os.zen => {
            while (true) {}
        },
        else => {
            @import("std").debug.panic("{}", msg);
        },
    }
}
