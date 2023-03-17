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
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();

    const check_dylib = dylib.checkObject();
    check_dylib.checkStart("cmd ID_DYLIB");
    check_dylib.checkNext("name @rpath/liba.dylib");
    check_dylib.checkNext("timestamp 2");
    check_dylib.checkNext("current version 10000");
    check_dylib.checkNext("compatibility version 10000");

    test_step.dependOn(&check_dylib.step);

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkSystemLibrary("a");
    exe.addLibraryPathDirectorySource(dylib.getOutputDirectorySource());
    exe.addRPathDirectorySource(dylib.getOutputDirectorySource());
    exe.linkLibC();

    const check_exe = exe.checkObject();
    check_exe.checkStart("cmd LOAD_DYLIB");
    check_exe.checkNext("name @rpath/liba.dylib");
    check_exe.checkNext("timestamp 2");
    check_exe.checkNext("current version 10000");
    check_exe.checkNext("compatibility version 10000");

    check_exe.checkStart("cmd RPATH");
    // TODO check this (perhaps with `checkNextFileSource(dylib.getOutputDirectorySource())`)
    //check_exe.checkNext(std.fmt.allocPrint(b.allocator, "path {s}", .{
    //    b.pathFromRoot("zig-out/lib"),
    //}) catch unreachable);

    const run = check_exe.runAndCompare();
    run.expectStdOutEqual("Hello world");
    test_step.dependOn(&run.step);
}
