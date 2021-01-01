const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    _ = b.standardReleaseOptions();

    const main = b.addTest("main.zig");

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
