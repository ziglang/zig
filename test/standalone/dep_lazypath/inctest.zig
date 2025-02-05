const std = @import("std");
const c = @cImport({
    @cInclude("foo.h");
});
comptime {
    std.debug.assert(c.foo_value == 42);
}
pub fn main() void {}
