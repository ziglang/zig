const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .os_tag = .linux,
        .cpu_arch = .x86_64,
    });
    const optimize: std.builtin.OptimizeMode = .Debug;

    const main = b.addTest2(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    main.pie = true;

    const run = b.addRunArtifact(main);
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
