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
        .target = target,
        .optimize = optimize,
    });
    dylib.addCSourceFile(.{ .file = .{ .path = "a.c" }, .flags = &.{} });
    dylib.linkLibC();
    b.installArtifact(dylib);

    const exe = b.addExecutable(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &[0][]const u8{} });
    exe.linkLibC();
    exe.root_module.linkSystemLibrary("a", .{ .weak = true });
    exe.addLibraryPath(dylib.getEmittedBinDirectory());
    exe.addRPath(dylib.getEmittedBinDirectory());

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd LOAD_WEAK_DYLIB");
    check.checkExact("name @rpath/liba.dylib");

    check.checkInSymtab();
    check.checkExact("(undefined) weakref external _a (from liba)");

    check.checkInSymtab();
    check.checkExact("(undefined) weakref external _asStr (from liba)");
    test_step.dependOn(&check.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("42 42");
    test_step.dependOn(&run.step);
}
