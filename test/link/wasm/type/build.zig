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
    const exe = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("lib.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
        .strip = false,
    });
    exe.entry = .disabled;
    exe.use_llvm = false;
    exe.use_lld = false;
    exe.root_module.export_symbol_names = &.{"foo"};
    b.installArtifact(exe);

    const check_exe = exe.checkObject();
    check_exe.checkInHeaders();
    check_exe.checkExact("Section type");
    // only 2 entries, although we have more functions.
    // This is to test functions with the same function signature
    // have their types deduplicated.
    check_exe.checkExact("entries 2");
    check_exe.checkExact("params 1");
    check_exe.checkExact("type i32");
    check_exe.checkExact("returns 1");
    check_exe.checkExact("type i64");
    check_exe.checkExact("params 0");
    check_exe.checkExact("returns 0");

    test_step.dependOn(&check_exe.step);
}
