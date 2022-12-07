const std = @import("std");
const builtin = @import("builtin");

fn foo() u32 {
    return 11227;
}
const bar = foo;
test "pointer to alias behaves same as pointer to function" {
    var a = &bar;
    try std.testing.expect(foo() == a());
}
