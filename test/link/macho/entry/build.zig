const std = @import("std");

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
    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.entry_symbol_name = "_non_main";

    const check_exe = exe.checkObject();

    check_exe.checkStart();
    check_exe.checkExact("segname __TEXT");
    check_exe.checkExtract("vmaddr {vmaddr}");

    check_exe.checkStart();
    check_exe.checkExact("cmd MAIN");
    check_exe.checkExtract("entryoff {entryoff}");

    check_exe.checkInSymtab();
    check_exe.checkExtract("{n_value} (__TEXT,__text) external _non_main");

    check_exe.checkComputeCompare("vmaddr entryoff +", .{ .op = .eq, .value = .{ .variable = "n_value" } });
    test_step.dependOn(&check_exe.step);

    const run = b.addRunArtifact(exe);
    run.skip_foreign_checks = true;
    run.expectStdOutEqual("42");
    test_step.dependOn(&run.step);
}
