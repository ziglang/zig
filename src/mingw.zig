const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const path = std.fs.path;
const assert = std.debug.assert;
const log = std.log.scoped(.mingw);

const builtin = @import("builtin");
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const Cache = std.Build.Cache;

pub const CRTFile = enum {
    crt2_o,
    dllcrt2_o,
    mingw32_lib,
};

pub fn buildCRTFile(comp: *Compilation, crt_file: CRTFile, prog_node: std.Progress.Node) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }
    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    switch (crt_file) {
        .crt2_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_cc_args(comp, arena, &args);
            if (comp.mingw_unicode_entry_point) {
                try args.appendSlice(&.{ "-DUNICODE", "-D_UNICODE" });
            }
            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", "mingw", "crt", "crtexe.c",
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                },
            };
            return comp.build_crt_file("crt2", .Obj, .@"mingw-w64 crt2.o", prog_node, &files);
        },

        .dllcrt2_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_cc_args(comp, arena, &args);
            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", "mingw", "crt", "crtdll.c",
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                },
            };
            return comp.build_crt_file("dllcrt2", .Obj, .@"mingw-w64 dllcrt2.o", prog_node, &files);
        },

        .mingw32_lib => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_cc_args(comp, arena, &args);
            var c_source_files = std.ArrayList(Compilation.CSourceFile).init(arena);

            for (mingw32_generic_src) |dep| {
                try c_source_files.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", "mingw", dep,
                    }),
                    .extra_flags = args.items,
                    .owner = undefined,
                });
            }
            const target = comp.getTarget();
            if (target.cpu.arch == .x86 or target.cpu.arch == .x86_64) {
                for (mingw32_x86_src) |dep| {
                    try c_source_files.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", "mingw", dep,
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
                if (target.cpu.arch == .x86) {
                    for (mingw32_x86_32_src) |dep| {
                        try c_source_files.append(.{
                            .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                                "libc", "mingw", dep,
                            }),
                            .extra_flags = args.items,
                            .owner = undefined,
                        });
                    }
                }
            } else if (target.cpu.arch.isARM()) {
                for (mingw32_arm32_src) |dep| {
                    try c_source_files.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", "mingw", dep,
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            } else if (target.cpu.arch.isAARCH64()) {
                for (mingw32_arm64_src) |dep| {
                    try c_source_files.append(.{
                        .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                            "libc", "mingw", dep,
                        }),
                        .extra_flags = args.items,
                        .owner = undefined,
                    });
                }
            } else {
                @panic("unsupported arch");
            }
            return comp.build_crt_file("mingw32", .Lib, .@"mingw-w64 mingw32.lib", prog_node, c_source_files.items);
        },
    }
}

fn add_cc_args(
    comp: *Compilation,
    arena: Allocator,
    args: *std.ArrayList([]const u8),
) error{OutOfMemory}!void {
    try args.appendSlice(&[_][]const u8{
        "-DHAVE_CONFIG_H",

        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "mingw", "include" }),

        "-isystem",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "include", "any-windows-any" }),
    });

    const target = comp.getTarget();
    if (target.cpu.arch.isARM() and target.ptrBitWidth() == 32) {
        try args.append("-mfpu=vfp");
    }

    try args.appendSlice(&[_][]const u8{
        "-std=gnu11",
        "-D_CRTBLD",
        "-D_SYSCRT=1",
        "-DCRTDLL=1",
        "-D_WIN32_WINNT=0x0f00",
        // According to Martin Storsjö,
        // > the files under mingw-w64-crt are designed to always
        // be built with __MSVCRT_VERSION__=0x700
        "-D__MSVCRT_VERSION__=0x700",
        "-D__USE_MINGW_ANSI_STDIO=0",
    });
}

