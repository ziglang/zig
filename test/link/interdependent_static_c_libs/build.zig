const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const lib_a = b.addStaticLibrary(.{
        .name = "a",
        .optimize = optimize,
        .target = .{},
    });
    lib_a.addCSourceFile("a.c", &[_][]const u8{});
    lib_a.addIncludePath(".");

    const lib_b = b.addStaticLibrary(.{
        .name = "b",
        .optimize = optimize,
        .target = .{},
    });
    lib_b.addCSourceFile("b.c", &[_][]const u8{});
    lib_b.addIncludePath(".");

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    test_exe.linkLibrary(lib_a);
    test_exe.linkLibrary(lib_b);
    test_exe.addIncludePath(".");

    test_step.dependOn(&test_exe.run().step);
}
