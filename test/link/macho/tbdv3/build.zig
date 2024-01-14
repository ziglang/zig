const std = @import("std");
const builtin = @import("builtin");

pub const requires_symlinks = true;
pub const requires_macos_sdk = false;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const target = b.resolveTargetQuery(.{ .os_tag = .macos });

    const lib = b.addSharedLibrary(.{
        .name = "a",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .optimize = optimize,
        .target = target,
    });
    lib.addCSourceFile(.{ .file = .{ .path = "a.c" }, .flags = &.{} });
    lib.linkLibC();

    const tbd_file = b.addWriteFile("liba.tbd",
        \\--- !tapi-tbd-v3
        \\archs:           [ arm64, x86_64 ]
        \\uuids:           [ 'arm64: DEADBEEF', 'x86_64: BEEFDEAD' ]
        \\platform:        macos
        \\install-name:    @rpath/liba.dylib
        \\current-version: 0
        \\exports:         
        \\  - archs:           [ arm64, x86_64 ]
        \\    symbols:         [ _getFoo ]
    );

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &[0][]const u8{} });
    exe.linkSystemLibrary("a");
    exe.addLibraryPath(tbd_file.getDirectory());
    exe.addRPath(lib.getEmittedBinDirectory());
    exe.linkLibC();

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectExitCode(0);

    test_step.dependOn(&run.step);
}
