const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const test_step = b.step("test", "Test it");
    _ = addExe(b, test_step, "example-no-pkg", "example.zig", &[_][]const u8 {
        "my_pkg is missing",
    });
    _ = addExe(b, test_step, "example-with-pkg", "example.zig", &[_][]const u8 {
        "have my_pkg",
        "a message from pkg.zig",
    }).addPackagePath("my_pkg", "pkg.zig");
}

fn addExe(
    b: *Builder,
    step: *std.build.Step,
    name: []const u8,
    root: []const u8,
    expect_matches: []const []const u8
) *std.build.LibExeObjStep {
    const exe = b.addExecutable(name, root);
    exe.setBuildMode(b.standardReleaseOptions());
    const run = exe.run();
    run.stdout_action = .{ .expect_matches = expect_matches };
    step.dependOn(&run.step);
    return exe;
}
