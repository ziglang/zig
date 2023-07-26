const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
    });
    main.forceEmit(.bin);
    main.forceEmit(.@"asm");

    test_step.dependOn(&b.addRunArtifact(main).step);
}
