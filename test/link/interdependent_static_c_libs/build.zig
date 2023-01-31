const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lib_a = b.addStaticLibrary(.{
        .name = "a",
        .optimize = optimize,
        .target = target,
    });
    lib_a.addCSourceFile("a.c", &[_][]const u8{});
    lib_a.addIncludePath(".");

    const lib_b = b.addStaticLibrary(.{
        .name = "b",
        .optimize = optimize,
        .target = target,
    });
    lib_b.addCSourceFile("b.c", &[_][]const u8{});
    lib_b.addIncludePath(".");

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    test_exe.linkLibrary(lib_a);
    test_exe.linkLibrary(lib_b);
    test_exe.addIncludePath(".");

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
