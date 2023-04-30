const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize: std.builtin.OptimizeMode = .Debug;

    const obj = b.addObject(.{
        .name = "exports",
        .main_module = b.createModule(.{
            .source_file = .{ .path = "export.zig" },
        }),
        .target = .{},
        .optimize = optimize,
    });
    const main = b.addTest(.{
        .main_module = b.createModule(.{
            .source_file = .{ .path = "main.zig" },
        }),
        .optimize = optimize,
    });
    main.addObject(obj);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
