const expect = @import("std").testing.expect;

usingnamespace @import("foo.zig");
usingnamespace @import("bar.zig");

test "no clobbering happened" {
    @This().foo_function();
    @This().bar_function();
    try expect(@This().saw_foo_function);
    try expect(@This().saw_bar_function);
}
