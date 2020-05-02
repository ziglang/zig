const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    try @import("compile_errors.zig").addCases(ctx);
    try @import("compare_output.zig").addCases(ctx);
    @import("zir.zig").addCases(ctx);
}
