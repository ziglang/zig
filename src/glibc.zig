const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const path = std.fs.path;
const assert = std.debug.assert;

const target_util = @import("target.zig");
const Compilation = @import("Compilation.zig");
const build_options = @import("build_options");
const trace = @import("tracy.zig").trace;
const Cache = @import("Cache.zig");
const Package = @import("Package.zig");

pub const Lib = struct {
    name: []const u8,
    sover: u8,
};

pub const Fn = struct {
    name: []const u8,
    lib: *const Lib,
};

pub const VerList = struct {
    /// 7 is just the max number, we know statically it's big enough.
    versions: [7]u8,
    len: u8,
};

pub const ABI = struct {
    all_versions: []const std.builtin.Version,
    all_functions: []const Fn,
    /// The value is a pointer to all_functions.len items and each item is an index into all_functions.
    version_table: std.AutoHashMapUnmanaged(target_util.ArchOsAbi, [*]VerList),
    arena_state: std.heap.ArenaAllocator.State,

    pub fn destroy(abi: *ABI, gpa: *Allocator) void {
        abi.version_table.deinit(gpa);
        abi.arena_state.promote(gpa).deinit(); // Frees the ABI memory too.
    }
};

// The order of the elements in this array defines the linking order.
pub const libs = [_]Lib{
    .{ .name = "m", .sover = 6 },
    .{ .name = "pthread", .sover = 0 },
    .{ .name = "c", .sover = 6 },
    .{ .name = "dl", .sover = 2 },
    .{ .name = "rt", .sover = 1 },
    .{ .name = "ld", .sover = 2 },
    .{ .name = "util", .sover = 1 },
};

pub const LoadMetaDataError = error{
    /// The files that ship with the Zig compiler were unable to be read, or otherwise had malformed data.
    ZigInstallationCorrupt,
    OutOfMemory,
};

