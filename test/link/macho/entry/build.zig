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
    const mod = b.createModule(.{
        .c_source_files = .{
            .files = &.{"main.c"},
            .flags = &.{},
        },
    });
    const exe = b.addExecutable(.{
        .name = "main",
        .main_module = mod,
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    exe.linkLibC();
    exe.entry_symbol_name = "_non_main";

    const check_exe = exe.checkObject();

    check_exe.checkStart("segname __TEXT");
    check_exe.checkNext("vmaddr {vmaddr}");

    check_exe.checkStart("cmd MAIN");
    check_exe.checkNext("entryoff {entryoff}");

    check_exe.checkInSymtab();
    check_exe.checkNext("{n_value} (__TEXT,__text) external _non_main");

    check_exe.checkComputeCompare("vmaddr entryoff +", .{ .op = .eq, .value = .{ .variable = "n_value" } });

    const run = check_exe.runAndCompare();
    run.expectStdOutEqual("42");
    test_step.dependOn(&run.step);
}
