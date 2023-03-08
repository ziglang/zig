pub const Case = struct {
    build_root: []const u8,
    import: type,
};

pub const cases = [_]Case{
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

    // WASM Cases
    .{
        .build_root = "test/link/wasm/archive",
        .import = @import("link/wasm/archive/build.zig"),
    },
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
    .{
        .build_root = "test/link/wasm/export-data",
        .import = @import("link/wasm/export-data/build.zig"),
    },
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

    // Mach-O Cases
    //    cases.addBuildFile("test/link/macho/bugs/13056/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/bugs/13457/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/dead_strip/build.zig", .{
    //        .build_modes = false,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/dead_strip_dylibs/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/dylib/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/empty/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/entry/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/headerpad/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/linksection/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/needed_framework/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/needed_library/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/objc/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/objcpp/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/pagezero/build.zig", .{
    //        .build_modes = false,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/search_strategy/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/stack_size/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/strict_validation/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/tls/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/unwind_info/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/uuid/build.zig", .{
    //        .build_modes = false,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/weak_library/build.zig", .{
    //        .build_modes = true,
    //        .requires_symlinks = true,
    //    });
    //
    //    cases.addBuildFile("test/link/macho/weak_framework/build.zig", .{
    //        .build_modes = true,
    //        .requires_macos_sdk = true,
    //        .requires_symlinks = true,
    //    });
};

const std = @import("std");
const builtin = @import("builtin");
