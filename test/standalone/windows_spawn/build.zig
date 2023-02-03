const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const hello = b.addExecutable(.{
        .name = "hello",
        .root_source_file = .{ .path = "hello.zig" },
        .optimize = optimize,
    });

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });

    const run = main.run();
    run.addArtifactArg(hello);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}
