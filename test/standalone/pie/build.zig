const std = @import("std");

pub fn build(b: *std.Build) void {
    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
    });
    main.pie = true;

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&main.step);

    b.default_step.dependOn(test_step);
}
