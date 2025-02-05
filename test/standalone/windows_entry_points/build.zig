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
        const exe = b.addExecutable(.{
            .name = "main",
            .root_module = b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = .Debug,
                .link_libc = true,
            }),
        });
        exe.root_module.addCSourceFile(.{ .file = b.path("main.c") });

        _ = exe.getEmittedBin();
        test_step.dependOn(&exe.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "wmain",
            .root_module = b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = .Debug,
                .link_libc = true,
            }),
        });
        exe.mingw_unicode_entry_point = true;
        exe.root_module.addCSourceFile(.{ .file = b.path("wmain.c") });

        _ = exe.getEmittedBin();
        test_step.dependOn(&exe.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "winmain",
            .root_module = b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = .Debug,
                .link_libc = true,
            }),
        });
        // Note: `exe.subsystem = .Windows;` is not necessary
        exe.root_module.addCSourceFile(.{ .file = b.path("winmain.c") });

        _ = exe.getEmittedBin();
        test_step.dependOn(&exe.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "wwinmain",
            .root_module = b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = .Debug,
                .link_libc = true,
            }),
        });
        exe.mingw_unicode_entry_point = true;
        // Note: `exe.subsystem = .Windows;` is not necessary
        exe.root_module.addCSourceFile(.{ .file = b.path("wwinmain.c") });

        _ = exe.getEmittedBin();
        test_step.dependOn(&exe.step);
    }
}
