const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    if (@import("builtin").os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/16959
        return;
    }

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("mathtest.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "mathtest",
        .root_module = lib_mod,
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .linkage = .dynamic,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = null,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe_mod.addCSourceFile(.{
        .file = b.path("test.c"),
        .flags = &.{"-std=c99"},
    });
    exe_mod.linkLibrary(lib);

    const exe = b.addExecutable2(.{
        .name = "test",
        .root_module = exe_mod,
    });

    const run_cmd = b.addRunArtifact(exe);
    test_step.dependOn(&run_cmd.step);
}
