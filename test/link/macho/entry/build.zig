const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const exe = b.addExecutable("main", null);
    exe.setBuildMode(mode);
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

    test_step.dependOn(&check_exe.step);

    const run = exe.run();
    run.expectStdOutEqual("42");
    test_step.dependOn(&run.step);
}