pub fn buildImportLib(comp: *Compilation, lib_name: []const u8) !void {
    if (build_options.only_c) @compileError("building import libs not included in core functionality");
    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const def_file_path = findDef(arena, comp.getTarget(), comp.zig_lib_directory, lib_name) catch |err| switch (err) {
        error.FileNotFound => {
            log.debug("no {s}.def file available to make a DLL import {s}.lib", .{ lib_name, lib_name });
            // In this case we will end up putting foo.lib onto the linker line and letting the linker
            // use its library paths to look for libraries and report any problems.
            return;
        },
        else => |e| return e,
    };

    const target = comp.getTarget();

    // Use the global cache directory.
    var cache: Cache = .{
        .gpa = comp.gpa,
        .manifest_dir = try comp.global_cache_directory.handle.makeOpenPath("h", .{}),
    };
    cache.addPrefix(.{ .path = null, .handle = std.fs.cwd() });
    cache.addPrefix(comp.zig_lib_directory);
    cache.addPrefix(comp.global_cache_directory);
    defer cache.manifest_dir.close();

    cache.hash.addBytes(build_options.version);
    cache.hash.addOptionalBytes(comp.zig_lib_directory.path);
    cache.hash.add(target.cpu.arch);

    var man = cache.obtain();
    defer man.deinit();

    _ = try man.addFile(def_file_path, null);

    const final_lib_basename = try std.fmt.allocPrint(comp.gpa, "{s}.lib", .{lib_name});
    errdefer comp.gpa.free(final_lib_basename);

    if (try man.hit()) {
        const digest = man.final();

        try comp.crt_files.ensureUnusedCapacity(comp.gpa, 1);
        comp.crt_files.putAssumeCapacityNoClobber(final_lib_basename, .{
            .full_object_path = try comp.global_cache_directory.join(comp.gpa, &[_][]const u8{
                "o", &digest, final_lib_basename,
            }),
            .lock = man.toOwnedLock(),
        });
        return;
    }

    const digest = man.final();
    const o_sub_path = try std.fs.path.join(arena, &[_][]const u8{ "o", &digest });
    var o_dir = try comp.global_cache_directory.handle.makeOpenPath(o_sub_path, .{});
    defer o_dir.close();

    const final_def_basename = try std.fmt.allocPrint(arena, "{s}.def", .{lib_name});
    const def_final_path = try comp.global_cache_directory.join(arena, &[_][]const u8{
        "o", &digest, final_def_basename,
    });

    const target_defines = switch (target.cpu.arch) {
        .x86 => "#define DEF_I386\n",
        .x86_64 => "#define DEF_X64\n",
        .arm, .armeb, .thumb, .thumbeb, .aarch64_32 => "#define DEF_ARM32\n",
        .aarch64, .aarch64_be => "#define DEF_ARM64\n",
        else => unreachable,
    };

    const aro = @import("aro");
    var aro_comp = aro.Compilation.init(comp.gpa);
    defer aro_comp.deinit();

    const include_dir = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "mingw", "def-include" });

    if (comp.verbose_cc) print: {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print("def file: {s}\n", .{def_file_path}) catch break :print;
        nosuspend stderr.print("include dir: {s}\n", .{include_dir}) catch break :print;
        nosuspend stderr.print("output path: {s}\n", .{def_final_path}) catch break :print;
    }

    try aro_comp.include_dirs.append(comp.gpa, include_dir);

    const builtin_macros = try aro_comp.generateBuiltinMacros(.include_system_defines);
    const user_macros = try aro_comp.addSourceFromBuffer("<command line>", target_defines);
    const def_file_source = try aro_comp.addSourceFromPath(def_file_path);

    var pp = aro.Preprocessor.init(&aro_comp);
    defer pp.deinit();
    pp.linemarkers = .none;
    pp.preserve_whitespace = true;

    try pp.preprocessSources(&.{ def_file_source, builtin_macros, user_macros });

    for (aro_comp.diagnostics.list.items) |diagnostic| {
        if (diagnostic.kind == .@"fatal error" or diagnostic.kind == .@"error") {
            aro.Diagnostics.render(&aro_comp, std.io.tty.detectConfig(std.io.getStdErr()));
            return error.AroPreprocessorFailed;
        }
    }

    {
        // new scope to ensure definition file is written before passing the path to WriteImportLibrary
        const def_final_file = try o_dir.createFile(final_def_basename, .{ .truncate = true });
        defer def_final_file.close();
        try pp.prettyPrintTokens(def_final_file.writer());
    }

    const lib_final_path = try comp.global_cache_directory.join(comp.gpa, &[_][]const u8{
        "o", &digest, final_lib_basename,
    });
    errdefer comp.gpa.free(lib_final_path);

    if (!build_options.have_llvm) return error.ZigCompilerNotBuiltWithLLVMExtensions;
    const llvm_bindings = @import("codegen/llvm/bindings.zig");
    const llvm = @import("codegen/llvm.zig");
    const arch_tag = llvm.targetArch(target.cpu.arch);
    const def_final_path_z = try arena.dupeZ(u8, def_final_path);
    const lib_final_path_z = try arena.dupeZ(u8, lib_final_path);
    if (llvm_bindings.WriteImportLibrary(def_final_path_z.ptr, arch_tag, lib_final_path_z.ptr, true)) {
        // TODO surface a proper error here
        log.err("unable to turn {s}.def into {s}.lib", .{ lib_name, lib_name });
        return error.WritingImportLibFailed;
    }

    man.writeManifest() catch |err| {
        log.warn("failed to write cache manifest for DLL import {s}.lib: {s}", .{ lib_name, @errorName(err) });
    };

    try comp.crt_files.putNoClobber(comp.gpa, final_lib_basename, .{
        .full_object_path = lib_final_path,
        .lock = man.toOwnedLock(),
    });
}

pub fn libExists(
    allocator: Allocator,
    target: std.Target,
    zig_lib_directory: Cache.Directory,
    lib_name: []const u8,
) !bool {
    const s = findDef(allocator, target, zig_lib_directory, lib_name) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    defer allocator.free(s);
    return true;
}

