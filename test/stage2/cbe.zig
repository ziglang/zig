const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    // These tests should work on every platform
    ctx.c11("empty start function", linux_x64,
        \\export fn start() void {}
    ,
        \\void start(void) {}
    );
}
