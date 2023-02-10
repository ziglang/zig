const std = @import("std");

pub fn build(b: *std.Build) void {
    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
    });
    main.addIncludePath(".");

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
