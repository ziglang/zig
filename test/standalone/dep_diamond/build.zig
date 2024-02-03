const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const main = b.createModule(.{
        .root_source_file = .{ .path = "test.zig" },
        .target = b.host,
        .optimize = optimize,
    });
    const foo = b.createModule(.{
        .root_source_file = .{ .path = "foo.zig" },
    });
    const bar = b.createModule(.{
        .root_source_file = .{ .path = "foo.zig" },
    });
    const shared = b.createModule(.{
        .root_source_file = .{ .path = "shared.zig" },
    });

    main.addImport("foo", foo);
    main.addImport("bar", bar);
    foo.addImport("shared", shared);
    bar.addImport("shared", shared);

    const exe = b.addExecutable2(.{
        .name = "test",
        .root_module = main,
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
