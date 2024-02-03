const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const main = b.createModule(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const foo = b.createModule(.{
        .root_source_file = .{ .path = "src/foo.zig" },
    });

    main.addImport("foo", foo);
    foo.addImport("root2", main);

    const exe = b.addExecutable2(.{
        .name = "depend_on_main_mod",
        .root_module = main,
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.expectExitCode(0);

    test_step.dependOn(&run_cmd.step);
}
