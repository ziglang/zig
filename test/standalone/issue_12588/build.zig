const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const optimize: std.builtin.OptimizeMode = .Debug;
    const target: std.zig.CrossTarget = .{};

    const obj = b.addObject(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = target,
    });
    obj.emit_llvm_ir = .{ .emit_to = b.pathFromRoot("main.ll") };
    obj.emit_llvm_bc = .{ .emit_to = b.pathFromRoot("main.bc") };
    obj.emit_bin = .no_emit;
    b.default_step.dependOn(&obj.step);

    test_step.dependOn(&obj.step);
}
