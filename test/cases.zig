const std = @import("std");
const TestContext = @import("../src/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    try @import("compile_errors.zig").addCases(ctx);
    try @import("stage2/cbe.zig").addCases(ctx);
    try @import("stage2/nvptx.zig").addCases(ctx);
}
