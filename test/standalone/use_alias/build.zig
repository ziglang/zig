const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;

    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
    });
    main.addIncludePath(.{ .path = "." });

    test_step.dependOn(&b.addRunArtifact(main).step);
}
