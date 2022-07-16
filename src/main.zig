const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const process = std.process;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const Ast = std.zig.Ast;
const warn = std.log.warn;

const tracy = @import("tracy.zig");
const Compilation = @import("Compilation.zig");
const link = @import("link.zig");
const Package = @import("Package.zig");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const wasi_libc = @import("wasi_libc.zig");
const translate_c = @import("translate_c.zig");
const Cache = @import("Cache.zig");
const target_util = @import("target.zig");
const ThreadPool = @import("ThreadPool.zig");
const crash_report = @import("crash_report.zig");

// Crash report needs to override the panic handler and other root decls
pub usingnamespace crash_report.root_decls;

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    process.exit(1);
}

/// There are many assumptions in the entire codebase that Zig source files can
/// be byte-indexed with a u32 integer.
pub const max_src_size = std.math.maxInt(u32);

pub const debug_extensions_enabled = builtin.mode == .Debug;

pub const Color = enum {
    auto,
    off,
    on,
};

const normal_usage =
    \\Usage: zig [command] [options]
    \\
    \\Commands:
    \\
    \\  build            Build project from build.zig
    \\  init-exe         Initialize a `zig build` application in the cwd
    \\  init-lib         Initialize a `zig build` library in the cwd
    \\
    \\  ast-check        Look for simple compile errors in any set of files
    \\  build-exe        Create executable from source or object files
    \\  build-lib        Create library from source or object files
    \\  build-obj        Create object from source or object files
    \\  fmt              Reformat Zig source into canonical form
    \\  run              Create executable and run immediately
    \\  test             Create and run a test build
    \\  translate-c      Convert C code to Zig code
    \\
    \\  ar               Use Zig as a drop-in archiver
    \\  cc               Use Zig as a drop-in C compiler
    \\  c++              Use Zig as a drop-in C++ compiler
    \\  dlltool          Use Zig as a drop-in dlltool.exe
    \\  lib              Use Zig as a drop-in lib.exe
    \\  ranlib           Use Zig as a drop-in ranlib
    \\
    \\  env              Print lib path, std path, cache directory, and version
    \\  help             Print this help and exit
    \\  libc             Display native libc paths file or validate one
    \\  targets          List available compilation targets
    \\  version          Print version number and exit
    \\  zen              Print Zen of Zig and exit
    \\
    \\General Options:
    \\
    \\  -h, --help       Print command-specific usage
    \\
;

const debug_usage = normal_usage ++
    \\
    \\Debug Commands:
    \\
    \\  changelist       Compute mappings from old ZIR to new ZIR
    \\
;

const usage = if (debug_extensions_enabled) debug_usage else normal_usage;

pub const log_level: std.log.Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast => .info,
    .ReleaseSmall => .err,
};

var log_scopes: std.ArrayListUnmanaged([]const u8) = .{};

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Hide debug messages unless:
    // * logging enabled with `-Dlog`.
    // * the --debug-log arg for the scope has been provided
    if (@enumToInt(level) > @enumToInt(std.log.level) or
        @enumToInt(level) > @enumToInt(std.log.Level.info))
    {
        if (!build_options.enable_logging) return;

        const scope_name = @tagName(scope);
        for (log_scopes.items) |log_scope| {
            if (mem.eql(u8, log_scope, scope_name))
                break;
        } else return;
    }

    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    // Print the message to stderr, silently ignoring any errors
    std.debug.print(prefix1 ++ prefix2 ++ format ++ "\n", args);
}

var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{
    .stack_trace_frames = build_options.mem_leak_frames,
}){};

pub fn main() anyerror!void {
    crash_report.initialize();

    const use_gpa = build_options.force_gpa or !builtin.link_libc;
    const gpa = gpa: {
        if (use_gpa) {
            break :gpa general_purpose_allocator.allocator();
        }
        // We would prefer to use raw libc allocator here, but cannot
        // use it if it won't support the alignment we need.
        if (@alignOf(std.c.max_align_t) < @alignOf(i128)) {
            break :gpa std.heap.c_allocator;
        }
        break :gpa std.heap.raw_c_allocator;
    };
    defer if (use_gpa) {
        _ = general_purpose_allocator.deinit();
    };
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try process.argsAlloc(arena);

    if (tracy.enable_allocation) {
        var gpa_tracy = tracy.tracyAllocator(gpa);
        return mainArgs(gpa_tracy.allocator(), arena, args);
    }

    // WASI: `--dir` instructs the WASM runtime to "preopen" a directory, making
    // it available to the us, the guest program. This is the only way for us to
    // access files/dirs on the host filesystem
    if (builtin.os.tag == .wasi) {
        // This sets our CWD to "/preopens/cwd"
        // Dot-prefixed preopens like `--dir=.` are "mounted" at "/preopens/cwd"
        // Other preopens like `--dir=lib` are "mounted" at "/"
        try std.os.initPreopensWasi(std.heap.page_allocator, "/preopens/cwd");
    }

    return mainArgs(gpa, arena, args);
}

pub fn mainArgs(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    if (args.len <= 1) {
        std.log.info("{s}", .{usage});
        fatal("expected command argument", .{});
    }

    if (std.process.can_execv and std.os.getenvZ("ZIG_IS_DETECTING_LIBC_PATHS") != null) {
        // In this case we have accidentally invoked ourselves as "the system C compiler"
        // to figure out where libc is installed. This is essentially infinite recursion
        // via child process execution due to the CC environment variable pointing to Zig.
        // Here we ignore the CC environment variable and exec `cc` as a child process.
        // However it's possible Zig is installed as *that* C compiler as well, which is
        // why we have this additional environment variable here to check.
        var env_map = try std.process.getEnvMap(arena);

        const inf_loop_env_key = "ZIG_IS_TRYING_TO_NOT_CALL_ITSELF";
        if (env_map.get(inf_loop_env_key) != null) {
            fatal("The compilation links against libc, but Zig is unable to provide a libc " ++
                "for this operating system, and no --libc " ++
                "parameter was provided, so Zig attempted to invoke the system C compiler " ++
                "in order to determine where libc is installed. However the system C " ++
                "compiler is `zig cc`, so no libc installation was found.", .{});
        }
        try env_map.put(inf_loop_env_key, "1");

        // Some programs such as CMake will strip the `cc` and subsequent args from the
        // CC environment variable. We detect and support this scenario here because of
        // the ZIG_IS_DETECTING_LIBC_PATHS environment variable.
        if (mem.eql(u8, args[1], "cc")) {
            return std.process.execve(arena, args[1..], &env_map);
        } else {
            const modified_args = try arena.dupe([]const u8, args);
            modified_args[0] = "cc";
            return std.process.execve(arena, modified_args, &env_map);
        }
    }

    defer log_scopes.deinit(gpa);

    const cmd = args[1];
    const cmd_args = args[2..];
    if (mem.eql(u8, cmd, "build-exe")) {
        return buildOutputType(gpa, arena, args, .{ .build = .Exe });
    } else if (mem.eql(u8, cmd, "build-lib")) {
        return buildOutputType(gpa, arena, args, .{ .build = .Lib });
    } else if (mem.eql(u8, cmd, "build-obj")) {
        return buildOutputType(gpa, arena, args, .{ .build = .Obj });
    } else if (mem.eql(u8, cmd, "test")) {
        return buildOutputType(gpa, arena, args, .zig_test);
    } else if (mem.eql(u8, cmd, "run")) {
        return buildOutputType(gpa, arena, args, .run);
    } else if (mem.eql(u8, cmd, "dlltool") or
        mem.eql(u8, cmd, "ranlib") or
        mem.eql(u8, cmd, "lib") or
        mem.eql(u8, cmd, "ar"))
    {
        return process.exit(try llvmArMain(arena, args));
    } else if (mem.eql(u8, cmd, "cc")) {
        return buildOutputType(gpa, arena, args, .cc);
    } else if (mem.eql(u8, cmd, "c++")) {
        return buildOutputType(gpa, arena, args, .cpp);
    } else if (mem.eql(u8, cmd, "translate-c")) {
        return buildOutputType(gpa, arena, args, .translate_c);
    } else if (mem.eql(u8, cmd, "clang") or
        mem.eql(u8, cmd, "-cc1") or mem.eql(u8, cmd, "-cc1as"))
    {
        return process.exit(try clangMain(arena, args));
    } else if (mem.eql(u8, cmd, "ld.lld") or
        mem.eql(u8, cmd, "lld-link") or
        mem.eql(u8, cmd, "wasm-ld"))
    {
        return process.exit(try lldMain(arena, args, true));
    } else if (mem.eql(u8, cmd, "build")) {
        return cmdBuild(gpa, arena, cmd_args);
    } else if (mem.eql(u8, cmd, "fmt")) {
        return cmdFmt(gpa, arena, cmd_args);
    } else if (mem.eql(u8, cmd, "libc")) {
        return cmdLibC(gpa, cmd_args);
    } else if (mem.eql(u8, cmd, "init-exe")) {
        return cmdInit(gpa, arena, cmd_args, .Exe);
    } else if (mem.eql(u8, cmd, "init-lib")) {
        return cmdInit(gpa, arena, cmd_args, .Lib);
    } else if (mem.eql(u8, cmd, "targets")) {
        const info = try detectNativeTargetInfo(arena, .{});
        const stdout = io.getStdOut().writer();
        return @import("print_targets.zig").cmdTargets(arena, cmd_args, stdout, info.target);
    } else if (mem.eql(u8, cmd, "version")) {
        return std.io.getStdOut().writeAll(build_options.version ++ "\n");
    } else if (mem.eql(u8, cmd, "env")) {
        return @import("print_env.zig").cmdEnv(arena, cmd_args, io.getStdOut().writer());
    } else if (mem.eql(u8, cmd, "zen")) {
        return io.getStdOut().writeAll(info_zen);
    } else if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "-h") or mem.eql(u8, cmd, "--help")) {
        return io.getStdOut().writeAll(usage);
    } else if (mem.eql(u8, cmd, "ast-check")) {
        return cmdAstCheck(gpa, arena, cmd_args);
    } else if (debug_extensions_enabled and mem.eql(u8, cmd, "changelist")) {
        return cmdChangelist(gpa, arena, cmd_args);
    } else {
        std.log.info("{s}", .{usage});
        fatal("unknown command: {s}", .{args[1]});
    }
}

const usage_build_generic =
    \\Usage: zig build-exe   [options] [files]
    \\       zig build-lib   [options] [files]
    \\       zig build-obj   [options] [files]
    \\       zig test        [options] [files]
    \\       zig run         [options] [files] [-- [args]]
    \\       zig translate-c [options] [file]
    \\
    \\Supported file types:
    \\                    .zig    Zig source code
    \\                      .o    ELF object file
    \\                      .o    Mach-O (macOS) object file
    \\                      .o    WebAssembly object file
    \\                    .obj    COFF (Windows) object file
    \\                    .lib    COFF (Windows) static library
    \\                      .a    ELF static library
    \\                      .a    Mach-O (macOS) static library
    \\                      .a    WebAssembly static library
    \\                     .so    ELF shared object (dynamic link)
    \\                    .dll    Windows Dynamic Link Library
    \\                  .dylib    Mach-O (macOS) dynamic library
    \\                    .tbd    (macOS) text-based dylib definition
    \\                      .s    Target-specific assembly source code
    \\                      .S    Assembly with C preprocessor (requires LLVM extensions)
    \\                      .c    C source code (requires LLVM extensions)
    \\  .cxx .cc .C .cpp .stub    C++ source code (requires LLVM extensions)
    \\                      .m    Objective-C source code (requires LLVM extensions)
    \\                     .mm    Objective-C++ source code (requires LLVM extensions)
    \\                     .bc    LLVM IR Module (requires LLVM extensions)
    \\                     .cu    Cuda source code (requires LLVM extensions)
    \\
    \\General Options:
    \\  -h, --help                Print this help and exit
    \\  --watch                   Enable compiler REPL
    \\  --color [auto|off|on]     Enable or disable colored error messages
    \\  -femit-bin[=path]         (default) Output machine code
    \\  -fno-emit-bin             Do not output machine code
    \\  -femit-asm[=path]         Output .s (assembly code)
    \\  -fno-emit-asm             (default) Do not output .s (assembly code)
    \\  -femit-llvm-ir[=path]     Produce a .ll file with LLVM IR (requires LLVM extensions)
    \\  -fno-emit-llvm-ir         (default) Do not produce a .ll file with LLVM IR
    \\  -femit-llvm-bc[=path]     Produce a LLVM module as a .bc file (requires LLVM extensions)
    \\  -fno-emit-llvm-bc         (default) Do not produce a LLVM module as a .bc file
    \\  -femit-h[=path]           Generate a C header file (.h)
    \\  -fno-emit-h               (default) Do not generate a C header file (.h)
    \\  -femit-docs[=path]        Create a docs/ dir with html documentation
    \\  -fno-emit-docs            (default) Do not produce docs/ dir with html documentation
    \\  -femit-analysis[=path]    Write analysis JSON file with type information
    \\  -fno-emit-analysis        (default) Do not write analysis JSON file with type information
    \\  -femit-implib[=path]      (default) Produce an import .lib when building a Windows DLL
    \\  -fno-emit-implib          Do not produce an import .lib when building a Windows DLL
    \\  --show-builtin            Output the source of @import("builtin") then exit
    \\  --cache-dir [path]        Override the local cache directory
    \\  --global-cache-dir [path] Override the global cache directory
    \\  --zig-lib-dir [path]      Override path to Zig installation lib directory
    \\  --enable-cache            Output to cache directory; print path to stdout
    \\
    \\Compile Options:
    \\  -target [name]            <arch><sub>-<os>-<abi> see the targets command
    \\  -mcpu [cpu]               Specify target CPU and feature set
    \\  -mcmodel=[default|tiny|   Limit range of code and data virtual addresses
    \\            small|kernel|
    \\            medium|large]
    \\  -mred-zone                Force-enable the "red-zone"
    \\  -mno-red-zone             Force-disable the "red-zone"
    \\  -fomit-frame-pointer      Omit the stack frame pointer
    \\  -fno-omit-frame-pointer   Store the stack frame pointer
    \\  -mexec-model=[value]      (WASI) Execution model
    \\  --name [name]             Override root name (not a file path)
    \\  -O [mode]                 Choose what to optimize for
    \\    Debug                   (default) Optimizations off, safety on
    \\    ReleaseFast             Optimizations on, safety off
    \\    ReleaseSafe             Optimizations on, safety on
    \\    ReleaseSmall            Optimize for small binary, safety off
    \\  --pkg-begin [name] [path] Make pkg available to import and push current pkg
    \\  --pkg-end                 Pop current pkg
    \\  --main-pkg-path           Set the directory of the root package
    \\  -fPIC                     Force-enable Position Independent Code
    \\  -fno-PIC                  Force-disable Position Independent Code
    \\  -fPIE                     Force-enable Position Independent Executable
    \\  -fno-PIE                  Force-disable Position Independent Executable
    \\  -flto                     Force-enable Link Time Optimization (requires LLVM extensions)
    \\  -fno-lto                  Force-disable Link Time Optimization
    \\  -fstack-check             Enable stack probing in unsafe builds
    \\  -fno-stack-check          Disable stack probing in safe builds
    \\  -fsanitize-c              Enable C undefined behavior detection in unsafe builds
    \\  -fno-sanitize-c           Disable C undefined behavior detection in safe builds
    \\  -fvalgrind                Include valgrind client requests in release builds
    \\  -fno-valgrind             Omit valgrind client requests in debug builds
    \\  -fsanitize-thread         Enable Thread Sanitizer
    \\  -fno-sanitize-thread      Disable Thread Sanitizer
    \\  -fdll-export-fns          Mark exported functions as DLL exports (Windows)
    \\  -fno-dll-export-fns       Force-disable marking exported functions as DLL exports
    \\  -funwind-tables           Always produce unwind table entries for all functions
    \\  -fno-unwind-tables        Never produce unwind table entries
    \\  -fLLVM                    Force using LLVM as the codegen backend
    \\  -fno-LLVM                 Prevent using LLVM as the codegen backend
    \\  -fClang                   Force using Clang as the C/C++ compilation backend
    \\  -fno-Clang                Prevent using Clang as the C/C++ compilation backend
    \\  -fstage1                  Force using bootstrap compiler as the codegen backend
    \\  -fno-stage1               Prevent using bootstrap compiler as the codegen backend
    \\  -fsingle-threaded         Code assumes there is only one thread
    \\  -fno-single-threaded      Code may not assume there is only one thread
    \\  -fbuiltin                 Enable implicit builtin knowledge of functions
    \\  -fno-builtin              Disable implicit builtin knowledge of functions
    \\  -ffunction-sections       Places each function in a separate section
    \\  -fno-function-sections    All functions go into same section
    \\  --strip                   Omit debug symbols
    \\  -ofmt=[mode]              Override target object format
    \\    elf                     Executable and Linking Format
    \\    c                       C source code
    \\    wasm                    WebAssembly
    \\    coff                    Common Object File Format (Windows)
    \\    macho                   macOS relocatables
    \\    spirv                   Standard, Portable Intermediate Representation V (SPIR-V)
    \\    plan9                   Plan 9 from Bell Labs object format
    \\    hex  (planned feature)  Intel IHEX
    \\    raw  (planned feature)  Dump machine code directly
    \\  -dirafter [dir]           Add directory to AFTER include search path
    \\  -isystem  [dir]           Add directory to SYSTEM include search path
    \\  -I[dir]                   Add directory to include search path
    \\  -D[macro]=[value]         Define C [macro] to [value] (1 if [value] omitted)
    \\  --libc [file]             Provide a file which specifies libc paths
    \\  -cflags [flags] --        Set extra flags for the next positional C source files
    \\
    \\Link Options:
    \\  -l[lib], --library [lib]       Link against system library (only if actually used)
    \\  -needed-l[lib],                Link against system library (even if unused)
    \\    --needed-library [lib]
    \\  -L[d], --library-directory [d] Add a directory to the library search path
    \\  -T[script], --script [script]  Use a custom linker script
    \\  --version-script [path]        Provide a version .map file
    \\  --dynamic-linker [path]        Set the dynamic interpreter path (usually ld.so)
    \\  --sysroot [path]               Set the system root directory (usually /)
    \\  --version [ver]                Dynamic library semver
    \\  --entry [name]                 Set the entrypoint symbol name
    \\  -fsoname[=name]                Override the default SONAME value
    \\  -fno-soname                    Disable emitting a SONAME
    \\  -fLLD                          Force using LLD as the linker
    \\  -fno-LLD                       Prevent using LLD as the linker
    \\  -fcompiler-rt                  Always include compiler-rt symbols in output
    \\  -fno-compiler-rt               Prevent including compiler-rt symbols in output
    \\  -rdynamic                      Add all symbols to the dynamic symbol table
    \\  -rpath [path]                  Add directory to the runtime library search path
    \\  -feach-lib-rpath               Ensure adding rpath for each used dynamic library
    \\  -fno-each-lib-rpath            Prevent adding rpath for each used dynamic library
    \\  -fallow-shlib-undefined        Allows undefined symbols in shared libraries
    \\  -fno-allow-shlib-undefined     Disallows undefined symbols in shared libraries
    \\  -fbuild-id                     Helps coordinate stripped binaries with debug symbols
    \\  -fno-build-id                  (default) Saves a bit of time linking
    \\  --eh-frame-hdr                 Enable C++ exception handling by passing --eh-frame-hdr to linker
    \\  --emit-relocs                  Enable output of relocation sections for post build tools
    \\  -z [arg]                       Set linker extension flags
    \\    nodelete                     Indicate that the object cannot be deleted from a process
    \\    notext                       Permit read-only relocations in read-only segments
    \\    defs                         Force a fatal error if any undefined symbols remain
    \\    origin                       Indicate that the object must have its origin processed
    \\    nocopyreloc                  Disable the creation of copy relocations
    \\    now                          (default) Force all relocations to be processed on load
    \\    lazy                         Don't force all relocations to be processed on load
    \\    relro                        (default) Force all relocations to be read-only after processing
    \\    norelro                      Don't force all relocations to be read-only after processing
    \\  -dynamic                       Force output to be dynamically linked
    \\  -static                        Force output to be statically linked
    \\  -Bsymbolic                     Bind global references locally
    \\  --compress-debug-sections=[e]  Debug section compression settings
    \\      none                       No compression
    \\      zlib                       Compression with deflate/inflate
    \\  --subsystem [subsystem]        (Windows) /SUBSYSTEM:<subsystem> to the linker
    \\  --stack [size]                 Override default stack size
    \\  --image-base [addr]            Set base address for executable image
    \\  -weak-l[lib]                   (Darwin) link against system library and mark it and all referenced symbols as weak
    \\    -weak_library [lib]
    \\  -framework [name]              (Darwin) link against framework
    \\  -needed_framework [name]       (Darwin) link against framework (even if unused)
    \\  -needed_library [lib]          (Darwin) link against system library (even if unused)
    \\  -weak_framework [name]         (Darwin) link against framework and mark it and all referenced symbols as weak
    \\  -F[dir]                        (Darwin) add search path for frameworks
    \\  -install_name=[value]          (Darwin) add dylib's install name
    \\  --entitlements [path]          (Darwin) add path to entitlements file for embedding in code signature
    \\  -pagezero_size [value]         (Darwin) size of the __PAGEZERO segment in hexadecimal notation
    \\  -search_paths_first            (Darwin) search each dir in library search paths for `libx.dylib` then `libx.a`
    \\  -search_dylibs_first           (Darwin) search `libx.dylib` in each dir in library search paths, then `libx.a`
    \\  -headerpad [value]             (Darwin) set minimum space for future expansion of the load commands in hexadecimal notation
    \\  -headerpad_max_install_names   (Darwin) set enough space as if all paths were MAXPATHLEN
    \\  -dead_strip_dylibs             (Darwin) remove dylibs that are unreachable by the entry point or exported symbols
    \\  --import-memory                (WebAssembly) import memory from the environment
    \\  --import-table                 (WebAssembly) import function table from the host environment
    \\  --export-table                 (WebAssembly) export function table to the host environment
    \\  --initial-memory=[bytes]       (WebAssembly) initial size of the linear memory
    \\  --max-memory=[bytes]           (WebAssembly) maximum size of the linear memory
    \\  --shared-memory                (WebAssembly) use shared linear memory
    \\  --global-base=[addr]           (WebAssembly) where to start to place global data
    \\  --export=[value]               (WebAssembly) Force a symbol to be exported
    \\
    \\Test Options:
    \\  --test-filter [text]           Skip tests that do not match filter
    \\  --test-name-prefix [text]      Add prefix to all tests
    \\  --test-cmd [arg]               Specify test execution command one arg at a time
    \\  --test-cmd-bin                 Appends test binary path to test cmd args
    \\  --test-evented-io              Runs the test in evented I/O mode
    \\  --test-no-exec                 Compiles test binary without running it
    \\
    \\Debug Options (Zig Compiler Development):
    \\  -ftime-report                Print timing diagnostics
    \\  -fstack-report               Print stack size diagnostics
    \\  --verbose-link               Display linker invocations
    \\  --verbose-cc                 Display C compiler invocations
    \\  --verbose-air                Enable compiler debug output for Zig AIR
    \\  --verbose-mir                Enable compiler debug output for Zig MIR
    \\  --verbose-llvm-ir            Enable compiler debug output for LLVM IR
    \\  --verbose-cimport            Enable compiler debug output for C imports
    \\  --verbose-llvm-cpu-features  Enable compiler debug output for LLVM CPU features
    \\  --debug-log [scope]          Enable printing debug/info log messages for scope
    \\  --debug-compile-errors       Crash with helpful diagnostics at the first compile error
    \\  --debug-link-snapshot        Enable dumping of the linker's state in JSON format
    \\
;

const repl_help =
    \\Commands:
    \\         update  Detect changes to source files and update output files.
    \\            run  Execute the output file, if it is an executable or test.
    \\ update-and-run  Perform an `update` followed by `run`.
    \\           help  Print this text
    \\           exit  Quit this repl
    \\
;

const SOName = union(enum) {
    no,
    yes_default_value,
    yes: []const u8,
};

const EmitBin = union(enum) {
    no,
    yes_default_path,
    yes: []const u8,
    yes_a_out,
};

