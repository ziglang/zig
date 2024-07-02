const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    if (builtin.os.tag == .wasi) return;

    const child = b.addExecutable2(.{
        .name = "child",
        .root_module = b.createModule(.{
            .root_source_file = b.path("child.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const main = b.addExecutable2(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run = b.addRunArtifact(main);
    run.addArtifactArg(child);
    run.expectExitCode(0);

    test_step.dependOn(&run.step);
}
