const std = @import("std");
const Allocator = std.mem.Allocator;
const target_util = @import("target.zig");
const mem = std.mem;
const Module = @import("Module.zig");
const path = std.fs.path;
const build_options = @import("build_options");

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

pub const libs = [_]Lib{
    .{ .name = "c", .sover = 6 },
    .{ .name = "m", .sover = 6 },
    .{ .name = "pthread", .sover = 0 },
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
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    var all_versions = std.ArrayListUnmanaged(std.builtin.Version){};
    var all_functions = std.ArrayListUnmanaged(Fn){};
    var version_table = std.AutoHashMapUnmanaged(target_util.ArchOsAbi, [*]VerList){};
    errdefer version_table.deinit(gpa);

    var glibc_dir = zig_lib_dir.openDir("libc" ++ path.sep_str ++ "glibc", .{}) catch |err| {
        std.log.err("unable to open glibc dir: {}", .{@errorName(err)});
        return error.ZigInstallationCorrupt;
    };
    defer glibc_dir.close();

    const max_txt_size = 500 * 1024; // Bigger than this and something is definitely borked.
    const vers_txt_contents = glibc_dir.readFileAlloc(gpa, "vers.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read vers.txt: {}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(vers_txt_contents);

    const fns_txt_contents = glibc_dir.readFileAlloc(gpa, "fns.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read fns.txt: {}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(fns_txt_contents);

    const abi_txt_contents = glibc_dir.readFileAlloc(gpa, "abi.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read abi.txt: {}", .{@errorName(err)});
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
                std.log.err("vers.txt:{}: expected 'GLIBC_' prefix", .{line_i});
                return error.ZigInstallationCorrupt;
            }
            const adjusted_line = line[prefix.len..];
            const ver = std.builtin.Version.parse(adjusted_line) catch |err| {
                std.log.err("vers.txt:{}: unable to parse glibc version '{}': {}", .{ line_i, line, @errorName(err) });
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
                std.log.err("fns.txt:{}: expected function name", .{line_i});
                return error.ZigInstallationCorrupt;
            };
            const lib_name = line_it.next() orelse {
                std.log.err("fns.txt:{}: expected library name", .{line_i});
                return error.ZigInstallationCorrupt;
            };
            const lib = findLib(lib_name) orelse {
                std.log.err("fns.txt:{}: unknown library name: {}", .{ line_i, lib_name });
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
                        std.log.err("abi.txt:{}: expected arch name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const os_name = component_it.next() orelse {
                        std.log.err("abi.txt:{}: expected OS name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const abi_name = component_it.next() orelse {
                        std.log.err("abi.txt:{}: expected ABI name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const arch_tag = std.meta.stringToEnum(std.Target.Cpu.Arch, arch_name) orelse {
                        std.log.err("abi.txt:{}: unrecognized arch: '{}'", .{ line_i, arch_name });
                        return error.ZigInstallationCorrupt;
                    };
                    if (!mem.eql(u8, os_name, "linux")) {
                        std.log.err("abi.txt:{}: expected OS 'linux', found '{}'", .{ line_i, os_name });
                        return error.ZigInstallationCorrupt;
                    }
                    const abi_tag = std.meta.stringToEnum(std.Target.Abi, abi_name) orelse {
                        std.log.err("abi.txt:{}: unrecognized ABI: '{}'", .{ line_i, abi_name });
                        return error.ZigInstallationCorrupt;
                    };

                    const triple = target_util.ArchOsAbi{
                        .arch = arch_tag,
                        .os = .linux,
                        .abi = abi_tag,
                    };
                    try version_table.put(arena, triple, ver_list_base.ptr);
                }
                break :blk ver_list_base;
            };
            for (ver_list_base) |*ver_list| {
                const line = file_it.next() orelse {
                    std.log.err("abi.txt:{}: missing version number line", .{line_i});
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
                        std.log.err("abi.txt:{}: too many versions", .{line_i});
                        return error.ZigInstallationCorrupt;
                    }
                    const version_index = std.fmt.parseInt(u8, version_index_string, 10) catch |err| {
                        // If this happens with legit data, increase the size of the integer type in the struct.
                        std.log.err("abi.txt:{}: unable to parse version: {}", .{ line_i, @errorName(err) });
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
    start_os,
    abi_note_o,
    scrt1_o,
    libc_nonshared_a,
};

pub fn buildCRTFile(mod: *Module, crt_file: CRTFile) !void {
    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }
    const gpa = mod.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    switch (crt_file) {
        .crti_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_include_dirs(mod, arena, &args);
            try args.appendSlice(&[_][]const u8{
                "-D_LIBC_REENTRANT",
                "-include",
                try lib_path(mod, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-modules.h"),
                "-DMODULE_NAME=libc",
                "-Wno-nonportable-include-path",
                "-include",
                try lib_path(mod, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-symbols.h"),
                "-DTOP_NAMESPACE=glibc",
                "-DASSEMBLER",
                "-g",
                "-Wa,--noexecstack",
            });
            const c_source_file: Module.CSourceFile = .{
                .src_path = try start_asm_path(mod, arena, "crti.S"),
                .extra_flags = args.items,
            };
            return build_libc_object(mod, "crti.o", c_source_file);
        },
        .crtn_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_include_dirs(mod, arena, &args);
            try args.appendSlice(&[_][]const u8{
                "-D_LIBC_REENTRANT",
                "-DMODULE_NAME=libc",
                "-DTOP_NAMESPACE=glibc",
                "-DASSEMBLER",
                "-g",
                "-Wa,--noexecstack",
            });
            const c_source_file: Module.CSourceFile = .{
                .src_path = try start_asm_path(mod, arena, "crtn.S"),
                .extra_flags = args.items,
            };
            return build_libc_object(mod, "crtn.o", c_source_file);
        },
        .start_os => {
            var args = std.ArrayList([]const u8).init(arena);
            try add_include_dirs(mod, arena, &args);
            try args.appendSlice(&[_][]const u8{
                "-D_LIBC_REENTRANT",
                "-include",
                try lib_path(mod, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-modules.h"),
                "-DMODULE_NAME=libc",
                "-Wno-nonportable-include-path",
                "-include",
                try lib_path(mod, arena, lib_libc_glibc ++ "include" ++ path.sep_str ++ "libc-symbols.h"),
                "-DPIC",
                "-DSHARED",
                "-DTOP_NAMESPACE=glibc",
                "-DASSEMBLER",
                "-g",
                "-Wa,--noexecstack",
            });
            const c_source_file: Module.CSourceFile = .{
                .src_path = try start_asm_path(mod, arena, "start.S"),
                .extra_flags = args.items,
            };
            return build_libc_object(mod, "start.os", c_source_file);
        },
        .abi_note_o => {
            var args = std.ArrayList([]const u8).init(arena);
            try args.appendSlice(&[_][]const u8{
                "-I",
                try lib_path(mod, arena, lib_libc_glibc ++ "glibc" ++ path.sep_str ++ "csu"),
            });
            try add_include_dirs(mod, arena, &args);
            try args.appendSlice(&[_][]const u8{
                "-D_LIBC_REENTRANT",
                "-DMODULE_NAME=libc",
                "-DTOP_NAMESPACE=glibc",
                "-DASSEMBLER",
                "-g",
                "-Wa,--noexecstack",
            });
            const c_source_file: Module.CSourceFile = .{
                .src_path = try lib_path(mod, arena, lib_libc_glibc ++ "csu" ++ path.sep_str ++ "abi-note.S"),
                .extra_flags = args.items,
            };
            return build_libc_object(mod, "abi-note.o", c_source_file);
        },
        .scrt1_o => {
            return error.Unimplemented; // TODO
        },
        .libc_nonshared_a => {
            return error.Unimplemented; // TODO
        },
    }
}

fn start_asm_path(mod: *Module, arena: *Allocator, basename: []const u8) ![]const u8 {
    const arch = mod.getTarget().cpu.arch;
    const is_ppc = arch == .powerpc or arch == .powerpc64 or arch == .powerpc64le;
    const is_aarch64 = arch == .aarch64 or arch == .aarch64_be;
    const is_sparc = arch == .sparc or arch == .sparcel or arch == .sparcv9;
    const is_64 = arch.ptrBitWidth() == 64;

    const s = path.sep_str;

    var result = std.ArrayList(u8).init(arena);
    try result.appendSlice(mod.zig_lib_directory.path.?);
    try result.appendSlice(s ++ "libc" ++ s ++ "glibc" ++ s ++ "sysdeps" ++ s);
    if (is_sparc) {
        if (is_64) {
            try result.appendSlice("sparc" ++ s ++ "sparc64");
        } else {
            try result.appendSlice("sparc" ++ s ++ "sparc32");
        }
    } else if (arch.isARM()) {
        try result.appendSlice("arm");
    } else if (arch.isMIPS()) {
        try result.appendSlice("mips");
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

fn add_include_dirs(mod: *Module, arena: *Allocator, args: *std.ArrayList([]const u8)) error{OutOfMemory}!void {
    const target = mod.getTarget();
    const arch = target.cpu.arch;
    const opt_nptl: ?[]const u8 = if (target.os.tag == .linux) "nptl" else "htl";
    const glibc = try lib_path(mod, arena, lib_libc ++ "glibc");

    const s = path.sep_str;

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "include"));

    if (target.os.tag == .linux) {
        try add_include_dirs_arch(arena, args, arch, null, try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix" ++ s ++ "sysv" ++ s ++ "linux"));
    }

    if (opt_nptl) |nptl| {
        try add_include_dirs_arch(arena, args, arch, nptl, try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps"));
    }

    if (target.os.tag == .linux) {
        try args.append("-I");
        try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++
            "unix" ++ s ++ "sysv" ++ s ++ "linux" ++ s ++ "generic"));

        try args.append("-I");
        try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++
            "unix" ++ s ++ "sysv" ++ s ++ "linux" ++ s ++ "include"));
        try args.append("-I");
        try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++
            "unix" ++ s ++ "sysv" ++ s ++ "linux"));
    }
    if (opt_nptl) |nptl| {
        try args.append("-I");
        try args.append(try path.join(arena, &[_][]const u8{ mod.zig_lib_directory.path.?, lib_libc_glibc ++ "sysdeps", nptl }));
    }

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "pthread"));

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix" ++ s ++ "sysv"));

    try add_include_dirs_arch(arena, args, arch, null, try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix"));

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "unix"));

    try add_include_dirs_arch(arena, args, arch, null, try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps"));

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc_glibc ++ "sysdeps" ++ s ++ "generic"));

    try args.append("-I");
    try args.append(try path.join(arena, &[_][]const u8{ mod.zig_lib_directory.path.?, lib_libc ++ "glibc" }));

    try args.append("-I");
    try args.append(try std.fmt.allocPrint(arena, "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{}-{}-{}", .{
        mod.zig_lib_directory.path.?, @tagName(arch), @tagName(target.os.tag), @tagName(target.abi),
    }));

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc ++ "include" ++ s ++ "generic-glibc"));

    try args.append("-I");
    try args.append(try std.fmt.allocPrint(arena, "{}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{}-linux-any", .{
        mod.zig_lib_directory.path.?, @tagName(arch),
    }));

    try args.append("-I");
    try args.append(try lib_path(mod, arena, lib_libc ++ "include" ++ s ++ "any-linux-any"));
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

