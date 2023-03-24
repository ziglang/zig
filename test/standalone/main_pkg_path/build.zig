const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const test_exe = b.addTest(.{
        .root_source_file = .{ .path = "a/test.zig" },
    });
    test_exe.setMainPkgPath(".");

    test_step.dependOn(&test_exe.run().step);
}
