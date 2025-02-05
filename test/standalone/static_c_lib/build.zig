const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const foo = b.addLibrary(.{
        .linkage = .static,
        .name = "foo",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = optimize,
            .target = b.graph.host,
        }),
    });
    foo.root_module.addCSourceFile(.{ .file = b.path("foo.c"), .flags = &[_][]const u8{} });
    foo.root_module.addIncludePath(b.path("."));

    const test_exe = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("foo.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    }) });
    test_exe.root_module.linkLibrary(foo);
    test_exe.root_module.addIncludePath(b.path("."));

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
