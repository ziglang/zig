const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

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

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
