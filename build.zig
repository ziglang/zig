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

pub fn build(b: &Builder) {
    const mode = b.standardReleaseOptions();

    var docgen_exe = b.addExecutable("docgen", "doc/docgen.zig");

    var docgen_cmd = b.addCommand(null, b.env_map, [][]const u8 {
        docgen_exe.getOutputPath(),
        "doc/langref.html.in",
        %%os.path.join(b.allocator, b.cache_root, "langref.html"),
    });
    docgen_cmd.step.dependOn(&docgen_exe.step);

    var docgen_home_cmd = b.addCommand(null, b.env_map, [][]const u8 {
        docgen_exe.getOutputPath(),
        "doc/home.html.in",
        %%os.path.join(b.allocator, b.cache_root, "home.html"),
    });
    docgen_home_cmd.step.dependOn(&docgen_exe.step);

    const docs_step = b.step("docs", "Build documentation");
    docs_step.dependOn(&docgen_cmd.step);
    docs_step.dependOn(&docgen_home_cmd.step);

    if (findLLVM(b)) |llvm| {
        // find the stage0 build artifacts because we're going to re-use config.h and zig_cpp library
        const build_info = b.exec([][]const u8{b.zig_exe, "BUILD_INFO"});
        var index: usize = 0;
        const cmake_binary_dir = nextValue(&index, build_info);
        const cxx_compiler = nextValue(&index, build_info);
        const lld_include_dir = nextValue(&index, build_info);
        const lld_libraries = nextValue(&index, build_info);

        var exe = b.addExecutable("zig", "src-self-hosted/main.zig");
        exe.setBuildMode(mode);
        exe.addIncludeDir("src");
        exe.addIncludeDir(cmake_binary_dir);
        addCppLib(b, exe, cmake_binary_dir, "zig_cpp");
        if (lld_include_dir.len != 0) {
            exe.addIncludeDir(lld_include_dir);
            var it = mem.split(lld_libraries, ";");
            while (it.next()) |lib| {
                exe.addObjectFile(lib);
            }
        } else {
            addCppLib(b, exe, cmake_binary_dir, "embedded_lld_elf");
            addCppLib(b, exe, cmake_binary_dir, "embedded_lld_coff");
            addCppLib(b, exe, cmake_binary_dir, "embedded_lld_lib");
        }
        dependOnLib(exe, llvm);

        if (!exe.target.isWindows()) {
            const libstdcxx_path_padded = b.exec([][]const u8{cxx_compiler, "-print-file-name=libstdc++.a"});
            const libstdcxx_path = ??mem.split(libstdcxx_path_padded, "\r\n").next();
            exe.addObjectFile(libstdcxx_path);

            exe.linkSystemLibrary("pthread");
        }

        exe.linkSystemLibrary("c");

        b.default_step.dependOn(&exe.step);
        b.default_step.dependOn(docs_step);

        b.installArtifact(exe);
        installStdLib(b);
    }


    const test_filter = b.option([]const u8, "test-filter", "Skip tests that do not match filter");
    const with_lldb = b.option(bool, "with-lldb", "Run tests in LLDB to get a backtrace if one fails") ?? false;
    const test_step = b.step("test", "Run all the tests");

    test_step.dependOn(docs_step);

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "test/behavior.zig", "behavior", "Run the behavior tests",
        with_lldb));

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "std/index.zig", "std", "Run the standard library tests",
        with_lldb));

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "std/special/compiler_rt/index.zig", "compiler-rt", "Run the compiler_rt tests",
        with_lldb));

    test_step.dependOn(tests.addPkgTests(b, test_filter,
        "src-self-hosted/main.zig", "fmt", "Run the fmt tests",
        with_lldb));

    test_step.dependOn(tests.addCompareOutputTests(b, test_filter));
    test_step.dependOn(tests.addBuildExampleTests(b, test_filter));
    test_step.dependOn(tests.addCompileErrorTests(b, test_filter));
    test_step.dependOn(tests.addAssembleAndLinkTests(b, test_filter));
    test_step.dependOn(tests.addDebugSafetyTests(b, test_filter));
    test_step.dependOn(tests.addTranslateCTests(b, test_filter));
}

