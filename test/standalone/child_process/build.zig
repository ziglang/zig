const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    if (builtin.os.tag == .wasi) return;

    const child = b.addExecutable(.{
        .name = "child",
        .root_module = b.createModule(.{
            .root_source_file = b.path("child.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const main = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });
    const run = b.addRunArtifact(main);
    run.addArtifactArg(child);
    run.expectExitCode(0);

    // Use a temporary directory within the cache as the CWD to test
    // spawning the child using a path that contains a leading `..` component.
    const run_relative = b.addRunArtifact(main);
    run_relative.addArtifactArg(child);
    const write_tmp_dir = b.addWriteFiles();
    const tmp_cwd = write_tmp_dir.getDirectory();
    run_relative.addDirectoryArg(tmp_cwd);
    run_relative.setCwd(tmp_cwd);
    run_relative.expectExitCode(0);

    test_step.dependOn(&run.step);
    test_step.dependOn(&run_relative.step);
}
