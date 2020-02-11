const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
const tests = @import("test/tests.zig");
const BufMap = std.BufMap;
const warn = std.debug.warn;
const mem = std.mem;
const ArrayList = std.ArrayList;
const io = std.io;
const fs = std.fs;
const InstallDirectoryOptions = std.build.InstallDirectoryOptions;

pub fn build(b: *Builder) !void {
    b.setPreferredReleaseMode(.ReleaseFast);
    const mode = b.standardReleaseOptions();

    var docgen_exe = b.addExecutable("docgen", "doc/docgen.zig");

    const rel_zig_exe = try fs.path.relative(b.allocator, b.build_root, b.zig_exe);
    const langref_out_path = fs.path.join(
        b.allocator,
        &[_][]const u8{ b.cache_root, "langref.html" },
    ) catch unreachable;
    var docgen_cmd = docgen_exe.run();
    docgen_cmd.addArgs(&[_][]const u8{
        rel_zig_exe,
        "doc" ++ fs.path.sep_str ++ "langref.html.in",
        langref_out_path,
    });
    docgen_cmd.step.dependOn(&docgen_exe.step);

    const docs_step = b.step("docs", "Build documentation");
    docs_step.dependOn(&docgen_cmd.step);

    const test_step = b.step("test", "Run all the tests");

    // find the stage0 build artifacts because we're going to re-use config.h and zig_cpp library
    const build_info = try b.exec(&[_][]const u8{
        b.zig_exe,
        "BUILD_INFO",
    });
    var index: usize = 0;
    var ctx = Context{
        .cmake_binary_dir = nextValue(&index, build_info),
        .cxx_compiler = nextValue(&index, build_info),
        .llvm_config_exe = nextValue(&index, build_info),
        .lld_include_dir = nextValue(&index, build_info),
        .lld_libraries = nextValue(&index, build_info),
        .dia_guids_lib = nextValue(&index, build_info),
        .llvm = undefined,
    };
    ctx.llvm = try findLLVM(b, ctx.llvm_config_exe);

    var test_stage2 = b.addTest("src-self-hosted/test.zig");
    test_stage2.setBuildMode(builtin.Mode.Debug);
    test_stage2.addPackagePath("stage2_tests", "test/stage2/test.zig");

    const fmt_build_zig = b.addFmt(&[_][]const u8{"build.zig"});

    var exe = b.addExecutable("zig", "src-self-hosted/main.zig");
    exe.setBuildMode(mode);

    try configureStage2(b, test_stage2, ctx);
    try configureStage2(b, exe, ctx);

    const skip_release = b.option(bool, "skip-release", "Main test suite skips release builds") orelse false;
    const skip_release_small = b.option(bool, "skip-release-small", "Main test suite skips release-small builds") orelse skip_release;
    const skip_release_fast = b.option(bool, "skip-release-fast", "Main test suite skips release-fast builds") orelse skip_release;
    const skip_release_safe = b.option(bool, "skip-release-safe", "Main test suite skips release-safe builds") orelse skip_release;
    const skip_non_native = b.option(bool, "skip-non-native", "Main test suite skips non-native builds") orelse false;
    const skip_libc = b.option(bool, "skip-libc", "Main test suite skips tests that link libc") orelse false;
    const skip_self_hosted = (b.option(bool, "skip-self-hosted", "Main test suite skips building self hosted compiler") orelse false) or true; // TODO evented I/O good enough that this passes everywhere
    if (!skip_self_hosted) {
        test_step.dependOn(&exe.step);
    }

    const only_install_lib_files = b.option(bool, "lib-files-only", "Only install library files") orelse false;
    if (!only_install_lib_files and !skip_self_hosted) {
        b.default_step.dependOn(&exe.step);
        exe.install();
    }

    b.installDirectory(InstallDirectoryOptions{
        .source_dir = "lib",
        .install_dir = .Lib,
        .install_subdir = "zig",
        .exclude_extensions = &[_][]const u8{ "test.zig", "README.md" },
    });

    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    const is_wine_enabled = b.option(bool, "enable-wine", "Use Wine to run cross compiled Windows tests") orelse false;
    const is_qemu_enabled = b.option(bool, "enable-qemu", "Use QEMU to run cross compiled foreign architecture tests") orelse false;
    const glibc_multi_dir = b.option([]const u8, "enable-foreign-glibc", "Provide directory with glibc installations to run cross compiled tests that link glibc");

    const test_stage2_step = b.step("test-stage2", "Run the stage2 compiler tests");
    test_stage2_step.dependOn(&test_stage2.step);
    test_step.dependOn(test_stage2_step);

    var chosen_modes: [4]builtin.Mode = undefined;
    var chosen_mode_index: usize = 0;
    chosen_modes[chosen_mode_index] = builtin.Mode.Debug;
    chosen_mode_index += 1;
    if (!skip_release_safe) {
        chosen_modes[chosen_mode_index] = builtin.Mode.ReleaseSafe;
        chosen_mode_index += 1;
    }
    if (!skip_release_fast) {
        chosen_modes[chosen_mode_index] = builtin.Mode.ReleaseFast;
        chosen_mode_index += 1;
    }
    if (!skip_release_small) {
        chosen_modes[chosen_mode_index] = builtin.Mode.ReleaseSmall;
        chosen_mode_index += 1;
    }
    const modes = chosen_modes[0..chosen_mode_index];

    // run stage1 `zig fmt` on this build.zig file just to make sure it works
    test_step.dependOn(&fmt_build_zig.step);
    const fmt_step = b.step("test-fmt", "Run zig fmt against build.zig to make sure it works");
    fmt_step.dependOn(&fmt_build_zig.step);

    test_step.dependOn(tests.addPkgTests(b, test_filter, "test/stage1/behavior.zig", "behavior", "Run the behavior tests", modes, false, skip_non_native, skip_libc, is_wine_enabled, is_qemu_enabled, glibc_multi_dir));

    test_step.dependOn(tests.addPkgTests(b, test_filter, "lib/std/std.zig", "std", "Run the standard library tests", modes, false, skip_non_native, skip_libc, is_wine_enabled, is_qemu_enabled, glibc_multi_dir));

    test_step.dependOn(tests.addPkgTests(b, test_filter, "lib/std/special/compiler_rt.zig", "compiler-rt", "Run the compiler_rt tests", modes, true, skip_non_native, true, is_wine_enabled, is_qemu_enabled, glibc_multi_dir));

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter, modes));
    test_step.dependOn(tests.addStandaloneTests(b, test_filter, modes));
    test_step.dependOn(tests.addStackTraceTests(b, test_filter, modes));
    test_step.dependOn(tests.addCliTests(b, test_filter, modes));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filter, modes));
    test_step.dependOn(tests.addRuntimeSafetyTests(b, test_filter, modes));
    test_step.dependOn(tests.addTranslateCTests(b, test_filter));
    test_step.dependOn(tests.addRunTranslatedCTests(b, test_filter));
    test_step.dependOn(tests.addGenHTests(b, test_filter));
    test_step.dependOn(tests.addCompileErrorTests(b, test_filter, modes));
    test_step.dependOn(docs_step);
}