const Emit = union(enum) {
    no,
    yes_default_path,
    yes: []const u8,

    const Resolved = struct {
        data: ?Compilation.EmitLoc,
        dir: ?fs.Dir,

        fn deinit(self: *Resolved) void {
            if (self.dir) |*dir| {
                dir.close();
            }
        }
    };

    fn resolve(emit: Emit, default_basename: []const u8) !Resolved {
        var resolved: Resolved = .{ .data = null, .dir = null };
        errdefer resolved.deinit();

        switch (emit) {
            .no => {},
            .yes_default_path => {
                resolved.data = Compilation.EmitLoc{
                    .directory = .{ .path = null, .handle = fs.cwd() },
                    .basename = default_basename,
                };
            },
            .yes => |full_path| {
                const basename = fs.path.basename(full_path);
                if (fs.path.dirname(full_path)) |dirname| {
                    const handle = try fs.cwd().openDir(dirname, .{});
                    resolved = .{
                        .dir = handle,
                        .data = Compilation.EmitLoc{
                            .basename = basename,
                            .directory = .{
                                .path = dirname,
                                .handle = handle,
                            },
                        },
                    };
                } else {
                    resolved.data = Compilation.EmitLoc{
                        .basename = basename,
                        .directory = .{ .path = null, .handle = fs.cwd() },
                    };
                }
            },
        }
        return resolved;
    }
};

fn optionalStringEnvVar(arena: Allocator, name: []const u8) !?[]const u8 {
    if (std.process.getEnvVarOwned(arena, name)) |value| {
        return value;
    } else |err| switch (err) {
        error.EnvironmentVariableNotFound => return null,
        else => |e| return e,
    }
}

const ArgMode = union(enum) {
    build: std.builtin.OutputMode,
    cc,
    cpp,
    translate_c,
    zig_test,
    run,
};

