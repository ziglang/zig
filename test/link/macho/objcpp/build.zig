const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Test the program");

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
