const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    if (builtin.os.tag == .windows and std.process.hasEnvVarConstant("ConEmuHWND")) {
        // ConEmu injects environment variables into processes before they are executed
        // depending on user settings. This obviously invalidates the test, so skipping
        // it is the best option.
        return;
    }

    if (builtin.os.tag == .windows and builtin.cpu.arch == .aarch64) {
        // https://github.com/ziglang/zig/issues/13685
        return;
    }

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    const run = b.addRunArtifact(main);
    run.clearEnvironment();
    run.disable_zig_progress = true;

    test_step.dependOn(&run.step);
}
