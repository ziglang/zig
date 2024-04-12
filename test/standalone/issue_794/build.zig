const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const test_artifact = b.addTest(.{
        .root_source_file = b.path("main.zig"),
    });
    test_artifact.addIncludePath(b.path("a_directory"));

    // TODO: actually check the output
    _ = test_artifact.getEmittedBin();

    test_step.dependOn(&test_artifact.step);
}
