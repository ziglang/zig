const std = @import("std");
const TestContext = @import("../src/test.zig").TestContext;

// Self-hosted has differing levels of support for various architectures. For now we pass explicit
// target parameters to each test case. At some point we will take this to the next level and have
// a set of targets that all test cases run on unless specifically overridden. For now, each test
// case applies to only the specified target.

pub fn addCases(ctx: *TestContext) !void {
    try @import("compile_errors.zig").addCases(ctx);
    try @import("stage2/cbe.zig").addCases(ctx);
    try @import("stage2/llvm.zig").addCases(ctx);
    try @import("stage2/plan9.zig").addCases(ctx);
    try @import("stage2/x86_64.zig").addCases(ctx);
    try @import("stage2/sparcv9.zig").addCases(ctx);
    // https://github.com/ziglang/zig/issues/10968
    //try @import("stage2/nvptx.zig").addCases(ctx);
}
