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
    lib_a.install();

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    test_exe.linkSystemLibrary("a"); // force linking liba.a as -la
    test_exe.addSystemIncludePath(".");
    const search_path = std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "lib" }) catch unreachable;
    test_exe.addLibraryPath(search_path);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_exe.step);
}
