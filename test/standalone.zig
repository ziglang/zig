pub const SimpleCase = struct {
    src_path: []const u8,
    link_libc: bool = false,
    all_modes: bool = false,
    target: std.zig.CrossTarget = .{},
    is_test: bool = false,
    is_exe: bool = true,
    /// Run only on this OS.
    os_filter: ?std.Target.Os.Tag = null,
};

pub const BuildCase = struct {
    build_root: []const u8,
    import: type,
};

pub const simple_cases = [_]SimpleCase{
    .{
        .src_path = "test/standalone/hello_world/hello.zig",
        .all_modes = true,
    },
    .{
        .src_path = "test/standalone/hello_world/hello_libc.zig",
        .link_libc = true,
        .all_modes = true,
    },
    .{
        .src_path = "test/standalone/cat/main.zig",
    },
    // https://github.com/ziglang/zig/issues/6025
    //.{
    //    .src_path = "test/standalone/issue_9693/main.zig",
    //},
    .{
        .src_path = "test/standalone/brace_expansion.zig",
        .is_test = true,
    },
    .{
        .src_path = "test/standalone/issue_7030.zig",
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    },

    .{ .src_path = "test/standalone/issue_12471/main.zig" },
    .{ .src_path = "test/standalone/guess_number/main.zig" },
    .{ .src_path = "test/standalone/main_return_error/error_u8.zig" },
    .{ .src_path = "test/standalone/main_return_error/error_u8_non_zero.zig" },
    .{ .src_path = "test/standalone/noreturn_call/inline.zig" },
    .{ .src_path = "test/standalone/noreturn_call/as_arg.zig" },

    .{
        .src_path = "test/standalone/issue_9402/main.zig",
        .os_filter = .windows,
        .link_libc = true,
    },
    .{
        .src_path = "test/standalone/http.zig",
        .all_modes = true,
    },

    // Ensure the development tools are buildable. Alphabetically sorted.
    // No need to build `tools/spirv/grammar.zig`.
    .{ .src_path = "tools/extract-grammar.zig" },
    .{ .src_path = "tools/gen_outline_atomics.zig" },
    .{ .src_path = "tools/gen_spirv_spec.zig" },
    .{ .src_path = "tools/gen_stubs.zig" },
    .{ .src_path = "tools/generate_linux_syscalls.zig" },
    .{ .src_path = "tools/process_headers.zig" },
    .{ .src_path = "tools/update-license-headers.zig" },
    .{ .src_path = "tools/update-linux-headers.zig" },
    .{ .src_path = "tools/update_clang_options.zig" },
    .{ .src_path = "tools/update_cpu_features.zig" },
    .{ .src_path = "tools/update_glibc.zig" },
    .{ .src_path = "tools/update_spirv_features.zig" },
};

pub const build_cases = [_]BuildCase{
    .{
        .build_root = "test/standalone/test_runner_path",
        .import = @import("standalone/test_runner_path/build.zig"),
    },
    .{
        .build_root = "test/standalone/test_runner_module_imports",
        .import = @import("standalone/test_runner_module_imports/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_13970",
        .import = @import("standalone/issue_13970/build.zig"),
    },
    .{
        .build_root = "test/standalone/main_pkg_path",
        .import = @import("standalone/main_pkg_path/build.zig"),
    },
    .{
        .build_root = "test/standalone/shared_library",
        .import = @import("standalone/shared_library/build.zig"),
    },
    .{
        .build_root = "test/standalone/mix_o_files",
        .import = @import("standalone/mix_o_files/build.zig"),
    },
    .{
        .build_root = "test/standalone/mix_c_files",
        .import = @import("standalone/mix_c_files/build.zig"),
    },
    .{
        .build_root = "test/standalone/global_linkage",
        .import = @import("standalone/global_linkage/build.zig"),
    },
    .{
        .build_root = "test/standalone/static_c_lib",
        .import = @import("standalone/static_c_lib/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_339",
        .import = @import("standalone/issue_339/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_8550",
        .import = @import("standalone/issue_8550/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_794",
        .import = @import("standalone/issue_794/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_5825",
        .import = @import("standalone/issue_5825/build.zig"),
    },
    .{
        .build_root = "test/standalone/pkg_import",
        .import = @import("standalone/pkg_import/build.zig"),
    },
    .{
        .build_root = "test/standalone/use_alias",
        .import = @import("standalone/use_alias/build.zig"),
    },
    .{
        .build_root = "test/standalone/install_raw_hex",
        .import = @import("standalone/install_raw_hex/build.zig"),
    },
    // TODO take away EmitOption.emit_to option and make it give a FileSource
    //.{
    //    .build_root = "test/standalone/emit_asm_and_bin",
    //    .import = @import("standalone/emit_asm_and_bin/build.zig"),
    //},
    // TODO take away EmitOption.emit_to option and make it give a FileSource
    //.{
    //    .build_root = "test/standalone/issue_12588",
    //    .import = @import("standalone/issue_12588/build.zig"),
    //},
    .{
        .build_root = "test/standalone/embed_generated_file",
        .import = @import("standalone/embed_generated_file/build.zig"),
    },
    .{
        .build_root = "test/standalone/extern",
        .import = @import("standalone/extern/build.zig"),
    },
    .{
        .build_root = "test/standalone/dep_diamond",
        .import = @import("standalone/dep_diamond/build.zig"),
    },
    .{
        .build_root = "test/standalone/dep_triangle",
        .import = @import("standalone/dep_triangle/build.zig"),
    },
    .{
        .build_root = "test/standalone/dep_recursive",
        .import = @import("standalone/dep_recursive/build.zig"),
    },
    .{
        .build_root = "test/standalone/dep_mutually_recursive",
        .import = @import("standalone/dep_mutually_recursive/build.zig"),
    },
    .{
        .build_root = "test/standalone/dep_shared_builtin",
        .import = @import("standalone/dep_shared_builtin/build.zig"),
    },
    .{
        .build_root = "test/standalone/empty_env",
        .import = @import("standalone/empty_env/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_11595",
        .import = @import("standalone/issue_11595/build.zig"),
    },
    .{
        .build_root = "test/standalone/load_dynamic_library",
        .import = @import("standalone/load_dynamic_library/build.zig"),
    },
    .{
        .build_root = "test/standalone/windows_spawn",
        .import = @import("standalone/windows_spawn/build.zig"),
    },
    .{
        .build_root = "test/standalone/c_compiler",
        .import = @import("standalone/c_compiler/build.zig"),
    },
    .{
        .build_root = "test/standalone/pie",
        .import = @import("standalone/pie/build.zig"),
    },
    .{
        .build_root = "test/standalone/issue_12706",
        .import = @import("standalone/issue_12706/build.zig"),
    },
    // TODO This test is disabled for doing naughty things in the build script.
    // The logic needs to get moved to a child process instead of build.zig.
    //.{
    //    .build_root = "test/standalone/sigpipe",
    //    .import = @import("standalone/sigpipe/build.zig"),
    //},
    .{
        .build_root = "test/standalone/issue_13030",
        .import = @import("standalone/issue_13030/build.zig"),
    },
    // TODO restore this test
    //.{
    //    .build_root = "test/standalone/options",
    //    .import = @import("standalone/options/build.zig"),
    //},
    .{
        .build_root = "test/standalone/strip_empty_loop",
        .import = @import("standalone/strip_empty_loop/build.zig"),
    },
};

const std = @import("std");
