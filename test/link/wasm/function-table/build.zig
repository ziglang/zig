const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Test");
    test_step.dependOn(b.getInstallStep());

    const import_table = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    import_table.use_llvm = false;
    import_table.use_lld = false;
    import_table.import_table = true;

    const export_table = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    export_table.use_llvm = false;
    export_table.use_lld = false;
    export_table.export_table = true;

    const regular_table = b.addSharedLibrary(.{
        .name = "lib",
        .root_source_file = .{ .path = "lib.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
        .optimize = optimize,
    });
    regular_table.use_llvm = false;
    regular_table.use_lld = false;

    const check_import = import_table.checkObject(.wasm);
    const check_export = export_table.checkObject(.wasm);
    const check_regular = regular_table.checkObject(.wasm);

    check_import.checkStart("Section import");
    check_import.checkNext("entries 1");
    check_import.checkNext("module env");
    check_import.checkNext("name __indirect_function_table");
    check_import.checkNext("kind table");
    check_import.checkNext("type funcref");
    check_import.checkNext("min 1"); // 1 function pointer
    check_import.checkNotPresent("max"); // when importing, we do not provide a max
    check_import.checkNotPresent("Section table"); // we're importing it

    check_export.checkStart("Section export");
    check_export.checkNext("entries 2");
    check_export.checkNext("name __indirect_function_table"); // as per linker specification
    check_export.checkNext("kind table");

    check_regular.checkStart("Section table");
    check_regular.checkNext("entries 1");
    check_regular.checkNext("type funcref");
    check_regular.checkNext("min 2"); // index starts at 1 & 1 function pointer = 2.
    check_regular.checkNext("max 2");
    check_regular.checkStart("Section element");
    check_regular.checkNext("entries 1");
    check_regular.checkNext("table index 0");
    check_regular.checkNext("i32.const 1"); // we want to start function indexes at 1
    check_regular.checkNext("indexes 1"); // 1 function pointer

    test_step.dependOn(&check_import.step);
    test_step.dependOn(&check_export.step);
    test_step.dependOn(&check_regular.step);
}
