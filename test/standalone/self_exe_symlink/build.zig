const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.host;

    // The test requires getFdPath in order to to get the path of the
    // File returned by openSelfExe
    if (!std.os.isGetFdPathSupportedOnTarget(target.result.os)) return;

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const create_symlink_exe = b.addExecutable(.{
        .name = "create-symlink",
        .root_source_file = b.path("create-symlink.zig"),
        .optimize = optimize,
        .target = target,
    });

    var run_create_symlink = b.addRunArtifact(create_symlink_exe);
    run_create_symlink.addArtifactArg(main);
    const symlink_path = run_create_symlink.addOutputFileArg("main-symlink");
    run_create_symlink.expectExitCode(0);
    run_create_symlink.skip_foreign_checks = true;

    var run_from_symlink = std.Build.Step.Run.create(b, "run symlink");
    run_from_symlink.addFileArg(symlink_path);
    run_from_symlink.expectExitCode(0);
    run_from_symlink.skip_foreign_checks = true;
    run_from_symlink.step.dependOn(&run_create_symlink.step);

    test_step.dependOn(&run_from_symlink.step);
}
