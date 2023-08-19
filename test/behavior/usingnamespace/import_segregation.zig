const expect = @import("std").testing.expect;
const builtin = @import("builtin");

usingnamespace @import("foo.zig");
usingnamespace @import("bar.zig");

test "no clobbering happened" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    if (builtin.zig_backend == .stage2_llvm and builtin.cpu.arch.isMIPS()) {
        // https://github.com/ziglang/zig/issues/16846
        return error.SkipZigTest;
    }

    @This().foo_function();
    @This().bar_function();
    try expect(@This().saw_foo_function);
    try expect(@This().saw_bar_function);
}
