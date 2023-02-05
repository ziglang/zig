const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const zip_add = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    zip_add.addCSourceFile("vendor/kuba-zip/zip.c", &[_][]const u8{
        "-std=c99",
        "-fno-sanitize=undefined",
    });
    zip_add.addIncludePath("vendor/kuba-zip");
    zip_add.linkLibC();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&zip_add.step);
}
