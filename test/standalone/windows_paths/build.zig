const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    if (builtin.os.tag != .windows) return;

    const relative = b.addExecutable(.{
        .name = "relative",
        .root_module = b.createModule(.{
            .root_source_file = b.path("relative.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const main = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const run = b.addRunArtifact(main);
    run.addArtifactArg(relative);
    run.expectExitCode(0);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
