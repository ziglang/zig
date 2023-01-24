const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const main = b.addTest("main.zig");
    main.setBuildMode(b.standardReleaseOptions());
    main.addIncludePath(".");
    main.linkLibC();

    if (target.isNative()) {
        const test_step = b.step("test", "Test the program");
        test_step.dependOn(&main.step);
    }
}
