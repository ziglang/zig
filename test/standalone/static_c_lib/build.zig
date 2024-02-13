const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const foo = b.addStaticLibrary(.{
        .name = "foo",
        .optimize = optimize,
        .target = b.host,
    });
    foo.addCSourceFile(.{ .file = .{ .path = "foo.c" }, .flags = &[_][]const u8{} });
    foo.addIncludePath(.{ .path = "." });

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "foo.zig" },
        .optimize = optimize,
    });
    test_exe.linkLibrary(foo);
    test_exe.addIncludePath(.{ .path = "." });

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