/// This function body is verbose but all it does is test 3 different paths and
/// see if a .def file exists.
fn findDef(
    allocator: Allocator,
    target: std.Target,
    zig_lib_directory: Cache.Directory,
    lib_name: []const u8,
) ![]u8 {
    const lib_path = switch (target.cpu.arch) {
        .x86 => "lib32",
        .x86_64 => "lib64",
        .arm, .armeb, .thumb, .thumbeb, .aarch64_32 => "libarm32",
        .aarch64, .aarch64_be => "libarm64",
        else => unreachable,
    };

    var override_path = std.ArrayList(u8).init(allocator);
    defer override_path.deinit();

    const s = path.sep_str;

    {
        // Try the archtecture-specific path first.
        const fmt_path = "libc" ++ s ++ "mingw" ++ s ++ "{s}" ++ s ++ "{s}.def";
        if (zig_lib_directory.path) |p| {
            try override_path.writer().print("{s}" ++ s ++ fmt_path, .{ p, lib_path, lib_name });
        } else {
            try override_path.writer().print(fmt_path, .{ lib_path, lib_name });
        }
        if (std.fs.cwd().access(override_path.items, .{})) |_| {
            return override_path.toOwnedSlice();
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        }
    }

    {
        // Try the generic version.
        override_path.shrinkRetainingCapacity(0);
        const fmt_path = "libc" ++ s ++ "mingw" ++ s ++ "lib-common" ++ s ++ "{s}.def";
        if (zig_lib_directory.path) |p| {
            try override_path.writer().print("{s}" ++ s ++ fmt_path, .{ p, lib_name });
        } else {
            try override_path.writer().print(fmt_path, .{lib_name});
        }
        if (std.fs.cwd().access(override_path.items, .{})) |_| {
            return override_path.toOwnedSlice();
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        }
    }

    {
        // Try the generic version and preprocess it.
        override_path.shrinkRetainingCapacity(0);
        const fmt_path = "libc" ++ s ++ "mingw" ++ s ++ "lib-common" ++ s ++ "{s}.def.in";
        if (zig_lib_directory.path) |p| {
            try override_path.writer().print("{s}" ++ s ++ fmt_path, .{ p, lib_name });
        } else {
            try override_path.writer().print(fmt_path, .{lib_name});
        }
        if (std.fs.cwd().access(override_path.items, .{})) |_| {
            return override_path.toOwnedSlice();
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        }
    }

    return error.FileNotFound;
}

