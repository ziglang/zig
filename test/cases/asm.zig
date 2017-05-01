const config = @import("builtin");
const assert = @import("std").debug.assert;

comptime {
    if (config.arch == config.Arch.x86_64) {
        asm volatile (
            \\.globl aoeu;
            \\.type aoeu, @function;
            \\.set aoeu, derp;
        );
    }
}

test "module level assembly" {
    if (config.arch == config.Arch.x86_64) {
        assert(aoeu() == 1234);
    }
}

extern fn aoeu() -> i32;

export fn derp() -> i32 {
    return 1234;
}
