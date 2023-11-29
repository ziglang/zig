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
    check_lib.checkExact("Section data");
    check_lib.checkExact("entries 2"); // rodata & data, no bss because we're exporting memory

    check_lib.checkStart();
    check_lib.checkExact("Section custom");
    check_lib.checkStart();
    check_lib.checkExact("name name"); // names custom section
    check_lib.checkStart();
    check_lib.checkExact("type data_segment");
    check_lib.checkExact("names 2");
    check_lib.checkExact("index 0");
    check_lib.checkExact("name .rodata");
    check_lib.checkExact("index 1");
    check_lib.checkExact("name .data");
    test_step.dependOn(&check_lib.step);
}
