const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const obj = b.addStaticLibrary("obj", "obj.zig");
    obj.setBuildMode(mode);

    const main = b.addTest("main.zig");
    main.setBuildMode(mode);
    main.linkLibrary(obj);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
