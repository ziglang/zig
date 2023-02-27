const builtin = @import("builtin");
const std = @import("std");
const CheckFileStep = std.Build.CheckFileStep;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step.dependOn(test_step);

    const target = .{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .gnueabihf,
    };

    const optimize = b.standardOptimizeOption(.{});

    const elf = b.addExecutable(.{
        .name = "zig-nrf52-blink.elf",
        .root_source_file = .{ .path = "main.zig" },
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
