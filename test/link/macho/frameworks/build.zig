const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    const test_step = b.step("test", "Test the program");

    const exe = b.addExecutable("test", null);
    b.default_step.dependOn(&exe.step);
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.linkFramework("Cocoa");

    const check = exe.checkObject(.macho);
    check.checkStart("cmd LOAD_DYLIB");
    check.checkNext("name {*}Cocoa");

    switch (mode) {
        .Debug, .ReleaseSafe => {
            check.checkStart("cmd LOAD_DYLIB");
            check.checkNext("name {*}libobjc{*}.dylib");
        },
        else => {},
    }

    test_step.dependOn(&check.step);

    const run_cmd = exe.run();
    test_step.dependOn(&run_cmd.step);
}
