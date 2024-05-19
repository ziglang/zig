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
        .root_source_file = b.path("lib.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
        .strip = false,
    });
    lib.entry = .disabled;
    lib.use_llvm = false;
    lib.use_lld = false;
    lib.stack_size = std.wasm.page_size * 2; // set an explicit stack size
    lib.link_gc_sections = false;
    b.installArtifact(lib);

    const check_lib = lib.checkObject();

    // ensure global exists and its initial value is equal to explitic stack size
    check_lib.checkInHeaders();
    check_lib.checkExact("Section global");
    check_lib.checkExact("entries 1");
    check_lib.checkExact("type i32"); // on wasm32 the stack pointer must be i32
    check_lib.checkExact("mutable true"); // must be able to mutate the stack pointer
    check_lib.checkExtract("i32.const {stack_pointer}");
    check_lib.checkComputeCompare("stack_pointer", .{ .op = .eq, .value = .{ .literal = lib.stack_size.? } });

    // validate memory section starts after virtual stack
    check_lib.checkInHeaders();
    check_lib.checkExact("Section data");
    check_lib.checkExtract("i32.const {data_start}");
    check_lib.checkComputeCompare("data_start", .{ .op = .eq, .value = .{ .variable = "stack_pointer" } });

    // validate the name of the stack pointer
    check_lib.checkInHeaders();
    check_lib.checkExact("Section custom");
    check_lib.checkExact("type global");
    check_lib.checkExact("names 1");
    check_lib.checkExact("index 0");
    check_lib.checkExact("name __stack_pointer");
    test_step.dependOn(&check_lib.step);
}
