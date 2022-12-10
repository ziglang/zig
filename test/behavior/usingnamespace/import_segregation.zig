const expect = @import("std").testing.expect;
const builtin = @import("builtin");

usingnamespace @import("foo.zig");
usingnamespace @import("bar.zig");

test "no clobbering happened" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    @This().foo_function();
    @This().bar_function();
    try expect(@This().saw_foo_function);
    try expect(@This().saw_bar_function);
}
