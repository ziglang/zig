const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const bootloader = b.addExecutable(.{
        .name = "bootloader",
        .root_source_file = .{ .path = "bootloader.zig" },
        .target = .{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
        },
        .optimize = .ReleaseSmall,
    });

    const exe = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addAnonymousModule("bootloader.elf", .{
        .source_file = bootloader.getOutputSource(),
    });

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&exe.step);
}
