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
    const libs_output = {
        const args1 = [][]const u8{"llvm-config-5.0", "--libs", "--system-libs"};
        const args2 = [][]const u8{"llvm-config", "--libs", "--system-libs"};
        const max_output_size = 10 * 1024;
        const good_result = exec(b.allocator, args1, null, null, max_output_size) %% |err| {
            if (err == error.FileNotFound) {
                exec(b.allocator, args2, null, null, max_output_size) %% |err2| {
                    std.debug.panic("unable to spawn {}: {}\n", args2[0], err2);
                }
            } else {
                std.debug.panic("unable to spawn {}: {}\n", args1[0], err);
            }
        };
        switch (good_result.term) {
            os.ChildProcess.Term.Exited => |code| {
                if (code != 0) {
                    std.debug.panic("llvm-config exited with {}:\n{}\n", code, good_result.stderr);
                }
            },
            else => {
                std.debug.panic("llvm-config failed:\n{}\n", good_result.stderr);
            },
        }
        good_result.stdout
    };
    const includes_output = {
        const args1 = [][]const u8{"llvm-config-5.0", "--includedir"};
        const args2 = [][]const u8{"llvm-config", "--includedir"};
        const max_output_size = 10 * 1024;
        const good_result = exec(b.allocator, args1, null, null, max_output_size) %% |err| {
            if (err == error.FileNotFound) {
                exec(b.allocator, args2, null, null, max_output_size) %% |err2| {
                    std.debug.panic("unable to spawn {}: {}\n", args2[0], err2);
                }
            } else {
                std.debug.panic("unable to spawn {}: {}\n", args1[0], err);
            }
        };
        switch (good_result.term) {
            os.ChildProcess.Term.Exited => |code| {
                if (code != 0) {
                    std.debug.panic("llvm-config --includedir exited with {}:\n{}\n", code, good_result.stderr);
                }
            },
            else => {
                std.debug.panic("llvm-config failed:\n{}\n", good_result.stderr);
            },
        }
        good_result.stdout
    };
    const libdir_output = {
        const args1 = [][]const u8{"llvm-config-5.0", "--libdir"};
        const args2 = [][]const u8{"llvm-config", "--libdir"};
        const max_output_size = 10 * 1024;
        const good_result = exec(b.allocator, args1, null, null, max_output_size) %% |err| {
            if (err == error.FileNotFound) {
                exec(b.allocator, args2, null, null, max_output_size) %% |err2| {
                    std.debug.panic("unable to spawn {}: {}\n", args2[0], err2);
                }
            } else {
                std.debug.panic("unable to spawn {}: {}\n", args1[0], err);
            }
        };
        switch (good_result.term) {
            os.ChildProcess.Term.Exited => |code| {
                if (code != 0) {
                    std.debug.panic("llvm-config --libdir exited with {}:\n{}\n", code, good_result.stderr);
                }
            },
            else => {
                std.debug.panic("llvm-config failed:\n{}\n", good_result.stderr);
            },
        }
        good_result.stdout
    };

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


// TODO move to std lib
const ExecResult = struct {
    term: os.ChildProcess.Term,
    stdout: []u8,
    stderr: []u8,
};

fn exec(allocator: &std.mem.Allocator, argv: []const []const u8, cwd: ?[]const u8, env_map: ?&const BufMap, max_output_size: usize) -> %ExecResult {
    const child = %%os.ChildProcess.init(argv, allocator);
    defer child.deinit();

    child.stdin_behavior = os.ChildProcess.StdIo.Ignore;
    child.stdout_behavior = os.ChildProcess.StdIo.Pipe;
    child.stderr_behavior = os.ChildProcess.StdIo.Pipe;
    child.cwd = cwd;
    child.env_map = env_map;

    %return child.spawn();

    var stdout = Buffer.initNull(allocator);
    var stderr = Buffer.initNull(allocator);
    defer Buffer.deinit(&stdout);
    defer Buffer.deinit(&stderr);

    var stdout_file_in_stream = io.FileInStream.init(&??child.stdout);
    var stderr_file_in_stream = io.FileInStream.init(&??child.stderr);

    %return stdout_file_in_stream.stream.readAllBuffer(&stdout, max_output_size);
    %return stderr_file_in_stream.stream.readAllBuffer(&stderr, max_output_size);

    return ExecResult {
        .term = %return child.wait(),
        .stdout = stdout.toOwnedSlice(),
        .stderr = stderr.toOwnedSlice(),
    };
}
