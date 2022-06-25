const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    {
        // Test -headerpad_max_install_names
        const exe = simpleExe(b, mode);
        exe.headerpad_max_install_names = true;

        const check = exe.checkObject(.macho);
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

        const run = exe.run();
        test_step.dependOn(&run.step);
    }

    {
        // Test -headerpad
        const exe = simpleExe(b, mode);
        exe.headerpad_size = 0x10000;

        const check = exe.checkObject(.macho);
        check.checkStart("sectname __text");
        check.checkNext("offset {offset}");
        check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });

        test_step.dependOn(&check.step);

        const run = exe.run();
        test_step.dependOn(&run.step);
    }

    {
        // Test both flags with -headerpad overriding -headerpad_max_install_names
        const exe = simpleExe(b, mode);
        exe.headerpad_max_install_names = true;
        exe.headerpad_size = 0x10000;

        const check = exe.checkObject(.macho);
        check.checkStart("sectname __text");
        check.checkNext("offset {offset}");
        check.checkComputeCompare("offset", .{ .op = .gte, .value = .{ .literal = 0x10000 } });

        test_step.dependOn(&check.step);

        const run = exe.run();
        test_step.dependOn(&run.step);
    }

    {
        // Test both flags with -headerpad_max_install_names overriding -headerpad
        const exe = simpleExe(b, mode);
        exe.headerpad_size = 0x1000;
        exe.headerpad_max_install_names = true;

        const check = exe.checkObject(.macho);
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

        const run = exe.run();
        test_step.dependOn(&run.step);
    }
}

fn simpleExe(b: *Builder, mode: std.builtin.Mode) *LibExeObjectStep {
    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
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
