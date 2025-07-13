const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    exe.addCSourceFile(.{
        .file = b.path("test.c"),
        .flags = &.{"-std=c23"},
    });
    exe.linkLibC();
    exe.addEmbedPath(b.path("data"));

    const run_c_cmd = b.addRunArtifact(exe);
    run_c_cmd.expectExitCode(0);
    run_c_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_c_cmd.step);
}
