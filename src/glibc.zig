const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const log = std.log;
const fs = std.fs;
const path = fs.path;
const assert = std.debug.assert;
const Version = std.SemanticVersion;

const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const trace = @import("tracy.zig").trace;
const Cache = std.Build.Cache;
const Module = @import("Package/Module.zig");

pub const Lib = struct {
    name: []const u8,
    sover: u8,
    removed_in: ?Version = null,
};

pub const ABI = struct {
    all_versions: []const Version, // all defined versions (one abilist from v2.0.0 up to current)
    all_targets: []const std.zig.target.ArchOsAbi,
    /// The bytes from the file verbatim, starting from the u16 number
    /// of function inclusions.
    inclusions: []const u8,
    arena_state: std.heap.ArenaAllocator.State,

    pub fn destroy(abi: *ABI, gpa: Allocator) void {
        abi.arena_state.promote(gpa).deinit();
    }
};

// The order of the elements in this array defines the linking order.
pub const libs = [_]Lib{
    .{ .name = "m", .sover = 6 },
    .{ .name = "pthread", .sover = 0, .removed_in = .{ .major = 2, .minor = 34, .patch = 0 } },
    .{ .name = "c", .sover = 6 },
    .{ .name = "dl", .sover = 2, .removed_in = .{ .major = 2, .minor = 34, .patch = 0 } },
    .{ .name = "rt", .sover = 1, .removed_in = .{ .major = 2, .minor = 34, .patch = 0 } },
    .{ .name = "ld", .sover = 2 },
    .{ .name = "util", .sover = 1, .removed_in = .{ .major = 2, .minor = 34, .patch = 0 } },
    .{ .name = "resolv", .sover = 2 },
};

pub const LoadMetaDataError = error{
    /// The files that ship with the Zig compiler were unable to be read, or otherwise had malformed data.
    ZigInstallationCorrupt,
    OutOfMemory,
};

pub const abilists_path = "libc" ++ path.sep_str ++ "glibc" ++ path.sep_str ++ "abilists";
pub const abilists_max_size = 800 * 1024; // Bigger than this and something is definitely borked.

/// This function will emit a log error when there is a problem with the zig
/// installation and then return `error.ZigInstallationCorrupt`.
pub fn loadMetaData(gpa: Allocator, contents: []const u8) LoadMetaDataError!*ABI {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var index: usize = 0;

    {
        const libs_len = contents[index];
        index += 1;

        var i: u8 = 0;
        while (i < libs_len) : (i += 1) {
            const lib_name = mem.sliceTo(contents[index..], 0);
            index += lib_name.len + 1;

            if (i >= libs.len or !mem.eql(u8, libs[i].name, lib_name)) {
                log.err("libc" ++ path.sep_str ++ "glibc" ++ path.sep_str ++
                    "abilists: invalid library name or index ({d}): '{s}'", .{ i, lib_name });
                return error.ZigInstallationCorrupt;
            }
        }
    }

    const versions = b: {
        const versions_len = contents[index];
        index += 1;

        const versions = try arena.alloc(Version, versions_len);
        var i: u8 = 0;
        while (i < versions.len) : (i += 1) {
            versions[i] = .{
                .major = contents[index + 0],
                .minor = contents[index + 1],
                .patch = contents[index + 2],
            };
            index += 3;
        }
        break :b versions;
    };

    const targets = b: {
        const targets_len = contents[index];
        index += 1;

        const targets = try arena.alloc(std.zig.target.ArchOsAbi, targets_len);
        var i: u8 = 0;
        while (i < targets.len) : (i += 1) {
            const target_name = mem.sliceTo(contents[index..], 0);
            index += target_name.len + 1;

            var component_it = mem.tokenizeScalar(u8, target_name, '-');
            const arch_name = component_it.next() orelse {
                log.err("abilists: expected arch name", .{});
                return error.ZigInstallationCorrupt;
            };
            const os_name = component_it.next() orelse {
                log.err("abilists: expected OS name", .{});
                return error.ZigInstallationCorrupt;
            };
            const abi_name = component_it.next() orelse {
                log.err("abilists: expected ABI name", .{});
                return error.ZigInstallationCorrupt;
            };
            const arch_tag = std.meta.stringToEnum(std.Target.Cpu.Arch, arch_name) orelse {
                log.err("abilists: unrecognized arch: '{s}'", .{arch_name});
                return error.ZigInstallationCorrupt;
            };
            if (!mem.eql(u8, os_name, "linux")) {
                log.err("abilists: expected OS 'linux', found '{s}'", .{os_name});
                return error.ZigInstallationCorrupt;
            }
            const abi_tag = std.meta.stringToEnum(std.Target.Abi, abi_name) orelse {
                log.err("abilists: unrecognized ABI: '{s}'", .{abi_name});
                return error.ZigInstallationCorrupt;
            };

            targets[i] = .{
                .arch = arch_tag,
                .os = .linux,
                .abi = abi_tag,
            };
        }
        break :b targets;
    };

    const abi = try arena.create(ABI);
    abi.* = .{
        .all_versions = versions,
        .all_targets = targets,
        .inclusions = contents[index..],
        .arena_state = arena_allocator.state,
    };
    return abi;
}

