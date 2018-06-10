const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const exe = b.addExecutable("test", "test.zig");
    exe.setBuildMode(b.standardReleaseOptions());

    const lib = b.addStaticLibrary("lib", "lib.zig");
    lib.setBuildMode(builtin.Mode.ReleaseSmall);
    lib.setTarget(builtin.Arch.wasm32, builtin.Os.freestanding, builtin.Environ.unknown);

    const run = b.addCommand(".", b.env_map, [][]const u8{exe.getOutputPath()});
    run.step.dependOn(&exe.step);
    run.step.dependOn(&lib.step);

    const test_step = b.step("test", "Test it");
    test_step.dependOn(&run.step);
}
