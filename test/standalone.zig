const std = @import("std");
const builtin = @import("builtin");
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.StandaloneContext) void {
    cases.add("test/standalone/hello_world/hello.zig");
    cases.addC("test/standalone/hello_world/hello_libc.zig");

    cases.addBuildFile("test/standalone/options/build.zig", .{
        .extra_argv = &.{
            "-Dbool_true",
            "-Dbool_false=false",
            "-Dint=1234",
            "-De=two",
            "-Dstring=hello",
        },
    });

    cases.add("test/standalone/cat/main.zig");
    if (builtin.zig_backend == .stage1) { // https://github.com/ziglang/zig/issues/6025
        cases.add("test/standalone/issue_9693/main.zig");
    }
    cases.add("test/standalone/issue_12471/main.zig");
    cases.add("test/standalone/guess_number/main.zig");
    cases.add("test/standalone/main_return_error/error_u8.zig");
    cases.add("test/standalone/main_return_error/error_u8_non_zero.zig");
    cases.add("test/standalone/noreturn_call/inline.zig");
    cases.add("test/standalone/noreturn_call/as_arg.zig");
    cases.addBuildFile("test/standalone/test_runner_path/build.zig", .{ .requires_stage2 = true });
    cases.addBuildFile("test/standalone/main_pkg_path/build.zig", .{});
    cases.addBuildFile("test/standalone/shared_library/build.zig", .{});
    cases.addBuildFile("test/standalone/mix_o_files/build.zig", .{});
    cases.addBuildFile("test/standalone/mix_c_files/build.zig", .{
        .build_modes = true,
        .cross_targets = true,
    });
    cases.addBuildFile("test/standalone/global_linkage/build.zig", .{});
    cases.addBuildFile("test/standalone/static_c_lib/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_339/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_8550/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_794/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_5825/build.zig", .{});
    cases.addBuildFile("test/standalone/pkg_import/build.zig", .{});
    cases.addBuildFile("test/standalone/use_alias/build.zig", .{});
    cases.addBuildFile("test/standalone/brace_expansion/build.zig", .{});
    if (builtin.os.tag != .windows or builtin.cpu.arch != .aarch64) {
        // https://github.com/ziglang/zig/issues/13685
        cases.addBuildFile("test/standalone/empty_env/build.zig", .{});
    }
    cases.addBuildFile("test/standalone/issue_7030/build.zig", .{});
    cases.addBuildFile("test/standalone/install_raw_hex/build.zig", .{});
    if (builtin.zig_backend == .stage1) { // https://github.com/ziglang/zig/issues/12194
        cases.addBuildFile("test/standalone/issue_9812/build.zig", .{});
    }
    if (builtin.os.tag != .windows) {
        // https://github.com/ziglang/zig/issues/12419
        cases.addBuildFile("test/standalone/issue_11595/build.zig", .{});
    }

    if (builtin.os.tag != .wasi and
        // https://github.com/ziglang/zig/issues/13550
        (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) and
        // https://github.com/ziglang/zig/issues/13686
        (builtin.os.tag != .windows or builtin.cpu.arch != .aarch64))
    {
        cases.addBuildFile("test/standalone/load_dynamic_library/build.zig", .{});
    }

    if (builtin.os.tag == .windows) {
        cases.addBuildFile("test/standalone/windows_spawn/build.zig", .{});
    }

    cases.addBuildFile("test/standalone/c_compiler/build.zig", .{
        .build_modes = true,
        .cross_targets = true,
    });

    if (builtin.os.tag == .windows) {
        cases.addC("test/standalone/issue_9402/main.zig");
    }
    // Try to build and run a PIE executable.
    if (builtin.os.tag == .linux) {
        cases.addBuildFile("test/standalone/pie/build.zig", .{});
    }
    cases.addBuildFile("test/standalone/issue_12706/build.zig", .{});

    // Ensure the development tools are buildable. Alphabetically sorted.
    // No need to build `tools/spirv/grammar.zig`.
    cases.add("tools/extract-grammar.zig");
    cases.add("tools/gen_outline_atomics.zig");
    cases.add("tools/gen_spirv_spec.zig");
    cases.add("tools/gen_stubs.zig");
    cases.add("tools/generate_linux_syscalls.zig");
    cases.add("tools/process_headers.zig");
    cases.add("tools/update-license-headers.zig");
    cases.add("tools/update-linux-headers.zig");
    cases.add("tools/update_clang_options.zig");
    cases.add("tools/update_cpu_features.zig");
    cases.add("tools/update_glibc.zig");
    cases.add("tools/update_spirv_features.zig");

    cases.addBuildFile("test/standalone/issue_13030/build.zig", .{ .build_modes = true });
    cases.addBuildFile("test/standalone/emit_asm_and_bin/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_12588/build.zig", .{});
    cases.addBuildFile("test/standalone/embed_generated_file/build.zig", .{});
}
