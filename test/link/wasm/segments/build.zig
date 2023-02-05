const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = b.standardOptimizeOption(.{}),
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;
    lib.install();

    const check_lib = lib.checkObject(.wasm);
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
