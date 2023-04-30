const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const exe_mod = b.createModule(.{ .source_file = .{ .path = "main.zig" }, .c_source_files = .{
        .files = &.{"foo.c"},
        .flags = &.{},
    } });
    const exe = b.addExecutable(.{
        .name = "extern",
        .main_module = exe_mod,
        .optimize = optimize,
        .target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
    });
    exe.use_llvm = false;
    exe.use_lld = false;

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("Result: 30");

    test_step.dependOn(&run.step);
}
