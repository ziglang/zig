const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.mingw);

const builtin = @import("builtin");
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const Cache = std.Build.Cache;

pub fn buildCRTFile(comp: *Compilation, crt_file: CRTFile, prog_node: *std.Progress.Node) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }
    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const mingw_arch = MingwArch.get(comp);

    var args = std.ArrayList([]const u8).init(arena);

    try args.appendSlice(&.{
        "-DHAVE_CONFIG_H",

        "-I",
        try comp.zig_lib_directory.join(arena, &.{ "libc", "mingw", "include" }),

        "-isystem",
        try comp.zig_lib_directory.join(arena, &.{ "libc", "include", "any-windows-any" }),

        "-std=gnu99",
        "-D_CRTBLD",
        "-D_WIN32_WINNT=0x0f00",
        "-D__MSVCRT_VERSION__=0x700",
        "-D__USE_MINGW_ANSI_STDIO=0",
    });

    if (mingw_arch == .libarm32) {
        try args.append("-mfpu=vfp");
    }

    if (crt_file == .crt2_o or crt_file == .dllcrt2_o) {
        try args.appendSlice(&.{ "-D_SYSCRT=1", "-DCRTDLL=1" });

        if (crt_file == .crt2_o) {
            return comp.build_crt_file("crt2", .Obj, .@"mingw-w64 crt2.o", prog_node, &.{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", "mingw", "crt", "crtexe.c",
                    }),
                    .extra_flags = args.items,
                },
            });
        } else {
            return comp.build_crt_file("dllcrt2", .Obj, .@"mingw-w64 dllcrt2.o", prog_node, &.{
                .{
                    .src_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                        "libc", "mingw", "crt", "crtdll.c",
                    }),
                    .extra_flags = args.items,
                },
            });
        }
    } else {
        try args.appendSlice(crt_file.cflags());

        const basename = if (crt_file.hasDef())
            try std.mem.concat(arena, u8, &.{ @tagName(crt_file), "_extra" })
        else
            @tagName(crt_file);

        var c_source_files = std.ArrayList(Compilation.CSourceFile).init(arena);
        inline for (.{ crt_file.commonSource(), crt_file.archSource(mingw_arch) }) |deps| {
            for (deps) |dep| {
                try c_source_files.append(.{
                    .src_path = try comp.zig_lib_directory.join(arena, &.{ "libc", "mingw", dep }),
                    .extra_flags = args.items,
                });
            }
        }

        return comp.build_crt_file(basename, .Lib, .@"mingw-w64 CRT lib", prog_node, c_source_files.items);
    }
}

fn fixLibName(name: []const u8, arch: MingwArch) []const u8 {
    if (arch == .lib32 or arch == .lib64) {
        if (std.ComptimeStringMap([]const u8, .{
            .{ "xinput", "xinput1_3" },
            .{ "xapofx", "xapofx1_5" },
            .{ "x3daudio", "x3daudio1_7" },
            .{ "d3dx9", "d3dx9_43" },
            .{ "d3dx11", "d3dx11_43" },
            .{ "d3dcsxd", "d3dcsxd_43" },
        }).get(name)) |new_name| {
            return new_name;
        }
    }

    if (std.ComptimeStringMap([]const u8, .{
        .{ "msvcrt", "ucrt" },
        .{ "msvcrt-os", "msvcrt" },
        .{ "d3dcompiler", "d3dcompiler_47" },
        .{ "xinput", "xinput1_4" },
    }).get(name)) |new_name| {
        return new_name;
    }

    return name;
}

/// Adjusts `comp.bin_file.options.system_libs` and adds items to `comp.work_queue`
/// to build and link the mingw CRT libraries.
pub fn processSystemLibs(comp: *Compilation) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const mingw_arch = MingwArch.get(comp);
    var new_system_libs: @TypeOf(comp.bin_file.options.system_libs) = .{};

    var it = comp.bin_file.options.system_libs.iterator();
    while (it.next()) |entry| {
        const lib_name = fixLibName(entry.key_ptr.*, mingw_arch);
        const val = entry.value_ptr.*;

        var have_crt_file = false;
        if (CRTFile.stringToLib(lib_name)) |lib| {
            have_crt_file = true;
            try comp.work_queue.writeItem(.{ .mingw_crt_file = lib });
            if (lib.hasDef()) {
                const extra_name = try std.mem.concat(comp.gpa, u8, &.{ lib_name, "_extra" });
                try new_system_libs.put(comp.gpa, extra_name, val);
            }
        }

        if (try findFile(arena, comp.zig_lib_directory, mingw_arch, lib_name, "zri")) |zri| {
            const file = try std.fs.cwd().openFile(zri, .{});
            defer file.close();

            var line = std.ArrayList(u8).init(arena);
            const reader = file.reader();
            const writer = line.writer();
            while (reader.streamUntilDelimiter(writer, '\n', null)) {
                const name = try comp.gpa.dupe(u8, line.items);
                try new_system_libs.put(comp.gpa, name, val);
                line.clearRetainingCapacity();
            } else |err| switch (err) {
                error.EndOfStream => {},
                else => return err,
            }

            // only link with the named library if it exists in a form other than .zri
            if (have_crt_file or try findDef(arena, comp.zig_lib_directory, mingw_arch, lib_name) != null) {
                try new_system_libs.put(comp.gpa, lib_name, val);
            }
        } else {
            try new_system_libs.put(comp.gpa, lib_name, val);
        }
    }

    comp.bin_file.options.system_libs.clearAndFree(comp.gpa);
    comp.bin_file.options.system_libs = new_system_libs;
}

