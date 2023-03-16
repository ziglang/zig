const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c11"});
    exe.linkLibC();
    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.skip_foreign_checks = true;
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}
