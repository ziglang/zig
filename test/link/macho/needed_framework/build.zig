const std = @import("std");

pub const requires_symlinks = true;
pub const requires_macos_sdk = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    // -dead_strip_dylibs
    // -needed_framework Cocoa
    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    exe.linkFrameworkNeeded("Cocoa");
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject();
    check.checkStart("cmd LOAD_DYLIB");
    check.checkNext("name {*}Cocoa");
    test_step.dependOn(&check.step);

    const run_cmd = b.addRunArtifact(exe);
    test_step.dependOn(&run_cmd.step);
}
