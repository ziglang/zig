const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.ofmt != .elf or !(target.result.abi.isMusl() or target.result.abi.isGnu()))
        return;

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.linkLibC();
    exe.addCSourceFile(.{
        .file = b.path("main.c"),
        .flags = &.{},
    });
    exe.link_gc_sections = false;
    exe.bundle_compiler_rt = true;

    // Verify compiler_rt hasn't pulled in any debug handlers
    const check_exe = exe.checkObject();
    check_exe.checkInSymtab();
    check_exe.checkNotPresent("debug.readElfDebugInfo");
    test_step.dependOn(&check_exe.step);
}
