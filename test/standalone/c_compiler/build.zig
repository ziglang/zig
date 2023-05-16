const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const target: std.zig.CrossTarget = .{};

    const exe_c = b.addExecutable(.{
        .name = "test_c",
        .optimize = optimize,
        .target = target,
    });
    exe_c.addCSourceFile("test.c", &[0][]const u8{});
    exe_c.linkLibC();

    const exe_cpp = b.addExecutable(.{
        .name = "test_cpp",
        .optimize = optimize,
        .target = target,
    });
    b.default_step.dependOn(&exe_cpp.step);
    exe_cpp.addCSourceFile("test.cpp", &[0][]const u8{});
    exe_cpp.linkLibCpp();

    switch (target.getOsTag()) {
        .windows => {
            // https://github.com/ziglang/zig/issues/8531
            exe_cpp.want_lto = false;
        },
        .macos => {
            // https://github.com/ziglang/zig/issues/8680
            exe_cpp.want_lto = false;
            exe_c.want_lto = false;
        },
        else => {},
    }

    const run_c_cmd = b.addRunArtifact(exe_c);
    run_c_cmd.expectExitCode(0);
    run_c_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_c_cmd.step);

    const run_cpp_cmd = b.addRunArtifact(exe_cpp);
    run_cpp_cmd.expectExitCode(0);
    run_cpp_cmd.skip_foreign_checks = true;
    test_step.dependOn(&run_cpp_cmd.step);
}
