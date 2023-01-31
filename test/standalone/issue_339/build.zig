const std = @import("std");

pub fn build(b: *std.Build) void {
    const obj = b.addObject(.{
        .name = "test",
        .root_source_file = .{ .path = "test.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&obj.step);
}
