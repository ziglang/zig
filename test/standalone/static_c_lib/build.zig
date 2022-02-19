const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const foo = b.addStaticLibrary("foo", null);
    foo.addCSourceFile("foo.c", &[_][]const u8{});
    foo.setBuildMode(mode);
    foo.addIncludePath(".");

    const test_exe = b.addTest("foo.zig");
    test_exe.setBuildMode(mode);
    test_exe.linkLibrary(foo);
    test_exe.addIncludePath(".");

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&test_exe.step);
}
