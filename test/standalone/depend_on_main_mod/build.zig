const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const foo_mod = b.addModule("foo", .{
        .root_source_file = b.path("src/foo.zig"),
    });

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Make `main_mod` depend on itself through foo
    foo_mod.addImport("root2", main_mod);
    main_mod.addImport("foo", foo_mod);

    const exe = b.addExecutable2(.{
        .name = "depend_on_main_mod",
        .root_module = main_mod,
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}
