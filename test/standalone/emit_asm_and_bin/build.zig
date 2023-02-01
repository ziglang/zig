const std = @import("std");

pub fn build(b: *std.Build) void {
    const main = b.addTest(.{
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
    });
    main.emit_asm = .{ .emit_to = b.pathFromRoot("main.s") };
    main.emit_bin = .{ .emit_to = b.pathFromRoot("main") };

    const test_step = b.step("test", "Run test");
    test_step.dependOn(&main.step);
}