const mingw32_generic_src = [_][]const u8{
    // mingw32
    "crt" ++ path.sep_str ++ "crtexewin.c",
    "crt" ++ path.sep_str ++ "dll_argv.c",
    "crt" ++ path.sep_str ++ "gccmain.c",
    "crt" ++ path.sep_str ++ "natstart.c",
    "crt" ++ path.sep_str ++ "pseudo-reloc-list.c",
    "crt" ++ path.sep_str ++ "wildcard.c",
    "crt" ++ path.sep_str ++ "charmax.c",
    "crt" ++ path.sep_str ++ "ucrtexewin.c",
    "crt" ++ path.sep_str ++ "dllargv.c",
    "crt" ++ path.sep_str ++ "_newmode.c",
    "crt" ++ path.sep_str ++ "tlssup.c",
    "crt" ++ path.sep_str ++ "xncommod.c",
    "crt" ++ path.sep_str ++ "cinitexe.c",
    "crt" ++ path.sep_str ++ "merr.c",
    "crt" ++ path.sep_str ++ "usermatherr.c",
    "crt" ++ path.sep_str ++ "pesect.c",
    "crt" ++ path.sep_str ++ "udllargc.c",
    "crt" ++ path.sep_str ++ "xthdloc.c",
    "crt" ++ path.sep_str ++ "CRT_fp10.c",
    "crt" ++ path.sep_str ++ "mingw_helpers.c",
    "crt" ++ path.sep_str ++ "pseudo-reloc.c",
    "crt" ++ path.sep_str ++ "udll_argv.c",
    "crt" ++ path.sep_str ++ "xtxtmode.c",
    "crt" ++ path.sep_str ++ "crt_handler.c",
    "crt" ++ path.sep_str ++ "tlsthrd.c",
    "crt" ++ path.sep_str ++ "tlsmthread.c",
    "crt" ++ path.sep_str ++ "tlsmcrt.c",
    "crt" ++ path.sep_str ++ "cxa_atexit.c",
    "crt" ++ path.sep_str ++ "cxa_thread_atexit.c",
    "crt" ++ path.sep_str ++ "tls_atexit.c",
    // mingwex
    "cfguard" ++ path.sep_str ++ "mingw_cfguard_support.c",
    "complex" ++ path.sep_str ++ "_cabs.c",
    "complex" ++ path.sep_str ++ "cabs.c",
    "complex" ++ path.sep_str ++ "cabsf.c",
    "complex" ++ path.sep_str ++ "cabsl.c",
    "complex" ++ path.sep_str ++ "cacos.c",
    "complex" ++ path.sep_str ++ "cacosf.c",
    "complex" ++ path.sep_str ++ "cacosl.c",
    "complex" ++ path.sep_str ++ "carg.c",
    "complex" ++ path.sep_str ++ "cargf.c",
    "complex" ++ path.sep_str ++ "cargl.c",
    "complex" ++ path.sep_str ++ "casin.c",
    "complex" ++ path.sep_str ++ "casinf.c",
    "complex" ++ path.sep_str ++ "casinl.c",
    "complex" ++ path.sep_str ++ "catan.c",
    "complex" ++ path.sep_str ++ "catanf.c",
    "complex" ++ path.sep_str ++ "catanl.c",
    "complex" ++ path.sep_str ++ "ccos.c",
    "complex" ++ path.sep_str ++ "ccosf.c",
    "complex" ++ path.sep_str ++ "ccosl.c",
    "complex" ++ path.sep_str ++ "cexp.c",
    "complex" ++ path.sep_str ++ "cexpf.c",
    "complex" ++ path.sep_str ++ "cexpl.c",
    "complex" ++ path.sep_str ++ "cimag.c",
    "complex" ++ path.sep_str ++ "cimagf.c",
    "complex" ++ path.sep_str ++ "cimagl.c",
    "complex" ++ path.sep_str ++ "clog.c",
    "complex" ++ path.sep_str ++ "clog10.c",
    "complex" ++ path.sep_str ++ "clog10f.c",
    "complex" ++ path.sep_str ++ "clog10l.c",
    "complex" ++ path.sep_str ++ "clogf.c",
    "complex" ++ path.sep_str ++ "clogl.c",
    "complex" ++ path.sep_str ++ "conj.c",
    "complex" ++ path.sep_str ++ "conjf.c",
    "complex" ++ path.sep_str ++ "conjl.c",
    "complex" ++ path.sep_str ++ "cpow.c",
    "complex" ++ path.sep_str ++ "cpowf.c",
    "complex" ++ path.sep_str ++ "cpowl.c",
    "complex" ++ path.sep_str ++ "cproj.c",
    "complex" ++ path.sep_str ++ "cprojf.c",
    "complex" ++ path.sep_str ++ "cprojl.c",
    "complex" ++ path.sep_str ++ "creal.c",
    "complex" ++ path.sep_str ++ "crealf.c",
    "complex" ++ path.sep_str ++ "creall.c",
    "complex" ++ path.sep_str ++ "csin.c",
    "complex" ++ path.sep_str ++ "csinf.c",
    "complex" ++ path.sep_str ++ "csinl.c",
    "complex" ++ path.sep_str ++ "csqrt.c",
    "complex" ++ path.sep_str ++ "csqrtf.c",
    "complex" ++ path.sep_str ++ "csqrtl.c",
    "complex" ++ path.sep_str ++ "ctan.c",
    "complex" ++ path.sep_str ++ "ctanf.c",
    "complex" ++ path.sep_str ++ "ctanl.c",
    "crt" ++ path.sep_str ++ "dllentry.c",
    "crt" ++ path.sep_str ++ "dllmain.c",
    "gdtoa" ++ path.sep_str ++ "arithchk.c",
    "gdtoa" ++ path.sep_str ++ "dmisc.c",
    "gdtoa" ++ path.sep_str ++ "dtoa.c",
    "gdtoa" ++ path.sep_str ++ "g__fmt.c",
    "gdtoa" ++ path.sep_str ++ "g_dfmt.c",
    "gdtoa" ++ path.sep_str ++ "g_ffmt.c",
    "gdtoa" ++ path.sep_str ++ "g_xfmt.c",
    "gdtoa" ++ path.sep_str ++ "gdtoa.c",
    "gdtoa" ++ path.sep_str ++ "gethex.c",
    "gdtoa" ++ path.sep_str ++ "gmisc.c",
    "gdtoa" ++ path.sep_str ++ "hd_init.c",
    "gdtoa" ++ path.sep_str ++ "hexnan.c",
    "gdtoa" ++ path.sep_str ++ "misc.c",
    "gdtoa" ++ path.sep_str ++ "qnan.c",
    "gdtoa" ++ path.sep_str ++ "smisc.c",
    "gdtoa" ++ path.sep_str ++ "strtodg.c",
    "gdtoa" ++ path.sep_str ++ "strtodnrp.c",
    "gdtoa" ++ path.sep_str ++ "strtof.c",
    "gdtoa" ++ path.sep_str ++ "strtopx.c",
    "gdtoa" ++ path.sep_str ++ "sum.c",
    "gdtoa" ++ path.sep_str ++ "ulp.c",
    "math" ++ path.sep_str ++ "coshl.c",
    "math" ++ path.sep_str ++ "fabsl.c",
    "math" ++ path.sep_str ++ "fp_consts.c",
    "math" ++ path.sep_str ++ "fp_constsf.c",
    "math" ++ path.sep_str ++ "fp_constsl.c",
    "math" ++ path.sep_str ++ "fpclassify.c",
    "math" ++ path.sep_str ++ "fpclassifyf.c",
    "math" ++ path.sep_str ++ "fpclassifyl.c",
    "math" ++ path.sep_str ++ "frexpf.c",
    "math" ++ path.sep_str ++ "frexpl.c",
    "math" ++ path.sep_str ++ "hypotf.c",
    "math" ++ path.sep_str ++ "hypotl.c",
    "math" ++ path.sep_str ++ "isnan.c",
    "math" ++ path.sep_str ++ "isnanf.c",
    "math" ++ path.sep_str ++ "isnanl.c",
    "math" ++ path.sep_str ++ "ldexpf.c",
    "math" ++ path.sep_str ++ "lgamma.c",
    "math" ++ path.sep_str ++ "lgammaf.c",
    "math" ++ path.sep_str ++ "lgammal.c",
    "math" ++ path.sep_str ++ "modfl.c",
    "math" ++ path.sep_str ++ "nextafterl.c",
    "math" ++ path.sep_str ++ "nexttoward.c",
    "math" ++ path.sep_str ++ "powi.c",
    "math" ++ path.sep_str ++ "powif.c",
    "math" ++ path.sep_str ++ "powil.c",
    "math" ++ path.sep_str ++ "signbit.c",
    "math" ++ path.sep_str ++ "signbitf.c",
    "math" ++ path.sep_str ++ "signbitl.c",
    "math" ++ path.sep_str ++ "signgam.c",
    "math" ++ path.sep_str ++ "sinhl.c",
    "math" ++ path.sep_str ++ "sqrtl.c",
    "math" ++ path.sep_str ++ "tanhl.c",
    "misc" ++ path.sep_str ++ "alarm.c",
    "misc" ++ path.sep_str ++ "btowc.c",
    "misc" ++ path.sep_str ++ "delay-f.c",
    "misc" ++ path.sep_str ++ "delay-n.c",
    "misc" ++ path.sep_str ++ "delayimp.c",
    "misc" ++ path.sep_str ++ "dirent.c",
    "misc" ++ path.sep_str ++ "dirname.c",
    "misc" ++ path.sep_str ++ "feclearexcept.c",
    "misc" ++ path.sep_str ++ "fegetenv.c",
    "misc" ++ path.sep_str ++ "fegetexceptflag.c",
    "misc" ++ path.sep_str ++ "fegetround.c",
    "misc" ++ path.sep_str ++ "feholdexcept.c",
    "misc" ++ path.sep_str ++ "feraiseexcept.c",
    "misc" ++ path.sep_str ++ "fesetenv.c",
    "misc" ++ path.sep_str ++ "fesetexceptflag.c",
    "misc" ++ path.sep_str ++ "fesetround.c",
    "misc" ++ path.sep_str ++ "fetestexcept.c",
    "misc" ++ path.sep_str ++ "feupdateenv.c",
    "misc" ++ path.sep_str ++ "ftruncate.c",
    "misc" ++ path.sep_str ++ "ftw.c",
    "misc" ++ path.sep_str ++ "ftw64.c",
    "misc" ++ path.sep_str ++ "fwide.c",
    "misc" ++ path.sep_str ++ "getlogin.c",
    "misc" ++ path.sep_str ++ "getopt.c",
    "misc" ++ path.sep_str ++ "gettimeofday.c",
    "misc" ++ path.sep_str ++ "isblank.c",
    "misc" ++ path.sep_str ++ "iswblank.c",
    "misc" ++ path.sep_str ++ "mempcpy.c",
    "misc" ++ path.sep_str ++ "mingw-access.c",
    "misc" ++ path.sep_str ++ "mingw-aligned-malloc.c",
    "misc" ++ path.sep_str ++ "mingw_getsp.S",
    "misc" ++ path.sep_str ++ "mingw_longjmp.S",
    "misc" ++ path.sep_str ++ "mingw_matherr.c",
    "misc" ++ path.sep_str ++ "mingw_mbwc_convert.c",
    "misc" ++ path.sep_str ++ "mingw_usleep.c",
    "misc" ++ path.sep_str ++ "mingw_wcstod.c",
    "misc" ++ path.sep_str ++ "mingw_wcstof.c",
    "misc" ++ path.sep_str ++ "mingw_wcstold.c",
    "misc" ++ path.sep_str ++ "mkstemp.c",
    "misc" ++ path.sep_str ++ "sleep.c",
    "misc" ++ path.sep_str ++ "strnlen.c",
    "misc" ++ path.sep_str ++ "strsafe.c",
    "misc" ++ path.sep_str ++ "tdelete.c",
    "misc" ++ path.sep_str ++ "tdestroy.c",
    "misc" ++ path.sep_str ++ "tfind.c",
    "misc" ++ path.sep_str ++ "tsearch.c",
    "misc" ++ path.sep_str ++ "twalk.c",
    "misc" ++ path.sep_str ++ "wcsnlen.c",
    "misc" ++ path.sep_str ++ "wcstof.c",
    "misc" ++ path.sep_str ++ "wcstoimax.c",
    "misc" ++ path.sep_str ++ "wcstold.c",
    "misc" ++ path.sep_str ++ "wcstoumax.c",
    "misc" ++ path.sep_str ++ "wctob.c",
    "misc" ++ path.sep_str ++ "wctrans.c",
    "misc" ++ path.sep_str ++ "wctype.c",
    "misc" ++ path.sep_str ++ "wdirent.c",
    "misc" ++ path.sep_str ++ "winbs_uint64.c",
    "misc" ++ path.sep_str ++ "winbs_ulong.c",
    "misc" ++ path.sep_str ++ "winbs_ushort.c",
    "misc" ++ path.sep_str ++ "wmemchr.c",
    "misc" ++ path.sep_str ++ "wmemcmp.c",
    "misc" ++ path.sep_str ++ "wmemcpy.c",
    "misc" ++ path.sep_str ++ "wmemmove.c",
    "misc" ++ path.sep_str ++ "wmempcpy.c",
    "misc" ++ path.sep_str ++ "wmemset.c",
    "stdio" ++ path.sep_str ++ "_Exit.c",
    "stdio" ++ path.sep_str ++ "_findfirst64i32.c",
    "stdio" ++ path.sep_str ++ "_findnext64i32.c",
    "stdio" ++ path.sep_str ++ "_fstat.c",
    "stdio" ++ path.sep_str ++ "_fstat64i32.c",
    "stdio" ++ path.sep_str ++ "_ftime.c",
    "stdio" ++ path.sep_str ++ "_stat.c",
    "stdio" ++ path.sep_str ++ "_stat64i32.c",
    "stdio" ++ path.sep_str ++ "_wfindfirst64i32.c",
    "stdio" ++ path.sep_str ++ "_wfindnext64i32.c",
    "stdio" ++ path.sep_str ++ "_wstat.c",
    "stdio" ++ path.sep_str ++ "_wstat64i32.c",
    "stdio" ++ path.sep_str ++ "asprintf.c",
    "stdio" ++ path.sep_str ++ "fgetpos64.c",
    "stdio" ++ path.sep_str ++ "fopen64.c",
    "stdio" ++ path.sep_str ++ "fseeko32.c",
    "stdio" ++ path.sep_str ++ "fseeko64.c",
    "stdio" ++ path.sep_str ++ "fsetpos64.c",
    "stdio" ++ path.sep_str ++ "ftello.c",
    "stdio" ++ path.sep_str ++ "ftello64.c",
    "stdio" ++ path.sep_str ++ "ftruncate64.c",
    "stdio" ++ path.sep_str ++ "lltoa.c",
    "stdio" ++ path.sep_str ++ "lltow.c",
    "stdio" ++ path.sep_str ++ "lseek64.c",
    "stdio" ++ path.sep_str ++ "mingw_asprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_fprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_fprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_fscanf.c",
    "stdio" ++ path.sep_str ++ "mingw_fwscanf.c",
    "stdio" ++ path.sep_str ++ "mingw_pformat.c",
    "stdio" ++ path.sep_str ++ "mingw_pformatw.c",
    "stdio" ++ path.sep_str ++ "mingw_printf.c",
    "stdio" ++ path.sep_str ++ "mingw_printfw.c",
    "stdio" ++ path.sep_str ++ "mingw_scanf.c",
    "stdio" ++ path.sep_str ++ "mingw_snprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_snprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_sprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_sprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_sscanf.c",
    "stdio" ++ path.sep_str ++ "mingw_swscanf.c",
    "stdio" ++ path.sep_str ++ "mingw_vasprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_vfprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_vfprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_vfscanf.c",
    "stdio" ++ path.sep_str ++ "mingw_vprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_vprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_vsnprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_vsnprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_vsprintf.c",
    "stdio" ++ path.sep_str ++ "mingw_vsprintfw.c",
    "stdio" ++ path.sep_str ++ "mingw_wscanf.c",
    "stdio" ++ path.sep_str ++ "mingw_wvfscanf.c",
    "stdio" ++ path.sep_str ++ "scanf2-argcount-char.c",
    "stdio" ++ path.sep_str ++ "scanf2-argcount-wchar.c",
    "stdio" ++ path.sep_str ++ "scanf.S",
    "stdio" ++ path.sep_str ++ "snprintf.c",
    "stdio" ++ path.sep_str ++ "snwprintf.c",
    "stdio" ++ path.sep_str ++ "strtok_r.c",
    "stdio" ++ path.sep_str ++ "truncate.c",
    "stdio" ++ path.sep_str ++ "ulltoa.c",
    "stdio" ++ path.sep_str ++ "ulltow.c",
    "stdio" ++ path.sep_str ++ "vasprintf.c",
    "stdio" ++ path.sep_str ++ "vfscanf.c",
    "stdio" ++ path.sep_str ++ "vfscanf2.S",
    "stdio" ++ path.sep_str ++ "vfwscanf.c",
    "stdio" ++ path.sep_str ++ "vfwscanf2.S",
    "stdio" ++ path.sep_str ++ "vscanf.c",
    "stdio" ++ path.sep_str ++ "vscanf2.S",
    "stdio" ++ path.sep_str ++ "vsnprintf.c",
    "stdio" ++ path.sep_str ++ "vsnwprintf.c",
    "stdio" ++ path.sep_str ++ "vsscanf.c",
    "stdio" ++ path.sep_str ++ "vsscanf2.S",
    "stdio" ++ path.sep_str ++ "vswscanf.c",
    "stdio" ++ path.sep_str ++ "vswscanf2.S",
    "stdio" ++ path.sep_str ++ "vwscanf.c",
    "stdio" ++ path.sep_str ++ "vwscanf2.S",
    "stdio" ++ path.sep_str ++ "wtoll.c",
    // ucrtbase
    "crt" ++ path.sep_str ++ "ucrtbase_compat.c",
    "math" ++ path.sep_str ++ "_huge.c",
    "misc" ++ path.sep_str ++ "__initenv.c",
    "misc" ++ path.sep_str ++ "ucrt-access.c",
    "stdio" ++ path.sep_str ++ "ucrt__snwprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt__vscprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt__vsnprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt__vsnwprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_fprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_fscanf.c",
    "stdio" ++ path.sep_str ++ "ucrt_fwprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_printf.c",
    "stdio" ++ path.sep_str ++ "ucrt_scanf.c",
    "stdio" ++ path.sep_str ++ "ucrt_snprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_sprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_sscanf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vfprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vfscanf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vscanf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vsnprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vsprintf.c",
    "stdio" ++ path.sep_str ++ "ucrt_vsscanf.c",
    // uuid
    "libsrc" ++ path.sep_str ++ "ativscp-uuid.c",
    "libsrc" ++ path.sep_str ++ "atsmedia-uuid.c",
    "libsrc" ++ path.sep_str ++ "bth-uuid.c",
    "libsrc" ++ path.sep_str ++ "cguid-uuid.c",
    "libsrc" ++ path.sep_str ++ "comcat-uuid.c",
    "libsrc" ++ path.sep_str ++ "ctxtcall-uuid.c",
    "libsrc" ++ path.sep_str ++ "devguid.c",
    "libsrc" ++ path.sep_str ++ "docobj-uuid.c",
    "libsrc" ++ path.sep_str ++ "dxva-uuid.c",
    "libsrc" ++ path.sep_str ++ "exdisp-uuid.c",
    "libsrc" ++ path.sep_str ++ "extras-uuid.c",
    "libsrc" ++ path.sep_str ++ "fwp-uuid.c",
    "libsrc" ++ path.sep_str ++ "guid_nul.c",
    "libsrc" ++ path.sep_str ++ "hlguids-uuid.c",
    "libsrc" ++ path.sep_str ++ "hlink-uuid.c",
    "libsrc" ++ path.sep_str ++ "mlang-uuid.c",
    "libsrc" ++ path.sep_str ++ "msctf-uuid.c",
    "libsrc" ++ path.sep_str ++ "mshtmhst-uuid.c",
    "libsrc" ++ path.sep_str ++ "mshtml-uuid.c",
    "libsrc" ++ path.sep_str ++ "msxml-uuid.c",
    "libsrc" ++ path.sep_str ++ "netcfg-uuid.c",
    "libsrc" ++ path.sep_str ++ "netcon-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddkbd-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddmou-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddpar-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddscsi-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddser-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddstor-uuid.c",
    "libsrc" ++ path.sep_str ++ "ntddvdeo-uuid.c",
    "libsrc" ++ path.sep_str ++ "oaidl-uuid.c",
    "libsrc" ++ path.sep_str ++ "objidl-uuid.c",
    "libsrc" ++ path.sep_str ++ "objsafe-uuid.c",
    "libsrc" ++ path.sep_str ++ "ocidl-uuid.c",
    "libsrc" ++ path.sep_str ++ "oleacc-uuid.c",
    "libsrc" ++ path.sep_str ++ "olectlid-uuid.c",
    "libsrc" ++ path.sep_str ++ "oleidl-uuid.c",
    "libsrc" ++ path.sep_str ++ "power-uuid.c",
    "libsrc" ++ path.sep_str ++ "powrprof-uuid.c",
    "libsrc" ++ path.sep_str ++ "uianimation-uuid.c",
    "libsrc" ++ path.sep_str ++ "usbcamdi-uuid.c",
    "libsrc" ++ path.sep_str ++ "usbiodef-uuid.c",
    "libsrc" ++ path.sep_str ++ "uuid.c",
    "libsrc" ++ path.sep_str ++ "vds-uuid.c",
    "libsrc" ++ path.sep_str ++ "virtdisk-uuid.c",
    "libsrc" ++ path.sep_str ++ "vss-uuid.c",
    "libsrc" ++ path.sep_str ++ "wia-uuid.c",
    "libsrc" ++ path.sep_str ++ "windowscodecs.c",
    // ws2_32
    "libsrc" ++ path.sep_str ++ "ws2_32.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_addr_equal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6addr_isany.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6addr_isloopback.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6addr_setany.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6addr_setloopback.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_linklocal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_loopback.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_mc_global.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_mc_linklocal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_mc_nodelocal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_mc_orglocal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_mc_sitelocal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_multicast.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_sitelocal.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_unspecified.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_v4compat.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_is_addr_v4mapped.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_set_addr_loopback.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "in6_set_addr_unspecified.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "gai_strerrorA.c",
    "libsrc" ++ path.sep_str ++ "ws2tcpip" ++ path.sep_str ++ "gai_strerrorW.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiStrdup.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiParseV4Address.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiNewAddrInfo.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiQueryDNS.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiLookupNode.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiClone.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiLegacyFreeAddrInfo.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiLegacyGetAddrInfo.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiLegacyGetNameInfo.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiLoad.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiGetAddrInfo.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiGetNameInfo.c",
    "libsrc" ++ path.sep_str ++ "wspiapi" ++ path.sep_str ++ "WspiapiFreeAddrInfo.c",
    // dinput
    "libsrc" ++ path.sep_str ++ "dinput_kbd.c",
    "libsrc" ++ path.sep_str ++ "dinput_joy.c",
    "libsrc" ++ path.sep_str ++ "dinput_joy2.c",
    "libsrc" ++ path.sep_str ++ "dinput_mouse.c",
    "libsrc" ++ path.sep_str ++ "dinput_mouse2.c",
    // dloadhelper
    "libsrc" ++ path.sep_str ++ "dloadhelper.c",
    "misc" ++ path.sep_str ++ "delay-f.c",
    // misc.
    "libsrc" ++ path.sep_str ++ "bits.c",
    "libsrc" ++ path.sep_str ++ "shell32.c",
    "libsrc" ++ path.sep_str ++ "dmoguids.c",
    "libsrc" ++ path.sep_str ++ "dxerr8.c",
    "libsrc" ++ path.sep_str ++ "dxerr8w.c",
    "libsrc" ++ path.sep_str ++ "dxerr9.c",
    "libsrc" ++ path.sep_str ++ "dxerr9w.c",
    "libsrc" ++ path.sep_str ++ "mfuuid.c",
    "libsrc" ++ path.sep_str ++ "msxml2.c",
    "libsrc" ++ path.sep_str ++ "msxml6.c",
    "libsrc" ++ path.sep_str ++ "amstrmid.c",
    "libsrc" ++ path.sep_str ++ "wbemuuid.c",
    "libsrc" ++ path.sep_str ++ "wmcodecdspuuid.c",
    "libsrc" ++ path.sep_str ++ "windowscodecs.c",
    "libsrc" ++ path.sep_str ++ "dxguid.c",
    "libsrc" ++ path.sep_str ++ "ksuser.c",
    "libsrc" ++ path.sep_str ++ "locationapi.c",
    "libsrc" ++ path.sep_str ++ "sapi.c",
    "libsrc" ++ path.sep_str ++ "sensorsapi.c",
    "libsrc" ++ path.sep_str ++ "portabledeviceguids.c",
    "libsrc" ++ path.sep_str ++ "taskschd.c",
    "libsrc" ++ path.sep_str ++ "strmiids.c",
    "libsrc" ++ path.sep_str ++ "gdiplus.c",
    "libsrc" ++ path.sep_str ++ "activeds-uuid.c",
};

