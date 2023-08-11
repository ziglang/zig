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
    const import_table = b.addSharedLibrary(.{
        .name = "import_table",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    import_table.use_llvm = false;
    import_table.use_lld = false;
    import_table.import_table = true;

    const export_table = b.addSharedLibrary(.{
        .name = "export_table",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    export_table.use_llvm = false;
    export_table.use_lld = false;
    export_table.export_table = true;

    const regular_table = b.addSharedLibrary(.{
        .name = "regular_table",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    regular_table.use_llvm = false;
    regular_table.use_lld = false;

    const check_import = import_table.checkObject();
    const check_export = export_table.checkObject();
    const check_regular = regular_table.checkObject();

    check_import.checkStart();
    check_import.checkExact("Section import");
    check_import.checkExact("entries 1");
    check_import.checkExact("module env");
    check_import.checkExact("name __indirect_function_table");
    check_import.checkExact("kind table");
    check_import.checkExact("type funcref");
    check_import.checkExact("min 1"); // 1 function pointer
    check_import.checkNotPresent("max"); // when importing, we do not provide a max
    check_import.checkNotPresent("Section table"); // we're importing it

    check_export.checkStart();
    check_export.checkExact("Section export");
    check_export.checkExact("entries 2");
    check_export.checkExact("name __indirect_function_table"); // as per linker specification
    check_export.checkExact("kind table");

    check_regular.checkStart();
    check_regular.checkExact("Section table");
    check_regular.checkExact("entries 1");
    check_regular.checkExact("type funcref");
    check_regular.checkExact("min 2"); // index starts at 1 & 1 function pointer = 2.
    check_regular.checkExact("max 2");

    check_regular.checkStart();
    check_regular.checkExact("Section element");
    check_regular.checkExact("entries 1");
    check_regular.checkExact("table index 0");
    check_regular.checkExact("i32.const 1"); // we want to start function indexes at 1
    check_regular.checkExact("indexes 1"); // 1 function pointer

    test_step.dependOn(&check_import.step);
    test_step.dependOn(&check_export.step);
    test_step.dependOn(&check_regular.step);
}
