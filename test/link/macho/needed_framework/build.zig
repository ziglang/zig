const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

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

    const check = exe.checkObject(.macho);
    check.checkStart("cmd LOAD_DYLIB");
    check.checkNext("name {*}Cocoa");
    test_step.dependOn(&check.step);

    const run_cmd = exe.run();
    test_step.dependOn(&run_cmd.step);
}