/// This function will emit a log error when there is a problem with the zig installation and then return
/// `error.ZigInstallationCorrupt`.
pub fn loadMetaData(gpa: *Allocator, zig_lib_dir: std.fs.Dir) LoadMetaDataError!*ABI {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    var all_versions = std.ArrayListUnmanaged(std.builtin.Version){};
    var all_functions = std.ArrayListUnmanaged(Fn){};
    var version_table = std.AutoHashMapUnmanaged(target_util.ArchOsAbi, [*]VerList){};
    errdefer version_table.deinit(gpa);

    var glibc_dir = zig_lib_dir.openDir("libc" ++ path.sep_str ++ "glibc", .{}) catch |err| {
        std.log.err("unable to open glibc dir: {s}", .{@errorName(err)});
        return error.ZigInstallationCorrupt;
    };
    defer glibc_dir.close();

    const max_txt_size = 500 * 1024; // Bigger than this and something is definitely borked.
    const vers_txt_contents = glibc_dir.readFileAlloc(gpa, "vers.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read vers.txt: {s}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(vers_txt_contents);

    // Arena allocated because the result contains references to function names.
    const fns_txt_contents = glibc_dir.readFileAlloc(arena, "fns.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read fns.txt: {s}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };

    const abi_txt_contents = glibc_dir.readFileAlloc(gpa, "abi.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read abi.txt: {s}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(abi_txt_contents);

    {
        var it = mem.tokenize(vers_txt_contents, "\r\n");
        var line_i: usize = 1;
        while (it.next()) |line| : (line_i += 1) {
            const prefix = "GLIBC_";
            if (!mem.startsWith(u8, line, prefix)) {
                std.log.err("vers.txt:{d}: expected 'GLIBC_' prefix", .{line_i});
                return error.ZigInstallationCorrupt;
            }
            const adjusted_line = line[prefix.len..];
            const ver = std.builtin.Version.parse(adjusted_line) catch |err| {
                std.log.err("vers.txt:{d}: unable to parse glibc version '{s}': {s}", .{ line_i, line, @errorName(err) });
                return error.ZigInstallationCorrupt;
            };
            try all_versions.append(arena, ver);
        }
    }
    {
        var file_it = mem.tokenize(fns_txt_contents, "\r\n");
        var line_i: usize = 1;
        while (file_it.next()) |line| : (line_i += 1) {
            var line_it = mem.tokenize(line, " ");
            const fn_name = line_it.next() orelse {
                std.log.err("fns.txt:{d}: expected function name", .{line_i});
                return error.ZigInstallationCorrupt;
            };
            const lib_name = line_it.next() orelse {
                std.log.err("fns.txt:{d}: expected library name", .{line_i});
                return error.ZigInstallationCorrupt;
            };
            const lib = findLib(lib_name) orelse {
                std.log.err("fns.txt:{d}: unknown library name: {s}", .{ line_i, lib_name });
                return error.ZigInstallationCorrupt;
            };
            try all_functions.append(arena, .{
                .name = fn_name,
                .lib = lib,
            });
        }
    }
    {
        var file_it = mem.split(abi_txt_contents, "\n");
        var line_i: usize = 0;
        while (true) {
            const ver_list_base: []VerList = blk: {
                const line = file_it.next() orelse break;
                if (line.len == 0) break;
                line_i += 1;
                const ver_list_base = try arena.alloc(VerList, all_functions.items.len);
                var line_it = mem.tokenize(line, " ");
                while (line_it.next()) |target_string| {
                    var component_it = mem.tokenize(target_string, "-");
                    const arch_name = component_it.next() orelse {
                        std.log.err("abi.txt:{d}: expected arch name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const os_name = component_it.next() orelse {
                        std.log.err("abi.txt:{d}: expected OS name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const abi_name = component_it.next() orelse {
                        std.log.err("abi.txt:{d}: expected ABI name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const arch_tag = std.meta.stringToEnum(std.Target.Cpu.Arch, arch_name) orelse {
                        std.log.err("abi.txt:{d}: unrecognized arch: '{s}'", .{ line_i, arch_name });
                        return error.ZigInstallationCorrupt;
                    };
                    if (!mem.eql(u8, os_name, "linux")) {
                        std.log.err("abi.txt:{d}: expected OS 'linux', found '{s}'", .{ line_i, os_name });
                        return error.ZigInstallationCorrupt;
                    }
                    const abi_tag = std.meta.stringToEnum(std.Target.Abi, abi_name) orelse {
                        std.log.err("abi.txt:{d}: unrecognized ABI: '{s}'", .{ line_i, abi_name });
                        return error.ZigInstallationCorrupt;
                    };

                    const triple = target_util.ArchOsAbi{
                        .arch = arch_tag,
                        .os = .linux,
                        .abi = abi_tag,
                    };
                    try version_table.put(gpa, triple, ver_list_base.ptr);
                }
                break :blk ver_list_base;
            };
            for (ver_list_base) |*ver_list| {
                const line = file_it.next() orelse {
                    std.log.err("abi.txt:{d}: missing version number line", .{line_i});
                    return error.ZigInstallationCorrupt;
                };
                line_i += 1;

                ver_list.* = .{
                    .versions = undefined,
                    .len = 0,
                };
                var line_it = mem.tokenize(line, " ");
                while (line_it.next()) |version_index_string| {
                    if (ver_list.len >= ver_list.versions.len) {
                        // If this happens with legit data, increase the array len in the type.
                        std.log.err("abi.txt:{d}: too many versions", .{line_i});
                        return error.ZigInstallationCorrupt;
                    }
                    const version_index = std.fmt.parseInt(u8, version_index_string, 10) catch |err| {
                        // If this happens with legit data, increase the size of the integer type in the struct.
                        std.log.err("abi.txt:{d}: unable to parse version: {s}", .{ line_i, @errorName(err) });
                        return error.ZigInstallationCorrupt;
                    };

                    ver_list.versions[ver_list.len] = version_index;
                    ver_list.len += 1;
                }
            }
        }
    }

    const abi = try arena.create(ABI);
    abi.* = .{
        .all_versions = all_versions.items,
        .all_functions = all_functions.items,
        .version_table = version_table,
        .arena_state = arena_allocator.state,
    };
    return abi;
}

fn findLib(name: []const u8) ?*const Lib {
    for (libs) |*lib| {
        if (mem.eql(u8, lib.name, name)) {
            return lib;
        }
    }
    return null;
}

pub const CRTFile = enum {
    crti_o,
    crtn_o,
    scrt1_o,
    libc_nonshared_a,
};

pub fn buildCRTFile(comp: *Compilation, crt_file: CRTFile) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }
    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

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
            return comp.build_crt_file("crti", .Obj, &[1]Compilation.CSourceFile{
                .{
                    .src_path = try start_asm_path(comp, arena, "crti.S"),
                    .extra_flags = args.items,
                },
            });
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
            return comp.build_crt_file("crtn", .Obj, &[1]Compilation.CSourceFile{
                .{
                    .src_path = try start_asm_path(comp, arena, "crtn.S"),
                    .extra_flags = args.items,
                },
            });
        },
        .scrt1_o => {
            const start_os: Compilation.CSourceFile = blk: {
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
                break :blk .{
                    .src_path = try start_asm_path(comp, arena, "start.S"),
                    .extra_flags = args.items,
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
                    .extra_flags = args.items,
                };
            };
            return comp.build_crt_file("Scrt1", .Obj, &[_]Compilation.CSourceFile{ start_os, abi_note_o });
        },
        .libc_nonshared_a => {
            const deps = [_][]const u8{
                lib_libc_glibc ++ "stdlib" ++ path.sep_str ++ "atexit.c",
                lib_libc_glibc ++ "stdlib" ++ path.sep_str ++ "at_quick_exit.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "stat.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "fstat.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "lstat.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "stat64.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "fstat64.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "lstat64.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "fstatat.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "fstatat64.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "mknod.c",
                lib_libc_glibc ++ "io" ++ path.sep_str ++ "mknodat.c",
                lib_libc_glibc ++ "nptl" ++ path.sep_str ++ "pthread_atfork.c",
                lib_libc_glibc ++ "debug" ++ path.sep_str ++ "stack_chk_fail_local.c",
            };

            var c_source_files: [deps.len + 1]Compilation.CSourceFile = undefined;

            c_source_files[0] = blk: {
                var args = std.ArrayList([]const u8).init(arena);
                try args.appendSlice(&[_][]const u8{
                    "-std=gnu11",
                    "-fgnu89-inline",
                    "-fmerge-all-constants",
                    "-fno-stack-protector",
                    "-fmath-errno",
                    "-fno-stack-protector",
                    "-I",
                    try lib_path(comp, arena, lib_libc_glibc ++ "csu"),
                });
                try add_include_dirs(comp, arena, &args);
                try args.appendSlice(&[_][]const u8{
                    "-DSTACK_PROTECTOR_LEVEL=0",
                    "-fPIC",
                    "-fno-stack-protector",
                    "-ftls-model=initial-exec",
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
                break :blk .{
                    .src_path = try lib_path(comp, arena, lib_libc_glibc ++ "csu" ++ path.sep_str ++ "elf-init.c"),
                    .extra_flags = args.items,
                };
            };

            for (deps) |dep, i| {
                var args = std.ArrayList([]const u8).init(arena);
                try args.appendSlice(&[_][]const u8{
                    "-std=gnu11",
                    "-fgnu89-inline",
                    "-fmerge-all-constants",
                    "-fno-stack-protector",
                    "-fmath-errno",
                    "-ftls-model=initial-exec",
                    "-Wno-ignored-attributes",
                });
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
                    "-DLIBC_NONSHARED=1",
                    "-DTOP_NAMESPACE=glibc",
                });
                c_source_files[i + 1] = .{
                    .src_path = try lib_path(comp, arena, dep),
                    .extra_flags = args.items,
                };
            }
            return comp.build_crt_file("c_nonshared", .Lib, &c_source_files);
        },
    }
}

fn start_asm_path(comp: *Compilation, arena: *Allocator, basename: []const u8) ![]const u8 {
    const arch = comp.getTarget().cpu.arch;
    const is_ppc = arch == .powerpc or arch == .powerpc64 or arch == .powerpc64le;
    const is_aarch64 = arch == .aarch64 or arch == .aarch64_be;
    const is_sparc = arch == .sparc or arch == .sparcel or arch == .sparcv9;
    const is_64 = arch.ptrBitWidth() == 64;

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
    } else if (arch == .i386) {
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
    }

    try result.appendSlice(s);
    try result.appendSlice(basename);
    return result.items;
}

fn add_include_dirs(comp: *Compilation, arena: *Allocator, args: *std.ArrayList([]const u8)) error{OutOfMemory}!void {
    const target = comp.getTarget();
    const arch = target.cpu.arch;
    const opt_nptl: ?[]const u8 = if (target.os.tag == .linux) "nptl" else "htl";
    const glibc = try lib_path(comp, arena, lib_libc ++ "glibc");

    const s = path.sep_str;

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "include"));

    if (target.os.tag == .linux) {
        try add_include_dirs_arch(arena, args, arch, null, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix" ++ s ++ "sysv" ++ s ++ "linux"));
    }

    if (opt_nptl) |nptl| {
        try add_include_dirs_arch(arena, args, arch, nptl, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps"));
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

    try add_include_dirs_arch(arena, args, arch, null, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix"));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix"));

    try add_include_dirs_arch(arena, args, arch, null, try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps"));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "generic"));

    try args.append("-I");
    try args.append(try path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, lib_libc ++ "glibc" }));

    try args.append("-I");
    try args.append(try std.fmt.allocPrint(arena, "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-{s}", .{
        comp.zig_lib_directory.path.?, @tagName(arch), @tagName(target.os.tag), @tagName(target.abi),
    }));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc ++ "include" ++ s ++ "generic-glibc"));

    try args.append("-I");
    try args.append(try std.fmt.allocPrint(arena, "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-linux-any", .{
        comp.zig_lib_directory.path.?, @tagName(arch),
    }));

    try args.append("-I");
    try args.append(try lib_path(comp, arena, lib_libc ++ "include" ++ s ++ "any-linux-any"));
}

