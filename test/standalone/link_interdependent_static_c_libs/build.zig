const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const lib_a = b.addStaticLibrary("a", null);
    lib_a.addCSourceFile("a.c", &[_][]const u8{});
    lib_a.setBuildMode(mode);
    lib_a.addIncludeDir(".");

    const lib_b = b.addStaticLibrary("b", null);
    lib_b.addCSourceFile("b.c", &[_][]const u8{});
    lib_b.setBuildMode(mode);
    lib_b.addIncludeDir(".");

    const test_exe = b.addTest("main.zig");
    test_exe.setBuildMode(mode);
    test_exe.linkLibrary(lib_a);
    test_exe.linkLibrary(lib_b);
    test_exe.addIncludeDir(".");

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
