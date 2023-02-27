const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const foo = @import("foo");

pub fn main() void {
    std.debug.assert(root == @This());
    std.debug.assert(std == foo.std);
    std.debug.assert(builtin == foo.builtin);
    std.debug.assert(root == foo.root);
}
