const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    });

    add(b, b.host, .any, test_step);
    add(b, target, .any, test_step);

    add(b, b.host, .gnu, test_step);
    add(b, target, .gnu, test_step);
}

fn add(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    rc_includes: enum { any, gnu },
    test_step: *std.Build.Step,
) void {
    const exe = b.addExecutable(.{
        .name = "zig_resource_test",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = .Debug,
    });
    exe.addWin32ResourceFile(.{
        .file = b.path("res/zig.rc"),
        .flags = &.{"/c65001"}, // UTF-8 code page
    });
    exe.rc_includes = switch (rc_includes) {
        .any => .any,
        .gnu => .gnu,
    };

    _ = exe.getEmittedBin();

    test_step.dependOn(&exe.step);
}
