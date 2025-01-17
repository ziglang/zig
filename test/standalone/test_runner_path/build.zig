const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const test_exe = b.addTest(.{ .root_module = b.createModule(.{
        .target = b.graph.host,
        .root_source_file = b.path("test.zig"),
    }) });
    test_exe.test_runner = b.path("test_runner.zig");

    const test_run = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_run.step);
}
