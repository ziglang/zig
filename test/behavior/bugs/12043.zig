const std = @import("std");
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