fn add_include_dirs_arch(
    arena: *Allocator,
    args: *std.ArrayList([]const u8),
    arch: std.Target.Cpu.Arch,
    opt_nptl: ?[]const u8,
    dir: []const u8,
) error{OutOfMemory}!void {
    const is_x86 = arch == .i386 or arch == .x86_64;
    const is_aarch64 = arch == .aarch64 or arch == .aarch64_be;
    const is_ppc = arch == .powerpc or arch == .powerpc64 or arch == .powerpc64le;
    const is_sparc = arch == .sparc or arch == .sparcel or arch == .sparcv9;
    const is_64 = arch.ptrBitWidth() == 64;

    const s = path.sep_str;

    if (is_x86) {
        if (arch == .x86_64) {
            if (opt_nptl) |nptl| {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "x86_64", nptl }));
            } else {
                try args.append("-I");
                try args.append(try path.join(arena, &[_][]const u8{ dir, "x86_64" }));
            }
        } else if (arch == .i386) {
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
    }
}

fn path_from_lib(comp: *Compilation, arena: *Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, sub_path });
}

const lib_libc = "libc" ++ path.sep_str;
const lib_libc_glibc = lib_libc ++ "glibc" ++ path.sep_str;

fn lib_path(comp: *Compilation, arena: *Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &[_][]const u8{ comp.zig_lib_directory.path.?, sub_path });
}

