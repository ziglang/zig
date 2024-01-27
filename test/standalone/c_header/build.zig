const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // single-file c-header library
    {
        const exe = b.addExecutable(.{
            .name = "single-file-library",
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        });

        exe.linkLibC();
        exe.addIncludePath(b.path("."));
        exe.addCSourceFile(.{
            .file = b.path("single_file_library.h"),
            .lang = .c,
            .flags = &.{"-DTSTLIB_IMPLEMENTATION"},
        });

        test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
