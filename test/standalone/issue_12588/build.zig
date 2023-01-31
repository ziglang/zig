const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

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

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&obj.step);
}
