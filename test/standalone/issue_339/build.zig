const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.host;

    const obj = b.addObject(.{
        .name = "test",
        .root_source_file = b.path("test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // TODO: actually check the output
    _ = obj.getEmittedBin();

    test_step.dependOn(&obj.step);
}
