pub const SimpleCase = struct {
    src_path: []const u8,
    link_libc: bool = false,
    all_modes: bool = false,
    target: std.Target.Query = .{},
    is_test: bool = false,
    is_exe: bool = true,
    /// Run only on this OS.
    os_filter: ?std.Target.Os.Tag = null,
};

pub const simple_cases = [_]SimpleCase{
    .{
        .src_path = "test/standalone/simple/hello_world/hello.zig",
        .all_modes = true,
    },
    .{
        .src_path = "test/standalone/simple/hello_world/hello_libc.zig",
        .link_libc = true,
        .all_modes = true,
    },
    .{
        .src_path = "test/standalone/simple/cat/main.zig",
    },
    // https://github.com/ziglang/zig/issues/6025
    //.{
    //    .src_path = "test/standalone/simple/issue_9693/main.zig",
    //},
    .{
        .src_path = "test/standalone/simple/brace_expansion.zig",
        .is_test = true,
    },
    .{
        .src_path = "test/standalone/simple/issue_7030.zig",
        .target = .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
        },
    },

    .{ .src_path = "test/standalone/simple/issue_12471/main.zig" },
    .{ .src_path = "test/standalone/simple/guess_number/main.zig" },
    .{ .src_path = "test/standalone/simple/main_return_error/error_u8.zig" },
    .{ .src_path = "test/standalone/simple/main_return_error/error_u8_non_zero.zig" },
    .{ .src_path = "test/standalone/simple/noreturn_call/inline.zig" },
    .{ .src_path = "test/standalone/simple/noreturn_call/as_arg.zig" },
    .{ .src_path = "test/standalone/simple/std_enums_big_enums.zig" },

    .{
        .src_path = "test/standalone/simple/issue_9402/main.zig",
        .os_filter = .windows,
        .link_libc = true,
    },

    // Ensure the development tools are buildable. Alphabetically sorted.
    // No need to build `tools/spirv/grammar.zig`.
    .{ .src_path = "tools/gen_outline_atomics.zig" },
    .{ .src_path = "tools/gen_spirv_spec.zig" },
    .{ .src_path = "tools/gen_stubs.zig" },
    .{ .src_path = "tools/generate_linux_syscalls.zig" },
    .{ .src_path = "tools/process_headers.zig" },
    .{ .src_path = "tools/update-linux-headers.zig" },
    .{ .src_path = "tools/update_clang_options.zig" },
    .{ .src_path = "tools/update_cpu_features.zig" },
    .{ .src_path = "tools/update_glibc.zig" },
    .{ .src_path = "tools/update_spirv_features.zig" },
};

const std = @import("std");
