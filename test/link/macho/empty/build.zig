const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.addCSourceFile("empty.c", &[0][]const u8{});
    exe.linkLibC();

    const run_cmd = std.Build.EmulatableRunStep.create(b, "run", exe);
    run_cmd.expectStdOutEqual("Hello!\n");
    test_step.dependOn(&run_cmd.step);
}
