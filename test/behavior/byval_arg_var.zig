const std = @import("std");
const builtin = @import("builtin");

var result: []const u8 = "wrong";

test "pass string literal byvalue to a generic var param" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    start();
    blowUpStack(10);

    try std.testing.expect(std.mem.eql(u8, result, "string literal"));
}

fn start() void {
    foo("string literal");
}

fn foo(x: anytype) void {
    bar(x);
}

fn bar(x: anytype) void {
    result = x;
}

fn blowUpStack(x: u32) void {
    if (x == 0) return;
    blowUpStack(x - 1);
}
