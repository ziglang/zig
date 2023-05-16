const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    {
        // Without -dead_strip, we expect `iAmUnused` symbol present
        const exe = createScenario(b, optimize, target, "no-gc");

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNext("{*} (__TEXT,__text) external _iAmUnused");

        const run_cmd = check.runAndCompare();
        run_cmd.expectStdOutEqual("Hello!\n");
        test_step.dependOn(&run_cmd.step);
    }

    {
        // With -dead_strip, no `iAmUnused` symbol should be present
        const exe = createScenario(b, optimize, target, "yes-gc");
        exe.link_gc_sections = true;

        const check = exe.checkObject();
        check.checkInSymtab();
        check.checkNotPresent("{*} (__TEXT,__text) external _iAmUnused");

        const run_cmd = check.runAndCompare();
        run_cmd.expectStdOutEqual("Hello!\n");
        test_step.dependOn(&run_cmd.step);
    }
}

fn createScenario(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
    name: []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    return exe;
}
