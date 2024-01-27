const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // testcase 1: single-file c-header library
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

    // testcase 2: precompiled c-header
    {
        const exe = b.addExecutable(.{
            .name = "pchtest",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        const pch = b.addPrecompiledCHeader(.{
            .name = "pch_c",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }, .{
            .file = b.path("include_a.h"),
            .flags = &[_][]const u8{},
            .lang = .h,
        });

        exe.addCSourceFiles(.{
            .files = &.{"test.c"},
            .flags = &[_][]const u8{},
            .lang = .c,
            .precompiled_header = pch.getEmittedBin(),
        });

        test_step.dependOn(&b.addRunArtifact(exe).step);
    }

    // testcase 3: precompiled c++-header
    {
        const exe = b.addExecutable(.{
            .name = "pchtest++",
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibCpp();

        const pch = b.addPrecompiledCHeader(.{
            .name = "pch_c++",
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }, .{
            .file = b.path("include_a.h"),
            .flags = &[_][]const u8{},
            .lang = .hpp,
        });

        exe.addCSourceFile(.{
            .file = b.path("test.cpp"),
            .flags = &[_][]const u8{},
            .precompiled_header = pch.getEmittedBin(),
        });

        test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
