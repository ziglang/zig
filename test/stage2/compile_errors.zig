const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    try ctx.testCompileError(
        \\export fn entry() void {}
        \\export fn entry() void {}
    , "1.zig", 2, 8, "exported symbol collision: 'entry'");

    try ctx.testCompileError(
        \\fn() void {}
    , "1.zig", 1, 1, "missing function name");
}
