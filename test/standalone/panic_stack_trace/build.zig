const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const lib = b.addStaticLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    // TODO: remove after https://github.com/ziglang/zig/pull/16977 is merged
    lib.linkLibC();
    const exe = b.addExecutable(.{
        .name = "exe",
        .root_source_file = .{ .path = "exe.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(lib);
    b.installArtifact(exe);

    const dest_path = "test/standalone/panic_stack_trace";
    b.install_prefix = dest_path;
    b.install_path = dest_path;
    const install_exe = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .{ .custom = "." } } });
    test_step.dependOn(&install_exe.step);

    const main = b.addExecutable(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    const run = b.addRunArtifact(main);
    run.addArtifactArg(exe);
    run.expectExitCode(0);
    run.skip_foreign_checks = true;
    test_step.dependOn(&run.step);
}
