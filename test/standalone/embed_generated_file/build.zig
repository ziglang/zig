const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const bootloader = b.addExecutable(.{
        .name = "bootloader",
        .root_source_file = b.path("bootloader.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
        }),
        .optimize = .ReleaseSmall,
    });

    const exe = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .optimize = .Debug,
    });
    exe.root_module.addAnonymousImport("bootloader.elf", .{
        .root_source_file = bootloader.getEmittedBin(),
    });

    // TODO: actually check the output
    _ = exe.getEmittedBin();

    test_step.dependOn(&exe.step);
}
