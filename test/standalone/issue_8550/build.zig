const std = @import("std");

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target = std.zig.CrossTarget{
        .os_tag = .freestanding,
        .cpu_arch = .arm,
        .cpu_model = .{
            .explicit = &std.Target.arm.cpu.arm1176jz_s,
        },
    };

    const kernel = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = .{ .path = "./main.zig" },
        .optimize = optimize,
        .target = target,
    });
    kernel.addObjectFile("./boot.S");
    kernel.setLinkerScriptPath(.{ .path = "./linker.ld" });
    b.installArtifact(kernel);

    test_step.dependOn(&kernel.step);
}
