const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;
const tests = @import("test/tests.zig");
const os = std.os;
const BufMap = std.BufMap;
const warn = std.debug.warn;
const mem = std.mem;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;
const io = std.io;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();

    var docgen_exe = b.addExecutable("docgen", "doc/docgen.zig");

    const rel_zig_exe = try os.path.relative(b.allocator, b.build_root, b.zig_exe);
    var docgen_cmd = b.addCommand(null, b.env_map, [][]const u8{
        docgen_exe.getOutputPath(),
        rel_zig_exe,
        "doc/langref.html.in",
        os.path.join(b.allocator, b.cache_root, "langref.html") catch unreachable,
    });
    docgen_cmd.step.dependOn(&docgen_exe.step);

    const docs_step = b.step("docs", "Build documentation");
    docs_step.dependOn(&docgen_cmd.step);

    const test_step = b.step("test", "Run all the tests");

    // find the stage0 build artifacts because we're going to re-use config.h and zig_cpp library
    const build_info = try b.exec([][]const u8{
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
        .std_files = nextValue(&index, build_info),
        .c_header_files = nextValue(&index, build_info),
        .dia_guids_lib = nextValue(&index, build_info),
        .llvm = undefined,
    };
    ctx.llvm = try findLLVM(b, ctx.llvm_config_exe);

    var test_stage2 = b.addTest("src-self-hosted/test.zig");
    test_stage2.setBuildMode(builtin.Mode.Debug);

    var exe = b.addExecutable("zig", "src-self-hosted/main.zig");
    exe.setBuildMode(mode);

    try configureStage2(b, test_stage2, ctx);
    try configureStage2(b, exe, ctx);

    b.default_step.dependOn(&exe.step);

    const skip_release = b.option(bool, "skip-release", "Main test suite skips release builds") orelse false;
    const skip_self_hosted = b.option(bool, "skip-self-hosted", "Main test suite skips building self hosted compiler") orelse false;
    if (!skip_self_hosted) {
        test_step.dependOn(&exe.step);
    }
    const verbose_link_exe = b.option(bool, "verbose-link", "Print link command for self hosted compiler") orelse false;
    exe.setVerboseLink(verbose_link_exe);

    b.installArtifact(exe);
    installStdLib(b, ctx.std_files);
    installCHeaders(b, ctx.c_header_files);

    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");

    const test_stage2_step = b.step("test-stage2", "Run the stage2 compiler tests");
    test_stage2_step.dependOn(&test_stage2.step);
    test_step.dependOn(test_stage2_step);

    const all_modes = []builtin.Mode{
        builtin.Mode.Debug,
        builtin.Mode.ReleaseSafe,
        builtin.Mode.ReleaseFast,
        builtin.Mode.ReleaseSmall,
    };
    const modes = if (skip_release) []builtin.Mode{builtin.Mode.Debug} else all_modes;

    test_step.dependOn(tests.addPkgTests(b, test_filter, "test/behavior.zig", "behavior", "Run the behavior tests", modes));

    test_step.dependOn(tests.addPkgTests(b, test_filter, "std/index.zig", "std", "Run the standard library tests", modes));

    test_step.dependOn(tests.addPkgTests(b, test_filter, "std/special/compiler_rt/index.zig", "compiler-rt", "Run the compiler_rt tests", modes));

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter, modes));
    test_step.dependOn(tests.addBuildExampleTests(b, test_filter, modes));
    test_step.dependOn(tests.addCompileErrorTests(b, test_filter, modes));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filter, modes));
    test_step.dependOn(tests.addRuntimeSafetyTests(b, test_filter, modes));
    test_step.dependOn(tests.addTranslateCTests(b, test_filter));
    test_step.dependOn(tests.addGenHTests(b, test_filter));
    test_step.dependOn(docs_step);
}

fn dependOnLib(lib_exe_obj: var, dep: *const LibraryDep) void {
    for (dep.libdirs.toSliceConst()) |lib_dir| {
        lib_exe_obj.addLibPath(lib_dir);
    }
    for (dep.system_libs.toSliceConst()) |lib| {
        lib_exe_obj.linkSystemLibrary(lib);
    }
    for (dep.libs.toSliceConst()) |lib| {
        lib_exe_obj.addObjectFile(lib);
    }
    for (dep.includes.toSliceConst()) |include_path| {
        lib_exe_obj.addIncludeDir(include_path);
    }
}

fn addCppLib(b: *Builder, lib_exe_obj: var, cmake_binary_dir: []const u8, lib_name: []const u8) void {
    const lib_prefix = if (lib_exe_obj.target.isWindows()) "" else "lib";
    lib_exe_obj.addObjectFile(os.path.join(b.allocator, cmake_binary_dir, "zig_cpp", b.fmt("{}{}{}", lib_prefix, lib_name, lib_exe_obj.target.libFileExt())) catch unreachable);
}

