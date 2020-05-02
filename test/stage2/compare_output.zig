const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    // TODO: re-enable these tests.
    // https://github.com/ziglang/zig/issues/1364

    //// hello world
    //try ctx.testCompareOutputLibC(
    //    \\extern fn puts([*]const u8) void;
    //    \\pub export fn main() c_int {
    //    \\    puts("Hello, world!");
    //    \\    return 0;
    //    \\}
    //, "Hello, world!" ++ std.cstr.line_sep);

    //// function calling another function
    //try ctx.testCompareOutputLibC(
    //    \\extern fn puts(s: [*]const u8) void;
    //    \\pub export fn main() c_int {
    //    \\    return foo("OK");
    //    \\}
    //    \\fn foo(s: [*]const u8) c_int {
    //    \\    puts(s);
    //    \\    return 0;
    //    \\}
    //, "OK" ++ std.cstr.line_sep);
}
