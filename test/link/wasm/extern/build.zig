const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "extern",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
        .target = .{ .cpu_arch = .wasm32, .os_tag = .wasi },
    });
    exe.addCSourceFile("foo.c", &.{});
    exe.use_llvm = false;
    exe.use_lld = false;

    const run = exe.runEmulatable();
    run.expectStdOutEqual("Result: 30");

    const test_step = b.step("test", "Run linker test");
    test_step.dependOn(&run.step);
}
