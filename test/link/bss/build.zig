const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const test_step = b.step("test", "Test");

    const exe = b.addExecutable(.{
        .name = "bss",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    b.default_step.dependOn(&exe.step);

    const run = exe.run();
    run.expectStdOutEqual("0, 1, 0\n");
    test_step.dependOn(&run.step);
}
