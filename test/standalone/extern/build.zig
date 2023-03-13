const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject(.{
        .name = "exports",
        .root_source_file = .{ .path = "exports.zig" },
        .target = .{},
        .optimize = optimize,
    });
    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    main.addObject(obj);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
