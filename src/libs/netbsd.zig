const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const log = std.log;
const fs = std.fs;
const path = fs.path;
const assert = std.debug.assert;
const Version = std.SemanticVersion;
const Path = std.Build.Cache.Path;

const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");
const trace = @import("../tracy.zig").trace;
const Cache = std.Build.Cache;
const Module = @import("../Package/Module.zig");
const link = @import("../link.zig");

pub const CrtFile = enum {
    scrt0_o,
};

pub fn needsCrt0(output_mode: std.builtin.OutputMode) ?CrtFile {
    // For shared libraries and PIC executables, we should actually link in a variant of crt1 that
    // is built with `-DSHARED` so that it calls `__cxa_finalize` in an ELF destructor. However, we
    // currently make no effort to respect `__cxa_finalize` on any other targets, so for now, we're
    // not doing it here either.
    //
    // See: https://github.com/ziglang/zig/issues/23574#issuecomment-2869089897
    return switch (output_mode) {
        .Obj, .Lib => null,
        .Exe => .scrt0_o,
    };
}

fn includePath(comp: *Compilation, arena: Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &.{
        comp.zig_lib_directory.path.?,
        "libc" ++ path.sep_str ++ "include",
        sub_path,
    });
}

fn csuPath(comp: *Compilation, arena: Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &.{
        comp.zig_lib_directory.path.?,
        "libc" ++ path.sep_str ++ "netbsd" ++ path.sep_str ++ "lib" ++ path.sep_str ++ "csu",
        sub_path,
    });
}

/// TODO replace anyerror with explicit error set, recording user-friendly errors with
/// setMiscFailure and returning error.SubCompilationFailed. see libcxx.zig for example.
pub fn buildCrtFile(comp: *Compilation, crt_file: CrtFile, prog_node: std.Progress.Node) anyerror!void {
    if (!build_options.have_llvm) return error.ZigCompilerNotBuiltWithLLVMExtensions;

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.root_mod.resolved_target.result;
    const target_version = target.os.version_range.semver.min;

    // In all cases in this function, we add the C compiler flags to
    // cache_exempt_flags rather than extra_flags, because these arguments
    // depend on only properties that are already covered by the cache
    // manifest. Including these arguments in the cache could only possibly
    // waste computation and create false negatives.

    switch (crt_file) {
        .scrt0_o => {
            var cflags = std.ArrayList([]const u8).init(arena);
            try cflags.appendSlice(&.{
                "-DHAVE_INITFINI_ARRAY",
                "-w", // Disable all warnings.
            });

            var acflags = std.ArrayList([]const u8).init(arena);
            try acflags.appendSlice(&.{
                // See `Compilation.addCCArgs`.
                try std.fmt.allocPrint(arena, "-D__NetBSD_Version__={d}", .{(target_version.major * 100_000_000) + (target_version.minor * 1_000_000)}),
            });

            const csu_march: ?[]const u8 = switch (target.cpu.arch) {
                .arm => if (target.abi.float() == .hard) "earmhf" else "earm",
                .armeb => if (target.abi.float() == .hard) "earmhfeb" else "earmeb",
                else => null,
            };

            inline for (.{ &cflags, &acflags }) |flags| {
                if (csu_march) |march| {
                    try flags.appendSlice(&.{
                        try std.fmt.allocPrint(arena, "-DELF_NOTE_MARCH_DESC=\"{s}\"", .{march}),
                        try std.fmt.allocPrint(arena, "-DELF_NOTE_MARCH_DESCSZ={d}", .{march.len + 1}),
                    });
                }

                try flags.appendSlice(&.{
                    "-I",
                    try includePath(comp, arena, try std.fmt.allocPrint(arena, "{s}-{s}-{s}", .{
                        std.zig.target.netbsdArchNameHeaders(target.cpu.arch),
                        @tagName(target.os.tag),
                        @tagName(target.abi),
                    })),
                    "-I",
                    try includePath(comp, arena, "generic-netbsd"),
                    "-I",
                    try csuPath(comp, arena, "common"),
                    "-Qunused-arguments",
                });
            }

            const sources = [_]struct {
                path: []const u8,
                flags: []const []const u8,
                condition: bool = true,
            }{
                .{
                    .path = "common" ++ path.sep_str ++ "crt0-common.c",
                    .flags = cflags.items,
                },
                .{
                    .path = "common" ++ path.sep_str ++ "crtbegin.c",
                    .flags = cflags.items,
                },
                .{
                    .path = "common" ++ path.sep_str ++ "sysident.S",
                    .flags = acflags.items,
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "earm" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch.isArm(),
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "aarch64" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch.isAARCH64(),
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "m68k" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch == .m68k,
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "mips" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch.isMIPS(),
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "powerpc" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch == .powerpc,
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "sparc" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch == .sparc,
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "sparc64" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch == .sparc64,
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "i386" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch == .x86,
                },

                .{
                    .path = "arch" ++ path.sep_str ++ "x86_64" ++ path.sep_str ++ "crt0.S",
                    .flags = acflags.items,
                    .condition = target.cpu.arch == .x86_64,
                },
            };

            var files_buf: [sources.len]Compilation.CSourceFile = undefined;
            var files_index: usize = 0;
            for (sources) |file| {
                if (!file.condition) continue;

                files_buf[files_index] = .{
                    .src_path = try csuPath(comp, arena, file.path),
                    .cache_exempt_flags = file.flags,
                    .owner = undefined,
                };
                files_index += 1;
            }
            const files = files_buf[0..files_index];

            return comp.build_crt_file("crt0", .Obj, .@"netbsd libc Scrt0.o", prog_node, files, .{
                .pic = true,
            });
        },
    }
}

