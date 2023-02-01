const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    // The code in question will pull-in compiler-rt,
    // and therefore link with its archive file.
    const lib = b.addSharedLibrary(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = b.standardOptimizeOption(.{}),
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;

    const check = lib.checkObject(.wasm);
    check.checkStart("Section custom");
    check.checkNext("name __truncsfhf2"); // Ensure it was imported and resolved

    test_step.dependOn(&check.step);
}
