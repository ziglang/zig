const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const step = b.step("test", "Run standalone test cases");
    b.default_step = step;

    const enable_ios_sdk = b.option(bool, "enable_ios_sdk", "Run tests requiring presence of iOS SDK and frameworks") orelse false;
    const enable_macos_sdk = b.option(bool, "enable_macos_sdk", "Run tests requiring presence of macOS SDK and frameworks") orelse enable_ios_sdk;
    const enable_symlinks_windows = b.option(bool, "enable_symlinks_windows", "Run tests requiring presence of symlinks on Windows") orelse false;
    const omit_symlinks = builtin.os.tag == .windows and !enable_symlinks_windows;

    const simple_skip_debug = b.option(bool, "simple_skip_debug", "Simple tests skip debug builds") orelse false;
    const simple_skip_release_safe = b.option(bool, "simple_skip_release_safe", "Simple tests skip release-safe builds") orelse false;
    const simple_skip_release_fast = b.option(bool, "simple_skip_release_fast", "Simple tests skip release-fast builds") orelse false;
    const simple_skip_release_small = b.option(bool, "simple_skip_release_small", "Simple tests skip release-small builds") orelse false;

    const simple_dep = b.dependency("simple", .{
        .skip_debug = simple_skip_debug,
        .skip_release_safe = simple_skip_release_safe,
        .skip_release_fast = simple_skip_release_fast,
        .skip_release_small = simple_skip_release_small,
    });
    const simple_dep_step = simple_dep.builder.default_step;
    simple_dep_step.name = "standalone_test_cases.simple";
    step.dependOn(simple_dep_step);

    // Ensure the development tools are buildable.
    const tools_tests_step = b.step("standalone_test_cases.tools", "Test tools");
    step.dependOn(tools_tests_step);
    const tools_target = b.resolveTargetQuery(.{});
    for ([_][]const u8{
        // Alphabetically sorted. No need to build `tools/spirv/grammar.zig`.
        "../../tools/gen_outline_atomics.zig",
        "../../tools/gen_spirv_spec.zig",
        "../../tools/gen_stubs.zig",
        "../../tools/generate_c_size_and_align_checks.zig",
        "../../tools/generate_linux_syscalls.zig",
        "../../tools/process_headers.zig",
        "../../tools/update-linux-headers.zig",
        "../../tools/update_clang_options.zig",
        "../../tools/update_cpu_features.zig",
        "../../tools/update_glibc.zig",
        "../../tools/update_spirv_features.zig",
    }) |tool_src_path| {
        const tool = b.addTest(.{
            .name = std.fs.path.stem(tool_src_path),
            .root_source_file = b.path(tool_src_path),
            .optimize = .Debug,
            .target = tools_target,
        });
        const run = b.addRunArtifact(tool);
        tools_tests_step.dependOn(&run.step);
    }

    add_dep_steps: for (b.available_deps) |available_dep| {
        const dep_name, const dep_hash = available_dep;

        // The 'simple' dependency was already handled manually above.
        if (std.mem.eql(u8, dep_name, "simple")) continue;

        const all_pkgs = @import("root").dependencies.packages;
        inline for (@typeInfo(all_pkgs).@"struct".decls) |decl| {
            const pkg_hash = decl.name;
            if (std.mem.eql(u8, dep_hash, pkg_hash)) {
                const pkg = @field(all_pkgs, pkg_hash);
                if (!@hasDecl(pkg, "build_zig")) {
                    std.debug.panic("standalone test case '{s}' is missing a 'build.zig' file", .{dep_name});
                }
                const requires_ios_sdk = @hasDecl(pkg.build_zig, "requires_ios_sdk") and
                    pkg.build_zig.requires_ios_sdk;
                const requires_macos_sdk = @hasDecl(pkg.build_zig, "requires_macos_sdk") and
                    pkg.build_zig.requires_macos_sdk;
                const requires_symlinks = @hasDecl(pkg.build_zig, "requires_symlinks") and
                    pkg.build_zig.requires_symlinks;
                if ((requires_symlinks and omit_symlinks) or
                    (requires_macos_sdk and !enable_macos_sdk) or
                    (requires_ios_sdk and !enable_ios_sdk))
                {
                    continue :add_dep_steps;
                }
                break;
            }
        } else unreachable;

        const dep = b.dependency(dep_name, .{});
        const dep_step = dep.builder.default_step;
        dep_step.name = b.fmt("standalone_test_cases.{s}", .{dep_name});
        step.dependOn(dep_step);
    }
}
