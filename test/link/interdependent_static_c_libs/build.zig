const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const lib_a_module = b.createModule(.{
        .c_source_files = .{
            .files = &.{"a.c"},
            .flags = &.{},
        },
    });
    const lib_a = b.addStaticLibrary(.{
        .name = "a",
        .main_module = lib_a_module,
        .optimize = optimize,
        .target = .{},
    });
    lib_a.addIncludePath(".");

    const lib_b_module = b.createModule(.{
        .c_source_files = .{
            .files = &.{"b.c"},
            .flags = &.{},
        },
    });
    const lib_b = b.addStaticLibrary(.{
        .name = "b",
        .main_module = lib_b_module,
        .optimize = optimize,
        .target = .{},
    });
    lib_b.addIncludePath(".");

    const test_mod = b.createModule(.{
        .source_file = .{ .path = "main.zig" },
    });
    const test_exe = b.addTest(.{
        .main_module = test_mod,
        .optimize = optimize,
    });
    test_exe.linkLibrary(lib_a);
    test_exe.linkLibrary(lib_b);
    test_exe.addIncludePath(".");

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
