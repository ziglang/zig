const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const native_target: std.zig.CrossTarget = .{};
    const cross_target = .{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    };

    add(b, native_target, test_step);
    add(b, cross_target, test_step);
}

fn add(b: *std.Build, target: std.zig.CrossTarget, test_step: *std.Build.Step) void {
    const exe = b.addExecutable(.{
        .name = "zig_resource_test",
        .root_source_file = .{ .path = "main.zig" },
        .target = target,
        .optimize = .Debug,
    });
    exe.addWin32ResourceFile(.{
        .file = .{ .path = "res/zig.rc" },
        .flags = &.{"/c65001"}, // UTF-8 code page
    });

    _ = exe.getEmittedBin();

    test_step.dependOn(&exe.step);
}
