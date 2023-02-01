const std = @import("std");
const builtin = @import("builtin");
const CrossTarget = std.zig.CrossTarget;

// TODO integrate this with the std.Build executor API
fn isRunnableTarget(t: CrossTarget) bool {
    if (t.isNative()) return true;

    return (t.getOsTag() == builtin.os.tag and
        t.getCpuArch() == builtin.cpu.arch);
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Test the program");

    const exe_c = b.addExecutable(.{
        .name = "test_c",
        .optimize = optimize,
        .target = target,
    });
    b.default_step.dependOn(&exe_c.step);
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

    if (isRunnableTarget(target)) {
        const run_c_cmd = exe_c.run();
        test_step.dependOn(&run_c_cmd.step);
        const run_cpp_cmd = exe_cpp.run();
        test_step.dependOn(&run_cpp_cmd.step);
    } else {
        test_step.dependOn(&exe_c.step);
        test_step.dependOn(&exe_cpp.step);
    }
}
