const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = b.resolveTargetQuery(.{ .os_tag = .macos });

    {
        const exe = b.addExecutable(.{
            .name = "pagezero",
            .optimize = optimize,
            .target = target,
        });
        exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &.{} });
        exe.linkLibC();
        exe.pagezero_size = 0x4000;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("LC 0");
        check.checkExact("segname __PAGEZERO");
        check.checkExact("vmaddr 0");
        check.checkExact("vmsize 4000");

        check.checkInHeaders();
        check.checkExact("segname __TEXT");
        check.checkExact("vmaddr 4000");

        test_step.dependOn(&check.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "no_pagezero",
            .optimize = optimize,
            .target = target,
        });
        exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &.{} });
        exe.linkLibC();
        exe.pagezero_size = 0;

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("LC 0");
        check.checkExact("segname __TEXT");
        check.checkExact("vmaddr 0");

        test_step.dependOn(&check.step);
    }
}
