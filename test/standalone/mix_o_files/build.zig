const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    const obj = b.addObject(.{
        .name = "base64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("base64.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = optimize,
            .target = target,
            .link_libc = true,
        }),
    });
    exe.root_module.addCSourceFile(.{
        .file = b.path("test.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });
    exe.root_module.addObject(obj);

    b.default_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    test_step.dependOn(&run_cmd.step);
}
