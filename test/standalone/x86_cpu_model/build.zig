const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const arch = target.result.cpu.arch;
    if (!arch.isX86()) return;

    const abi = target.result.abi;
    if (target.result.ofmt != .elf or !(abi.isMusl() or abi.isGnu())) return;

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
    exe.bundle_compiler_rt = true;

    const check_exe = exe.checkObject();
    check_exe.checkInSymtab();
    check_exe.checkContains("__cpu_model");
    check_exe.checkInSymtab();
    check_exe.checkContains("__cpu_features2");
    check_exe.checkInSymtab();
    check_exe.checkContains("__cpu_indicator_init");
    test_step.dependOn(&check_exe.step);

    const lib = b.addSharedLibrary(.{
        .name = "main-lib",
        .optimize = optimize,
        .target = target,
    });
    lib.linkLibC();
    lib.addCSourceFile(.{
        .file = b.path("main.c"),
        .flags = &.{ "-fvisibility=hidden", "-DNO_MAIN" },
    });
    lib.bundle_compiler_rt = true;

    const check_lib = lib.checkObject();
    check_lib.checkInDynamicSymtab();
    check_lib.checkNotPresent("__cpu_model");
    check_lib.checkInDynamicSymtab();
    check_lib.checkNotPresent("__cpu_features2");
    check_lib.checkInDynamicSymtab();
    check_lib.checkNotPresent("__cpu_indicator_init");
    test_step.dependOn(&check_lib.step);
}
