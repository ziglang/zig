const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("extern", "main.zig");
    exe.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    exe.setBuildMode(mode);
    exe.addCSourceFile("foo.c", &.{});
    exe.use_llvm = false;
    exe.use_lld = false;

    const run = exe.runEmulatable();
    run.expectStdOutEqual("Result: 30");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&run.step);
}
