const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    const exe = b.addExecutable(.{
        .name = "bss",
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });

    const run = b.addRunArtifact(exe);
    run.expectStdOutEqual("0, 1, 0\n");

    test_step.dependOn(&run.step);
}
