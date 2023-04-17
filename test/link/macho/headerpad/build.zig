const std = @import("std");
const builtin = @import("builtin");

pub const requires_symlinks = true;
pub const requires_macos_sdk = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    {
        // Test -headerpad_max_install_names
        const exe = simpleExe(b, optimize, "headerpad_max_install_names");
        exe.headerpad_max_install_names = true;

        const check = exe.checkObject();
        check.checkStart("sectname __text");
        check.checkNext("offset {offset}");

        switch (builtin.cpu.arch) {
            .aarch64 => {
                check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x4000 } });
            },
            .x86_64 => {
                check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x1000 } });
            },
            else => unreachable,
        }

        test_step.dependOn(&check.step);

        const run = b.addRunArtifact(exe);
        test_step.dependOn(&run.step);
    }

    {
        // Test -headerpad
        const exe = simpleExe(b, optimize, "headerpad");
        exe.headerpad_size = 0x10000;

        const check = exe.checkObject();
        check.checkStart("sectname __text");
        check.checkNext("offset {offset}");
        check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });

        test_step.dependOn(&check.step);

        const run = b.addRunArtifact(exe);
        test_step.dependOn(&run.step);
    }

    {
        // Test both flags with -headerpad overriding -headerpad_max_install_names
        const exe = simpleExe(b, optimize, "headerpad_overriding");
        exe.headerpad_max_install_names = true;
        exe.headerpad_size = 0x10000;

        const check = exe.checkObject();
        check.checkStart("sectname __text");
        check.checkNext("offset {offset}");
        check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });

        test_step.dependOn(&check.step);

        const run = b.addRunArtifact(exe);
        test_step.dependOn(&run.step);
    }

    {
        // Test both flags with -headerpad_max_install_names overriding -headerpad
        const exe = simpleExe(b, optimize, "headerpad_max_install_names_overriding");
        exe.headerpad_size = 0x1000;
        exe.headerpad_max_install_names = true;

        const check = exe.checkObject();
        check.checkStart("sectname __text");
        check.checkNext("offset {offset}");

        switch (builtin.cpu.arch) {
            .aarch64 => {
                check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x4000 } });
            },
            .x86_64 => {
                check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x1000 } });
            },
            else => unreachable,
        }

        test_step.dependOn(&check.step);

        const run = b.addRunArtifact(exe);
        test_step.dependOn(&run.step);
    }
}

fn simpleExe(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
) *std.Build.CompileStep {
    const exe = b.addExecutable(.{
        .name = name,
        .optimize = optimize,
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.linkFramework("CoreFoundation");
    exe.linkFramework("Foundation");
    exe.linkFramework("Cocoa");
    exe.linkFramework("CoreGraphics");
    exe.linkFramework("CoreHaptics");
    exe.linkFramework("CoreAudio");
    exe.linkFramework("AVFoundation");
    exe.linkFramework("CoreImage");
    exe.linkFramework("CoreLocation");
    exe.linkFramework("CoreML");
    exe.linkFramework("CoreVideo");
    exe.linkFramework("CoreText");
    exe.linkFramework("CryptoKit");
    exe.linkFramework("GameKit");
    exe.linkFramework("SwiftUI");
    exe.linkFramework("StoreKit");
    exe.linkFramework("SpriteKit");
    return exe;
}