pub const BuiltSharedObjects = struct {
    lock: Cache.Lock,
    dir_path: []u8,

    pub fn deinit(self: *BuiltSharedObjects, gpa: *Allocator) void {
        self.lock.release();
        gpa.free(self.dir_path);
        self.* = undefined;
    }
};

const all_map_basename = "all.map";

pub fn buildSharedObjects(comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    var arena_allocator = std.heap.ArenaAllocator.init(comp.gpa);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const target = comp.getTarget();
    const target_version = target.os.version_range.linux.glibc;

    // Use the global cache directory.
    var cache_parent: Cache = .{
        .gpa = comp.gpa,
        .manifest_dir = try comp.global_cache_directory.handle.makeOpenPath("h", .{}),
    };
    defer cache_parent.manifest_dir.close();

    var cache = cache_parent.obtain();
    defer cache.deinit();
    cache.hash.addBytes(build_options.version);
    cache.hash.addBytes(comp.zig_lib_directory.path orelse ".");
    cache.hash.add(target.cpu.arch);
    cache.hash.add(target.abi);
    cache.hash.add(target_version);

    const hit = try cache.hit();
    const digest = cache.final();
    const o_sub_path = try path.join(arena, &[_][]const u8{ "o", &digest });

    // Even if we get a hit, it doesn't guarantee that we finished the job last time.
    // We use the presence of an "ok" file to determine if it is a true hit.

    var o_directory: Compilation.Directory = .{
        .handle = try comp.global_cache_directory.handle.makeOpenPath(o_sub_path, .{}),
        .path = try path.join(arena, &[_][]const u8{ comp.global_cache_directory.path.?, o_sub_path }),
    };
    defer o_directory.handle.close();

    const ok_basename = "ok";
    const actual_hit = if (hit) blk: {
        o_directory.handle.access(ok_basename, .{}) catch |err| switch (err) {
            error.FileNotFound => break :blk false,
            else => |e| return e,
        };
        break :blk true;
    } else false;

    if (!actual_hit) {
        const metadata = try loadMetaData(comp.gpa, comp.zig_lib_directory.handle);
        defer metadata.destroy(comp.gpa);

        const ver_list_base = metadata.version_table.get(.{
            .arch = target.cpu.arch,
            .os = target.os.tag,
            .abi = target.abi,
        }) orelse return error.GLibCUnavailableForThisTarget;
        const target_ver_index = for (metadata.all_versions) |ver, i| {
            switch (ver.order(target_version)) {
                .eq => break i,
                .lt => continue,
                .gt => {
                    // TODO Expose via compile error mechanism instead of log.
                    std.log.err("invalid target glibc version: {}", .{target_version});
                    return error.InvalidTargetGLibCVersion;
                },
            }
        } else {
            const latest_index = metadata.all_versions.len - 1;
            // TODO Expose via compile error mechanism instead of log.
            std.log.err("zig does not yet provide glibc version {}, the max provided version is {}", .{
                target_version, metadata.all_versions[latest_index],
            });
            return error.InvalidTargetGLibCVersion;
        };
        {
            var map_contents = std.ArrayList(u8).init(arena);
            for (metadata.all_versions) |ver| {
                if (ver.patch == 0) {
                    try map_contents.writer().print("GLIBC_{d}.{d} {{ }};\n", .{ ver.major, ver.minor });
                } else {
                    try map_contents.writer().print("GLIBC_{d}.{d}.{d} {{ }};\n", .{ ver.major, ver.minor, ver.patch });
                }
            }
            try o_directory.handle.writeFile(all_map_basename, map_contents.items);
            map_contents.deinit(); // The most recent allocation of an arena can be freed :)
        }
        var zig_body = std.ArrayList(u8).init(comp.gpa);
        defer zig_body.deinit();
        for (libs) |*lib| {
            zig_body.shrinkRetainingCapacity(0);

            for (metadata.all_functions) |*libc_fn, fn_i| {
                if (libc_fn.lib != lib) continue;

                const ver_list = ver_list_base[fn_i];
                // Pick the default symbol version:
                // - If there are no versions, don't emit it
                // - Take the greatest one <= than the target one
                // - If none of them is <= than the
                //   specified one don't pick any default version
                if (ver_list.len == 0) continue;
                var chosen_def_ver_index: u8 = 255;
                {
                    var ver_i: u8 = 0;
                    while (ver_i < ver_list.len) : (ver_i += 1) {
                        const ver_index = ver_list.versions[ver_i];
                        if ((chosen_def_ver_index == 255 or ver_index > chosen_def_ver_index) and
                            target_ver_index >= ver_index)
                        {
                            chosen_def_ver_index = ver_index;
                        }
                    }
                }
                {
                    var ver_i: u8 = 0;
                    while (ver_i < ver_list.len) : (ver_i += 1) {
                        // Example:
                        // .globl _Exit_2_2_5
                        // .type _Exit_2_2_5, %function;
                        // .symver _Exit_2_2_5, _Exit@@GLIBC_2.2.5
                        // _Exit_2_2_5:
                        const ver_index = ver_list.versions[ver_i];
                        const ver = metadata.all_versions[ver_index];
                        const sym_name = libc_fn.name;
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
                            try zig_body.writer().print(
                                \\.globl {s}
                                \\.type {s}, %function;
                                \\.symver {s}, {s}{s}GLIBC_{d}.{d}
                                \\{s}:
                                \\
                            , .{
                                sym_plus_ver,
                                sym_plus_ver,
                                sym_plus_ver,
                                sym_name,
                                at_sign_str,
                                ver.major,
                                ver.minor,
                                sym_plus_ver,
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
                            try zig_body.writer().print(
                                \\.globl {s}
                                \\.type {s}, %function;
                                \\.symver {s}, {s}{s}GLIBC_{d}.{d}.{d}
                                \\{s}:
                                \\
                            , .{
                                sym_plus_ver,
                                sym_plus_ver,
                                sym_plus_ver,
                                sym_name,
                                at_sign_str,
                                ver.major,
                                ver.minor,
                                ver.patch,
                                sym_plus_ver,
                            });
                        }
                    }
                }
            }

            var lib_name_buf: [32]u8 = undefined; // Larger than each of the names "c", "pthread", etc.
            const asm_file_basename = std.fmt.bufPrint(&lib_name_buf, "{s}.s", .{lib.name}) catch unreachable;
            try o_directory.handle.writeFile(asm_file_basename, zig_body.items);

            try buildSharedLib(comp, arena, comp.global_cache_directory, o_directory, asm_file_basename, lib);
        }
        // No need to write the manifest because there are no file inputs associated with this cache hash.
        // However we do need to write the ok file now.
        if (o_directory.handle.createFile(ok_basename, .{})) |file| {
            file.close();
        } else |err| {
            std.log.warn("glibc shared objects: failed to mark completion: {s}", .{@errorName(err)});
        }
    }

    assert(comp.glibc_so_files == null);
    comp.glibc_so_files = BuiltSharedObjects{
        .lock = cache.toOwnedLock(),
        .dir_path = try path.join(comp.gpa, &[_][]const u8{ comp.global_cache_directory.path.?, o_sub_path }),
    };
}

// zig fmt: on

fn buildSharedLib(
    comp: *Compilation,
    arena: *Allocator,
    zig_cache_directory: Compilation.Directory,
    bin_directory: Compilation.Directory,
    asm_file_basename: []const u8,
    lib: *const Lib,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const basename = try std.fmt.allocPrint(arena, "lib{s}.so.{d}", .{ lib.name, lib.sover });
    const emit_bin = Compilation.EmitLoc{
        .directory = bin_directory,
        .basename = basename,
    };
    const version: std.builtin.Version = .{ .major = lib.sover, .minor = 0, .patch = 0 };
    const ld_basename = path.basename(comp.getTarget().standardDynamicLinkerPath().get().?);
    const soname = if (mem.eql(u8, lib.name, "ld")) ld_basename else basename;
    const map_file_path = try path.join(arena, &[_][]const u8{ bin_directory.path.?, all_map_basename });
    const c_source_files = [1]Compilation.CSourceFile{
        .{
            .src_path = try path.join(arena, &[_][]const u8{ bin_directory.path.?, asm_file_basename }),
        },
    };
    const sub_compilation = try Compilation.create(comp.gpa, .{
        .local_cache_directory = zig_cache_directory,
        .global_cache_directory = comp.global_cache_directory,
        .zig_lib_directory = comp.zig_lib_directory,
        .target = comp.getTarget(),
        .root_name = lib.name,
        .root_pkg = null,
        .output_mode = .Lib,
        .link_mode = .Dynamic,
        .thread_pool = comp.thread_pool,
        .libc_installation = comp.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = comp.compilerRtOptMode(),
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_red_zone = comp.bin_file.options.red_zone,
        .want_valgrind = false,
        .want_tsan = false,
        .emit_h = null,
        .strip = comp.compilerRtStrip(),
        .is_native_os = false,
        .is_native_abi = false,
        .self_exe_path = comp.self_exe_path,
        .verbose_cc = comp.verbose_cc,
        .verbose_link = comp.bin_file.options.verbose_link,
        .verbose_air = comp.verbose_air,
        .verbose_llvm_ir = comp.verbose_llvm_ir,
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

    try sub_compilation.updateSubCompilation();
}
