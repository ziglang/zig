const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // c-header
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
            .file = .{ .path = "include_a.h" },
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

    // c++-header
    {
        const exe = b.addExecutable(.{
            .name = "pchtest++",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        exe.linkLibCpp();

        const pch = b.addPrecompiledCHeader(.{
            .name = "pch_c++",
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }, .{
            .file = .{ .path = "include_a.h" },
            .flags = &[_][]const u8{},
            .lang = .hpp,
        });

        exe.addCSourceFile(.{
            .file = .{ .path = "test.cpp" },
            .flags = &[_][]const u8{},
            .precompiled_header = pch.getEmittedBin(),
        });

        test_step.dependOn(&b.addRunArtifact(exe).step);
    }
}
