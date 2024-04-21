const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "depend_on_main_mod",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const foo_module = b.addModule("foo", .{
        .root_source_file = b.path("src/foo.zig"),
    });

    foo_module.addImport("root2", &exe.root_module);
    exe.root_module.addImport("foo", foo_module);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}
