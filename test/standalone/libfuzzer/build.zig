const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (builtin.os.tag == .windows) return; // TODO: libfuzzer support for windows

    const run_step = b.step("run", "Run executables");
    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .fuzz = true,
        }),
    });

    b.installArtifact(exe);
    b.default_step = run_step;

    const run_artifact = b.addRunArtifact(exe);
    run_artifact.addArg(b.cache_root.path orelse "");
    run_step.dependOn(&run_artifact.step);
}
