const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const test_artifact = b.addTest("main.zig");
    test_artifact.addIncludePath("a_directory");

    b.default_step.dependOn(&test_artifact.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&test_artifact.step);
}
