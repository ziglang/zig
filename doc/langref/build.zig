const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{ .path = "example.zig" },
        .optimize = optimize,
    });
    b.default_step.dependOn(&exe.step);
}

// syntax
