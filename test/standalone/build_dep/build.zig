const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.host;
    const optimize = .Debug;

    const test_step = b.step("test", "Test it");

    const dependency = b.dependency("dep", .{});

    const dep_main1 = dependency.artifact("main1");
    const dep_main1_run = b.addRunArtifact(dep_main1);

    const dep_main2 = b.addExecutable(.{
        .name = "main2",
        .root_source_file = dependency.path("main2.zig"),
        .target = target,
        .optimize = optimize,
    });
    const dep_main2_run = b.addRunArtifact(dep_main2);

    const dep_main3 = b.addExecutable(.{
        .name = "main3",
        .root_source_file = b.path("main3.zig"),
        .target = target,
        .optimize = optimize,
    });
    dep_main3.root_module.addImport("dep_root", dependency.module("root"));
    const dep_main3_run = b.addRunArtifact(dep_main3);

    test_step.dependOn(&dep_main1_run.step);
    test_step.dependOn(&dep_main2_run.step);
    test_step.dependOn(&dep_main3_run.step);
}
