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
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.addCSourceFile("empty.c", &[0][]const u8{});
    exe.linkLibC();

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.skip_foreign_checks = true;
    run_cmd.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run_cmd.step);
}
