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
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("");

    test_step.dependOn(&run.step);
}
