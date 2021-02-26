const std = @import("std");
const Builder = std.build.Builder;
const RunStep = @import("RunStep.zig");

pub fn build(b: *Builder) !void {
    const test_step = b.step("test", "Resolve android and test the zig build files");

    try addRunStep(b, test_step, .{
        .expect = .pass,
        .outputs = &[_][]const u8 {"android not enabled, 'androidbuild' package not needed"},
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 { "missing package 'androidbuild'" },
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
        .outputs = &[_][]const u8 { "we have and need the 'androidbuild' package" },
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
        .outputs = &[_][]const u8 {
            "we have and need the 'androidbuild' package",
            "-Dfastcompress requires the 'fastcompressor' package"
        },
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
        .expect = .pass,
        .outputs = &[_][]const u8 {
            "we have and need the 'androidbuild' package",
            "we have and need the 'fastcompressor' package",
         },
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "--pkg-begin",
            "androidbuild",
            "android/build.zig",
            "--pkg-begin",
            "fastcompressor",
            "fastcompressor/build.zig",
            "--pkg-end",
            "--pkg-end",
            "-Dandroid",
            "-Dfastcompress",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 { "buildpkgs.has MUST be called with comptime" },
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file", "missing-comptime/build.zig",
        }),
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 { "unable to find 'buildpkgs'" },
        .args = try std.mem.dupe(b.allocator, []const u8, &[_][]const u8 {
            b.zig_exe,
            "build-exe",
            "import-buildpkgs-outside-build.zig",
        }),
    });
}

fn addRunStep(b: *Builder, test_step: *std.build.Step, opt: RunStep.Options) !void {
    const run = try b.allocator.create(RunStep);
    run.* = RunStep.init(b, opt);
    run.opt.cwd = b.build_root;
    test_step.dependOn(&run.step);
}
