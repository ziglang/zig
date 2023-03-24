const std = @import("std");

pub const requires_macos_sdk = true;
pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };
    const target_info = std.zig.system.NativeTargetInfo.detect(target) catch unreachable;
    const sdk = std.zig.system.darwin.getDarwinSDK(b.allocator, target_info.target) orelse
        @panic("macOS SDK is required to run the test");

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    exe.addIncludePath(std.fs.path.join(b.allocator, &.{ sdk.path, "/usr/include" }) catch unreachable);
    exe.addIncludePath(std.fs.path.join(b.allocator, &.{ sdk.path, "/usr/include/c++/v1" }) catch unreachable);
    exe.addCSourceFile("test.cpp", &.{
        "-nostdlib++",
        "-nostdinc++",
    });
    exe.addObjectFile(std.fs.path.join(b.allocator, &.{ sdk.path, "/usr/lib/libc++.tbd" }) catch unreachable);

    const run_cmd = exe.run();
    run_cmd.expectStdErrEqual("x: 5\n");

    test_step.dependOn(&run_cmd.step);
}
