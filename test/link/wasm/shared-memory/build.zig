const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    add(b, test_step, .Debug);

    // Enable the following build modes once garbage-collection is implemented properly.
    // add(b, test_step, .ReleaseFast);
    // add(b, test_step, .ReleaseSmall);
    // add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize_mode: std.builtin.OptimizeMode) void {
    {
        const lib = b.addSharedLibrary(.{
            .name = "lib",
            .root_source_file = .{ .path = "lib.zig" },
            .target = .{
                .cpu_arch = .wasm32,
                .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
                .cpu_features_add = std.Target.wasm.featureSet(&.{ .atomics, .bulk_memory }),
                .os_tag = .freestanding,
            },
            .optimize = optimize_mode,
        });
        lib.use_lld = false;
        lib.strip = false;
        lib.import_memory = true;
        lib.export_memory = true;
        lib.shared_memory = true;
        lib.max_memory = 67108864;
        lib.single_threaded = false;
        lib.export_symbol_names = &.{"foo"};

        const check_lib = lib.checkObject();

        check_lib.checkStart("Section import");
        check_lib.checkNext("entries 1");
        check_lib.checkNext("module env");
        check_lib.checkNext("name memory"); // ensure we are importing memory

        check_lib.checkStart("Section export");
        check_lib.checkNext("entries 2");
        check_lib.checkNext("name memory"); // ensure we also export memory again

        // This section *must* be emit as the start function is set to the index
        // of __wasm_init_memory
        check_lib.checkStart("Section start");

        // This section is only and *must* be emit when shared-memory is enabled
        check_lib.checkStart("Section data_count");
        check_lib.checkNext("count 3");

        check_lib.checkStart("Section custom");
        check_lib.checkNext("name name");
        check_lib.checkNext("type function");
        check_lib.checkNext("name __wasm_init_memory");
        check_lib.checkNext("name __wasm_init_tls");
        check_lib.checkNext("type global");
        check_lib.checkNext("name __tls_size");
        check_lib.checkNext("name __tls_align");
        check_lib.checkNext("name __tls_base");

        check_lib.checkNext("type data_segment");
        check_lib.checkNext("names 3");
        check_lib.checkNext("index 0");
        check_lib.checkNext("name .rodata");
        check_lib.checkNext("index 1");
        check_lib.checkNext("name .bss");
        check_lib.checkNext("index 2");
        check_lib.checkNext("name .tdata");

        test_step.dependOn(&check_lib.step);
    }
}
