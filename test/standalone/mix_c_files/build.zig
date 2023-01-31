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

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("test.c", &[_][]const u8{"-std=c11"});
    exe.linkLibC();
    b.default_step.dependOn(&exe.step);

    const test_step = b.step("test", "Test the program");
    if (isRunnableTarget(target)) {
        const run_cmd = exe.run();
        test_step.dependOn(&run_cmd.step);
    } else {
        test_step.dependOn(&exe.step);
    }
}
