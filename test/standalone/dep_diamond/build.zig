const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const shared = b.createModule(.{
        .root_source_file = b.path("shared.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("test.zig"),
        .target = b.host,
        .optimize = optimize,
    });
    exe.root_module.addAnonymousImport("foo", .{
        .root_source_file = b.path("foo.zig"),
        .imports = &.{.{ .name = "shared", .module = shared }},
    });
    exe.root_module.addAnonymousImport("bar", .{
        .root_source_file = b.path("bar.zig"),
        .imports = &.{.{ .name = "shared", .module = shared }},
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
