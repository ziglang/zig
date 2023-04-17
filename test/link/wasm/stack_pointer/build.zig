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
    lib.stack_size = std.wasm.page_size * 2; // set an explicit stack size
    b.installArtifact(lib);

    const check_lib = lib.checkObject();

    // ensure global exists and its initial value is equal to explitic stack size
    check_lib.checkStart("Section global");
    check_lib.checkNext("entries 1");
    check_lib.checkNext("type i32"); // on wasm32 the stack pointer must be i32
    check_lib.checkNext("mutable true"); // must be able to mutate the stack pointer
    check_lib.checkNext("i32.const {stack_pointer}");
    check_lib.checkComputeCompare("stack_pointer", .{ .op = .eq, .value = .{ .literal = lib.stack_size.? } });

    // validate memory section starts after virtual stack
    check_lib.checkNext("Section data");
    check_lib.checkNext("i32.const {data_start}");
    check_lib.checkComputeCompare("data_start", .{ .op = .eq, .value = .{ .variable = "stack_pointer" } });

    // validate the name of the stack pointer
    check_lib.checkStart("Section custom");
    check_lib.checkNext("type global");
    check_lib.checkNext("names 1");
    check_lib.checkNext("index 0");
    check_lib.checkNext("name __stack_pointer");
    test_step.dependOn(&check_lib.step);
}