fn useElfInitFini(target: std.Target) bool {
    // Legacy architectures use _init/_fini.
    return switch (target.cpu.arch) {
        .arm, .armeb => true,
        .aarch64, .aarch64_be => true,
        .m68k => true,
        .mips, .mipsel, .mips64, .mips64el => true,
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => true,
        .s390x => true,
        .sparc, .sparc64 => true,
        .x86, .x86_64 => true,
        else => false,
    };
}

pub const CrtFile = enum {
    crti_o,
    crtn_o,
    scrt1_o,
    libc_nonshared_a,
};

pub fn buildCrtFile(comp: *Compilation, crt_file: CrtFile, prog_node: std.Progress.Node) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }
    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.root_mod.resolved_target.result;
    const target_ver = target.os.version_range.linux.glibc;
    const nonshared_stat = target_ver.order(.{ .major = 2, .minor = 32, .patch = 0 }) != .gt;
    const start_old_init_fini = target_ver.order(.{ .major = 2, .minor = 33, .patch = 0 }) != .gt;

    // In all cases in this function, we add the C compiler flags to
    // cache_exempt_flags rather than extra_flags, because these arguments
    // depend on only properties that are already covered by the cache
    // manifest. Including these arguments in the cache could only possibly
    // waste computation and create false negatives.

    switch (crt_file) {
        .crti_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_include_dirs(comp, arena, &args);
            try args.appendSlice(&[_][]const u8{
                "-D_LIBC_REENTRANT",
                "-include",
                try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-modules.h"),
                "-DMODULE_NAME=libc",
                "-Wno-nonportable-include-path",
                "-include",
                try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-symbols.h"),
                "-DTOP_NAMESPACE=glibc",
                "-DASSEMBLER",
                "-Wa,--noexecstack",
            });
            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try start_asm_path(comp, arena, "crti.S"),
                    .cache_exempt_flags = args.items,
                    .owner = comp.root_mod,
                },
            };
            return comp.build_crt_file("crti", .Obj, .@"glibc crti.o", prog_node, &files);
        },
        .crtn_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_include_dirs(comp, arena, &args);
            try args.appendSlice(&[_][]const u8{
                "-D_LIBC_REENTRANT",
                "-DMODULE_NAME=libc",
                "-include",
                try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-symbols.h"),
                "-DTOP_NAMESPACE=glibc",
                "-DASSEMBLER",
                "-Wa,--noexecstack",
            });
            var files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try start_asm_path(comp, arena, "crtn.S"),
                    .cache_exempt_flags = args.items,
                    .owner = undefined,
                },
            };
            return comp.build_crt_file("crtn", .Obj, .@"glibc crtn.o", prog_node, &files);
        },
        .scrt1_o => {
            const start_o: Compilation.CSourceFile = blk: {
                var args = std.ArrayList([]const u8).init(arena);
                try add_include_dirs(comp, arena, &args);
                try args.appendSlice(&[_][]const u8{
                    "-D_LIBC_REENTRANT",
                    "-include",
                    try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-modules.h"),
                    "-DMODULE_NAME=libc",
                    "-Wno-nonportable-include-path",
                    "-include",
                    try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-symbols.h"),
                    "-DPIC",
                    "-DSHARED",
                    "-DTOP_NAMESPACE=glibc",
                    "-DASSEMBLER",
                    "-Wa,--noexecstack",
                });
                const src_path = if (start_old_init_fini) "start-2.33.S" else "start.S";
                break :blk .{
                    .src_path = try start_asm_path(comp, arena, src_path),
                    .cache_exempt_flags = args.items,
                    .owner = undefined,
                };
            };
            const abi_note_o: Compilation.CSourceFile = blk: {
                var args = std.ArrayList([]const u8).init(arena);
                try args.appendSlice(&[_][]const u8{
                    "-I",
                    try lib_path(comp, arena, lib_libc_glibc ++ "csu"),
                });
                try add_include_dirs(comp, arena, &args);
                try args.appendSlice(&[_][]const u8{
                    "-D_LIBC_REENTRANT",
                    "-DMODULE_NAME=libc",
                    "-DTOP_NAMESPACE=glibc",
                    "-DASSEMBLER",
                    "-Wa,--noexecstack",
                });
                break :blk .{
                    .src_path = try lib_path(comp, arena, lib_libc_glibc ++ "csu" ++ path.sep_str ++ "abi-note.S"),
                    .cache_exempt_flags = args.items,
                    .owner = undefined,
                };
            };
            const init_o: Compilation.CSourceFile = .{
                .src_path = try lib_path(comp, arena, lib_libc_glibc ++ "csu" ++ path.sep_str ++ "init.c"),
                .owner = undefined,
            };
            var files = [_]Compilation.CSourceFile{ start_o, abi_note_o, init_o };
            const basename = if (comp.config.output_mode == .Exe and !comp.config.pie) "crt1" else "Scrt1";
            return comp.build_crt_file(basename, .Obj, .@"glibc Scrt1.o", prog_node, &files);
        },
        .libc_nonshared_a => {
            const s = path.sep_str;
            const Dep = struct {
                path: []const u8,
                include: bool = true,
            };
            const deps = [_]Dep{
                .{ .path = lib_libc_glibc ++ "stdlib" ++ s ++ "atexit.c" },
                .{ .path = lib_libc_glibc ++ "stdlib" ++ s ++ "at_quick_exit.c" },
                .{ .path = lib_libc_glibc ++ "sysdeps" ++ s ++ "pthread" ++ s ++ "pthread_atfork.c" },
                .{ .path = lib_libc_glibc ++ "debug" ++ s ++ "stack_chk_fail_local.c" },

                // libc_nonshared.a redirected stat functions to xstat until glibc 2.33,
                // when they were finally versioned like other symbols.
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "stat-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "fstat-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "lstat-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "stat64-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "fstat64-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "lstat64-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "fstatat-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "fstatat64-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "mknodat-2.32.c",
                    .include = nonshared_stat,
                },
                .{
                    .path = lib_libc_glibc ++ "io" ++ s ++ "mknod-2.32.c",
                    .include = nonshared_stat,
                },

                // __libc_start_main used to require statically linked init/fini callbacks
                // until glibc 2.34 when they were assimilated into the shared library.
                .{
                    .path = lib_libc_glibc ++ "csu" ++ s ++ "elf-init-2.33.c",
                    .include = start_old_init_fini,
                },
            };

            var files_buf: [deps.len]Compilation.CSourceFile = undefined;
            var files_index: usize = 0;

            for (deps) |dep| {
                if (!dep.include) continue;

                var args = std.ArrayList([]const u8).init(arena);
                try args.appendSlice(&[_][]const u8{
                    "-std=gnu11",
                    "-fgnu89-inline",
                    "-fmerge-all-constants",
                    "-frounding-math",
                    "-Wno-unsupported-floating-point-opt", // For targets that don't support -frounding-math.
                    "-fno-stack-protector",
                    "-fno-common",
                    "-fmath-errno",
                    "-ftls-model=initial-exec",
                    "-Wno-ignored-attributes",
                    "-Qunused-arguments",
                });
                try add_include_dirs(comp, arena, &args);

                if (!useElfInitFini(target)) {
                    try args.append("-DNO_INITFINI");
                }

                if (target.cpu.arch == .x86) {
                    // This prevents i386/sysdep.h from trying to do some
                    // silly and unnecessary inline asm hack that uses weird
                    // syntax that clang does not support.
                    try args.append("-DCAN_USE_REGISTER_ASM_EBP");
                }

                try args.appendSlice(&[_][]const u8{
                    "-D_LIBC_REENTRANT",
                    "-include",
                    try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-modules.h"),
                    "-DMODULE_NAME=libc",
                    "-Wno-nonportable-include-path",
                    "-include",
                    try lib_path(comp, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-symbols.h"),
                    "-DPIC",
                    "-DLIBC_NONSHARED=1",
                    "-DTOP_NAMESPACE=glibc",
                });
                files_buf[files_index] = .{
                    .src_path = try lib_path(comp, arena, dep.path),
                    .cache_exempt_flags = args.items,
                    .owner = undefined,
                };
                files_index += 1;
            }
            const files = files_buf[0..files_index];
            return comp.build_crt_file("c_nonshared", .Lib, .@"glibc libc_nonshared.a", prog_node, files);
        },
    }
}

