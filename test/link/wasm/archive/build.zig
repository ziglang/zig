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
    const lib = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .optimize = optimize,
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .strip = false,
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.root_module.export_symbol_names = &.{"foo"};

    const check = lib.checkObject();
    check.checkInHeaders();
    check.checkExact("Section custom");
    check.checkExact("name __trunch"); // Ensure it was imported and resolved

    test_step.dependOn(&check.step);
}
