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
        .root_module = b.createModule(.{
            .root_source_file = null,
            .optimize = optimize,
            .target = target,
            .link_libc = true,
        }),
    });
    exe.root_module.addCSourceFile(.{ .file = b.path("main.m"), .flags = &.{} });
    exe.root_module.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
    exe.root_module.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
    exe.root_module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
    exe.root_module.linkFramework("Foundation", .{});
    exe.root_module.linkFramework("UIKit", .{});

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd BUILD_VERSION");
    check.checkExact("platform IOS");
    test_step.dependOn(&check.step);
}