fn path_from_lib(mod: *Module, arena: *Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &[_][]const u8{ mod.zig_lib_directory.path.?, sub_path });
}

const lib_libc = "libc" ++ path.sep_str;
const lib_libc_glibc = lib_libc ++ "glibc" ++ path.sep_str;

fn lib_path(mod: *Module, arena: *Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &[_][]const u8{ mod.zig_lib_directory.path.?, sub_path });
}

fn build_libc_object(mod: *Module, basename: []const u8, c_source_file: Module.CSourceFile) !void {
    // TODO: This is extracted into a local variable to work around a stage1 miscompilation.
    const emit_bin = Module.EmitLoc{
        .directory = null, // Put it in the cache directory.
        .basename = basename,
    };
    const sub_module = try Module.create(mod.gpa, .{
        // TODO use the global cache directory here
        .zig_cache_directory = mod.zig_cache_directory,
        .zig_lib_directory = mod.zig_lib_directory,
        .target = mod.getTarget(),
        .root_name = mem.split(basename, ".").next().?,
        .root_pkg = null,
        .output_mode = .Obj,
        .rand = mod.rand,
        .libc_installation = mod.bin_file.options.libc_installation,
        .emit_bin = emit_bin,
        .optimize_mode = mod.bin_file.options.optimize_mode,
        .want_sanitize_c = false,
        .want_stack_check = false,
        .want_valgrind = false,
        .want_pic = mod.bin_file.options.pic,
        .emit_h = null,
        .strip = mod.bin_file.options.strip,
        .is_native_os = mod.bin_file.options.is_native_os,
        .self_exe_path = mod.self_exe_path,
        .c_source_files = &[1]Module.CSourceFile{c_source_file},
        .debug_cc = mod.debug_cc,
        .debug_link = mod.bin_file.options.debug_link,
    });
    defer sub_module.destroy();

    try sub_module.update();

    try mod.crt_files.ensureCapacity(mod.gpa, mod.crt_files.count() + 1);
    const artifact_path = try std.fs.path.join(mod.gpa, &[_][]const u8{
        sub_module.zig_cache_artifact_directory.path.?, basename,
    });
    mod.crt_files.putAssumeCapacityNoClobber(basename, artifact_path);
}