fn buildOutputType(
    gpa: Allocator,
    arena: Allocator,
    all_args: []const []const u8,
    arg_mode: ArgMode,
) !void {
    var color: Color = .auto;
    var optimize_mode: std.builtin.Mode = .Debug;
    var provided_name: ?[]const u8 = null;
    var link_mode: ?std.builtin.LinkMode = null;
    var dll_export_fns: ?bool = null;
    var single_threaded: ?bool = null;
    var root_src_file: ?[]const u8 = null;
    var version: std.builtin.Version = .{ .major = 0, .minor = 0, .patch = 0 };
    var have_version = false;
    var compatibility_version: ?std.builtin.Version = null;
    var strip = false;
    var function_sections = false;
    var no_builtin = false;
    var watch = false;
    var debug_compile_errors = false;
    var verbose_link = std.process.hasEnvVarConstant("ZIG_VERBOSE_LINK");
    var verbose_cc = std.process.hasEnvVarConstant("ZIG_VERBOSE_CC");
    var verbose_air = false;
    var verbose_llvm_ir = false;
    var verbose_cimport = false;
    var verbose_llvm_cpu_features = false;
    var time_report = false;
    var stack_report = false;
    var show_builtin = false;
    var emit_bin: EmitBin = .yes_default_path;
    var emit_asm: Emit = .no;
    var emit_llvm_ir: Emit = .no;
    var emit_llvm_bc: Emit = .no;
    var emit_docs: Emit = .no;
    var emit_analysis: Emit = .no;
    var emit_implib: Emit = .yes_default_path;
    var emit_implib_arg_provided = false;
    var target_arch_os_abi: []const u8 = "native";
    var target_mcpu: ?[]const u8 = null;
    var target_dynamic_linker: ?[]const u8 = null;
    var target_ofmt: ?[]const u8 = null;
    var output_mode: std.builtin.OutputMode = undefined;
    var emit_h: Emit = .no;
    var soname: SOName = undefined;
    var ensure_libc_on_non_freestanding = false;
    var ensure_libcpp_on_non_freestanding = false;
    var link_libc = false;
    var link_libcpp = false;
    var link_libunwind = false;
    var want_native_include_dirs = false;
    var enable_cache: ?bool = null;
    var want_pic: ?bool = null;
    var want_pie: ?bool = null;
    var want_lto: ?bool = null;
    var want_unwind_tables: ?bool = null;
    var want_sanitize_c: ?bool = null;
    var want_stack_check: ?bool = null;
    var want_red_zone: ?bool = null;
    var omit_frame_pointer: ?bool = null;
    var want_valgrind: ?bool = null;
    var want_tsan: ?bool = null;
    var want_compiler_rt: ?bool = null;
    var rdynamic: bool = false;
    var linker_script: ?[]const u8 = null;
    var version_script: ?[]const u8 = null;
    var disable_c_depfile = false;
    var linker_gc_sections: ?bool = null;
    var linker_compress_debug_sections: ?link.CompressDebugSections = null;
    var linker_allow_shlib_undefined: ?bool = null;
    var linker_bind_global_refs_locally: ?bool = null;
    var linker_import_memory: ?bool = null;
    var linker_import_table: bool = false;
    var linker_export_table: bool = false;
    var linker_initial_memory: ?u64 = null;
    var linker_max_memory: ?u64 = null;
    var linker_shared_memory: bool = false;
    var linker_global_base: ?u64 = null;
    var linker_z_nodelete = false;
    var linker_z_notext = false;
    var linker_z_defs = false;
    var linker_z_origin = false;
    var linker_z_now = true;
    var linker_z_relro = true;
    var linker_tsaware = false;
    var linker_nxcompat = false;
    var linker_dynamicbase = false;
    var linker_optimization: ?u8 = null;
    var test_evented_io = false;
    var test_no_exec = false;
    var entry: ?[]const u8 = null;
    var stack_size_override: ?u64 = null;
    var image_base_override: ?u64 = null;
    var use_llvm: ?bool = null;
    var use_lld: ?bool = null;
    var use_clang: ?bool = null;
    var use_stage1: ?bool = null;
    var link_eh_frame_hdr = false;
    var link_emit_relocs = false;
    var each_lib_rpath: ?bool = null;
    var build_id: ?bool = null;
    var sysroot: ?[]const u8 = null;
    var libc_paths_file: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LIBC");
    var machine_code_model: std.builtin.CodeModel = .default;
    var runtime_args_start: ?usize = null;
    var test_filter: ?[]const u8 = null;
    var test_name_prefix: ?[]const u8 = null;
    var override_local_cache_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LOCAL_CACHE_DIR");
    var override_global_cache_dir: ?[]const u8 = null;
    var override_lib_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LIB_DIR");
    var main_pkg_path: ?[]const u8 = null;
    var clang_preprocessor_mode: Compilation.ClangPreprocessorMode = .no;
    var subsystem: ?std.Target.SubSystem = null;
    var major_subsystem_version: ?u32 = null;
    var minor_subsystem_version: ?u32 = null;
    var wasi_exec_model: ?std.builtin.WasiExecModel = null;
    var enable_link_snapshots: bool = false;
    var native_darwin_sdk: ?std.zig.system.darwin.DarwinSDK = null;
    var install_name: ?[]const u8 = null;
    var hash_style: link.HashStyle = .both;
    var entitlements: ?[]const u8 = null;
    var pagezero_size: ?u64 = null;
    var search_strategy: ?link.File.MachO.SearchStrategy = null;
    var headerpad_size: ?u32 = null;
    var headerpad_max_install_names: bool = false;
    var dead_strip_dylibs: bool = false;

    // e.g. -m3dnow or -mno-outline-atomics. They correspond to std.Target llvm cpu feature names.
    // This array is populated by zig cc frontend and then has to be converted to zig-style
    // CPU features.
    var llvm_m_args = std.ArrayList([]const u8).init(gpa);
    defer llvm_m_args.deinit();

    var system_libs = std.StringArrayHashMap(Compilation.SystemLib).init(gpa);
    defer system_libs.deinit();

    var static_libs = std.ArrayList([]const u8).init(gpa);
    defer static_libs.deinit();

    var wasi_emulated_libs = std.ArrayList(wasi_libc.CRTFile).init(gpa);
    defer wasi_emulated_libs.deinit();

    var clang_argv = std.ArrayList([]const u8).init(gpa);
    defer clang_argv.deinit();

    var extra_cflags = std.ArrayList([]const u8).init(gpa);
    defer extra_cflags.deinit();

    var lib_dirs = std.ArrayList([]const u8).init(gpa);
    defer lib_dirs.deinit();

    var rpath_list = std.ArrayList([]const u8).init(gpa);
    defer rpath_list.deinit();

    var c_source_files = std.ArrayList(Compilation.CSourceFile).init(gpa);
    defer c_source_files.deinit();

    var link_objects = std.ArrayList(Compilation.LinkObject).init(gpa);
    defer link_objects.deinit();

    // This map is a flag per link_objects item, used to represent the
    // `-l :file.so` syntax from gcc/clang.
    // This is only exposed from the `zig cc` interface. It means that the `path`
    // field from the corresponding `link_objects` element is a suffix, and is
    // to be tried against each library path as a prefix until an existing file is found.
    // This map remains empty for the main CLI.
    var link_objects_lib_search_paths: std.AutoHashMapUnmanaged(u32, void) = .{};

    var framework_dirs = std.ArrayList([]const u8).init(gpa);
    defer framework_dirs.deinit();

    var frameworks: std.StringArrayHashMapUnmanaged(Compilation.SystemLib) = .{};

    // null means replace with the test executable binary
    var test_exec_args = std.ArrayList(?[]const u8).init(gpa);
    defer test_exec_args.deinit();

    var linker_export_symbol_names = std.ArrayList([]const u8).init(gpa);
    defer linker_export_symbol_names.deinit();

    // This package only exists to clean up the code parsing --pkg-begin and
    // --pkg-end flags. Use dummy values that are safe for the destroy call.
    var pkg_tree_root: Package = .{
        .root_src_directory = .{ .path = null, .handle = fs.cwd() },
        .root_src_path = &[0]u8{},
    };
    defer freePkgTree(gpa, &pkg_tree_root, false);
    var cur_pkg: *Package = &pkg_tree_root;

    // before arg parsing, check for the NO_COLOR environment variable
    // if it exists, default the color setting to .off
    // explicit --color arguments will still override this setting.
    color = if (std.process.hasEnvVarConstant("NO_COLOR")) .off else .auto;

    switch (arg_mode) {
        .build, .translate_c, .zig_test, .run => {
            var optimize_mode_string: ?[]const u8 = null;
            switch (arg_mode) {
                .build => |m| {
                    output_mode = m;
                },
                .translate_c => {
                    emit_bin = .no;
                    output_mode = .Obj;
                },
                .zig_test, .run => {
                    output_mode = .Exe;
                },
                else => unreachable,
            }

            soname = .yes_default_value;

            const Iterator = struct {
                resp_file: ?ArgIteratorResponseFile = null,
                args: []const []const u8,
                i: usize = 0,
                fn next(it: *@This()) ?[]const u8 {
                    if (it.i >= it.args.len) {
                        if (it.resp_file) |*resp| return if (resp.next()) |sentinel| std.mem.span(sentinel) else null;
                        return null;
                    }
                    defer it.i += 1;
                    return it.args[it.i];
                }
            };
            var args_iter = Iterator{
                .args = all_args[2..],
            };

            args_loop: while (args_iter.next()) |arg| {
                if (mem.startsWith(u8, arg, "@")) {
                    // This is a "compiler response file". We must parse the file and treat its
                    // contents as command line parameters.
                    const resp_file_path = arg[1..];
                    args_iter.resp_file = initArgIteratorResponseFile(arena, resp_file_path) catch |err| {
                        fatal("unable to read response file '{s}': {s}", .{ resp_file_path, @errorName(err) });
                    };
                } else if (mem.startsWith(u8, arg, "-")) {
                    if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                        try io.getStdOut().writeAll(usage_build_generic);
                        return cleanExit();
                    } else if (mem.eql(u8, arg, "--")) {
                        if (arg_mode == .run) {
                            // args_iter.i is 1, referring the next arg after "--" in ["--", ...]
                            // Add +2 to the index so it is relative to all_args
                            runtime_args_start = args_iter.i + 2;
                            break :args_loop;
                        } else {
                            fatal("unexpected end-of-parameter mark: --", .{});
                        }
                    } else if (mem.eql(u8, arg, "--pkg-begin")) {
                        const pkg_name = args_iter.next();
                        const pkg_path = args_iter.next();
                        if (pkg_name == null or pkg_path == null) fatal("Expected 2 arguments after {s}", .{arg});

                        const new_cur_pkg = Package.create(
                            gpa,
                            fs.path.dirname(pkg_path.?),
                            fs.path.basename(pkg_path.?),
                        ) catch |err| {
                            fatal("Failed to add package at path {s}: {s}", .{ pkg_path.?, @errorName(err) });
                        };
                        try cur_pkg.addAndAdopt(gpa, pkg_name.?, new_cur_pkg);
                        cur_pkg = new_cur_pkg;
                    } else if (mem.eql(u8, arg, "--pkg-end")) {
                        cur_pkg = cur_pkg.parent orelse
                            fatal("encountered --pkg-end with no matching --pkg-begin", .{});
                    } else if (mem.eql(u8, arg, "--main-pkg-path")) {
                        main_pkg_path = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "-cflags")) {
                        extra_cflags.shrinkRetainingCapacity(0);
                        while (true) {
                            const next_arg = args_iter.next() orelse {
                                fatal("expected -- after -cflags", .{});
                            };
                            if (mem.eql(u8, next_arg, "--")) break;
                            try extra_cflags.append(next_arg);
                        }
                    } else if (mem.eql(u8, arg, "--color")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected [auto|on|off] after --color", .{});
                        };
                        color = std.meta.stringToEnum(Color, next_arg) orelse {
                            fatal("expected [auto|on|off] after --color, found '{s}'", .{next_arg});
                        };
                    } else if (mem.eql(u8, arg, "--subsystem")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        subsystem = try parseSubSystem(next_arg);
                    } else if (mem.eql(u8, arg, "-O")) {
                        optimize_mode_string = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--entry")) {
                        entry = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--stack")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        stack_size_override = std.fmt.parseUnsigned(u64, next_arg, 0) catch |err| {
                            fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "--image-base")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        image_base_override = std.fmt.parseUnsigned(u64, next_arg, 0) catch |err| {
                            fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "--name")) {
                        provided_name = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "-rpath")) {
                        try rpath_list.append(args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        });
                    } else if (mem.eql(u8, arg, "--library-directory") or mem.eql(u8, arg, "-L")) {
                        try lib_dirs.append(args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        });
                    } else if (mem.eql(u8, arg, "-F")) {
                        try framework_dirs.append(args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        });
                    } else if (mem.eql(u8, arg, "-framework")) {
                        const path = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        try frameworks.put(gpa, path, .{});
                    } else if (mem.eql(u8, arg, "-weak_framework")) {
                        const path = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        try frameworks.put(gpa, path, .{ .weak = true });
                    } else if (mem.eql(u8, arg, "-needed_framework")) {
                        const path = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        try frameworks.put(gpa, path, .{ .needed = true });
                    } else if (mem.eql(u8, arg, "-install_name")) {
                        install_name = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.startsWith(u8, arg, "--compress-debug-sections=")) {
                        const param = arg["--compress-debug-sections=".len..];
                        linker_compress_debug_sections = std.meta.stringToEnum(link.CompressDebugSections, param) orelse {
                            fatal("expected --compress-debug-sections=[none|zlib], found '{s}'", .{param});
                        };
                    } else if (mem.eql(u8, arg, "--compress-debug-sections")) {
                        linker_compress_debug_sections = link.CompressDebugSections.zlib;
                    } else if (mem.eql(u8, arg, "-pagezero_size")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        pagezero_size = std.fmt.parseUnsigned(u64, eatIntPrefix(next_arg, 16), 16) catch |err| {
                            fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "-search_paths_first")) {
                        search_strategy = .paths_first;
                    } else if (mem.eql(u8, arg, "-search_dylibs_first")) {
                        search_strategy = .dylibs_first;
                    } else if (mem.eql(u8, arg, "-headerpad")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        headerpad_size = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                            fatal("unable to parser '{s}': {s}", .{ arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "-headerpad_max_install_names")) {
                        headerpad_max_install_names = true;
                    } else if (mem.eql(u8, arg, "-dead_strip_dylibs")) {
                        dead_strip_dylibs = true;
                    } else if (mem.eql(u8, arg, "-T") or mem.eql(u8, arg, "--script")) {
                        linker_script = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--version-script")) {
                        version_script = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--library") or mem.eql(u8, arg, "-l")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        // We don't know whether this library is part of libc or libc++ until
                        // we resolve the target, so we simply append to the list for now.
                        try system_libs.put(next_arg, .{});
                    } else if (mem.eql(u8, arg, "--needed-library") or
                        mem.eql(u8, arg, "-needed-l") or
                        mem.eql(u8, arg, "-needed_library"))
                    {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        try system_libs.put(next_arg, .{ .needed = true });
                    } else if (mem.eql(u8, arg, "-weak_library") or mem.eql(u8, arg, "-weak-l")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        try system_libs.put(next_arg, .{ .weak = true });
                    } else if (mem.eql(u8, arg, "-D") or
                        mem.eql(u8, arg, "-isystem") or
                        mem.eql(u8, arg, "-I") or
                        mem.eql(u8, arg, "-dirafter") or
                        mem.eql(u8, arg, "-iwithsysroot") or
                        mem.eql(u8, arg, "-iframework") or
                        mem.eql(u8, arg, "-iframeworkwithsysroot"))
                    {
                        try clang_argv.append(arg);
                        try clang_argv.append(args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        });
                    } else if (mem.eql(u8, arg, "--version")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        version = std.builtin.Version.parse(next_arg) catch |err| {
                            fatal("unable to parse --version '{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                        have_version = true;
                    } else if (mem.eql(u8, arg, "-target")) {
                        target_arch_os_abi = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "-mcpu")) {
                        target_mcpu = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "-mcmodel")) {
                        machine_code_model = parseCodeModel(args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        });
                    } else if (mem.startsWith(u8, arg, "-ofmt=")) {
                        target_ofmt = arg["-ofmt=".len..];
                    } else if (mem.startsWith(u8, arg, "-mcpu=")) {
                        target_mcpu = arg["-mcpu=".len..];
                    } else if (mem.startsWith(u8, arg, "-mcmodel=")) {
                        machine_code_model = parseCodeModel(arg["-mcmodel=".len..]);
                    } else if (mem.startsWith(u8, arg, "-O")) {
                        optimize_mode_string = arg["-O".len..];
                    } else if (mem.eql(u8, arg, "--dynamic-linker")) {
                        target_dynamic_linker = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--sysroot")) {
                        sysroot = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        try clang_argv.append("-isysroot");
                        try clang_argv.append(sysroot.?);
                    } else if (mem.eql(u8, arg, "--libc")) {
                        libc_paths_file = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--test-filter")) {
                        test_filter = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--test-name-prefix")) {
                        test_name_prefix = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--test-cmd")) {
                        try test_exec_args.append(args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        });
                    } else if (mem.eql(u8, arg, "--cache-dir")) {
                        override_local_cache_dir = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--global-cache-dir")) {
                        override_global_cache_dir = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                        override_lib_dir = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "--debug-log")) {
                        const next_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        if (!build_options.enable_logging) {
                            std.log.warn("Zig was compiled without logging enabled (-Dlog). --debug-log has no effect.", .{});
                        } else {
                            try log_scopes.append(gpa, next_arg);
                        }
                    } else if (mem.eql(u8, arg, "--debug-link-snapshot")) {
                        if (!build_options.enable_link_snapshots) {
                            std.log.warn("Zig was compiled without linker snapshots enabled (-Dlink-snapshot). --debug-link-snapshot has no effect.", .{});
                        } else {
                            enable_link_snapshots = true;
                        }
                    } else if (mem.eql(u8, arg, "--entitlements")) {
                        entitlements = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                    } else if (mem.eql(u8, arg, "-fcompiler-rt")) {
                        want_compiler_rt = true;
                    } else if (mem.eql(u8, arg, "-fno-compiler-rt")) {
                        want_compiler_rt = false;
                    } else if (mem.eql(u8, arg, "-feach-lib-rpath")) {
                        each_lib_rpath = true;
                    } else if (mem.eql(u8, arg, "-fno-each-lib-rpath")) {
                        each_lib_rpath = false;
                    } else if (mem.eql(u8, arg, "-fbuild-id")) {
                        build_id = true;
                    } else if (mem.eql(u8, arg, "-fno-build-id")) {
                        build_id = false;
                    } else if (mem.eql(u8, arg, "--enable-cache")) {
                        enable_cache = true;
                    } else if (mem.eql(u8, arg, "--test-cmd-bin")) {
                        try test_exec_args.append(null);
                    } else if (mem.eql(u8, arg, "--test-evented-io")) {
                        test_evented_io = true;
                    } else if (mem.eql(u8, arg, "--test-no-exec")) {
                        test_no_exec = true;
                    } else if (mem.eql(u8, arg, "--watch")) {
                        watch = true;
                    } else if (mem.eql(u8, arg, "-ftime-report")) {
                        time_report = true;
                    } else if (mem.eql(u8, arg, "-fstack-report")) {
                        stack_report = true;
                    } else if (mem.eql(u8, arg, "-fPIC")) {
                        want_pic = true;
                    } else if (mem.eql(u8, arg, "-fno-PIC")) {
                        want_pic = false;
                    } else if (mem.eql(u8, arg, "-fPIE")) {
                        want_pie = true;
                    } else if (mem.eql(u8, arg, "-fno-PIE")) {
                        want_pie = false;
                    } else if (mem.eql(u8, arg, "-flto")) {
                        want_lto = true;
                    } else if (mem.eql(u8, arg, "-fno-lto")) {
                        want_lto = false;
                    } else if (mem.eql(u8, arg, "-funwind-tables")) {
                        want_unwind_tables = true;
                    } else if (mem.eql(u8, arg, "-fno-unwind-tables")) {
                        want_unwind_tables = false;
                    } else if (mem.eql(u8, arg, "-fstack-check")) {
                        want_stack_check = true;
                    } else if (mem.eql(u8, arg, "-fno-stack-check")) {
                        want_stack_check = false;
                    } else if (mem.eql(u8, arg, "-mred-zone")) {
                        want_red_zone = true;
                    } else if (mem.eql(u8, arg, "-mno-red-zone")) {
                        want_red_zone = false;
                    } else if (mem.eql(u8, arg, "-fomit-frame-pointer")) {
                        omit_frame_pointer = true;
                    } else if (mem.eql(u8, arg, "-fno-omit-frame-pointer")) {
                        omit_frame_pointer = false;
                    } else if (mem.eql(u8, arg, "-fsanitize-c")) {
                        want_sanitize_c = true;
                    } else if (mem.eql(u8, arg, "-fno-sanitize-c")) {
                        want_sanitize_c = false;
                    } else if (mem.eql(u8, arg, "-fvalgrind")) {
                        want_valgrind = true;
                    } else if (mem.eql(u8, arg, "-fno-valgrind")) {
                        want_valgrind = false;
                    } else if (mem.eql(u8, arg, "-fsanitize-thread")) {
                        want_tsan = true;
                    } else if (mem.eql(u8, arg, "-fno-sanitize-thread")) {
                        want_tsan = false;
                    } else if (mem.eql(u8, arg, "-fLLVM")) {
                        use_llvm = true;
                    } else if (mem.eql(u8, arg, "-fno-LLVM")) {
                        use_llvm = false;
                    } else if (mem.eql(u8, arg, "-fLLD")) {
                        use_lld = true;
                    } else if (mem.eql(u8, arg, "-fno-LLD")) {
                        use_lld = false;
                    } else if (mem.eql(u8, arg, "-fClang")) {
                        use_clang = true;
                    } else if (mem.eql(u8, arg, "-fno-Clang")) {
                        use_clang = false;
                    } else if (mem.eql(u8, arg, "-fstage1")) {
                        use_stage1 = true;
                    } else if (mem.eql(u8, arg, "-fno-stage1")) {
                        use_stage1 = false;
                    } else if (mem.eql(u8, arg, "-rdynamic")) {
                        rdynamic = true;
                    } else if (mem.eql(u8, arg, "-fsoname")) {
                        soname = .yes_default_value;
                    } else if (mem.startsWith(u8, arg, "-fsoname=")) {
                        soname = .{ .yes = arg["-fsoname=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-soname")) {
                        soname = .no;
                    } else if (mem.eql(u8, arg, "-femit-bin")) {
                        emit_bin = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-bin=")) {
                        emit_bin = .{ .yes = arg["-femit-bin=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-bin")) {
                        emit_bin = .no;
                    } else if (mem.eql(u8, arg, "-femit-h")) {
                        emit_h = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-h=")) {
                        emit_h = .{ .yes = arg["-femit-h=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-h")) {
                        emit_h = .no;
                    } else if (mem.eql(u8, arg, "-femit-asm")) {
                        emit_asm = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-asm=")) {
                        emit_asm = .{ .yes = arg["-femit-asm=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-asm")) {
                        emit_asm = .no;
                    } else if (mem.eql(u8, arg, "-femit-llvm-ir")) {
                        emit_llvm_ir = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-llvm-ir=")) {
                        emit_llvm_ir = .{ .yes = arg["-femit-llvm-ir=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-llvm-ir")) {
                        emit_llvm_ir = .no;
                    } else if (mem.eql(u8, arg, "-femit-llvm-bc")) {
                        emit_llvm_bc = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-llvm-bc=")) {
                        emit_llvm_bc = .{ .yes = arg["-femit-llvm-bc=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-llvm-bc")) {
                        emit_llvm_bc = .no;
                    } else if (mem.eql(u8, arg, "-femit-docs")) {
                        emit_docs = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-docs=")) {
                        emit_docs = .{ .yes = arg["-femit-docs=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-docs")) {
                        emit_docs = .no;
                    } else if (mem.eql(u8, arg, "-femit-analysis")) {
                        emit_analysis = .yes_default_path;
                    } else if (mem.startsWith(u8, arg, "-femit-analysis=")) {
                        emit_analysis = .{ .yes = arg["-femit-analysis=".len..] };
                    } else if (mem.eql(u8, arg, "-fno-emit-analysis")) {
                        emit_analysis = .no;
                    } else if (mem.eql(u8, arg, "-femit-implib")) {
                        emit_implib = .yes_default_path;
                        emit_implib_arg_provided = true;
                    } else if (mem.startsWith(u8, arg, "-femit-implib=")) {
                        emit_implib = .{ .yes = arg["-femit-implib=".len..] };
                        emit_implib_arg_provided = true;
                    } else if (mem.eql(u8, arg, "-fno-emit-implib")) {
                        emit_implib = .no;
                        emit_implib_arg_provided = true;
                    } else if (mem.eql(u8, arg, "-dynamic")) {
                        link_mode = .Dynamic;
                    } else if (mem.eql(u8, arg, "-static")) {
                        link_mode = .Static;
                    } else if (mem.eql(u8, arg, "-fdll-export-fns")) {
                        dll_export_fns = true;
                    } else if (mem.eql(u8, arg, "-fno-dll-export-fns")) {
                        dll_export_fns = false;
                    } else if (mem.eql(u8, arg, "--show-builtin")) {
                        show_builtin = true;
                        emit_bin = .no;
                    } else if (mem.eql(u8, arg, "--strip")) {
                        strip = true;
                    } else if (mem.eql(u8, arg, "-fsingle-threaded")) {
                        single_threaded = true;
                    } else if (mem.eql(u8, arg, "-fno-single-threaded")) {
                        single_threaded = false;
                    } else if (mem.eql(u8, arg, "-ffunction-sections")) {
                        function_sections = true;
                    } else if (mem.eql(u8, arg, "-fno-function-sections")) {
                        function_sections = false;
                    } else if (mem.eql(u8, arg, "-fbuiltin")) {
                        no_builtin = false;
                    } else if (mem.eql(u8, arg, "-fno-builtin")) {
                        no_builtin = true;
                    } else if (mem.eql(u8, arg, "--eh-frame-hdr")) {
                        link_eh_frame_hdr = true;
                    } else if (mem.eql(u8, arg, "--emit-relocs")) {
                        link_emit_relocs = true;
                    } else if (mem.eql(u8, arg, "-fallow-shlib-undefined")) {
                        linker_allow_shlib_undefined = true;
                    } else if (mem.eql(u8, arg, "-fno-allow-shlib-undefined")) {
                        linker_allow_shlib_undefined = false;
                    } else if (mem.eql(u8, arg, "-z")) {
                        const z_arg = args_iter.next() orelse {
                            fatal("expected parameter after {s}", .{arg});
                        };
                        if (mem.eql(u8, z_arg, "nodelete")) {
                            linker_z_nodelete = true;
                        } else if (mem.eql(u8, z_arg, "notext")) {
                            linker_z_notext = true;
                        } else if (mem.eql(u8, z_arg, "defs")) {
                            linker_z_defs = true;
                        } else if (mem.eql(u8, z_arg, "origin")) {
                            linker_z_origin = true;
                        } else if (mem.eql(u8, z_arg, "now")) {
                            linker_z_now = true;
                        } else if (mem.eql(u8, z_arg, "lazy")) {
                            linker_z_now = false;
                        } else if (mem.eql(u8, z_arg, "relro")) {
                            linker_z_relro = true;
                        } else if (mem.eql(u8, z_arg, "norelro")) {
                            linker_z_relro = false;
                        } else {
                            warn("unsupported linker extension flag: -z {s}", .{z_arg});
                        }
                    } else if (mem.eql(u8, arg, "--import-memory")) {
                        linker_import_memory = true;
                    } else if (mem.eql(u8, arg, "--import-table")) {
                        linker_import_table = true;
                    } else if (mem.eql(u8, arg, "--export-table")) {
                        linker_export_table = true;
                    } else if (mem.startsWith(u8, arg, "--initial-memory=")) {
                        linker_initial_memory = parseIntSuffix(arg, "--initial-memory=".len);
                    } else if (mem.startsWith(u8, arg, "--max-memory=")) {
                        linker_max_memory = parseIntSuffix(arg, "--max-memory=".len);
                    } else if (mem.startsWith(u8, arg, "--shared-memory")) {
                        linker_shared_memory = true;
                    } else if (mem.startsWith(u8, arg, "--global-base=")) {
                        linker_global_base = parseIntSuffix(arg, "--global-base=".len);
                    } else if (mem.startsWith(u8, arg, "--export=")) {
                        try linker_export_symbol_names.append(arg["--export=".len..]);
                    } else if (mem.eql(u8, arg, "-Bsymbolic")) {
                        linker_bind_global_refs_locally = true;
                    } else if (mem.eql(u8, arg, "--debug-compile-errors")) {
                        debug_compile_errors = true;
                    } else if (mem.eql(u8, arg, "--verbose-link")) {
                        verbose_link = true;
                    } else if (mem.eql(u8, arg, "--verbose-cc")) {
                        verbose_cc = true;
                    } else if (mem.eql(u8, arg, "--verbose-air")) {
                        verbose_air = true;
                    } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                        verbose_llvm_ir = true;
                    } else if (mem.eql(u8, arg, "--verbose-cimport")) {
                        verbose_cimport = true;
                    } else if (mem.eql(u8, arg, "--verbose-llvm-cpu-features")) {
                        verbose_llvm_cpu_features = true;
                    } else if (mem.startsWith(u8, arg, "-T")) {
                        linker_script = arg[2..];
                    } else if (mem.startsWith(u8, arg, "-L")) {
                        try lib_dirs.append(arg[2..]);
                    } else if (mem.startsWith(u8, arg, "-F")) {
                        try framework_dirs.append(arg[2..]);
                    } else if (mem.startsWith(u8, arg, "-l")) {
                        // We don't know whether this library is part of libc or libc++ until
                        // we resolve the target, so we simply append to the list for now.
                        try system_libs.put(arg["-l".len..], .{});
                    } else if (mem.startsWith(u8, arg, "-needed-l")) {
                        try system_libs.put(arg["-needed-l".len..], .{ .needed = true });
                    } else if (mem.startsWith(u8, arg, "-weak-l")) {
                        try system_libs.put(arg["-weak-l".len..], .{ .weak = true });
                    } else if (mem.startsWith(u8, arg, "-D") or
                        mem.startsWith(u8, arg, "-I"))
                    {
                        try clang_argv.append(arg);
                    } else if (mem.startsWith(u8, arg, "-mexec-model=")) {
                        wasi_exec_model = std.meta.stringToEnum(std.builtin.WasiExecModel, arg["-mexec-model=".len..]) orelse {
                            fatal("expected [command|reactor] for -mexec-mode=[value], found '{s}'", .{arg["-mexec-model=".len..]});
                        };
                    } else {
                        fatal("unrecognized parameter: '{s}'", .{arg});
                    }
                } else switch (Compilation.classifyFileExt(arg)) {
                    .object, .static_library, .shared_library => {
                        try link_objects.append(.{ .path = arg });
                    },
                    .assembly, .c, .cpp, .h, .ll, .bc, .m, .mm, .cu => {
                        try c_source_files.append(.{
                            .src_path = arg,
                            .extra_flags = try arena.dupe([]const u8, extra_cflags.items),
                        });
                    },
                    .zig => {
                        if (root_src_file) |other| {
                            fatal("found another zig file '{s}' after root source file '{s}'", .{ arg, other });
                        } else {
                            root_src_file = arg;
                        }
                    },
                    .unknown => {
                        fatal("unrecognized file extension of parameter '{s}'", .{arg});
                    },
                }
            }
            if (optimize_mode_string) |s| {
                optimize_mode = std.meta.stringToEnum(std.builtin.Mode, s) orelse
                    fatal("unrecognized optimization mode: '{s}'", .{s});
            }
        },
        .cc, .cpp => {
            emit_h = .no;
            soname = .no;
            strip = false;
            ensure_libc_on_non_freestanding = true;
            ensure_libcpp_on_non_freestanding = arg_mode == .cpp;
            want_native_include_dirs = true;
            // Clang's driver enables this switch unconditionally.
            // Disabling the emission of .eh_frame_hdr can unexpectedly break
            // some functionality that depend on it, such as C++ exceptions and
            // DWARF-based stack traces.
            link_eh_frame_hdr = true;

            const COutMode = enum {
                link,
                object,
                assembly,
                preprocessor,
            };
            var c_out_mode: COutMode = .link;
            var out_path: ?[]const u8 = null;
            var is_shared_lib = false;
            var linker_args = std.ArrayList([]const u8).init(arena);
            var it = ClangArgIterator.init(arena, all_args);
            var emit_llvm = false;
            var needed = false;
            var must_link = false;
            var force_static_libs = false;
            while (it.has_next) {
                it.next() catch |err| {
                    fatal("unable to parse command line parameters: {s}", .{@errorName(err)});
                };
                switch (it.zig_equivalent) {
                    .target => target_arch_os_abi = it.only_arg, // example: -target riscv64-linux-unknown
                    .o => {
                        // We handle -o /dev/null equivalent to -fno-emit-bin because
                        // otherwise our atomic rename into place will fail. This also
                        // makes Zig do less work, avoiding pointless file system operations.
                        if (mem.eql(u8, it.only_arg, "/dev/null")) {
                            emit_bin = .no;
                        } else {
                            out_path = it.only_arg;
                        }
                    },
                    .c => c_out_mode = .object, // -c
                    .asm_only => c_out_mode = .assembly, // -S
                    .preprocess_only => c_out_mode = .preprocessor, // -E
                    .emit_llvm => emit_llvm = true,
                    .other => {
                        try clang_argv.appendSlice(it.other_args);
                    },
                    .positional => {
                        const file_ext = Compilation.classifyFileExt(mem.sliceTo(it.only_arg, 0));
                        switch (file_ext) {
                            .assembly, .c, .cpp, .ll, .bc, .h, .m, .mm, .cu => {
                                try c_source_files.append(.{ .src_path = it.only_arg });
                            },
                            .unknown, .shared_library, .object, .static_library => {
                                try link_objects.append(.{
                                    .path = it.only_arg,
                                    .must_link = must_link,
                                });
                            },
                            .zig => {
                                if (root_src_file) |other| {
                                    fatal("found another zig file '{s}' after root source file '{s}'", .{ it.only_arg, other });
                                } else {
                                    root_src_file = it.only_arg;
                                }
                            },
                        }
                    },
                    .l => {
                        // -l
                        // We don't know whether this library is part of libc or libc++ until
                        // we resolve the target, so we simply append to the list for now.
                        if (mem.startsWith(u8, it.only_arg, ":")) {
                            // This "feature" of gcc/clang means to treat this as a positional
                            // link object, but using the library search directories as a prefix.
                            try link_objects.append(.{
                                .path = it.only_arg[1..],
                                .must_link = must_link,
                            });
                            const index = @intCast(u32, link_objects.items.len - 1);
                            try link_objects_lib_search_paths.put(arena, index, {});
                        } else if (force_static_libs) {
                            try static_libs.append(it.only_arg);
                        } else {
                            try system_libs.put(it.only_arg, .{ .needed = needed });
                        }
                    },
                    .ignore => {},
                    .driver_punt => {
                        // Never mind what we're doing, just pass the args directly. For example --help.
                        return process.exit(try clangMain(arena, all_args));
                    },
                    .pic => want_pic = true,
                    .no_pic => want_pic = false,
                    .pie => want_pie = true,
                    .no_pie => want_pie = false,
                    .lto => want_lto = true,
                    .no_lto => want_lto = false,
                    .red_zone => want_red_zone = true,
                    .no_red_zone => want_red_zone = false,
                    .omit_frame_pointer => omit_frame_pointer = true,
                    .no_omit_frame_pointer => omit_frame_pointer = false,
                    .function_sections => function_sections = true,
                    .no_function_sections => function_sections = false,
                    .builtin => no_builtin = false,
                    .no_builtin => no_builtin = true,
                    .color_diagnostics => color = .on,
                    .no_color_diagnostics => color = .off,
                    .stack_check => want_stack_check = true,
                    .no_stack_check => want_stack_check = false,
                    .unwind_tables => want_unwind_tables = true,
                    .no_unwind_tables => want_unwind_tables = false,
                    .nostdlib => ensure_libc_on_non_freestanding = false,
                    .nostdlib_cpp => ensure_libcpp_on_non_freestanding = false,
                    .shared => {
                        link_mode = .Dynamic;
                        is_shared_lib = true;
                    },
                    .rdynamic => rdynamic = true,
                    .wl => {
                        var split_it = mem.split(u8, it.only_arg, ",");
                        while (split_it.next()) |linker_arg| {
                            // Handle nested-joined args like `-Wl,-rpath=foo`.
                            // Must be prefixed with 1 or 2 dashes.
                            if (linker_arg.len >= 3 and
                                linker_arg[0] == '-' and
                                linker_arg[2] != '-')
                            {
                                if (mem.indexOfScalar(u8, linker_arg, '=')) |equals_pos| {
                                    const key = linker_arg[0..equals_pos];
                                    const value = linker_arg[equals_pos + 1 ..];
                                    if (mem.eql(u8, key, "build-id")) {
                                        build_id = true;
                                        warn("ignoring build-id style argument: '{s}'", .{value});
                                        continue;
                                    }
                                    try linker_args.append(key);
                                    try linker_args.append(value);
                                    continue;
                                }
                            }
                            if (mem.eql(u8, linker_arg, "--as-needed")) {
                                needed = false;
                            } else if (mem.eql(u8, linker_arg, "--no-as-needed")) {
                                needed = true;
                            } else if (mem.eql(u8, linker_arg, "-no-pie")) {
                                want_pie = false;
                            } else if (mem.eql(u8, linker_arg, "--whole-archive") or
                                mem.eql(u8, linker_arg, "-whole-archive"))
                            {
                                must_link = true;
                            } else if (mem.eql(u8, linker_arg, "--no-whole-archive") or
                                mem.eql(u8, linker_arg, "-no-whole-archive"))
                            {
                                must_link = false;
                            } else if (mem.eql(u8, linker_arg, "-Bdynamic") or
                                mem.eql(u8, linker_arg, "-dy") or
                                mem.eql(u8, linker_arg, "-call_shared"))
                            {
                                force_static_libs = false;
                            } else if (mem.eql(u8, linker_arg, "-Bstatic") or
                                mem.eql(u8, linker_arg, "-dn") or
                                mem.eql(u8, linker_arg, "-non_shared") or
                                mem.eql(u8, linker_arg, "-static"))
                            {
                                force_static_libs = true;
                            } else if (mem.eql(u8, linker_arg, "-search_paths_first")) {
                                search_strategy = .paths_first;
                            } else if (mem.eql(u8, linker_arg, "-search_dylibs_first")) {
                                search_strategy = .dylibs_first;
                            } else {
                                try linker_args.append(linker_arg);
                            }
                        }
                    },
                    .optimize => {
                        // Alright, what release mode do they want?
                        const level = if (it.only_arg.len >= 1 and it.only_arg[0] == 'O') it.only_arg[1..] else it.only_arg;
                        if (mem.eql(u8, level, "s") or
                            mem.eql(u8, level, "z"))
                        {
                            optimize_mode = .ReleaseSmall;
                        } else if (mem.eql(u8, level, "1") or
                            mem.eql(u8, level, "2") or
                            mem.eql(u8, level, "3") or
                            mem.eql(u8, level, "4") or
                            mem.eql(u8, level, "fast"))
                        {
                            optimize_mode = .ReleaseFast;
                        } else if (mem.eql(u8, level, "g") or
                            mem.eql(u8, level, "0"))
                        {
                            optimize_mode = .Debug;
                        } else {
                            try clang_argv.appendSlice(it.other_args);
                        }
                    },
                    .debug => {
                        strip = false;
                        if (mem.eql(u8, it.only_arg, "g")) {
                            // We handled with strip = false above.
                        } else if (mem.eql(u8, it.only_arg, "g1") or
                            mem.eql(u8, it.only_arg, "gline-tables-only"))
                        {
                            // We handled with strip = false above. but we also want reduced debug info.
                            try clang_argv.append("-gline-tables-only");
                        } else {
                            try clang_argv.appendSlice(it.other_args);
                        }
                    },
                    .sanitize => {
                        if (mem.eql(u8, it.only_arg, "undefined")) {
                            want_sanitize_c = true;
                        } else if (mem.eql(u8, it.only_arg, "thread")) {
                            want_tsan = true;
                        } else {
                            try clang_argv.appendSlice(it.other_args);
                        }
                    },
                    .linker_script => linker_script = it.only_arg,
                    .verbose => {
                        verbose_link = true;
                        // Have Clang print more infos, some tools such as CMake
                        // parse this to discover any implicit include and
                        // library dir to look-up into.
                        try clang_argv.append("-v");
                    },
                    .dry_run => {
                        verbose_link = true;
                        try clang_argv.append("-###");
                        // This flag is supposed to mean "dry run" but currently this
                        // will actually still execute. The tracking issue for this is
                        // https://github.com/ziglang/zig/issues/7170
                    },
                    .for_linker => try linker_args.append(it.only_arg),
                    .linker_input_z => {
                        try linker_args.append("-z");
                        try linker_args.append(it.only_arg);
                    },
                    .lib_dir => try lib_dirs.append(it.only_arg),
                    .mcpu => target_mcpu = it.only_arg,
                    .m => try llvm_m_args.append(it.only_arg),
                    .dep_file => {
                        disable_c_depfile = true;
                        try clang_argv.appendSlice(it.other_args);
                    },
                    .dep_file_mm => { // -MM
                        // "Like -MMD, but also implies -E and writes to stdout by default"
                        c_out_mode = .preprocessor;
                        disable_c_depfile = true;
                        try clang_argv.appendSlice(it.other_args);
                    },
                    .framework_dir => try framework_dirs.append(it.only_arg),
                    .framework => try frameworks.put(gpa, it.only_arg, .{}),
                    .nostdlibinc => want_native_include_dirs = false,
                    .strip => strip = true,
                    .exec_model => {
                        wasi_exec_model = std.meta.stringToEnum(std.builtin.WasiExecModel, it.only_arg) orelse {
                            fatal("expected [command|reactor] for -mexec-mode=[value], found '{s}'", .{it.only_arg});
                        };
                    },
                    .sysroot => {
                        sysroot = it.only_arg;
                    },
                    .entry => {
                        entry = it.only_arg;
                    },
                    .weak_library => try system_libs.put(it.only_arg, .{ .weak = true }),
                    .weak_framework => try frameworks.put(gpa, it.only_arg, .{ .weak = true }),
                    .headerpad_max_install_names => headerpad_max_install_names = true,
                    .compress_debug_sections => {
                        if (it.only_arg.len == 0) {
                            linker_compress_debug_sections = .zlib;
                        } else {
                            linker_compress_debug_sections = std.meta.stringToEnum(link.CompressDebugSections, it.only_arg) orelse {
                                fatal("expected [none|zlib] after --compress-debug-sections, found '{s}'", .{it.only_arg});
                            };
                        }
                    },
                }
            }
            // Parse linker args.
            var i: usize = 0;
            while (i < linker_args.items.len) : (i += 1) {
                const arg = linker_args.items[i];
                if (mem.eql(u8, arg, "-soname") or
                    mem.eql(u8, arg, "--soname"))
                {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    const name = linker_args.items[i];
                    soname = .{ .yes = name };
                    // Use it as --name.
                    // Example: libsoundio.so.2
                    var prefix: usize = 0;
                    if (mem.startsWith(u8, name, "lib")) {
                        prefix = 3;
                    }
                    var end: usize = name.len;
                    if (mem.endsWith(u8, name, ".so")) {
                        end -= 3;
                    } else {
                        var found_digit = false;
                        while (end > 0 and std.ascii.isDigit(name[end - 1])) {
                            found_digit = true;
                            end -= 1;
                        }
                        if (found_digit and end > 0 and name[end - 1] == '.') {
                            end -= 1;
                        } else {
                            end = name.len;
                        }
                        if (mem.endsWith(u8, name[prefix..end], ".so")) {
                            end -= 3;
                        }
                    }
                    provided_name = name[prefix..end];
                } else if (mem.eql(u8, arg, "-rpath")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try rpath_list.append(linker_args.items[i]);
                } else if (mem.eql(u8, arg, "--subsystem")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    subsystem = try parseSubSystem(linker_args.items[i]);
                } else if (mem.eql(u8, arg, "-I") or
                    mem.eql(u8, arg, "--dynamic-linker") or
                    mem.eql(u8, arg, "-dynamic-linker"))
                {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    target_dynamic_linker = linker_args.items[i];
                } else if (mem.eql(u8, arg, "-E") or
                    mem.eql(u8, arg, "--export-dynamic") or
                    mem.eql(u8, arg, "-export-dynamic"))
                {
                    rdynamic = true;
                } else if (mem.eql(u8, arg, "--version-script")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    version_script = linker_args.items[i];
                } else if (mem.eql(u8, arg, "-O")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    linker_optimization = std.fmt.parseUnsigned(u8, linker_args.items[i], 10) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.startsWith(u8, arg, "-O")) {
                    linker_optimization = std.fmt.parseUnsigned(u8, arg["-O".len..], 10) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-pagezero_size")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    const next_arg = linker_args.items[i];
                    pagezero_size = std.fmt.parseUnsigned(u64, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-headerpad")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    const next_arg = linker_args.items[i];
                    headerpad_size = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-headerpad_max_install_names")) {
                    headerpad_max_install_names = true;
                } else if (mem.eql(u8, arg, "-dead_strip_dylibs")) {
                    dead_strip_dylibs = true;
                } else if (mem.eql(u8, arg, "--gc-sections")) {
                    linker_gc_sections = true;
                } else if (mem.eql(u8, arg, "--no-gc-sections")) {
                    linker_gc_sections = false;
                } else if (mem.eql(u8, arg, "--allow-shlib-undefined") or
                    mem.eql(u8, arg, "-allow-shlib-undefined"))
                {
                    linker_allow_shlib_undefined = true;
                } else if (mem.eql(u8, arg, "--no-allow-shlib-undefined") or
                    mem.eql(u8, arg, "-no-allow-shlib-undefined"))
                {
                    linker_allow_shlib_undefined = false;
                } else if (mem.eql(u8, arg, "-Bsymbolic")) {
                    linker_bind_global_refs_locally = true;
                } else if (mem.eql(u8, arg, "--import-memory")) {
                    linker_import_memory = true;
                } else if (mem.eql(u8, arg, "--import-table")) {
                    linker_import_table = true;
                } else if (mem.eql(u8, arg, "--export-table")) {
                    linker_export_table = true;
                } else if (mem.startsWith(u8, arg, "--initial-memory=")) {
                    linker_initial_memory = parseIntSuffix(arg, "--initial-memory=".len);
                } else if (mem.startsWith(u8, arg, "--max-memory=")) {
                    linker_max_memory = parseIntSuffix(arg, "--max-memory=".len);
                } else if (mem.startsWith(u8, arg, "--shared-memory")) {
                    linker_shared_memory = true;
                } else if (mem.startsWith(u8, arg, "--global-base=")) {
                    linker_global_base = parseIntSuffix(arg, "--global-base=".len);
                } else if (mem.startsWith(u8, arg, "--export=")) {
                    try linker_export_symbol_names.append(arg["--export=".len..]);
                } else if (mem.eql(u8, arg, "--export")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try linker_export_symbol_names.append(linker_args.items[i]);
                } else if (mem.eql(u8, arg, "--compress-debug-sections")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    const arg1 = linker_args.items[i];
                    linker_compress_debug_sections = std.meta.stringToEnum(link.CompressDebugSections, arg1) orelse {
                        fatal("expected [none|zlib] after --compress-debug-sections, found '{s}'", .{arg1});
                    };
                } else if (mem.eql(u8, arg, "-z")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker extension flag after '{s}'", .{arg});
                    }
                    const z_arg = linker_args.items[i];
                    if (mem.eql(u8, z_arg, "nodelete")) {
                        linker_z_nodelete = true;
                    } else if (mem.eql(u8, z_arg, "notext")) {
                        linker_z_notext = true;
                    } else if (mem.eql(u8, z_arg, "defs")) {
                        linker_z_defs = true;
                    } else if (mem.eql(u8, z_arg, "origin")) {
                        linker_z_origin = true;
                    } else if (mem.eql(u8, z_arg, "noexecstack")) {
                        // noexecstack is the default when linking with LLD
                    } else if (mem.eql(u8, z_arg, "now")) {
                        linker_z_now = true;
                    } else if (mem.eql(u8, z_arg, "lazy")) {
                        linker_z_now = false;
                    } else if (mem.eql(u8, z_arg, "relro")) {
                        linker_z_relro = true;
                    } else if (mem.eql(u8, z_arg, "norelro")) {
                        linker_z_relro = false;
                    } else {
                        warn("unsupported linker extension flag: -z {s}", .{z_arg});
                    }
                } else if (mem.eql(u8, arg, "--major-image-version")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    version.major = std.fmt.parseUnsigned(u32, linker_args.items[i], 10) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "--minor-image-version")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    version.minor = std.fmt.parseUnsigned(u32, linker_args.items[i], 10) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "-e") or mem.eql(u8, arg, "--entry")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    entry = linker_args.items[i];
                } else if (mem.eql(u8, arg, "--stack")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    stack_size_override = std.fmt.parseUnsigned(u64, linker_args.items[i], 0) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--image-base")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    image_base_override = std.fmt.parseUnsigned(u64, linker_args.items[i], 0) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-T") or mem.eql(u8, arg, "--script")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    linker_script = linker_args.items[i];
                } else if (mem.eql(u8, arg, "--eh-frame-hdr")) {
                    link_eh_frame_hdr = true;
                } else if (mem.eql(u8, arg, "--no-eh-frame-hdr")) {
                    link_eh_frame_hdr = false;
                } else if (mem.eql(u8, arg, "--tsaware")) {
                    linker_tsaware = true;
                } else if (mem.eql(u8, arg, "--nxcompat")) {
                    linker_nxcompat = true;
                } else if (mem.eql(u8, arg, "--dynamicbase")) {
                    linker_dynamicbase = true;
                } else if (mem.eql(u8, arg, "--high-entropy-va")) {
                    // This option does not do anything.
                } else if (mem.eql(u8, arg, "--export-all-symbols")) {
                    rdynamic = true;
                } else if (mem.eql(u8, arg, "-s") or mem.eql(u8, arg, "--strip-all") or
                    mem.eql(u8, arg, "-S") or mem.eql(u8, arg, "--strip-debug"))
                {
                    // -s, --strip-all             Strip all symbols
                    // -S, --strip-debug           Strip debugging symbols
                    strip = true;
                } else if (mem.eql(u8, arg, "--start-group") or
                    mem.eql(u8, arg, "--end-group"))
                {
                    // We don't need to care about these because these args are
                    // for resolving circular dependencies but our linker takes
                    // care of this without explicit args.
                } else if (mem.eql(u8, arg, "--major-os-version") or
                    mem.eql(u8, arg, "--minor-os-version"))
                {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    // This option does not do anything.
                } else if (mem.eql(u8, arg, "--major-subsystem-version")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }

                    major_subsystem_version = std.fmt.parseUnsigned(
                        u32,
                        linker_args.items[i],
                        10,
                    ) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--minor-subsystem-version")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }

                    minor_subsystem_version = std.fmt.parseUnsigned(
                        u32,
                        linker_args.items[i],
                        10,
                    ) catch |err| {
                        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-framework")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try frameworks.put(gpa, linker_args.items[i], .{});
                } else if (mem.eql(u8, arg, "-weak_framework")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try frameworks.put(gpa, linker_args.items[i], .{ .weak = true });
                } else if (mem.eql(u8, arg, "-needed_framework")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try frameworks.put(gpa, linker_args.items[i], .{ .needed = true });
                } else if (mem.eql(u8, arg, "-needed_library")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try system_libs.put(linker_args.items[i], .{ .needed = true });
                } else if (mem.startsWith(u8, arg, "-weak-l")) {
                    try system_libs.put(arg["-weak-l".len..], .{ .weak = true });
                } else if (mem.eql(u8, arg, "-weak_library")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try system_libs.put(linker_args.items[i], .{ .weak = true });
                } else if (mem.eql(u8, arg, "-compatibility_version")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    compatibility_version = std.builtin.Version.parse(linker_args.items[i]) catch |err| {
                        fatal("unable to parse -compatibility_version '{s}': {s}", .{ linker_args.items[i], @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-current_version")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    version = std.builtin.Version.parse(linker_args.items[i]) catch |err| {
                        fatal("unable to parse -current_version '{s}': {s}", .{ linker_args.items[i], @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "--out-implib") or
                    mem.eql(u8, arg, "-implib"))
                {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    emit_implib = .{ .yes = linker_args.items[i] };
                    emit_implib_arg_provided = true;
                } else if (mem.eql(u8, arg, "-undefined")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    if (mem.eql(u8, "dynamic_lookup", linker_args.items[i])) {
                        linker_allow_shlib_undefined = true;
                    } else {
                        fatal("unsupported -undefined option '{s}'", .{linker_args.items[i]});
                    }
                } else if (mem.eql(u8, arg, "-install_name")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    install_name = linker_args.items[i];
                } else if (mem.eql(u8, arg, "-force_load")) {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    try link_objects.append(.{
                        .path = linker_args.items[i],
                        .must_link = true,
                    });
                } else if (mem.eql(u8, arg, "-hash-style") or
                    mem.eql(u8, arg, "--hash-style"))
                {
                    i += 1;
                    if (i >= linker_args.items.len) {
                        fatal("expected linker arg after '{s}'", .{arg});
                    }
                    const next_arg = linker_args.items[i];
                    hash_style = std.meta.stringToEnum(link.HashStyle, next_arg) orelse {
                        fatal("expected [sysv|gnu|both] after --hash-style, found '{s}'", .{
                            next_arg,
                        });
                    };
                } else {
                    warn("unsupported linker arg: {s}", .{arg});
                }
            }

            if (want_sanitize_c) |wsc| {
                if (wsc and optimize_mode == .ReleaseFast) {
                    optimize_mode = .ReleaseSafe;
                }
            }

            switch (c_out_mode) {
                .link => {
                    output_mode = if (is_shared_lib) .Lib else .Exe;
                    emit_bin = if (out_path) |p| .{ .yes = p } else EmitBin.yes_a_out;
                    enable_cache = true;
                    if (emit_llvm) {
                        fatal("-emit-llvm cannot be used when linking", .{});
                    }
                },
                .object => {
                    output_mode = .Obj;
                    if (emit_llvm) {
                        emit_bin = .no;
                        if (out_path) |p| {
                            emit_llvm_bc = .{ .yes = p };
                        } else {
                            emit_llvm_bc = .yes_default_path;
                        }
                    } else {
                        if (out_path) |p| {
                            emit_bin = .{ .yes = p };
                        } else {
                            emit_bin = .yes_default_path;
                        }
                    }
                },
                .assembly => {
                    output_mode = .Obj;
                    emit_bin = .no;
                    if (emit_llvm) {
                        if (out_path) |p| {
                            emit_llvm_ir = .{ .yes = p };
                        } else {
                            emit_llvm_ir = .yes_default_path;
                        }
                    } else {
                        if (out_path) |p| {
                            emit_asm = .{ .yes = p };
                        } else {
                            emit_asm = .yes_default_path;
                        }
                    }
                },
                .preprocessor => {
                    output_mode = .Obj;
                    // An error message is generated when there is more than 1 C source file.
                    if (c_source_files.items.len != 1) {
                        // For example `zig cc` and no args should print the "no input files" message.
                        return process.exit(try clangMain(arena, all_args));
                    }
                    if (out_path) |p| {
                        emit_bin = .{ .yes = p };
                        clang_preprocessor_mode = .yes;
                    } else {
                        clang_preprocessor_mode = .stdout;
                    }
                },
            }
            if (c_source_files.items.len == 0 and
                link_objects.items.len == 0 and
                root_src_file == null)
            {
                // For example `zig cc` and no args should print the "no input files" message.
                // There could be other reasons to punt to clang, for example, --help.
                return process.exit(try clangMain(arena, all_args));
            }
        },
    }

    if (arg_mode == .translate_c and c_source_files.items.len != 1) {
        fatal("translate-c expects exactly 1 source file (found {d})", .{c_source_files.items.len});
    }

    if (root_src_file == null and arg_mode == .zig_test) {
        fatal("`zig test` expects a zig source file argument", .{});
    }

    const root_name = if (provided_name) |n| n else blk: {
        if (arg_mode == .zig_test) {
            break :blk "test";
        } else if (root_src_file) |file| {
            const basename = fs.path.basename(file);
            break :blk basename[0 .. basename.len - fs.path.extension(basename).len];
        } else if (c_source_files.items.len >= 1) {
            const basename = fs.path.basename(c_source_files.items[0].src_path);
            break :blk basename[0 .. basename.len - fs.path.extension(basename).len];
        } else if (link_objects.items.len >= 1) {
            const basename = fs.path.basename(link_objects.items[0].path);
            break :blk basename[0 .. basename.len - fs.path.extension(basename).len];
        } else if (emit_bin == .yes) {
            const basename = fs.path.basename(emit_bin.yes);
            break :blk basename[0 .. basename.len - fs.path.extension(basename).len];
        } else if (show_builtin) {
            break :blk "builtin";
        } else if (arg_mode == .run) {
            fatal("`zig run` expects at least one positional argument", .{});
            // TODO once the attempt to unwrap error: LinkingWithoutZigSourceUnimplemented
            // is solved, remove the above fatal() and uncomment the `break` below.
            //break :blk "run";
        } else {
            fatal("expected a positional argument, -femit-bin=[path], --show-builtin, or --name [name]", .{});
        }
    };

    var target_parse_options: std.zig.CrossTarget.ParseOptions = .{
        .arch_os_abi = target_arch_os_abi,
        .cpu_features = target_mcpu,
        .dynamic_linker = target_dynamic_linker,
    };

    // Before passing the mcpu string in for parsing, we convert any -m flags that were
    // passed in via zig cc to zig-style.
    if (llvm_m_args.items.len != 0) {
        // If this returns null, we let it fall through to the case below which will
        // run the full parse function and do proper error handling.
        if (std.zig.CrossTarget.parseCpuArch(target_parse_options)) |cpu_arch| {
            var llvm_to_zig_name = std.StringHashMap([]const u8).init(gpa);
            defer llvm_to_zig_name.deinit();

            for (cpu_arch.allFeaturesList()) |feature| {
                const llvm_name = feature.llvm_name orelse continue;
                try llvm_to_zig_name.put(llvm_name, feature.name);
            }

            var mcpu_buffer = std.ArrayList(u8).init(gpa);
            defer mcpu_buffer.deinit();

            try mcpu_buffer.appendSlice(target_mcpu orelse "baseline");

            for (llvm_m_args.items) |llvm_m_arg| {
                if (mem.startsWith(u8, llvm_m_arg, "mno-")) {
                    const llvm_name = llvm_m_arg["mno-".len..];
                    const zig_name = llvm_to_zig_name.get(llvm_name) orelse {
                        fatal("target architecture {s} has no LLVM CPU feature named '{s}'", .{
                            @tagName(cpu_arch), llvm_name,
                        });
                    };
                    try mcpu_buffer.append('-');
                    try mcpu_buffer.appendSlice(zig_name);
                } else if (mem.startsWith(u8, llvm_m_arg, "m")) {
                    const llvm_name = llvm_m_arg["m".len..];
                    const zig_name = llvm_to_zig_name.get(llvm_name) orelse {
                        fatal("target architecture {s} has no LLVM CPU feature named '{s}'", .{
                            @tagName(cpu_arch), llvm_name,
                        });
                    };
                    try mcpu_buffer.append('+');
                    try mcpu_buffer.appendSlice(zig_name);
                } else {
                    unreachable;
                }
            }

            const adjusted_target_mcpu = try arena.dupe(u8, mcpu_buffer.items);
            std.log.debug("adjusted target_mcpu: {s}", .{adjusted_target_mcpu});
            target_parse_options.cpu_features = adjusted_target_mcpu;
        }
    }

    const cross_target = try parseCrossTargetOrReportFatalError(arena, target_parse_options);
    const target_info = try detectNativeTargetInfo(gpa, cross_target);

    if (target_info.target.os.tag != .freestanding) {
        if (ensure_libc_on_non_freestanding)
            link_libc = true;
        if (ensure_libcpp_on_non_freestanding)
            link_libcpp = true;
    }

    if (target_info.target.cpu.arch.isWasm() and linker_shared_memory) {
        if (output_mode == .Obj) {
            fatal("shared memory is not allowed in object files", .{});
        }

        if (!target_info.target.cpu.features.isEnabled(@enumToInt(std.Target.wasm.Feature.atomics)) or
            !target_info.target.cpu.features.isEnabled(@enumToInt(std.Target.wasm.Feature.bulk_memory)))
        {
            fatal("'atomics' and 'bulk-memory' features must be enabled to use shared memory", .{});
        }
    }

    // Now that we have target info, we can find out if any of the system libraries
    // are part of libc or libc++. We remove them from the list and communicate their
    // existence via flags instead.
    {
        // Similarly, if any libs in this list are statically provided, we remove
        // them from this list and populate the link_objects array instead.
        const sep = fs.path.sep_str;
        var test_path = std.ArrayList(u8).init(gpa);
        defer test_path.deinit();

        var i: usize = 0;
        syslib: while (i < system_libs.count()) {
            const lib_name = system_libs.keys()[i];

            if (target_util.is_libc_lib_name(target_info.target, lib_name)) {
                link_libc = true;
                system_libs.orderedRemoveAt(i);
                continue;
            }
            if (target_util.is_libcpp_lib_name(target_info.target, lib_name)) {
                link_libcpp = true;
                system_libs.orderedRemoveAt(i);
                continue;
            }
            switch (target_util.classifyCompilerRtLibName(target_info.target, lib_name)) {
                .none => {},
                .only_libunwind, .both => {
                    link_libunwind = true;
                    system_libs.orderedRemoveAt(i);
                    continue;
                },
                .only_compiler_rt => {
                    std.log.warn("ignoring superfluous library '{s}': this dependency is fulfilled instead by compiler-rt which zig unconditionally provides", .{lib_name});
                    system_libs.orderedRemoveAt(i);
                    continue;
                },
            }

            if (std.fs.path.isAbsolute(lib_name)) {
                fatal("cannot use absolute path as a system library: {s}", .{lib_name});
            }

            if (target_info.target.os.tag == .wasi) {
                if (wasi_libc.getEmulatedLibCRTFile(lib_name)) |crt_file| {
                    try wasi_emulated_libs.append(crt_file);
                    system_libs.orderedRemoveAt(i);
                    continue;
                }
            }

            for (lib_dirs.items) |lib_dir_path| {
                if (cross_target.isDarwin()) break; // Targeting Darwin we let the linker resolve the libraries in the correct order
                test_path.clearRetainingCapacity();
                try test_path.writer().print("{s}" ++ sep ++ "{s}{s}{s}", .{
                    lib_dir_path,
                    target_info.target.libPrefix(),
                    lib_name,
                    target_info.target.staticLibSuffix(),
                });
                fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
                    error.FileNotFound => continue,
                    else => |e| fatal("unable to search for static library '{s}': {s}", .{
                        test_path.items, @errorName(e),
                    }),
                };
                try link_objects.append(.{ .path = try arena.dupe(u8, test_path.items) });
                system_libs.orderedRemoveAt(i);
                continue :syslib;
            }

            // Unfortunately, in the case of MinGW we also need to look for `libfoo.a`.
            if (target_info.target.isMinGW()) {
                for (lib_dirs.items) |lib_dir_path| {
                    test_path.clearRetainingCapacity();
                    try test_path.writer().print("{s}" ++ sep ++ "lib{s}.a", .{
                        lib_dir_path, lib_name,
                    });
                    fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
                        error.FileNotFound => continue,
                        else => |e| fatal("unable to search for static library '{s}': {s}", .{
                            test_path.items, @errorName(e),
                        }),
                    };
                    try link_objects.append(.{ .path = try arena.dupe(u8, test_path.items) });
                    system_libs.orderedRemoveAt(i);
                    continue :syslib;
                }
            }

            std.log.scoped(.cli).debug("depending on system for -l{s}", .{lib_name});

            i += 1;
        }
    }
    // libc++ depends on libc
    if (link_libcpp) {
        link_libc = true;
    }

    if (use_lld) |opt| {
        if (opt and cross_target.isDarwin()) {
            fatal("LLD requested with Mach-O object format. Only the self-hosted linker is supported for this target.", .{});
        }
    }

    if (want_lto) |opt| {
        if (opt and cross_target.isDarwin()) {
            fatal("LTO is not yet supported with the Mach-O object format. More details: https://github.com/ziglang/zig/issues/8680", .{});
        }
    }

    if (comptime builtin.target.isDarwin()) {
        // If we want to link against frameworks, we need system headers.
        if (framework_dirs.items.len > 0 or frameworks.count() > 0)
            want_native_include_dirs = true;
    }

    if (sysroot == null and cross_target.isNativeOs() and
        (system_libs.count() != 0 or want_native_include_dirs))
    {
        const paths = std.zig.system.NativePaths.detect(arena, target_info) catch |err| {
            fatal("unable to detect native system paths: {s}", .{@errorName(err)});
        };
        for (paths.warnings.items) |warning| {
            warn("{s}", .{warning});
        }

        const has_sysroot = if (comptime builtin.target.isDarwin()) outer: {
            if (std.zig.system.darwin.isDarwinSDKInstalled(arena)) {
                const sdk = std.zig.system.darwin.getDarwinSDK(arena, target_info.target) orelse
                    break :outer false;
                native_darwin_sdk = sdk;
                try clang_argv.ensureUnusedCapacity(2);
                clang_argv.appendAssumeCapacity("-isysroot");
                clang_argv.appendAssumeCapacity(sdk.path);
                break :outer true;
            } else break :outer false;
        } else false;

        try clang_argv.ensureUnusedCapacity(paths.include_dirs.items.len * 2);
        const isystem_flag = if (has_sysroot) "-iwithsysroot" else "-isystem";
        for (paths.include_dirs.items) |include_dir| {
            clang_argv.appendAssumeCapacity(isystem_flag);
            clang_argv.appendAssumeCapacity(include_dir);
        }

        try clang_argv.ensureUnusedCapacity(paths.framework_dirs.items.len * 2);
        try framework_dirs.ensureUnusedCapacity(paths.framework_dirs.items.len);
        const iframework_flag = if (has_sysroot) "-iframeworkwithsysroot" else "-iframework";
        for (paths.framework_dirs.items) |framework_dir| {
            clang_argv.appendAssumeCapacity(iframework_flag);
            clang_argv.appendAssumeCapacity(framework_dir);
            framework_dirs.appendAssumeCapacity(framework_dir);
        }

        for (paths.lib_dirs.items) |lib_dir| {
            try lib_dirs.append(lib_dir);
        }
        for (paths.rpaths.items) |rpath| {
            try rpath_list.append(rpath);
        }
    }

    {
        // Resolve static libraries into full paths.
        const sep = fs.path.sep_str;

        var test_path = std.ArrayList(u8).init(gpa);
        defer test_path.deinit();

        for (static_libs.items) |static_lib| {
            for (lib_dirs.items) |lib_dir_path| {
                test_path.clearRetainingCapacity();
                try test_path.writer().print("{s}" ++ sep ++ "{s}{s}{s}", .{
                    lib_dir_path,
                    target_info.target.libPrefix(),
                    static_lib,
                    target_info.target.staticLibSuffix(),
                });
                fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
                    error.FileNotFound => continue,
                    else => |e| fatal("unable to search for static library '{s}': {s}", .{
                        test_path.items, @errorName(e),
                    }),
                };
                try link_objects.append(.{ .path = try arena.dupe(u8, test_path.items) });
                break;
            } else {
                var search_paths = std.ArrayList(u8).init(arena);
                for (lib_dirs.items) |lib_dir_path| {
                    try search_paths.writer().print("\n {s}" ++ sep ++ "{s}{s}{s}", .{
                        lib_dir_path,
                        target_info.target.libPrefix(),
                        static_lib,
                        target_info.target.staticLibSuffix(),
                    });
                }
                try search_paths.appendSlice("\n suggestion: use full paths to static libraries on the command line rather than using -l and -L arguments");
                fatal("static library '{s}' not found. search paths: {s}", .{
                    static_lib, search_paths.items,
                });
            }
        }
    }

    // Resolve `-l :file.so` syntax from `zig cc`. We use a separate map for this data
    // since this is an uncommon case.
    {
        var it = link_objects_lib_search_paths.iterator();
        while (it.next()) |item| {
            const link_object_i = item.key_ptr.*;
            const suffix = link_objects.items[link_object_i].path;

            for (lib_dirs.items) |lib_dir_path| {
                const test_path = try fs.path.join(arena, &.{ lib_dir_path, suffix });
                fs.cwd().access(test_path, .{}) catch |err| switch (err) {
                    error.FileNotFound => continue,
                    else => |e| fatal("unable to search for library '{s}': {s}", .{
                        test_path, @errorName(e),
                    }),
                };
                link_objects.items[link_object_i].path = test_path;
                break;
            } else {
                fatal("library '{s}' not found", .{suffix});
            }
        }
    }

    const object_format: std.Target.ObjectFormat = blk: {
        const ofmt = target_ofmt orelse break :blk target_info.target.getObjectFormat();
        if (mem.eql(u8, ofmt, "elf")) {
            break :blk .elf;
        } else if (mem.eql(u8, ofmt, "c")) {
            break :blk .c;
        } else if (mem.eql(u8, ofmt, "coff")) {
            break :blk .coff;
        } else if (mem.eql(u8, ofmt, "macho")) {
            break :blk .macho;
        } else if (mem.eql(u8, ofmt, "wasm")) {
            break :blk .wasm;
        } else if (mem.eql(u8, ofmt, "hex")) {
            break :blk .hex;
        } else if (mem.eql(u8, ofmt, "raw")) {
            break :blk .raw;
        } else if (mem.eql(u8, ofmt, "spirv")) {
            break :blk .spirv;
        } else {
            fatal("unsupported object format: {s}", .{ofmt});
        }
    };

    if (output_mode == .Obj and (object_format == .coff or object_format == .macho)) {
        const total_obj_count = c_source_files.items.len +
            @boolToInt(root_src_file != null) +
            link_objects.items.len;
        if (total_obj_count > 1) {
            fatal("{s} does not support linking multiple objects into one", .{@tagName(object_format)});
        }
    }

    var cleanup_emit_bin_dir: ?fs.Dir = null;
    defer if (cleanup_emit_bin_dir) |*dir| dir.close();

    const have_enable_cache = enable_cache orelse false;
    const optional_version = if (have_version) version else null;

    const resolved_soname: ?[]const u8 = switch (soname) {
        .yes => |explicit| explicit,
        .no => null,
        .yes_default_value => switch (object_format) {
            .elf => if (have_version)
                try std.fmt.allocPrint(arena, "lib{s}.so.{d}", .{ root_name, version.major })
            else
                try std.fmt.allocPrint(arena, "lib{s}.so", .{root_name}),
            else => null,
        },
    };

    const a_out_basename = switch (object_format) {
        .coff => "a.exe",
        else => "a.out",
    };

    const emit_bin_loc: ?Compilation.EmitLoc = switch (emit_bin) {
        .no => null,
        .yes_default_path => Compilation.EmitLoc{
            .directory = blk: {
                switch (arg_mode) {
                    .run, .zig_test => break :blk null,
                    else => {
                        if (have_enable_cache) {
                            break :blk null;
                        } else {
                            break :blk .{ .path = null, .handle = fs.cwd() };
                        }
                    },
                }
            },
            .basename = try std.zig.binNameAlloc(arena, .{
                .root_name = root_name,
                .target = target_info.target,
                .output_mode = output_mode,
                .link_mode = link_mode,
                .object_format = object_format,
                .version = optional_version,
            }),
        },
        .yes => |full_path| b: {
            const basename = fs.path.basename(full_path);
            if (have_enable_cache) {
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = null,
                };
            }
            if (fs.path.dirname(full_path)) |dirname| {
                const handle = fs.cwd().openDir(dirname, .{}) catch |err| {
                    fatal("unable to open output directory '{s}': {s}", .{ dirname, @errorName(err) });
                };
                cleanup_emit_bin_dir = handle;
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = .{
                        .path = dirname,
                        .handle = handle,
                    },
                };
            } else {
                break :b Compilation.EmitLoc{
                    .basename = basename,
                    .directory = .{ .path = null, .handle = fs.cwd() },
                };
            }
        },
        .yes_a_out => Compilation.EmitLoc{
            .directory = null,
            .basename = a_out_basename,
        },
    };

    const default_h_basename = try std.fmt.allocPrint(arena, "{s}.h", .{root_name});
    var emit_h_resolved = emit_h.resolve(default_h_basename) catch |err| {
        switch (emit_h) {
            .yes => |p| {
                fatal("unable to open directory from argument '-femit-h', '{s}': {s}", .{
                    p, @errorName(err),
                });
            },
            .yes_default_path => {
                fatal("unable to open directory from arguments '--name' or '-fsoname', '{s}': {s}", .{
                    default_h_basename, @errorName(err),
                });
            },
            .no => unreachable,
        }
    };
    defer emit_h_resolved.deinit();

    const default_asm_basename = try std.fmt.allocPrint(arena, "{s}.s", .{root_name});
    var emit_asm_resolved = emit_asm.resolve(default_asm_basename) catch |err| {
        switch (emit_asm) {
            .yes => |p| {
                fatal("unable to open directory from argument '-femit-asm', '{s}': {s}", .{
                    p, @errorName(err),
                });
            },
            .yes_default_path => {
                fatal("unable to open directory from arguments '--name' or '-fsoname', '{s}': {s}", .{
                    default_asm_basename, @errorName(err),
                });
            },
            .no => unreachable,
        }
    };
    defer emit_asm_resolved.deinit();

    const default_llvm_ir_basename = try std.fmt.allocPrint(arena, "{s}.ll", .{root_name});
    var emit_llvm_ir_resolved = emit_llvm_ir.resolve(default_llvm_ir_basename) catch |err| {
        switch (emit_llvm_ir) {
            .yes => |p| {
                fatal("unable to open directory from argument '-femit-llvm-ir', '{s}': {s}", .{
                    p, @errorName(err),
                });
            },
            .yes_default_path => {
                fatal("unable to open directory from arguments '--name' or '-fsoname', '{s}': {s}", .{
                    default_llvm_ir_basename, @errorName(err),
                });
            },
            .no => unreachable,
        }
    };
    defer emit_llvm_ir_resolved.deinit();

    const default_llvm_bc_basename = try std.fmt.allocPrint(arena, "{s}.bc", .{root_name});
    var emit_llvm_bc_resolved = emit_llvm_bc.resolve(default_llvm_bc_basename) catch |err| {
        switch (emit_llvm_bc) {
            .yes => |p| {
                fatal("unable to open directory from argument '-femit-llvm-bc', '{s}': {s}", .{
                    p, @errorName(err),
                });
            },
            .yes_default_path => {
                fatal("unable to open directory from arguments '--name' or '-fsoname', '{s}': {s}", .{
                    default_llvm_bc_basename, @errorName(err),
                });
            },
            .no => unreachable,
        }
    };
    defer emit_llvm_bc_resolved.deinit();

    const default_analysis_basename = try std.fmt.allocPrint(arena, "{s}-analysis.json", .{root_name});
    var emit_analysis_resolved = emit_analysis.resolve(default_analysis_basename) catch |err| {
        switch (emit_analysis) {
            .yes => |p| {
                fatal("unable to open directory from argument '-femit-analysis',  '{s}': {s}", .{
                    p, @errorName(err),
                });
            },
            .yes_default_path => {
                fatal("unable to open directory from arguments 'name' or 'soname', '{s}': {s}", .{
                    default_analysis_basename, @errorName(err),
                });
            },
            .no => unreachable,
        }
    };
    defer emit_analysis_resolved.deinit();

    var emit_docs_resolved = emit_docs.resolve("docs") catch |err| {
        switch (emit_docs) {
            .yes => |p| {
                fatal("unable to open directory from argument '-femit-docs', '{s}': {s}", .{
                    p, @errorName(err),
                });
            },
            .yes_default_path => {
                fatal("unable to open directory 'docs': {s}", .{@errorName(err)});
            },
            .no => unreachable,
        }
    };
    defer emit_docs_resolved.deinit();

    const is_exe_or_dyn_lib = switch (output_mode) {
        .Obj => false,
        .Lib => (link_mode orelse .Static) == .Dynamic,
        .Exe => true,
    };
    // Note that cmake when targeting Windows will try to execute
    // zig cc to make an executable and output an implib too.
    const implib_eligible = is_exe_or_dyn_lib and
        emit_bin_loc != null and target_info.target.os.tag == .windows;
    if (!implib_eligible) {
        if (!emit_implib_arg_provided) {
            emit_implib = .no;
        } else if (emit_implib != .no) {
            fatal("the argument -femit-implib is allowed only when building a Windows DLL", .{});
        }
    }
    const default_implib_basename = try std.fmt.allocPrint(arena, "{s}.lib", .{root_name});
    var emit_implib_resolved = switch (emit_implib) {
        .no => Emit.Resolved{ .data = null, .dir = null },
        .yes => |p| emit_implib.resolve(default_implib_basename) catch |err| {
            fatal("unable to open directory from argument '-femit-implib', '{s}': {s}", .{
                p, @errorName(err),
            });
        },
        .yes_default_path => Emit.Resolved{
            .data = Compilation.EmitLoc{
                .directory = emit_bin_loc.?.directory,
                .basename = default_implib_basename,
            },
            .dir = null,
        },
    };
    defer emit_implib_resolved.deinit();

    const main_pkg: ?*Package = if (root_src_file) |src_path| blk: {
        if (main_pkg_path) |p| {
            const rel_src_path = try fs.path.relative(gpa, p, src_path);
            defer gpa.free(rel_src_path);
            break :blk try Package.create(gpa, p, rel_src_path);
        } else {
            break :blk try Package.create(gpa, fs.path.dirname(src_path), fs.path.basename(src_path));
        }
    } else null;
    defer if (main_pkg) |p| p.destroy(gpa);

    // Transfer packages added with --pkg-begin/--pkg-end to the root package
    if (main_pkg) |pkg| {
        pkg.table = pkg_tree_root.table;
        pkg_tree_root.table = .{};
    }

    const self_exe_path = try introspect.findZigExePath(arena);
    var zig_lib_directory: Compilation.Directory = if (override_lib_dir) |lib_dir| .{
        .path = lib_dir,
        .handle = fs.cwd().openDir(lib_dir, .{}) catch |err| {
            fatal("unable to open zig lib directory from 'zig-lib-dir' argument or env, '{s}': {s}", .{ lib_dir, @errorName(err) });
        },
    } else introspect.findZigLibDirFromSelfExe(arena, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(gpa);
    defer thread_pool.deinit();

    var libc_installation: ?LibCInstallation = null;
    defer if (libc_installation) |*l| l.deinit(gpa);

    if (libc_paths_file) |paths_file| {
        libc_installation = LibCInstallation.parse(gpa, paths_file, cross_target) catch |err| {
            fatal("unable to parse libc paths file at path {s}: {s}", .{ paths_file, @errorName(err) });
        };
    }

    var global_cache_directory: Compilation.Directory = l: {
        const p = override_global_cache_dir orelse try introspect.resolveGlobalCacheDir(arena);
        break :l .{
            .handle = try fs.cwd().makeOpenPath(p, .{}),
            .path = p,
        };
    };
    defer global_cache_directory.handle.close();

    var cleanup_local_cache_dir: ?fs.Dir = null;
    defer if (cleanup_local_cache_dir) |*dir| dir.close();

    var local_cache_directory: Compilation.Directory = l: {
        if (override_local_cache_dir) |local_cache_dir_path| {
            const dir = try fs.cwd().makeOpenPath(local_cache_dir_path, .{});
            cleanup_local_cache_dir = dir;
            break :l .{
                .handle = dir,
                .path = local_cache_dir_path,
            };
        }
        if (arg_mode == .run) {
            break :l global_cache_directory;
        }
        if (main_pkg) |pkg| {
            const cache_dir_path = try pkg.root_src_directory.join(arena, &[_][]const u8{"zig-cache"});
            const dir = try pkg.root_src_directory.handle.makeOpenPath("zig-cache", .{});
            cleanup_local_cache_dir = dir;
            break :l .{
                .handle = dir,
                .path = cache_dir_path,
            };
        }
        // Otherwise we really don't have a reasonable place to put the local cache directory,
        // so we utilize the global one.
        break :l global_cache_directory;
    };

    if (build_options.have_llvm and emit_asm != .no) {
        // LLVM has no way to set this non-globally.
        const argv = [_][*:0]const u8{ "zig (LLVM option parsing)", "--x86-asm-syntax=intel" };
        @import("codegen/llvm/bindings.zig").ParseCommandLineOptions(argv.len, &argv);
    }

    const clang_passthrough_mode = switch (arg_mode) {
        .cc, .cpp, .translate_c => true,
        else => false,
    };

    gimmeMoreOfThoseSweetSweetFileDescriptors();

    const comp = Compilation.create(gpa, .{
        .zig_lib_directory = zig_lib_directory,
        .local_cache_directory = local_cache_directory,
        .global_cache_directory = global_cache_directory,
        .root_name = root_name,
        .target = target_info.target,
        .is_native_os = cross_target.isNativeOs(),
        .is_native_abi = cross_target.isNativeAbi(),
        .dynamic_linker = target_info.dynamic_linker.get(),
        .sysroot = sysroot,
        .output_mode = output_mode,
        .main_pkg = main_pkg,
        .emit_bin = emit_bin_loc,
        .emit_h = emit_h_resolved.data,
        .emit_asm = emit_asm_resolved.data,
        .emit_llvm_ir = emit_llvm_ir_resolved.data,
        .emit_llvm_bc = emit_llvm_bc_resolved.data,
        .emit_docs = emit_docs_resolved.data,
        .emit_analysis = emit_analysis_resolved.data,
        .emit_implib = emit_implib_resolved.data,
        .link_mode = link_mode,
        .dll_export_fns = dll_export_fns,
        .object_format = object_format,
        .optimize_mode = optimize_mode,
        .keep_source_files_loaded = false,
        .clang_argv = clang_argv.items,
        .lib_dirs = lib_dirs.items,
        .rpath_list = rpath_list.items,
        .c_source_files = c_source_files.items,
        .link_objects = link_objects.items,
        .framework_dirs = framework_dirs.items,
        .frameworks = frameworks,
        .system_lib_names = system_libs.keys(),
        .system_lib_infos = system_libs.values(),
        .wasi_emulated_libs = wasi_emulated_libs.items,
        .link_libc = link_libc,
        .link_libcpp = link_libcpp,
        .link_libunwind = link_libunwind,
        .want_pic = want_pic,
        .want_pie = want_pie,
        .want_lto = want_lto,
        .want_unwind_tables = want_unwind_tables,
        .want_sanitize_c = want_sanitize_c,
        .want_stack_check = want_stack_check,
        .want_red_zone = want_red_zone,
        .omit_frame_pointer = omit_frame_pointer,
        .want_valgrind = want_valgrind,
        .want_tsan = want_tsan,
        .want_compiler_rt = want_compiler_rt,
        .use_llvm = use_llvm,
        .use_lld = use_lld,
        .use_clang = use_clang,
        .use_stage1 = use_stage1,
        .hash_style = hash_style,
        .rdynamic = rdynamic,
        .linker_script = linker_script,
        .version_script = version_script,
        .disable_c_depfile = disable_c_depfile,
        .soname = resolved_soname,
        .linker_gc_sections = linker_gc_sections,
        .linker_allow_shlib_undefined = linker_allow_shlib_undefined,
        .linker_bind_global_refs_locally = linker_bind_global_refs_locally,
        .linker_import_memory = linker_import_memory,
        .linker_import_table = linker_import_table,
        .linker_export_table = linker_export_table,
        .linker_initial_memory = linker_initial_memory,
        .linker_max_memory = linker_max_memory,
        .linker_shared_memory = linker_shared_memory,
        .linker_global_base = linker_global_base,
        .linker_export_symbol_names = linker_export_symbol_names.items,
        .linker_z_nodelete = linker_z_nodelete,
        .linker_z_notext = linker_z_notext,
        .linker_z_defs = linker_z_defs,
        .linker_z_origin = linker_z_origin,
        .linker_z_now = linker_z_now,
        .linker_z_relro = linker_z_relro,
        .linker_tsaware = linker_tsaware,
        .linker_nxcompat = linker_nxcompat,
        .linker_dynamicbase = linker_dynamicbase,
        .linker_optimization = linker_optimization,
        .linker_compress_debug_sections = linker_compress_debug_sections,
        .major_subsystem_version = major_subsystem_version,
        .minor_subsystem_version = minor_subsystem_version,
        .link_eh_frame_hdr = link_eh_frame_hdr,
        .link_emit_relocs = link_emit_relocs,
        .entry = entry,
        .stack_size_override = stack_size_override,
        .image_base_override = image_base_override,
        .strip = strip,
        .single_threaded = single_threaded,
        .function_sections = function_sections,
        .no_builtin = no_builtin,
        .self_exe_path = self_exe_path,
        .thread_pool = &thread_pool,
        .clang_passthrough_mode = clang_passthrough_mode,
        .clang_preprocessor_mode = clang_preprocessor_mode,
        .version = optional_version,
        .libc_installation = if (libc_installation) |*lci| lci else null,
        .verbose_cc = verbose_cc,
        .verbose_link = verbose_link,
        .verbose_air = verbose_air,
        .verbose_llvm_ir = verbose_llvm_ir,
        .verbose_cimport = verbose_cimport,
        .verbose_llvm_cpu_features = verbose_llvm_cpu_features,
        .machine_code_model = machine_code_model,
        .color = color,
        .time_report = time_report,
        .stack_report = stack_report,
        .is_test = arg_mode == .zig_test,
        .each_lib_rpath = each_lib_rpath,
        .build_id = build_id,
        .test_evented_io = test_evented_io,
        .test_filter = test_filter,
        .test_name_prefix = test_name_prefix,
        .disable_lld_caching = !have_enable_cache,
        .subsystem = subsystem,
        .wasi_exec_model = wasi_exec_model,
        .debug_compile_errors = debug_compile_errors,
        .enable_link_snapshots = enable_link_snapshots,
        .native_darwin_sdk = native_darwin_sdk,
        .install_name = install_name,
        .entitlements = entitlements,
        .pagezero_size = pagezero_size,
        .search_strategy = search_strategy,
        .headerpad_size = headerpad_size,
        .headerpad_max_install_names = headerpad_max_install_names,
        .dead_strip_dylibs = dead_strip_dylibs,
    }) catch |err| switch (err) {
        error.LibCUnavailable => {
            const target = target_info.target;
            const triple_name = try target.zigTriple(arena);
            std.log.err("unable to find or provide libc for target '{s}'", .{triple_name});

            for (target_util.available_libcs) |t| {
                if (t.arch == target.cpu.arch and t.os == target.os.tag) {
                    if (t.os_ver) |os_ver| {
                        std.log.info("zig can provide libc for related target {s}-{s}.{d}-{s}", .{
                            @tagName(t.arch), @tagName(t.os), os_ver.major, @tagName(t.abi),
                        });
                    } else {
                        std.log.info("zig can provide libc for related target {s}-{s}-{s}", .{
                            @tagName(t.arch), @tagName(t.os), @tagName(t.abi),
                        });
                    }
                }
            }
            process.exit(1);
        },
        error.ExportTableAndImportTableConflict => {
            fatal("--import-table and --export-table may not be used together", .{});
        },
        else => fatal("unable to create compilation: {s}", .{@errorName(err)}),
    };
    var comp_destroyed = false;
    defer if (!comp_destroyed) comp.destroy();

    if (show_builtin) {
        return std.io.getStdOut().writeAll(try comp.generateBuiltinZigSource(arena));
    }
    if (arg_mode == .translate_c) {
        const stage1_mode = use_stage1 orelse build_options.is_stage1;
        return cmdTranslateC(comp, arena, have_enable_cache, stage1_mode);
    }

    const hook: AfterUpdateHook = blk: {
        if (!have_enable_cache)
            break :blk .none;

        switch (emit_bin) {
            .no => break :blk .none,
            .yes_default_path => break :blk .print_emit_bin_dir_path,
            .yes => |full_path| break :blk .{ .update = full_path },
            .yes_a_out => break :blk .{ .update = a_out_basename },
        }
    };

    updateModule(gpa, comp, hook) catch |err| switch (err) {
        error.SemanticAnalyzeFail => if (!watch) process.exit(1),
        else => |e| return e,
    };
    try comp.makeBinFileExecutable();

    if (test_exec_args.items.len == 0 and object_format == .c) default_exec_args: {
        // Default to using `zig run` to execute the produced .c code from `zig test`.
        const c_code_loc = emit_bin_loc orelse break :default_exec_args;
        const c_code_directory = c_code_loc.directory orelse comp.bin_file.options.emit.?.directory;
        const c_code_path = try fs.path.join(arena, &[_][]const u8{
            c_code_directory.path orelse ".", c_code_loc.basename,
        });
        try test_exec_args.appendSlice(&.{ self_exe_path, "run", "-lc", c_code_path });
    }

    const run_or_test = switch (arg_mode) {
        .run => true,
        .zig_test => !test_no_exec,
        else => false,
    };
    if (run_or_test) {
        try runOrTest(
            comp,
            gpa,
            arena,
            test_exec_args.items,
            self_exe_path,
            arg_mode,
            target_info,
            watch,
            &comp_destroyed,
            all_args,
            runtime_args_start,
            link_libc,
        );
    }

    const stdin = std.io.getStdIn().reader();
    const stderr = std.io.getStdErr().writer();
    var repl_buf: [1024]u8 = undefined;

    const ReplCmd = enum {
        update,
        help,
        run,
        update_and_run,
    };

    var last_cmd: ReplCmd = .help;

    while (watch) {
        try stderr.print("(zig) ", .{});
        try comp.makeBinFileExecutable();
        if (stdin.readUntilDelimiterOrEof(&repl_buf, '\n') catch |err| {
            try stderr.print("\nUnable to parse command: {s}\n", .{@errorName(err)});
            continue;
        }) |line| {
            const actual_line = mem.trimRight(u8, line, "\r\n ");
            const cmd: ReplCmd = blk: {
                if (mem.eql(u8, actual_line, "update")) {
                    break :blk .update;
                } else if (mem.eql(u8, actual_line, "exit")) {
                    break;
                } else if (mem.eql(u8, actual_line, "help")) {
                    break :blk .help;
                } else if (mem.eql(u8, actual_line, "run")) {
                    break :blk .run;
                } else if (mem.eql(u8, actual_line, "update-and-run")) {
                    break :blk .update_and_run;
                } else if (actual_line.len == 0) {
                    break :blk last_cmd;
                } else {
                    try stderr.print("unknown command: {s}\n", .{actual_line});
                    continue;
                }
            };
            last_cmd = cmd;
            switch (cmd) {
                .update => {
                    tracy.frameMark();
                    if (output_mode == .Exe) {
                        try comp.makeBinFileWritable();
                    }
                    updateModule(gpa, comp, hook) catch |err| switch (err) {
                        error.SemanticAnalyzeFail => continue,
                        else => |e| return e,
                    };
                },
                .help => {
                    try stderr.writeAll(repl_help);
                },
                .run => {
                    tracy.frameMark();
                    try runOrTest(
                        comp,
                        gpa,
                        arena,
                        test_exec_args.items,
                        self_exe_path,
                        arg_mode,
                        target_info,
                        watch,
                        &comp_destroyed,
                        all_args,
                        runtime_args_start,
                        link_libc,
                    );
                },
                .update_and_run => {
                    tracy.frameMark();
                    if (output_mode == .Exe) {
                        try comp.makeBinFileWritable();
                    }
                    updateModule(gpa, comp, hook) catch |err| switch (err) {
                        error.SemanticAnalyzeFail => continue,
                        else => |e| return e,
                    };
                    try comp.makeBinFileExecutable();
                    try runOrTest(
                        comp,
                        gpa,
                        arena,
                        test_exec_args.items,
                        self_exe_path,
                        arg_mode,
                        target_info,
                        watch,
                        &comp_destroyed,
                        all_args,
                        runtime_args_start,
                        link_libc,
                    );
                },
            }
        } else {
            break;
        }
    }
    // Skip resource deallocation in release builds; let the OS do it.
    return cleanExit();
}

