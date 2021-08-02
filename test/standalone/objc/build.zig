const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Test the program");

    const exe = b.addExecutable("test", null);
    b.default_step.dependOn(&exe.step);
    exe.addIncludeDir(".");
    exe.addCSourceFile("Foo.m", &[0][]const u8{});
    exe.addCSourceFile("test.m", &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkLibC();
    exe.linkFramework("Foundation");

    const run_cmd = exe.run();
    test_step.dependOn(&run_cmd.step);
}
