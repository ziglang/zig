const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const test_step = b.step("test", "Run unit tests");
    {
        const exe = b.addExecutable("provided_std_streams", "provided_std_streams.zig");
        const run = exe.run();
        test_step.dependOn(&run.step);
    }
}
