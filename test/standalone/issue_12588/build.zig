const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const obj = b.addObject("main", "main.zig");
    obj.setBuildMode(mode);
    obj.setTarget(target);
    obj.emit_llvm_ir = .{ .emit_to = b.pathFromRoot("main.ll") };
    obj.emit_llvm_bc = .{ .emit_to = b.pathFromRoot("main.bc") };
    obj.emit_bin = .no_emit;
    b.default_step.dependOn(&obj.step);

    const test_step = b.step("test", "Test the program");
    test_step.dependOn(&obj.step);
}