pub const Lib = struct {
    name: []const u8,
    sover: u8,
};

pub const libs = [_]Lib{
    .{ .name = "m", .sover = 0 },
    .{ .name = "pthread", .sover = 1 },
    .{ .name = "c", .sover = 12 },
    .{ .name = "rt", .sover = 1 },
    .{ .name = "ld", .sover = 0 },
    .{ .name = "util", .sover = 7 },
    .{ .name = "execinfo", .sover = 0 },
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

pub const LoadMetaDataError = error{
    /// The files that ship with the Zig compiler were unable to be read, or otherwise had malformed data.
    ZigInstallationCorrupt,
    OutOfMemory,
};

pub const abilists_path = "libc" ++ path.sep_str ++ "netbsd" ++ path.sep_str ++ "abilists";
pub const abilists_max_size = 300 * 1024; // Bigger than this and something is definitely borked.

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
                log.err("libc" ++ path.sep_str ++ "netbsd" ++ path.sep_str ++
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
            if (!mem.eql(u8, os_name, "netbsd")) {
                log.err("abilists: expected OS 'netbsd', found '{s}'", .{os_name});
                return error.ZigInstallationCorrupt;
            }
            const abi_tag = std.meta.stringToEnum(std.Target.Abi, abi_name) orelse {
                log.err("abilists: unrecognized ABI: '{s}'", .{abi_name});
                return error.ZigInstallationCorrupt;
            };

            targets[i] = .{
                .arch = arch_tag,
                .os = .netbsd,
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

pub const BuiltSharedObjects = struct {
    lock: Cache.Lock,
    dir_path: Path,

    pub fn deinit(self: *BuiltSharedObjects, gpa: Allocator) void {
        self.lock.release();
        gpa.free(self.dir_path.sub_path);
        self.* = undefined;
    }
};

fn wordDirective(target: std.Target) []const u8 {
    // Based on its description in the GNU `as` manual, you might assume that `.word` is sized
    // according to the target word size. But no; that would just make too much sense.
    return if (target.ptrBitWidth() == 64) ".quad" else ".long";
}

/// TODO replace anyerror with explicit error set, recording user-friendly errors with
/// setMiscFailure and returning error.SubCompilationFailed. see libcxx.zig for example.
pub fn buildSharedObjects(comp: *Compilation, prog_node: std.Progress.Node) anyerror!void {
    // See also glibc.zig which this code is based on.

    const tracy = trace(@src());
    defer tracy.end();

    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const gpa = comp.gpa;

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.getTarget();
    const target_version = target.os.version_range.semver.min;

    // Use the global cache directory.
    var cache: Cache = .{
        .gpa = gpa,
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

        return queueSharedObjects(comp, .{
            .lock = man.toOwnedLock(),
            .dir_path = .{
                .root_dir = comp.global_cache_directory,
                .sub_path = try gpa.dupe(u8, "o" ++ fs.path.sep_str ++ digest),
            },
        });
    }

    const digest = man.final();
    const o_sub_path = try path.join(arena, &[_][]const u8{ "o", &digest });

    var o_directory: Compilation.Directory = .{
        .handle = try comp.global_cache_directory.handle.makeOpenPath(o_sub_path, .{}),
        .path = try comp.global_cache_directory.join(arena, &.{o_sub_path}),
    };
    defer o_directory.handle.close();

    const abilists_contents = man.files.keys()[abilists_index].contents.?;
    const metadata = try loadMetaData(gpa, abilists_contents);
    defer metadata.destroy(gpa);

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
                log.warn("invalid target NetBSD libc version: {}", .{target_version});
                return error.InvalidTargetLibCVersion;
            },
        }
    } else blk: {
        const latest_index = metadata.all_versions.len - 1;
        log.warn("zig cannot build new NetBSD libc version {}; providing instead {}", .{
            target_version, metadata.all_versions[latest_index],
        });
        break :blk latest_index;
    };

    var stubs_asm = std.ArrayList(u8).init(gpa);
    defer stubs_asm.deinit();

    for (libs, 0..) |lib, lib_i| {
        stubs_asm.shrinkRetainingCapacity(0);

        const stubs_writer = stubs_asm.writer();

        try stubs_writer.writeAll(".text\n");

        var sym_i: usize = 0;
        var sym_name_buf = std.ArrayList(u8).init(arena);
        var opt_symbol_name: ?[]const u8 = null;

        var inc_fbs = std.io.fixedBufferStream(metadata.inclusions);
        var inc_reader = inc_fbs.reader();

        const fn_inclusions_len = try inc_reader.readInt(u16, .little);

        var chosen_ver_index: usize = 255;
        var chosen_is_weak: bool = undefined;

        while (sym_i < fn_inclusions_len) : (sym_i += 1) {
            const sym_name = opt_symbol_name orelse n: {
                sym_name_buf.clearRetainingCapacity();
                try inc_reader.streamUntilDelimiter(sym_name_buf.writer(), 0, null);

                opt_symbol_name = sym_name_buf.items;
                chosen_ver_index = 255;

                break :n sym_name_buf.items;
            };

            {
                const targets = try std.leb.readUleb128(u64, inc_reader);
                var lib_index = try inc_reader.readByte();

                const is_weak = (lib_index & (1 << 6)) != 0;
                const is_terminal = (lib_index & (1 << 7)) != 0;

                lib_index = @as(u5, @truncate(lib_index));

                // Test whether the inclusion applies to our current library and target.
                const ok_lib_and_target =
                    (lib_index == lib_i) and
                    ((targets & (@as(u64, 1) << @as(u6, @intCast(target_targ_index)))) != 0);

                while (true) {
                    const byte = try inc_reader.readByte();
                    const last = (byte & 0b1000_0000) != 0;
                    const ver_i = @as(u7, @truncate(byte));
                    if (ok_lib_and_target and ver_i <= target_ver_index and
                        (chosen_ver_index == 255 or ver_i > chosen_ver_index))
                    {
                        chosen_ver_index = ver_i;
                        chosen_is_weak = is_weak;
                    }
                    if (last) break;
                }

                if (is_terminal) {
                    opt_symbol_name = null;
                } else continue;
            }

            if (chosen_ver_index != 255) {
                // Example:
                // .balign 4
                // .globl _Exit
                // .type _Exit, %function
                // _Exit: .long 0
                try stubs_writer.print(
                    \\.balign {d}
                    \\.{s} {s}
                    \\.type {s}, %function
                    \\{s}: {s} 0
                    \\
                , .{
                    target.ptrBitWidth() / 8,
                    if (chosen_is_weak) "weak" else "globl",
                    sym_name,
                    sym_name,
                    sym_name,
                    wordDirective(target),
                });
            }
        }

        try stubs_writer.writeAll(".data\n");

        const obj_inclusions_len = try inc_reader.readInt(u16, .little);

        sym_i = 0;
        opt_symbol_name = null;

        var chosen_size: u16 = undefined;

        while (sym_i < obj_inclusions_len) : (sym_i += 1) {
            const sym_name = opt_symbol_name orelse n: {
                sym_name_buf.clearRetainingCapacity();
                try inc_reader.streamUntilDelimiter(sym_name_buf.writer(), 0, null);

                opt_symbol_name = sym_name_buf.items;
                chosen_ver_index = 255;

                break :n sym_name_buf.items;
            };

            {
                const targets = try std.leb.readUleb128(u64, inc_reader);
                const size = try std.leb.readUleb128(u16, inc_reader);
                var lib_index = try inc_reader.readByte();

                const is_weak = (lib_index & (1 << 6)) != 0;
                const is_terminal = (lib_index & (1 << 7)) != 0;

                lib_index = @as(u5, @truncate(lib_index));

                // Test whether the inclusion applies to our current library and target.
                const ok_lib_and_target =
                    (lib_index == lib_i) and
                    ((targets & (@as(u64, 1) << @as(u6, @intCast(target_targ_index)))) != 0);

                while (true) {
                    const byte = try inc_reader.readByte();
                    const last = (byte & 0b1000_0000) != 0;
                    const ver_i = @as(u7, @truncate(byte));
                    if (ok_lib_and_target and ver_i <= target_ver_index and
                        (chosen_ver_index == 255 or ver_i > chosen_ver_index))
                    {
                        chosen_ver_index = ver_i;
                        chosen_size = size;
                        chosen_is_weak = is_weak;
                    }
                    if (last) break;
                }

                if (is_terminal) {
                    opt_symbol_name = null;
                } else continue;
            }

            if (chosen_ver_index != 255) {
                // Example:
                // .balign 4
                // .globl malloc_conf
                // .type malloc_conf, %object
                // .size malloc_conf, 4
                // malloc_conf: .fill 4, 1, 0
                try stubs_writer.print(
                    \\.balign {d}
                    \\.{s} {s}
                    \\.type {s}, %object
                    \\.size {s}, {d}
                    \\{s}: {s} 0
                    \\
                , .{
                    target.ptrBitWidth() / 8,
                    if (chosen_is_weak) "weak" else "globl",
                    sym_name,
                    sym_name,
                    sym_name,
                    chosen_size,
                    sym_name,
                    wordDirective(target),
                });
            }
        }

        var lib_name_buf: [32]u8 = undefined; // Larger than each of the names "c", "pthread", etc.
        const asm_file_basename = std.fmt.bufPrint(&lib_name_buf, "{s}.s", .{lib.name}) catch unreachable;
        try o_directory.handle.writeFile(.{ .sub_path = asm_file_basename, .data = stubs_asm.items });
        try buildSharedLib(comp, arena, comp.global_cache_directory, o_directory, asm_file_basename, lib, prog_node);
    }

    man.writeManifest() catch |err| {
        log.warn("failed to write cache manifest for NetBSD libc stubs: {s}", .{@errorName(err)});
    };

    return queueSharedObjects(comp, .{
        .lock = man.toOwnedLock(),
        .dir_path = .{
            .root_dir = comp.global_cache_directory,
            .sub_path = try gpa.dupe(u8, "o" ++ fs.path.sep_str ++ digest),
        },
    });
}

