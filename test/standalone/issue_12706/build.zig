const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.graph.host;
    const optimize: std.builtin.OptimizeMode = .Debug;

    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    main_mod.addCSourceFiles(.{ .files = &.{"test.c"} });

    const exe = b.addExecutable2(.{
        .name = "main",
        .root_module = main_mod,
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.expectExitCode(0);
    run_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_cmd.step);
}