const mingw32_x86_src = [_][]const u8{
    // mingwex
    "math" ++ path.sep_str ++ "cbrtl.c",
    "math" ++ path.sep_str ++ "erfl.c",
    "math" ++ path.sep_str ++ "fdiml.c",
    "math" ++ path.sep_str ++ "fmal.c",
    "math" ++ path.sep_str ++ "fmaxl.c",
    "math" ++ path.sep_str ++ "fminl.c",
    "math" ++ path.sep_str ++ "llrintl.c",
    "math" ++ path.sep_str ++ "llroundl.c",
    "math" ++ path.sep_str ++ "lrintl.c",
    "math" ++ path.sep_str ++ "lroundl.c",
    "math" ++ path.sep_str ++ "rintl.c",
    "math" ++ path.sep_str ++ "roundl.c",
    "math" ++ path.sep_str ++ "tgammal.c",
    "math" ++ path.sep_str ++ "truncl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "acoshl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "acosl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "asinhl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "asinl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "atan2l.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "atanhl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "atanl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "ceill.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "_chgsignl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "copysignl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "cosl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "cosl_internal.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "cossin.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "exp2l.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "expl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "expm1l.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "floorl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "fmodl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "fucom.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "ilogbl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "internal_logl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "ldexp.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "ldexpl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "log10l.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "log1pl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "log2l.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "logbl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "logl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "nearbyintl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "powl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "remainderl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "remquol.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "scalbnf.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "scalbnl.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "scalbn.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "sinl.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "sinl_internal.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "tanl.S",
    // ucrtbase
    "math" ++ path.sep_str ++ "fabsf.c",
    "math" ++ path.sep_str ++ "nexttowardf.c",
};

