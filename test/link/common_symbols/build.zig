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
    lib_a.addCSourceFiles(&.{ "c.c", "a.c", "b.c" }, &.{"-fcommon"});

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    test_exe.linkLibrary(lib_a);

    test_step.dependOn(&test_exe.run().step);
}
