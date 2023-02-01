const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const lib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });
    lib.addCSourceFile("a.c", &.{});
    lib.linkLibC();

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    test_exe.linkLibrary(lib);
    test_exe.linkLibC();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
