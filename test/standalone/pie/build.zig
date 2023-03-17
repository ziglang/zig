const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{
        .os_tag = .linux,
        .cpu_arch = .x86_64,
    };

    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    main.pie = true;

    const run = main.run();
    run.skip_foreign_checks = true;

    test_step.dependOn(&run.step);
}
