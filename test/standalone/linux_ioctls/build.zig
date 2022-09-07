const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const exe = b.addExecutable("linux_ioctls", "main.zig");
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_cmd.step);
}
