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
const ThreadPool = std.Thread.Pool;
const cleanExit = std.process.cleanExit;

const tracy = @import("tracy.zig");
const Compilation = @import("Compilation.zig");
const link = @import("link.zig");
const Package = @import("Package.zig");
const build_options = @import("build_options");
const introspect = @import("introspect.zig");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const wasi_libc = @import("wasi_libc.zig");
const translate_c = @import("translate_c.zig");
const clang = @import("clang.zig");
const BuildId = std.Build.CompileStep.BuildId;
const Cache = std.Build.Cache;
const target_util = @import("target.zig");
const crash_report = @import("crash_report.zig");
const Module = @import("Module.zig");
const AstGen = @import("AstGen.zig");
const Server = std.zig.Server;

pub const std_options = struct {
    pub const wasiCwd = wasi_cwd;
    pub const logFn = log;
    pub const enable_segfault_handler = false;

    pub const log_level: std.log.Level = switch (builtin.mode) {
        .Debug => .debug,
        .ReleaseSafe, .ReleaseFast => .info,
        .ReleaseSmall => .err,
    };
};

// Crash report needs to override the panic handler
pub const panic = crash_report.panic;

var wasi_preopens: fs.wasi.Preopens = undefined;
pub fn wasi_cwd() fs.Dir {
    // Expect the first preopen to be current working directory.
    const cwd_fd: std.os.fd_t = 3;
    assert(mem.eql(u8, wasi_preopens.names[cwd_fd], "."));
    return .{ .fd = cwd_fd };
}

pub fn getWasiPreopen(name: []const u8) Compilation.Directory {
    return .{
        .path = name,
        .handle = .{
            .fd = wasi_preopens.find(name) orelse fatal("WASI preopen not found: '{s}'", .{name}),
        },
    };
}

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
    \\  objcopy          Use Zig as a drop-in objcopy
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
    \\  dump-zir         Dump a file containing cached ZIR
    \\
;

