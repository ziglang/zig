const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const arch = target.getCpuArch();
    if (!arch.isX86()) return;

    const abi = target.getAbi();
    if (target.getObjectFormat() != .elf or !(abi.isMusl() or abi.isGnu())) return;

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.linkLibC();
    exe.addCSourceFile(.{
        .file = .{ .path = "main.c" },
        .flags = &.{},
    });
    exe.bundle_compiler_rt = true;

    const check_exe = exe.checkObject();
    check_exe.checkInSymtab();
    check_exe.checkContains("__cpu_model");
    check_exe.checkInSymtab();
    check_exe.checkContains("__cpu_features2");
    check_exe.checkInSymtab();
    check_exe.checkContains("__cpu_indicator_init");
    test_step.dependOn(&check_exe.step);
}
