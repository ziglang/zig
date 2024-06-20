const std = @import("std");

pub const requires_symlinks = true;
pub const requires_ios_sdk = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
    });
    const optimize: std.builtin.OptimizeMode = .Debug;

    const sdk = std.zig.system.darwin.getSdk(b.allocator, target.result) orelse
        @panic("no iOS SDK found");
    b.sysroot = sdk;

    const main_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    main_mod.addCSourceFile(.{
        .file = b.path("main.m"),
        .flags = &.{},
    });
    main_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/include" }) });
    main_mod.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/System/Library/Frameworks" }) });
    main_mod.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "/usr/lib" }) });
    main_mod.linkFramework("Foundation", .{});
    main_mod.linkFramework("UIKit", .{});

    const exe = b.addExecutable2(.{
        .name = "main",
        .root_module = main_mod,
    });

    const check = exe.checkObject();
    check.checkInHeaders();
    check.checkExact("cmd BUILD_VERSION");
    check.checkExact("platform IOS");
    test_step.dependOn(&check.step);
}
