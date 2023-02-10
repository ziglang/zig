const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    const dylib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    dylib.addCSourceFile("a.c", &.{});
    dylib.linkLibC();
    dylib.install();

    // -dead_strip_dylibs
    // -needed-la
    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    exe.linkSystemLibraryNeeded("a");
    exe.addLibraryPath(b.pathFromRoot("zig-out/lib"));
    exe.addRPath(b.pathFromRoot("zig-out/lib"));
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject(.macho);
    check.checkStart("cmd LOAD_DYLIB");
    check.checkNext("name @rpath/liba.dylib");

    const run_cmd = check.runAndCompare();
    test_step.dependOn(&run_cmd.step);
}
