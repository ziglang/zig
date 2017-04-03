// This file contains functions that zig depends on to coordinate between
// multiple .o files. The symbols are defined Weak so that multiple
// instances of zig_rt.zig do not conflict with each other.

export coldcc fn __zig_panic(message_ptr: &const u8, message_len: usize) -> noreturn {
    @setGlobalLinkage(__zig_panic, GlobalLinkage.Weak);
    @setDebugSafety(this, false);

    if (@compileVar("panic_implementation_provided")) {
        @import("@root").panic(message_ptr[0...message_len]);
    } else if (@compileVar("os") == Os.freestanding) {
        while (true) {}
    } else {
        @import("std").debug.panic("{}", message_ptr[0...message_len]);
    }
}