fn parseCrossTargetOrReportFatalError(
    allocator: Allocator,
    opts: std.zig.CrossTarget.ParseOptions,
) !std.zig.CrossTarget {
    var opts_with_diags = opts;
    var diags: std.zig.CrossTarget.ParseOptions.Diagnostics = .{};
    if (opts_with_diags.diagnostics == null) {
        opts_with_diags.diagnostics = &diags;
    }
    return std.zig.CrossTarget.parse(opts_with_diags) catch |err| switch (err) {
        error.UnknownCpuModel => {
            help: {
                var help_text = std.ArrayList(u8).init(allocator);
                defer help_text.deinit();
                for (diags.arch.?.allCpuModels()) |cpu| {
                    help_text.writer().print(" {s}\n", .{cpu.name}) catch break :help;
                }
                std.log.info("Available CPUs for architecture '{s}':\n{s}", .{
                    @tagName(diags.arch.?), help_text.items,
                });
            }
            fatal("Unknown CPU: '{s}'", .{diags.cpu_name.?});
        },
        error.UnknownCpuFeature => {
            help: {
                var help_text = std.ArrayList(u8).init(allocator);
                defer help_text.deinit();
                for (diags.arch.?.allFeaturesList()) |feature| {
                    help_text.writer().print(" {s}: {s}\n", .{ feature.name, feature.description }) catch break :help;
                }
                std.log.info("Available CPU features for architecture '{s}':\n{s}", .{
                    @tagName(diags.arch.?), help_text.items,
                });
            }
            fatal("Unknown CPU feature: '{s}'", .{diags.unknown_feature_name});
        },
        else => |e| return e,
    };
}

