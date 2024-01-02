const std = @import("std");

pub const requires_symlinks = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const target = b.resolveTargetQuery(.{ .os_tag = .macos });

    const lib = b.addSharedLibrary(.{
        .name = "a",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = .Debug,
        .target = target,
    });

    const check = lib.checkObject();
    check.checkInSymtab();
    check.checkNotPresent("external _abc");

    test_step.dependOn(&check.step);
}
