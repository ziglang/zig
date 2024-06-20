const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    const main = b.addExecutable2(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
        }),
    });

    // TODO: actually check the output
    _ = main.getEmittedBin();

    test_step.dependOn(&main.step);
}
