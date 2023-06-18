const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var ok = false;
fn foo(x: anytype) void {
    ok = x;
}
test {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const x = &foo;
    x(true);
    try expect(ok);
}
