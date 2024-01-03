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

    const dylib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile(.{ .file = .{ .path = "a.c" }, .flags = &.{} });
    dylib.linkLibC();

    const check_dylib = dylib.checkObject();
    check_dylib.checkInHeaders();
    check_dylib.checkExact("cmd ID_DYLIB");
    check_dylib.checkExact("name @rpath/liba.dylib");
    check_dylib.checkExact("timestamp 2");
    check_dylib.checkExact("current version 10000");
    check_dylib.checkExact("compatibility version 10000");

    test_step.dependOn(&check_dylib.step);

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &.{} });
    exe.linkSystemLibrary("a");
    exe.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.addRPath(dylib.getEmittedBinDirectory());
    exe.linkLibC();

    const check_exe = exe.checkObject();
    check_exe.checkInHeaders();
    check_exe.checkExact("cmd LOAD_DYLIB");
    check_exe.checkExact("name @rpath/liba.dylib");
    check_exe.checkExact("timestamp 2");
    check_exe.checkExact("current version 10000");
    check_exe.checkExact("compatibility version 10000");

    check_exe.checkInHeaders();
    check_exe.checkExact("cmd RPATH");
    check_exe.checkExactPath("path", dylib.getEmittedBinDirectory());
    test_step.dependOn(&check_exe.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);
}
