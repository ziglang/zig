const std = @import("std");
const Builder = std.build.Builder;
const RunStep = @import("RunStep.zig");

pub fn build(b: *Builder) !void {
    const test_step = b.step("test", "Resolve android and test the zig build files");

    try addRunStep(b, test_step, .{
        .expect = .pass,
        .outputs = &[_][]const u8 {"android not enabled, 'androidbuild' package not needed"},
        .args = &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
        },
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 { "missing package 'androidbuild'" },
        .args = &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "-Dandroid",
        },
    });
    try addRunStep(b, test_step, .{
        .expect = .pass,
        .outputs = &[_][]const u8 { "we have and need the 'androidbuild' package" },
        .args = &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file",
            "app-that-might-use-android/build.zig",
            "--pkg-begin",
            "androidbuild",
            "android/build.zig",
            "--pkg-end",
            "-Dandroid",
        },
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 {
            "we have and need the 'androidbuild' package",
            "-Dfastcompress requires the 'fastcompressor' package"
        },
        .args = &[_][]const u8 {
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
        },
    });
    try addRunStep(b, test_step, .{
        .expect = .pass,
        .outputs = &[_][]const u8 {
            "we have and need the 'androidbuild' package",
            "we have and need the 'fastcompressor' package",
         },
        .args = &[_][]const u8 {
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
        },
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 { "buildpkgs.has MUST be called with comptime" },
        .args = &[_][]const u8 {
            b.zig_exe,
            "build",
            "--build-file", "missing-comptime/build.zig",
        },
    });
    try addRunStep(b, test_step, .{
        .expect = .fail,
        .outputs = &[_][]const u8 { "unable to find 'buildpkgs'" },
        .args = &[_][]const u8 {
            b.zig_exe,
            "build-exe",
            "import-buildpkgs-outside-build.zig",
        },
    });
}

fn addRunStep(b: *Builder, test_step: *std.build.Step, opt: struct {
    expect: enum { fail, pass },
    outputs: []const []const u8,
    args: []const []const u8,
}) !void {
    const run = std.build.RunStep.create(b, opt.outputs[0]);
    run.expected_exit_code = if (opt.expect == .pass) 0 else 1;
    run.addArgs(opt.args);
    run.stderr_action = .{ .expect_matches = opt.outputs };
    test_step.dependOn(&run.step);
}
