const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.graph.host;

    const obj1 = b.addStaticLibrary(.{
        .name = "obj1",
        .root_module = b.createModule(.{
            .root_source_file = b.path("obj1.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const obj2 = b.addStaticLibrary(.{
        .name = "obj2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("obj2.zig"),
            .optimize = optimize,
            .target = target,
        }),
    });

    const main_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });
    main_mod.linkLibrary(obj1);
    main_mod.linkLibrary(obj2);

    const main = b.addTest(.{ .root_module = main_mod });
    test_step.dependOn(&b.addRunArtifact(main).step);
}