const mingw32_x86_32_src = [_][]const u8{
    "math" ++ path.sep_str ++ "coshf.c",
    "math" ++ path.sep_str ++ "expf.c",
    "math" ++ path.sep_str ++ "log10f.c",
    "math" ++ path.sep_str ++ "logf.c",
    "math" ++ path.sep_str ++ "modff.c",
    "math" ++ path.sep_str ++ "powf.c",
    "math" ++ path.sep_str ++ "sinhf.c",
    "math" ++ path.sep_str ++ "sqrtf.c",
    "math" ++ path.sep_str ++ "tanhf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "acosf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "asinf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "atan2f.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "atanf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "ceilf.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "cosf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "floorf.S",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "fmodf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "sinf.c",
    "math" ++ path.sep_str ++ "x86" ++ path.sep_str ++ "tanf.c",
};

const mingw32_arm32_src = [_][]const u8{
    "math" ++ path.sep_str ++ "arm-common" ++ path.sep_str ++ "ldexpl.c",
    "math" ++ path.sep_str ++ "arm" ++ path.sep_str ++ "_chgsignl.S",
    "math" ++ path.sep_str ++ "arm" ++ path.sep_str ++ "s_rint.c",
    "math" ++ path.sep_str ++ "arm" ++ path.sep_str ++ "s_rintf.c",
    "math" ++ path.sep_str ++ "arm" ++ path.sep_str ++ "sincos.S",
    "math" ++ path.sep_str ++ "arm" ++ path.sep_str ++ "sincosf.S",
};