const LibraryDep = struct {
    libdirs: ArrayList([]const u8),
    libs: ArrayList([]const u8),
    system_libs: ArrayList([]const u8),
    includes: ArrayList([]const u8),
};

fn findLLVM(b: *Builder, llvm_config_exe: []const u8) !LibraryDep {
    const libs_output = try b.exec([][]const u8{
        llvm_config_exe,
        "--libs",
        "--system-libs",
    });
    const includes_output = try b.exec([][]const u8{
        llvm_config_exe,
        "--includedir",
    });
    const libdir_output = try b.exec([][]const u8{
        llvm_config_exe,
        "--libdir",
    });

    var result = LibraryDep{
        .libs = ArrayList([]const u8).init(b.allocator),
        .system_libs = ArrayList([]const u8).init(b.allocator),
        .includes = ArrayList([]const u8).init(b.allocator),
        .libdirs = ArrayList([]const u8).init(b.allocator),
    };
    {
        var it = mem.split(libs_output, " \r\n");
        while (it.next()) |lib_arg| {
            if (mem.startsWith(u8, lib_arg, "-l")) {
                try result.system_libs.append(lib_arg[2..]);
            } else {
                if (os.path.isAbsolute(lib_arg)) {
                    try result.libs.append(lib_arg);
                } else {
                    try result.system_libs.append(lib_arg);
                }
            }
        }
    }
    {
        var it = mem.split(includes_output, " \r\n");
        while (it.next()) |include_arg| {
            if (mem.startsWith(u8, include_arg, "-I")) {
                try result.includes.append(include_arg[2..]);
            } else {
                try result.includes.append(include_arg);
            }
        }
    }
    {
        var it = mem.split(libdir_output, " \r\n");
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

pub fn installStdLib(b: *Builder, stdlib_files: []const u8) void {
    var it = mem.split(stdlib_files, ";");
    while (it.next()) |stdlib_file| {
        const src_path = os.path.join(b.allocator, "std", stdlib_file) catch unreachable;
        const dest_path = os.path.join(b.allocator, "lib", "zig", "std", stdlib_file) catch unreachable;
        b.installFile(src_path, dest_path);
    }
}

pub fn installCHeaders(b: *Builder, c_header_files: []const u8) void {
    var it = mem.split(c_header_files, ";");
    while (it.next()) |c_header_file| {
        const src_path = os.path.join(b.allocator, "c_headers", c_header_file) catch unreachable;
        const dest_path = os.path.join(b.allocator, "lib", "zig", "include", c_header_file) catch unreachable;
        b.installFile(src_path, dest_path);
    }
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
    // This is for finding /lib/libz.a on alpine linux.
    // TODO turn this into -Dextra-lib-path=/lib option
    exe.addLibPath("/lib");

    exe.addIncludeDir("src");
    exe.addIncludeDir(ctx.cmake_binary_dir);
    addCppLib(b, exe, ctx.cmake_binary_dir, "zig_cpp");
    if (ctx.lld_include_dir.len != 0) {
        exe.addIncludeDir(ctx.lld_include_dir);
        var it = mem.split(ctx.lld_libraries, ";");
        while (it.next()) |lib| {
            exe.addObjectFile(lib);
        }
    } else {
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_wasm");
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_elf");
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_coff");
        addCppLib(b, exe, ctx.cmake_binary_dir, "embedded_lld_lib");
    }
    dependOnLib(exe, ctx.llvm);

    if (exe.target.getOs() == builtin.Os.linux) {
        const libstdcxx_path_padded = try b.exec([][]const u8{
            ctx.cxx_compiler,
            "-print-file-name=libstdc++.a",
        });
        const libstdcxx_path = mem.split(libstdcxx_path_padded, "\r\n").next().?;
        if (mem.eql(u8, libstdcxx_path, "libstdc++.a")) {
            warn(
                \\Unable to determine path to libstdc++.a
                \\On Fedora, install libstdc++-static and try again.
                \\
            );
            return error.RequiredLibraryNotFound;
        }
        exe.addObjectFile(libstdcxx_path);

        exe.linkSystemLibrary("pthread");
    } else if (exe.target.isDarwin()) {
        exe.linkSystemLibrary("c++");
    }

    if (ctx.dia_guids_lib.len != 0) {
        exe.addObjectFile(ctx.dia_guids_lib);
    }

    if (exe.target.getOs() != builtin.Os.windows) {
        exe.linkSystemLibrary("xml2");
    }
    exe.linkSystemLibrary("c");
}

const Context = struct {
    cmake_binary_dir: []const u8,
    cxx_compiler: []const u8,
    llvm_config_exe: []const u8,
    lld_include_dir: []const u8,
    lld_libraries: []const u8,
    std_files: []const u8,
    c_header_files: []const u8,
    dia_guids_lib: []const u8,
    llvm: LibraryDep,
};
