const std = @import("std");
const builtin = @import("builtin");

pub const requires_symlinks = true;
pub const requires_macos_sdk = false;

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
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &[0][]const u8{} });
    switch (builtin.cpu.arch) {
        .aarch64 => {
            exe.addCSourceFile(.{ .file = .{ .path = "a_arm64.s" }, .flags = &[0][]const u8{} });
        },
        .x86_64 => {
            exe.addCSourceFile(.{ .file = .{ .path = "a_x64.s" }, .flags = &[0][]const u8{} });
        },
        else => unreachable,
    }
    exe.linkLibC();

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("4\n");

    test_step.dependOn(&run.step);
}
