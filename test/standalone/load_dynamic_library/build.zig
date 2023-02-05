const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "add",
        .root_source_file = .{ .path = "add.zig" },
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const run = main.run();
    run.addArtifactArg(lib);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&run.step);
}
