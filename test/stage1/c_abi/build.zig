const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const rel_opts = b.standardReleaseOptions();

    const c_obj = b.addCObject("cfuncs", "cfuncs.c");
    c_obj.setBuildMode(rel_opts);

    const main = b.addTest("main.zig");
    main.setBuildMode(rel_opts);
    main.addObject(c_obj);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&main.step);

    b.default_step.dependOn(test_step);
}
