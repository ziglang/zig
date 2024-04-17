const std = @import("std");

pub const requires_symlinks = true;
pub const requires_ios_sdk = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
    });
    const sdk = std.zig.system.darwin.getSdk(b.allocator, target.result) orelse
        @panic("no iOS SDK found");
    b.sysroot = sdk;

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = b.path("main.m"), .flags = &.{} });
    exe.addSystemIncludePath(b.path(b.pathJoin(&.{ sdk, "/usr/include" })));
    exe.addSystemFrameworkPath(b.path(b.pathJoin(&.{ sdk, "/System/Library/Frameworks" })));
    exe.addLibraryPath(b.path(b.pathJoin(&.{ sdk, "/usr/lib" })));
    exe.linkFramework("Foundation");
    exe.linkFramework("UIKit");
    exe.linkLibC();

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd BUILD_VERSION");
    check.checkExact("platform IOS");
    test_step.dependOn(&check.step);
}