fn runOrTest(
    comp: *Compilation,
    gpa: Allocator,
    arena: Allocator,
    test_exec_args: []const ?[]const u8,
    self_exe_path: []const u8,
    arg_mode: ArgMode,
    target_info: std.zig.system.NativeTargetInfo,
    watch: bool,
    comp_destroyed: *bool,
    all_args: []const []const u8,
    runtime_args_start: ?usize,
    link_libc: bool,
) !void {
    const exe_emit = comp.bin_file.options.emit orelse return;
    // A naive `directory.join` here will indeed get the correct path to the binary,
    // however, in the case of cwd, we actually want `./foo` so that the path can be executed.
    const exe_path = try fs.path.join(arena, &[_][]const u8{
        exe_emit.directory.path orelse ".", exe_emit.sub_path,
    });

    var argv = std.ArrayList([]const u8).init(gpa);
    defer argv.deinit();

    if (test_exec_args.len == 0) {
        // when testing pass the zig_exe_path to argv
        if (arg_mode == .zig_test)
            try argv.appendSlice(&[_][]const u8{
                exe_path, self_exe_path,
            })
            // when running just pass the current exe
        else
            try argv.appendSlice(&[_][]const u8{
                exe_path,
            });
    } else {
        for (test_exec_args) |arg| {
            if (arg) |a| {
                try argv.append(a);
            } else {
                try argv.appendSlice(&[_][]const u8{
                    exe_path, self_exe_path,
                });
            }
        }
    }
    if (runtime_args_start) |i| {
        try argv.appendSlice(all_args[i..]);
    }
    // We do not execve for tests because if the test fails we want to print
    // the error message and invocation below.
    if (std.process.can_execv and arg_mode == .run and !watch) {
        // execv releases the locks; no need to destroy the Compilation here.
        const err = std.process.execv(gpa, argv.items);
        try warnAboutForeignBinaries(gpa, arena, arg_mode, target_info, link_libc);
        const cmd = try std.mem.join(arena, " ", argv.items);
        fatal("the following command failed to execve with '{s}':\n{s}", .{ @errorName(err), cmd });
    } else if (std.process.can_spawn) {
        var child = std.ChildProcess.init(argv.items, gpa);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        if (!watch) {
            // Here we release all the locks associated with the Compilation so
            // that whatever this child process wants to do won't deadlock.
            comp.destroy();
            comp_destroyed.* = true;
        }

        const term = child.spawnAndWait() catch |err| {
            try warnAboutForeignBinaries(gpa, arena, arg_mode, target_info, link_libc);
            const cmd = try std.mem.join(arena, " ", argv.items);
            fatal("the following command failed with '{s}':\n{s}", .{ @errorName(err), cmd });
        };
        switch (arg_mode) {
            .run, .build => {
                switch (term) {
                    .Exited => |code| {
                        if (code == 0) {
                            if (!watch) return cleanExit();
                        } else if (watch) {
                            warn("process exited with code {d}", .{code});
                        } else {
                            // TODO https://github.com/ziglang/zig/issues/6342
                            process.exit(1);
                        }
                    },
                    else => {
                        if (watch) {
                            warn("process aborted abnormally", .{});
                        } else {
                            process.exit(1);
                        }
                    },
                }
            },
            .zig_test => {
                switch (term) {
                    .Exited => |code| {
                        if (code == 0) {
                            if (!watch) return cleanExit();
                        } else {
                            const cmd = try std.mem.join(arena, " ", argv.items);
                            fatal("the following test command failed with exit code {d}:\n{s}", .{ code, cmd });
                        }
                    },
                    else => {
                        const cmd = try std.mem.join(arena, " ", argv.items);
                        fatal("the following test command crashed:\n{s}", .{cmd});
                    },
                }
            },
            else => unreachable,
        }
    } else {
        const cmd = try std.mem.join(arena, " ", argv.items);
        fatal("the following command cannot be executed ({s} does not support spawning a child process):\n{s}", .{ @tagName(builtin.os.tag), cmd });
    }
}

