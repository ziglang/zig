const std = @import("std");

pub fn build(b: *std.Build) void {
    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
    });

    const run = main.run();
    run.clearEnvironment();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}
