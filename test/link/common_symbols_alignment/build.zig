const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lib_a = b.addStaticLibrary(.{
        .name = "a",
        .optimize = optimize,
        .target = target,
    });
    lib_a.addCSourceFiles(&.{"a.c"}, &.{"-fcommon"});

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    test_exe.linkLibrary(lib_a);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
