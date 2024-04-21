const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("test.zig"),
        .optimize = optimize,
        .target = b.host,
    });
    exe.root_module.addAnonymousImport("my_pkg", .{ .root_source_file = b.path("pkg.zig") });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
