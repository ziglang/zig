const std = @import("std");
const builtin = @import("builtin");
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.StandaloneContext) void {
    cases.addBuildFile("test/link/bss/build.zig", .{
        .build_modes = false, // we only guarantee zerofill for undefined in Debug
    });

    cases.addBuildFile("test/link/common_symbols/build.zig", .{
        .build_modes = true,
    });

    cases.addBuildFile("test/link/common_symbols_alignment/build.zig", .{
        .build_modes = true,
    });

    cases.addBuildFile("test/link/interdependent_static_c_libs/build.zig", .{
        .build_modes = true,
    });

    cases.addBuildFile("test/link/static_lib_as_system_lib/build.zig", .{
        .build_modes = true,
    });

    addWasmCases(cases);
    addMachOCases(cases);
}

fn addWasmCases(cases: *tests.StandaloneContext) void {
    cases.addBuildFile("test/link/wasm/archive/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/basic-features/build.zig", .{
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/bss/build.zig", .{
        .build_modes = false,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/export/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    // TODO: Fix open handle in wasm-linker refraining rename from working on Windows.
    if (builtin.os.tag != .windows) {
        cases.addBuildFile("test/link/wasm/export-data/build.zig", .{});
    }

    cases.addBuildFile("test/link/wasm/extern/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
        .use_emulation = true,
    });

    cases.addBuildFile("test/link/wasm/extern-mangle/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/function-table/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/infer-features/build.zig", .{
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/producers/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/segments/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/stack_pointer/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });

    cases.addBuildFile("test/link/wasm/type/build.zig", .{
        .build_modes = true,
        .requires_stage2 = true,
    });
}

fn addMachOCases(cases: *tests.StandaloneContext) void {
    cases.addBuildFile("test/link/macho/bugs/13056/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/bugs/13457/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/dead_strip/build.zig", .{
        .build_modes = false,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/dead_strip_dylibs/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/dylib/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/empty/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/entry/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/headerpad/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/linksection/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/needed_framework/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/needed_library/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/objc/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/objcpp/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/pagezero/build.zig", .{
        .build_modes = false,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/search_strategy/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/stack_size/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/strict_validation/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/tls/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/unwind_info/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/uuid/build.zig", .{
        .build_modes = false,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/weak_library/build.zig", .{
        .build_modes = true,
        .requires_symlinks = true,
    });

    cases.addBuildFile("test/link/macho/weak_framework/build.zig", .{
        .build_modes = true,
        .requires_macos_sdk = true,
        .requires_symlinks = true,
    });
}
