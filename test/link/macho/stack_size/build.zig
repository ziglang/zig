const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable("main", null);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.stack_size = 0x100000000;

    const check_exe = exe.checkObject(.macho);
    check_exe.checkStart("cmd MAIN");
    check_exe.checkNext("stacksize 100000000");
    test_step.dependOn(&check_exe.step);

    const run = check_exe.runAndCompare();
    test_step.dependOn(&run.step);
}
