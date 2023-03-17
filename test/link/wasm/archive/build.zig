const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    // The code in question will pull-in compiler-rt,
    // and therefore link with its archive file.
    const lib = b.addSharedLibrary(.{
        .name = "main",
        .root_source_file = .{ .path = "main.zig" },
        .optimize = optimize,
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;

    const check = lib.checkObject();
    check.checkStart("Section custom");
    check.checkNext("name __truncsfhf2"); // Ensure it was imported and resolved

    test_step.dependOn(&check.step);
}
