const std = @import("std");

pub const requires_macos_sdk = true;
pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    {
        // Without -dead_strip_dylibs we expect `-la` to include liba.dylib in the final executable
        const exe = createScenario(b, optimize, "no-dead-strip");

        const check = exe.checkObject();
        check.checkInHeaders();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkContains("Cocoa");

        check.checkInHeaders();
        check.checkExact("cmd LOAD_DYLIB");
        check.checkContains("libobjc");

        test_step.dependOn(&check.step);

        const run_cmd = b.addRunArtifact(exe);
        test_step.dependOn(&run_cmd.step);
    }

    {
        // With -dead_strip_dylibs, we should include liba.dylib as it's unreachable
        const exe = createScenario(b, optimize, "yes-dead-strip");
        exe.dead_strip_dylibs = true;

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.expectExitCode(@as(u8, @bitCast(@as(i8, -2)))); // should fail
        test_step.dependOn(&run_cmd.step);
    }
}

fn createScenario(
    b: *std.Build,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .optimize = optimize,
        .target = b.host,
    });
    exe.addCSourceFile(.{ .file = .{ .path = "main.c" }, .flags = &[0][]const u8{} });
    exe.linkLibC();
    exe.linkFramework("Cocoa");
    return exe;
}
