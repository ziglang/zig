const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    if (builtin.os.tag == .wasi) return;

    if (builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/16960
        return;
    }

    const lib = b.addLibrary(.{
        .name = "add",
        .root_module = b.createModule(.{
            .root_source_file = b.path("add.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .linkage = .dynamic,
    });

    const main = b.addExecutable2(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run = b.addRunArtifact(main);
    run.addArtifactArg(lib);
    run.skip_foreign_checks = true;
    run.expectExitCode(0);

    test_step.dependOn(&run.step);
}
