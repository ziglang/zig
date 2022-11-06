const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");

    const exe = b.addExecutable("test", "main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);

    const run = exe.runEmulatable();
    test_step.dependOn(&run.step);
}
