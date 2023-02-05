const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable(.{
        .name = "main",
        .optimize = optimize,
        .target = .{ .os_tag = .macos },
    });
    exe.addCSourceFile("main.c", &.{});
    exe.linkLibC();
    exe.entry_symbol_name = "_non_main";

    const check_exe = exe.checkObject(.macho);

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
