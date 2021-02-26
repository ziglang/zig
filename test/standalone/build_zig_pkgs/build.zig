const std = @import("std");
const Builder = std.build.Builder;
const RunStep = @import("RunStep.zig");

pub fn build(b: *Builder) !void {
    const test_step = b.step("test", "Resolve android and test the zig build files");

    try addRunStep(b, test_step, .{
        .expect = .pass,
        .output = "android not enabled, 'androidbuild' package not needed",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .output = "missing package 'androidbuild'",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "-Dandroid",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .pass,
        .output = "we have and need the 'androidbuild' package",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "--pkg-begin",
            "androidbuild",
            "android/build.zig",
            "--pkg-end",
            "-Dandroid",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .output = "-Dfastcompress requires the 'fastcompressor' package",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "--pkg-begin",
            "androidbuild",
            "android/build.zig",
            "--pkg-end",
            "-Dandroid",
            "-Dfastcompress",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .output = "-Dfastcompress requires the 'fastcompressor' package",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "--pkg-begin",
            "androidbuild",
            "android/build.zig",
            "--pkg-begin",
            "fastcompress",
            "fastcompress/build.zig",
            "--pkg-end",
            "--pkg-end",
            "-Dandroid",
            "-Dfastcompress",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .output = "builtin.hasPkg MUST be called with comptime",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file", "missing-comptime/build.zig",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .output = "builtin.hasPkg is only available in build.zig",
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build-exe",
            "calling-haspkg-outside-build.zig"
        }),
    });
}

fn addRunStep(b: *Builder, test_step: *std.build.Step, opt: RunStep.Options) !void {
    const run = try b.allocator.create(RunStep);
    run.* = RunStep.init(b, opt);
    test_step.dependOn(&run.step);
}
