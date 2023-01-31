const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Test the program");

    const exe = b.addExecutable(.{
        .name = "test",
        .optimize = optimize,
    });
    exe.addIncludePath(".");
    exe.addCSourceFile("Foo.m", &[0][]const u8{});
    exe.addCSourceFile("test.m", &[0][]const u8{});
    exe.linkLibC();
    // TODO when we figure out how to ship framework stubs for cross-compilation,
    // populate paths to the sysroot here.
    exe.linkFramework("Foundation");

    const run_cmd = std.Build.EmulatableRunStep.create(b, "run", exe);
    test_step.dependOn(&run_cmd.step);
}
