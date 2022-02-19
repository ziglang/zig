const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();
    const zip_add = b.addTest("main.zig");
    zip_add.setBuildMode(mode);
    zip_add.addCSourceFile("vendor/kuba-zip/zip.c", &[_][]const u8{
        "-std=c99",
        "-fno-sanitize=undefined",
    });
    zip_add.addIncludePath("vendor/kuba-zip");
    zip_add.linkLibC();

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&zip_add.step);
}
