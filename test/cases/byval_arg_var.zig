const std = @import("std");

var result: []const u8 = "wrong";

test "aoeu" {
    start();
    blowUpStack(10);

    std.debug.assert(std.mem.eql(u8, result, "string literal"));
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
