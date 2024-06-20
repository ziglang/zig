const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject2(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    _ = obj.getEmittedAsm();
    b.default_step.dependOn(&obj.step);

    test_step.dependOn(&obj.step);
}
