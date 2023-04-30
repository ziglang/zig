const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const my_pkg = b.createModule(.{
        .source_file = .{ .path = "pkg.zig" },
    });
    const exe = b.addExecutable(.{
        .name = "test",
        .main_module = b.createModule(.{
            .source_file = .{ .path = "test.zig" },
            .dependencies = &.{
                .{ .name = "my_pkg", .module = my_pkg },
            },
        }),
        .optimize = optimize,
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
