const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const ok = (builtin.os.tag != .wasi and
        // https://github.com/ziglang/zig/issues/13550
        (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) and
        // https://github.com/ziglang/zig/issues/13686
        (builtin.os.tag != .windows or builtin.cpu.arch != .aarch64));
    if (!ok) return;

    const lib = b.addSharedLibrary(.{
        .name = "add",
        .root_source_file = .{ .path = "add.zig" },
        .version = .{ .major = 1, .minor = 0 },
        .optimize = optimize,
        .target = target,
    });

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });

    const run = b.addRunArtifact(main);
    run.addArtifactArg(lib);
    run.skip_foreign_checks = true;
    run.expectExitCode(0);

    test_step.dependOn(&run.step);
}
