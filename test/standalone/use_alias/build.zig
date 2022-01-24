const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const main = b.addTest("main.zig");
    main.setBuildMode(b.standardReleaseOptions());
    main.addIncludePath(".");

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
