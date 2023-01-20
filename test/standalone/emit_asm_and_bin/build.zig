const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const main = b.addTest("main.zig");
    main.setBuildMode(b.standardReleaseOptions());
    main.emit_asm = .{ .emit_to = b.pathFromRoot("main.s") };
    main.emit_bin = .{ .emit_to = b.pathFromRoot("main") };

    const test_step = b.step("test", "Run test");
    test_step.dependOn(&main.step);
}
