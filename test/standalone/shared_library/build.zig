const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    if (@import("builtin").os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/16959
        return;
    }

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;
    const lib = b.addSharedLibrary(.{
        .name = "mathtest",
        .root_source_file = b.path("mathtest.zig"),
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFile(.{
        .file = b.path("test.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });
    exe.linkLibrary(lib);
    exe.linkSystemLibrary("c");

    const run_cmd = b.addRunArtifact(exe);
    test_step.dependOn(&run_cmd.step);
}
