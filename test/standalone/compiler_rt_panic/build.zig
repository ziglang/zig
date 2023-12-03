const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const resolved_target = b.standardTargetOptions(.{});
    const target = resolved_target.target;
    const optimize = b.standardOptimizeOption(.{});

    if (target.ofmt != .elf or !(target.abi.isMusl() or target.abi.isGnu())) return;

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = resolved_target,
    });
    exe.linkLibC();
    exe.addCSourceFile(.{
        .file = .{ .path = "main.c" },
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
