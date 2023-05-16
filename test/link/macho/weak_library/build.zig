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
        .target = target,
        .optimize = optimize,
    });
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    b.installArtifact(dylib);

    const exe = b.addExecutable(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    exe.linkSystemLibraryWeak("a");
    exe.addLibraryPathDirectorySource(dylib.getOutputDirectorySource());
    exe.addRPathDirectorySource(dylib.getOutputDirectorySource());

    const check = exe.checkObject();
    check.checkStart("cmd LOAD_WEAK_DYLIB");
    check.checkNext("name @rpath/liba.dylib");

    check.checkInSymtab();
    check.checkNext("(undefined) weak external _a (from liba)");

    check.checkInSymtab();
    check.checkNext("(undefined) weak external _asStr (from liba)");

    const run_cmd = check.runAndCompare();
    run_cmd.expectStdOutEqual("42 42");
    test_step.dependOn(&run_cmd.step);
}