fn dependOnLib(lib_exe_obj: &std.build.LibExeObjStep, dep: &const LibraryDep) {
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

fn addCppLib(b: &Builder, lib_exe_obj: &std.build.LibExeObjStep, cmake_binary_dir: []const u8, lib_name: []const u8) {
    const lib_prefix = if (lib_exe_obj.target.isWindows()) "" else "lib";
    lib_exe_obj.addObjectFile(%%os.path.join(b.allocator, cmake_binary_dir, "zig_cpp",
        b.fmt("{}{}{}", lib_prefix, lib_name, lib_exe_obj.target.libFileExt())));
}

const LibraryDep = struct {
    libdirs: ArrayList([]const u8),
    libs: ArrayList([]const u8),
    system_libs: ArrayList([]const u8),
    includes: ArrayList([]const u8),
};

fn findLLVM(b: &Builder) -> ?LibraryDep {
    const llvm_config_exe = b.findProgram(
        [][]const u8{"llvm-config-5.0", "llvm-config"},
        [][]const u8{
            "C:/Libraries/llvm-5.0.0/bin",
            "/c/msys64/mingw64/bin",
            "c:/msys64/mingw64/bin",
            "/usr/local/opt/llvm@5/bin",
            "/mingw64/bin",
        }) %% |err|
    {
        warn("unable to find llvm-config: {}\n", err);
        return null;
    };
    const libs_output = b.exec([][]const u8{llvm_config_exe, "--libs", "--system-libs"});
    const includes_output = b.exec([][]const u8{llvm_config_exe, "--includedir"});
    const libdir_output = b.exec([][]const u8{llvm_config_exe, "--libdir"});

    var result = LibraryDep {
        .libs = ArrayList([]const u8).init(b.allocator),
        .system_libs = ArrayList([]const u8).init(b.allocator),
        .includes = ArrayList([]const u8).init(b.allocator),
        .libdirs = ArrayList([]const u8).init(b.allocator),
    };
    {
        var it = mem.split(libs_output, " \r\n");
        while (it.next()) |lib_arg| {
            if (mem.startsWith(u8, lib_arg, "-l")) {
                %%result.system_libs.append(lib_arg[2..]);
            } else {
                if (os.path.isAbsolute(lib_arg)) {
                    %%result.libs.append(lib_arg);
                } else {
                    %%result.system_libs.append(lib_arg);
                }
            }
        }
    }
    {
        var it = mem.split(includes_output, " \r\n");
        while (it.next()) |include_arg| {
            if (mem.startsWith(u8, include_arg, "-I")) {
                %%result.includes.append(include_arg[2..]);
            } else {
                %%result.includes.append(include_arg);
            }
        }
    }
    {
        var it = mem.split(libdir_output, " \r\n");
        while (it.next()) |libdir| {
            if (mem.startsWith(u8, libdir, "-L")) {
                %%result.libdirs.append(libdir[2..]);
            } else {
                %%result.libdirs.append(libdir);
            }
        }
    }
    return result;
}

pub fn installStdLib(b: &Builder) {
    const stdlib_files = []const []const u8 {
        "array_list.zig",
        "base64.zig",
        "buf_map.zig",
        "buf_set.zig",
        "buffer.zig",
        "build.zig",
        "c/darwin.zig",
        "c/index.zig",
        "c/linux.zig",
        "c/windows.zig",
        "cstr.zig",
        "debug/failing_allocator.zig",
        "debug/index.zig",
        "dwarf.zig",
        "elf.zig",
        "empty.zig",
        "endian.zig",
        "fmt/errol/enum3.zig",
        "fmt/errol/index.zig",
        "fmt/errol/lookup.zig",
        "fmt/index.zig",
        "hash_map.zig",
        "heap.zig",
        "index.zig",
        "io.zig",
        "linked_list.zig",
        "math/acos.zig",
        "math/acosh.zig",
        "math/asin.zig",
        "math/asinh.zig",
        "math/atan.zig",
        "math/atan2.zig",
        "math/atanh.zig",
        "math/cbrt.zig",
        "math/ceil.zig",
        "math/copysign.zig",
        "math/cos.zig",
        "math/cosh.zig",
        "math/exp.zig",
        "math/exp2.zig",
        "math/expm1.zig",
        "math/expo2.zig",
        "math/fabs.zig",
        "math/floor.zig",
        "math/fma.zig",
        "math/frexp.zig",
        "math/hypot.zig",
        "math/ilogb.zig",
        "math/index.zig",
        "math/inf.zig",
        "math/isfinite.zig",
        "math/isinf.zig",
        "math/isnan.zig",
        "math/isnormal.zig",
        "math/ln.zig",
        "math/log.zig",
        "math/log10.zig",
        "math/log1p.zig",
        "math/log2.zig",
        "math/modf.zig",
        "math/nan.zig",
        "math/pow.zig",
        "math/round.zig",
        "math/scalbn.zig",
        "math/signbit.zig",
        "math/sin.zig",
        "math/sinh.zig",
        "math/sqrt.zig",
        "math/tan.zig",
        "math/tanh.zig",
        "math/trunc.zig",
        "mem.zig",
        "net.zig",
        "os/child_process.zig",
        "os/darwin.zig",
        "os/darwin_errno.zig",
        "os/get_user_id.zig",
        "os/index.zig",
        "os/linux.zig",
        "os/linux_errno.zig",
        "os/linux_i386.zig",
        "os/linux_x86_64.zig",
        "os/path.zig",
        "os/windows/error.zig",
        "os/windows/index.zig",
        "os/windows/util.zig",
        "rand.zig",
        "sort.zig",
        "unicode.zig",
        "special/bootstrap.zig",
        "special/bootstrap_lib.zig",
        "special/build_file_template.zig",
        "special/build_runner.zig",
        "special/builtin.zig",
        "special/compiler_rt/aulldiv.zig",
        "special/compiler_rt/aullrem.zig",
        "special/compiler_rt/comparetf2.zig",
        "special/compiler_rt/fixuint.zig",
        "special/compiler_rt/fixunsdfdi.zig",
        "special/compiler_rt/fixunsdfsi.zig",
        "special/compiler_rt/fixunsdfti.zig",
        "special/compiler_rt/fixunssfdi.zig",
        "special/compiler_rt/fixunssfsi.zig",
        "special/compiler_rt/fixunssfti.zig",
        "special/compiler_rt/fixunstfdi.zig",
        "special/compiler_rt/fixunstfsi.zig",
        "special/compiler_rt/fixunstfti.zig",
        "special/compiler_rt/index.zig",
        "special/compiler_rt/udivmod.zig",
        "special/compiler_rt/udivmoddi4.zig",
        "special/compiler_rt/udivmodti4.zig",
        "special/compiler_rt/udivti3.zig",
        "special/compiler_rt/umodti3.zig",
        "special/panic.zig",
        "special/test_runner.zig",
    };
    for (stdlib_files) |stdlib_file| {
        const src_path = %%os.path.join(b.allocator, "std", stdlib_file);
        const dest_path = %%os.path.join(b.allocator, "lib", "zig", "std", stdlib_file);
        b.installFile(src_path, dest_path);
    }
}

fn nextValue(index: &usize, build_info: []const u8) -> []const u8 {
    const start = *index;
    while (build_info[*index] != '\n' and build_info[*index] != '\r') : (*index += 1) { }
    const result = build_info[start..*index];
    *index += 1;
    return result;
}
