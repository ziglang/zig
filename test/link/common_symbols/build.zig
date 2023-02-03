const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const lib_a = b.addStaticLibrary(.{
        .name = "a",
        .optimize = optimize,
        .target = .{},
    });
    lib_a.addCSourceFiles(&.{ "c.c", "a.c", "b.c" }, &.{"-fcommon"});

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    test_exe.linkLibrary(lib_a);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
