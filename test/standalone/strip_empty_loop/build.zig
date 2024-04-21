const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const optimize = std.builtin.OptimizeMode.Debug;
    const target = b.host;

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
        .target = target,
        .strip = true,
    });

    // TODO: actually check the output
    _ = main.getEmittedBin();

    test_step.dependOn(&main.step);
}
