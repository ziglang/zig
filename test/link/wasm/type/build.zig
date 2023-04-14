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
    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;
    b.installArtifact(lib);

    const check_lib = lib.checkObject();
    check_lib.checkStart("Section type");
    // only 3 entries, although we have more functions.
    // This is to test functions with the same function signature
    // have their types deduplicated.
    check_lib.checkNext("entries 3");
    check_lib.checkNext("params 1");
    check_lib.checkNext("type i32");
    check_lib.checkNext("returns 1");
    check_lib.checkNext("type i64");
    check_lib.checkNext("params 0");
    check_lib.checkNext("returns 0");

    test_step.dependOn(&check_lib.step);
}
