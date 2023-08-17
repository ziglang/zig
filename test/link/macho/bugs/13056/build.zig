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
    const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse
        @panic("macOS SDK is required to run the test");

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    exe.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk.path, "/usr/include" }) });
    exe.addIncludePath(.{ .path = b.pathJoin(&.{ sdk.path, "/usr/include/c++/v1" }) });
    exe.addCSourceFile(.{ .file = .{ .path = "test.cpp" }, .flags = &.{
        "-nostdlib++",
        "-nostdinc++",
    } });
    exe.addObjectFile(.{ .path = b.pathJoin(&.{ sdk.path, "/usr/lib/libc++.tbd" }) });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.expectStdErrEqual("x: 5\n");

    test_step.dependOn(&run_cmd.step);
}
