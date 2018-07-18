const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    try ctx.testCompileError(
        \\export fn entry() void {}
        \\export fn entry() void {}
    , "1.zig", 2, 8, "exported symbol collision: 'entry'");

    try ctx.testCompileError(
        \\fn() void {}
    , "1.zig", 1, 1, "missing function name");

    try ctx.testCompileError(
        \\comptime {
        \\    return;
        \\}
    , "1.zig", 2, 5, "return expression outside function definition");

    try ctx.testCompileError(
        \\export fn entry() void {
        \\    defer return;
        \\}
    , "1.zig", 2, 11, "cannot return from defer expression");
}
