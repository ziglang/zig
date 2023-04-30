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
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const lib_mod = b.createModule(.{});
    const lib = b.addSharedLibrary(.{
        .name = "a",
        .main_module = lib_mod,
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    lib.addCSourceFile("a.c", &.{});
    lib.linkLibC();

    const test_mod = b.createModule(.{
        .source_file = .{ .path = "main.zig" },
    });
    const test_exe = b.addTest(.{
        .main_module = test_mod,
        .optimize = optimize,
        .target = target,
    });
    test_exe.linkLibrary(lib);
    test_exe.linkLibC();

    const run = b.addRunArtifact(test_exe);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
