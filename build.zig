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

    var exe = b.addExecutable("zig", "src-self-hosted/main.zig");
    exe.setBuildMode(mode);
    exe.linkSystemLibrary("c");
    dependOnLib(exe, findLLVM(b));

    b.default_step.dependOn(&exe.step);
    b.default_step.dependOn(docs_step);

    b.installArtifact(exe);


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
    for (dep.libs.toSliceConst()) |lib| {
        lib_exe_obj.linkSystemLibrary(lib);
    }
    for (dep.includes.toSliceConst()) |include_path| {
        lib_exe_obj.addIncludeDir(include_path);
    }
}

const LibraryDep = struct {
    libdirs: ArrayList([]const u8),
    libs: ArrayList([]const u8),
    includes: ArrayList([]const u8),
};

fn findLLVM(b: &Builder) -> LibraryDep {
    const llvm_config_exe = b.findProgram(
        [][]const u8{"llvm-config-5.0", "llvm-config"},
        [][]const u8{
            "/usr/local/opt/llvm@5/",
            "/mingw64/bin",
            "/c/msys64/mingw64/bin",
            "c:/msys64/mingw64/bin",
            "C:/Libraries/llvm-5.0.0/bin",
        }) %% |err|
    {
        std.debug.panic("unable to find llvm-config: {}\n", err);
    };
    const libs_output = b.exec([][]const u8{llvm_config_exe, "--libs", "--system-libs"});
    const includes_output = b.exec([][]const u8{llvm_config_exe, "--includedir"});
    const libdir_output = b.exec([][]const u8{llvm_config_exe, "--libdir"});

    var result = LibraryDep {
        .libs = ArrayList([]const u8).init(b.allocator),
        .includes = ArrayList([]const u8).init(b.allocator),
        .libdirs = ArrayList([]const u8).init(b.allocator),
    };
    {
        var it = mem.split(libs_output, " \n");
        while (it.next()) |lib_arg| {
            if (mem.startsWith(u8, lib_arg, "-l")) {
                %%result.libs.append(lib_arg[2..]);
            }
        }
    }
    {
        var it = mem.split(includes_output, " \n");
        while (it.next()) |include_arg| {
            if (mem.startsWith(u8, include_arg, "-I")) {
                %%result.includes.append(include_arg[2..]);
            } else {
                %%result.includes.append(include_arg);
            }
        }
    }
    {
        var it = mem.split(libdir_output, " \n");
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