const AfterUpdateHook = union(enum) {
    none,
    print_emit_bin_dir_path,
    update: []const u8,
};

fn updateModule(gpa: Allocator, comp: *Compilation, hook: AfterUpdateHook) !void {
    try comp.update();

    var errors = try comp.getAllErrorsAlloc();
    defer errors.deinit(comp.gpa);

    if (errors.list.len != 0) {
        const ttyconf: std.debug.TTY.Config = switch (comp.color) {
            .auto => std.debug.detectTTYConfig(),
            .on => .escape_codes,
            .off => .no_color,
        };
        for (errors.list) |full_err_msg| {
            full_err_msg.renderToStdErr(ttyconf);
        }
        const log_text = comp.getCompileLogOutput();
        if (log_text.len != 0) {
            std.debug.print("\nCompile Log Output:\n{s}", .{log_text});
        }
        return error.SemanticAnalyzeFail;
    } else switch (hook) {
        .none => {},
        .print_emit_bin_dir_path => {
            const emit = comp.bin_file.options.emit.?;
            const full_path = try emit.directory.join(gpa, &.{emit.sub_path});
            defer gpa.free(full_path);
            const dir_path = fs.path.dirname(full_path).?;
            try io.getStdOut().writer().print("{s}\n", .{dir_path});
        },
        .update => |full_path| {
            const bin_sub_path = comp.bin_file.options.emit.?.sub_path;
            const cwd = fs.cwd();
            const cache_dir = comp.bin_file.options.emit.?.directory.handle;
            _ = try cache_dir.updateFile(bin_sub_path, cwd, full_path, .{});

            // If a .pdb file is part of the expected output, we must also copy
            // it into place here.
            const is_coff = comp.bin_file.options.object_format == .coff;
            const have_pdb = is_coff and !comp.bin_file.options.strip;
            if (have_pdb) {
                // Replace `.out` or `.exe` with `.pdb` on both the source and destination
                const src_bin_ext = fs.path.extension(bin_sub_path);
                const dst_bin_ext = fs.path.extension(full_path);

                const src_pdb_path = try std.fmt.allocPrint(gpa, "{s}.pdb", .{
                    bin_sub_path[0 .. bin_sub_path.len - src_bin_ext.len],
                });
                defer gpa.free(src_pdb_path);

                const dst_pdb_path = try std.fmt.allocPrint(gpa, "{s}.pdb", .{
                    full_path[0 .. full_path.len - dst_bin_ext.len],
                });
                defer gpa.free(dst_pdb_path);

                _ = try cache_dir.updateFile(src_pdb_path, cwd, dst_pdb_path, .{});
            }
        },
    }
}

fn freePkgTree(gpa: Allocator, pkg: *Package, free_parent: bool) void {
    {
        var it = pkg.table.valueIterator();
        while (it.next()) |value| {
            freePkgTree(gpa, value.*, true);
        }
    }
    if (free_parent) {
        pkg.destroy(gpa);
    }
}

fn cmdTranslateC(comp: *Compilation, arena: Allocator, enable_cache: bool, stage1_mode: bool) !void {
    if (!build_options.have_llvm)
        fatal("cannot translate-c: compiler built without LLVM extensions", .{});

    assert(comp.c_source_files.len == 1);
    const c_source_file = comp.c_source_files[0];

    const translated_zig_basename = try std.fmt.allocPrint(arena, "{s}.zig", .{comp.bin_file.options.root_name});

    var man: Cache.Manifest = comp.obtainCObjectCacheManifest();
    defer if (enable_cache) man.deinit();

    man.hash.add(@as(u16, 0xb945)); // Random number to distinguish translate-c from compiling C objects
    man.hash.add(stage1_mode);
    man.hashCSource(c_source_file) catch |err| {
        fatal("unable to process '{s}': {s}", .{ c_source_file.src_path, @errorName(err) });
    };

    const digest = if (try man.hit()) man.final() else digest: {
        var argv = std.ArrayList([]const u8).init(arena);
        try argv.append(""); // argv[0] is program name, actual args start at [1]

        var zig_cache_tmp_dir = try comp.local_cache_directory.handle.makeOpenPath("tmp", .{});
        defer zig_cache_tmp_dir.close();

        const ext = Compilation.classifyFileExt(c_source_file.src_path);
        const out_dep_path: ?[]const u8 = blk: {
            if (comp.disable_c_depfile or !ext.clangSupportsDepFile())
                break :blk null;

            const c_src_basename = fs.path.basename(c_source_file.src_path);
            const dep_basename = try std.fmt.allocPrint(arena, "{s}.d", .{c_src_basename});
            const out_dep_path = try comp.tmpFilePath(arena, dep_basename);
            break :blk out_dep_path;
        };

        try comp.addTranslateCCArgs(arena, &argv, ext, out_dep_path);
        try argv.append(c_source_file.src_path);

        if (comp.verbose_cc) {
            std.debug.print("clang ", .{});
            Compilation.dump_argv(argv.items);
        }

        // Convert to null terminated args.
        const clang_args_len = argv.items.len + c_source_file.extra_flags.len;
        const new_argv_with_sentinel = try arena.alloc(?[*:0]const u8, clang_args_len + 1);
        new_argv_with_sentinel[clang_args_len] = null;
        const new_argv = new_argv_with_sentinel[0..clang_args_len :null];
        for (argv.items) |arg, i| {
            new_argv[i] = try arena.dupeZ(u8, arg);
        }
        for (c_source_file.extra_flags) |arg, i| {
            new_argv[argv.items.len + i] = try arena.dupeZ(u8, arg);
        }

        const c_headers_dir_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{"include"});
        const c_headers_dir_path_z = try arena.dupeZ(u8, c_headers_dir_path);
        var clang_errors: []translate_c.ClangErrMsg = &[0]translate_c.ClangErrMsg{};
        var tree = translate_c.translate(
            comp.gpa,
            new_argv.ptr,
            new_argv.ptr + new_argv.len,
            &clang_errors,
            c_headers_dir_path_z,
            stage1_mode,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ASTUnitFailure => fatal("clang API returned errors but due to a clang bug, it is not exposing the errors for zig to see. For more details: https://github.com/ziglang/zig/issues/4455", .{}),
            error.SemanticAnalyzeFail => {
                for (clang_errors) |clang_err| {
                    std.debug.print("{s}:{d}:{d}: {s}\n", .{
                        if (clang_err.filename_ptr) |p| p[0..clang_err.filename_len] else "(no file)",
                        clang_err.line + 1,
                        clang_err.column + 1,
                        clang_err.msg_ptr[0..clang_err.msg_len],
                    });
                }
                process.exit(1);
            },
        };
        defer tree.deinit(comp.gpa);

        if (out_dep_path) |dep_file_path| {
            const dep_basename = std.fs.path.basename(dep_file_path);
            // Add the files depended on to the cache system.
            try man.addDepFilePost(zig_cache_tmp_dir, dep_basename);
            // Just to save disk space, we delete the file because it is never needed again.
            zig_cache_tmp_dir.deleteFile(dep_basename) catch |err| {
                warn("failed to delete '{s}': {s}", .{ dep_file_path, @errorName(err) });
            };
        }

        const digest = man.final();
        const o_sub_path = try fs.path.join(arena, &[_][]const u8{ "o", &digest });

        var o_dir = try comp.local_cache_directory.handle.makeOpenPath(o_sub_path, .{});
        defer o_dir.close();

        var zig_file = try o_dir.createFile(translated_zig_basename, .{});
        defer zig_file.close();

        const formatted = try tree.render(comp.gpa);
        defer comp.gpa.free(formatted);

        try zig_file.writeAll(formatted);

        man.writeManifest() catch |err| warn("failed to write cache manifest: {s}", .{
            @errorName(err),
        });

        break :digest digest;
    };

    if (enable_cache) {
        const full_zig_path = try comp.local_cache_directory.join(arena, &[_][]const u8{
            "o", &digest, translated_zig_basename,
        });
        try io.getStdOut().writer().print("{s}\n", .{full_zig_path});
        return cleanExit();
    } else {
        const out_zig_path = try fs.path.join(arena, &[_][]const u8{ "o", &digest, translated_zig_basename });
        const zig_file = comp.local_cache_directory.handle.openFile(out_zig_path, .{}) catch |err| {
            fatal("unable to open cached translated zig file '{s}{s}{s}': {s}", .{ comp.local_cache_directory.path, fs.path.sep_str, out_zig_path, @errorName(err) });
        };
        defer zig_file.close();
        try io.getStdOut().writeFileAll(zig_file, .{});
        return cleanExit();
    }
}

pub const usage_libc =
    \\Usage: zig libc
    \\
    \\    Detect the native libc installation and print the resulting
    \\    paths to stdout. You can save this into a file and then edit
    \\    the paths to create a cross compilation libc kit. Then you
    \\    can pass `--libc [file]` for Zig to use it.
    \\
    \\Usage: zig libc [paths_file]
    \\
    \\    Parse a libc installation text file and validate it.
    \\
    \\Options:
    \\    -h, --help             Print this help and exit
    \\    -target [name]         <arch><sub>-<os>-<abi> see the targets command
    \\
;

pub fn cmdLibC(gpa: Allocator, args: []const []const u8) !void {
    var input_file: ?[]const u8 = null;
    var target_arch_os_abi: []const u8 = "native";
    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    const stdout = io.getStdOut().writer();
                    try stdout.writeAll(usage_libc);
                    return cleanExit();
                } else if (mem.eql(u8, arg, "-target")) {
                    if (i + 1 >= args.len) fatal("expected parameter after {s}", .{arg});
                    i += 1;
                    target_arch_os_abi = args[i];
                } else {
                    fatal("unrecognized parameter: '{s}'", .{arg});
                }
            } else if (input_file != null) {
                fatal("unexpected extra parameter: '{s}'", .{arg});
            } else {
                input_file = arg;
            }
        }
    }

    const cross_target = try parseCrossTargetOrReportFatalError(gpa, .{
        .arch_os_abi = target_arch_os_abi,
    });

    if (input_file) |libc_file| {
        var libc = LibCInstallation.parse(gpa, libc_file, cross_target) catch |err| {
            fatal("unable to parse libc file at path {s}: {s}", .{ libc_file, @errorName(err) });
        };
        defer libc.deinit(gpa);
    } else {
        if (!cross_target.isNative()) {
            fatal("unable to detect libc for non-native target", .{});
        }

        var libc = LibCInstallation.findNative(.{
            .allocator = gpa,
            .verbose = true,
        }) catch |err| {
            fatal("unable to detect native libc: {s}", .{@errorName(err)});
        };
        defer libc.deinit(gpa);

        var bw = io.bufferedWriter(io.getStdOut().writer());
        try libc.render(bw.writer());
        try bw.flush();
    }
}

pub const usage_init =
    \\Usage: zig init-exe
    \\       zig init-lib
    \\
    \\   Initializes a `zig build` project in the current working
    \\   directory.
    \\
    \\Options:
    \\   -h, --help             Print this help and exit
    \\
    \\
;

pub fn cmdInit(
    gpa: Allocator,
    arena: Allocator,
    args: []const []const u8,
    output_mode: std.builtin.OutputMode,
) !void {
    _ = gpa;
    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    try io.getStdOut().writeAll(usage_init);
                    return cleanExit();
                } else {
                    fatal("unrecognized parameter: '{s}'", .{arg});
                }
            } else {
                fatal("unexpected extra parameter: '{s}'", .{arg});
            }
        }
    }
    const self_exe_path = try introspect.findZigExePath(arena);
    var zig_lib_directory = introspect.findZigLibDirFromSelfExe(arena, self_exe_path) catch |err| {
        fatal("unable to find zig installation directory: {s}\n", .{@errorName(err)});
    };
    defer zig_lib_directory.handle.close();

    const s = fs.path.sep_str;
    const template_sub_path = switch (output_mode) {
        .Obj => unreachable,
        .Lib => "init-lib",
        .Exe => "init-exe",
    };
    var template_dir = zig_lib_directory.handle.openDir(template_sub_path, .{}) catch |err| {
        fatal("unable to open zig project template directory '{s}{s}{s}': {s}", .{ zig_lib_directory.path, s, template_sub_path, @errorName(err) });
    };
    defer template_dir.close();

    const cwd_path = try process.getCwdAlloc(arena);
    const cwd_basename = fs.path.basename(cwd_path);

    const max_bytes = 10 * 1024 * 1024;
    const build_zig_contents = template_dir.readFileAlloc(arena, "build.zig", max_bytes) catch |err| {
        fatal("unable to read template file 'build.zig': {s}", .{@errorName(err)});
    };
    var modified_build_zig_contents = try std.ArrayList(u8).initCapacity(arena, build_zig_contents.len);
    for (build_zig_contents) |c| {
        if (c == '$') {
            try modified_build_zig_contents.appendSlice(cwd_basename);
        } else {
            try modified_build_zig_contents.append(c);
        }
    }
    const main_zig_contents = template_dir.readFileAlloc(arena, "src" ++ s ++ "main.zig", max_bytes) catch |err| {
        fatal("unable to read template file 'main.zig': {s}", .{@errorName(err)});
    };
    if (fs.cwd().access("build.zig", .{})) |_| {
        fatal("existing build.zig file would be overwritten", .{});
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => fatal("unable to test existence of build.zig: {s}\n", .{@errorName(err)}),
    }
    if (fs.cwd().access("src" ++ s ++ "main.zig", .{})) |_| {
        fatal("existing src" ++ s ++ "main.zig file would be overwritten", .{});
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => fatal("unable to test existence of src" ++ s ++ "main.zig: {s}\n", .{@errorName(err)}),
    }
    var src_dir = try fs.cwd().makeOpenPath("src", .{});
    defer src_dir.close();

    try src_dir.writeFile("main.zig", main_zig_contents);
    try fs.cwd().writeFile("build.zig", modified_build_zig_contents.items);

    std.log.info("Created build.zig", .{});
    std.log.info("Created src" ++ s ++ "main.zig", .{});

    switch (output_mode) {
        .Lib => std.log.info("Next, try `zig build --help` or `zig build test`", .{}),
        .Exe => std.log.info("Next, try `zig build --help` or `zig build run`", .{}),
        .Obj => unreachable,
    }
}

pub const usage_build =
    \\Usage: zig build [steps] [options]
    \\
    \\   Build a project from build.zig.
    \\
    \\Options:
    \\   -fstage1                      Force using bootstrap compiler as the codegen backend
    \\   -fno-stage1                   Prevent using bootstrap compiler as the codegen backend
    \\   --build-file [file]           Override path to build.zig
    \\   --cache-dir [path]            Override path to local Zig cache directory
    \\   --global-cache-dir [path]     Override path to global Zig cache directory
    \\   --zig-lib-dir [arg]           Override path to Zig lib directory
    \\   --prominent-compile-errors    Output compile errors formatted for a human to read
    \\   -h, --help                    Print this help and exit
    \\
;

pub fn cmdBuild(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    var prominent_compile_errors: bool = false;
    var use_stage1: ?bool = null;

    // We want to release all the locks before executing the child process, so we make a nice
    // big block here to ensure the cleanup gets run when we extract out our argv.
    const child_argv = argv: {
        const self_exe_path = try introspect.findZigExePath(arena);

        var build_file: ?[]const u8 = null;
        var override_lib_dir: ?[]const u8 = null;
        var override_global_cache_dir: ?[]const u8 = null;
        var override_local_cache_dir: ?[]const u8 = null;
        var child_argv = std.ArrayList([]const u8).init(arena);

        const argv_index_exe = child_argv.items.len;
        _ = try child_argv.addOne();

        try child_argv.append(self_exe_path);

        const argv_index_build_file = child_argv.items.len;
        _ = try child_argv.addOne();

        const argv_index_cache_dir = child_argv.items.len;
        _ = try child_argv.addOne();

        const argv_index_global_cache_dir = child_argv.items.len;
        _ = try child_argv.addOne();

        {
            var i: usize = 0;
            while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (mem.startsWith(u8, arg, "-")) {
                    if (mem.eql(u8, arg, "--build-file")) {
                        if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                        i += 1;
                        build_file = args[i];
                        continue;
                    } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                        if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                        i += 1;
                        override_lib_dir = args[i];
                        try child_argv.appendSlice(&[_][]const u8{ arg, args[i] });
                        continue;
                    } else if (mem.eql(u8, arg, "--cache-dir")) {
                        if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                        i += 1;
                        override_local_cache_dir = args[i];
                        continue;
                    } else if (mem.eql(u8, arg, "--global-cache-dir")) {
                        if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                        i += 1;
                        override_global_cache_dir = args[i];
                        continue;
                    } else if (mem.eql(u8, arg, "--prominent-compile-errors")) {
                        prominent_compile_errors = true;
                    } else if (mem.eql(u8, arg, "-fstage1")) {
                        use_stage1 = true;
                        try child_argv.append(arg);
                    } else if (mem.eql(u8, arg, "-fno-stage1")) {
                        use_stage1 = false;
                        try child_argv.append(arg);
                    }
                }
                try child_argv.append(arg);
            }
        }

        var zig_lib_directory: Compilation.Directory = if (override_lib_dir) |lib_dir| .{
            .path = lib_dir,
            .handle = fs.cwd().openDir(lib_dir, .{}) catch |err| {
                fatal("unable to open zig lib directory from 'zig-lib-dir' argument: '{s}': {s}", .{ lib_dir, @errorName(err) });
            },
        } else introspect.findZigLibDirFromSelfExe(arena, self_exe_path) catch |err| {
            fatal("unable to find zig installation directory '{s}': {s}", .{ self_exe_path, @errorName(err) });
        };
        defer zig_lib_directory.handle.close();

        var main_pkg: Package = .{
            .root_src_directory = zig_lib_directory,
            .root_src_path = "build_runner.zig",
        };

        var cleanup_build_dir: ?fs.Dir = null;
        defer if (cleanup_build_dir) |*dir| dir.close();

        const cwd_path = try process.getCwdAlloc(arena);
        const build_zig_basename = if (build_file) |bf| fs.path.basename(bf) else "build.zig";
        const build_directory: Compilation.Directory = blk: {
            if (build_file) |bf| {
                if (fs.path.dirname(bf)) |dirname| {
                    const dir = fs.cwd().openDir(dirname, .{}) catch |err| {
                        fatal("unable to open directory to build file from argument 'build-file', '{s}': {s}", .{ dirname, @errorName(err) });
                    };
                    cleanup_build_dir = dir;
                    break :blk .{ .path = dirname, .handle = dir };
                }

                break :blk .{ .path = null, .handle = fs.cwd() };
            }
            // Search up parent directories until we find build.zig.
            var dirname: []const u8 = cwd_path;
            while (true) {
                const joined_path = try fs.path.join(arena, &[_][]const u8{ dirname, build_zig_basename });
                if (fs.cwd().access(joined_path, .{})) |_| {
                    const dir = fs.cwd().openDir(dirname, .{}) catch |err| {
                        fatal("unable to open directory while searching for build.zig file, '{s}': {s}", .{ dirname, @errorName(err) });
                    };
                    break :blk .{ .path = dirname, .handle = dir };
                } else |err| switch (err) {
                    error.FileNotFound => {
                        dirname = fs.path.dirname(dirname) orelse {
                            std.log.info("{s}", .{
                                \\Initialize a 'build.zig' template file with `zig init-lib` or `zig init-exe`,
                                \\or see `zig --help` for more options.
                            });
                            fatal("No 'build.zig' file found, in the current directory or any parent directories.", .{});
                        };
                        continue;
                    },
                    else => |e| return e,
                }
            }
        };
        child_argv.items[argv_index_build_file] = build_directory.path orelse cwd_path;

        var build_pkg: Package = .{
            .root_src_directory = build_directory,
            .root_src_path = build_zig_basename,
        };
        try main_pkg.addAndAdopt(arena, "@build", &build_pkg);

        var global_cache_directory: Compilation.Directory = l: {
            const p = override_global_cache_dir orelse try introspect.resolveGlobalCacheDir(arena);
            break :l .{
                .handle = try fs.cwd().makeOpenPath(p, .{}),
                .path = p,
            };
        };
        defer global_cache_directory.handle.close();

        child_argv.items[argv_index_global_cache_dir] = global_cache_directory.path orelse cwd_path;

        var local_cache_directory: Compilation.Directory = l: {
            if (override_local_cache_dir) |local_cache_dir_path| {
                break :l .{
                    .handle = try fs.cwd().makeOpenPath(local_cache_dir_path, .{}),
                    .path = local_cache_dir_path,
                };
            }
            const cache_dir_path = try build_directory.join(arena, &[_][]const u8{"zig-cache"});
            break :l .{
                .handle = try build_directory.handle.makeOpenPath("zig-cache", .{}),
                .path = cache_dir_path,
            };
        };
        defer local_cache_directory.handle.close();

        child_argv.items[argv_index_cache_dir] = local_cache_directory.path orelse cwd_path;

        gimmeMoreOfThoseSweetSweetFileDescriptors();

        const cross_target: std.zig.CrossTarget = .{};
        const target_info = try detectNativeTargetInfo(gpa, cross_target);

        const exe_basename = try std.zig.binNameAlloc(arena, .{
            .root_name = "build",
            .target = target_info.target,
            .output_mode = .Exe,
        });
        const emit_bin: Compilation.EmitLoc = .{
            .directory = null, // Use the local zig-cache.
            .basename = exe_basename,
        };
        var thread_pool: ThreadPool = undefined;
        try thread_pool.init(gpa);
        defer thread_pool.deinit();
        const comp = Compilation.create(gpa, .{
            .zig_lib_directory = zig_lib_directory,
            .local_cache_directory = local_cache_directory,
            .global_cache_directory = global_cache_directory,
            .root_name = "build",
            .target = target_info.target,
            .is_native_os = cross_target.isNativeOs(),
            .is_native_abi = cross_target.isNativeAbi(),
            .dynamic_linker = target_info.dynamic_linker.get(),
            .output_mode = .Exe,
            .main_pkg = &main_pkg,
            .emit_bin = emit_bin,
            .emit_h = null,
            .optimize_mode = .Debug,
            .self_exe_path = self_exe_path,
            .thread_pool = &thread_pool,
            .use_stage1 = use_stage1,
            .cache_mode = .whole,
        }) catch |err| {
            fatal("unable to create compilation: {s}", .{@errorName(err)});
        };
        defer comp.destroy();

        updateModule(gpa, comp, .none) catch |err| switch (err) {
            error.SemanticAnalyzeFail => process.exit(1),
            else => |e| return e,
        };
        try comp.makeBinFileExecutable();

        const emit = comp.bin_file.options.emit.?;
        child_argv.items[argv_index_exe] = try emit.directory.join(
            arena,
            &[_][]const u8{emit.sub_path},
        );

        break :argv child_argv.items;
    };

    if (std.process.can_spawn) {
        var child = std.ChildProcess.init(child_argv, gpa);
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        const term = try child.spawnAndWait();
        switch (term) {
            .Exited => |code| {
                if (code == 0) return cleanExit();

                if (prominent_compile_errors) {
                    fatal("the build command failed with exit code {d}", .{code});
                } else {
                    const cmd = try std.mem.join(arena, " ", child_argv);
                    fatal("the following build command failed with exit code {d}:\n{s}", .{ code, cmd });
                }
            },
            else => {
                const cmd = try std.mem.join(arena, " ", child_argv);
                fatal("the following build command crashed:\n{s}", .{cmd});
            },
        }
    } else {
        const cmd = try std.mem.join(arena, " ", child_argv);
        fatal("the following command cannot be executed ({s} does not support spawning a child process):\n{s}", .{ @tagName(builtin.os.tag), cmd });
    }
}