fn start_asm_path(comp: *Compilation, arena: Allocator, basename: []const u8) ![]const u8 {
    const arch = comp.getTarget().cpu.arch;
    const is_ppc = arch.isPowerPC();
    const is_aarch64 = arch.isAARCH64();
    const is_sparc = arch.isSPARC();
    const is_64 = comp.getTarget().ptrBitWidth() == 64;

    const s = path.sep_str;

    var result = std.ArrayList(u8).init(arena);
    try result.appendSlice(comp.zig_lib_directory.path.?);
    try result.appendSlice(s ++ "libc" ++ s ++ "glibc" ++ s ++ "sysdeps" ++ s);
    if (is_sparc) {
        if (mem.eql(u8, basename, "crti.S") or mem.eql(u8, basename, "crtn.S")) {
            try result.appendSlice("sparc");
        } else {
            if (is_64) {
                try result.appendSlice("sparc" ++ s ++ "sparc64");
            } else {
                try result.appendSlice("sparc" ++ s ++ "sparc32");
            }
        }
    } else if (arch.isARM()) {
        try result.appendSlice("arm");
    } else if (arch.isMIPS()) {
        if (!mem.eql(u8, basename, "crti.S") and !mem.eql(u8, basename, "crtn.S")) {
            try result.appendSlice("mips");
        } else {
            if (is_64) {
                const abi_dir = if (comp.getTarget().abi == .gnuabin32)
                    "n32"
                else
                    "n64";
                try result.appendSlice("mips" ++ s ++ "mips64" ++ s);
                try result.appendSlice(abi_dir);
            } else {
                try result.appendSlice("mips" ++ s ++ "mips32");
            }
        }
    } else if (arch == .x86_64) {
        try result.appendSlice("x86_64");
    } else if (arch == .x86) {
        try result.appendSlice("i386");
    } else if (is_aarch64) {
        try result.appendSlice("aarch64");
    } else if (arch.isRISCV()) {
        try result.appendSlice("riscv");
    } else if (is_ppc) {
        if (is_64) {
            try result.appendSlice("powerpc" ++ s ++ "powerpc64");
        } else {
            try result.appendSlice("powerpc" ++ s ++ "powerpc32");
        }
    } else if (arch == .s390x) {
        try result.appendSlice("s390" ++ s ++ "s390-64");
    } else if (arch.isLoongArch()) {
        try result.appendSlice("loongarch");
    } else if (arch == .m68k) {
        try result.appendSlice("m68k");
    } else if (arch == .arc) {
        try result.appendSlice("arc");
    } else if (arch == .csky) {
        try result.appendSlice("csky" ++ s ++ "abiv2");
    }

    try result.appendSlice(s);
    try result.appendSlice(basename);
    return result.items;
}

