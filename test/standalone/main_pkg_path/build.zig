const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "a/test.zig" },
        .main_pkg_path = .{ .path = "." },
    });

    test_step.dependOn(&b.addRunArtifact(test_exe).step);
}