fn readSourceFileToEndAlloc(
    allocator: mem.Allocator,
    input: *const fs.File,
    size_hint: ?usize,
) ![:0]u8 {
    const source_code = input.readToEndAllocOptions(
        allocator,
        max_src_size,
        size_hint,
        @alignOf(u16),
        0,
    ) catch |err| switch (err) {
        error.ConnectionResetByPeer => unreachable,
        error.ConnectionTimedOut => unreachable,
        error.NotOpenForReading => unreachable,
        else => |e| return e,
    };
    errdefer allocator.free(source_code);

    // Detect unsupported file types with their Byte Order Mark
    const unsupported_boms = [_][]const u8{
        "\xff\xfe\x00\x00", // UTF-32 little endian
        "\xfe\xff\x00\x00", // UTF-32 big endian
        "\xfe\xff", // UTF-16 big endian
    };
    for (unsupported_boms) |bom| {
        if (mem.startsWith(u8, source_code, bom)) {
            return error.UnsupportedEncoding;
        }
    }

    // If the file starts with a UTF-16 little endian BOM, translate it to UTF-8
    if (mem.startsWith(u8, source_code, "\xff\xfe")) {
        const source_code_utf16_le = mem.bytesAsSlice(u16, source_code);
        const source_code_utf8 = std.unicode.utf16leToUtf8AllocZ(allocator, source_code_utf16_le) catch |err| switch (err) {
            error.DanglingSurrogateHalf => error.UnsupportedEncoding,
            error.ExpectedSecondSurrogateHalf => error.UnsupportedEncoding,
            error.UnexpectedSecondSurrogateHalf => error.UnsupportedEncoding,
            else => |e| return e,
        };

        allocator.free(source_code);
        return source_code_utf8;
    }

    return source_code;
}

pub const usage_fmt =
    \\Usage: zig fmt [file]...
    \\
    \\   Formats the input files and modifies them in-place.
    \\   Arguments can be files or directories, which are searched
    \\   recursively.
    \\
    \\Options:
    \\   -h, --help             Print this help and exit
    \\   --color [auto|off|on]  Enable or disable colored error messages
    \\   --stdin                Format code from stdin; output to stdout
    \\   --check                List non-conforming files and exit with an error
    \\                          if the list is non-empty
    \\   --ast-check            Run zig ast-check on every file
    \\   --exclude [file]       Exclude file or directory from formatting
    \\
    \\
;

const Fmt = struct {
    seen: SeenMap,
    any_error: bool,
    check_ast: bool,
    color: Color,
    gpa: Allocator,
    arena: Allocator,
    out_buffer: std.ArrayList(u8),

    const SeenMap = std.AutoHashMap(fs.File.INode, void);
};

pub fn cmdFmt(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    var color: Color = .auto;
    var stdin_flag: bool = false;
    var check_flag: bool = false;
    var check_ast_flag: bool = false;
    var input_files = ArrayList([]const u8).init(gpa);
    defer input_files.deinit();
    var excluded_files = ArrayList([]const u8).init(gpa);
    defer excluded_files.deinit();

    {
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (mem.startsWith(u8, arg, "-")) {
                if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                    const stdout = io.getStdOut().writer();
                    try stdout.writeAll(usage_fmt);
                    return cleanExit();
                } else if (mem.eql(u8, arg, "--color")) {
                    if (i + 1 >= args.len) {
                        fatal("expected [auto|on|off] after --color", .{});
                    }
                    i += 1;
                    const next_arg = args[i];
                    color = std.meta.stringToEnum(Color, next_arg) orelse {
                        fatal("expected [auto|on|off] after --color, found '{s}'", .{next_arg});
                    };
                } else if (mem.eql(u8, arg, "--stdin")) {
                    stdin_flag = true;
                } else if (mem.eql(u8, arg, "--check")) {
                    check_flag = true;
                } else if (mem.eql(u8, arg, "--ast-check")) {
                    check_ast_flag = true;
                } else if (mem.eql(u8, arg, "--exclude")) {
                    if (i + 1 >= args.len) {
                        fatal("expected parameter after --exclude", .{});
                    }
                    i += 1;
                    const next_arg = args[i];
                    try excluded_files.append(next_arg);
                } else {
                    fatal("unrecognized parameter: '{s}'", .{arg});
                }
            } else {
                try input_files.append(arg);
            }
        }
    }

    if (stdin_flag) {
        if (input_files.items.len != 0) {
            fatal("cannot use --stdin with positional arguments", .{});
        }

        const stdin = io.getStdIn();
        const source_code = readSourceFileToEndAlloc(gpa, &stdin, null) catch |err| {
            fatal("unable to read stdin: {s}", .{err});
        };
        defer gpa.free(source_code);

        var tree = std.zig.parse(gpa, source_code) catch |err| {
            fatal("error parsing stdin: {s}", .{err});
        };
        defer tree.deinit(gpa);

        try printErrsMsgToStdErr(gpa, arena, tree.errors, tree, "<stdin>", color);
        var has_ast_error = false;
        if (check_ast_flag) {
            const Module = @import("Module.zig");
            const AstGen = @import("AstGen.zig");

            var file: Module.File = .{
                .status = .never_loaded,
                .source_loaded = true,
                .zir_loaded = false,
                .sub_file_path = "<stdin>",
                .source = source_code,
                .stat = undefined,
                .tree = tree,
                .tree_loaded = true,
                .zir = undefined,
                .pkg = undefined,
                .root_decl = .none,
            };

            file.pkg = try Package.create(gpa, null, file.sub_file_path);
            defer file.pkg.destroy(gpa);

            file.zir = try AstGen.generate(gpa, file.tree);
            file.zir_loaded = true;
            defer file.zir.deinit(gpa);

            if (file.zir.hasCompileErrors()) {
                var arena_instance = std.heap.ArenaAllocator.init(gpa);
                defer arena_instance.deinit();
                var errors = std.ArrayList(Compilation.AllErrors.Message).init(gpa);
                defer errors.deinit();

                try Compilation.AllErrors.addZir(arena_instance.allocator(), &errors, &file);
                const ttyconf: std.debug.TTY.Config = switch (color) {
                    .auto => std.debug.detectTTYConfig(),
                    .on => .escape_codes,
                    .off => .no_color,
                };
                for (errors.items) |full_err_msg| {
                    full_err_msg.renderToStdErr(ttyconf);
                }
                has_ast_error = true;
            }
        }
        if (tree.errors.len != 0 or has_ast_error) {
            process.exit(1);
        }
        const formatted = try tree.render(gpa);
        defer gpa.free(formatted);

        if (check_flag) {
            const code: u8 = @boolToInt(mem.eql(u8, formatted, source_code));
            process.exit(code);
        }

        return io.getStdOut().writeAll(formatted);
    }

    if (input_files.items.len == 0) {
        fatal("expected at least one source file argument", .{});
    }

    var fmt = Fmt{
        .gpa = gpa,
        .arena = arena,
        .seen = Fmt.SeenMap.init(gpa),
        .any_error = false,
        .check_ast = check_ast_flag,
        .color = color,
        .out_buffer = std.ArrayList(u8).init(gpa),
    };
    defer fmt.seen.deinit();
    defer fmt.out_buffer.deinit();

    // Mark any excluded files/directories as already seen,
    // so that they are skipped later during actual processing
    for (excluded_files.items) |file_path| {
        var dir = fs.cwd().openDir(file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        defer dir.close();

        const stat = try dir.stat();
        try fmt.seen.put(stat.inode, {});
    }

    for (input_files.items) |file_path| {
        try fmtPath(&fmt, file_path, check_flag, fs.cwd(), file_path);
    }
    if (fmt.any_error) {
        process.exit(1);
    }
}

const FmtError = error{
    SystemResources,
    OperationAborted,
    IoPending,
    BrokenPipe,
    Unexpected,
    WouldBlock,
    FileClosed,
    DestinationAddressRequired,
    DiskQuota,
    FileTooBig,
    InputOutput,
    NoSpaceLeft,
    AccessDenied,
    OutOfMemory,
    RenameAcrossMountPoints,
    ReadOnlyFileSystem,
    LinkQuotaExceeded,
    FileBusy,
    EndOfStream,
    Unseekable,
    NotOpenForWriting,
    UnsupportedEncoding,
    ConnectionResetByPeer,
} || fs.File.OpenError;

fn fmtPath(fmt: *Fmt, file_path: []const u8, check_mode: bool, dir: fs.Dir, sub_path: []const u8) FmtError!void {
    fmtPathFile(fmt, file_path, check_mode, dir, sub_path) catch |err| switch (err) {
        error.IsDir, error.AccessDenied => return fmtPathDir(fmt, file_path, check_mode, dir, sub_path),
        else => {
            warn("unable to format '{s}': {s}", .{ file_path, @errorName(err) });
            fmt.any_error = true;
            return;
        },
    };
}

fn fmtPathDir(
    fmt: *Fmt,
    file_path: []const u8,
    check_mode: bool,
    parent_dir: fs.Dir,
    parent_sub_path: []const u8,
) FmtError!void {
    var iterable_dir = try parent_dir.openIterableDir(parent_sub_path, .{});
    defer iterable_dir.close();

    const stat = try iterable_dir.dir.stat();
    if (try fmt.seen.fetchPut(stat.inode, {})) |_| return;

    var dir_it = iterable_dir.iterate();
    while (try dir_it.next()) |entry| {
        const is_dir = entry.kind == .Directory;

        if (is_dir and (mem.eql(u8, entry.name, "zig-cache") or mem.eql(u8, entry.name, "zig-out"))) continue;

        if (is_dir or mem.endsWith(u8, entry.name, ".zig")) {
            const full_path = try fs.path.join(fmt.gpa, &[_][]const u8{ file_path, entry.name });
            defer fmt.gpa.free(full_path);

            if (is_dir) {
                try fmtPathDir(fmt, full_path, check_mode, iterable_dir.dir, entry.name);
            } else {
                fmtPathFile(fmt, full_path, check_mode, iterable_dir.dir, entry.name) catch |err| {
                    warn("unable to format '{s}': {s}", .{ full_path, @errorName(err) });
                    fmt.any_error = true;
                    return;
                };
            }
        }
    }
}

fn fmtPathFile(
    fmt: *Fmt,
    file_path: []const u8,
    check_mode: bool,
    dir: fs.Dir,
    sub_path: []const u8,
) FmtError!void {
    const source_file = try dir.openFile(sub_path, .{});
    var file_closed = false;
    errdefer if (!file_closed) source_file.close();

    const stat = try source_file.stat();

    if (stat.kind == .Directory)
        return error.IsDir;

    const source_code = try readSourceFileToEndAlloc(
        fmt.gpa,
        &source_file,
        std.math.cast(usize, stat.size) orelse return error.FileTooBig,
    );
    defer fmt.gpa.free(source_code);

    source_file.close();
    file_closed = true;

    // Add to set after no longer possible to get error.IsDir.
    if (try fmt.seen.fetchPut(stat.inode, {})) |_| return;

    var tree = try std.zig.parse(fmt.gpa, source_code);
    defer tree.deinit(fmt.gpa);

    try printErrsMsgToStdErr(fmt.gpa, fmt.arena, tree.errors, tree, file_path, fmt.color);
    if (tree.errors.len != 0) {
        fmt.any_error = true;
        return;
    }

    if (fmt.check_ast) {
        const Module = @import("Module.zig");
        const AstGen = @import("AstGen.zig");

        var file: Module.File = .{
            .status = .never_loaded,
            .source_loaded = true,
            .zir_loaded = false,
            .sub_file_path = file_path,
            .source = source_code,
            .stat = .{
                .size = stat.size,
                .inode = stat.inode,
                .mtime = stat.mtime,
            },
            .tree = tree,
            .tree_loaded = true,
            .zir = undefined,
            .pkg = undefined,
            .root_decl = .none,
        };

        file.pkg = try Package.create(fmt.gpa, null, file.sub_file_path);
        defer file.pkg.destroy(fmt.gpa);

        if (stat.size > max_src_size)
            return error.FileTooBig;

        file.zir = try AstGen.generate(fmt.gpa, file.tree);
        file.zir_loaded = true;
        defer file.zir.deinit(fmt.gpa);

        if (file.zir.hasCompileErrors()) {
            var arena_instance = std.heap.ArenaAllocator.init(fmt.gpa);
            defer arena_instance.deinit();
            var errors = std.ArrayList(Compilation.AllErrors.Message).init(fmt.gpa);
            defer errors.deinit();

            try Compilation.AllErrors.addZir(arena_instance.allocator(), &errors, &file);
            const ttyconf: std.debug.TTY.Config = switch (fmt.color) {
                .auto => std.debug.detectTTYConfig(),
                .on => .escape_codes,
                .off => .no_color,
            };
            for (errors.items) |full_err_msg| {
                full_err_msg.renderToStdErr(ttyconf);
            }
            fmt.any_error = true;
        }
    }

    // As a heuristic, we make enough capacity for the same as the input source.
    fmt.out_buffer.shrinkRetainingCapacity(0);
    try fmt.out_buffer.ensureTotalCapacity(source_code.len);

    try tree.renderToArrayList(&fmt.out_buffer);
    if (mem.eql(u8, fmt.out_buffer.items, source_code))
        return;

    if (check_mode) {
        const stdout = io.getStdOut().writer();
        try stdout.print("{s}\n", .{file_path});
        fmt.any_error = true;
    } else {
        var af = try dir.atomicFile(sub_path, .{ .mode = stat.mode });
        defer af.deinit();

        try af.file.writeAll(fmt.out_buffer.items);
        try af.finish();
        const stdout = io.getStdOut().writer();
        try stdout.print("{s}\n", .{file_path});
    }
}

fn printErrsMsgToStdErr(
    gpa: mem.Allocator,
    arena: mem.Allocator,
    parse_errors: []const Ast.Error,
    tree: Ast,
    path: []const u8,
    color: Color,
) !void {
    var i: usize = 0;
    while (i < parse_errors.len) : (i += 1) {
        const parse_error = parse_errors[i];
        const lok_token = parse_error.token;
        const token_tags = tree.tokens.items(.tag);
        const start_loc = tree.tokenLocation(0, lok_token);
        const source_line = tree.source[start_loc.line_start..start_loc.line_end];

        var text_buf = std.ArrayList(u8).init(gpa);
        defer text_buf.deinit();
        const writer = text_buf.writer();
        try tree.renderError(parse_error, writer);
        const text = try arena.dupe(u8, text_buf.items);

        var notes_buffer: [2]Compilation.AllErrors.Message = undefined;
        var notes_len: usize = 0;

        if (token_tags[parse_error.token + @boolToInt(parse_error.token_is_prev)] == .invalid) {
            const bad_off = @intCast(u32, tree.tokenSlice(parse_error.token + @boolToInt(parse_error.token_is_prev)).len);
            const byte_offset = @intCast(u32, start_loc.line_start) + @intCast(u32, start_loc.column) + bad_off;
            notes_buffer[notes_len] = .{
                .src = .{
                    .src_path = path,
                    .msg = try std.fmt.allocPrint(arena, "invalid byte: '{'}'", .{
                        std.zig.fmtEscapes(tree.source[byte_offset..][0..1]),
                    }),
                    .span = .{ .start = byte_offset, .end = byte_offset + 1, .main = byte_offset },
                    .line = @intCast(u32, start_loc.line),
                    .column = @intCast(u32, start_loc.column) + bad_off,
                    .source_line = source_line,
                },
            };
            notes_len += 1;
        }

        for (parse_errors[i + 1 ..]) |note| {
            if (!note.is_note) break;

            text_buf.items.len = 0;
            try tree.renderError(note, writer);
            const note_loc = tree.tokenLocation(0, note.token);
            const byte_offset = @intCast(u32, note_loc.line_start);
            notes_buffer[notes_len] = .{
                .src = .{
                    .src_path = path,
                    .msg = try arena.dupe(u8, text_buf.items),
                    .span = .{
                        .start = byte_offset,
                        .end = byte_offset + @intCast(u32, tree.tokenSlice(note.token).len),
                        .main = byte_offset,
                    },
                    .line = @intCast(u32, note_loc.line),
                    .column = @intCast(u32, note_loc.column),
                    .source_line = tree.source[note_loc.line_start..note_loc.line_end],
                },
            };
            i += 1;
            notes_len += 1;
        }

        const extra_offset = tree.errorOffset(parse_error);
        const byte_offset = @intCast(u32, start_loc.line_start) + extra_offset;
        const message: Compilation.AllErrors.Message = .{
            .src = .{
                .src_path = path,
                .msg = text,
                .span = .{
                    .start = byte_offset,
                    .end = byte_offset + @intCast(u32, tree.tokenSlice(lok_token).len),
                    .main = byte_offset,
                },
                .line = @intCast(u32, start_loc.line),
                .column = @intCast(u32, start_loc.column) + extra_offset,
                .source_line = source_line,
                .notes = notes_buffer[0..notes_len],
            },
        };

        const ttyconf: std.debug.TTY.Config = switch (color) {
            .auto => std.debug.detectTTYConfig(),
            .on => .escape_codes,
            .off => .no_color,
        };

        message.renderToStdErr(ttyconf);
    }
}

pub const info_zen =
    \\
    \\ * Communicate intent precisely.
    \\ * Edge cases matter.
    \\ * Favor reading code over writing code.
    \\ * Only one obvious way to do things.
    \\ * Runtime crashes are better than bugs.
    \\ * Compile errors are better than runtime crashes.
    \\ * Incremental improvements.
    \\ * Avoid local maximums.
    \\ * Reduce the amount one must remember.
    \\ * Focus on code rather than style.
    \\ * Resource allocation may fail; resource deallocation must succeed.
    \\ * Memory is a resource.
    \\ * Together we serve the users.
    \\
    \\
;

extern "c" fn ZigClang_main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;
extern "c" fn ZigLlvmAr_main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;

fn argsCopyZ(alloc: Allocator, args: []const []const u8) ![:null]?[*:0]u8 {
    var argv = try alloc.allocSentinel(?[*:0]u8, args.len, null);
    for (args) |arg, i| {
        argv[i] = try alloc.dupeZ(u8, arg); // TODO If there was an argsAllocZ we could avoid this allocation.
    }
    return argv;
}

pub fn clangMain(alloc: Allocator, args: []const []const u8) error{OutOfMemory}!u8 {
    if (!build_options.have_llvm)
        fatal("`zig cc` and `zig c++` unavailable: compiler built without LLVM extensions", .{});

    var arena_instance = std.heap.ArenaAllocator.init(alloc);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // Convert the args to the null-terminated format Clang expects.
    const argv = try argsCopyZ(arena, args);
    const exit_code = ZigClang_main(@intCast(c_int, argv.len), argv.ptr);
    return @bitCast(u8, @truncate(i8, exit_code));
}

pub fn llvmArMain(alloc: Allocator, args: []const []const u8) error{OutOfMemory}!u8 {
    if (!build_options.have_llvm)
        fatal("`zig ar`, `zig dlltool`, `zig ranlib', and `zig lib` unavailable: compiler built without LLVM extensions", .{});

    var arena_instance = std.heap.ArenaAllocator.init(alloc);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // Convert the args to the format llvm-ar expects.
    // We intentionally shave off the zig binary at args[0].
    const argv = try argsCopyZ(arena, args[1..]);
    const exit_code = ZigLlvmAr_main(@intCast(c_int, argv.len), argv.ptr);
    return @bitCast(u8, @truncate(i8, exit_code));
}

/// The first argument determines which backend is invoked. The options are:
/// * `ld.lld` - ELF
/// * `lld-link` - COFF
/// * `wasm-ld` - WebAssembly
pub fn lldMain(
    alloc: Allocator,
    args: []const []const u8,
    can_exit_early: bool,
) error{OutOfMemory}!u8 {
    if (!build_options.have_llvm)
        fatal("`zig {s}` unavailable: compiler built without LLVM extensions", .{args[0]});

    // Print a warning if lld is called multiple times in the same process,
    // since it may misbehave
    // https://github.com/ziglang/zig/issues/3825
    const CallCounter = struct {
        var count: usize = 0;
    };
    if (CallCounter.count == 1) { // Issue the warning on the first repeat call
        warn("invoking LLD for the second time within the same process because the host OS ({s}) does not support spawning child processes. This sometimes activates LLD bugs", .{@tagName(builtin.os.tag)});
    }
    CallCounter.count += 1;

    var arena_instance = std.heap.ArenaAllocator.init(alloc);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // Convert the args to the format LLD expects.
    // We intentionally shave off the zig binary at args[0].
    const argv = try argsCopyZ(arena, args[1..]);
    // "If an error occurs, false will be returned."
    const ok = rc: {
        const llvm = @import("codegen/llvm/bindings.zig");
        const argc = @intCast(c_int, argv.len);
        if (mem.eql(u8, args[1], "ld.lld")) {
            break :rc llvm.LinkELF(argc, argv.ptr, can_exit_early, false);
        } else if (mem.eql(u8, args[1], "lld-link")) {
            break :rc llvm.LinkCOFF(argc, argv.ptr, can_exit_early, false);
        } else if (mem.eql(u8, args[1], "wasm-ld")) {
            break :rc llvm.LinkWasm(argc, argv.ptr, can_exit_early, false);
        } else {
            unreachable;
        }
    };
    return @boolToInt(!ok);
}

const ArgIteratorResponseFile = process.ArgIteratorGeneral(.{ .comments = true, .single_quotes = true });

/// Initialize the arguments from a Response File. "*.rsp"
fn initArgIteratorResponseFile(allocator: Allocator, resp_file_path: []const u8) !ArgIteratorResponseFile {
    const max_bytes = 10 * 1024 * 1024; // 10 MiB of command line arguments is a reasonable limit
    var cmd_line = try fs.cwd().readFileAlloc(allocator, resp_file_path, max_bytes);
    errdefer allocator.free(cmd_line);

    return ArgIteratorResponseFile.initTakeOwnership(allocator, cmd_line);
}

const clang_args = @import("clang_options.zig").list;