fn dependOnLib(b: *Builder, lib_exe_obj: var, dep: LibraryDep) void {
    for (dep.libdirs.toSliceConst()) |lib_dir| {
        lib_exe_obj.addLibPath(lib_dir);
    }
    const lib_dir = fs.path.join(
        b.allocator,
        &[_][]const u8{ dep.prefix, "lib" },
    ) catch unreachable;
    for (dep.system_libs.toSliceConst()) |lib| {
        const static_bare_name = if (mem.eql(u8, lib, "curses"))
            @as([]const u8, "libncurses.a")
        else
            b.fmt("lib{}.a", .{lib});
        const static_lib_name = fs.path.join(
            b.allocator,
            &[_][]const u8{ lib_dir, static_bare_name },
        ) catch unreachable;
        const have_static = fileExists(static_lib_name) catch unreachable;
        if (have_static) {
            lib_exe_obj.addObjectFile(static_lib_name);
        } else {
            lib_exe_obj.linkSystemLibrary(lib);
        }
    }
    for (dep.libs.toSliceConst()) |lib| {
        lib_exe_obj.addObjectFile(lib);
    }
    for (dep.includes.toSliceConst()) |include_path| {
        lib_exe_obj.addIncludeDir(include_path);
    }
}

fn fileExists(filename: []const u8) !bool {
    fs.cwd().access(filename, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return true;
}

fn addCppLib(b: *Builder, lib_exe_obj: var, cmake_binary_dir: []const u8, lib_name: []const u8) void {
    lib_exe_obj.addObjectFile(fs.path.join(b.allocator, &[_][]const u8{
        cmake_binary_dir,
        "zig_cpp",
        b.fmt("{}{}{}", .{ lib_exe_obj.target.libPrefix(), lib_name, lib_exe_obj.target.staticLibSuffix() }),
    }) catch unreachable);
}

const LibraryDep = struct {
    prefix: []const u8,
    libdirs: ArrayList([]const u8),
    libs: ArrayList([]const u8),
    system_libs: ArrayList([]const u8),
    includes: ArrayList([]const u8),
};

fn findLLVM(b: *Builder, llvm_config_exe: []const u8) !LibraryDep {
    const shared_mode = try b.exec(&[_][]const u8{ llvm_config_exe, "--shared-mode" });
    const is_static = mem.startsWith(u8, shared_mode, "static");
    const libs_output = if (is_static)
        try b.exec(&[_][]const u8{
            llvm_config_exe,
            "--libfiles",
            "--system-libs",
        })
    else
        try b.exec(&[_][]const u8{
            llvm_config_exe,
            "--libs",
        });
    const includes_output = try b.exec(&[_][]const u8{ llvm_config_exe, "--includedir" });
    const libdir_output = try b.exec(&[_][]const u8{ llvm_config_exe, "--libdir" });
    const prefix_output = try b.exec(&[_][]const u8{ llvm_config_exe, "--prefix" });

    var result = LibraryDep{
        .prefix = mem.tokenize(prefix_output, " \r\n").next().?,
        .libs = ArrayList([]const u8).init(b.allocator),
        .system_libs = ArrayList([]const u8).init(b.allocator),
        .includes = ArrayList([]const u8).init(b.allocator),
        .libdirs = ArrayList([]const u8).init(b.allocator),
    };
    {
        var it = mem.tokenize(libs_output, " \r\n");
        while (it.next()) |lib_arg| {
            if (mem.startsWith(u8, lib_arg, "-l")) {
                try result.system_libs.append(lib_arg[2..]);
            } else {
                if (fs.path.isAbsolute(lib_arg)) {
                    try result.libs.append(lib_arg);
                } else {
                    if (mem.endsWith(u8, lib_arg, ".lib")) {
                        lib_arg = lib_arg[0 .. lib_arg.len - 4];
                    }
                    try result.system_libs.append(lib_arg);
                }
            }
        }
    }
    {
        var it = mem.tokenize(includes_output, " \r\n");
        while (it.next()) |include_arg| {
            if (mem.startsWith(u8, include_arg, "-I")) {
                try result.includes.append(include_arg[2..]);
            } else {
                try result.includes.append(include_arg);
            }
        }
    }
    {
        var it = mem.tokenize(libdir_output, " \r\n");
        while (it.next()) |libdir| {
            if (mem.startsWith(u8, libdir, "-L")) {
                try result.libdirs.append(libdir[2..]);
            } else {
                try result.libdirs.append(libdir);
            }
        }
    }
    return result;
}

fn nextValue(index: *usize, build_info: []const u8) []const u8 {
    const start = index.*;
    while (true) : (index.* += 1) {
        switch (build_info[index.*]) {
            '\n' => {
                const result = build_info[start..index.*];
                index.* += 1;
                return result;
            },
            '\r' => {
                const result = build_info[start..index.*];
                index.* += 2;
                return result;
            },
            else => continue,
        }
    }
}

fn configureStage2(b: *Builder, exe: var, ctx: Context) !void {
    exe.addIncludeDir("src");
    exe.addIncludeDir(ctx.cmake_binary_dir);
    addCppLib(b, exe, ctx.cmake_binary_dir, "zig_cpp");
    if (ctx.lld_include_dir.len != 0) {
        exe.addIncludeDir(ctx.lld_include_dir);
        var it = mem.tokenize(ctx.lld_libraries, ";");
        while (it.next()) |lib| {
            exe.addObjectFile(lib);
        }
    } else {
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_wasm");
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_elf");
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_coff");
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_lib");
    }
    dependOnLib(b, exe, ctx.llvm);

    if (exe.target.getOsTag() == .linux) {
        try addCxxKnownPath(b, ctx, exe, "libstdc++.a",
            \\Unable to determine path to libstdc++.a
            \\On Fedora, install libstdc++-static and try again.
        );

        exe.linkSystemLibrary("pthread");
    } else if (exe.target.isFreeBSD()) {
        try addCxxKnownPath(b, ctx, exe, "libc++.a", null);
        exe.linkSystemLibrary("pthread");
    } else if (exe.target.isDarwin()) {
        if (addCxxKnownPath(b, ctx, exe, "libgcc_eh.a", "")) {
            // Compiler is GCC.
            try addCxxKnownPath(b, ctx, exe, "libstdc++.a", null);
            exe.linkSystemLibrary("pthread");
            // TODO LLD cannot perform this link.
            // See https://github.com/ziglang/zig/issues/1535
            exe.enableSystemLinkerHack();
        } else |err| switch (err) {
            error.RequiredLibraryNotFound => {
                // System compiler, not gcc.
                exe.linkSystemLibrary("c++");
            },
            else => return err,
        }
    }

    if (ctx.dia_guids_lib.len != 0) {
        exe.addObjectFile(ctx.dia_guids_lib);
    }

    exe.linkSystemLibrary("c");
}

fn addCxxKnownPath(
    b: *Builder,
    ctx: Context,
    exe: var,
    objname: []const u8,
    errtxt: ?[]const u8,
) !void {
    const path_padded = try b.exec(&[_][]const u8{
        ctx.cxx_compiler,
        b.fmt("-print-file-name={}", .{objname}),
    });
    const path_unpadded = mem.tokenize(path_padded, "\r\n").next().?;
    if (mem.eql(u8, path_unpadded, objname)) {
        if (errtxt) |msg| {
            warn("{}", .{msg});
        } else {
            warn("Unable to determine path to {}\n", .{objname});
        }
        return error.RequiredLibraryNotFound;
    }
    exe.addObjectFile(path_unpadded);
}

const Context = struct {
    cmake_binary_dir: []const u8,
    cxx_compiler: []const u8,
    llvm_config_exe: []const u8,
    lld_include_dir: []const u8,
    lld_libraries: []const u8,
    dia_guids_lib: []const u8,
    llvm: LibraryDep,
};
