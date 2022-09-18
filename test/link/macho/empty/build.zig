const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable("test", null);
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.addCSourceFile("empty.c", &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkLibC();

    const run_cmd = std.build.EmulatableRunStep.create(b, "run", exe);
    run_cmd.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run_cmd.step);
}
