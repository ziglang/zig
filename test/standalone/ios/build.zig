const std = @import("std");

pub const requires_symlinks = true;
pub const requires_ios_sdk = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
    };
    const target_info = std.zig.system.NativeTargetInfo.detect(target) catch @panic("couldn't detect native target");
    const sdk = std.zig.system.darwin.getSdk(b.allocator, target_info.target) orelse @panic("no iOS SDK found");
    b.sysroot = sdk.path;

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.m" }, .flags = &.{} });
    exe.addSystemIncludePath(.{ .path = b.pathJoin(&.{ sdk.path, "/usr/include" }) });
    exe.addSystemFrameworkPath(.{ .path = b.pathJoin(&.{ sdk.path, "/System/Library/Frameworks" }) });
    exe.addLibraryPath(.{ .path = b.pathJoin(&.{ sdk.path, "/usr/lib" }) });
    exe.linkFramework("Foundation");
    exe.linkFramework("UIKit");
    exe.linkLibC();

    const check = exe.checkObject();
    check.checkStart();
    check.checkExact("cmd BUILD_VERSION");
    check.checkExact("platform IOS");
    test_step.dependOn(&check.step);
}
