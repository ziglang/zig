const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const target = b.resolveTargetQuery(.{ .os_tag = .macos });

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &.{} });
    exe.linkLibC();
    exe.stack_size = 0x100000000;

    const check_exe = exe.checkObject();
    check_exe.checkInHeaders();
    check_exe.checkExact("cmd MAIN");
    check_exe.checkExact("stacksize 100000000");
    test_step.dependOn(&check_exe.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("");
    test_step.dependOn(&run.step);
}
