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
    const lib = b.addExecutable(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;
    b.installArtifact(lib);

    const check_lib = lib.checkObject();
    check_lib.checkStart();
    check_lib.checkExact("Section type");
    // only 2 entries, although we have more functions.
    // This is to test functions with the same function signature
    // have their types deduplicated.
    check_lib.checkExact("entries 2");
    check_lib.checkExact("params 1");
    check_lib.checkExact("type i32");
    check_lib.checkExact("returns 1");
    check_lib.checkExact("type i64");
    check_lib.checkExact("params 0");
    check_lib.checkExact("returns 0");

    test_step.dependOn(&check_lib.step);
}
