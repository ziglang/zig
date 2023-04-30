const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const shared = b.createModule(.{
        .source_file = .{ .path = "shared.zig" },
    });

    const foo_mod = b.createModule(.{
        .source_file = .{ .path = "foo.zig" },
        .dependencies = &.{.{ .name = "shared", .module = shared }},
    });

    const exe = b.addExecutable(.{
        .name = "test",
        .main_module = b.createModule(.{
            .source_file = .{ .path = "test.zig" },
            .dependencies = &.{
                .{ .name = "foo", .module = foo_mod },
                .{ .name = "shared", .module = shared },
            },
        }),
        .optimize = optimize,
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
