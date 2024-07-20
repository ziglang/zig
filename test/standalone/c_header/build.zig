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

    // testcase 2: precompiled header in C, from a generated file, with a compile step generated automaticcaly, twice with a cache hit
    //       and it also test the explicit source lang not inferred from file extenson.
    {
        const exe = b.addExecutable(.{
            .name = "pchtest",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        const generated_header = b.addWriteFiles().add("generated.h",
            \\ /* generated file */
            \\ #include "include_a.h"
        );

        exe.addCSourceFile(.{
            .file = b.path("test.c2"),
            .flags = &[_][]const u8{},
            .lang = .c,
            .precompiled_header = .{ .source_header = .{ .path = generated_header, .lang = .h } },
        });
        exe.addCSourceFiles(.{
            .files = &.{"test.c"},
            .flags = &[_][]const u8{},
            .lang = .c,
            .precompiled_header = .{ .source_header = .{ .path = generated_header, .lang = .h } },
        });

        exe.addIncludePath(b.path("."));

        test_step.dependOn(&b.addRunArtifact(exe).step);
    }

    // testcase 3: precompiled header in C++, from a .h file that must be precompiled as c++, with an explicit pch compile step.
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
            .precompiled_header = .{ .pch_step = pch },
        });

        test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
