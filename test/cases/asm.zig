const config = @import("builtin");
const assert = @import("std").debug.assert;

comptime {
    @export("derp", derp);
    if (config.arch == config.Arch.x86_64 and config.os == config.Os.linux) {
        asm volatile (
            \\.globl my_aoeu_symbol_asdf;
            \\.type my_aoeu_symbol_asdf, @function;
            \\.set my_aoeu_symbol_asdf, derp;
        );
    }
}

test "module level assembly" {
    if (config.arch == config.Arch.x86_64 and config.os == config.Os.linux) {
        assert(my_aoeu_symbol_asdf() == 1234);
    }
}

extern fn my_aoeu_symbol_asdf() -> i32;

extern fn derp() -> i32 {
    return 1234;
}
