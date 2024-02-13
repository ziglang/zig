pub const Case = struct {
    build_root: []const u8,
    import: type,
};

pub const cases = [_]Case{
    .{
        .build_root = "test/link",
        .import = @import("link/link.zig"),
    },

    .{
        .build_root = "test/link/bss",
        .import = @import("link/bss/build.zig"),
    },
    .{
        .build_root = "test/link/common_symbols",
        .import = @import("link/common_symbols/build.zig"),
    },
    .{
        .build_root = "test/link/common_symbols_alignment",
        .import = @import("link/common_symbols_alignment/build.zig"),
    },
    .{
        .build_root = "test/link/interdependent_static_c_libs",
        .import = @import("link/interdependent_static_c_libs/build.zig"),
    },
    .{
        .build_root = "test/link/static_libs_from_object_files",
        .import = @import("link/static_libs_from_object_files/build.zig"),
    },
    .{
        .build_root = "test/link/glibc_compat",
        .import = @import("link/glibc_compat/build.zig"),
    },

    // WASM Cases
    // https://github.com/ziglang/zig/issues/16938
    //.{
    //    .build_root = "test/link/wasm/archive",
    //    .import = @import("link/wasm/archive/build.zig"),
    //},
    .{
        .build_root = "test/link/wasm/basic-features",
        .import = @import("link/wasm/basic-features/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/bss",
        .import = @import("link/wasm/bss/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/export",
        .import = @import("link/wasm/export/build.zig"),
    },
    // https://github.com/ziglang/zig/issues/16937
    //.{
    //    .build_root = "test/link/wasm/export-data",
    //    .import = @import("link/wasm/export-data/build.zig"),
    //},
    .{
        .build_root = "test/link/wasm/extern",
        .import = @import("link/wasm/extern/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/extern-mangle",
        .import = @import("link/wasm/extern-mangle/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/function-table",
        .import = @import("link/wasm/function-table/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/infer-features",
        .import = @import("link/wasm/infer-features/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/producers",
        .import = @import("link/wasm/producers/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/segments",
        .import = @import("link/wasm/segments/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/stack_pointer",
        .import = @import("link/wasm/stack_pointer/build.zig"),
    },
    .{
        .build_root = "test/link/wasm/type",
        .import = @import("link/wasm/type/build.zig"),
    },
};
