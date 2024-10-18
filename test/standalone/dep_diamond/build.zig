const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    // Dependency scheme:
    // exe_mod -> foo, bar -> shared

    const shared = b.createModule(.{
        .root_source_file = b.path("shared.zig"),
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("test.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    exe_mod.addAnonymousImport("foo", .{
        .root_source_file = b.path("foo.zig"),
        .imports = &.{.{
            .name = "shared",
            .module = shared,
        }},
    });
    exe_mod.addAnonymousImport("bar", .{
        .root_source_file = b.path("bar.zig"),
        .imports = &.{.{
            .name = "shared",
            .module = shared,
        }},
    });

    const exe = b.addExecutable2(.{
        .name = "test",
        .root_module = exe_mod,
    });

    const run = b.addRunArtifact(exe);
    test_step.dependOn(&run.step);
}