const usage = if (debug_extensions_enabled) debug_usage else normal_usage;

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
    if (@enumToInt(level) > @enumToInt(std.options.log_level) or
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

    const use_gpa = (build_options.force_gpa or !builtin.link_libc) and builtin.os.tag != .wasi;
    const gpa = gpa: {
        if (builtin.os.tag == .wasi) {
            break :gpa std.heap.wasm_allocator;
        }
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

    if (builtin.os.tag == .wasi) {
        wasi_preopens = try fs.wasi.preopensAlloc(arena);
    }

    // Short circuit some of the other logic for bootstrapping.
    if (build_options.only_c) {
        if (mem.eql(u8, args[1], "build-exe")) {
            return buildOutputType(gpa, arena, args, .{ .build = .Exe });
        } else if (mem.eql(u8, args[1], "build-obj")) {
            return buildOutputType(gpa, arena, args, .{ .build = .Obj });
        } else {
            @panic("only build-exe or build-obj is supported in a -Donly-c build");
        }
    }

    return mainArgs(gpa, arena, args);
}

/// Check that LLVM and Clang have been linked properly so that they are using the same
/// libc++ and can safely share objects with pointers to static variables in libc++
fn verifyLibcxxCorrectlyLinked() void {
    if (build_options.have_llvm and ZigClangIsLLVMUsingSeparateLibcxx()) {
        fatal(
            \\Zig was built/linked incorrectly: LLVM and Clang have separate copies of libc++
            \\       If you are dynamically linking LLVM, make sure you dynamically link libc++ too
        , .{});
    }
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
    } else if (mem.eql(u8, cmd, "objcopy")) {
        return @import("objcopy.zig").cmdObjCopy(gpa, arena, cmd_args);
    } else if (mem.eql(u8, cmd, "libc")) {
        return cmdLibC(gpa, cmd_args);
    } else if (mem.eql(u8, cmd, "init-exe")) {
        return cmdInit(gpa, arena, cmd_args, .Exe);
    } else if (mem.eql(u8, cmd, "init-lib")) {
        return cmdInit(gpa, arena, cmd_args, .Lib);
    } else if (mem.eql(u8, cmd, "targets")) {
        const info = try detectNativeTargetInfo(.{});
        const stdout = io.getStdOut().writer();
        return @import("print_targets.zig").cmdTargets(arena, cmd_args, stdout, info.target);
    } else if (mem.eql(u8, cmd, "version")) {
        try std.io.getStdOut().writeAll(build_options.version ++ "\n");
        // Check libc++ linkage to make sure Zig was built correctly, but only for "env" and "version"
        // to avoid affecting the startup time for build-critical commands (check takes about ~10 μs)
        return verifyLibcxxCorrectlyLinked();
    } else if (mem.eql(u8, cmd, "env")) {
        verifyLibcxxCorrectlyLinked();
        return @import("print_env.zig").cmdEnv(arena, cmd_args, io.getStdOut().writer());
    } else if (mem.eql(u8, cmd, "zen")) {
        return io.getStdOut().writeAll(info_zen);
    } else if (mem.eql(u8, cmd, "help") or mem.eql(u8, cmd, "-h") or mem.eql(u8, cmd, "--help")) {
        return io.getStdOut().writeAll(usage);
    } else if (mem.eql(u8, cmd, "ast-check")) {
        return cmdAstCheck(gpa, arena, cmd_args);
    } else if (debug_extensions_enabled and mem.eql(u8, cmd, "changelist")) {
        return cmdChangelist(gpa, arena, cmd_args);
    } else if (debug_extensions_enabled and mem.eql(u8, cmd, "dump-zir")) {
        return cmdDumpZir(gpa, arena, cmd_args);
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
    \\  --color [auto|off|on]     Enable or disable colored error messages
    \\  -femit-bin[=path]         (default) Output machine code
    \\  -fno-emit-bin             Do not output machine code
    \\  -femit-asm[=path]         Output .s (assembly code)
    \\  -fno-emit-asm             (default) Do not output .s (assembly code)
    \\  -femit-llvm-ir[=path]     Produce a .ll file with optimized LLVM IR (requires LLVM extensions)
    \\  -fno-emit-llvm-ir         (default) Do not produce a .ll file with optimized LLVM IR
    \\  -femit-llvm-bc[=path]     Produce an optimized LLVM module as a .bc file (requires LLVM extensions)
    \\  -fno-emit-llvm-bc         (default) Do not produce an optimized LLVM module as a .bc file
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
    \\
    \\Compile Options:
    \\  -target [name]            <arch><sub>-<os>-<abi> see the targets command
    \\  -mcpu [cpu]               Specify target CPU and feature set
    \\  -mcmodel=[default|tiny|   Limit range of code and data virtual addresses
    \\            small|kernel|
    \\            medium|large]
    \\  -x language               Treat subsequent input files as having type <language>
    \\  -mred-zone                Force-enable the "red-zone"
    \\  -mno-red-zone             Force-disable the "red-zone"
    \\  -fomit-frame-pointer      Omit the stack frame pointer
    \\  -fno-omit-frame-pointer   Store the stack frame pointer
    \\  -mexec-model=[value]      (WASI) Execution model
    \\  --name [name]             Override root name (not a file path)
    \\  -O [mode]                 Choose what to optimize for
    \\    Debug                   (default) Optimizations off, safety on
    \\    ReleaseFast             Optimize for performance, safety off
    \\    ReleaseSafe             Optimize for performance, safety on
    \\    ReleaseSmall            Optimize for small binary, safety off
    \\  --mod [name]:[deps]:[src] Make a module available for dependency under the given name
    \\      deps: [dep],[dep],...
    \\      dep:  [[import=]name]
    \\  --deps [dep],[dep],...    Set dependency names for the root package
    \\      dep:  [[import=]name]
    \\  --main-pkg-path           Set the directory of the root package
    \\  -fPIC                     Force-enable Position Independent Code
    \\  -fno-PIC                  Force-disable Position Independent Code
    \\  -fPIE                     Force-enable Position Independent Executable
    \\  -fno-PIE                  Force-disable Position Independent Executable
    \\  -flto                     Force-enable Link Time Optimization (requires LLVM extensions)
    \\  -fno-lto                  Force-disable Link Time Optimization
    \\  -fstack-check             Enable stack probing in unsafe builds
    \\  -fno-stack-check          Disable stack probing in safe builds
    \\  -fstack-protector         Enable stack protection in unsafe builds
    \\  -fno-stack-protector      Disable stack protection in safe builds
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
    \\  -freference-trace[=num]   How many lines of reference trace should be shown per compile error
    \\  -fno-reference-trace      Disable reference trace
    \\  -ferror-tracing           Enable error tracing in ReleaseFast mode
    \\  -fno-error-tracing        Disable error tracing in Debug and ReleaseSafe mode
    \\  -fsingle-threaded         Code assumes there is only one thread
    \\  -fno-single-threaded      Code may not assume there is only one thread
    \\  -fbuiltin                 Enable implicit builtin knowledge of functions
    \\  -fno-builtin              Disable implicit builtin knowledge of functions
    \\  -ffunction-sections       Places each function in a separate section
    \\  -fno-function-sections    All functions go into same section
    \\  -fstrip                   Omit debug symbols
    \\  -fno-strip                Keep debug symbols
    \\  -fformatted-panics        Enable formatted safety panics
    \\  -fno-formatted-panics     Disable formatted safety panics
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
    \\  -idirafter [dir]          Add directory to AFTER include search path
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
    \\  --force_undefined [name]       Specify the symbol must be defined for the link to succeed
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
    \\  --build-id[=style]             At a minor link-time expense, coordinates stripped binaries
    \\      fast, uuid, sha1, md5      with debug symbols via a '.note.gnu.build-id' section
    \\      0x[hexstring]              Maximum 32 bytes
    \\      none                       (default) Disable build-id
    \\  --eh-frame-hdr                 Enable C++ exception handling by passing --eh-frame-hdr to linker
    \\  --emit-relocs                  Enable output of relocation sections for post build tools
    \\  -z [arg]                       Set linker extension flags
    \\    nodelete                     Indicate that the object cannot be deleted from a process
    \\    notext                       Permit read-only relocations in read-only segments
    \\    defs                         Force a fatal error if any undefined symbols remain
    \\    undefs                       Reverse of -z defs
    \\    origin                       Indicate that the object must have its origin processed
    \\    nocopyreloc                  Disable the creation of copy relocations
    \\    now                          (default) Force all relocations to be processed on load
    \\    lazy                         Don't force all relocations to be processed on load
    \\    relro                        (default) Force all relocations to be read-only after processing
    \\    norelro                      Don't force all relocations to be read-only after processing
    \\    common-page-size=[bytes]     Set the common page size for ELF binaries
    \\    max-page-size=[bytes]        Set the max page size for ELF binaries
    \\  -dynamic                       Force output to be dynamically linked
    \\  -static                        Force output to be statically linked
    \\  -Bsymbolic                     Bind global references locally
    \\  --compress-debug-sections=[e]  Debug section compression settings
    \\      none                       No compression
    \\      zlib                       Compression with deflate/inflate
    \\  --gc-sections                  Force removal of functions and data that are unreachable by the entry point or exported symbols
    \\  --no-gc-sections               Don't force removal of unreachable functions and data
    \\  --sort-section=[value]         Sort wildcard section patterns by 'name' or 'alignment'
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
    \\  -dead_strip                    (Darwin) remove functions and data that are unreachable by the entry point or exported symbols
    \\  -dead_strip_dylibs             (Darwin) remove dylibs that are unreachable by the entry point or exported symbols
    \\  --import-memory                (WebAssembly) import memory from the environment
    \\  --import-symbols               (WebAssembly) import missing symbols from the host environment
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
    \\  --test-runner [path]           Specify a custom test runner
    \\
    \\Debug Options (Zig Compiler Development):
    \\  -fopt-bisect-limit=[limit]   Only run [limit] first LLVM optimization passes
    \\  -ftime-report                Print timing diagnostics
    \\  -fstack-report               Print stack size diagnostics
    \\  --verbose-link               Display linker invocations
    \\  --verbose-cc                 Display C compiler invocations
    \\  --verbose-air                Enable compiler debug output for Zig AIR
    \\  --verbose-llvm-ir[=path]     Enable compiler debug output for unoptimized LLVM IR
    \\  --verbose-llvm-bc=[path]     Enable compiler debug output for unoptimized LLVM BC
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
    // Env vars aren't used in the bootstrap stage.
    if (build_options.only_c) {
        return null;
    }
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

/// Avoid dragging networking into zig2.c because it adds dependencies on some
/// linker symbols that are annoying to satisfy while bootstrapping.
const Ip4Address = if (build_options.omit_pkg_fetching_code) void else std.net.Ip4Address;

const Listen = union(enum) {
    none,
    ip4: Ip4Address,
    stdio,
};

const ArgsIterator = struct {
    resp_file: ?ArgIteratorResponseFile = null,
    args: []const []const u8,
    i: usize = 0,
    fn next(it: *@This()) ?[]const u8 {
        if (it.i >= it.args.len) {
            if (it.resp_file) |*resp| return resp.next();
            return null;
        }
        defer it.i += 1;
        return it.args[it.i];
    }
    fn nextOrFatal(it: *@This()) []const u8 {
        if (it.i >= it.args.len) {
            if (it.resp_file) |*resp| if (resp.next()) |ret| return ret;
            fatal("expected parameter after {s}", .{it.args[it.i - 1]});
        }
        defer it.i += 1;
        return it.args[it.i];
    }
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
    var strip: ?bool = null;
    var formatted_panics: ?bool = null;
    var function_sections = false;
    var no_builtin = false;
    var listen: Listen = .none;
    var debug_compile_errors = false;
    var verbose_link = (builtin.os.tag != .wasi or builtin.link_libc) and std.process.hasEnvVarConstant("ZIG_VERBOSE_LINK");
    var verbose_cc = (builtin.os.tag != .wasi or builtin.link_libc) and std.process.hasEnvVarConstant("ZIG_VERBOSE_CC");
    var verbose_air = false;
    var verbose_llvm_ir: ?[]const u8 = null;
    var verbose_llvm_bc: ?[]const u8 = null;
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
    var want_pic: ?bool = null;
    var want_pie: ?bool = null;
    var want_lto: ?bool = null;
    var want_unwind_tables: ?bool = null;
    var want_sanitize_c: ?bool = null;
    var want_stack_check: ?bool = null;
    var want_stack_protector: ?u32 = null;
    var want_red_zone: ?bool = null;
    var omit_frame_pointer: ?bool = null;
    var want_valgrind: ?bool = null;
    var want_tsan: ?bool = null;
    var want_compiler_rt: ?bool = null;
    var rdynamic: bool = false;
    var linker_script: ?[]const u8 = null;
    var version_script: ?[]const u8 = null;
    var disable_c_depfile = false;
    var linker_sort_section: ?link.SortSection = null;
    var linker_gc_sections: ?bool = null;
    var linker_compress_debug_sections: ?link.CompressDebugSections = null;
    var linker_allow_shlib_undefined: ?bool = null;
    var linker_bind_global_refs_locally: ?bool = null;
    var linker_import_memory: ?bool = null;
    var linker_import_symbols: bool = false;
    var linker_import_table: bool = false;
    var linker_export_table: bool = false;
    var linker_initial_memory: ?u64 = null;
    var linker_max_memory: ?u64 = null;
    var linker_shared_memory: bool = false;
    var linker_global_base: ?u64 = null;
    var linker_print_gc_sections: bool = false;
    var linker_print_icf_sections: bool = false;
    var linker_print_map: bool = false;
    var linker_opt_bisect_limit: i32 = -1;
    var linker_z_nocopyreloc = false;
    var linker_z_nodelete = false;
    var linker_z_notext = false;
    var linker_z_defs = false;
    var linker_z_origin = false;
    var linker_z_now = true;
    var linker_z_relro = true;
    var linker_z_common_page_size: ?u64 = null;
    var linker_z_max_page_size: ?u64 = null;
    var linker_tsaware = false;
    var linker_nxcompat = false;
    var linker_dynamicbase = true;
    var linker_optimization: ?u8 = null;
    var linker_module_definition_file: ?[]const u8 = null;
    var test_evented_io = false;
    var test_no_exec = false;
    var entry: ?[]const u8 = null;
    var force_undefined_symbols: std.StringArrayHashMapUnmanaged(void) = .{};
    var stack_size_override: ?u64 = null;
    var image_base_override: ?u64 = null;
    var use_llvm: ?bool = null;
    var use_lld: ?bool = null;
    var use_clang: ?bool = null;
    var link_eh_frame_hdr = false;
    var link_emit_relocs = false;
    var each_lib_rpath: ?bool = null;
    var build_id: ?BuildId = null;
    var sysroot: ?[]const u8 = null;
    var libc_paths_file: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LIBC");
    var machine_code_model: std.builtin.CodeModel = .default;
    var runtime_args_start: ?usize = null;
    var test_filter: ?[]const u8 = null;
    var test_name_prefix: ?[]const u8 = null;
    var test_runner_path: ?[]const u8 = null;
    var override_local_cache_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LOCAL_CACHE_DIR");
    var override_global_cache_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_GLOBAL_CACHE_DIR");
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
    var reference_trace: ?u32 = null;
    var error_tracing: ?bool = null;
    var pdb_out_path: ?[]const u8 = null;
    var dwarf_format: ?std.dwarf.Format = null;

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

    var symbol_wrap_set: std.StringArrayHashMapUnmanaged(void) = .{};

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

    // Contains every module specified via --mod. The dependencies are added
    // after argument parsing is completed. We use a StringArrayHashMap to make
    // error output consistent.
    var modules = std.StringArrayHashMap(struct {
        mod: *Package,
        deps_str: []const u8, // still in CLI arg format
    }).init(gpa);
    defer {
        var it = modules.iterator();
        while (it.next()) |kv| kv.value_ptr.mod.destroy(gpa);
        modules.deinit();
    }

    // The dependency string for the root package
    var root_deps_str: ?[]const u8 = null;

    // before arg parsing, check for the NO_COLOR environment variable
    // if it exists, default the color setting to .off
    // explicit --color arguments will still override this setting.
    // Disable color on WASI per https://github.com/WebAssembly/WASI/issues/162
    color = if (builtin.os.tag == .wasi or std.process.hasEnvVarConstant("NO_COLOR")) .off else .auto;

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

            var args_iter = ArgsIterator{
                .args = all_args[2..],
            };

            var cssan = ClangSearchSanitizer.init(gpa, &clang_argv);
            defer cssan.map.deinit();

            var file_ext: ?Compilation.FileExt = null;
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
                    } else if (mem.eql(u8, arg, "--mod")) {
                        const info = args_iter.nextOrFatal();
                        var info_it = mem.split(u8, info, ":");
                        const mod_name = info_it.next() orelse fatal("expected non-empty argument after {s}", .{arg});
                        const deps_str = info_it.next() orelse fatal("expected 'name:deps:path' after {s}", .{arg});
                        const root_src_orig = info_it.rest();
                        if (root_src_orig.len == 0) fatal("expected 'name:deps:path' after {s}", .{arg});
                        if (mod_name.len == 0) fatal("empty name for module at '{s}'", .{root_src_orig});

                        const root_src = try introspect.resolvePath(arena, root_src_orig);

                        for ([_][]const u8{ "std", "root", "builtin" }) |name| {
                            if (mem.eql(u8, mod_name, name)) {
                                fatal("unable to add module '{s}' -> '{s}': conflicts with builtin module", .{ mod_name, root_src });
                            }
                        }

                        var mod_it = modules.iterator();
                        while (mod_it.next()) |kv| {
                            if (std.mem.eql(u8, mod_name, kv.key_ptr.*)) {
                                fatal("unable to add module '{s}' -> '{s}': already exists as '{s}'", .{ mod_name, root_src, kv.value_ptr.mod.root_src_path });
                            }
                        }

                        try modules.ensureUnusedCapacity(1);
                        modules.put(mod_name, .{
                            .mod = try Package.create(
                                gpa,
                                fs.path.dirname(root_src),
                                fs.path.basename(root_src),
                            ),
                            .deps_str = deps_str,
                        }) catch unreachable;
                    } else if (mem.eql(u8, arg, "--deps")) {
                        if (root_deps_str != null) {
                            fatal("only one --deps argument is allowed", .{});
                        }
                        root_deps_str = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--main-pkg-path")) {
                        main_pkg_path = args_iter.nextOrFatal();
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
                        subsystem = try parseSubSystem(args_iter.nextOrFatal());
                    } else if (mem.eql(u8, arg, "-O")) {
                        optimize_mode_string = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--entry")) {
                        entry = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--force_undefined")) {
                        try force_undefined_symbols.put(gpa, args_iter.nextOrFatal(), {});
                    } else if (mem.eql(u8, arg, "--stack")) {
                        const next_arg = args_iter.nextOrFatal();
                        stack_size_override = std.fmt.parseUnsigned(u64, next_arg, 0) catch |err| {
                            fatal("unable to parse stack size '{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "--image-base")) {
                        const next_arg = args_iter.nextOrFatal();
                        image_base_override = std.fmt.parseUnsigned(u64, next_arg, 0) catch |err| {
                            fatal("unable to parse image base override '{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "--name")) {
                        provided_name = args_iter.nextOrFatal();
                        if (!mem.eql(u8, provided_name.?, fs.path.basename(provided_name.?)))
                            fatal("invalid package name '{s}': cannot contain folder separators", .{provided_name.?});
                    } else if (mem.eql(u8, arg, "-rpath")) {
                        try rpath_list.append(args_iter.nextOrFatal());
                    } else if (mem.eql(u8, arg, "--library-directory") or mem.eql(u8, arg, "-L")) {
                        try lib_dirs.append(args_iter.nextOrFatal());
                    } else if (mem.eql(u8, arg, "-F")) {
                        try framework_dirs.append(args_iter.nextOrFatal());
                    } else if (mem.eql(u8, arg, "-framework")) {
                        try frameworks.put(gpa, args_iter.nextOrFatal(), .{});
                    } else if (mem.eql(u8, arg, "-weak_framework")) {
                        try frameworks.put(gpa, args_iter.nextOrFatal(), .{ .weak = true });
                    } else if (mem.eql(u8, arg, "-needed_framework")) {
                        try frameworks.put(gpa, args_iter.nextOrFatal(), .{ .needed = true });
                    } else if (mem.eql(u8, arg, "-install_name")) {
                        install_name = args_iter.nextOrFatal();
                    } else if (mem.startsWith(u8, arg, "--compress-debug-sections=")) {
                        const param = arg["--compress-debug-sections=".len..];
                        linker_compress_debug_sections = std.meta.stringToEnum(link.CompressDebugSections, param) orelse {
                            fatal("expected --compress-debug-sections=[none|zlib], found '{s}'", .{param});
                        };
                    } else if (mem.eql(u8, arg, "--compress-debug-sections")) {
                        linker_compress_debug_sections = link.CompressDebugSections.zlib;
                    } else if (mem.eql(u8, arg, "-pagezero_size")) {
                        const next_arg = args_iter.nextOrFatal();
                        pagezero_size = std.fmt.parseUnsigned(u64, eatIntPrefix(next_arg, 16), 16) catch |err| {
                            fatal("unable to parse pagezero size'{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "-search_paths_first")) {
                        search_strategy = .paths_first;
                    } else if (mem.eql(u8, arg, "-search_dylibs_first")) {
                        search_strategy = .dylibs_first;
                    } else if (mem.eql(u8, arg, "-headerpad")) {
                        const next_arg = args_iter.nextOrFatal();
                        headerpad_size = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                            fatal("unable to parse headerpat size '{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "-headerpad_max_install_names")) {
                        headerpad_max_install_names = true;
                    } else if (mem.eql(u8, arg, "-dead_strip")) {
                        linker_gc_sections = true;
                    } else if (mem.eql(u8, arg, "-dead_strip_dylibs")) {
                        dead_strip_dylibs = true;
                    } else if (mem.eql(u8, arg, "-T") or mem.eql(u8, arg, "--script")) {
                        linker_script = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--version-script")) {
                        version_script = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--library") or mem.eql(u8, arg, "-l")) {
                        // We don't know whether this library is part of libc or libc++ until
                        // we resolve the target, so we simply append to the list for now.
                        try system_libs.put(args_iter.nextOrFatal(), .{});
                    } else if (mem.eql(u8, arg, "--needed-library") or
                        mem.eql(u8, arg, "-needed-l") or
                        mem.eql(u8, arg, "-needed_library"))
                    {
                        const next_arg = args_iter.nextOrFatal();
                        try system_libs.put(next_arg, .{ .needed = true });
                    } else if (mem.eql(u8, arg, "-weak_library") or mem.eql(u8, arg, "-weak-l")) {
                        try system_libs.put(args_iter.nextOrFatal(), .{ .weak = true });
                    } else if (mem.eql(u8, arg, "-D")) {
                        try clang_argv.append(arg);
                        try clang_argv.append(args_iter.nextOrFatal());
                    } else if (mem.eql(u8, arg, "-I")) {
                        try cssan.addIncludePath(.I, arg, args_iter.nextOrFatal(), false);
                    } else if (mem.eql(u8, arg, "-isystem") or mem.eql(u8, arg, "-iwithsysroot")) {
                        try cssan.addIncludePath(.isystem, arg, args_iter.nextOrFatal(), false);
                    } else if (mem.eql(u8, arg, "-idirafter")) {
                        try cssan.addIncludePath(.idirafter, arg, args_iter.nextOrFatal(), false);
                    } else if (mem.eql(u8, arg, "-iframework") or mem.eql(u8, arg, "-iframeworkwithsysroot")) {
                        try cssan.addIncludePath(.iframework, arg, args_iter.nextOrFatal(), false);
                    } else if (mem.eql(u8, arg, "--version")) {
                        const next_arg = args_iter.nextOrFatal();
                        version = std.builtin.Version.parse(next_arg) catch |err| {
                            fatal("unable to parse --version '{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                        have_version = true;
                    } else if (mem.eql(u8, arg, "-target")) {
                        target_arch_os_abi = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "-mcpu")) {
                        target_mcpu = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "-mcmodel")) {
                        machine_code_model = parseCodeModel(args_iter.nextOrFatal());
                    } else if (mem.startsWith(u8, arg, "-ofmt=")) {
                        target_ofmt = arg["-ofmt=".len..];
                    } else if (mem.startsWith(u8, arg, "-mcpu=")) {
                        target_mcpu = arg["-mcpu=".len..];
                    } else if (mem.startsWith(u8, arg, "-mcmodel=")) {
                        machine_code_model = parseCodeModel(arg["-mcmodel=".len..]);
                    } else if (mem.startsWith(u8, arg, "-O")) {
                        optimize_mode_string = arg["-O".len..];
                    } else if (mem.eql(u8, arg, "--dynamic-linker")) {
                        target_dynamic_linker = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--sysroot")) {
                        sysroot = args_iter.nextOrFatal();
                        try clang_argv.append("-isysroot");
                        try clang_argv.append(sysroot.?);
                    } else if (mem.eql(u8, arg, "--libc")) {
                        libc_paths_file = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--test-filter")) {
                        test_filter = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--test-name-prefix")) {
                        test_name_prefix = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--test-runner")) {
                        test_runner_path = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--test-cmd")) {
                        try test_exec_args.append(args_iter.nextOrFatal());
                    } else if (mem.eql(u8, arg, "--cache-dir")) {
                        override_local_cache_dir = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--global-cache-dir")) {
                        override_global_cache_dir = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--zig-lib-dir")) {
                        override_lib_dir = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "--debug-log")) {
                        if (!build_options.enable_logging) {
                            std.log.warn("Zig was compiled without logging enabled (-Dlog). --debug-log has no effect.", .{});
                            _ = args_iter.nextOrFatal();
                        } else {
                            try log_scopes.append(gpa, args_iter.nextOrFatal());
                        }
                    } else if (mem.eql(u8, arg, "--listen")) {
                        const next_arg = args_iter.nextOrFatal();
                        if (mem.eql(u8, next_arg, "-")) {
                            listen = .stdio;
                        } else {
                            if (build_options.omit_pkg_fetching_code) unreachable;
                            // example: --listen 127.0.0.1:9000
                            var it = std.mem.split(u8, next_arg, ":");
                            const host = it.next().?;
                            const port_text = it.next() orelse "14735";
                            const port = std.fmt.parseInt(u16, port_text, 10) catch |err|
                                fatal("invalid port number: '{s}': {s}", .{ port_text, @errorName(err) });
                            listen = .{ .ip4 = std.net.Ip4Address.parse(host, port) catch |err|
                                fatal("invalid host: '{s}': {s}", .{ host, @errorName(err) }) };
                        }
                    } else if (mem.eql(u8, arg, "--listen=-")) {
                        listen = .stdio;
                    } else if (mem.eql(u8, arg, "--debug-link-snapshot")) {
                        if (!build_options.enable_link_snapshots) {
                            std.log.warn("Zig was compiled without linker snapshots enabled (-Dlink-snapshot). --debug-link-snapshot has no effect.", .{});
                        } else {
                            enable_link_snapshots = true;
                        }
                    } else if (mem.eql(u8, arg, "--entitlements")) {
                        entitlements = args_iter.nextOrFatal();
                    } else if (mem.eql(u8, arg, "-fcompiler-rt")) {
                        want_compiler_rt = true;
                    } else if (mem.eql(u8, arg, "-fno-compiler-rt")) {
                        want_compiler_rt = false;
                    } else if (mem.eql(u8, arg, "-feach-lib-rpath")) {
                        each_lib_rpath = true;
                    } else if (mem.eql(u8, arg, "-fno-each-lib-rpath")) {
                        each_lib_rpath = false;
                    } else if (mem.eql(u8, arg, "--test-cmd-bin")) {
                        try test_exec_args.append(null);
                    } else if (mem.eql(u8, arg, "--test-evented-io")) {
                        test_evented_io = true;
                    } else if (mem.eql(u8, arg, "--test-no-exec")) {
                        test_no_exec = true;
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
                    } else if (mem.eql(u8, arg, "-fstack-protector")) {
                        want_stack_protector = Compilation.default_stack_protector_buffer_size;
                    } else if (mem.eql(u8, arg, "-fno-stack-protector")) {
                        want_stack_protector = 0;
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
                    } else if (mem.eql(u8, arg, "-freference-trace")) {
                        reference_trace = 256;
                    } else if (mem.startsWith(u8, arg, "-freference-trace=")) {
                        const num = arg["-freference-trace=".len..];
                        reference_trace = std.fmt.parseUnsigned(u32, num, 10) catch |err| {
                            fatal("unable to parse reference_trace count '{s}': {s}", .{ num, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "-fno-reference-trace")) {
                        reference_trace = null;
                    } else if (mem.eql(u8, arg, "-ferror-tracing")) {
                        error_tracing = true;
                    } else if (mem.eql(u8, arg, "-fno-error-tracing")) {
                        error_tracing = false;
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
                    } else if (mem.eql(u8, arg, "-fstrip")) {
                        strip = true;
                    } else if (mem.eql(u8, arg, "-fno-strip")) {
                        strip = false;
                    } else if (mem.eql(u8, arg, "-gdwarf32")) {
                        dwarf_format = .@"32";
                    } else if (mem.eql(u8, arg, "-gdwarf64")) {
                        dwarf_format = .@"64";
                    } else if (mem.eql(u8, arg, "-fformatted-panics")) {
                        formatted_panics = true;
                    } else if (mem.eql(u8, arg, "-fno-formatted-panics")) {
                        formatted_panics = false;
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
                    } else if (mem.startsWith(u8, arg, "-fopt-bisect-limit=")) {
                        linker_opt_bisect_limit = std.math.lossyCast(i32, parseIntSuffix(arg, "-fopt-bisect-limit=".len));
                    } else if (mem.eql(u8, arg, "--eh-frame-hdr")) {
                        link_eh_frame_hdr = true;
                    } else if (mem.eql(u8, arg, "--dynamicbase")) {
                        linker_dynamicbase = true;
                    } else if (mem.eql(u8, arg, "--no-dynamicbase")) {
                        linker_dynamicbase = false;
                    } else if (mem.eql(u8, arg, "--emit-relocs")) {
                        link_emit_relocs = true;
                    } else if (mem.eql(u8, arg, "-fallow-shlib-undefined")) {
                        linker_allow_shlib_undefined = true;
                    } else if (mem.eql(u8, arg, "-fno-allow-shlib-undefined")) {
                        linker_allow_shlib_undefined = false;
                    } else if (mem.eql(u8, arg, "-z")) {
                        const z_arg = args_iter.nextOrFatal();
                        if (mem.eql(u8, z_arg, "nodelete")) {
                            linker_z_nodelete = true;
                        } else if (mem.eql(u8, z_arg, "notext")) {
                            linker_z_notext = true;
                        } else if (mem.eql(u8, z_arg, "defs")) {
                            linker_z_defs = true;
                        } else if (mem.eql(u8, z_arg, "undefs")) {
                            linker_z_defs = false;
                        } else if (mem.eql(u8, z_arg, "origin")) {
                            linker_z_origin = true;
                        } else if (mem.eql(u8, z_arg, "nocopyreloc")) {
                            linker_z_nocopyreloc = true;
                        } else if (mem.eql(u8, z_arg, "now")) {
                            linker_z_now = true;
                        } else if (mem.eql(u8, z_arg, "lazy")) {
                            linker_z_now = false;
                        } else if (mem.eql(u8, z_arg, "relro")) {
                            linker_z_relro = true;
                        } else if (mem.eql(u8, z_arg, "norelro")) {
                            linker_z_relro = false;
                        } else if (mem.startsWith(u8, z_arg, "common-page-size=")) {
                            linker_z_common_page_size = parseIntSuffix(z_arg, "common-page-size=".len);
                        } else if (mem.startsWith(u8, z_arg, "max-page-size=")) {
                            linker_z_max_page_size = parseIntSuffix(z_arg, "max-page-size=".len);
                        } else {
                            fatal("unsupported linker extension flag: -z {s}", .{z_arg});
                        }
                    } else if (mem.eql(u8, arg, "--import-memory")) {
                        linker_import_memory = true;
                    } else if (mem.eql(u8, arg, "--import-symbols")) {
                        linker_import_symbols = true;
                    } else if (mem.eql(u8, arg, "--import-table")) {
                        linker_import_table = true;
                    } else if (mem.eql(u8, arg, "--export-table")) {
                        linker_export_table = true;
                    } else if (mem.startsWith(u8, arg, "--initial-memory=")) {
                        linker_initial_memory = parseIntSuffix(arg, "--initial-memory=".len);
                    } else if (mem.startsWith(u8, arg, "--max-memory=")) {
                        linker_max_memory = parseIntSuffix(arg, "--max-memory=".len);
                    } else if (mem.eql(u8, arg, "--shared-memory")) {
                        linker_shared_memory = true;
                    } else if (mem.startsWith(u8, arg, "--global-base=")) {
                        linker_global_base = parseIntSuffix(arg, "--global-base=".len);
                    } else if (mem.startsWith(u8, arg, "--export=")) {
                        try linker_export_symbol_names.append(arg["--export=".len..]);
                    } else if (mem.eql(u8, arg, "-Bsymbolic")) {
                        linker_bind_global_refs_locally = true;
                    } else if (mem.eql(u8, arg, "--gc-sections")) {
                        linker_gc_sections = true;
                    } else if (mem.eql(u8, arg, "--no-gc-sections")) {
                        linker_gc_sections = false;
                    } else if (mem.eql(u8, arg, "--build-id")) {
                        build_id = .fast;
                    } else if (mem.startsWith(u8, arg, "--build-id=")) {
                        const style = arg["--build-id=".len..];
                        build_id = BuildId.parse(style) catch |err| {
                            fatal("unable to parse --build-id style '{s}': {s}", .{
                                style, @errorName(err),
                            });
                        };
                    } else if (mem.eql(u8, arg, "--debug-compile-errors")) {
                        if (!crash_report.is_enabled) {
                            std.log.warn("Zig was compiled in a release mode. --debug-compile-errors has no effect.", .{});
                        } else {
                            debug_compile_errors = true;
                        }
                    } else if (mem.eql(u8, arg, "--verbose-link")) {
                        verbose_link = true;
                    } else if (mem.eql(u8, arg, "--verbose-cc")) {
                        verbose_cc = true;
                    } else if (mem.eql(u8, arg, "--verbose-air")) {
                        verbose_air = true;
                    } else if (mem.eql(u8, arg, "--verbose-llvm-ir")) {
                        verbose_llvm_ir = "-";
                    } else if (mem.startsWith(u8, arg, "--verbose-llvm-ir=")) {
                        verbose_llvm_ir = arg["--verbose-llvm-ir=".len..];
                    } else if (mem.startsWith(u8, arg, "--verbose-llvm-bc=")) {
                        verbose_llvm_bc = arg["--verbose-llvm-bc=".len..];
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
                    } else if (mem.startsWith(u8, arg, "-D")) {
                        try clang_argv.append(arg);
                    } else if (mem.startsWith(u8, arg, "-I")) {
                        try cssan.addIncludePath(.I, arg, arg[2..], true);
                    } else if (mem.eql(u8, arg, "-x")) {
                        const lang = args_iter.nextOrFatal();
                        if (mem.eql(u8, lang, "none")) {
                            file_ext = null;
                        } else if (Compilation.LangToExt.get(lang)) |got_ext| {
                            file_ext = got_ext;
                        } else {
                            fatal("language not recognized: '{s}'", .{lang});
                        }
                    } else if (mem.startsWith(u8, arg, "-mexec-model=")) {
                        wasi_exec_model = std.meta.stringToEnum(std.builtin.WasiExecModel, arg["-mexec-model=".len..]) orelse {
                            fatal("expected [command|reactor] for -mexec-mode=[value], found '{s}'", .{arg["-mexec-model=".len..]});
                        };
                    } else {
                        fatal("unrecognized parameter: '{s}'", .{arg});
                    }
                } else switch (file_ext orelse
                    Compilation.classifyFileExt(arg)) {
                    .object, .static_library, .shared_library => try link_objects.append(.{ .path = arg }),
                    .assembly, .assembly_with_cpp, .c, .cpp, .h, .ll, .bc, .m, .mm, .cu => {
                        try c_source_files.append(.{
                            .src_path = arg,
                            .extra_flags = try arena.dupe([]const u8, extra_cflags.items),
                            // duped when parsing the args.
                            .ext = file_ext,
                        });
                    },
                    .zig => {
                        if (root_src_file) |other| {
                            fatal("found another zig file '{s}' after root source file '{s}'", .{ arg, other });
                        } else root_src_file = arg;
                    },
                    .def, .unknown => {
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
            if (build_options.only_c) unreachable;

            emit_h = .no;
            soname = .no;
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
            var file_ext: ?Compilation.FileExt = null;
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
                    .c, .r => c_out_mode = .object, // -c or -r
                    .asm_only => c_out_mode = .assembly, // -S
                    .preprocess_only => c_out_mode = .preprocessor, // -E
                    .emit_llvm => emit_llvm = true,
                    .x => {
                        const lang = mem.sliceTo(it.only_arg, 0);
                        if (mem.eql(u8, lang, "none")) {
                            file_ext = null;
                        } else if (Compilation.LangToExt.get(lang)) |got_ext| {
                            file_ext = got_ext;
                        } else {
                            fatal("language not recognized: '{s}'", .{lang});
                        }
                    },
                    .other => {
                        try clang_argv.appendSlice(it.other_args);
                    },
                    .positional => switch (file_ext orelse
                        Compilation.classifyFileExt(mem.sliceTo(it.only_arg, 0))) {
                        .assembly, .assembly_with_cpp, .c, .cpp, .ll, .bc, .h, .m, .mm, .cu => {
                            try c_source_files.append(.{
                                .src_path = it.only_arg,
                                .ext = file_ext, // duped while parsing the args.
                            });
                        },
                        .unknown, .shared_library, .object, .static_library => try link_objects.append(.{
                            .path = it.only_arg,
                            .must_link = must_link,
                        }),
                        .def => {
                            linker_module_definition_file = it.only_arg;
                        },
                        .zig => {
                            if (root_src_file) |other| {
                                fatal("found another zig file '{s}' after root source file '{s}'", .{ it.only_arg, other });
                            } else root_src_file = it.only_arg;
                        },
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
                    .stack_protector => {
                        if (want_stack_protector == null) {
                            want_stack_protector = Compilation.default_stack_protector_buffer_size;
                        }
                    },
                    .no_stack_protector => want_stack_protector = 0,
                    .unwind_tables => want_unwind_tables = true,
                    .no_unwind_tables => want_unwind_tables = false,
                    .nostdlib => {
                        ensure_libc_on_non_freestanding = false;
                        ensure_libcpp_on_non_freestanding = false;
                    },
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
                                    if (mem.eql(u8, key, "--build-id")) {
                                        build_id = BuildId.parse(value) catch |err| {
                                            fatal("unable to parse --build-id style '{s}': {s}", .{
                                                value, @errorName(err),
                                            });
                                        };
                                        continue;
                                    } else if (mem.eql(u8, key, "--sort-common")) {
                                        // this ignores --sort=common=<anything>; ignoring plain --sort-common
                                        // is done below.
                                        continue;
                                    }
                                    try linker_args.append(key);
                                    try linker_args.append(value);
                                    continue;
                                }
                            }
                            if (mem.eql(u8, linker_arg, "--build-id")) {
                                build_id = .fast;
                            } else if (mem.eql(u8, linker_arg, "--as-needed")) {
                                needed = false;
                            } else if (mem.eql(u8, linker_arg, "--no-as-needed")) {
                                needed = true;
                            } else if (mem.eql(u8, linker_arg, "-no-pie")) {
                                want_pie = false;
                            } else if (mem.eql(u8, linker_arg, "--sort-common")) {
                                // from ld.lld(1): --sort-common is ignored for GNU compatibility,
                                // this ignores plain --sort-common
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
                    .gdwarf32 => {
                        strip = false;
                        dwarf_format = .@"32";
                    },
                    .gdwarf64 => {
                        strip = false;
                        dwarf_format = .@"64";
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
                        // This flag means "dry run". Clang will not actually output anything
                        // to the file system.
                        verbose_link = true;
                        disable_c_depfile = true;
                        try clang_argv.append("-###");
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
                    .dep_file_to_stdout => { // -M, -MM
                        // "Like -MD, but also implies -E and writes to stdout by default"
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
                    .force_undefined_symbol => {
                        try force_undefined_symbols.put(gpa, it.only_arg, {});
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
                    .install_name => {
                        install_name = it.only_arg;
                    },
                    .undefined => {
                        if (mem.eql(u8, "dynamic_lookup", it.only_arg)) {
                            linker_allow_shlib_undefined = true;
                        } else if (mem.eql(u8, "error", it.only_arg)) {
                            linker_allow_shlib_undefined = false;
                        } else {
                            fatal("unsupported -undefined option '{s}'", .{it.only_arg});
                        }
                    },
                }
            }
            // Parse linker args.
            var linker_args_it = ArgsIterator{
                .args = linker_args.items,
            };
            while (linker_args_it.next()) |arg| {
                if (mem.eql(u8, arg, "-soname") or
                    mem.eql(u8, arg, "--soname"))
                {
                    const name = linker_args_it.nextOrFatal();
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
                    try rpath_list.append(linker_args_it.nextOrFatal());
                } else if (mem.eql(u8, arg, "--subsystem")) {
                    subsystem = try parseSubSystem(linker_args_it.nextOrFatal());
                } else if (mem.eql(u8, arg, "-I") or
                    mem.eql(u8, arg, "--dynamic-linker") or
                    mem.eql(u8, arg, "-dynamic-linker"))
                {
                    target_dynamic_linker = linker_args_it.nextOrFatal();
                } else if (mem.eql(u8, arg, "-E") or
                    mem.eql(u8, arg, "--export-dynamic") or
                    mem.eql(u8, arg, "-export-dynamic"))
                {
                    rdynamic = true;
                } else if (mem.eql(u8, arg, "--version-script")) {
                    version_script = linker_args_it.nextOrFatal();
                } else if (mem.eql(u8, arg, "-O")) {
                    const opt = linker_args_it.nextOrFatal();
                    linker_optimization = std.fmt.parseUnsigned(u8, opt, 10) catch |err| {
                        fatal("unable to parse optimization level '{s}': {s}", .{ opt, @errorName(err) });
                    };
                } else if (mem.startsWith(u8, arg, "-O")) {
                    linker_optimization = std.fmt.parseUnsigned(u8, arg["-O".len..], 10) catch |err| {
                        fatal("unable to parse optimization level '{s}': {s}", .{ arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-pagezero_size")) {
                    const next_arg = linker_args_it.nextOrFatal();
                    pagezero_size = std.fmt.parseUnsigned(u64, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse pagezero size '{s}': {s}", .{ next_arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-headerpad")) {
                    const next_arg = linker_args_it.nextOrFatal();
                    headerpad_size = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse  headerpad size '{s}': {s}", .{ next_arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-headerpad_max_install_names")) {
                    headerpad_max_install_names = true;
                } else if (mem.eql(u8, arg, "-dead_strip")) {
                    linker_gc_sections = true;
                } else if (mem.eql(u8, arg, "-dead_strip_dylibs")) {
                    dead_strip_dylibs = true;
                } else if (mem.eql(u8, arg, "--no-undefined")) {
                    linker_z_defs = true;
                } else if (mem.eql(u8, arg, "--gc-sections")) {
                    linker_gc_sections = true;
                } else if (mem.eql(u8, arg, "--no-gc-sections")) {
                    linker_gc_sections = false;
                } else if (mem.eql(u8, arg, "--print-gc-sections")) {
                    linker_print_gc_sections = true;
                } else if (mem.eql(u8, arg, "--print-icf-sections")) {
                    linker_print_icf_sections = true;
                } else if (mem.eql(u8, arg, "--print-map")) {
                    linker_print_map = true;
                } else if (mem.eql(u8, arg, "--sort-section")) {
                    const arg1 = linker_args_it.nextOrFatal();
                    linker_sort_section = std.meta.stringToEnum(link.SortSection, arg1) orelse {
                        fatal("expected [name|alignment] after --sort-section, found '{s}'", .{arg1});
                    };
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
                } else if (mem.eql(u8, arg, "--import-symbols")) {
                    linker_import_symbols = true;
                } else if (mem.eql(u8, arg, "--import-table")) {
                    linker_import_table = true;
                } else if (mem.eql(u8, arg, "--export-table")) {
                    linker_export_table = true;
                } else if (mem.eql(u8, arg, "--initial-memory")) {
                    const next_arg = linker_args_it.nextOrFatal();
                    linker_initial_memory = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse initial memory size '{s}': {s}", .{ next_arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--max-memory")) {
                    const next_arg = linker_args_it.nextOrFatal();
                    linker_max_memory = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse max memory size '{s}': {s}", .{ next_arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--shared-memory")) {
                    linker_shared_memory = true;
                } else if (mem.eql(u8, arg, "--global-base")) {
                    const next_arg = linker_args_it.nextOrFatal();
                    linker_global_base = std.fmt.parseUnsigned(u32, eatIntPrefix(next_arg, 16), 16) catch |err| {
                        fatal("unable to parse global base '{s}': {s}", .{ next_arg, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--export")) {
                    try linker_export_symbol_names.append(linker_args_it.nextOrFatal());
                } else if (mem.eql(u8, arg, "--compress-debug-sections")) {
                    const arg1 = linker_args_it.nextOrFatal();
                    linker_compress_debug_sections = std.meta.stringToEnum(link.CompressDebugSections, arg1) orelse {
                        fatal("expected [none|zlib] after --compress-debug-sections, found '{s}'", .{arg1});
                    };
                } else if (mem.startsWith(u8, arg, "-z")) {
                    var z_arg = arg[2..];
                    if (z_arg.len == 0) {
                        z_arg = linker_args_it.nextOrFatal();
                    }
                    if (mem.eql(u8, z_arg, "nodelete")) {
                        linker_z_nodelete = true;
                    } else if (mem.eql(u8, z_arg, "notext")) {
                        linker_z_notext = true;
                    } else if (mem.eql(u8, z_arg, "defs")) {
                        linker_z_defs = true;
                    } else if (mem.eql(u8, z_arg, "undefs")) {
                        linker_z_defs = false;
                    } else if (mem.eql(u8, z_arg, "origin")) {
                        linker_z_origin = true;
                    } else if (mem.eql(u8, z_arg, "nocopyreloc")) {
                        linker_z_nocopyreloc = true;
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
                    } else if (mem.startsWith(u8, z_arg, "stack-size=")) {
                        const next_arg = z_arg["stack-size=".len..];
                        stack_size_override = std.fmt.parseUnsigned(u64, next_arg, 0) catch |err| {
                            fatal("unable to parse stack size '{s}': {s}", .{ next_arg, @errorName(err) });
                        };
                    } else if (mem.startsWith(u8, z_arg, "common-page-size=")) {
                        linker_z_common_page_size = parseIntSuffix(z_arg, "common-page-size=".len);
                    } else if (mem.startsWith(u8, z_arg, "max-page-size=")) {
                        linker_z_max_page_size = parseIntSuffix(z_arg, "max-page-size=".len);
                    } else {
                        fatal("unsupported linker extension flag: -z {s}", .{z_arg});
                    }
                } else if (mem.eql(u8, arg, "--major-image-version")) {
                    const major = linker_args_it.nextOrFatal();
                    version.major = std.fmt.parseUnsigned(u32, major, 10) catch |err| {
                        fatal("unable to parse major image version '{s}': {s}", .{ major, @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "--minor-image-version")) {
                    const minor = linker_args_it.nextOrFatal();
                    version.minor = std.fmt.parseUnsigned(u32, minor, 10) catch |err| {
                        fatal("unable to parse minor image version '{s}': {s}", .{ minor, @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "-e") or mem.eql(u8, arg, "--entry")) {
                    entry = linker_args_it.nextOrFatal();
                } else if (mem.eql(u8, arg, "-u")) {
                    try force_undefined_symbols.put(gpa, linker_args_it.nextOrFatal(), {});
                } else if (mem.eql(u8, arg, "--stack") or mem.eql(u8, arg, "-stack_size")) {
                    const stack_size = linker_args_it.nextOrFatal();
                    stack_size_override = std.fmt.parseUnsigned(u64, stack_size, 0) catch |err| {
                        fatal("unable to parse stack size override '{s}': {s}", .{ stack_size, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--image-base")) {
                    const image_base = linker_args_it.nextOrFatal();
                    image_base_override = std.fmt.parseUnsigned(u64, image_base, 0) catch |err| {
                        fatal("unable to parse image base override '{s}': {s}", .{ image_base, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-T") or mem.eql(u8, arg, "--script")) {
                    linker_script = linker_args_it.nextOrFatal();
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
                } else if (mem.eql(u8, arg, "--no-dynamicbase")) {
                    linker_dynamicbase = false;
                } else if (mem.eql(u8, arg, "--high-entropy-va")) {
                    // This option does not do anything.
                } else if (mem.eql(u8, arg, "--export-all-symbols")) {
                    rdynamic = true;
                } else if (mem.eql(u8, arg, "--color-diagnostics") or
                    mem.eql(u8, arg, "--color-diagnostics=always"))
                {
                    color = .on;
                } else if (mem.eql(u8, arg, "--no-color-diagnostics") or
                    mem.eql(u8, arg, "--color-diagnostics=never"))
                {
                    color = .off;
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
                    // This option does not do anything.
                    _ = linker_args_it.nextOrFatal();
                } else if (mem.eql(u8, arg, "--major-subsystem-version")) {
                    const major = linker_args_it.nextOrFatal();
                    major_subsystem_version = std.fmt.parseUnsigned(
                        u32,
                        major,
                        10,
                    ) catch |err| {
                        fatal("unable to parse major subsystem version '{s}': {s}", .{ major, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "--minor-subsystem-version")) {
                    const minor = linker_args_it.nextOrFatal();
                    minor_subsystem_version = std.fmt.parseUnsigned(
                        u32,
                        minor,
                        10,
                    ) catch |err| {
                        fatal("unable to parse minor subsystem version '{s}': {s}", .{ minor, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-framework")) {
                    try frameworks.put(gpa, linker_args_it.nextOrFatal(), .{});
                } else if (mem.eql(u8, arg, "-weak_framework")) {
                    try frameworks.put(gpa, linker_args_it.nextOrFatal(), .{ .weak = true });
                } else if (mem.eql(u8, arg, "-needed_framework")) {
                    try frameworks.put(gpa, linker_args_it.nextOrFatal(), .{ .needed = true });
                } else if (mem.eql(u8, arg, "-needed_library")) {
                    try system_libs.put(linker_args_it.nextOrFatal(), .{ .needed = true });
                } else if (mem.startsWith(u8, arg, "-weak-l")) {
                    try system_libs.put(arg["-weak-l".len..], .{ .weak = true });
                } else if (mem.eql(u8, arg, "-weak_library")) {
                    try system_libs.put(linker_args_it.nextOrFatal(), .{ .weak = true });
                } else if (mem.eql(u8, arg, "-compatibility_version")) {
                    const compat_version = linker_args_it.nextOrFatal();
                    compatibility_version = std.builtin.Version.parse(compat_version) catch |err| {
                        fatal("unable to parse -compatibility_version '{s}': {s}", .{ compat_version, @errorName(err) });
                    };
                } else if (mem.eql(u8, arg, "-current_version")) {
                    const curr_version = linker_args_it.nextOrFatal();
                    version = std.builtin.Version.parse(curr_version) catch |err| {
                        fatal("unable to parse -current_version '{s}': {s}", .{ curr_version, @errorName(err) });
                    };
                    have_version = true;
                } else if (mem.eql(u8, arg, "--out-implib") or
                    mem.eql(u8, arg, "-implib"))
                {
                    emit_implib = .{ .yes = linker_args_it.nextOrFatal() };
                    emit_implib_arg_provided = true;
                } else if (mem.eql(u8, arg, "-undefined")) {
                    const lookup_type = linker_args_it.nextOrFatal();
                    if (mem.eql(u8, "dynamic_lookup", lookup_type)) {
                        linker_allow_shlib_undefined = true;
                    } else if (mem.eql(u8, "error", lookup_type)) {
                        linker_allow_shlib_undefined = false;
                    } else {
                        fatal("unsupported -undefined option '{s}'", .{lookup_type});
                    }
                } else if (mem.eql(u8, arg, "-install_name")) {
                    install_name = linker_args_it.nextOrFatal();
                } else if (mem.eql(u8, arg, "-force_load")) {
                    try link_objects.append(.{
                        .path = linker_args_it.nextOrFatal(),
                        .must_link = true,
                    });
                } else if (mem.eql(u8, arg, "-hash-style") or
                    mem.eql(u8, arg, "--hash-style"))
                {
                    const next_arg = linker_args_it.nextOrFatal();
                    hash_style = std.meta.stringToEnum(link.HashStyle, next_arg) orelse {
                        fatal("expected [sysv|gnu|both] after --hash-style, found '{s}'", .{
                            next_arg,
                        });
                    };
                } else if (mem.eql(u8, arg, "-wrap")) {
                    const next_arg = linker_args_it.nextOrFatal();
                    try symbol_wrap_set.put(arena, next_arg, {});
                } else if (mem.startsWith(u8, arg, "/subsystem:")) {
                    var split_it = mem.splitBackwards(u8, arg, ":");
                    subsystem = try parseSubSystem(split_it.first());
                } else if (mem.startsWith(u8, arg, "/implib:")) {
                    var split_it = mem.splitBackwards(u8, arg, ":");
                    emit_implib = .{ .yes = split_it.first() };
                    emit_implib_arg_provided = true;
                } else if (mem.startsWith(u8, arg, "/pdb:")) {
                    var split_it = mem.splitBackwards(u8, arg, ":");
                    pdb_out_path = split_it.first();
                } else if (mem.startsWith(u8, arg, "/version:")) {
                    var split_it = mem.splitBackwards(u8, arg, ":");
                    const version_arg = split_it.first();
                    version = std.builtin.Version.parse(version_arg) catch |err| {
                        fatal("unable to parse /version '{s}': {s}", .{ arg, @errorName(err) });
                    };

                    have_version = true;
                } else {
                    fatal("unsupported linker arg: {s}", .{arg});
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

    {
        // Resolve module dependencies
        var it = modules.iterator();
        while (it.next()) |kv| {
            const deps_str = kv.value_ptr.deps_str;
            var deps_it = ModuleDepIterator.init(deps_str);
            while (deps_it.next()) |dep| {
                if (dep.expose.len == 0) {
                    fatal("module '{s}' depends on '{s}' with a blank name", .{ kv.key_ptr.*, dep.name });
                }

                for ([_][]const u8{ "std", "root", "builtin" }) |name| {
                    if (mem.eql(u8, dep.expose, name)) {
                        fatal("unable to add module '{s}' under name '{s}': conflicts with builtin module", .{ dep.name, dep.expose });
                    }
                }

                const dep_mod = modules.get(dep.name) orelse
                    fatal("module '{s}' depends on module '{s}' which does not exist", .{ kv.key_ptr.*, dep.name });

                try kv.value_ptr.mod.add(gpa, dep.expose, dep_mod.mod);
            }
        }
    }

    if (arg_mode == .build and optimize_mode == .ReleaseSmall and strip == null)
        strip = true;

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
        .object_format = target_ofmt,
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
    const target_info = try detectNativeTargetInfo(cross_target);

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

            if (fs.path.isAbsolute(lib_name)) {
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

    const object_format = target_info.target.ofmt;

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

    const output_to_cache = listen != .none;
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
                        if (output_to_cache) {
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
                .version = optional_version,
            }),
        },
        .yes => |full_path| b: {
            const basename = fs.path.basename(full_path);
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
            .directory = .{ .path = null, .handle = fs.cwd() },
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

    const main_pkg: ?*Package = if (root_src_file) |unresolved_src_path| blk: {
        const src_path = try introspect.resolvePath(arena, unresolved_src_path);
        if (main_pkg_path) |unresolved_main_pkg_path| {
            const p = try introspect.resolvePath(arena, unresolved_main_pkg_path);
            if (p.len == 0) {
                break :blk try Package.create(gpa, null, src_path);
            } else {
                const rel_src_path = try fs.path.relative(arena, p, src_path);
                break :blk try Package.create(gpa, p, rel_src_path);
            }
        } else {
            const root_src_dir_path = fs.path.dirname(src_path);
            break :blk Package.create(gpa, root_src_dir_path, fs.path.basename(src_path)) catch |err| {
                if (root_src_dir_path) |p| {
                    fatal("unable to open '{s}': {s}", .{ p, @errorName(err) });
                } else {
                    return err;
                }
            };
        }
    } else null;
    defer if (main_pkg) |p| p.destroy(gpa);

    // Transfer packages added with --deps to the root package
    if (main_pkg) |mod| {
        var it = ModuleDepIterator.init(root_deps_str orelse "");
        while (it.next()) |dep| {
            if (dep.expose.len == 0) {
                fatal("root module depends on '{s}' with a blank name", .{dep.name});
            }

            for ([_][]const u8{ "std", "root", "builtin" }) |name| {
                if (mem.eql(u8, dep.expose, name)) {
                    fatal("unable to add module '{s}' under name '{s}': conflicts with builtin module", .{ dep.name, dep.expose });
                }
            }

            const dep_mod = modules.get(dep.name) orelse
                fatal("root module depends on module '{s}' which does not exist", .{dep.name});

            try mod.add(gpa, dep.expose, dep_mod.mod);
        }
    }

    const self_exe_path: ?[]const u8 = if (!process.can_spawn)
        null
    else
        introspect.findZigExePath(arena) catch |err| {
            fatal("unable to find zig self exe path: {s}", .{@errorName(err)});
        };

    var zig_lib_directory: Compilation.Directory = d: {
        if (override_lib_dir) |unresolved_lib_dir| {
            const lib_dir = try introspect.resolvePath(arena, unresolved_lib_dir);
            break :d .{
                .path = lib_dir,
                .handle = fs.cwd().openDir(lib_dir, .{}) catch |err| {
                    fatal("unable to open zig lib directory '{s}': {s}", .{ lib_dir, @errorName(err) });
                },
            };
        } else if (builtin.os.tag == .wasi) {
            break :d getWasiPreopen("/lib");
        } else if (self_exe_path) |p| {
            break :d introspect.findZigLibDirFromSelfExe(arena, p) catch |err| {
                fatal("unable to find zig installation directory: {s}", .{@errorName(err)});
            };
        } else {
            unreachable;
        }
    };

    defer zig_lib_directory.handle.close();

    var thread_pool: ThreadPool = undefined;
    try thread_pool.init(.{ .allocator = gpa });
    defer thread_pool.deinit();

    var libc_installation: ?LibCInstallation = null;
    defer if (libc_installation) |*l| l.deinit(gpa);

    if (libc_paths_file) |paths_file| {
        libc_installation = LibCInstallation.parse(gpa, paths_file, cross_target) catch |err| {
            fatal("unable to parse libc paths file at path {s}: {s}", .{ paths_file, @errorName(err) });
        };
    }

    var global_cache_directory: Compilation.Directory = l: {
        if (override_global_cache_dir) |p| {
            break :l .{
                .handle = try fs.cwd().makeOpenPath(p, .{}),
                .path = p,
            };
        }
        if (builtin.os.tag == .wasi) {
            break :l getWasiPreopen("/cache");
        }
        const p = try introspect.resolveGlobalCacheDir(arena);
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
            // search upwards from cwd until we find directory with build.zig
            const cwd_path = try process.getCwdAlloc(arena);
            const build_zig = "build.zig";
            const zig_cache = "zig-cache";
            var dirname: []const u8 = cwd_path;
            while (true) {
                const joined_path = try fs.path.join(arena, &[_][]const u8{ dirname, build_zig });
                if (fs.cwd().access(joined_path, .{})) |_| {
                    const cache_dir_path = try fs.path.join(arena, &[_][]const u8{ dirname, zig_cache });
                    const dir = try pkg.root_src_directory.handle.makeOpenPath(cache_dir_path, .{});
                    cleanup_local_cache_dir = dir;
                    break :l .{ .handle = dir, .path = cache_dir_path };
                } else |err| switch (err) {
                    error.FileNotFound => {
                        dirname = fs.path.dirname(dirname) orelse {
                            break :l global_cache_directory;
                        };
                        continue;
                    },
                    else => break :l global_cache_directory,
                }
            }
        }
        // Otherwise we really don't have a reasonable place to put the local cache directory,
        // so we utilize the global one.
        break :l global_cache_directory;
    };

    for (c_source_files.items) |*src| {
        if (!mem.eql(u8, src.src_path, "-")) continue;

        const ext = src.ext orelse
            fatal("-E or -x is required when reading from a non-regular file", .{});

        // "-" is stdin. Dump it to a real file.
        const sep = fs.path.sep_str;
        const sub_path = try std.fmt.allocPrint(arena, "tmp" ++ sep ++ "{x}-stdin{s}", .{
            std.crypto.random.int(u64), ext.canonicalName(target_info.target),
        });
        try local_cache_directory.handle.makePath("tmp");
        // Note that in one of the happy paths, execve() is used to switch
        // to clang in which case any cleanup logic that exists for this
        // temporary file will not run and this temp file will be leaked.
        // Oh well. It's a minor punishment for using `-x c` which nobody
        // should be doing. Therefore, we make no effort to clean up. Using
        // `-` for stdin as a source file always leaks a temp file.
        var f = try local_cache_directory.handle.createFile(sub_path, .{});
        defer f.close();
        try f.writeFileAll(io.getStdIn(), .{});

        // Convert `sub_path` to be relative to current working directory.
        src.src_path = try local_cache_directory.join(arena, &.{sub_path});
    }

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
        .optimize_mode = optimize_mode,
        .keep_source_files_loaded = false,
        .clang_argv = clang_argv.items,
        .lib_dirs = lib_dirs.items,
        .rpath_list = rpath_list.items,
        .symbol_wrap_set = symbol_wrap_set,
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
        .want_stack_protector = want_stack_protector,
        .want_red_zone = want_red_zone,
        .omit_frame_pointer = omit_frame_pointer,
        .want_valgrind = want_valgrind,
        .want_tsan = want_tsan,
        .want_compiler_rt = want_compiler_rt,
        .use_llvm = use_llvm,
        .use_lld = use_lld,
        .use_clang = use_clang,
        .hash_style = hash_style,
        .rdynamic = rdynamic,
        .linker_script = linker_script,
        .version_script = version_script,
        .disable_c_depfile = disable_c_depfile,
        .soname = resolved_soname,
        .linker_sort_section = linker_sort_section,
        .linker_gc_sections = linker_gc_sections,
        .linker_allow_shlib_undefined = linker_allow_shlib_undefined,
        .linker_bind_global_refs_locally = linker_bind_global_refs_locally,
        .linker_import_memory = linker_import_memory,
        .linker_import_symbols = linker_import_symbols,
        .linker_import_table = linker_import_table,
        .linker_export_table = linker_export_table,
        .linker_initial_memory = linker_initial_memory,
        .linker_max_memory = linker_max_memory,
        .linker_shared_memory = linker_shared_memory,
        .linker_print_gc_sections = linker_print_gc_sections,
        .linker_print_icf_sections = linker_print_icf_sections,
        .linker_print_map = linker_print_map,
        .linker_opt_bisect_limit = linker_opt_bisect_limit,
        .linker_global_base = linker_global_base,
        .linker_export_symbol_names = linker_export_symbol_names.items,
        .linker_z_nocopyreloc = linker_z_nocopyreloc,
        .linker_z_nodelete = linker_z_nodelete,
        .linker_z_notext = linker_z_notext,
        .linker_z_defs = linker_z_defs,
        .linker_z_origin = linker_z_origin,
        .linker_z_now = linker_z_now,
        .linker_z_relro = linker_z_relro,
        .linker_z_common_page_size = linker_z_common_page_size,
        .linker_z_max_page_size = linker_z_max_page_size,
        .linker_tsaware = linker_tsaware,
        .linker_nxcompat = linker_nxcompat,
        .linker_dynamicbase = linker_dynamicbase,
        .linker_optimization = linker_optimization,
        .linker_compress_debug_sections = linker_compress_debug_sections,
        .linker_module_definition_file = linker_module_definition_file,
        .major_subsystem_version = major_subsystem_version,
        .minor_subsystem_version = minor_subsystem_version,
        .link_eh_frame_hdr = link_eh_frame_hdr,
        .link_emit_relocs = link_emit_relocs,
        .entry = entry,
        .force_undefined_symbols = force_undefined_symbols,
        .stack_size_override = stack_size_override,
        .image_base_override = image_base_override,
        .strip = strip,
        .formatted_panics = formatted_panics,
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
        .verbose_llvm_bc = verbose_llvm_bc,
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
        .test_runner_path = test_runner_path,
        .disable_lld_caching = !output_to_cache,
        .subsystem = subsystem,
        .dwarf_format = dwarf_format,
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
        .reference_trace = reference_trace,
        .error_tracing = error_tracing,
        .pdb_out_path = pdb_out_path,
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
    switch (listen) {
        .none => {},
        .stdio => {
            if (build_options.only_c) unreachable;
            try serve(
                comp,
                std.io.getStdIn(),
                std.io.getStdOut(),
                test_exec_args.items,
                self_exe_path,
                arg_mode,
                all_args,
                runtime_args_start,
            );
            return cleanExit();
        },
        .ip4 => |ip4_addr| {
            if (build_options.omit_pkg_fetching_code) unreachable;

            var server = std.net.StreamServer.init(.{
                .reuse_address = true,
            });
            defer server.deinit();

            try server.listen(.{ .in = ip4_addr });

            const conn = try server.accept();
            defer conn.stream.close();

            try serve(
                comp,
                .{ .handle = conn.stream.handle },
                .{ .handle = conn.stream.handle },
                test_exec_args.items,
                self_exe_path,
                arg_mode,
                all_args,
                runtime_args_start,
            );
            return cleanExit();
        },
    }

    if (arg_mode == .translate_c) {
        return cmdTranslateC(comp, arena, null);
    }

    updateModule(comp) catch |err| switch (err) {
        error.SemanticAnalyzeFail => if (listen == .none) process.exit(1),
        else => |e| return e,
    };
    if (build_options.only_c) return cleanExit();
    try comp.makeBinFileExecutable();

    if (test_exec_args.items.len == 0 and object_format == .c) default_exec_args: {
        // Default to using `zig run` to execute the produced .c code from `zig test`.
        const c_code_loc = emit_bin_loc orelse break :default_exec_args;
        const c_code_directory = c_code_loc.directory orelse comp.bin_file.options.emit.?.directory;
        const c_code_path = try fs.path.join(arena, &[_][]const u8{
            c_code_directory.path orelse ".", c_code_loc.basename,
        });
        try test_exec_args.append(self_exe_path);
        try test_exec_args.append("run");
        if (zig_lib_directory.path) |p| {
            try test_exec_args.appendSlice(&.{ "-I", p });
        }

        if (link_libc) {
            try test_exec_args.append("-lc");
        } else if (target_info.target.os.tag == .windows) {
            try test_exec_args.appendSlice(&.{
                "--subsystem", "console",
                "-lkernel32",  "-lntdll",
            });
        }

        if (!mem.eql(u8, target_arch_os_abi, "native")) {
            try test_exec_args.append("-target");
            try test_exec_args.append(target_arch_os_abi);
        }
        if (target_mcpu) |mcpu| {
            try test_exec_args.append(try std.fmt.allocPrint(arena, "-mcpu={s}", .{mcpu}));
        }
        if (target_dynamic_linker) |dl| {
            try test_exec_args.append("--dynamic-linker");
            try test_exec_args.append(dl);
        }
        try test_exec_args.append(c_code_path);
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
            self_exe_path.?,
            arg_mode,
            target_info,
            &comp_destroyed,
            all_args,
            runtime_args_start,
            link_libc,
        );
    }

    // Skip resource deallocation in release builds; let the OS do it.
    return cleanExit();
}

fn serve(
    comp: *Compilation,
    in: fs.File,
    out: fs.File,
    test_exec_args: []const ?[]const u8,
    self_exe_path: ?[]const u8,
    arg_mode: ArgMode,
    all_args: []const []const u8,
    runtime_args_start: ?usize,
) !void {
    const gpa = comp.gpa;

    var server = try Server.init(.{
        .gpa = gpa,
        .in = in,
        .out = out,
        .zig_version = build_options.version,
    });
    defer server.deinit();

    var child_pid: ?std.ChildProcess.Id = null;

    var progress: std.Progress = .{
        .terminal = null,
        .root = .{
            .context = undefined,
            .parent = null,
            .name = "",
            .unprotected_estimated_total_items = 0,
            .unprotected_completed_items = 0,
        },
        .columns_written = 0,
        .prev_refresh_timestamp = 0,
        .timer = null,
        .done = false,
    };
    const main_progress_node = &progress.root;
    main_progress_node.context = &progress;

    while (true) {
        const hdr = try server.receiveMessage();

        switch (hdr.tag) {
            .exit => return,
            .update => {
                assert(main_progress_node.recently_updated_child == null);
                tracy.frameMark();

                if (arg_mode == .translate_c) {
                    var arena_instance = std.heap.ArenaAllocator.init(gpa);
                    defer arena_instance.deinit();
                    const arena = arena_instance.allocator();
                    var output: TranslateCOutput = undefined;
                    try cmdTranslateC(comp, arena, &output);
                    try server.serveEmitBinPath(output.path, .{
                        .flags = .{ .cache_hit = output.cache_hit },
                    });
                    continue;
                }

                if (comp.bin_file.options.output_mode == .Exe) {
                    try comp.makeBinFileWritable();
                }

                {
                    var reset: std.Thread.ResetEvent = .{};

                    var progress_thread = try std.Thread.spawn(.{}, progressThread, .{
                        &progress, &server, &reset,
                    });
                    defer {
                        reset.set();
                        progress_thread.join();
                    }

                    try comp.update(main_progress_node);
                }

                try comp.makeBinFileExecutable();
                try serveUpdateResults(&server, comp);
            },
            .run => {
                if (child_pid != null) {
                    @panic("TODO block until the child exits");
                }
                @panic("TODO call runOrTest");
                //try runOrTest(
                //    comp,
                //    gpa,
                //    arena,
                //    test_exec_args,
                //    self_exe_path.?,
                //    arg_mode,
                //    target_info,
                //    true,
                //    &comp_destroyed,
                //    all_args,
                //    runtime_args_start,
                //    link_libc,
                //);
            },
            .hot_update => {
                tracy.frameMark();
                assert(main_progress_node.recently_updated_child == null);
                if (child_pid) |pid| {
                    try comp.hotCodeSwap(main_progress_node, pid);
                    try serveUpdateResults(&server, comp);
                } else {
                    if (comp.bin_file.options.output_mode == .Exe) {
                        try comp.makeBinFileWritable();
                    }
                    try comp.update(main_progress_node);
                    try comp.makeBinFileExecutable();
                    try serveUpdateResults(&server, comp);

                    child_pid = try runOrTestHotSwap(
                        comp,
                        gpa,
                        test_exec_args,
                        self_exe_path.?,
                        arg_mode,
                        all_args,
                        runtime_args_start,
                    );
                }
            },
            else => {
                fatal("unrecognized message from client: 0x{x}", .{@enumToInt(hdr.tag)});
            },
        }
    }
}

fn progressThread(progress: *std.Progress, server: *const Server, reset: *std.Thread.ResetEvent) void {
    while (true) {
        if (reset.timedWait(500 * std.time.ns_per_ms)) |_| {
            // The Compilation update has completed.
            return;
        } else |err| switch (err) {
            error.Timeout => {},
        }

        var buf: std.BoundedArray(u8, 160) = .{};

        {
            progress.update_mutex.lock();
            defer progress.update_mutex.unlock();

            var need_ellipse = false;
            var maybe_node: ?*std.Progress.Node = &progress.root;
            while (maybe_node) |node| {
                if (need_ellipse) {
                    buf.appendSlice("... ") catch {};
                }
                need_ellipse = false;
                const eti = @atomicLoad(usize, &node.unprotected_estimated_total_items, .Monotonic);
                const completed_items = @atomicLoad(usize, &node.unprotected_completed_items, .Monotonic);
                const current_item = completed_items + 1;
                if (node.name.len != 0 or eti > 0) {
                    if (node.name.len != 0) {
                        buf.appendSlice(node.name) catch {};
                        need_ellipse = true;
                    }
                    if (eti > 0) {
                        if (need_ellipse) buf.appendSlice(" ") catch {};
                        buf.writer().print("[{d}/{d}] ", .{ current_item, eti }) catch {};
                        need_ellipse = false;
                    } else if (completed_items != 0) {
                        if (need_ellipse) buf.appendSlice(" ") catch {};
                        buf.writer().print("[{d}] ", .{current_item}) catch {};
                        need_ellipse = false;
                    }
                }
                maybe_node = @atomicLoad(?*std.Progress.Node, &node.recently_updated_child, .Acquire);
            }
        }

        const progress_string = buf.slice();

        server.serveMessage(.{
            .tag = .progress,
            .bytes_len = @intCast(u32, progress_string.len),
        }, &.{
            progress_string,
        }) catch |err| {
            fatal("unable to write to client: {s}", .{@errorName(err)});
        };
    }
}

fn serveUpdateResults(s: *Server, comp: *Compilation) !void {
    const gpa = comp.gpa;
    var error_bundle = try comp.getAllErrorsAlloc();
    defer error_bundle.deinit(gpa);
    if (error_bundle.errorMessageCount() > 0) {
        try s.serveErrorBundle(error_bundle);
    } else if (comp.bin_file.options.emit) |emit| {
        const full_path = try emit.directory.join(gpa, &.{emit.sub_path});
        defer gpa.free(full_path);
        try s.serveEmitBinPath(full_path, .{
            .flags = .{ .cache_hit = comp.last_update_was_cache_hit },
        });
    }
}

const ModuleDepIterator = struct {
    split: mem.SplitIterator(u8),

    fn init(deps_str: []const u8) ModuleDepIterator {
        return .{ .split = mem.split(u8, deps_str, ",") };
    }

    const Dependency = struct {
        expose: []const u8,
        name: []const u8,
    };

    fn next(it: *ModuleDepIterator) ?Dependency {
        if (it.split.buffer.len == 0) return null; // don't return "" for the first iteration on ""
        const str = it.split.next() orelse return null;
        if (mem.indexOfScalar(u8, str, '=')) |i| {
            return .{
                .expose = str[0..i],
                .name = str[i + 1 ..],
            };
        } else {
            return .{ .expose = str, .name = str };
        }
    }
};

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
                std.log.info("available CPUs for architecture '{s}':\n{s}", .{
                    @tagName(diags.arch.?), help_text.items,
                });
            }
            fatal("unknown CPU: '{s}'", .{diags.cpu_name.?});
        },
        error.UnknownCpuFeature => {
            help: {
                var help_text = std.ArrayList(u8).init(allocator);
                defer help_text.deinit();
                for (diags.arch.?.allFeaturesList()) |feature| {
                    help_text.writer().print(" {s}: {s}\n", .{ feature.name, feature.description }) catch break :help;
                }
                std.log.info("available CPU features for architecture '{s}':\n{s}", .{
                    @tagName(diags.arch.?), help_text.items,
                });
            }
            fatal("unknown CPU feature: '{s}'", .{diags.unknown_feature_name.?});
        },
        error.UnknownObjectFormat => {
            help: {
                var help_text = std.ArrayList(u8).init(allocator);
                defer help_text.deinit();
                inline for (@typeInfo(std.Target.ObjectFormat).Enum.fields) |field| {
                    help_text.writer().print(" {s}\n", .{field.name}) catch break :help;
                }
                std.log.info("available object formats:\n{s}", .{help_text.items});
            }
            fatal("unknown object format: '{s}'", .{opts.object_format.?});
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
        try argv.append(exe_path);
    } else {
        for (test_exec_args) |arg| {
            try argv.append(arg orelse exe_path);
        }
    }
    if (runtime_args_start) |i| {
        try argv.appendSlice(all_args[i..]);
    }
    var env_map = try std.process.getEnvMap(arena);
    try env_map.put("ZIG_EXE", self_exe_path);

    // We do not execve for tests because if the test fails we want to print
    // the error message and invocation below.
    if (std.process.can_execv and arg_mode == .run) {
        // execv releases the locks; no need to destroy the Compilation here.
        const err = std.process.execve(gpa, argv.items, &env_map);
        try warnAboutForeignBinaries(arena, arg_mode, target_info, link_libc);
        const cmd = try std.mem.join(arena, " ", argv.items);
        fatal("the following command failed to execve with '{s}':\n{s}", .{ @errorName(err), cmd });
    } else if (std.process.can_spawn) {
        var child = std.ChildProcess.init(argv.items, gpa);
        child.env_map = &env_map;
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        // Here we release all the locks associated with the Compilation so
        // that whatever this child process wants to do won't deadlock.
        comp.destroy();
        comp_destroyed.* = true;

        const term = child.spawnAndWait() catch |err| {
            try warnAboutForeignBinaries(arena, arg_mode, target_info, link_libc);
            const cmd = try std.mem.join(arena, " ", argv.items);
            fatal("the following command failed with '{s}':\n{s}", .{ @errorName(err), cmd });
        };
        switch (arg_mode) {
            .run, .build => {
                switch (term) {
                    .Exited => |code| {
                        if (code == 0) {
                            return cleanExit();
                        } else {
                            process.exit(code);
                        }
                    },
                    else => {
                        process.exit(1);
                    },
                }
            },
            .zig_test => {
                switch (term) {
                    .Exited => |code| {
                        if (code == 0) {
                            return cleanExit();
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

fn runOrTestHotSwap(
    comp: *Compilation,
    gpa: Allocator,
    test_exec_args: []const ?[]const u8,
    self_exe_path: []const u8,
    arg_mode: ArgMode,
    all_args: []const []const u8,
    runtime_args_start: ?usize,
) !std.ChildProcess.Id {
    const exe_emit = comp.bin_file.options.emit.?;

    const exe_path = switch (builtin.target.os.tag) {
        // On Windows it seems impossible to perform an atomic rename of a file that is currently
        // running in a process. Therefore, we do the opposite. We create a copy of the file in
        // tmp zig-cache and use it to spawn the child process. This way we are free to update
        // the binary with each requested hot update.
        .windows => blk: {
            try exe_emit.directory.handle.copyFile(exe_emit.sub_path, comp.local_cache_directory.handle, exe_emit.sub_path, .{});
            break :blk try fs.path.join(gpa, &[_][]const u8{
                comp.local_cache_directory.path orelse ".", exe_emit.sub_path,
            });
        },

        // A naive `directory.join` here will indeed get the correct path to the binary,
        // however, in the case of cwd, we actually want `./foo` so that the path can be executed.
        else => try fs.path.join(gpa, &[_][]const u8{
            exe_emit.directory.path orelse ".", exe_emit.sub_path,
        }),
    };
    defer gpa.free(exe_path);

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

    switch (builtin.target.os.tag) {
        .macos, .ios, .tvos, .watchos => {
            const PosixSpawn = std.os.darwin.PosixSpawn;

            var attr = try PosixSpawn.Attr.init();
            defer attr.deinit();

            // ASLR is probably a good default for better debugging experience/programming
            // with hot-code updates in mind. However, we can also make it work with ASLR on.
            const flags: u16 = std.os.darwin.POSIX_SPAWN.SETSIGDEF |
                std.os.darwin.POSIX_SPAWN.SETSIGMASK |
                std.os.darwin.POSIX_SPAWN.DISABLE_ASLR;
            try attr.set(flags);

            var arena_allocator = std.heap.ArenaAllocator.init(gpa);
            defer arena_allocator.deinit();
            const arena = arena_allocator.allocator();

            const argv_buf = try arena.allocSentinel(?[*:0]u8, argv.items.len, null);
            for (argv.items, 0..) |arg, i| argv_buf[i] = (try arena.dupeZ(u8, arg)).ptr;

            const pid = try PosixSpawn.spawn(argv.items[0], null, attr, argv_buf, std.c.environ);
            return pid;
        },
        else => {
            var child = std.ChildProcess.init(argv.items, gpa);

            child.stdin_behavior = .Inherit;
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;

            try child.spawn();

            return child.id;
        },
    }
}

fn updateModule(comp: *Compilation) !void {
    {
        // If the terminal is dumb, we dont want to show the user all the output.
        var progress: std.Progress = .{ .dont_print_on_dumb = true };
        const main_progress_node = progress.start("", 0);
        defer main_progress_node.end();
        switch (comp.color) {
            .off => {
                progress.terminal = null;
            },
            .on => {
                progress.terminal = std.io.getStdErr();
                progress.supports_ansi_escape_codes = true;
            },
            .auto => {},
        }

        try comp.update(main_progress_node);
    }

    var errors = try comp.getAllErrorsAlloc();
    defer errors.deinit(comp.gpa);

    if (errors.errorMessageCount() > 0) {
        errors.renderToStdErr(renderOptions(comp.color));
        return error.SemanticAnalyzeFail;
    }
}

const TranslateCOutput = struct {
    path: []const u8,
    cache_hit: bool,
};

fn cmdTranslateC(comp: *Compilation, arena: Allocator, fancy_output: ?*TranslateCOutput) !void {
    if (!build_options.have_llvm)
        fatal("cannot translate-c: compiler built without LLVM extensions", .{});

    assert(comp.c_source_files.len == 1);
    const c_source_file = comp.c_source_files[0];

    const translated_zig_basename = try std.fmt.allocPrint(arena, "{s}.zig", .{comp.bin_file.options.root_name});

    var man: Cache.Manifest = comp.obtainCObjectCacheManifest();
    man.want_shared_lock = false;
    defer man.deinit();

    man.hash.add(@as(u16, 0xb945)); // Random number to distinguish translate-c from compiling C objects
    Compilation.cache_helpers.hashCSource(&man, c_source_file) catch |err| {
        fatal("unable to process '{s}': {s}", .{ c_source_file.src_path, @errorName(err) });
    };

    if (fancy_output) |p| p.cache_hit = true;
    const digest = if (try man.hit()) man.final() else digest: {
        if (fancy_output) |p| p.cache_hit = false;
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
        for (argv.items, 0..) |arg, i| {
            new_argv[i] = try arena.dupeZ(u8, arg);
        }
        for (c_source_file.extra_flags, 0..) |arg, i| {
            new_argv[argv.items.len + i] = try arena.dupeZ(u8, arg);
        }

        const c_headers_dir_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{"include"});
        const c_headers_dir_path_z = try arena.dupeZ(u8, c_headers_dir_path);
        var clang_errors: []clang.ErrorMsg = &[0]clang.ErrorMsg{};
        var tree = translate_c.translate(
            comp.gpa,
            new_argv.ptr,
            new_argv.ptr + new_argv.len,
            &clang_errors,
            c_headers_dir_path_z,
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.ASTUnitFailure => fatal("clang API returned errors but due to a clang bug, it is not exposing the errors for zig to see. For more details: https://github.com/ziglang/zig/issues/4455", .{}),
            error.SemanticAnalyzeFail => {
                // TODO convert these to zig errors
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
            const dep_basename = fs.path.basename(dep_file_path);
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

    if (fancy_output) |p| {
        const full_zig_path = try comp.local_cache_directory.join(arena, &[_][]const u8{
            "o", &digest, translated_zig_basename,
        });
        p.path = full_zig_path;
    } else {
        const out_zig_path = try fs.path.join(arena, &[_][]const u8{ "o", &digest, translated_zig_basename });
        const zig_file = comp.local_cache_directory.handle.openFile(out_zig_path, .{}) catch |err| {
            const path = comp.local_cache_directory.path orelse ".";
            fatal("unable to open cached translated zig file '{s}{s}{s}': {s}", .{ path, fs.path.sep_str, out_zig_path, @errorName(err) });
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
        const path = zig_lib_directory.path orelse ".";
        fatal("unable to open zig project template directory '{s}{s}{s}': {s}", .{ path, s, template_sub_path, @errorName(err) });
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
    \\   -freference-trace[=num]       How many lines of reference trace should be shown per compile error
    \\   -fno-reference-trace          Disable reference trace
    \\   -fsummary                     Print the build summary, even on success
    \\   -fno-summary                  Omit the build summary, even on failure
    \\   --build-file [file]           Override path to build.zig
    \\   --cache-dir [path]            Override path to local Zig cache directory
    \\   --global-cache-dir [path]     Override path to global Zig cache directory
    \\   --zig-lib-dir [arg]           Override path to Zig lib directory
    \\   --build-runner [file]         Override path to build runner
    \\   -h, --help                    Print this help and exit
    \\
;

pub fn cmdBuild(gpa: Allocator, arena: Allocator, args: []const []const u8) !void {
    var color: Color = .auto;

    // We want to release all the locks before executing the child process, so we make a nice
    // big block here to ensure the cleanup gets run when we extract out our argv.
    const child_argv = argv: {
        const self_exe_path = try introspect.findZigExePath(arena);

        var build_file: ?[]const u8 = null;
        var override_lib_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LIB_DIR");
        var override_global_cache_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_GLOBAL_CACHE_DIR");
        var override_local_cache_dir: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_LOCAL_CACHE_DIR");
        var override_build_runner: ?[]const u8 = try optionalStringEnvVar(arena, "ZIG_BUILD_RUNNER");
        var child_argv = std.ArrayList([]const u8).init(arena);
        var reference_trace: ?u32 = null;
        var debug_compile_errors = false;

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
                    } else if (mem.eql(u8, arg, "--build-runner")) {
                        if (i + 1 >= args.len) fatal("expected argument after '{s}'", .{arg});
                        i += 1;
                        override_build_runner = args[i];
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
                    } else if (mem.eql(u8, arg, "-freference-trace")) {
                        try child_argv.append(arg);
                        reference_trace = 256;
                    } else if (mem.startsWith(u8, arg, "-freference-trace=")) {
                        try child_argv.append(arg);
                        const num = arg["-freference-trace=".len..];
                        reference_trace = std.fmt.parseUnsigned(u32, num, 10) catch |err| {
                            fatal("unable to parse reference_trace count '{s}': {s}", .{ num, @errorName(err) });
                        };
                    } else if (mem.eql(u8, arg, "-fno-reference-trace")) {
                        try child_argv.append(arg);
                        reference_trace = null;
                    } else if (mem.eql(u8, arg, "--debug-compile-errors")) {
                        try child_argv.append(arg);
                        debug_compile_errors = true;
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
        const target_info = try detectNativeTargetInfo(cross_target);

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
        try thread_pool.init(.{ .allocator = gpa });
        defer thread_pool.deinit();

        var cleanup_build_runner_dir: ?fs.Dir = null;
        defer if (cleanup_build_runner_dir) |*dir| dir.close();

        var main_pkg: Package = if (override_build_runner) |build_runner_path|
            .{
                .root_src_directory = blk: {
                    if (std.fs.path.dirname(build_runner_path)) |dirname| {
                        const dir = fs.cwd().openDir(dirname, .{}) catch |err| {
                            fatal("unable to open directory to build runner from argument 'build-runner', '{s}': {s}", .{ dirname, @errorName(err) });
                        };
                        cleanup_build_runner_dir = dir;
                        break :blk .{ .path = dirname, .handle = dir };
                    }

                    break :blk .{ .path = null, .handle = fs.cwd() };
                },
                .root_src_path = std.fs.path.basename(build_runner_path),
            }
        else
            .{
                .root_src_directory = zig_lib_directory,
                .root_src_path = "build_runner.zig",
            };

        var build_pkg: Package = .{
            .root_src_directory = build_directory,
            .root_src_path = build_zig_basename,
        };
        if (!build_options.omit_pkg_fetching_code) {
            var http_client: std.http.Client = .{ .allocator = gpa };
            defer http_client.deinit();

            // Here we provide an import to the build runner that allows using reflection to find
            // all of the dependencies. Without this, there would be no way to use `@import` to
            // access dependencies by name, since `@import` requires string literals.
            var dependencies_source = std.ArrayList(u8).init(gpa);
            defer dependencies_source.deinit();
            try dependencies_source.appendSlice("pub const imports = struct {\n");

            // This will go into the same package. It contains the file system paths
            // to all the build.zig files.
            var build_roots_source = std.ArrayList(u8).init(gpa);
            defer build_roots_source.deinit();

            var all_modules: Package.AllModules = .{};
            defer all_modules.deinit(gpa);

            var wip_errors: std.zig.ErrorBundle.Wip = undefined;
            try wip_errors.init(gpa);
            defer wip_errors.deinit();

            // Here we borrow main package's table and will replace it with a fresh
            // one after this process completes.
            const fetch_result = build_pkg.fetchAndAddDependencies(
                &main_pkg,
                arena,
                &thread_pool,
                &http_client,
                build_directory,
                global_cache_directory,
                local_cache_directory,
                &dependencies_source,
                &build_roots_source,
                "",
                &wip_errors,
                &all_modules,
            );
            if (wip_errors.root_list.items.len > 0) {
                var errors = try wip_errors.toOwnedBundle("");
                defer errors.deinit(gpa);
                errors.renderToStdErr(renderOptions(color));
                process.exit(1);
            }
            try fetch_result;

            try dependencies_source.appendSlice("};\npub const build_root = struct {\n");
            try dependencies_source.appendSlice(build_roots_source.items);
            try dependencies_source.appendSlice("};\n");

            const deps_pkg = try Package.createFilePkg(
                gpa,
                local_cache_directory,
                "dependencies.zig",
                dependencies_source.items,
            );

            mem.swap(Package.Table, &main_pkg.table, &deps_pkg.table);
            try main_pkg.add(gpa, "@dependencies", deps_pkg);
        }
        try main_pkg.add(gpa, "@build", &build_pkg);

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
            .cache_mode = .whole,
            .reference_trace = reference_trace,
            .debug_compile_errors = debug_compile_errors,
        }) catch |err| {
            fatal("unable to create compilation: {s}", .{@errorName(err)});
        };
        defer comp.destroy();

        updateModule(comp) catch |err| switch (err) {
            error.SemanticAnalyzeFail => process.exit(2),
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
                // Indicates that the build runner has reported compile errors
                // and this parent process does not need to report any further
                // diagnostics.
                if (code == 2) process.exit(2);

                const cmd = try std.mem.join(arena, " ", child_argv);
                fatal("the following build command failed with exit code {d}:\n{s}", .{ code, cmd });
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
    allocator: Allocator,
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
            fatal("unable to read stdin: {}", .{err});
        };
        defer gpa.free(source_code);

        var tree = Ast.parse(gpa, source_code, .zig) catch |err| {
            fatal("error parsing stdin: {}", .{err});
        };
        defer tree.deinit(gpa);

        if (check_ast_flag) {
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
                var wip_errors: std.zig.ErrorBundle.Wip = undefined;
                try wip_errors.init(gpa);
                defer wip_errors.deinit();
                try Compilation.addZirErrorMessages(&wip_errors, &file);
                var error_bundle = try wip_errors.toOwnedBundle("");
                defer error_bundle.deinit(gpa);
                error_bundle.renderToStdErr(renderOptions(color));
                process.exit(2);
            }
        } else if (tree.errors.len != 0) {
            try printAstErrorsToStderr(gpa, tree, "<stdin>", color);
            process.exit(2);
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
    LockViolation,
    NetNameDeleted,
    InvalidArgument,
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

        if (is_dir or entry.kind == .File and (mem.endsWith(u8, entry.name, ".zig") or mem.endsWith(u8, entry.name, ".zon"))) {
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

    const gpa = fmt.gpa;
    const source_code = try readSourceFileToEndAlloc(
        gpa,
        &source_file,
        std.math.cast(usize, stat.size) orelse return error.FileTooBig,
    );
    defer gpa.free(source_code);

    source_file.close();
    file_closed = true;

    // Add to set after no longer possible to get error.IsDir.
    if (try fmt.seen.fetchPut(stat.inode, {})) |_| return;

    var tree = try Ast.parse(gpa, source_code, .zig);
    defer tree.deinit(gpa);

    if (tree.errors.len != 0) {
        try printAstErrorsToStderr(gpa, tree, file_path, fmt.color);
        fmt.any_error = true;
        return;
    }

    if (fmt.check_ast) {
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

        file.pkg = try Package.create(gpa, null, file.sub_file_path);
        defer file.pkg.destroy(gpa);

        if (stat.size > max_src_size)
            return error.FileTooBig;

        file.zir = try AstGen.generate(gpa, file.tree);
        file.zir_loaded = true;
        defer file.zir.deinit(gpa);

        if (file.zir.hasCompileErrors()) {
            var wip_errors: std.zig.ErrorBundle.Wip = undefined;
            try wip_errors.init(gpa);
            defer wip_errors.deinit();
            try Compilation.addZirErrorMessages(&wip_errors, &file);
            var error_bundle = try wip_errors.toOwnedBundle("");
            defer error_bundle.deinit(gpa);
            error_bundle.renderToStdErr(renderOptions(fmt.color));
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

fn printAstErrorsToStderr(gpa: Allocator, tree: Ast, path: []const u8, color: Color) !void {
    var wip_errors: std.zig.ErrorBundle.Wip = undefined;
    try wip_errors.init(gpa);
    defer wip_errors.deinit();

    try putAstErrorsIntoBundle(gpa, tree, path, &wip_errors);

    var error_bundle = try wip_errors.toOwnedBundle("");
    defer error_bundle.deinit(gpa);
    error_bundle.renderToStdErr(renderOptions(color));
}

pub fn putAstErrorsIntoBundle(
    gpa: Allocator,
    tree: Ast,
    path: []const u8,
    wip_errors: *std.zig.ErrorBundle.Wip,
) !void {
    var file: Module.File = .{
        .status = .never_loaded,
        .source_loaded = true,
        .zir_loaded = false,
        .sub_file_path = path,
        .source = tree.source,
        .stat = .{
            .size = 0,
            .inode = 0,
            .mtime = 0,
        },
        .tree = tree,
        .tree_loaded = true,
        .zir = undefined,
        .pkg = undefined,
        .root_decl = .none,
    };

    file.pkg = try Package.create(gpa, null, path);
    defer file.pkg.destroy(gpa);

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    defer file.zir.deinit(gpa);

    try Compilation.addZirErrorMessages(wip_errors, &file);
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

extern fn ZigClangIsLLVMUsingSeparateLibcxx() bool;

extern "c" fn ZigClang_main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;
extern "c" fn ZigLlvmAr_main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;

fn argsCopyZ(alloc: Allocator, args: []const []const u8) ![:null]?[*:0]u8 {
    var argv = try alloc.allocSentinel(?[*:0]u8, args.len, null);
    for (args, 0..) |arg, i| {
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
        r,
        m,
        x,
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
        gdwarf32,
        gdwarf64,
        sanitize,
        linker_script,
        dry_run,
        verbose,
        for_linker,
        linker_input_z,
        lib_dir,
        mcpu,
        dep_file,
        dep_file_to_stdout,
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
        stack_protector,
        no_stack_protector,
        strip,
        exec_model,
        emit_llvm,
        sysroot,
        entry,
        force_undefined_symbol,
        weak_library,
        weak_framework,
        headerpad_max_install_names,
        compress_debug_sections,
        install_name,
        undefined,
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
        var arg = self.argv[self.next_index];
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
            const resp_arg_slice = try resp_arg_list.toOwnedSlice();
            self.next_index = 0;
            self.argv = resp_arg_slice;

            if (resp_arg_slice.len == 0) {
                self.resolveRespFileArgs();
                return;
            }

            self.has_next = true;
            self.other_args = (self.argv.ptr + self.next_index)[0..1]; // We adjust len below when necessary.
            arg = self.argv[self.next_index];
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

fn detectNativeTargetInfo(cross_target: std.zig.CrossTarget) !std.zig.system.NativeTargetInfo {
    return std.zig.system.NativeTargetInfo.detect(cross_target);
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
            fatal("unable to read stdin: {}", .{err});
        };
        file.sub_file_path = "<stdin>";
        file.source = source;
        file.source_loaded = true;
        file.stat.size = source.len;
    }

    file.pkg = try Package.create(gpa, null, file.sub_file_path);
    defer file.pkg.destroy(gpa);

    file.tree = try Ast.parse(gpa, file.source, .zig);
    file.tree_loaded = true;
    defer file.tree.deinit(gpa);

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    defer file.zir.deinit(gpa);

    if (file.zir.hasCompileErrors()) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(gpa);
        defer wip_errors.deinit();
        try Compilation.addZirErrorMessages(&wip_errors, &file);
        var error_bundle = try wip_errors.toOwnedBundle("");
        defer error_bundle.deinit(gpa);
        error_bundle.renderToStdErr(renderOptions(color));
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
pub fn cmdDumpZir(
    gpa: Allocator,
    arena: Allocator,
    args: []const []const u8,
) !void {
    _ = arena;
    const Zir = @import("Zir.zig");

    const cache_file = args[0];

    var f = fs.cwd().openFile(cache_file, .{}) catch |err| {
        fatal("unable to open zir cache file for dumping '{s}': {s}", .{ cache_file, @errorName(err) });
    };
    defer f.close();

    var file: Module.File = .{
        .status = .never_loaded,
        .source_loaded = false,
        .tree_loaded = false,
        .zir_loaded = true,
        .sub_file_path = undefined,
        .source = undefined,
        .stat = undefined,
        .tree = undefined,
        .zir = try Module.loadZirCache(gpa, f),
        .pkg = undefined,
        .root_decl = .none,
    };

    {
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
            \\# Total ZIR bytes:    {}
            \\# Instructions:       {d} ({})
            \\# String Table Bytes: {}
            \\# Extra Data Items:   {d} ({})
            \\
        , .{
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
    const color: Color = .auto;
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

    file.tree = try Ast.parse(gpa, file.source, .zig);
    file.tree_loaded = true;
    defer file.tree.deinit(gpa);

    file.zir = try AstGen.generate(gpa, file.tree);
    file.zir_loaded = true;
    defer file.zir.deinit(gpa);

    if (file.zir.hasCompileErrors()) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(gpa);
        defer wip_errors.deinit();
        try Compilation.addZirErrorMessages(&wip_errors, &file);
        var error_bundle = try wip_errors.toOwnedBundle("");
        defer error_bundle.deinit(gpa);
        error_bundle.renderToStdErr(renderOptions(color));
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

    var new_tree = try Ast.parse(gpa, new_source, .zig);
    defer new_tree.deinit(gpa);

    var old_zir = file.zir;
    defer old_zir.deinit(gpa);
    file.zir_loaded = false;
    file.zir = try AstGen.generate(gpa, new_tree);
    file.zir_loaded = true;

    if (file.zir.hasCompileErrors()) {
        var wip_errors: std.zig.ErrorBundle.Wip = undefined;
        try wip_errors.init(gpa);
        defer wip_errors.deinit();
        try Compilation.addZirErrorMessages(&wip_errors, &file);
        var error_bundle = try wip_errors.toOwnedBundle("");
        defer error_bundle.deinit(gpa);
        error_bundle.renderToStdErr(renderOptions(color));
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
    arena: Allocator,
    arg_mode: ArgMode,
    target_info: std.zig.system.NativeTargetInfo,
    link_libc: bool,
) !void {
    const host_cross_target: std.zig.CrossTarget = .{};
    const host_target_info = try detectNativeTargetInfo(host_cross_target);

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

/// Model a header searchlist as a group.
/// Silently ignore superfluous search dirs.
/// Warn when a dir is added to multiple searchlists.
const ClangSearchSanitizer = struct {
    argv: *std.ArrayList([]const u8),
    map: std.StringHashMap(Membership),

    fn init(gpa: Allocator, argv: *std.ArrayList([]const u8)) @This() {
        return .{
            .argv = argv,
            .map = std.StringHashMap(Membership).init(gpa),
        };
    }

    fn addIncludePath(self: *@This(), group: Group, arg: []const u8, dir: []const u8, joined: bool) !void {
        const gopr = try self.map.getOrPut(dir);
        const m = gopr.value_ptr;
        if (!gopr.found_existing) {
            // init empty membership
            m.* = .{};
        }
        const wtxt = "add '{s}' to header searchlist '-{s}' conflicts with '-{s}'";
        switch (group) {
            .I => {
                if (m.I) return;
                m.I = true;
                if (m.isystem) std.log.warn(wtxt, .{ dir, "I", "isystem" });
                if (m.idirafter) std.log.warn(wtxt, .{ dir, "I", "idirafter" });
                if (m.iframework) std.log.warn(wtxt, .{ dir, "I", "iframework" });
            },
            .isystem => {
                if (m.isystem) return;
                m.isystem = true;
                if (m.I) std.log.warn(wtxt, .{ dir, "isystem", "I" });
                if (m.idirafter) std.log.warn(wtxt, .{ dir, "isystem", "idirafter" });
                if (m.iframework) std.log.warn(wtxt, .{ dir, "isystem", "iframework" });
            },
            .idirafter => {
                if (m.idirafter) return;
                m.idirafter = true;
                if (m.I) std.log.warn(wtxt, .{ dir, "idirafter", "I" });
                if (m.isystem) std.log.warn(wtxt, .{ dir, "idirafter", "isystem" });
                if (m.iframework) std.log.warn(wtxt, .{ dir, "idirafter", "iframework" });
            },
            .iframework => {
                if (m.iframework) return;
                m.iframework = true;
                if (m.I) std.log.warn(wtxt, .{ dir, "iframework", "I" });
                if (m.isystem) std.log.warn(wtxt, .{ dir, "iframework", "isystem" });
                if (m.idirafter) std.log.warn(wtxt, .{ dir, "iframework", "idirafter" });
            },
        }
        try self.argv.append(arg);
        if (!joined) try self.argv.append(dir);
    }

    const Group = enum { I, isystem, idirafter, iframework };

    const Membership = packed struct {
        I: bool = false,
        isystem: bool = false,
        idirafter: bool = false,
        iframework: bool = false,
    };
};

fn get_tty_conf(color: Color) std.debug.TTY.Config {
    return switch (color) {
        .auto => std.debug.detectTTYConfig(std.io.getStdErr()),
        .on => .escape_codes,
        .off => .no_color,
    };
}

fn renderOptions(color: Color) std.zig.ErrorBundle.RenderOptions {
    const ttyconf = get_tty_conf(color);
    return .{
        .ttyconf = ttyconf,
        .include_source_line = ttyconf != .no_color,
        .include_reference_trace = ttyconf != .no_color,
    };
}
