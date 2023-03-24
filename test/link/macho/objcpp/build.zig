const std = @import("std");

pub const requires_symlinks = true;
pub const requires_macos_sdk = true;

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
        .name = "test",
        .optimize = optimize,
    });
    b.default_step.dependOn(&exe.step);
    exe.addIncludePath(".");
    exe.addCSourceFile("Foo.mm", &[0][]const u8{});
    exe.addCSourceFile("test.mm", &[0][]const u8{});
    exe.linkLibCpp();
    // TODO when we figure out how to ship framework stubs for cross-compilation,
    // populate paths to the sysroot here.
    exe.linkFramework("Foundation");

    const run_cmd = exe.run();
    run_cmd.expectStdOutEqual("Hello from C++ and Zig");

    test_step.dependOn(&run_cmd.step);
}
