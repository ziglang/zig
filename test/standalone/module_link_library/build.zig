const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .optimize = optimize,
    });
    const lib = b.addStaticLibrary(.{
        .name = "lib",
        .target = .{},
        .optimize = optimize,
    });
    lib.addIncludePath("lib");
    lib.addCSourceFile("lib/lib.c", &.{""});

    var module = b.addModule("test_module", .{
        .source_file = .{
            .path = "test_module.zig",
        },
        .dependencies = &.{},
    });
    module.addIncludePath("lib");
    module.linkLibrary(lib);

    exe.addModule("test_module", module);

    const run = b.addRunArtifact(exe);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}
