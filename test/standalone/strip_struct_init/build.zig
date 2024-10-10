const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    const main = b.addTest2(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
        }),
    });

    test_step.dependOn(&b.addRunArtifact(main).step);
}
