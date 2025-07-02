const std = @import("std");
const builtin = @import("builtin");

/// This tests the path where DWARF information is embedded in a COFF binary
pub fn build(b: *std.Build) void {
    switch (builtin.cpu.arch) {
        .aarch64,
        .x86,
        .x86_64,
        => {},
        else => return,
    }

    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = if (builtin.os.tag == .windows)
        b.standardTargetOptions(.{})
    else
        b.resolveTargetQuery(.{ .os_tag = .windows });

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "shared_lib",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = optimize,
            .target = target,
            .link_libc = true,
        }),
    });
    lib.root_module.addCSourceFile(.{ .file = b.path("shared_lib.c"), .flags = &.{"-gdwarf"} });
    exe.root_module.linkLibrary(lib);

    const run = b.addRunArtifact(exe);
    run.expectExitCode(0);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
