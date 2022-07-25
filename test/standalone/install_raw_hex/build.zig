const builtin = @import("builtin");
const std = @import("std");
const CheckFileStep = std.build.CheckFileStep;

pub fn build(b: *std.build.Builder) void {
    const target = .{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m4 },
        .os_tag = .freestanding,
        .abi = .gnueabihf,
    };

    const mode = b.standardReleaseOptions();

    const elf = b.addExecutable("zig-nrf52-blink.elf", "main.zig");
    elf.setTarget(target);
    elf.setBuildMode(mode);

    const test_step = b.step("test", "Test the program");
    b.default_step.dependOn(test_step);

    const hex_step = b.addInstallRaw(elf, "hello.hex", .{});
    test_step.dependOn(&hex_step.step);

    const explicit_format_hex_step = b.addInstallRaw(elf, "hello.foo", .{ .format = .hex });
    test_step.dependOn(&explicit_format_hex_step.step);
}
