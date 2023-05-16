const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

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
        .optimize = .Debug,
    });
    exe.addAnonymousModule("bootloader.elf", .{
        .source_file = bootloader.getOutputSource(),
    });

    test_step.dependOn(&exe.step);
}
