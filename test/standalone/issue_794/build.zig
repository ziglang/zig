const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const test_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
    });
    test_mod.addIncludePath(b.path("a_directory"));

    const test_artifact = b.addTest2(.{
        .root_module = test_mod,
    });

    // TODO: actually check the output
    _ = test_artifact.getEmittedBin();

    test_step.dependOn(&test_artifact.step);
}
