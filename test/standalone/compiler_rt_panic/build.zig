const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.ofmt != .elf or !(target.result.abi.isMusl() or target.result.abi.isGnu()))
        return;

    const mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addCSourceFile(.{
        .file = b.path("main.c"),
        .flags = &.{},
    });

    const exe = b.addExecutable2(.{
        .name = "main",
        .root_module = mod,
    });
    exe.link_gc_sections = false;
    exe.bundle_compiler_rt = true;

    // Verify compiler_rt hasn't pulled in any debug handlers
    const check_exe = exe.checkObject();
    check_exe.checkInSymtab();
    check_exe.checkNotPresent("debug.readElfDebugInfo");
    test_step.dependOn(&check_exe.step);
}
