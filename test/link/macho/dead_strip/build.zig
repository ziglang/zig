const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    {
        // Without -dead_strip, we expect `iAmUnused` symbol present
        const exe = createScenario(b, mode);

        const check = exe.checkObject(.macho);
        check.checkInSymtab();
        check.checkNext("{*} (__TEXT,__text) external _iAmUnused");

        test_step.dependOn(&check.step);

        const run_cmd = exe.run();
        run_cmd.expectStdOutEqual("Hello!\n");
        test_step.dependOn(&run_cmd.step);
    }

    {
        // With -dead_strip, no `iAmUnused` symbol should be present
        const exe = createScenario(b, mode);
        exe.link_gc_sections = true;

        const check = exe.checkObject(.macho);
        check.checkInSymtab();
        check.checkNotPresent("{*} (__TEXT,__text) external _iAmUnused");

        test_step.dependOn(&check.step);

        const run_cmd = exe.run();
        run_cmd.expectStdOutEqual("Hello!\n");
        test_step.dependOn(&run_cmd.step);
    }
}

fn createScenario(b: *Builder, mode: std.builtin.Mode) *LibExeObjectStep {
    const exe = b.addExecutable("test", null);
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.linkLibC();
    return exe;
}