fn add_include_dirs(comp: *Compilation, arena: Allocator, args: *std.ArrayList([]const u8)) error{OutOfMemory}!void {
    const target = comp.getTarget();
    const opt_nptl: ?[]const u8 = if (target.os.tag == .linux) "nptl" else "htl";

    const s = path.sep_str;

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "include"));

    if (target.os.tag == .linux) {
        try add_include_dirs_arch(arena, args, target, null, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix" ++ s ++ "sysv" ++ s ++ "linux"));
    }

    if (opt_nptl) |nptl| {
        try add_include_dirs_arch(arena, args, target, nptl, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps"));
    }

    if (target.os.tag == .linux) {
        try args.append("-I");
        try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++
            "unix" ++ s ++ "sysv" ++ s ++ "linux" ++ s ++ "generic"));

        try args.append("-I");
        try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++
            "unix" ++ s ++ "sysv" ++ s ++ "linux" ++ s ++ "include"));
        try args.append("-I");
        try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++
            "unix" ++ s ++ "sysv" ++ s ++ "linux"));
    }
    if (opt_nptl) |nptl| {
        try args.append("-I");
        try args.append(try path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, lib_libc_glibc ++ "sysdeps", nptl }));
    }

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "pthread"));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix" ++ s ++ "sysv"));

    try add_include_dirs_arch(arena, args, target, null, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix"));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix"));

    try add_include_dirs_arch(arena, args, target, null, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps"));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "generic"));

    try args.append("-I");
    try args.append(try path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, lib_libc ++ "glibc" }));

    try args.append("-I");
    try args.append(try std.fmt.allocPrint(arena, "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-{s}", .{
        comp.zig_lib_directory.path.?, @tagName(target.cpu.arch), @tagName(target.os.tag), @tagName(target.abi),
    }));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc ++ "include" ++ s ++ "generic-glibc"));

    const arch_name = target.osArchName();
    try args.append("-I");
    try args.append(try std.fmt.allocPrint(arena, "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-linux-any", .{
        comp.zig_lib_directory.path.?, arch_name,
    }));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc ++ "include" ++ s ++ "any-linux-any"));
}

fn add_include_dirs_arch(
    arena: Allocator,
    args: *std.ArrayList([]const u8),
    target: std.Target,
    opt_nptl: ?[]const u8,
    dir: []const u8,
) error{OutOfMemory}!void {
    const arch = target.cpu.arch;
    const is_x86 = arch.isX86();
    const is_aarch64 = arch.isAARCH64();
    const is_ppc = arch.isPowerPC();
    const is_sparc = arch.isSPARC();
    const is_64 = target.ptrBitWidth() == 64;

    const s = path.sep_str;

    if (is_x86) {
        if (arch == .x86_64) {
            if (opt_nptl) |nptl| {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "x86_64", nptl }));
            } else {
                if (target.abi == .gnux32) {
                    try args.append("-I");
                    try args.append(try path.join(arena, &[_][]const u8{ dir, "x86_64", "x32" }));
                }
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "x86_64" }));
            }
        } else if (arch == .x86) {
            if (opt_nptl) |nptl| {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "i386", nptl }));
            } else {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "i386" }));
            }
        }
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "x86", nptl }));
        } else {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "x86" }));
        }
    } else if (arch.isARM()) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "arm", nptl }));
        } else {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "arm" }));
        }
    } else if (arch.isMIPS()) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "mips", nptl }));
        } else {
            if (is_64) {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "mips" ++ s ++ "mips64" }));
            } else {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "mips" ++ s ++ "mips32" }));
            }
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "mips" }));
        }
    } else if (is_sparc) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "sparc", nptl }));
        } else {
            if (is_64) {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "sparc" ++ s ++ "sparc64" }));
            } else {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "sparc" ++ s ++ "sparc32" }));
            }
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "sparc" }));
        }
    } else if (is_aarch64) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "aarch64", nptl }));
        } else {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "aarch64" }));
        }
    } else if (is_ppc) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "powerpc", nptl }));
        } else {
            if (is_64) {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "powerpc" ++ s ++ "powerpc64" }));
            } else {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "powerpc" ++ s ++ "powerpc32" }));
            }
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "powerpc" }));
        }
    } else if (arch.isRISCV()) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "riscv", nptl }));
        } else {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "riscv" }));
        }
    } else if (arch == .s390x) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "s390", nptl }));
        } else {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "s390" ++ s ++ "s390-64" }));
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "s390" }));
        }
    } else if (arch.isLoongArch()) {
        try args.append("-I");
        try args.append(try path.join(arena, &[_][]const u8{ dir, "loongarch" }));
    } else if (arch == .m68k) {
        if (opt_nptl) |nptl| {
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "m68k", nptl }));
        } else {
            // coldfire ABI support requires: https://github.com/ziglang/zig/issues/20690
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "m68k" ++ s ++ "m680x0" }));
            try args.append("-I");
            try args.append(try path.join(arena, &[_][]const u8{ dir, "m68k" }));
        }
    } else if (arch == .arc) {
        try args.append("-I");
        try args.append(try path.join(arena, &[_][]const u8{ dir, "arc" }));
    } else if (arch == .csky) {
        try args.append("-I");
        try args.append(try path.join(arena, &[_][]const u8{ dir, "csky" }));
    }
}

