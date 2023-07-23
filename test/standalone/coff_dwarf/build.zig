const std = @import("std");
const builtin = @import("builtin");

/// This tests the path where DWARF information is embedded in a COFF binary
pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.standardTargetOptions(.{});

    if (builtin.os.tag != .windows) return;

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const lib = b.addSharedLibrary(.{
        .name = "shared_lib",
        .optimize = optimize,
        .target = target,
    });
    lib.addCSourceFile("shared_lib.c", &.{"-gdwarf"});
    lib.linkLibC();
    exe.linkLibrary(lib);

    const run = b.addRunArtifact(exe);
    run.expectExitCode(0);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
