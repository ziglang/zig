const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    {
        // Without -dead_strip, we expect `iAmUnused` symbol present
        const exe = createScenario(b, optimize, target);

        const check = exe.checkObject(.macho);
        check.checkInSymtab();
        check.checkNext("{*} (__TEXT,__text) external _iAmUnused");

        const run_cmd = check.runAndCompare();
        run_cmd.expectStdOutEqual("Hello!\n");
        test_step.dependOn(&run_cmd.step);
    }

    {
        // With -dead_strip, no `iAmUnused` symbol should be present
        const exe = createScenario(b, optimize, target);
        exe.link_gc_sections = true;

        const check = exe.checkObject(.macho);
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
) *std.Build.CompileStep {
    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
        .target = target,
    });
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.linkLibC();
    return exe;
}
