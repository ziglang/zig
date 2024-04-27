const std = @import("std");

pub fn build(b: *std.Build) void {
    const obj = b.addObject(.{
        .name = "base64",
        .root_source_file = .{ .path = "base64.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "test",
    });
    exe.addCSourceFile(.{ .file = .{ .path = "test.c" }, .flags = &.{"-std=c99",} });
    exe.addObject(obj);
    exe.linkSystemLibrary("c");
    b.installArtifact(exe);
}

// syntax
