const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const rel_opts = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .cpu_arch = .wasm32, .os_tag = .wasi };
    b.use_stage1 = false;

    const c_obj = b.addObject("cfuncs", null);
    c_obj.addCSourceFile("cfuncs.c", &[_][]const u8{"-std=c99"});
    c_obj.setBuildMode(rel_opts);
    c_obj.linkSystemLibrary("c");
    c_obj.setTarget(target);

    const main = b.addTest("main.zig");
    main.setBuildMode(rel_opts);
    main.addObject(c_obj);
    main.setTarget(target);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&main.step);

    b.default_step.dependOn(test_step);
}
