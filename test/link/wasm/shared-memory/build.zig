const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    add(b, test_step, .Debug);
    add(b, test_step, .ReleaseFast);
    add(b, test_step, .ReleaseSmall);
    add(b, test_step, .ReleaseSafe);
}

fn add(b: *std.Build, test_step: *std.Build.Step, optimize_mode: std.builtin.OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "lib",
        .root_source_file = b.path("lib.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
            .cpu_features_add = std.Target.wasm.featureSet(&.{ .atomics, .bulk_memory }),
            .os_tag = .freestanding,
        }),
        .optimize = optimize_mode,
        .strip = false,
        .single_threaded = false,
    });
    exe.entry = .disabled;
    exe.use_lld = false;
    exe.import_memory = true;
    exe.export_memory = true;
    exe.shared_memory = true;
    exe.max_memory = 67108864;
    exe.root_module.export_symbol_names = &.{"foo"};

    const check_exe = exe.checkObject();

    check_exe.checkInHeaders();
    check_exe.checkExact("Section import");
    check_exe.checkExact("entries 1");
    check_exe.checkExact("module env");
    check_exe.checkExact("name memory"); // ensure we are importing memory

    check_exe.checkInHeaders();
    check_exe.checkExact("Section export");
    check_exe.checkExact("entries 2");
    check_exe.checkExact("name memory"); // ensure we also export memory again

    // This section *must* be emit as the start function is set to the index
    // of __wasm_init_memory
    // release modes will have the TLS segment optimized out in our test-case.
    // This means we won't have __wasm_init_memory in such case, and therefore
    // should also not have a section "start"
    if (optimize_mode == .Debug) {
        check_exe.checkInHeaders();
        check_exe.checkExact("Section start");
    }

    // This section is only and *must* be emit when shared-memory is enabled
    // release modes will have the TLS segment optimized out in our test-case.
    if (optimize_mode == .Debug) {
        check_exe.checkInHeaders();
        check_exe.checkExact("Section data_count");
        check_exe.checkExact("count 1");
    }

    check_exe.checkInHeaders();
    check_exe.checkExact("Section custom");
    check_exe.checkExact("name name");
    check_exe.checkExact("type function");
    if (optimize_mode == .Debug) {
        check_exe.checkExact("name __wasm_init_memory");
    }
    check_exe.checkExact("name __wasm_init_tls");
    check_exe.checkExact("type global");

    // In debug mode the symbol __tls_base is resolved to an undefined symbol
    // from the object file, hence its placement differs than in release modes
    // where the entire tls segment is optimized away, and tls_base will have
    // its original position.
    check_exe.checkExact("name __tls_base");
    check_exe.checkExact("name __tls_size");
    check_exe.checkExact("name __tls_align");

    check_exe.checkExact("type data_segment");
    if (optimize_mode == .Debug) {
        check_exe.checkExact("names 1");
        check_exe.checkExact("index 0");
        check_exe.checkExact("name .tdata");
    }

    test_step.dependOn(&check_exe.step);
}
