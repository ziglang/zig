const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject(.{
        .name = "exports",
        .root_source_file = b.path("exports.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    const main = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
    });
    main.addObject(obj);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
