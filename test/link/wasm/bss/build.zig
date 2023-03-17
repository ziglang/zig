const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    const lib = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = .Debug,
    });
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.strip = false;
    // to make sure the bss segment is emitted, we must import memory
    lib.import_memory = true;
    lib.install();

    const check_lib = lib.checkObject();

    // since we import memory, make sure it exists with the correct naming
    check_lib.checkStart("Section import");
    check_lib.checkNext("entries 1");
    check_lib.checkNext("module env"); // default module name is "env"
    check_lib.checkNext("name memory"); // as per linker specification

    // since we are importing memory, ensure it's not exported
    check_lib.checkNotPresent("Section export");

    // validate the name of the stack pointer
    check_lib.checkStart("Section custom");
    check_lib.checkNext("type data_segment");
    check_lib.checkNext("names 2");
    check_lib.checkNext("index 0");
    check_lib.checkNext("name .rodata");
    check_lib.checkNext("index 1"); // bss section always last
    check_lib.checkNext("name .bss");

    test_step.dependOn(&check_lib.step);
}