pub fn sharedObjectsCount() u8 {
    return libs.len;
}

fn queueSharedObjects(comp: *Compilation, so_files: BuiltSharedObjects) void {
    assert(comp.netbsd_so_files == null);
    comp.netbsd_so_files = so_files;

    var task_buffer: [libs.len]link.Task = undefined;
    var task_buffer_i: usize = 0;

    {
        comp.mutex.lock(); // protect comp.arena
        defer comp.mutex.unlock();

        for (libs) |lib| {
            const so_path: Path = .{
                .root_dir = so_files.dir_path.root_dir,
                .sub_path = std.fmt.allocPrint(comp.arena, "{s}{c}lib{s}.so.{d}", .{
                    so_files.dir_path.sub_path, fs.path.sep, lib.name, lib.sover,
                }) catch return comp.setAllocFailure(),
            };
            task_buffer[task_buffer_i] = .{ .load_dso = so_path };
            task_buffer_i += 1;
        }
    }

    comp.queueLinkTasks(task_buffer[0..task_buffer_i]);
}

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
            .sanitize_c = .off,
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
        .soname = soname,
        .c_source_files = &c_source_files,
        .skip_linker_dependencies = true,
    });
    defer sub_compilation.destroy();

    try comp.updateSubCompilation(sub_compilation, .@"netbsd libc shared object", prog_node);
}
