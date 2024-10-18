const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject2(.{
        .name = "base64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("base64.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addCSourceFile(.{
        .file = b.path("test.c"),
        .flags = &.{"-std=c99"},
    });
    mod.addObject(obj);

    const exe = b.addExecutable2(.{
        .name = "test",
        .root_module = mod,
    });

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    test_step.dependOn(&run_cmd.step);
}
