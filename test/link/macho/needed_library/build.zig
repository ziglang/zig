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

    const dylib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile(.{ .file = .{ .path = "a.c" }, .flags = &.{} });
    dylib.linkLibC();

    // -dead_strip_dylibs
    // -needed-la
    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &[0][]const u8{} });
    exe.linkLibC();
    exe.linkSystemLibraryNeeded("a");
    exe.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.addRPath(dylib.getEmittedBinDirectory());
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_DYLIB");
    check.checkExact("name @rpath/liba.dylib");
    test_step.dependOn(&check.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("");
    test_step.dependOn(&run.step);
}
