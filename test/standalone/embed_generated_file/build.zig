const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const bootloader = b.addExecutable(.{
        .name = "bootloader",
        .main_module = b.createModule(.{
            .source_file = .{ .path = "bootloader.zig" },
        }),
        .target = .{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
        },
        .optimize = .ReleaseSmall,
    });

    const bootloader_mod = b.createModule(.{
        .source_file = bootloader.getOutputSource(),
    });
    const exe = b.addTest(.{
        .main_module = b.createModule(.{
            .source_file = .{ .path = "main.zig" },
            .dependencies = &.{
                .{ .name = "bootloader.elf", .module = bootloader_mod },
            },
        }),
        .optimize = .Debug,
    });

    test_step.dependOn(&exe.step);
}
