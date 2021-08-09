const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;

fn isRunnableTarget(t: CrossTarget) bool {
    // TODO I think we might be able to run this on Linux via Darling.
    // Add a check for that here, and return true if Darling is available.
    if (t.isNative() and t.getOsTag() == .macos)
        return true
    else
        return false;
}

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const test_step = b.step("test", "Test the program");

    const exe = b.addExecutable("test", null);
    b.default_step.dependOn(&exe.step);
    exe.addCSourceFile("main.c", &[0][]const u8{});
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.linkLibC();
    // TODO when we figure out how to ship framework stubs for cross-compilation,
    // populate paths to the sysroot here.
    exe.linkFramework("Cocoa");

    if (isRunnableTarget(target)) {
        const run_cmd = exe.run();
        test_step.dependOn(&run_cmd.step);
    }
}
