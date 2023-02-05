const std = @import("std");
const builtin = @import("builtin");
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const obj = b.addObject(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    b.default_step.dependOn(&obj.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&obj.step);
}
