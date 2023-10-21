const std = @import("std");
const builtin = @import("builtin");

const Foo = struct {
    free: bool,

    pub const FooError = error{NotFree};
};

var foo = Foo{ .free = true };
var default_foo: ?*Foo = null;

fn get_foo() Foo.FooError!*Foo {
    if (foo.free) {
        foo.free = false;
        return &foo;
    }
    return error.NotFree;
}

test "fixed" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    default_foo = get_foo() catch null; // This Line
    try std.testing.expect(!default_foo.?.free);
}
