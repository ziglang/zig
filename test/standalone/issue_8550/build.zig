const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = std.zig.CrossTarget{
        .os_tag = .freestanding,
        .cpu_arch = .arm,
        .cpu_model = .{
            .explicit = &std.Target.arm.cpu.arm1176jz_s,
        },
    };
    const mode = b.standardReleaseOptions();
    const kernel = b.addExecutable("kernel", "./main.zig");
    kernel.addObjectFile("./boot.S");
    kernel.setLinkerScriptPath(.{ .path = "./linker.ld" });
    kernel.setBuildMode(mode);
    kernel.setTarget(target);
    kernel.install();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&kernel.step);
}
