const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const test1 = b.addTest(.{
        .root_source_file = .{ .path = "test_root/empty.zig" },
        .test_runner = "src/main.zig",
    });
    const test2 = b.addTest(.{
        .root_source_file = .{ .path = "src/empty.zig" },
        .test_runner = "src/main.zig",
    });
    const test3 = b.addTest(.{
        .root_source_file = .{ .path = "empty.zig" },
        .test_runner = "src/main.zig",
    });

    test_step.dependOn(&b.addRunArtifact(test1).step);
    test_step.dependOn(&b.addRunArtifact(test2).step);
    test_step.dependOn(&b.addRunArtifact(test3).step);
}
