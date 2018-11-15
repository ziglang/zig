const config = @import("builtin");
const assert = @import("std").debug.assert;

comptime {
    if (config.arch == config.Arch.x86_64 and config.os == config.Os.linux) {
        asm volatile (
            \\.globl aoeu;
            \\.type aoeu, @function;
            \\.set aoeu, derp;
        );
    }
}

test "module level assembly" {
    if (config.arch == config.Arch.x86_64 and config.os == config.Os.linux) {
        assert(aoeu() == 1234);
    }
}

test "alternative constraints" {
    // Make sure we allow commas as a separator for alternative constraints.
    var a: u32 = 3;
    asm volatile ("" : [_]"=r,m"(a) : [_]"r,m"(a) : "");
}

extern fn aoeu() i32;

export fn derp() i32 {
    return 1234;
}