pub const ClangArgIterator = struct {
    has_next: bool,
    zig_equivalent: ZigEquivalent,
    only_arg: []const u8,
    second_arg: []const u8,
    other_args: []const []const u8,
    argv: []const []const u8,
    next_index: usize,
    root_args: ?*Args,
    arg_iterator_response_file: ArgIteratorResponseFile,
    arena: Allocator,

    pub const ZigEquivalent = enum {
        target,
        o,
        c,
        m,
        other,
        positional,
        l,
        ignore,
        driver_punt,
        pic,
        no_pic,
        pie,
        no_pie,
        lto,
        no_lto,
        unwind_tables,
        no_unwind_tables,
        nostdlib,
        nostdlib_cpp,
        shared,
        rdynamic,
        wl,
        preprocess_only,
        asm_only,
        optimize,
        debug,
        sanitize,
        linker_script,
        dry_run,
        verbose,
        for_linker,
        linker_input_z,
        lib_dir,
        mcpu,
        dep_file,
        dep_file_mm,
        framework_dir,
        framework,
        nostdlibinc,
        red_zone,
        no_red_zone,
        omit_frame_pointer,
        no_omit_frame_pointer,
        function_sections,
        no_function_sections,
        builtin,
        no_builtin,
        color_diagnostics,
        no_color_diagnostics,
        stack_check,
        no_stack_check,
        strip,
        exec_model,
        emit_llvm,
        sysroot,
        entry,
        weak_library,
        weak_framework,
        headerpad_max_install_names,
        compress_debug_sections,
    };

    const Args = struct {
        next_index: usize,
        argv: []const []const u8,
    };

    fn init(arena: Allocator, argv: []const []const u8) ClangArgIterator {
        return .{
            .next_index = 2, // `zig cc foo` this points to `foo`
            .has_next = argv.len > 2,
            .zig_equivalent = undefined,
            .only_arg = undefined,
            .second_arg = undefined,
            .other_args = undefined,
            .argv = argv,
            .root_args = null,
            .arg_iterator_response_file = undefined,
            .arena = arena,
        };
    }

    fn next(self: *ClangArgIterator) !void {
        assert(self.has_next);
        assert(self.next_index < self.argv.len);
        // In this state we know that the parameter we are looking at is a root parameter
        // rather than an argument to a parameter.
        // We adjust the len below when necessary.
        self.other_args = (self.argv.ptr + self.next_index)[0..1];
        var arg = mem.span(self.argv[self.next_index]);
        self.incrementArgIndex();

        if (mem.startsWith(u8, arg, "@")) {
            if (self.root_args != null) return error.NestedResponseFile;

            // This is a "compiler response file". We must parse the file and treat its
            // contents as command line parameters.
            const arena = self.arena;
            const resp_file_path = arg[1..];

            self.arg_iterator_response_file =
                initArgIteratorResponseFile(arena, resp_file_path) catch |err| {
                fatal("unable to read response file '{s}': {s}", .{ resp_file_path, @errorName(err) });
            };
            // NOTE: The ArgIteratorResponseFile returns tokens from next() that are slices of an
            // internal buffer. This internal buffer is arena allocated, so it is not cleaned up here.

            var resp_arg_list = std.ArrayList([]const u8).init(arena);
            defer resp_arg_list.deinit();
            {
                while (self.arg_iterator_response_file.next()) |token| {
                    try resp_arg_list.append(token);
                }

                const args = try arena.create(Args);
                errdefer arena.destroy(args);
                args.* = .{
                    .next_index = self.next_index,
                    .argv = self.argv,
                };
                self.root_args = args;
            }
            const resp_arg_slice = resp_arg_list.toOwnedSlice();
            self.next_index = 0;
            self.argv = resp_arg_slice;

            if (resp_arg_slice.len == 0) {
                self.resolveRespFileArgs();
                return;
            }

            self.has_next = true;
            self.other_args = (self.argv.ptr + self.next_index)[0..1]; // We adjust len below when necessary.
            arg = mem.span(self.argv[self.next_index]);
            self.incrementArgIndex();
        }

        if (mem.eql(u8, arg, "-") or !mem.startsWith(u8, arg, "-")) {
            self.zig_equivalent = .positional;
            self.only_arg = arg;
            return;
        }

        find_clang_arg: for (clang_args) |clang_arg| switch (clang_arg.syntax) {
            .flag => {
                const prefix_len = clang_arg.matchEql(arg);
                if (prefix_len > 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg[prefix_len..];

                    break :find_clang_arg;
                }
            },
            .joined, .comma_joined => {
                // joined example: --target=foo
                // comma_joined example: -Wl,-soname,libsoundio.so.2
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg[prefix_len..]; // This will skip over the "--target=" part.

                    break :find_clang_arg;
                }
            },
            .joined_or_separate => {
                // Examples: `-lfoo`, `-l foo`
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len == arg.len) {
                    if (self.next_index >= self.argv.len) {
                        fatal("Expected parameter after '{s}'", .{arg});
                    }
                    self.only_arg = self.argv[self.next_index];
                    self.incrementArgIndex();
                    self.other_args.len += 1;
                    self.zig_equivalent = clang_arg.zig_equivalent;

                    break :find_clang_arg;
                } else if (prefix_len != 0) {
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    self.only_arg = arg[prefix_len..];

                    break :find_clang_arg;
                }
            },
            .joined_and_separate => {
                // Example: `-Xopenmp-target=riscv64-linux-unknown foo`
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    self.only_arg = arg[prefix_len..];
                    if (self.next_index >= self.argv.len) {
                        fatal("Expected parameter after '{s}'", .{arg});
                    }
                    self.second_arg = self.argv[self.next_index];
                    self.incrementArgIndex();
                    self.other_args.len += 1;
                    self.zig_equivalent = clang_arg.zig_equivalent;
                    break :find_clang_arg;
                }
            },
            .separate => if (clang_arg.matchEql(arg) > 0) {
                if (self.next_index >= self.argv.len) {
                    fatal("Expected parameter after '{s}'", .{arg});
                }
                self.only_arg = self.argv[self.next_index];
                self.incrementArgIndex();
                self.other_args.len += 1;
                self.zig_equivalent = clang_arg.zig_equivalent;
                break :find_clang_arg;
            },
            .remaining_args_joined => {
                const prefix_len = clang_arg.matchStartsWith(arg);
                if (prefix_len != 0) {
                    @panic("TODO");
                }
            },
            .multi_arg => |num_args| if (clang_arg.matchEql(arg) > 0) {
                // Example `-sectcreate <arg1> <arg2> <arg3>`.
                var i: usize = 0;
                while (i < num_args) : (i += 1) {
                    self.incrementArgIndex();
                    self.other_args.len += 1;
                }
                self.zig_equivalent = clang_arg.zig_equivalent;
                break :find_clang_arg;
            },
        } else {
            fatal("Unknown Clang option: '{s}'", .{arg});
        }
    }

    fn incrementArgIndex(self: *ClangArgIterator) void {
        self.next_index += 1;
        self.resolveRespFileArgs();
    }

    fn resolveRespFileArgs(self: *ClangArgIterator) void {
        const arena = self.arena;
        if (self.next_index >= self.argv.len) {
            if (self.root_args) |root_args| {
                self.next_index = root_args.next_index;
                self.argv = root_args.argv;

                arena.destroy(root_args);
                self.root_args = null;
            }
            if (self.next_index >= self.argv.len) {
                self.has_next = false;
            }
        }
    }
};

fn parseCodeModel(arg: []const u8) std.builtin.CodeModel {
    return std.meta.stringToEnum(std.builtin.CodeModel, arg) orelse
        fatal("unsupported machine code model: '{s}'", .{arg});
}

/// Raise the open file descriptor limit. Ask and ye shall receive.
/// For one example of why this is handy, consider the case of building musl libc.
/// We keep a lock open for each of the object files in the form of a file descriptor
/// until they are finally put into an archive file. This is to allow a zig-cache
/// garbage collector to run concurrently to zig processes, and to allow multiple
/// zig processes to run concurrently with each other, without clobbering each other.
fn gimmeMoreOfThoseSweetSweetFileDescriptors() void {
    if (!@hasDecl(std.os.system, "rlimit")) return;
    const posix = std.os;

    var lim = posix.getrlimit(.NOFILE) catch return; // Oh well; we tried.
    if (comptime builtin.target.isDarwin()) {
        // On Darwin, `NOFILE` is bounded by a hardcoded value `OPEN_MAX`.
        // According to the man pages for setrlimit():
        //   setrlimit() now returns with errno set to EINVAL in places that historically succeeded.
        //   It no longer accepts "rlim_cur = RLIM.INFINITY" for RLIM.NOFILE.
        //   Use "rlim_cur = min(OPEN_MAX, rlim_max)".
        lim.max = std.math.min(std.os.darwin.OPEN_MAX, lim.max);
    }
    if (lim.cur == lim.max) return;

    // Do a binary search for the limit.
    var min: posix.rlim_t = lim.cur;
    var max: posix.rlim_t = 1 << 20;
    // But if there's a defined upper bound, don't search, just set it.
    if (lim.max != posix.RLIM.INFINITY) {
        min = lim.max;
        max = lim.max;
    }

    while (true) {
        lim.cur = min + @divTrunc(max - min, 2); // on freebsd rlim_t is signed
        if (posix.setrlimit(.NOFILE, lim)) |_| {
            min = lim.cur;
        } else |_| {
            max = lim.cur;
        }
        if (min + 1 >= max) break;
    }
}

test "fds" {
    gimmeMoreOfThoseSweetSweetFileDescriptors();
}

fn detectNativeTargetInfo(gpa: Allocator, cross_target: std.zig.CrossTarget) !std.zig.system.NativeTargetInfo {
    return std.zig.system.NativeTargetInfo.detect(gpa, cross_target);
}

/// Indicate that we are now terminating with a successful exit code.
/// In debug builds, this is a no-op, so that the calling code's
/// cleanup mechanisms are tested and so that external tools that
/// check for resource leaks can be accurate. In release builds, this
/// calls exit(0), and does not return.
pub fn cleanExit() void {
    if (builtin.mode == .Debug) {
        return;
    } else {
        process.exit(0);
    }
}

const usage_ast_check =
    \\Usage: zig ast-check [file]
    \\
    \\    Given a .zig source file, reports any compile errors that can be
    \\    ascertained on the basis of the source code alone, without target
    \\    information or type checking.
    \\
    \\    If [file] is omitted, stdin is used.
    \\
    \\Options:
    \\  -h, --help            Print this help and exit
    \\  --color [auto|off|on] Enable or disable colored error messages
    \\  -t                    (debug option) Output ZIR in text form to stdout
    \\
    \\
;

pub fn cmdAstCheck(
    gpa: Allocator,
    arena: Allocator,
    args: []const []const u8,
) !void {
    const Module = @import("Module.zig");
    const AstGen = @import("AstGen.zig");
    const Zir = @import("Zir.zig");

    var color: Color = .auto;
    var want_output_text = false;
    var zig_source_file: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (mem.startsWith(u8, arg, "-")) {
            if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                try io.getStdOut().writeAll(usage_ast_check);
                return cleanExit();
            } else if (mem.eql(u8, arg, "-t")) {
                want_output_text = true;
            } else if (mem.eql(u8, arg, "--color")) {
                if (i + 1 >= args.len) {
                    fatal("expected [auto|on|off] after --color", .{});
                }
                i += 1;
                const next_arg = args[i];
                color = std.meta.stringToEnum(Color, next_arg) orelse {
                    fatal("expected [auto|on|off] after --color, found '{s}'", .{next_arg});
                };
            } else {
                fatal("unrecognized parameter: '{s}'", .{arg});
            }
        } else if (zig_source_file == null) {
            zig_source_file = arg;
        } else {
            fatal("extra positional parameter: '{s}'", .{arg});
        }
    }

    var file: Module.File = .{
        .status = .never_loaded,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .sub_file_path = undefined,
        .source = undefined,
        .stat = undefined,
        .tree = undefined,
        .zir = undefined,
        .pkg = undefined,
        .root_decl = .none,
    };
    if (zig_source_file) |file_name| {
        var f = fs.cwd().openFile(file_name, .{}) catch |err| {
            fatal("unable to open file for ast-check '{s}': {s}", .{ file_name, @errorName(err) });
        };
        defer f.close();

        const stat = try f.stat();

        if (stat.size > max_src_size)
            return error.FileTooBig;

        const source = try arena.allocSentinel(u8, @intCast(usize, stat.size), 0);
        const amt = try f.readAll(source);
        if (amt != stat.size)
            return error.UnexpectedEndOfFile;

        file.sub_file_path = file_name;
        file.source = source;
        file.source_loaded = true;
        file.stat = .{
            .size = stat.size,
            .inode = stat.inode,
            .mtime = stat.mtime,
        };
    } else {
        const stdin = io.getStdIn();
        const source = readSourceFileToEndAlloc(arena, &stdin, null) catch |err| {
            fatal("unable to read stdin: {s}", .{err});
        };
        file.sub_file_path = "<stdin>";
        file.source = source;
        file.source_loaded = true;
        file.stat.size = source.len;
    }

    file.pkg = try Package.create(gpa, null, file.sub_file_path);
    defer file.pkg.destroy(gpa);

    file.tree = try std.zig.parse(gpa, file.source);
    file.tree_loaded = true;
    defer file.tree.deinit(gpa);

    try printErrsMsgToStdErr(gpa, arena, file.tree.errors, file.tree, file.sub_file_path, color);
    if (file.tree.errors.len != 0) {
        process.exit(1);
    }

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    defer file.zir.deinit(gpa);

    if (file.zir.hasCompileErrors()) {
        var errors = std.ArrayList(Compilation.AllErrors.Message).init(arena);
        try Compilation.AllErrors.addZir(arena, &errors, &file);
        const ttyconf: std.debug.TTY.Config = switch (color) {
            .auto => std.debug.detectTTYConfig(),
            .on => .escape_codes,
            .off => .no_color,
        };
        for (errors.items) |full_err_msg| {
            full_err_msg.renderToStdErr(ttyconf);
        }
        process.exit(1);
    }

    if (!want_output_text) {
        return cleanExit();
    }
    if (!debug_extensions_enabled) {
        fatal("-t option only available in debug builds of zig", .{});
    }

    {
        const token_bytes = @sizeOf(Ast.TokenList) +
            file.tree.tokens.len * (@sizeOf(std.zig.Token.Tag) + @sizeOf(Ast.ByteOffset));
        const tree_bytes = @sizeOf(Ast) + file.tree.nodes.len *
            (@sizeOf(Ast.Node.Tag) +
            @sizeOf(Ast.Node.Data) +
            @sizeOf(Ast.TokenIndex));
        const instruction_bytes = file.zir.instructions.len *
            // Here we don't use @sizeOf(Zir.Inst.Data) because it would include
            // the debug safety tag but we want to measure release size.
            (@sizeOf(Zir.Inst.Tag) + 8);
        const extra_bytes = file.zir.extra.len * @sizeOf(u32);
        const total_bytes = @sizeOf(Zir) + instruction_bytes + extra_bytes +
            file.zir.string_bytes.len * @sizeOf(u8);
        const stdout = io.getStdOut();
        const fmtIntSizeBin = std.fmt.fmtIntSizeBin;
        // zig fmt: off
        try stdout.writer().print(
            \\# Source bytes:       {}
            \\# Tokens:             {} ({})
            \\# AST Nodes:          {} ({})
            \\# Total ZIR bytes:    {}
            \\# Instructions:       {d} ({})
            \\# String Table Bytes: {}
            \\# Extra Data Items:   {d} ({})
            \\
        , .{
            fmtIntSizeBin(file.source.len),
            file.tree.tokens.len, fmtIntSizeBin(token_bytes),
            file.tree.nodes.len, fmtIntSizeBin(tree_bytes),
            fmtIntSizeBin(total_bytes),
            file.zir.instructions.len, fmtIntSizeBin(instruction_bytes),
            fmtIntSizeBin(file.zir.string_bytes.len),
            file.zir.extra.len, fmtIntSizeBin(extra_bytes),
        });
        // zig fmt: on
    }

    return @import("print_zir.zig").renderAsTextToFile(gpa, &file, io.getStdOut());
}

/// This is only enabled for debug builds.
pub fn cmdChangelist(
    gpa: Allocator,
    arena: Allocator,
    args: []const []const u8,
) !void {
    const Module = @import("Module.zig");
    const AstGen = @import("AstGen.zig");
    const Zir = @import("Zir.zig");

    const old_source_file = args[0];
    const new_source_file = args[1];

    var f = fs.cwd().openFile(old_source_file, .{}) catch |err| {
        fatal("unable to open old source file for comparison '{s}': {s}", .{ old_source_file, @errorName(err) });
    };
    defer f.close();

    const stat = try f.stat();

    if (stat.size > max_src_size)
        return error.FileTooBig;

    var file: Module.File = .{
        .status = .never_loaded,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = false,
        .sub_file_path = old_source_file,
        .source = undefined,
        .stat = .{
            .size = stat.size,
            .inode = stat.inode,
            .mtime = stat.mtime,
        },
        .tree = undefined,
        .zir = undefined,
        .pkg = undefined,
        .root_decl = .none,
    };

    file.pkg = try Package.create(gpa, null, file.sub_file_path);
    defer file.pkg.destroy(gpa);

    const source = try arena.allocSentinel(u8, @intCast(usize, stat.size), 0);
    const amt = try f.readAll(source);
    if (amt != stat.size)
        return error.UnexpectedEndOfFile;
    file.source = source;
    file.source_loaded = true;

    file.tree = try std.zig.parse(gpa, file.source);
    file.tree_loaded = true;
    defer file.tree.deinit(gpa);

    try printErrsMsgToStdErr(gpa, arena, file.tree.errors, file.tree, old_source_file, .auto);
    if (file.tree.errors.len != 0) {
        process.exit(1);
    }

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    defer file.zir.deinit(gpa);

    if (file.zir.hasCompileErrors()) {
        var errors = std.ArrayList(Compilation.AllErrors.Message).init(arena);
        try Compilation.AllErrors.addZir(arena, &errors, &file);
        const ttyconf = std.debug.detectTTYConfig();
        for (errors.items) |full_err_msg| {
            full_err_msg.renderToStdErr(ttyconf);
        }
        process.exit(1);
    }

    var new_f = fs.cwd().openFile(new_source_file, .{}) catch |err| {
        fatal("unable to open new source file for comparison '{s}': {s}", .{ new_source_file, @errorName(err) });
    };
    defer new_f.close();

    const new_stat = try new_f.stat();

    if (new_stat.size > max_src_size)
        return error.FileTooBig;

    const new_source = try arena.allocSentinel(u8, @intCast(usize, new_stat.size), 0);
    const new_amt = try new_f.readAll(new_source);
    if (new_amt != new_stat.size)
        return error.UnexpectedEndOfFile;

    var new_tree = try std.zig.parse(gpa, new_source);
    defer new_tree.deinit(gpa);

    try printErrsMsgToStdErr(gpa, arena, new_tree.errors, new_tree, new_source_file, .auto);
    if (new_tree.errors.len != 0) {
        process.exit(1);
    }

    var old_zir = file.zir;
    defer old_zir.deinit(gpa);
    file.zir_loaded = false;
    file.zir = try AstGen.generate(gpa, new_tree);
    file.zir_loaded = true;

    if (file.zir.hasCompileErrors()) {
        var errors = std.ArrayList(Compilation.AllErrors.Message).init(arena);
        try Compilation.AllErrors.addZir(arena, &errors, &file);
        const ttyconf = std.debug.detectTTYConfig();
        for (errors.items) |full_err_msg| {
            full_err_msg.renderToStdErr(ttyconf);
        }
        process.exit(1);
    }

    var inst_map: std.AutoHashMapUnmanaged(Zir.Inst.Index, Zir.Inst.Index) = .{};
    defer inst_map.deinit(gpa);

    var extra_map: std.AutoHashMapUnmanaged(u32, u32) = .{};
    defer extra_map.deinit(gpa);

    try Module.mapOldZirToNew(gpa, old_zir, file.zir, &inst_map, &extra_map);

    var bw = io.bufferedWriter(io.getStdOut().writer());
    const stdout = bw.writer();
    {
        try stdout.print("Instruction mappings:\n", .{});
        var it = inst_map.iterator();
        while (it.next()) |entry| {
            try stdout.print(" %{d} => %{d}\n", .{
                entry.key_ptr.*, entry.value_ptr.*,
            });
        }
    }
    {
        try stdout.print("Extra mappings:\n", .{});
        var it = extra_map.iterator();
        while (it.next()) |entry| {
            try stdout.print(" {d} => {d}\n", .{
                entry.key_ptr.*, entry.value_ptr.*,
            });
        }
    }
    try bw.flush();
}

fn eatIntPrefix(arg: []const u8, radix: u8) []const u8 {
    if (arg.len > 2 and arg[0] == '0') {
        switch (std.ascii.toLower(arg[1])) {
            'b' => if (radix == 2) return arg[2..],
            'o' => if (radix == 8) return arg[2..],
            'x' => if (radix == 16) return arg[2..],
            else => {},
        }
    }
    return arg;
}

fn parseIntSuffix(arg: []const u8, prefix_len: usize) u64 {
    return std.fmt.parseUnsigned(u64, arg[prefix_len..], 0) catch |err| {
        fatal("unable to parse '{s}': {s}", .{ arg, @errorName(err) });
    };
}

fn warnAboutForeignBinaries(
    gpa: Allocator,
    arena: Allocator,
    arg_mode: ArgMode,
    target_info: std.zig.system.NativeTargetInfo,
    link_libc: bool,
) !void {
    const host_cross_target: std.zig.CrossTarget = .{};
    const host_target_info = try detectNativeTargetInfo(gpa, host_cross_target);

    switch (host_target_info.getExternalExecutor(target_info, .{ .link_libc = link_libc })) {
        .native => return,
        .rosetta => {
            const host_name = try host_target_info.target.zigTriple(arena);
            const foreign_name = try target_info.target.zigTriple(arena);
            warn("the host system ({s}) does not appear to be capable of executing binaries from the target ({s}). Consider installing Rosetta.", .{
                host_name, foreign_name,
            });
        },
        .qemu => |qemu| {
            const host_name = try host_target_info.target.zigTriple(arena);
            const foreign_name = try target_info.target.zigTriple(arena);
            switch (arg_mode) {
                .zig_test => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '--test-cmd {s} --test-cmd-bin' " ++
                        "to run the tests",
                    .{ host_name, foreign_name, qemu },
                ),
                else => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '{s}' to run the binary",
                    .{ host_name, foreign_name, qemu },
                ),
            }
        },
        .wine => |wine| {
            const host_name = try host_target_info.target.zigTriple(arena);
            const foreign_name = try target_info.target.zigTriple(arena);
            switch (arg_mode) {
                .zig_test => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '--test-cmd {s} --test-cmd-bin' " ++
                        "to run the tests",
                    .{ host_name, foreign_name, wine },
                ),
                else => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '{s}' to run the binary",
                    .{ host_name, foreign_name, wine },
                ),
            }
        },
        .wasmtime => |wasmtime| {
            const host_name = try host_target_info.target.zigTriple(arena);
            const foreign_name = try target_info.target.zigTriple(arena);
            switch (arg_mode) {
                .zig_test => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '--test-cmd {s} --test-cmd-bin' " ++
                        "to run the tests",
                    .{ host_name, foreign_name, wasmtime },
                ),
                else => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '{s}' to run the binary",
                    .{ host_name, foreign_name, wasmtime },
                ),
            }
        },
        .darling => |darling| {
            const host_name = try host_target_info.target.zigTriple(arena);
            const foreign_name = try target_info.target.zigTriple(arena);
            switch (arg_mode) {
                .zig_test => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '--test-cmd {s} --test-cmd-bin' " ++
                        "to run the tests",
                    .{ host_name, foreign_name, darling },
                ),
                else => warn(
                    "the host system ({s}) does not appear to be capable of executing binaries " ++
                        "from the target ({s}). Consider using '{s}' to run the binary",
                    .{ host_name, foreign_name, darling },
                ),
            }
        },
        .bad_dl => |foreign_dl| {
            const host_dl = host_target_info.dynamic_linker.get() orelse "(none)";
            const tip_suffix = switch (arg_mode) {
                .zig_test => ", '--test-no-exec', or '--test-cmd'",
                else => "",
            };
            warn("the host system does not appear to be capable of executing binaries from the target because the host dynamic linker is '{s}', while the target dynamic linker is '{s}'. Consider using '--dynamic-linker'{s}", .{
                host_dl, foreign_dl, tip_suffix,
            });
        },
        .bad_os_or_cpu => {
            const host_name = try host_target_info.target.zigTriple(arena);
            const foreign_name = try target_info.target.zigTriple(arena);
            const tip_suffix = switch (arg_mode) {
                .zig_test => ". Consider using '--test-no-exec' or '--test-cmd'",
                else => "",
            };
            warn("the host system ({s}) does not appear to be capable of executing binaries from the target ({s}){s}", .{
                host_name, foreign_name, tip_suffix,
            });
        },
    }
}

fn parseSubSystem(next_arg: []const u8) !std.Target.SubSystem {
    if (mem.eql(u8, next_arg, "console")) {
        return .Console;
    } else if (mem.eql(u8, next_arg, "windows")) {
        return .Windows;
    } else if (mem.eql(u8, next_arg, "posix")) {
        return .Posix;
    } else if (mem.eql(u8, next_arg, "native")) {
        return .Native;
    } else if (mem.eql(u8, next_arg, "efi_application")) {
        return .EfiApplication;
    } else if (mem.eql(u8, next_arg, "efi_boot_service_driver")) {
        return .EfiBootServiceDriver;
    } else if (mem.eql(u8, next_arg, "efi_rom")) {
        return .EfiRom;
    } else if (mem.eql(u8, next_arg, "efi_runtime_driver")) {
        return .EfiRuntimeDriver;
    } else {
        fatal("invalid: --subsystem: '{s}'. Options are:\n{s}", .{
            next_arg,
            \\  console
            \\  windows
            \\  posix
            \\  native
            \\  efi_application
            \\  efi_boot_service_driver
            \\  efi_rom
            \\  efi_runtime_driver
            \\
        });
    }
}
