const std = @import("std");

pub fn build(b: *std.Build) void {
    const config_header = b.addConfigHeader(
        .{ .style = .{ .autoconf_undef = b.path("config.h.in") } },
        .{
            .SOME_NO = null,
            .SOME_TRUE = true,
            .SOME_FALSE = false,
            .SOME_ZERO = 0,
            .SOME_ONE = 1,
            .SOME_TEN = 10,
            .SOME_ENUM = @as(enum { foo, bar }, .foo),
            .SOME_ENUM_LITERAL = .@"test",
            .SOME_STRING = "test",

            .PREFIX_SPACE = null,
            .PREFIX_TAB = null,
            .POSTFIX_SPACE = null,
            .POSTFIX_TAB = null,
        },
    );

    const check_config_header = b.addCheckFile(config_header.getOutput(), .{ .expected_exact = @embedFile("config.h") });

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&check_config_header.step);
}
