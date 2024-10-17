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
    const a_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.graph.host,
        .optimize = optimize,
    });
    a_mod.addIncludePath(b.path("."));
    a_mod.addCSourceFile(.{ .file = b.path("a.c") });

    const b_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.graph.host,
        .optimize = optimize,
    });
    b_mod.addIncludePath(b.path("."));
    b_mod.addCSourceFile(.{ .file = b.path("b.c") });

    const a_lib = b.addStaticLibrary2(.{
        .name = "a",
        .root_module = a_mod,
    });

    const b_lib = b.addStaticLibrary2(.{
        .name = "b",
        .root_module = b_mod,
    });

    const test_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    test_mod.addIncludePath(b.path("."));
    test_mod.linkLibrary(a_lib);
    test_mod.linkLibrary(b_lib);

    const test_exe = b.addTest2(.{
        .root_module = test_mod,
    });

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
