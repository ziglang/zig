const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const obj = b.addObject(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .target = target,
        .optimize = optimize,
    });

    test_step.dependOn(&obj.step);
}
