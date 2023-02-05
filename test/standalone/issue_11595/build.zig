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
        .name = "zigtest",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.install();

    const c_sources = [_][]const u8{
        "test.c",
    };

    exe.addCSourceFiles(&c_sources, &.{});
    exe.linkLibC();

    var i: i32 = 0;
    while (i < 1000) : (i += 1) {
        exe.defineCMacro("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA");
    }

    exe.defineCMacro("FOO", "42");
    exe.defineCMacro("BAR", "\"BAR\"");
    exe.defineCMacro("BAZ",
        \\"\"BAZ\""
    );
    exe.defineCMacro("QUX", "\"Q\" \"UX\"");
    exe.defineCMacro("QUUX", "\"QU\\\"UX\"");

    b.default_step.dependOn(&exe.step);

    const test_step = b.step("test", "Test the program");
    if (isRunnableTarget(target)) {
        const run_cmd = exe.run();
        test_step.dependOn(&run_cmd.step);
    } else {
        test_step.dependOn(&exe.step);
    }
}
