const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const foo = b.addStaticLibrary(.{
        .name = "foo",
        .optimize = optimize,
        .target = .{},
    });
    foo.addCSourceFile("foo.c", &[_][]const u8{});
    foo.addIncludePath(".");

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "foo.zig" },
        .optimize = optimize,
    });
    test_exe.linkLibrary(foo);
    test_exe.addIncludePath(".");

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
