const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    });

    {
        const mod = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = .Debug,
            .link_libc = true,
        });
        mod.addCSourceFile(.{ .file = b.path("main.c") });

        const exe = b.addExecutable2(.{
            .name = "main",
            .root_module = mod,
        });

        _ = exe.getEmittedBin();

        test_step.dependOn(&exe.step);
    }

    {
        const mod = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = .Debug,
            .link_libc = true,
        });
        mod.addCSourceFile(.{ .file = b.path("wmain.c") });

        const exe = b.addExecutable2(.{
            .name = "wmain",
            .root_module = mod,
        });
        exe.mingw_unicode_entry_point = true;

        _ = exe.getEmittedBin();

        test_step.dependOn(&exe.step);
    }

    {
        const mod = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = .Debug,
            .link_libc = true,
        });
        mod.addCSourceFile(.{ .file = b.path("winmain.c") });

        const exe = b.addExecutable2(.{
            .name = "winmain",
            .root_module = mod,
        });
        // Note: `exe.subsystem = .Windows;` is not necessary

        _ = exe.getEmittedBin();

        test_step.dependOn(&exe.step);
    }

    {
        const mod = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = .Debug,
            .link_libc = true,
        });
        mod.addCSourceFile(.{ .file = b.path("wwinmain.c") });

        const exe = b.addExecutable2(.{
            .name = "wwinmain",
            .root_module = mod,
        });
        // Note: `exe.subsystem = .Windows;` is not necessary
        exe.mingw_unicode_entry_point = true;

        _ = exe.getEmittedBin();

        test_step.dependOn(&exe.step);
    }
}
