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
    check_lib.checkStart("Section data");
    check_lib.checkNext("entries 2"); // rodata & data, no bss because we're exporting memory

    check_lib.checkStart("Section custom");
    check_lib.checkStart("name name"); // names custom section
    check_lib.checkStart("type data_segment");
    check_lib.checkNext("names 2");
    check_lib.checkNext("index 0");
    check_lib.checkNext("name .rodata");
    check_lib.checkNext("index 1");
    check_lib.checkNext("name .data");
    test_step.dependOn(&check_lib.step);
}
