const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    const dylib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .target = target,
        .optimize = optimize,
    });
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.install();

    const exe = b.addExecutable(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    exe.linkSystemLibraryWeak("a");
    exe.addLibraryPath(b.pathFromRoot("zig-out/lib"));
    exe.addRPath(b.pathFromRoot("zig-out/lib"));

    const check = exe.checkObject(.macho);
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
