const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    {
        const exe = b.addExecutable("pagezero", null);
        exe.setBuildMode(mode);
        exe.addCSourceFile("main.c", &.{});
        exe.linkLibC();
        exe.pagezero_size = 0x4000;

        const check_macho = exe.checkMachO();
        check_macho.checkLoadCommand(.{
            .cmd = std.macho.LC.SEGMENT_64,
            .index = 0,
            .name = "__PAGEZERO",
            .vaddr = 0,
            .memsz = 0x4000,
        });
        check_macho.checkLoadCommand(.{
            .cmd = std.macho.LC.SEGMENT_64,
            .index = 1,
            .name = "__TEXT",
            .vaddr = 0x4000,
        });

        test_step.dependOn(&check_macho.step);
    }

    {
        const exe = b.addExecutable("no_pagezero", null);
        exe.setBuildMode(mode);
        exe.addCSourceFile("main.c", &.{});
        exe.linkLibC();
        exe.pagezero_size = 0;

        const check_macho = exe.checkMachO();
        check_macho.checkLoadCommand(.{
            .cmd = std.macho.LC.SEGMENT_64,
            .index = 0,
            .name = "__TEXT",
            .vaddr = 0,
        });

        test_step.dependOn(&check_macho.step);
    }
}
