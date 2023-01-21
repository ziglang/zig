const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target: std.zig.CrossTarget = .{ .os_tag = .macos };

    const test_step = b.step("test", "Test the program");

    testUnwindInfo(b, test_step, mode, target, false);
    testUnwindInfo(b, test_step, mode, target, true);
}

fn testUnwindInfo(
    b: *Builder,
    test_step: *std.build.Step,
    mode: std.builtin.Mode,
    target: std.zig.CrossTarget,
    dead_strip: bool,
) void {
    const exe = createScenario(b, mode, target);
    exe.link_gc_sections = dead_strip;

    const check = exe.checkObject(.macho);
    check.checkStart("segname __TEXT");
    check.checkNext("sectname __gcc_except_tab");
    check.checkNext("sectname __unwind_info");

    switch (builtin.cpu.arch) {
        .aarch64 => {
            check.checkNext("sectname __eh_frame");
        },
        .x86_64 => {}, // We do not expect `__eh_frame` section on x86_64 in this case
        else => unreachable,
    }

    check.checkInSymtab();
    check.checkNext("{*} (__TEXT,__text) external ___gxx_personality_v0");

    const run_cmd = check.runAndCompare();
    run_cmd.expectStdOutEqual(
        \\Constructed: a
        \\Constructed: b
        \\About to destroy: b
        \\About to destroy: a
        \\Error: Not enough memory!
        \\
    );

    test_step.dependOn(&run_cmd.step);
}

fn createScenario(b: *Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget) *LibExeObjectStep {
    const exe = b.addExecutable("test", null);
    b.default_step.dependOn(&exe.step);
    exe.addIncludePath(".");
    exe.addCSourceFiles(&[_][]const u8{
        "main.cpp",
        "simple_string.cpp",
        "simple_string_owner.cpp",
    }, &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkLibCpp();
    return exe;
}
