const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const obj1 = b.addStaticLibrary(.{
        .name = "obj1",
        .root_source_file = .{ .path = "obj1.zig" },
        .optimize = optimize,
        .target = .{},
    });

    const obj2 = b.addStaticLibrary(.{
        .name = "obj2",
        .root_source_file = .{ .path = "obj2.zig" },
        .optimize = optimize,
        .target = .{},
    });

    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    main.linkLibrary(obj1);
    main.linkLibrary(obj2);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&main.step);
}
