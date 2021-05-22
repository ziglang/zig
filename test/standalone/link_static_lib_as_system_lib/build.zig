const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const lib_a = b.addStaticLibrary("a", null);
    lib_a.addCSourceFile("a.c", &[_][]const u8{});
    lib_a.setBuildMode(mode);
    lib_a.addIncludeDir(".");
    lib_a.install();

    const test_exe = b.addTest("main.zig");
    test_exe.setBuildMode(mode);
    test_exe.linkSystemLibrary("a"); // force linking liba.a as -la
    test_exe.addSystemIncludeDir(".");
    const search_path = std.fs.path.join(b.allocator, &[_][]const u8{ b.install_path, "lib" }) catch unreachable;
    test_exe.addLibPath(search_path);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_exe.step);
}
