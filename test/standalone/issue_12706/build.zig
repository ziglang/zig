const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;

// TODO integrate this with the std.build executor API
fn isRunnableTarget(t: CrossTarget) bool {
    if (t.isNative()) return true;

    return (t.getOsTag() == builtin.os.tag and
        t.getCpuArch() == builtin.cpu.arch);
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable("main", "main.zig");
    exe.setBuildMode(mode);
    exe.install();

    const c_sources = [_][]const u8{
        "test.c",
    };

    exe.addCSourceFiles(&c_sources, &.{});
    exe.linkLibC();

    exe.setTarget(target);
    b.default_step.dependOn(&exe.step);

    const test_step = b.step("test", "Test the program");
    if (isRunnableTarget(target)) {
        const run_cmd = exe.run();
        test_step.dependOn(&run_cmd.step);
    } else {
        test_step.dependOn(&exe.step);
    }
}
