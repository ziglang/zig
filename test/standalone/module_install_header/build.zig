const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    var module = b.addModule("test_module", .{
        .source_file = .{
            .path = "test_module.zig",
        },
        .dependencies = &.{},
    });
    module.installHeader("include/header.h", "header.h");

    exe.addModule("test_module", module);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(b.getInstallStep());
    b.default_step = test_step;
}
