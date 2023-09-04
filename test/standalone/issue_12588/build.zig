const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const obj = b.addObject(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    _ = obj.getEmittedLlvmIr();
    _ = obj.getEmittedLlvmBc();
    b.default_step.dependOn(&obj.step);

    test_step.dependOn(&obj.step);
}
