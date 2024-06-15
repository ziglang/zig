const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const c_sources = [_][]const u8{
        "test.c",
    };
    exe.addCSourceFiles(.{ .files = &c_sources });
    exe.linkLibC();

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.expectExitCode(0);
    run_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_cmd.step);
}