pub fn buildImportLib(comp: *Compilation, lib_name: []const u8) !void {
    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    // We need to invoke `zig clang` to use the preprocessor.
    if (!build_options.have_llvm) return error.ZigCompilerNotBuiltWithLLVMExtensions;
    const self_exe_path = comp.self_exe_path orelse return error.PreprocessorDisabled;

    const target = comp.getTarget();
    const mingw_arch = MingwArch.convert(target.cpu.arch);

    const def_file_path = try findDef(arena, comp.zig_lib_directory, mingw_arch, lib_name) orelse {
        log.debug("no {s}.def file available to make a DLL import {s}.lib", .{ lib_name, lib_name });
        // In this case we will end up putting foo.lib onto the linker line and letting the linker
        // use its library paths to look for libraries and report any problems.
        return;
    };

    var cache: Cache = .{
        .gpa = comp.gpa,
        .manifest_dir = comp.cache_parent.manifest_dir,
    };
    for (comp.cache_parent.prefixes()) |prefix| {
        cache.addPrefix(prefix);
    }

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
    const def_final_path = try comp.global_cache_directory.joinZ(arena, &[_][]const u8{
        "o", &digest, final_def_basename,
    });

    const target_def_arg = switch (mingw_arch) {
        .lib32 => "-DDEF_I386",
        .lib64 => "-DDEF_X64",
        .libarm32 => "-DDEF_ARM32",
        .libarm64 => "-DDEF_ARM64",
    };

    const args = [_][]const u8{
        self_exe_path,
        "clang",
        "-x",
        "c",
        def_file_path,
        "-Wp,-w",
        "-undef",
        "-P",
        "-I",
        try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "mingw", "def-include" }),
        target_def_arg,
        "-E",
        "-o",
        def_final_path,
    };

    if (comp.verbose_cc) {
        Compilation.dump_argv(&args);
    }

    if (std.process.can_spawn) {
        var child = std.ChildProcess.init(&args, arena);
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        try child.spawn();

        const stderr = try child.stderr.?.reader().readAllAlloc(arena, std.math.maxInt(usize));

        const term = child.wait() catch |err| {
            // TODO surface a proper error here
            log.err("unable to spawn {s}: {s}", .{ args[0], @errorName(err) });
            return error.ClangPreprocessorFailed;
        };
        switch (term) {
            .Exited => |code| {
                if (code != 0) {
                    // TODO surface a proper error here
                    log.err("clang exited with code {d} and stderr: {s}", .{ code, stderr });
                    return error.ClangPreprocessorFailed;
                }
            },
            else => {
                // TODO surface a proper error here
                log.err("clang terminated unexpectedly with stderr: {s}", .{stderr});
                return error.ClangPreprocessorFailed;
            },
        }
    } else {
        log.err("unable to spawn {s}: spawning child process not supported on {s}", .{ args[0], @tagName(builtin.os.tag) });
        return error.ClangPreprocessorFailed;
    }

    const lib_final_path = try comp.global_cache_directory.joinZ(comp.gpa, &[_][]const u8{
        "o", &digest, final_lib_basename,
    });
    errdefer comp.gpa.free(lib_final_path);

    const llvm_bindings = @import("codegen/llvm/bindings.zig");
    const llvm = @import("codegen/llvm.zig");
    const arch_tag = llvm.targetArch(target.cpu.arch);
    if (llvm_bindings.WriteImportLibrary(def_final_path.ptr, arch_tag, lib_final_path.ptr, true)) {
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
    arena: Allocator,
    target: std.Target,
    zig_lib_directory: Cache.Directory,
    lib_name: []const u8,
) !bool {
    const mingw_arch = MingwArch.convert(target.cpu.arch);
    if (try findDef(arena, zig_lib_directory, mingw_arch, lib_name) != null) return true;
    if (try findFile(arena, zig_lib_directory, mingw_arch, lib_name, "zri") != null) return true;
    if (CRTFile.stringToLib(lib_name) != null) return true;
    return false;
}

fn findDef(arena: Allocator, zig_lib_directory: Cache.Directory, mingw_arch: MingwArch, lib_name: []const u8) !?[:0]u8 {
    return try findFile(arena, zig_lib_directory, mingw_arch, lib_name, "def") orelse
        findFile(arena, zig_lib_directory, mingw_arch, lib_name, "def.in");
}

fn findFile(arena: Allocator, zig_lib_directory: Cache.Directory, mingw_arch: MingwArch, lib_name: []const u8, ext: []const u8) !?[:0]u8 {
    return try findLibFile(arena, zig_lib_directory, @tagName(mingw_arch), lib_name, ext) orelse
        findLibFile(arena, zig_lib_directory, "lib-common", lib_name, ext);
}

fn findLibFile(arena: Allocator, zig_lib_directory: Cache.Directory, mingw_sub_dir: []const u8, lib_name: []const u8, ext: []const u8) !?[:0]u8 {
    const file = try std.mem.concat(arena, u8, &.{ lib_name, ".", ext });
    const path = try zig_lib_directory.joinZ(arena, &.{ "libc", "mingw", mingw_sub_dir, file });
    if (std.fs.cwd().access(path, .{})) {
        return path;
    } else |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    }
}

const MingwArch = enum {
    lib32,
    lib64,
    libarm32,
    libarm64,

    pub fn convert(arch: std.Target.Cpu.Arch) MingwArch {
        return switch (arch) {
            .x86 => .lib32,
            .x86_64 => .lib64,
            .arm, .armeb, .thumb, .thumbeb, .aarch64_32 => .libarm32,
            .aarch64, .aarch64_be => .libarm64,
            else => unreachable,
        };
    }

    pub fn get(comp: *Compilation) MingwArch {
        const arch = comp.getTarget().cpu.arch;
        return convert(arch);
    }
};

pub const always_link_libs = [_][]const u8{
    "advapi32",
    "kernel32",
    "mingw32",
    "mingwex",
    "ntdll",
    "shell32",
    "user32",
};