fn path_from_lib(comp: *Compilation, arena: Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, sub_path });
}

const lib_libc = "libc" ++ path.sep_str;
const lib_libc_glibc = lib_libc ++ "glibc" ++ path.sep_str;

fn lib_path(comp: *Compilation, arena: Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, sub_path });
}

pub const BuiltSharedObjects = struct {
    lock: Cache.Lock,
    dir_path: []u8,

    pub fn deinit(self: *BuiltSharedObjects, gpa: Allocator) void {
        self.lock.release();
        gpa.free(self.dir_path);
        self.* = undefined;
    }
};

const all_map_basename = "all.map";

fn wordDirective(target: std.Target) []const u8 {
    // Based on its description in the GNU `as` manual, you might assume that `.word` is sized
    // according to the target word size. But no; that would just make too much sense.
    return if (target.ptrBitWidth() == 64) ".quad" else ".long";
}

pub fn buildSharedObjects(comp: *Compilation, prog_node: std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.getTarget();
    const target_version = target.os.version_range.linux.glibc;

    // Use the global cache directory.
    var cache: Cache = .{
        .gpa = comp.gpa,
        .manifest_dir = try comp.global_cache_directory.handle.makeOpenPath("h", .{}),
    };
    cache.addPrefix(.{ .path = null, .handle = fs.cwd() });
    cache.addPrefix(comp.zig_lib_directory);
    cache.addPrefix(comp.global_cache_directory);
    defer cache.manifest_dir.close();

    var man = cache.obtain();
    defer man.deinit();
    man.hash.addBytes(build_options.version);
    man.hash.add(target.cpu.arch);
    man.hash.add(target.abi);
    man.hash.add(target_version);

    const full_abilists_path = try comp.zig_lib_directory.join(arena, &.{abilists_path});
    const abilists_index = try man.addFile(full_abilists_path, abilists_max_size);

    if (try man.hit()) {
        const digest = man.final();

        assert(comp.glibc_so_files == null);
        comp.glibc_so_files = BuiltSharedObjects{
            .lock = man.toOwnedLock(),
            .dir_path = try comp.global_cache_directory.join(comp.gpa, &.{ "o", &digest }),
        };
        return;
    }

    const digest = man.final();
    const o_sub_path = try path.join(arena, &[_][]const u8{ "o", &digest });

    var o_directory: Compilation.Directory = .{
        .handle = try comp.global_cache_directory.handle.makeOpenPath(o_sub_path, .{}),
        .path = try comp.global_cache_directory.join(arena, &.{o_sub_path}),
    };
    defer o_directory.handle.close();

    const abilists_contents = man.files.keys()[abilists_index].contents.?;
    const metadata = try loadMetaData(comp.gpa, abilists_contents);
    defer metadata.destroy(comp.gpa);

    const target_targ_index = for (metadata.all_targets, 0..) |targ, i| {
        if (targ.arch == target.cpu.arch and
            targ.os == target.os.tag and
            targ.abi == target.abi)
        {
            break i;
        }
    } else {
        unreachable; // std.zig.target.available_libcs prevents us from getting here
    };

    const target_ver_index = for (metadata.all_versions, 0..) |ver, i| {
        switch (ver.order(target_version)) {
            .eq => break i,
            .lt => continue,
            .gt => {
                // TODO Expose via compile error mechanism instead of log.
                log.warn("invalid target glibc version: {}", .{target_version});
                return error.InvalidTargetGLibCVersion;
            },
        }
    } else blk: {
        const latest_index = metadata.all_versions.len - 1;
        log.warn("zig cannot build new glibc version {}; providing instead {}", .{
            target_version, metadata.all_versions[latest_index],
        });
        break :blk latest_index;
    };

    {
        var map_contents = std.ArrayList(u8).init(arena);
        for (metadata.all_versions[0 .. target_ver_index + 1]) |ver| {
            if (ver.patch == 0) {
                try map_contents.writer().print("GLIBC_{d}.{d} {{ }};\n", .{ ver.major, ver.minor });
            } else {
                try map_contents.writer().print("GLIBC_{d}.{d}.{d} {{ }};\n", .{ ver.major, ver.minor, ver.patch });
            }
        }
        try o_directory.handle.writeFile(.{ .sub_path = all_map_basename, .data = map_contents.items });
        map_contents.deinit(); // The most recent allocation of an arena can be freed :)
    }

    var stubs_asm = std.ArrayList(u8).init(comp.gpa);
    defer stubs_asm.deinit();

    for (libs, 0..) |lib, lib_i| {
        if (lib.removed_in) |rem_in| {
            if (target_version.order(rem_in) != .lt) continue;
        }

        stubs_asm.shrinkRetainingCapacity(0);
        try stubs_asm.appendSlice(".text\n");

        var sym_i: usize = 0;
        var sym_name_buf = std.ArrayList(u8).init(arena);
        var opt_symbol_name: ?[]const u8 = null;
        var versions_buffer: [32]u8 = undefined;
        var versions_len: usize = undefined;

        // There can be situations where there are multiple inclusions for the same symbol with
        // partially overlapping versions, due to different target lists. For example:
        //
        //  lgammal:
        //   library: libm.so
        //   versions: 2.4 2.23
        //   targets: ... powerpc64-linux-gnu s390x-linux-gnu
        //  lgammal:
        //   library: libm.so
        //   versions: 2.2 2.23
        //   targets: sparc64-linux-gnu s390x-linux-gnu
        //
        // If we don't handle this, we end up writing the default `lgammal` symbol for version 2.33
        // twice, which causes a "duplicate symbol" assembler error.
        var versions_written = std.AutoArrayHashMap(Version, void).init(arena);

        var inc_fbs = std.io.fixedBufferStream(metadata.inclusions);
        var inc_reader = inc_fbs.reader();

        const fn_inclusions_len = try inc_reader.readInt(u16, .little);

        while (sym_i < fn_inclusions_len) : (sym_i += 1) {
            const sym_name = opt_symbol_name orelse n: {
                sym_name_buf.clearRetainingCapacity();
                try inc_reader.streamUntilDelimiter(sym_name_buf.writer(), 0, null);

                opt_symbol_name = sym_name_buf.items;
                versions_buffer = undefined;
                versions_len = 0;

                break :n sym_name_buf.items;
            };
            const targets = try std.leb.readUleb128(u64, inc_reader);
            var lib_index = try inc_reader.readByte();

            const is_terminal = (lib_index & (1 << 7)) != 0;
            if (is_terminal) {
                lib_index &= ~@as(u8, 1 << 7);
                opt_symbol_name = null;
            }

            // Test whether the inclusion applies to our current library and target.
            const ok_lib_and_target =
                (lib_index == lib_i) and
                ((targets & (@as(u64, 1) << @as(u6, @intCast(target_targ_index)))) != 0);

            while (true) {
                const byte = try inc_reader.readByte();
                const last = (byte & 0b1000_0000) != 0;
                const ver_i = @as(u7, @truncate(byte));
                if (ok_lib_and_target and ver_i <= target_ver_index) {
                    versions_buffer[versions_len] = ver_i;
                    versions_len += 1;
                }
                if (last) break;
            }

            if (!is_terminal) continue;

            // Pick the default symbol version:
            // - If there are no versions, don't emit it
            // - Take the greatest one <= than the target one
            // - If none of them is <= than the
            //   specified one don't pick any default version
            if (versions_len == 0) continue;
            var chosen_def_ver_index: u8 = 255;
            {
                var ver_buf_i: u8 = 0;
                while (ver_buf_i < versions_len) : (ver_buf_i += 1) {
                    const ver_index = versions_buffer[ver_buf_i];
                    if (chosen_def_ver_index == 255 or ver_index > chosen_def_ver_index) {
                        chosen_def_ver_index = ver_index;
                    }
                }
            }

            versions_written.clearRetainingCapacity();
            try versions_written.ensureTotalCapacity(versions_len);

            {
                var ver_buf_i: u8 = 0;
                while (ver_buf_i < versions_len) : (ver_buf_i += 1) {
                    // Example:
                    // .balign 4
                    // .globl _Exit_2_2_5
                    // .type _Exit_2_2_5, %function;
                    // .symver _Exit_2_2_5, _Exit@@GLIBC_2.2.5
                    // _Exit_2_2_5: .long 0
                    const ver_index = versions_buffer[ver_buf_i];
                    const ver = metadata.all_versions[ver_index];

                    if (versions_written.getOrPutAssumeCapacity(ver).found_existing) continue;

                    // Default symbol version definition vs normal symbol version definition
                    const want_default = chosen_def_ver_index != 255 and ver_index == chosen_def_ver_index;
                    const at_sign_str: []const u8 = if (want_default) "@@" else "@";
                    if (ver.patch == 0) {
                        const sym_plus_ver = if (want_default)
                            sym_name
                        else
                            try std.fmt.allocPrint(
                                arena,
                                "{s}_GLIBC_{d}_{d}",
                                .{ sym_name, ver.major, ver.minor },
                            );
                        try stubs_asm.writer().print(
                            \\.balign {d}
                            \\.globl {s}
                            \\.type {s}, %function;
                            \\.symver {s}, {s}{s}GLIBC_{d}.{d}
                            \\{s}: {s} 0
                            \\
                        , .{
                            target.ptrBitWidth() / 8,
                            sym_plus_ver,
                            sym_plus_ver,
                            sym_plus_ver,
                            sym_name,
                            at_sign_str,
                            ver.major,
                            ver.minor,
                            sym_plus_ver,
                            wordDirective(target),
                        });
                    } else {
                        const sym_plus_ver = if (want_default)
                            sym_name
                        else
                            try std.fmt.allocPrint(
                                arena,
                                "{s}_GLIBC_{d}_{d}_{d}",
                                .{ sym_name, ver.major, ver.minor, ver.patch },
                            );
                        try stubs_asm.writer().print(
                            \\.balign {d}
                            \\.globl {s}
                            \\.type {s}, %function;
                            \\.symver {s}, {s}{s}GLIBC_{d}.{d}.{d}
                            \\{s}: {s} 0
                            \\
                        , .{
                            target.ptrBitWidth() / 8,
                            sym_plus_ver,
                            sym_plus_ver,
                            sym_plus_ver,
                            sym_name,
                            at_sign_str,
                            ver.major,
                            ver.minor,
                            ver.patch,
                            sym_plus_ver,
                            wordDirective(target),
                        });
                    }
                }
            }
        }

        try stubs_asm.appendSlice(".data\n");

        // For some targets, the real `libc.so.6` will contain a weak reference to `_IO_stdin_used`,
        // making the linker put the symbol in the dynamic symbol table. We likewise need to emit a
        // reference to it here for that effect, or it will not show up, which in turn will cause
        // the real glibc to think that the program was built against an ancient `FILE` structure
        // (pre-glibc 2.1).
        //
        // Note that glibc only compiles in the legacy compatibility code for some targets; it
        // depends on what is defined in the `shlib-versions` file for the particular architecture
        // and ABI. Those files are preprocessed by 2 separate tools during the glibc build to get
        // the final `abi-versions.h`, so it would be quite brittle to try to condition our emission
        // of the `_IO_stdin_used` reference in the exact same way. The only downside of emitting
        // the reference unconditionally is that it ends up being unused for newer targets; it
        // otherwise has no negative effect.
        //
        // glibc uses a weak reference because it has to work with programs compiled against pre-2.1
        // versions where the symbol didn't exist. We only care about modern glibc versions, so use
        // a strong reference.
        if (std.mem.eql(u8, lib.name, "c")) {
            try stubs_asm.writer().print(
                \\.balign {d}
                \\.globl _IO_stdin_used
                \\{s} _IO_stdin_used
                \\
            , .{
                target.ptrBitWidth() / 8,
                wordDirective(target),
            });
        }

        const obj_inclusions_len = try inc_reader.readInt(u16, .little);

        sym_i = 0;
        opt_symbol_name = null;
        versions_buffer = undefined;
        versions_len = undefined;
        while (sym_i < obj_inclusions_len) : (sym_i += 1) {
            const sym_name = opt_symbol_name orelse n: {
                sym_name_buf.clearRetainingCapacity();
                try inc_reader.streamUntilDelimiter(sym_name_buf.writer(), 0, null);

                opt_symbol_name = sym_name_buf.items;
                versions_buffer = undefined;
                versions_len = 0;

                break :n sym_name_buf.items;
            };
            const targets = try std.leb.readUleb128(u64, inc_reader);
            const size = try std.leb.readUleb128(u16, inc_reader);
            var lib_index = try inc_reader.readByte();

            const is_terminal = (lib_index & (1 << 7)) != 0;
            if (is_terminal) {
                lib_index &= ~@as(u8, 1 << 7);
                opt_symbol_name = null;
            }

            // Test whether the inclusion applies to our current library and target.
            const ok_lib_and_target =
                (lib_index == lib_i) and
                ((targets & (@as(u64, 1) << @as(u6, @intCast(target_targ_index)))) != 0);

            while (true) {
                const byte = try inc_reader.readByte();
                const last = (byte & 0b1000_0000) != 0;
                const ver_i = @as(u7, @truncate(byte));
                if (ok_lib_and_target and ver_i <= target_ver_index) {
                    versions_buffer[versions_len] = ver_i;
                    versions_len += 1;
                }
                if (last) break;
            }

            if (!is_terminal) continue;

            // Pick the default symbol version:
            // - If there are no versions, don't emit it
            // - Take the greatest one <= than the target one
            // - If none of them is <= than the
            //   specified one don't pick any default version
            if (versions_len == 0) continue;
            var chosen_def_ver_index: u8 = 255;
            {
                var ver_buf_i: u8 = 0;
                while (ver_buf_i < versions_len) : (ver_buf_i += 1) {
                    const ver_index = versions_buffer[ver_buf_i];
                    if (chosen_def_ver_index == 255 or ver_index > chosen_def_ver_index) {
                        chosen_def_ver_index = ver_index;
                    }
                }
            }

            versions_written.clearRetainingCapacity();
            try versions_written.ensureTotalCapacity(versions_len);

            {
                var ver_buf_i: u8 = 0;
                while (ver_buf_i < versions_len) : (ver_buf_i += 1) {
                    // Example:
                    // .balign 4
                    // .globl environ_2_2_5
                    // .type environ_2_2_5, %object;
                    // .size environ_2_2_5, 4;
                    // .symver environ_2_2_5, environ@@GLIBC_2.2.5
                    // environ_2_2_5: .fill 4, 1, 0
                    const ver_index = versions_buffer[ver_buf_i];
                    const ver = metadata.all_versions[ver_index];

                    if (versions_written.getOrPutAssumeCapacity(ver).found_existing) continue;

                    // Default symbol version definition vs normal symbol version definition
                    const want_default = chosen_def_ver_index != 255 and ver_index == chosen_def_ver_index;
                    const at_sign_str: []const u8 = if (want_default) "@@" else "@";
                    if (ver.patch == 0) {
                        const sym_plus_ver = if (want_default)
                            sym_name
                        else
                            try std.fmt.allocPrint(
                                arena,
                                "{s}_GLIBC_{d}_{d}",
                                .{ sym_name, ver.major, ver.minor },
                            );
                        try stubs_asm.writer().print(
                            \\.balign {d}
                            \\.globl {s}
                            \\.type {s}, %object;
                            \\.size {s}, {d};
                            \\.symver {s}, {s}{s}GLIBC_{d}.{d}
                            \\{s}: .fill {d}, 1, 0
                            \\
                        , .{
                            target.ptrBitWidth() / 8,
                            sym_plus_ver,
                            sym_plus_ver,
                            sym_plus_ver,
                            size,
                            sym_plus_ver,
                            sym_name,
                            at_sign_str,
                            ver.major,
                            ver.minor,
                            sym_plus_ver,
                            size,
                        });
                    } else {
                        const sym_plus_ver = if (want_default)
                            sym_name
                        else
                            try std.fmt.allocPrint(
                                arena,
                                "{s}_GLIBC_{d}_{d}_{d}",
                                .{ sym_name, ver.major, ver.minor, ver.patch },
                            );
                        try stubs_asm.writer().print(
                            \\.balign {d}
                            \\.globl {s}
                            \\.type {s}, %object;
                            \\.size {s}, {d};
                            \\.symver {s}, {s}{s}GLIBC_{d}.{d}.{d}
                            \\{s}: .fill {d}, 1, 0
                            \\
                        , .{
                            target.ptrBitWidth() / 8,
                            sym_plus_ver,
                            sym_plus_ver,
                            sym_plus_ver,
                            size,
                            sym_plus_ver,
                            sym_name,
                            at_sign_str,
                            ver.major,
                            ver.minor,
                            ver.patch,
                            sym_plus_ver,
                            size,
                        });
                    }
                }
            }
        }

        var lib_name_buf: [32]u8 = undefined; // Larger than each of the names "c", "pthread", etc.
        const asm_file_basename = std.fmt.bufPrint(&lib_name_buf, "{s}.s", .{lib.name}) catch unreachable;
        try o_directory.handle.writeFile(.{ .sub_path = asm_file_basename, .data = stubs_asm.items });

        try buildSharedLib(comp, arena, comp.global_cache_directory, o_directory, asm_file_basename, lib, prog_node);
    }

    man.writeManifest() catch |err| {
        log.warn("failed to write cache manifest for glibc stubs: {s}", .{@errorName(err)});
    };

    assert(comp.glibc_so_files == null);
    comp.glibc_so_files = BuiltSharedObjects{
        .lock = man.toOwnedLock(),
        .dir_path = try comp.global_cache_directory.join(comp.gpa, &.{ "o", &digest }),
    };
}

