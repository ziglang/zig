const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "test.zig" },
    });
    test_exe.test_runner = "test_runner.zig";

    const test_run = test_exe.run();

    test_step.dependOn(&test_run.step);
}
