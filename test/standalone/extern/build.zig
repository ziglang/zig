const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject(.{
        .name = "exports",
        .root_module = b.createModule(.{
            .root_source_file = b.path("exports.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    const shared = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "shared",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = b.graph.host,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    if (b.graph.host.result.abi == .msvc) shared.root_module.addCMacro("API", "__declspec(dllexport)");
    shared.root_module.addCSourceFile(.{ .file = b.path("shared.c"), .flags = &.{} });
    const test_exe = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    }) });
    test_exe.addObject(obj);
    test_exe.linkLibrary(shared);

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
