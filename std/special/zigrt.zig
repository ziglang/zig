// This file contains functions that zig depends on to coordinate between
// multiple .o files. The symbols are defined Weak so that multiple
// instances of zig_rt.zig do not conflict with each other.

const builtin = @import("builtin");

export coldcc fn __zig_panic(message_ptr: &const u8, message_len: usize) -> noreturn {
    @setGlobalLinkage(__zig_panic, builtin.GlobalLinkage.LinkOnce);
    @setDebugSafety(this, false);

    if (builtin.__zig_panic_implementation_provided) {
        @import("@root").panic(message_ptr[0...message_len]);
    } else if (builtin.os == builtin.Os.freestanding) {
        while (true) {}
    } else {
        @import("std").debug.panic("{}", message_ptr[0...message_len]);
    }
}
