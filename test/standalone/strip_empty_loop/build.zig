const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const optimize = std.builtin.OptimizeMode.Debug;
    const target = std.zig.CrossTarget{};

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    main.strip = true;
    test_step.dependOn(&main.step);
}
