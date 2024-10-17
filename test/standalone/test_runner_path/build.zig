const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const test_exe = b.addTest2(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = b.graph.host,
        }),
        .test_runner = b.path("test_runner.zig"),
    });

    const test_run = b.addRunArtifact(test_exe);
    test_step.dependOn(&test_run.step);
}
