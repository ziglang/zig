const std = @import("std");

var result: []const u8 = "wrong";

test "pass string literal byvalue to a generic var param" {
    start();
    blowUpStack(10);

    std.testing.expect(std.mem.eql(u8, result, "string literal"));
}

fn start() void {
    foo("string literal");
}

fn foo(x: var) void {
    bar(x);
}

fn bar(x: var) void {
    result = x;
}

fn blowUpStack(x: u32) void {
    if (x == 0) return;
    blowUpStack(x - 1);
}
