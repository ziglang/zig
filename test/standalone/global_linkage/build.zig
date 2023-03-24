const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test the program");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const obj1 = b.addStaticLibrary(.{
        .name = "obj1",
        .root_source_file = .{ .path = "obj1.zig" },
        .optimize = optimize,
        .target = target,
    });

    const obj2 = b.addStaticLibrary(.{
        .name = "obj2",
        .root_source_file = .{ .path = "obj2.zig" },
        .optimize = optimize,
        .target = target,
    });

    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    main.linkLibrary(obj1);
    main.linkLibrary(obj2);

    test_step.dependOn(&main.run().step);
}
