const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.stack_size = 0x100000000;

    const check_exe = exe.checkObject(.macho);
    check_exe.checkStart("cmd MAIN");
    check_exe.checkNext("stacksize 100000000");

    const run = check_exe.runAndCompare();
    test_step.dependOn(&run.step);
}
