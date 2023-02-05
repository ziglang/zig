const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "test.zig" },
        .kind = .test_exe,
    });
    test_exe.test_runner = "test_runner.zig";

    const test_run = test_exe.run();

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&test_run.step);
}
