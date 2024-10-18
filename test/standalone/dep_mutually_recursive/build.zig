const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const foo = b.createModule(.{
        .root_source_file = b.path("foo.zig"),
    });
    const bar = b.createModule(.{
        .root_source_file = b.path("bar.zig"),
        .imports = &.{
            .{
                .name = "foo",
                .module = foo,
            },
        },
    });
    // Make it mutually recursive:
    foo.addImport("bar", bar);

    const exe = b.addExecutable2(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = b.graph.host,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "foo",
                    .module = foo,
                },
            },
        }),
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