pub const CRTFile = enum {
    crt2_o,
    dllcrt2_o,

    bits,
    shell32,
    dinput,
    dinput8,
    dmoguids,
    dxerr8,
    dxerr9,
    mfuuid,
    msxml2,
    msxml6,
    amstrmid,
    wbemuuid,
    wmcodecdspuuid,
    windowscodecs,
    dxguid,
    ksuser,
    ksguid,
    largeint,
    locationapi,
    sapi,
    sensorsapi,
    portabledeviceguids,
    taskschd,
    ntoskrnl,
    dloadhelper,
    mingw32,
    scrnsave,
    scrnsavw,
    strmiids,
    mingwthrd,
    gdiplus,
    adsiid,
    uuid,
    ws2_32,

    msvcrt,
    ucrt,
    ucrtbase,
    ucrtapp,
    crtdll,
    msvcrt10,
    msvcrt20,
    msvcrt40,
    msvcr70,
    msvcr71,
    msvcr80,
    msvcr90,
    msvcr90d,
    msvcr100,
    msvcr110,
    msvcr120,
    msvcr120d,
    msvcr120_app,

    mingwex,
    kernel32,

    pub fn stringToLib(str: []const u8) ?CRTFile {
        const val = std.meta.stringToEnum(CRTFile, str);
        return if (val == .crt2_o or val == .dllcrt2_o) null else val;
    }

    pub fn hasDef(lib: CRTFile) bool {
        switch (lib) {
            .bits,
            .dmoguids,
            .dxerr8,
            .dxerr9,
            .mfuuid,
            .msxml2,
            .amstrmid,
            .wbemuuid,
            .wmcodecdspuuid,
            .dxguid,
            .ksguid,
            .largeint,
            .locationapi,
            .portabledeviceguids,
            .taskschd,
            .dloadhelper,
            .mingw32,
            .scrnsave,
            .scrnsavw,
            .strmiids,
            .mingwthrd,
            .adsiid,
            .uuid,
            .ucrt,
            .ucrtapp,
            .mingwex,
            => return false,
            else => return true,
        }
    }

    pub fn archSupported(lib: CRTFile, arch: MingwArch) bool {
        switch (lib) {
            .crtdll,
            .msvcrt10,
            .msvcrt20,
            .msvcrt40,
            .msvcr70,
            .msvcr71,
            => return (arch == .lib32),
            .msvcr80,
            .msvcr90,
            .msvcr90d,
            .msvcr100,
            .msvcr120,
            .msvcr120d,
            => return (arch == .lib32 or arch == .lib64),
            .msvcr110,
            .msvcr120_app,
            => return (arch == .lib32 or arch == .lib64 or arch == .libarm32),
            else => return true,
        }
    }

    pub fn cflags(lib: CRTFile) []const []const u8 {
        return switch (lib) {
            .crtdll,
            .msvcrt10,
            .msvcrt20,
            .msvcrt40,
            .msvcr70,
            .msvcr71,
            .msvcr80,
            .msvcr90,
            .msvcr90d,
            .msvcr100,
            .msvcr110,
            .msvcr120,
            .msvcr120d,
            .msvcr120_app,
            .ucrt,
            .ucrtbase,
            .ucrtapp,
            => &.{"-D__LIBMSVCRT__"},
            .msvcrt => &.{ "-D__LIBMSVCRT__", "-D__LIBMSVCRT_OS__" },
            .mingw32 => &.{ "-D_SYSCRT=1", "-DCRTDLL=1" },
            .scrnsavw => &.{"-DUNICODE"},
            else => &.{},
        };
    }

    inline fn convertPathSep(comptime paths: anytype) []const []const u8 {
        comptime {
            @setEvalBranchQuota(100000);
            var new_paths: [paths.len][]const u8 = undefined;
            inline for (paths, &new_paths) |path, *out| {
                var new_path = path.*;
                std.mem.replaceScalar(u8, &new_path, '/', std.fs.path.sep);
                out.* = &new_path;
            }
            return &new_paths;
        }
    }

    pub fn commonSource(lib: CRTFile) []const []const u8 {
        const s = convertPathSep;

        const msvcrt_common_src = s(.{
            "misc/mbrtowc.c",
            "misc/mbsinit.c",
            "misc/onexit_table.c",
            "misc/register_tls_atexit.c",
            "misc/wcrtomb.c",
            "stdio/_getc_nolock.c",
            "stdio/_getwc_nolock.c",
            "stdio/_putc_nolock.c",
            "stdio/_putwc_nolock.c",
            "stdio/_strtof_l.c",
            "stdio/_wcstof_l.c",
            "stdio/acrt_iob_func.c",
            "stdio/strtof.c",
            "stdio/snprintf_alias.c",
            "stdio/vsnprintf_alias.c",
            "math/frexp.c",
        });

        return switch (lib) {
            .bits => s(.{"libsrc/bits.c"}),
            .shell32 => s(.{"libsrc/shell32.c"}),
            .dinput, .dinput8 => s(.{
                "libsrc/dinput_kbd.c",   "libsrc/dinput_joy.c",    "libsrc/dinput_joy2.c",
                "libsrc/dinput_mouse.c", "libsrc/dinput_mouse2.c",
            }),
            .dmoguids => s(.{"libsrc/dmoguids.c"}),
            .dxerr8 => s(.{ "libsrc/dxerr8.c", "libsrc/dxerr8w.c" }),
            .dxerr9 => s(.{ "libsrc/dxerr9.c", "libsrc/dxerr9w.c" }),
            .mfuuid => s(.{"libsrc/mfuuid.c"}),
            .msxml2 => s(.{"libsrc/msxml2.c"}),
            .msxml6 => s(.{"libsrc/msxml6.c"}),
            .amstrmid => s(.{"libsrc/amstrmid.c"}),
            .wbemuuid => s(.{"libsrc/wbemuuid.c"}),
            .wmcodecdspuuid => s(.{"libsrc/wmcodecdspuuid.c"}),
            .windowscodecs => s(.{"libsrc/windowscodecs.c"}),
            .dxguid => s(.{"libsrc/dxguid.c"}),
            .ksuser => s(.{"libsrc/ksuser.c"}),
            .ksguid => s(.{"libsrc/ksuser.c"}),
            .largeint => s(.{"libsrc/largeint.c"}),
            .locationapi => s(.{"libsrc/locationapi.c"}),
            .sapi => s(.{"libsrc/sapi.c"}),
            .sensorsapi => s(.{"libsrc/sensorsapi.c"}),
            .portabledeviceguids => s(.{"libsrc/portabledeviceguids.c"}),
            .taskschd => s(.{"libsrc/taskschd.c"}),
            .ntoskrnl => s(.{"libsrc/memcmp.c"}),
            .dloadhelper => s(.{ "libsrc/dloadhelper.c", "misc/delay-f.c" }),

            .mingw32 => s(.{
                "crt/crtexewin.c",    "crt/dll_argv.c",          "crt/gccmain.c",
                "crt/natstart.c",     "crt/pseudo-reloc-list.c", "crt/wildcard.c",
                "crt/charmax.c",      "crt/ucrtexewin.c",        "crt/dllargv.c",
                "crt/_newmode.c",     "crt/tlssup.c",            "crt/xncommod.c",
                "crt/cinitexe.c",     "crt/merr.c",              "crt/pesect.c",
                "crt/udllargc.c",     "crt/xthdloc.c",           "crt/CRT_fp10.c",
                "crt/mingw_custom.c", "crt/mingw_helpers.c",     "crt/pseudo-reloc.c",
                "crt/udll_argv.c",    "crt/usermatherr.c",       "crt/xtxtmode.c",
                "crt/crt_handler.c",  "crt/tlsthrd.c",           "crt/tlsmthread.c",
                "crt/tlsmcrt.c",      "crt/cxa_atexit.c",        "crt/cxa_thread_atexit.c",
                "crt/tls_atexit.c",
            }),

            .scrnsave, .scrnsavw => s(.{"libsrc/scrnsave.c"}),
            .strmiids => s(.{"libsrc/strmiids.c"}),
            .mingwthrd => s(.{"libsrc/mingwthrd_mt.c"}),

            .gdiplus => s(.{"libsrc/gdiplus.c"}),

            .adsiid => s(.{"libsrc/activeds-uuid.c"}),

            .uuid => s(.{
                "libsrc/ativscp-uuid.c",  "libsrc/atsmedia-uuid.c", "libsrc/bth-uuid.c",
                "libsrc/cguid-uuid.c",    "libsrc/comcat-uuid.c",   "libsrc/ctxtcall-uuid.c",
                "libsrc/devguid.c",       "libsrc/docobj-uuid.c",   "libsrc/dxva-uuid.c",
                "libsrc/exdisp-uuid.c",   "libsrc/extras-uuid.c",   "libsrc/fwp-uuid.c",
                "libsrc/guid_nul.c",      "libsrc/hlguids-uuid.c",  "libsrc/hlink-uuid.c",
                "libsrc/mlang-uuid.c",    "libsrc/msctf-uuid.c",    "libsrc/mshtmhst-uuid.c",
                "libsrc/mshtml-uuid.c",   "libsrc/msxml-uuid.c",    "libsrc/netcfg-uuid.c",
                "libsrc/netcon-uuid.c",   "libsrc/ntddkbd-uuid.c",  "libsrc/ntddmou-uuid.c",
                "libsrc/ntddpar-uuid.c",  "libsrc/ntddscsi-uuid.c", "libsrc/ntddser-uuid.c",
                "libsrc/ntddstor-uuid.c", "libsrc/ntddvdeo-uuid.c", "libsrc/oaidl-uuid.c",
                "libsrc/objidl-uuid.c",   "libsrc/objsafe-uuid.c",  "libsrc/ocidl-uuid.c",
                "libsrc/oleacc-uuid.c",   "libsrc/olectlid-uuid.c", "libsrc/oleidl-uuid.c",
                "libsrc/power-uuid.c",    "libsrc/powrprof-uuid.c", "libsrc/uianimation-uuid.c",
                "libsrc/usbcamdi-uuid.c", "libsrc/usbiodef-uuid.c", "libsrc/uuid.c",
                "libsrc/vds-uuid.c",      "libsrc/virtdisk-uuid.c", "libsrc/vss-uuid.c",
                "libsrc/wia-uuid.c",      "libsrc/windowscodecs.c",
            }),

            .ws2_32 => s(.{
                "libsrc/ws2_32.c",                            "libsrc/ws2tcpip/in6_addr_equal.c",
                "libsrc/ws2tcpip/in6addr_isany.c",            "libsrc/ws2tcpip/in6addr_isloopback.c",
                "libsrc/ws2tcpip/in6addr_setany.c",           "libsrc/ws2tcpip/in6addr_setloopback.c",
                "libsrc/ws2tcpip/in6_is_addr_linklocal.c",    "libsrc/ws2tcpip/in6_is_addr_loopback.c",
                "libsrc/ws2tcpip/in6_is_addr_mc_global.c",    "libsrc/ws2tcpip/in6_is_addr_mc_linklocal.c",
                "libsrc/ws2tcpip/in6_is_addr_mc_nodelocal.c", "libsrc/ws2tcpip/in6_is_addr_mc_orglocal.c",
                "libsrc/ws2tcpip/in6_is_addr_mc_sitelocal.c", "libsrc/ws2tcpip/in6_is_addr_multicast.c",
                "libsrc/ws2tcpip/in6_is_addr_sitelocal.c",    "libsrc/ws2tcpip/in6_is_addr_unspecified.c",
                "libsrc/ws2tcpip/in6_is_addr_v4compat.c",     "libsrc/ws2tcpip/in6_is_addr_v4mapped.c",
                "libsrc/ws2tcpip/in6_set_addr_loopback.c",    "libsrc/ws2tcpip/in6_set_addr_unspecified.c",
                "libsrc/ws2tcpip/gai_strerrorA.c",            "libsrc/ws2tcpip/gai_strerrorW.c",
                "libsrc/wspiapi/WspiapiStrdup.c",             "libsrc/wspiapi/WspiapiParseV4Address.c",
                "libsrc/wspiapi/WspiapiNewAddrInfo.c",        "libsrc/wspiapi/WspiapiQueryDNS.c",
                "libsrc/wspiapi/WspiapiLookupNode.c",         "libsrc/wspiapi/WspiapiClone.c",
                "libsrc/wspiapi/WspiapiLegacyFreeAddrInfo.c", "libsrc/wspiapi/WspiapiLegacyGetAddrInfo.c",
                "libsrc/wspiapi/WspiapiLegacyGetNameInfo.c",  "libsrc/wspiapi/WspiapiLoad.c",
                "libsrc/wspiapi/WspiapiGetAddrInfo.c",        "libsrc/wspiapi/WspiapiGetNameInfo.c",
                "libsrc/wspiapi/WspiapiFreeAddrInfo.c",
            }),

            .msvcrt => msvcrt_common_src ++ s(.{
                "misc/_configthreadlocale.c", "misc/imaxdiv.c",          "misc/invalid_parameter_handler.c",
                "misc/output_format.c",       "misc/purecall.c",         "secapi/_access_s.c",
                "secapi/_cgets_s.c",          "secapi/_cgetws_s.c",      "secapi/_chsize_s.c",
                "secapi/_controlfp_s.c",      "secapi/_cprintf_s.c",     "secapi/_cprintf_s_l.c",
                "secapi/_ctime32_s.c",        "secapi/_ctime64_s.c",     "secapi/_cwprintf_s.c",
                "secapi/_cwprintf_s_l.c",     "secapi/_gmtime32_s.c",    "secapi/_gmtime64_s.c",
                "secapi/_localtime32_s.c",    "secapi/_localtime64_s.c", "secapi/_mktemp_s.c",
                "secapi/_sopen_s.c",          "secapi/_strdate_s.c",     "secapi/_strtime_s.c",
                "secapi/_umask_s.c",          "secapi/_vcprintf_s.c",    "secapi/_vcprintf_s_l.c",
                "secapi/_vcwprintf_s.c",      "secapi/_vcwprintf_s_l.c", "secapi/_vscprintf_p.c",
                "secapi/_vscwprintf_p.c",     "secapi/_vswprintf_p.c",   "secapi/_waccess_s.c",
                "secapi/_wasctime_s.c",       "secapi/_wctime32_s.c",    "secapi/_wctime64_s.c",
                "secapi/_wstrtime_s.c",       "secapi/_wmktemp_s.c",     "secapi/_wstrdate_s.c",
                "secapi/asctime_s.c",         "secapi/memcpy_s.c",       "secapi/memmove_s.c",
                "secapi/rand_s.c",            "secapi/sprintf_s.c",      "secapi/strerror_s.c",
                "secapi/vsprintf_s.c",        "secapi/wmemcpy_s.c",      "secapi/wmemmove_s.c",
                "stdio/fseeki64.c",           "stdio/mingw_lock.c",
            }),

            .ucrt, .ucrtbase => s(.{
                "crt/ucrtbase_compat.c",    "math/_huge.c",            "misc/__initenv.c",
                "misc/ucrt-access.c",       "stdio/ucrt_fprintf.c",    "stdio/ucrt_fscanf.c",
                "stdio/ucrt_fwprintf.c",    "stdio/ucrt_printf.c",     "stdio/ucrt_scanf.c",
                "stdio/ucrt__snwprintf.c",  "stdio/ucrt_snprintf.c",   "stdio/ucrt_sprintf.c",
                "stdio/ucrt_sscanf.c",      "stdio/ucrt__vscprintf.c", "stdio/ucrt__vsnprintf.c",
                "stdio/ucrt__vsnwprintf.c", "stdio/ucrt_vfprintf.c",   "stdio/ucrt_vfscanf.c",
                "stdio/ucrt_vprintf.c",     "stdio/ucrt_vscanf.c",     "stdio/ucrt_vsnprintf.c",
                "stdio/ucrt_vsprintf.c",    "stdio/ucrt_vsscanf.c",
            }),

            .ucrtapp => s(.{
                "crt/__C_specific_handler.c", "misc/longjmp.S",   "misc/setjmp.S",
                "string/memchr.c",            "string/memcmp.c",  "string/memcpy.c",
                "string/memmove.c",           "string/memrchr.c", "string/strchr.c",
                "string/strchrnul.c",         "string/strrchr.c", "string/strstr.c",
                "string/wcschr.c",            "string/wcsrchr.c", "string/wcsstr.c",
            }),

            .crtdll => msvcrt_common_src ++ s(.{
                "crt/crtdll_compat.c",   "misc/___mb_cur_max_func.c", "misc/__initenv.c",
                "misc/__p___argv.c",     "misc/__p__acmdln.c",        "misc/__p__commode.c",
                "misc/__p__fmode.c",     "misc/__set_app_type.c",     "misc/dummy__setusermatherr.c",
                "misc/imaxabs.c",        "misc/imaxdiv.c",            "misc/invalid_parameter_handler.c",
                "misc/lc_locale_func.c", "misc/seterrno.c",           "misc/strtoimax.c",
                "misc/strtoumax.c",      "stdio/_scprintf.c",         "stdio/_vscprintf.c",
                "stdio/atoll.c",         "stdio/mingw_dummy__lock.c", "stdio/mingw_lock.c",
            }),

            .msvcrt10 => msvcrt_common_src ++ s(.{
                "misc/___mb_cur_max_func.c", "misc/__initenv.c",                 "misc/__p___argv.c",
                "misc/__p__acmdln.c",        "misc/__p__commode.c",              "misc/__p__fmode.c",
                "misc/__set_app_type.c",     "misc/dummy__setusermatherr.c",     "misc/imaxabs.c",
                "misc/imaxdiv.c",            "misc/invalid_parameter_handler.c", "misc/lc_locale_func.c",
                "misc/seterrno.c",           "misc/strtoimax.c",                 "misc/strtoumax.c",
                "stdio/_scprintf.c",         "stdio/_vscprintf.c",               "stdio/atoll.c",
                "stdio/mingw_dummy__lock.c", "stdio/mingw_lock.c",
            }),

            .msvcrt20 => msvcrt_common_src ++ s(.{
                "misc/___mb_cur_max_func.c", "misc/__set_app_type.c",     "misc/dummy__setusermatherr.c",
                "misc/imaxabs.c",            "misc/imaxdiv.c",            "misc/invalid_parameter_handler.c",
                "misc/lc_locale_func.c",     "misc/seterrno.c",           "misc/strtoimax.c",
                "misc/strtoumax.c",          "stdio/_scprintf.c",         "stdio/_vscprintf.c",
                "stdio/atoll.c",             "stdio/mingw_dummy__lock.c", "stdio/mingw_lock.c",
            }),

            .msvcrt40 => msvcrt_common_src ++ s(.{
                "misc/___mb_cur_max_func.c",        "misc/imaxabs.c",        "misc/imaxdiv.c",
                "misc/invalid_parameter_handler.c", "misc/lc_locale_func.c", "misc/seterrno.c",
                "misc/strtoimax.c",                 "misc/strtoumax.c",      "stdio/_scprintf.c",
                "stdio/_vscprintf.c",               "stdio/atoll.c",         "stdio/mingw_dummy__lock.c",
                "stdio/mingw_lock.c",
            }),

            .msvcr70, .msvcr71 => msvcrt_common_src ++ s(.{
                "misc/imaxabs.c",
                "misc/imaxdiv.c",
                "misc/invalid_parameter_handler.c",
                "stdio/mingw_lock.c",
            }),

            .msvcr80, .msvcr90 => msvcrt_common_src ++ s(.{"misc/imaxdiv.c"}),

            .msvcr90d,
            .msvcr100,
            .msvcr110,
            .msvcr120,
            .msvcr120d,
            => msvcrt_common_src,

            .msvcr120_app => msvcrt_common_src ++ s(.{ "misc/__set_app_type.c", "misc/_getpid.c" }),

            .mingwex => s(.{
                "cfguard/mingw_cfguard_support.c",
            } ++ .{
                "crt/dllentry.c",
                "crt/dllmain.c",
            } ++ .{
                "complex/_cabs.c",  "complex/cabs.c",    "complex/cabsf.c",   "complex/cabsl.c",
                "complex/cacos.c",  "complex/cacosf.c",  "complex/cacosl.c",  "complex/carg.c",
                "complex/cargf.c",  "complex/cargl.c",   "complex/casin.c",   "complex/casinf.c",
                "complex/casinl.c", "complex/catan.c",   "complex/catanf.c",  "complex/catanl.c",
                "complex/ccos.c",   "complex/ccosf.c",   "complex/ccosl.c",   "complex/cexp.c",
                "complex/cexpf.c",  "complex/cexpl.c",   "complex/cimag.c",   "complex/cimagf.c",
                "complex/cimagl.c", "complex/clog.c",    "complex/clogf.c",   "complex/clogl.c",
                "complex/clog10.c", "complex/clog10f.c", "complex/clog10l.c", "complex/conj.c",
                "complex/conjf.c",  "complex/conjl.c",   "complex/cpow.c",    "complex/cpowf.c",
                "complex/cpowl.c",  "complex/cproj.c",   "complex/cprojf.c",  "complex/cprojl.c",
                "complex/creal.c",  "complex/crealf.c",  "complex/creall.c",  "complex/csin.c",
                "complex/csinf.c",  "complex/csinl.c",   "complex/csqrt.c",   "complex/csqrtf.c",
                "complex/csqrtl.c", "complex/ctan.c",    "complex/ctanf.c",   "complex/ctanl.c",
            } ++ .{
                "gdtoa/arithchk.c",  "gdtoa/dmisc.c",  "gdtoa/dtoa.c",    "gdtoa/g_dfmt.c",
                "gdtoa/gdtoa.c",     "gdtoa/gethex.c", "gdtoa/g_ffmt.c",  "gdtoa/g__fmt.c",
                "gdtoa/gmisc.c",     "gdtoa/g_xfmt.c", "gdtoa/hd_init.c", "gdtoa/hexnan.c",
                "gdtoa/misc.c",      "gdtoa/qnan.c",   "gdtoa/smisc.c",   "gdtoa/strtodg.c",
                "gdtoa/strtodnrp.c", "gdtoa/strtof.c", "gdtoa/strtopx.c", "gdtoa/sum.c",
                "gdtoa/ulp.c",
            } ++ .{
                "math/cbrt.c",        "math/cbrtf.c",       "math/cbrtl.c",      "math/copysign.c",
                "math/copysignf.c",   "math/coshf.c",       "math/coshl.c",      "math/erfl.c",
                "math/expf.c",        "math/fabs.c",        "math/fabsf.c",      "math/fabsl.c",
                "math/fdim.c",        "math/fdimf.c",       "math/fdiml.c",      "math/fma.c",
                "math/fmaf.c",        "math/fmal.c",        "math/fmax.c",       "math/fmaxf.c",
                "math/fmaxl.c",       "math/fmin.c",        "math/fminf.c",      "math/fminl.c",
                "math/fp_consts.c",   "math/fp_constsf.c",  "math/fp_constsl.c", "math/fpclassify.c",
                "math/fpclassifyf.c", "math/fpclassifyl.c", "math/frexpf.c",     "math/frexpl.c",
                "math/hypotf.c",      "math/hypot.c",       "math/hypotl.c",     "math/isnan.c",
                "math/isnanf.c",      "math/isnanl.c",      "math/ldexpf.c",     "math/lgamma.c",
                "math/lgammaf.c",     "math/lgammal.c",     "math/llrint.c",     "math/signgam.c",
                "math/llrintf.c",     "math/llrintl.c",     "math/llround.c",    "math/llroundf.c",
                "math/llroundl.c",    "math/log10f.c",      "math/logf.c",       "math/lrint.c",
                "math/lrintf.c",      "math/lrintl.c",      "math/lround.c",     "math/lroundf.c",
                "math/lroundl.c",     "math/modf.c",        "math/modff.c",      "math/modfl.c",
                "math/nextafterf.c",  "math/nextafterl.c",  "math/nexttoward.c", "math/nexttowardf.c",
                "math/powf.c",        "math/powi.c",        "math/powif.c",      "math/powil.c",
                "math/rintl.c",       "math/round.c",       "math/roundf.c",     "math/roundl.c",
                "math/s_erf.c",       "math/sf_erf.c",      "math/signbit.c",    "math/signbitf.c",
                "math/signbitl.c",    "math/sinhf.c",       "math/sinhl.c",      "math/sqrt.c",
                "math/sqrtf.c",       "math/sqrtl.c",       "math/tanhf.c",      "math/tanhl.c",
                "math/tgamma.c",      "math/tgammaf.c",     "math/tgammal.c",    "math/truncl.c",
            } ++ .{
                "misc/mingw_longjmp.S",   "misc/mingw_getsp.S",        "misc/alarm.c",
                "misc/basename.c",        "misc/btowc.c",              "misc/delay-f.c",
                "misc/delay-n.c",         "misc/delayimp.c",           "misc/dirent.c",
                "misc/dirname.c",         "misc/feclearexcept.c",      "misc/fegetenv.c",
                "misc/fegetexceptflag.c", "misc/fegetround.c",         "misc/feholdexcept.c",
                "misc/feraiseexcept.c",   "misc/fesetenv.c",           "misc/fesetexceptflag.c",
                "misc/fesetround.c",      "misc/fetestexcept.c",       "misc/feupdateenv.c",
                "misc/ftruncate.c",       "misc/fwide.c",              "misc/getlogin.c",
                "misc/getopt.c",          "misc/gettimeofday.c",       "misc/isblank.c",
                "misc/iswblank.c",        "misc/mempcpy.c",            "misc/mingw-aligned-malloc.c",
                "misc/mingw_matherr.c",   "misc/mingw_mbwc_convert.c", "misc/mingw_usleep.c",
                "misc/mingw_wcstod.c",    "misc/mingw_wcstof.c",       "misc/mingw_wcstold.c",
                "misc/mkstemp.c",         "misc/sleep.c",              "misc/strnlen.c",
                "misc/strsafe.c",         "misc/tdelete.c",            "misc/tdestroy.c",
                "misc/tfind.c",           "misc/tsearch.c",            "misc/twalk.c",
                "misc/wcsnlen.c",         "misc/wcstof.c",             "misc/wcstoimax.c",
                "misc/wcstold.c",         "misc/wcstoumax.c",          "misc/wctob.c",
                "misc/wctrans.c",         "misc/wctype.c",             "misc/wdirent.c",
                "misc/winbs_uint64.c",    "misc/winbs_ulong.c",        "misc/winbs_ushort.c",
                "misc/wmemchr.c",         "misc/wmemcmp.c",            "misc/wmemcpy.c",
                "misc/wmemmove.c",        "misc/wmempcpy.c",           "misc/wmemset.c",
                "misc/ftw.c",             "misc/ftw64.c",              "misc/mingw-access.c",
            } ++ .{
                "ssp/chk_fail.c",    "ssp/gets_chk.c",   "ssp/memcpy_chk.c",     "ssp/memmove_chk.c",
                "ssp/mempcpy_chk.c", "ssp/memset_chk.c", "ssp/stack_chk_fail.c", "ssp/stack_chk_guard.c",
                "ssp/strcat_chk.c",  "ssp/stpcpy_chk.c", "ssp/strcpy_chk.c",     "ssp/strncat_chk.c",
                "ssp/strncpy_chk.c",
            } ++ .{
                "stdio/scanf2-argcount-char.c", "stdio/scanf2-argcount-wchar.c", "stdio/vfscanf2.S",
                "stdio/vfwscanf2.S",            "stdio/vscanf2.S",               "stdio/vsscanf2.S",
                "stdio/vswscanf2.S",            "stdio/vwscanf2.S",              "stdio/strtok_r.c",
                "stdio/scanf.S",                "stdio/_Exit.c",                 "stdio/_findfirst64i32.c",
                "stdio/_findnext64i32.c",       "stdio/_fstat.c",                "stdio/_fstat64i32.c",
                "stdio/_ftime.c",               "stdio/_stat.c",                 "stdio/_stat64i32.c",
                "stdio/_wfindfirst64i32.c",     "stdio/_wfindnext64i32.c",       "stdio/_wstat.c",
                "stdio/_wstat64i32.c",          "stdio/asprintf.c",              "stdio/fgetpos64.c",
                "stdio/fopen64.c",              "stdio/fseeko32.c",              "stdio/fseeko64.c",
                "stdio/fsetpos64.c",            "stdio/ftello.c",                "stdio/ftello64.c",
                "stdio/ftruncate64.c",          "stdio/lltoa.c",                 "stdio/lltow.c",
                "stdio/lseek64.c",              "stdio/mingw_fprintf.c",         "stdio/mingw_fprintfw.c",
                "stdio/mingw_fscanf.c",         "stdio/mingw_fwscanf.c",         "stdio/mingw_pformat.c",
                "stdio/mingw_pformatw.c",       "stdio/mingw_printf.c",          "stdio/mingw_printfw.c",
                "stdio/mingw_scanf.c",          "stdio/mingw_snprintf.c",        "stdio/mingw_snprintfw.c",
                "stdio/mingw_sprintf.c",        "stdio/mingw_sprintfw.c",        "stdio/mingw_sscanf.c",
                "stdio/mingw_swscanf.c",        "stdio/mingw_vfprintf.c",        "stdio/mingw_vfprintfw.c",
                "stdio/mingw_vfscanf.c",        "stdio/mingw_vprintf.c",         "stdio/mingw_vprintfw.c",
                "stdio/mingw_vsnprintf.c",      "stdio/mingw_vsnprintfw.c",      "stdio/mingw_vsprintf.c",
                "stdio/mingw_vsprintfw.c",      "stdio/mingw_wscanf.c",          "stdio/mingw_wvfscanf.c",
                "stdio/snprintf.c",             "stdio/snwprintf.c",             "stdio/truncate.c",
                "stdio/ulltoa.c",               "stdio/ulltow.c",                "stdio/vasprintf.c",
                "stdio/vfscanf.c",              "stdio/vfwscanf.c",              "stdio/vscanf.c",
                "stdio/vsnprintf.c",            "stdio/vsnwprintf.c",            "stdio/vsscanf.c",
                "stdio/vswscanf.c",             "stdio/vwscanf.c",               "stdio/wtoll.c",
                "stdio/mingw_asprintf.c",       "stdio/mingw_vasprintf.c",
            }),

            .kernel32 => s(.{
                "intrincs/__movsb.c",             "intrincs/__movsd.c",        "intrincs/__movsw.c",
                "intrincs/__stosb.c",             "intrincs/__stosd.c",        "intrincs/__stosw.c",
                "intrincs/_rotl64.c",             "intrincs/_rotr64.c",        "intrincs/bitscanfwd.c",
                "intrincs/bitscanrev.c",          "intrincs/bittest.c",        "intrincs/bittestc.c",
                "intrincs/bittestci.c",           "intrincs/bittestr.c",       "intrincs/bittestri.c",
                "intrincs/bittests.c",            "intrincs/bittestsi.c",      "intrincs/cpuid.c",
                "intrincs/ilockadd.c",            "intrincs/ilockand.c",       "intrincs/ilockand64.c",
                "intrincs/ilockcxch.c",           "intrincs/ilockcxch16.c",    "intrincs/ilockcxch64.c",
                "intrincs/ilockcxchptr.c",        "intrincs/ilockdec.c",       "intrincs/ilockdec16.c",
                "intrincs/ilockdec64.c",          "intrincs/ilockexch.c",      "intrincs/ilockexch64.c",
                "intrincs/ilockexchadd.c",        "intrincs/ilockexchadd64.c", "intrincs/ilockexchptr.c",
                "intrincs/ilockinc.c",            "intrincs/ilockinc16.c",     "intrincs/ilockinc64.c",
                "intrincs/ilockor.c",             "intrincs/ilockor64.c",      "intrincs/ilockxor.c",
                "intrincs/ilockxor64.c",          "intrincs/inbyte.c",         "intrincs/inbytestring.c",
                "intrincs/indword.c",             "intrincs/indwordstring.c",  "intrincs/inword.c",
                "intrincs/inwordstring.c",        "intrincs/outbyte.c",        "intrincs/outbytestring.c",
                "intrincs/outdword.c",            "intrincs/outdwordstring.c", "intrincs/outword.c",
                "intrincs/outwordstring.c",       "intrincs/readcr0.c",        "intrincs/readcr2.c",
                "intrincs/readcr3.c",             "intrincs/readcr4.c",        "intrincs/readmsr.c",
                "intrincs/writecr0.c",            "intrincs/writecr2.c",       "intrincs/writecr3.c",
                "intrincs/writecr4.c",            "intrincs/writemsr.c",       "intrincs/__int2c.c",
                "intrincs/RtlSecureZeroMemory.c",
            }),

            .crt2_o, .dllcrt2_o => unreachable, // handled separately in buildCRTFile
        };
    }

    pub fn archSource(lib: CRTFile, arch: MingwArch) []const []const u8 {
        const s = convertPathSep;
        return switch (lib) {
            .msvcrt => switch (arch) {
                .lib32 => s(.{
                    "math/x86/_copysignf.c", "misc/___mb_cur_max_func.c",  "misc/_create_locale.c",
                    "misc/_free_locale.c",   "misc/_get_current_locale.c", "misc/imaxabs.c",
                    "misc/lc_locale_func.c", "misc/seterrno.c",            "misc/wassert.c",
                    "stdio/_scprintf.c",     "stdio/_vscprintf.c",
                }),
                .lib64 => s(.{
                    "misc/__p___argv.c",   "misc/__p__acmdln.c",         "misc/__p__commode.c",
                    "misc/__p__fmode.c",   "misc/__p__wcmdln.c",         "misc/_create_locale.c",
                    "misc/_free_locale.c", "misc/_get_current_locale.c", "misc/seterrno.c",
                }),
                .libarm32 => s(.{
                    "misc/__p___argv.c",           "misc/__p__acmdln.c",           "misc/__p__commode.c",
                    "misc/__p__fmode.c",           "misc/__p__wcmdln.c",           "misc/_getpid.c",
                    "misc/initenv.c",              "stdio/_setmaxstdio.c",         "stdio/gets.c",
                    "math/arm/exp2.S",             "math/arm/exp2f.S",             "math/arm/nearbyint.S",
                    "math/arm/nearbyintf.S",       "math/arm/nearbyintl.S",        "math/arm/s_trunc.c",
                    "math/arm/s_truncf.c",         "math/arm-common/acosh.c",      "math/arm-common/acoshf.c",
                    "math/arm-common/acoshl.c",    "math/arm-common/asinh.c",      "math/arm-common/asinhf.c",
                    "math/arm-common/asinhl.c",    "math/arm-common/atanh.c",      "math/arm-common/atanhf.c",
                    "math/arm-common/atanhl.c",    "math/arm-common/copysignl.c",  "math/arm-common/expm1.c",
                    "math/arm-common/expm1f.c",    "math/arm-common/expm1l.c",     "math/arm-common/ilogb.c",
                    "math/arm-common/ilogbf.c",    "math/arm-common/ilogbl.c",     "math/arm-common/log1p.c",
                    "math/arm-common/log1pf.c",    "math/arm-common/log1pl.c",     "math/arm-common/log2.c",
                    "math/arm-common/logb.c",      "math/arm-common/logbf.c",      "math/arm-common/logbl.c",
                    "math/arm-common/pow.c",       "math/arm-common/powf.c",       "math/arm-common/powl.c",
                    "math/arm-common/remainder.c", "math/arm-common/remainderf.c", "math/arm-common/remainderl.c",
                    "math/arm-common/remquol.c",   "math/arm-common/s_remquo.c",   "math/arm-common/s_remquof.c",
                    "math/arm-common/scalbn.c",
                }),
                .libarm64 => s(.{
                    "math/arm-common/acosh.c",      "math/arm-common/acoshf.c",     "math/arm-common/acoshl.c",
                    "math/arm-common/asinh.c",      "math/arm-common/asinhf.c",     "math/arm-common/asinhl.c",
                    "math/arm-common/atanh.c",      "math/arm-common/atanhf.c",     "math/arm-common/atanhl.c",
                    "math/arm-common/copysignl.c",  "math/arm-common/expm1.c",      "math/arm-common/expm1f.c",
                    "math/arm-common/expm1l.c",     "math/arm-common/ilogb.c",      "math/arm-common/ilogbf.c",
                    "math/arm-common/ilogbl.c",     "math/arm-common/log1p.c",      "math/arm-common/log1pf.c",
                    "math/arm-common/log1pl.c",     "math/arm-common/log2.c",       "math/arm-common/logb.c",
                    "math/arm-common/logbf.c",      "math/arm-common/logbl.c",      "math/arm-common/pow.c",
                    "math/arm-common/powf.c",       "math/arm-common/powl.c",       "math/arm-common/remainder.c",
                    "math/arm-common/remainderf.c", "math/arm-common/remainderl.c", "math/arm-common/remquol.c",
                    "math/arm-common/s_remquo.c",   "math/arm-common/s_remquof.c",  "math/arm-common/scalbn.c",
                    "math/arm64/exp2.S",            "math/arm64/exp2f.S",           "math/arm64/nearbyint.S",
                    "math/arm64/nearbyintf.S",      "math/arm64/nearbyintl.S",      "math/arm64/trunc.S",
                    "math/arm64/truncf.S",          "misc/__p___argv.c",            "misc/__p__acmdln.c",
                    "misc/__p__commode.c",          "misc/__p__fmode.c",            "misc/__p__wcmdln.c",
                    "misc/_getpid.c",               "misc/initenv.c",               "stdio/_setmaxstdio.c",
                    "stdio/gets.c",
                }),
            },
            .msvcr80 => switch (arch) {
                .lib32 => s(.{"misc/imaxabs.c"}),
                .lib64 => s(.{
                    "misc/__p___argv.c",   "misc/__p__acmdln.c",
                    "misc/__p__commode.c", "misc/__p__fmode.c",
                    "misc/__p__wcmdln.c",
                }),
                else => unreachable, // not supported for other targets
            },
            .mingwex => switch (arch) {
                .lib32, .lib64 => s(.{
                    "math/x86/_chgsignl.S",  "math/x86/acosf.c",         "math/x86/acosh.c",
                    "math/x86/acosl.c",      "math/x86/acoshf.c",        "math/x86/acoshl.c",
                    "math/x86/asinf.c",      "math/x86/asinh.c",         "math/x86/asinl.c",
                    "math/x86/asinhf.c",     "math/x86/asinhl.c",        "math/x86/atan2f.c",
                    "math/x86/atan2.c",      "math/x86/atan2l.c",        "math/x86/atanf.c",
                    "math/x86/atanh.c",      "math/x86/atanl.c",         "math/x86/atanhf.c",
                    "math/x86/atanhl.c",     "math/x86/ceil.S",          "math/x86/ceilf.S",
                    "math/x86/ceill.S",      "math/x86/copysignl.S",     "math/x86/cos.c",
                    "math/x86/cosf.c",       "math/x86/cosl.c",          "math/x86/cosl_internal.S",
                    "math/x86/cossin.c",     "math/x86/exp.c",           "math/x86/expl.c",
                    "math/x86/exp2.S",       "math/x86/exp2f.S",         "math/x86/exp2l.S",
                    "math/x86/expm1.c",      "math/x86/expm1f.c",        "math/x86/expm1l.c",
                    "math/x86/floor.S",      "math/x86/floorf.S",        "math/x86/floorl.S",
                    "math/x86/fmod.c",       "math/x86/fmodf.c",         "math/x86/fmodl.c",
                    "math/x86/fucom.c",      "math/x86/ilogb.S",         "math/x86/ilogbf.S",
                    "math/x86/ilogbl.S",     "math/x86/internal_logl.S", "math/x86/ldexp.c",
                    "math/x86/ldexpl.c",     "math/x86/log.c",           "math/x86/log10l.S",
                    "math/x86/log1p.S",      "math/x86/log1pf.S",        "math/x86/log1pl.S",
                    "math/x86/log2.S",       "math/x86/log2f.S",         "math/x86/log2l.S",
                    "math/x86/logb.c",       "math/x86/logbf.c",         "math/x86/logbl.c",
                    "math/x86/logl.c",       "math/x86/nearbyint.S",     "math/x86/nearbyintf.S",
                    "math/x86/nearbyintl.S", "math/x86/pow.c",           "math/x86/powl.c",
                    "math/x86/remainder.S",  "math/x86/remainderf.S",    "math/x86/remainderl.S",
                    "math/x86/remquo.S",     "math/x86/remquof.S",       "math/x86/remquol.S",
                    "math/x86/rint.c",       "math/x86/rintf.c",         "math/x86/scalbn.S",
                    "math/x86/scalbnf.S",    "math/x86/scalbnl.S",       "math/x86/sin.c",
                    "math/x86/sinf.c",       "math/x86/sinl.c",          "math/x86/sinl_internal.S",
                    "math/x86/tanf.c",       "math/x86/tanl.S",          "math/x86/trunc.S",
                    "math/x86/truncf.S",
                }),
                .libarm32 => s(.{
                    "math/arm/_chgsignl.S",     "math/arm/s_rint.c", "math/arm/s_rintf.c",
                    "math/arm-common/ldexpl.c", "math/arm/sincos.S", "math/arm/sincosf.S",
                }),
                .libarm64 => s(.{
                    "math/arm64/_chgsignl.S", "math/arm64/rint.c",    "math/arm64/rintf.c",
                    "math/arm64/sincos.S",    "math/arm64/sincosf.S", "math/arm-common/ldexpl.c",
                }),
            },
            .kernel32 => switch (arch) {
                .lib64 => s(.{
                    "intrincs/bittest64.c",       "intrincs/bittestc64.c",   "intrincs/bittestr64.c",
                    "intrincs/bittestri64.c",     "intrincs/bittests64.c",   "intrincs/bittestsi64.c",
                    "intrincs/bitscanfwd64.c",    "intrincs/bitscanrev64.c", "intrincs/ilockadd64.c",
                    "intrincs/rdtsc.c",           "intrincs/readgsbyte.c",   "intrincs/readgsword.c",
                    "intrincs/readgsdword.c",     "intrincs/readgsqword.c",  "intrincs/writegsbyte.c",
                    "intrincs/writegsword.c",     "intrincs/writegsdword.c", "intrincs/writegsqword.c",
                    "intrincs/mul128ex.c",        "intrincs/umul128ex.c",    "intrincs/_mul128.c",
                    "intrincs/_umul128.c",        "intrincs/__movsq.c",      "intrincs/__stosq.c",
                    "intrincs/__shiftright128.c", "intrincs/bittestci64.c",  "intrincs/__faststorefence.c",
                    "intrincs/__shiftleft128.c",  "intrincs/readcr8.c",      "intrincs/writecr8.c",
                }),
                .lib32 => s(.{
                    "intrincs/rdtsc.c",        "intrincs/readfsbyte.c",  "intrincs/readfsword.c",
                    "intrincs/readfsdword.c",  "intrincs/writefsbyte.c", "intrincs/writefsword.c",
                    "intrincs/writefsdword.c",
                }),
                else => &.{},
            },
            else => &.{},
        };
    }
};
