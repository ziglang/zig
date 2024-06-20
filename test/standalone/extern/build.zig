const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject2(.{
        .name = "exports",
        .root_module = b.createModule(.{
            .root_source_file = b.path("exports.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });

    const main = b.addTest2(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
    });
    main.addObject(obj);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
