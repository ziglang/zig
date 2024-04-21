const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .gnueabihf,
    });

    const optimize: std.builtin.OptimizeMode = .Debug;

    const elf = b.addExecutable(.{
        .name = "zig-nrf52-blink.elf",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const hex_step = elf.addObjCopy(.{
        .basename = "hello.hex",
    });
    test_step.dependOn(&hex_step.step);

    const explicit_format_hex_step = elf.addObjCopy(.{
        .basename = "hello.foo",
        .format = .hex,
    });
    test_step.dependOn(&explicit_format_hex_step.step);
}
