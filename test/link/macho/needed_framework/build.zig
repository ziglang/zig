const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(b.getInstallStep());

    // -dead_strip_dylibs
    // -needed_framework Cocoa
    const exe = b.addExecutable("test", null);
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.linkFrameworkNeeded("Cocoa");
    exe.dead_strip_dylibs = true;

    const check = exe.checkObject(.macho);
    check.checkStart("cmd LOAD_DYLIB");
    check.checkNext("name {*}Cocoa");
    test_step.dependOn(&check.step);

    const run_cmd = exe.run();
    test_step.dependOn(&run_cmd.step);
}
