const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const obj1 = b.addStaticLibrary("obj1", "obj1.zig");
    obj1.setBuildMode(mode);

    const obj2 = b.addStaticLibrary("obj2", "obj2.zig");
    obj2.setBuildMode(mode);

    const main = b.addTest("main.zig");
    main.setBuildMode(mode);
    main.linkLibrary(obj1);
    main.linkLibrary(obj2);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
