const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    try ctx.testCompareOutputLibC(
        \\extern fn puts([*]const u8) void;
        \\export fn main() c_int {
        \\    puts(c"Hello, world!");
        \\    return 0;
        \\}
    , "Hello, world!" ++ std.cstr.line_sep);
}
