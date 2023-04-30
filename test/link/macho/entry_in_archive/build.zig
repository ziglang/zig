const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const lib_mod = b.createModule(.{
        .c_source_files = .{
            .files = &.{"main.c"},
            .flags = &.{},
        },
    });
    const lib = b.addStaticLibrary(.{
        .name = "main",
        .main_module = lib_mod,
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    lib.linkLibC();

    const exe_mod = b.createModule(.{});
    const exe = b.addExecutable(.{
        .name = "main",
        .main_module = exe_mod,
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    exe.linkLibrary(lib);
    exe.linkLibC();

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectExitCode(0);
    test_step.dependOn(&run.step);
}
