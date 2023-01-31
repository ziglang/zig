const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_artifact = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
    });
    test_artifact.addIncludePath("a_directory");

    b.default_step.dependOn(&test_artifact.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&test_artifact.step);
}