// zig fmt: on

fn buildSharedLib(
    comp: *Compilation,
    arena: Allocator,
    zig_cache_directory: Compilation.Directory,
    bin_directory: Compilation.Directory,
    asm_file_basename: []const u8,
    lib: Lib,
    prog_node: std.Progress.Node,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const basename = try std.fmt.allocPrint(arena, "lib{s}.so.{d}", .{ lib.name, lib.sover });
    const emit_bin = Compilation.EmitLoc{
        .directory = bin_directory,
        .basename = basename,
    };
    const version: Version = .{ .major = lib.sover, .minor = 0, .patch = 0 };
    const ld_basename = path.basename(comp.getTarget().standardDynamicLinkerPath().get().?);
    const soname = if (mem.eql(u8, lib.name, "ld")) ld_basename else basename;
    const map_file_path = try path.join(arena, &.{ bin_directory.path.?, all_map_basename });

    const optimize_mode = comp.compilerRtOptMode();
    const strip = comp.compilerRtStrip();
    const config = try Compilation.Config.resolve(.{
        .output_mode = .Lib,
        .link_mode = .dynamic,
        .resolved_target = comp.root_mod.resolved_target,
        .is_test = false,
        .have_zcu = false,
        .emit_bin = true,
        .root_optimize_mode = optimize_mode,
        .root_strip = strip,
        .link_libc = false,
    });

    const root_mod = try Module.create(arena, .{
        .global_cache_directory = comp.global_cache_directory,
        .paths = .{
            .root = .{ .root_dir = comp.zig_lib_directory },
            .root_src_path = "",
        },
        .fully_qualified_name = "root",
        .inherited = .{
            .resolved_target = comp.root_mod.resolved_target,
            .strip = strip,
            .stack_check = false,
            .stack_protector = 0,
            .sanitize_c = false,
            .sanitize_thread = false,
            .red_zone = comp.root_mod.red_zone,
            .omit_frame_pointer = comp.root_mod.omit_frame_pointer,
            .valgrind = false,
            .optimize_mode = optimize_mode,
            .structured_cfg = comp.root_mod.structured_cfg,
        },
        .global = config,
        .cc_argv = &.{},
        .parent = null,
        .builtin_mod = null,
        .builtin_modules = null, // there is only one module in this compilation
    });

    const c_source_files = [1]Compilation.CSourceFile{
        .{
            .src_path = try path.join(arena, &.{ bin_directory.path.?, asm_file_basename }),
            .owner = root_mod,
        },
    };

    const sub_compilation = try Compilation.create(comp.gpa, arena, .{
        .local_cache_directory = zig_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .thread_pool = comp.thread_pool,
        .self_exe_path = comp.self_exe_path,
        .cache_mode = .incremental,
        .config = config,
        .root_mod = root_mod,
        .root_name = lib.name,
        .libc_installation = comp.libc_installation,
        .emit_bin = emit_bin,
        .emit_h = null,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
        .verbose_llvm_bc = comp.verbose_llvm_bc,
        .verbose_cimport = comp.verbose_cimport,
        .verbose_llvm_cpu_features = comp.verbose_llvm_cpu_features,
        .clang_passthrough_mode = comp.clang_passthrough_mode,
        .version = version,
        .version_script = map_file_path,
        .soname = soname,
        .c_source_files = &c_source_files,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, .@"glibc shared object", prog_node);
}

// Return true if glibc has crti/crtn sources for that architecture.
pub fn needsCrtiCrtn(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .riscv32, .riscv64 => false,
        .loongarch64 => false,
        else => true,
    };
}
