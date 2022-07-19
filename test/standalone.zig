const std = @import("std");
const builtin = @import("builtin");
const tests = @import("tests.zig");

pub fn addCases(cases: *tests.StandaloneContext) void {
    cases.add("test/standalone/hello_world/hello.zig");
    cases.addC("test/standalone/hello_world/hello_libc.zig");
    cases.add("test/standalone/cat/main.zig");
    cases.add("test/standalone/issue_9693/main.zig");
    cases.add("test/standalone/guess_number/main.zig");
    cases.add("test/standalone/main_return_error/error_u8.zig");
    cases.add("test/standalone/main_return_error/error_u8_non_zero.zig");
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
    cases.addBuildFile("test/standalone/empty_env/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_7030/build.zig", .{});
    cases.addBuildFile("test/standalone/install_raw_hex/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_9812/build.zig", .{});
    cases.addBuildFile("test/standalone/issue_11595/build.zig", .{});
    if (builtin.os.tag != .wasi) {
        cases.addBuildFile("test/standalone/load_dynamic_library/build.zig", .{});
    }
    // C ABI compatibility issue: https://github.com/ziglang/zig/issues/1481
    if (builtin.cpu.arch == .x86_64) {
        cases.addBuildFile("test/stage1/c_abi/build.zig", .{});
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

    // Ensure the development tools are buildable.

    // Disabled due to tripping LLVM 13 assertion:
    // https://github.com/ziglang/zig/issues/12015
    //cases.add("tools/gen_spirv_spec.zig");

    cases.add("tools/gen_stubs.zig");
    cases.add("tools/generate_linux_syscalls.zig");
    cases.add("tools/process_headers.zig");
    cases.add("tools/update-license-headers.zig");
    cases.add("tools/update-linux-headers.zig");

    // Disabled due to tripping LLVM 13 assertion:
    // https://github.com/ziglang/zig/issues/12022
    //cases.add("tools/update_clang_options.zig");

    cases.add("tools/update_cpu_features.zig");
    cases.add("tools/update_glibc.zig");

    // Disabled due to tripping LLVM 13 assertion:
    // https://github.com/ziglang/zig/issues/12015
    //cases.add("tools/update_spirv_features.zig");
}
