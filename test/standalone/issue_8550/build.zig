const std = @import("std");

pub fn build(b: *std.Build) !void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .arm,
        .cpu_model = .{
            .explicit = &std.Target.arm.cpu.arm1176jz_s,
        },
    });
    const optimize: std.builtin.OptimizeMode = .Debug;

    const kernel_mod = b.createModule(.{
        .root_source_file = b.path("./main.zig"),
        .target = target,
        .optimize = optimize,
    });
    kernel_mod.addObjectFile(b.path("./boot.S"));

    const kernel = b.addExecutable2(.{
        .name = "kernel",
        .root_module = kernel_mod,
    });
    kernel.setLinkerScript(b.path("./linker.ld"));
    b.installArtifact(kernel);

    test_step.dependOn(&kernel.step);
}
