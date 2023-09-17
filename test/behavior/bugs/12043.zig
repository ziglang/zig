const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var ok = false;
fn foo(x: anytype) void {
    ok = x;
}
test {
    const x = &foo;
    x(true);
    try expect(ok);
}