const mingw32_arm64_src = [_][]const u8{
    "math" ++ path.sep_str ++ "arm-common" ++ path.sep_str ++ "ldexpl.c",
    "math" ++ path.sep_str ++ "arm64" ++ path.sep_str ++ "_chgsignl.S",
    "math" ++ path.sep_str ++ "arm64" ++ path.sep_str ++ "rint.c",
    "math" ++ path.sep_str ++ "arm64" ++ path.sep_str ++ "rintf.c",
    "math" ++ path.sep_str ++ "arm64" ++ path.sep_str ++ "sincos.S",
    "math" ++ path.sep_str ++ "arm64" ++ path.sep_str ++ "sincosf.S",
};

pub const always_link_libs = [_][]const u8{
    "api-ms-win-crt-conio-l1-1-0",
    "api-ms-win-crt-convert-l1-1-0",
    "api-ms-win-crt-environment-l1-1-0",
    "api-ms-win-crt-filesystem-l1-1-0",
    "api-ms-win-crt-heap-l1-1-0",
    "api-ms-win-crt-locale-l1-1-0",
    "api-ms-win-crt-math-l1-1-0",
    "api-ms-win-crt-multibyte-l1-1-0",
    "api-ms-win-crt-private-l1-1-0",
    "api-ms-win-crt-process-l1-1-0",
    "api-ms-win-crt-runtime-l1-1-0",
    "api-ms-win-crt-stdio-l1-1-0",
    "api-ms-win-crt-string-l1-1-0",
    "api-ms-win-crt-time-l1-1-0",
    "api-ms-win-crt-utility-l1-1-0",
    "advapi32",
    "kernel32",
    "ntdll",
    "shell32",
    "user32",
};
