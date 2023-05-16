const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
    });
    main.emit_asm = .{ .emit_to = b.pathFromRoot("main.s") };
    main.emit_bin = .{ .emit_to = b.pathFromRoot("main") };

    test_step.dependOn(&b.addRunArtifact(main).step);
}
