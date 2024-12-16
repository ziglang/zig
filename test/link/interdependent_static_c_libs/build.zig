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
    const lib_a = b.addStaticLibrary(.{
        .name = "a",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = optimize,
            .target = b.graph.host,
        }),
    });
    lib_a.root_module.addCSourceFile(.{ .file = b.path("a.c"), .flags = &[_][]const u8{} });
    lib_a.root_module.addIncludePath(b.path("."));

    const lib_b = b.addStaticLibrary(.{
        .name = "b",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = optimize,
            .target = b.graph.host,
        }),
    });
    lib_b.root_module.addCSourceFile(.{ .file = b.path("b.c"), .flags = &[_][]const u8{} });
    lib_b.root_module.addIncludePath(b.path("."));

    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    test_exe.root_module.linkLibrary(lib_a);
    test_exe.root_module.linkLibrary(lib_b);
    test_exe.root_module.addIncludePath(b.path("."));

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
