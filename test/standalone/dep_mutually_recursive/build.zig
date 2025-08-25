const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const main_mod = b.createModule(.{
        .root_source_file = b.path("test.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    const foo_mod = b.createModule(.{
        .root_source_file = b.path("foo.zig"),
    });
    const bar_mod = b.createModule(.{
        .root_source_file = b.path("bar.zig"),
    });

    main_mod.addImport("foo", foo_mod);
    foo_mod.addImport("bar", bar_mod);
    bar_mod.addImport("foo", foo_mod);

    const exe = b.addExecutable(.{
        .name = "test",
        .root_module = main_mod,
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
