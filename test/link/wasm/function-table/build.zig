const std = @import("std");

pub const requires_stage2 = true;

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    add(b, test_step, .Debug);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize: std.builtin.OptimizeMode) void {
    const export_table = b.addExecutable(.{
        .name = "export_table",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = optimize,
        }),
    });
    export_table.entry = .disabled;
    export_table.use_llvm = false;
    export_table.use_lld = false;
    export_table.export_table = true;
    export_table.link_gc_sections = false;

    const regular_table = b.addExecutable(.{
        .name = "regular_table",
        .root_module = b.createModule(.{
            .root_source_file = b.path("lib.zig"),
            .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
            .optimize = optimize,
        }),
    });
    regular_table.entry = .disabled;
    regular_table.use_llvm = false;
    regular_table.use_lld = false;
    regular_table.link_gc_sections = false; // Ensure function table is not empty

    const check_export = export_table.checkObject();
    const check_regular = regular_table.checkObject();

    check_export.checkInHeaders();
    check_export.checkExact("Section export");
    check_export.checkExact("entries 2");
    check_export.checkExact("name __indirect_function_table"); // as per linker specification
    check_export.checkExact("kind table");

    check_regular.checkInHeaders();
    check_regular.checkExact("Section table");
    check_regular.checkExact("entries 1");
    check_regular.checkExact("type funcref");
    check_regular.checkExact("min 2"); // index starts at 1 & 1 function pointer = 2.
    check_regular.checkExact("max 2");

    check_regular.checkInHeaders();
    check_regular.checkExact("Section element");
    check_regular.checkExact("entries 1");
    check_regular.checkExact("table index 0");
    check_regular.checkExact("i32.const 1"); // we want to start function indexes at 1
    check_regular.checkExact("indexes 1"); // 1 function pointer

    test_step.dependOn(&check_export.step);
    test_step.dependOn(&check_regular.step);
}
