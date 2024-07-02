const std = @import("std");
const builtin = @import("builtin");

/// This tests the path where DWARF information is embedded in a COFF binary
pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.standardTargetOptions(.{});

    if (builtin.os.tag != .windows) return;

    if (builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/18427
        return;
    }

    const lib_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib_mod.addCSourceFile(.{
        .file = b.path("shared_lib.c"),
        .flags = &.{"-gdwarf"},
    });

    const lib = b.addLibrary(.{
        .name = "shared_lib",
        .root_module = lib_mod,
        .linkage = .dynamic,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.linkLibrary(lib);

    const exe = b.addExecutable2(.{
        .name = "main",
        .root_module = exe_mod,
    });

    const run = b.addRunArtifact(exe);
    run.expectExitCode(0);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
