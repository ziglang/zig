const std = @import("std");
const Builder = std.build.Builder;
const LibExeObjectStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());
    testUuid(b, test_step, .ReleaseSafe, "46b333df88f5314686fc0cba3b939ca8");
    testUuid(b, test_step, .ReleaseFast, "46b333df88f5314686fc0cba3b939ca8");
    testUuid(b, test_step, .ReleaseSmall, "46b333df88f5314686fc0cba3b939ca8");
}

fn testUuid(b: *Builder, test_step: *std.build.Step, mode: std.builtin.Mode, comptime exp: []const u8) void {
    // The calculated UUID value is independent of debug info and so it should
    // stay the same across builds.
    {
        const dylib = simpleDylib(b, mode);
        const check_dylib = dylib.checkObject(.macho);
        check_dylib.checkStart("cmd UUID");
        check_dylib.checkNext("uuid " ++ exp);
        test_step.dependOn(&check_dylib.step);
    }
    {
        const dylib = simpleDylib(b, mode);
        dylib.strip = true;
        const check_dylib = dylib.checkObject(.macho);
        check_dylib.checkStart("cmd UUID");
        check_dylib.checkNext("uuid " ++ exp);
        test_step.dependOn(&check_dylib.step);
    }
}

fn simpleDylib(b: *Builder, mode: std.builtin.Mode) *LibExeObjectStep {
    const dylib = b.addSharedLibrary("test", null, b.version(1, 0, 0));
    dylib.setBuildMode(mode);
    dylib.setTarget(.{ .cpu_arch = .aarch64, .os_tag = .macos });
    dylib.addCSourceFile("test.c", &.{});
    dylib.linkLibC();
    return dylib;
}
