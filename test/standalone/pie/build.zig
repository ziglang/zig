const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const main = b.addTest("main.zig");
    main.setBuildMode(b.standardReleaseOptions());
    main.pie = true;

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&main.step);

    b.default_step.dependOn(test_step);
}
