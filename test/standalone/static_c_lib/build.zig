const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const c_mod = b.createModule(.{
        .root_source_file = null,
        .target = b.graph.host,
        .optimize = optimize,
    });
    c_mod.addIncludePath(b.path("."));
    c_mod.addCSourceFile(.{ .file = b.path("foo.c") });

    const c_lib = b.addStaticLibrary2(.{
        .name = "foo",
        .root_module = c_mod,
    });

    const test_mod = b.createModule(.{
        .root_source_file = b.path("foo.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    test_mod.addIncludePath(b.path("."));
    test_mod.linkLibrary(c_lib);

    const test_exe = b.addTest2(.{
        .root_module = test_mod,
    });

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
