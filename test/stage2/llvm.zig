const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;
const build_options = @import("build_options");

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exeUsingLlvmBackend("simple addition and subtraction", linux_x64);

        case.addCompareOutput(
            \\fn add(a: i32, b: i32) i32 {
            \\    return a + b;
            \\}
            \\
            \\export fn main() c_int {
            \\    var a: i32 = -5;
            \\    const x = add(a, 7);
            \\    var y = add(2, 0);
            \\    y -= x;
            \\    return y;
            \\}
        , "");
    }

    {
        var case = ctx.exeUsingLlvmBackend("hello world", linux_x64);

        case.addCompareOutput(
            \\extern fn puts(s: [*:0]const u8) c_int;
            \\
            \\export fn main() c_int {
            \\    _ = puts("hello world!");
            \\    return 0;
            \\}
        , "hello world!" ++ std.cstr.line_sep);
    }
}
