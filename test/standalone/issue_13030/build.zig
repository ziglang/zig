const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const obj = b.addObject("main", "main.zig");
    obj.setBuildMode(mode);

    obj.setTarget(target);
    b.default_step.dependOn(&obj.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&obj.step);
}
