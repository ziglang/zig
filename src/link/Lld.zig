base: link.File,
ofmt: union(enum) {
    elf: Elf,
    coff: Coff,
    wasm: Wasm,
},

const Coff = struct {
    image_base: u64,
    entry: link.File.OpenOptions.Entry,
    pdb_out_path: ?[]const u8,
    repro: bool,
    tsaware: bool,
    nxcompat: bool,
    dynamicbase: bool,
    /// TODO this and minor_subsystem_version should be combined into one property and left as
    /// default or populated together. They should not be separate fields.
    major_subsystem_version: u16,
    minor_subsystem_version: u16,
    lib_directories: []const Cache.Directory,
    module_definition_file: ?[]const u8,
    subsystem: ?std.Target.SubSystem,
    /// These flags are populated by `codegen.llvm.updateExports` to allow us to guess the subsystem.
    lld_export_flags: struct {
        c_main: bool,
        winmain: bool,
        wwinmain: bool,
        winmain_crt_startup: bool,
        wwinmain_crt_startup: bool,
        dllmain_crt_startup: bool,
    },
    fn init(comp: *Compilation, options: link.File.OpenOptions) !Coff {
        const target = comp.root_mod.resolved_target.result;
        const output_mode = comp.config.output_mode;
        return .{
            .image_base = options.image_base orelse switch (output_mode) {
                .Exe => switch (target.cpu.arch) {
                    .aarch64, .x86_64 => 0x140000000,
                    .thumb, .x86 => 0x400000,
                    else => unreachable,
                },
                .Lib => switch (target.cpu.arch) {
                    .aarch64, .x86_64 => 0x180000000,
                    .thumb, .x86 => 0x10000000,
                    else => unreachable,
                },
                .Obj => 0,
            },
            .entry = options.entry,
            .pdb_out_path = options.pdb_out_path,
            .repro = options.repro,
            .tsaware = options.tsaware,
            .nxcompat = options.nxcompat,
            .dynamicbase = options.dynamicbase,
            .major_subsystem_version = options.major_subsystem_version orelse 6,
            .minor_subsystem_version = options.minor_subsystem_version orelse 0,
            .lib_directories = options.lib_directories,
            .module_definition_file = options.module_definition_file,
            // Subsystem depends on the set of public symbol names from linked objects.
            // See LinkerDriver::inferSubsystem from the LLD project for the flow chart.
            .subsystem = options.subsystem,
            // These flags are initially all `false`; the LLVM backend populates them when it learns about exports.
            .lld_export_flags = .{
                .c_main = false,
                .winmain = false,
                .wwinmain = false,
                .winmain_crt_startup = false,
                .wwinmain_crt_startup = false,
                .dllmain_crt_startup = false,
            },
        };
    }
};
pub const Elf = struct {
    entry_name: ?[]const u8,
    hash_style: HashStyle,
    image_base: u64,
    linker_script: ?[]const u8,
    version_script: ?[]const u8,
    sort_section: ?SortSection,
    print_icf_sections: bool,
    print_map: bool,
    emit_relocs: bool,
    z_nodelete: bool,
    z_notext: bool,
    z_defs: bool,
    z_origin: bool,
    z_nocopyreloc: bool,
    z_now: bool,
    z_relro: bool,
    z_common_page_size: ?u64,
    z_max_page_size: ?u64,
    rpath_list: []const []const u8,
    symbol_wrap_set: []const []const u8,
    soname: ?[]const u8,
    allow_undefined_version: bool,
    enable_new_dtags: ?bool,
    compress_debug_sections: CompressDebugSections,
    bind_global_refs_locally: bool,
    pub const HashStyle = enum { sysv, gnu, both };
    pub const SortSection = enum { name, alignment };
    pub const CompressDebugSections = enum { none, zlib, zstd };

    fn init(comp: *Compilation, options: link.File.OpenOptions) !Elf {
        const PtrWidth = enum { p32, p64 };
        const target = comp.root_mod.resolved_target.result;
        const output_mode = comp.config.output_mode;
        const is_dyn_lib = output_mode == .Lib and comp.config.link_mode == .dynamic;
        const ptr_width: PtrWidth = switch (target.ptrBitWidth()) {
            0...32 => .p32,
            33...64 => .p64,
            else => return error.UnsupportedElfArchitecture,
        };
        const default_entry_name: []const u8 = switch (target.cpu.arch) {
            .mips, .mipsel, .mips64, .mips64el => "__start",
            else => "_start",
        };
        return .{
            .entry_name = switch (options.entry) {
                .disabled => null,
                .default => if (output_mode != .Exe) null else default_entry_name,
                .enabled => default_entry_name,
                .named => |name| name,
            },
            .hash_style = options.hash_style,
            .image_base = b: {
                if (is_dyn_lib) break :b 0;
                if (output_mode == .Exe and comp.config.pie) break :b 0;
                break :b options.image_base orelse switch (ptr_width) {
                    .p32 => 0x10000,
                    .p64 => 0x1000000,
                };
            },
            .linker_script = options.linker_script,
            .version_script = options.version_script,
            .sort_section = options.sort_section,
            .print_icf_sections = options.print_icf_sections,
            .print_map = options.print_map,
            .emit_relocs = options.emit_relocs,
            .z_nodelete = options.z_nodelete,
            .z_notext = options.z_notext,
            .z_defs = options.z_defs,
            .z_origin = options.z_origin,
            .z_nocopyreloc = options.z_nocopyreloc,
            .z_now = options.z_now,
            .z_relro = options.z_relro,
            .z_common_page_size = options.z_common_page_size,
            .z_max_page_size = options.z_max_page_size,
            .rpath_list = options.rpath_list,
            .symbol_wrap_set = options.symbol_wrap_set.keys(),
            .soname = options.soname,
            .allow_undefined_version = options.allow_undefined_version,
            .enable_new_dtags = options.enable_new_dtags,
            .compress_debug_sections = options.compress_debug_sections,
            .bind_global_refs_locally = options.bind_global_refs_locally,
        };
    }
};
const Wasm = struct {
    /// Symbol name of the entry function to export
    entry_name: ?[]const u8,
    /// When true, will import the function table from the host environment.
    import_table: bool,
    /// When true, will export the function table to the host environment.
    export_table: bool,
    /// When defined, sets the initial memory size of the memory.
    initial_memory: ?u64,
    /// When defined, sets the maximum memory size of the memory.
    max_memory: ?u64,
    /// When defined, sets the start of the data section.
    global_base: ?u64,
    /// Set of *global* symbol names to export to the host environment.
    export_symbol_names: []const []const u8,
    /// When true, will allow undefined symbols
    import_symbols: bool,
    fn init(comp: *Compilation, options: link.File.OpenOptions) !Wasm {
        const default_entry_name: []const u8 = switch (comp.config.wasi_exec_model) {
            .reactor => "_initialize",
            .command => "_start",
        };
        return .{
            .entry_name = switch (options.entry) {
                .disabled => null,
                .default => if (comp.config.output_mode != .Exe) null else default_entry_name,
                .enabled => default_entry_name,
                .named => |name| name,
            },
            .import_table = options.import_table,
            .export_table = options.export_table,
            .initial_memory = options.initial_memory,
            .max_memory = options.max_memory,
            .global_base = options.global_base,
            .export_symbol_names = options.export_symbol_names,
            .import_symbols = options.import_symbols,
        };
    }
};

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Cache.Path,
    options: link.File.OpenOptions,
) !*Lld {
    const target = comp.root_mod.resolved_target.result;
    const output_mode = comp.config.output_mode;
    const optimize_mode = comp.root_mod.optimize_mode;
    const is_native_os = comp.root_mod.resolved_target.is_native_os;

    const obj_file_ext: []const u8 = switch (target.ofmt) {
        .coff => "obj",
        .elf, .wasm => "o",
        else => unreachable,
    };
    const gc_sections: bool = options.gc_sections orelse switch (target.ofmt) {
        .coff => optimize_mode != .Debug,
        .elf => optimize_mode != .Debug and output_mode != .Obj,
        .wasm => output_mode != .Obj,
        else => unreachable,
    };
    const stack_size: u64 = options.stack_size orelse default: {
        if (target.ofmt == .wasm and target.os.tag == .freestanding)
            break :default 1 * 1024 * 1024; // 1 MiB
        break :default 16 * 1024 * 1024; // 16 MiB
    };

    const lld = try arena.create(Lld);
    lld.* = .{
        .base = .{
            .tag = .lld,
            .comp = comp,
            .emit = emit,
            .zcu_object_basename = try allocPrint(arena, "{s}_zcu.{s}", .{ fs.path.stem(emit.sub_path), obj_file_ext }),
            .gc_sections = gc_sections,
            .print_gc_sections = options.print_gc_sections,
            .stack_size = stack_size,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse !is_native_os,
            .file = null,
            .build_id = options.build_id,
        },
        .ofmt = switch (target.ofmt) {
            .coff => .{ .coff = try .init(comp, options) },
            .elf => .{ .elf = try .init(comp, options) },
            .wasm => .{ .wasm = try .init(comp, options) },
            else => unreachable,
        },
    };
    return lld;
}
pub fn deinit(lld: *Lld) void {
    _ = lld;
}
pub fn flush(
    lld: *Lld,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) link.File.FlushError!void {
    dev.check(.lld_linker);
    _ = tid;

    const tracy = trace(@src());
    defer tracy.end();

    const sub_prog_node = prog_node.start("LLD Link", 0);
    defer sub_prog_node.end();

    const comp = lld.base.comp;
    const result = if (comp.config.output_mode == .Lib and comp.config.link_mode == .static) r: {
        if (!@import("build_options").have_llvm or !comp.config.use_lib_llvm) {
            return lld.base.comp.link_diags.fail("using lld without libllvm not implemented", .{});
        }
        break :r linkAsArchive(lld, arena);
    } else switch (lld.ofmt) {
        .coff => coffLink(lld, arena),
        .elf => elfLink(lld, arena),
        .wasm => wasmLink(lld, arena),
    };
    result catch |err| switch (err) {
        error.OutOfMemory, error.LinkFailure => |e| return e,
        else => |e| return lld.base.comp.link_diags.fail("failed to link with LLD: {s}", .{@errorName(e)}),
    };
}

fn linkAsArchive(lld: *Lld, arena: Allocator) !void {
    const base = &lld.base;
    const comp = base.comp;
    const directory = base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});
    const full_out_path_z = try arena.dupeZ(u8, full_out_path);
    const opt_zcu = comp.zcu;

    const zcu_obj_path: ?Cache.Path = if (opt_zcu != null) p: {
        break :p try comp.resolveEmitPathFlush(arena, .temp, base.zcu_object_basename.?);
    } else null;

    log.debug("zcu_obj_path={?}", .{zcu_obj_path});

    const compiler_rt_path: ?Cache.Path = if (comp.compiler_rt_strat == .obj)
        comp.compiler_rt_obj.?.full_object_path
    else
        null;

    const ubsan_rt_path: ?Cache.Path = if (comp.ubsan_rt_strat == .obj)
        comp.ubsan_rt_obj.?.full_object_path
    else
        null;

    // This function follows the same pattern as link.Elf.linkWithLLD so if you want some
    // insight as to what's going on here you can read that function body which is more
    // well-commented.

    const link_inputs = comp.link_inputs;

    var object_files: std.ArrayListUnmanaged([*:0]const u8) = .empty;

    try object_files.ensureUnusedCapacity(arena, link_inputs.len);
    for (link_inputs) |input| {
        object_files.appendAssumeCapacity(try input.path().?.toStringZ(arena));
    }

    try object_files.ensureUnusedCapacity(arena, comp.c_object_table.count() +
        comp.win32_resource_table.count() + 2);

    for (comp.c_object_table.keys()) |key| {
        object_files.appendAssumeCapacity(try key.status.success.object_path.toStringZ(arena));
    }
    for (comp.win32_resource_table.keys()) |key| {
        object_files.appendAssumeCapacity(try arena.dupeZ(u8, key.status.success.res_path));
    }
    if (zcu_obj_path) |p| object_files.appendAssumeCapacity(try p.toStringZ(arena));
    if (compiler_rt_path) |p| object_files.appendAssumeCapacity(try p.toStringZ(arena));
    if (ubsan_rt_path) |p| object_files.appendAssumeCapacity(try p.toStringZ(arena));

    if (comp.verbose_link) {
        std.debug.print("ar rcs {s}", .{full_out_path_z});
        for (object_files.items) |arg| {
            std.debug.print(" {s}", .{arg});
        }
        std.debug.print("\n", .{});
    }

    const llvm_bindings = @import("../codegen/llvm/bindings.zig");
    const llvm = @import("../codegen/llvm.zig");
    const target = comp.root_mod.resolved_target.result;
    llvm.initializeLLVMTarget(target.cpu.arch);
    const bad = llvm_bindings.WriteArchive(
        full_out_path_z,
        object_files.items.ptr,
        object_files.items.len,
        switch (target.os.tag) {
            .aix => .AIXBIG,
            .windows => .COFF,
            else => if (target.os.tag.isDarwin()) .DARWIN else .GNU,
        },
    );
    if (bad) return error.UnableToWriteArchive;
}

fn coffLink(lld: *Lld, arena: Allocator) !void {
    const comp = lld.base.comp;
    const gpa = comp.gpa;
    const base = &lld.base;
    const coff = &lld.ofmt.coff;

    const directory = base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});

    const zcu_obj_path: ?Cache.Path = if (comp.zcu != null) p: {
        break :p try comp.resolveEmitPathFlush(arena, .temp, base.zcu_object_basename.?);
    } else null;

    const is_lib = comp.config.output_mode == .Lib;
    const is_dyn_lib = comp.config.link_mode == .dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or comp.config.output_mode == .Exe;
    const link_in_crt = comp.config.link_libc and is_exe_or_dyn_lib;
    const target = comp.root_mod.resolved_target.result;
    const optimize_mode = comp.root_mod.optimize_mode;
    const entry_name: ?[]const u8 = switch (coff.entry) {
        // This logic isn't quite right for disabled or enabled. No point in fixing it
        // when the goal is to eliminate dependency on LLD anyway.
        // https://github.com/ziglang/zig/issues/17751
        .disabled, .default, .enabled => null,
        .named => |name| name,
    };

    if (comp.config.output_mode == .Obj) {
        // LLD's COFF driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (link.firstObjectInput(comp.link_inputs)) |obj| break :blk obj.path;

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (zcu_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        try std.fs.Dir.copyFile(
            the_object_path.root_dir.handle,
            the_object_path.sub_path,
            directory.handle,
            base.emit.sub_path,
            .{},
        );
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "lld-link";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });

        if (target.isMinGW()) {
            try argv.append("-lldmingw");
        }

        try argv.append("-ERRORLIMIT:0");
        try argv.append("-NOLOGO");
        if (comp.config.debug_format != .strip) {
            try argv.append("-DEBUG");

            const out_ext = std.fs.path.extension(full_out_path);
            const out_pdb = coff.pdb_out_path orelse try allocPrint(arena, "{s}.pdb", .{
                full_out_path[0 .. full_out_path.len - out_ext.len],
            });
            const out_pdb_basename = std.fs.path.basename(out_pdb);

            try argv.append(try allocPrint(arena, "-PDB:{s}", .{out_pdb}));
            try argv.append(try allocPrint(arena, "-PDBALTPATH:{s}", .{out_pdb_basename}));
        }
        if (comp.version) |version| {
            try argv.append(try allocPrint(arena, "-VERSION:{}.{}", .{ version.major, version.minor }));
        }

        if (target_util.llvmMachineAbi(target)) |mabi| {
            try argv.append(try allocPrint(arena, "-MLLVM:-target-abi={s}", .{mabi}));
        }

        try argv.append(try allocPrint(arena, "-MLLVM:-float-abi={s}", .{if (target.abi.float() == .hard) "hard" else "soft"}));

        if (comp.config.lto != .none) {
            switch (optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("-OPT:lldlto=2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("-OPT:lldlto=3"),
            }
        }
        if (comp.config.output_mode == .Exe) {
            try argv.append(try allocPrint(arena, "-STACK:{d}", .{base.stack_size}));
        }
        try argv.append(try allocPrint(arena, "-BASE:{d}", .{coff.image_base}));

        switch (base.build_id) {
            .none => try argv.append("-BUILD-ID:NO"),
            .fast => try argv.append("-BUILD-ID"),
            .uuid, .sha1, .md5, .hexstring => {},
        }

        if (target.cpu.arch == .x86) {
            try argv.append("-MACHINE:X86");
        } else if (target.cpu.arch == .x86_64) {
            try argv.append("-MACHINE:X64");
        } else if (target.cpu.arch == .thumb) {
            try argv.append("-MACHINE:ARM");
        } else if (target.cpu.arch == .aarch64) {
            try argv.append("-MACHINE:ARM64");
        }

        for (comp.force_undefined_symbols.keys()) |symbol| {
            try argv.append(try allocPrint(arena, "-INCLUDE:{s}", .{symbol}));
        }

        if (is_dyn_lib) {
            try argv.append("-DLL");
        }

        if (entry_name) |name| {
            try argv.append(try allocPrint(arena, "-ENTRY:{s}", .{name}));
        }

        if (coff.repro) {
            try argv.append("-BREPRO");
        }

        if (coff.tsaware) {
            try argv.append("-tsaware");
        }
        if (coff.nxcompat) {
            try argv.append("-nxcompat");
        }
        if (!coff.dynamicbase) {
            try argv.append("-dynamicbase:NO");
        }
        if (base.allow_shlib_undefined) {
            try argv.append("-FORCE:UNRESOLVED");
        }

        try argv.append(try allocPrint(arena, "-OUT:{s}", .{full_out_path}));

        if (comp.emit_implib) |raw_emit_path| {
            const path = try comp.resolveEmitPathFlush(arena, .temp, raw_emit_path);
            try argv.append(try allocPrint(arena, "-IMPLIB:{}", .{path}));
        }

        if (comp.config.link_libc) {
            if (comp.libc_installation) |libc_installation| {
                try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.crt_dir.?}));

                if (target.abi == .msvc or target.abi == .itanium) {
                    try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.msvc_lib_dir.?}));
                    try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.kernel32_lib_dir.?}));
                }
            }
        }

        for (coff.lib_directories) |lib_directory| {
            try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{lib_directory.path orelse "."}));
        }

        try argv.ensureUnusedCapacity(comp.link_inputs.len);
        for (comp.link_inputs) |link_input| switch (link_input) {
            .dso_exact => unreachable, // not applicable to PE/COFF
            inline .dso, .res => |x| {
                argv.appendAssumeCapacity(try x.path.toString(arena));
            },
            .object, .archive => |obj| {
                if (obj.must_link) {
                    argv.appendAssumeCapacity(try allocPrint(arena, "-WHOLEARCHIVE:{}", .{@as(Cache.Path, obj.path)}));
                } else {
                    argv.appendAssumeCapacity(try obj.path.toString(arena));
                }
            },
        };

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }

        for (comp.win32_resource_table.keys()) |key| {
            try argv.append(key.status.success.res_path);
        }

        if (zcu_obj_path) |p| {
            try argv.append(try p.toString(arena));
        }

        if (coff.module_definition_file) |def| {
            try argv.append(try allocPrint(arena, "-DEF:{s}", .{def}));
        }

        const resolved_subsystem: ?std.Target.SubSystem = blk: {
            if (coff.subsystem) |explicit| break :blk explicit;
            switch (target.os.tag) {
                .windows => {
                    if (comp.zcu != null) {
                        if (coff.lld_export_flags.dllmain_crt_startup or is_dyn_lib)
                            break :blk null;
                        if (coff.lld_export_flags.c_main or comp.config.is_test or
                            coff.lld_export_flags.winmain_crt_startup or
                            coff.lld_export_flags.wwinmain_crt_startup)
                        {
                            break :blk .Console;
                        }
                        if (coff.lld_export_flags.winmain or coff.lld_export_flags.wwinmain)
                            break :blk .Windows;
                    }
                },
                .uefi => break :blk .EfiApplication,
                else => {},
            }
            break :blk null;
        };

        const Mode = enum { uefi, win32 };
        const mode: Mode = mode: {
            if (resolved_subsystem) |subsystem| {
                const subsystem_suffix = try allocPrint(arena, ",{d}.{d}", .{
                    coff.major_subsystem_version, coff.minor_subsystem_version,
                });

                switch (subsystem) {
                    .Console => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:console{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .EfiApplication => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_application{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiBootServiceDriver => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_boot_service_driver{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiRom => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_rom{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiRuntimeDriver => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_runtime_driver{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .Native => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:native{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .Posix => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:posix{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .Windows => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:windows{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                }
            } else if (target.os.tag == .uefi) {
                break :mode .uefi;
            } else {
                break :mode .win32;
            }
        };

        switch (mode) {
            .uefi => try argv.appendSlice(&[_][]const u8{
                "-BASE:0",
                "-ENTRY:EfiMain",
                "-OPT:REF",
                "-SAFESEH:NO",
                "-MERGE:.rdata=.data",
                "-NODEFAULTLIB",
                "-SECTION:.xdata,D",
            }),
            .win32 => {
                if (link_in_crt) {
                    if (target.abi.isGnu()) {
                        if (target.cpu.arch == .x86) {
                            try argv.append("-ALTERNATENAME:__image_base__=___ImageBase");
                        } else {
                            try argv.append("-ALTERNATENAME:__image_base__=__ImageBase");
                        }

                        if (is_dyn_lib) {
                            try argv.append(try comp.crtFileAsString(arena, "dllcrt2.obj"));
                            if (target.cpu.arch == .x86) {
                                try argv.append("-ALTERNATENAME:__DllMainCRTStartup@12=_DllMainCRTStartup@12");
                            } else {
                                try argv.append("-ALTERNATENAME:_DllMainCRTStartup=DllMainCRTStartup");
                            }
                        } else {
                            try argv.append(try comp.crtFileAsString(arena, "crt2.obj"));
                        }

                        try argv.append(try comp.crtFileAsString(arena, "libmingw32.lib"));
                    } else {
                        try argv.append(switch (comp.config.link_mode) {
                            .static => "libcmt.lib",
                            .dynamic => "msvcrt.lib",
                        });

                        const lib_str = switch (comp.config.link_mode) {
                            .static => "lib",
                            .dynamic => "",
                        };
                        try argv.append(try allocPrint(arena, "{s}vcruntime.lib", .{lib_str}));
                        try argv.append(try allocPrint(arena, "{s}ucrt.lib", .{lib_str}));

                        //Visual C++ 2015 Conformance Changes
                        //https://msdn.microsoft.com/en-us/library/bb531344.aspx
                        try argv.append("legacy_stdio_definitions.lib");

                        // msvcrt depends on kernel32 and ntdll
                        try argv.append("kernel32.lib");
                        try argv.append("ntdll.lib");
                    }
                } else {
                    try argv.append("-NODEFAULTLIB");
                    if (!is_lib and entry_name == null) {
                        if (comp.zcu != null) {
                            if (coff.lld_export_flags.winmain_crt_startup) {
                                try argv.append("-ENTRY:WinMainCRTStartup");
                            } else {
                                try argv.append("-ENTRY:wWinMainCRTStartup");
                            }
                        } else {
                            try argv.append("-ENTRY:wWinMainCRTStartup");
                        }
                    }
                }
            },
        }

        if (comp.config.link_libc and link_in_crt) {
            if (comp.zigc_static_lib) |zigc| {
                try argv.append(try zigc.full_object_path.toString(arena));
            }
        }

        // libc++ dep
        if (comp.config.link_libcpp) {
            try argv.append(try comp.libcxxabi_static_lib.?.full_object_path.toString(arena));
            try argv.append(try comp.libcxx_static_lib.?.full_object_path.toString(arena));
        }

        // libunwind dep
        if (comp.config.link_libunwind) {
            try argv.append(try comp.libunwind_static_lib.?.full_object_path.toString(arena));
        }

        if (comp.config.any_fuzz) {
            try argv.append(try comp.fuzzer_lib.?.full_object_path.toString(arena));
        }

        const ubsan_rt_path: ?Cache.Path = blk: {
            if (comp.ubsan_rt_lib) |x| break :blk x.full_object_path;
            if (comp.ubsan_rt_obj) |x| break :blk x.full_object_path;
            break :blk null;
        };
        if (ubsan_rt_path) |path| {
            try argv.append(try path.toString(arena));
        }

        if (is_exe_or_dyn_lib and !comp.skip_linker_dependencies) {
            // MSVC compiler_rt is missing some stuff, so we build it unconditionally but
            // and rely on weak linkage to allow MSVC compiler_rt functions to override ours.
            if (comp.compiler_rt_obj) |obj| try argv.append(try obj.full_object_path.toString(arena));
            if (comp.compiler_rt_lib) |lib| try argv.append(try lib.full_object_path.toString(arena));
        }

        try argv.ensureUnusedCapacity(comp.windows_libs.count());
        for (comp.windows_libs.keys()) |key| {
            const lib_basename = try allocPrint(arena, "{s}.lib", .{key});
            if (comp.crt_files.get(lib_basename)) |crt_file| {
                argv.appendAssumeCapacity(try crt_file.full_object_path.toString(arena));
                continue;
            }
            if (try findLib(arena, lib_basename, coff.lib_directories)) |full_path| {
                argv.appendAssumeCapacity(full_path);
                continue;
            }
            if (target.abi.isGnu()) {
                const fallback_name = try allocPrint(arena, "lib{s}.dll.a", .{key});
                if (try findLib(arena, fallback_name, coff.lib_directories)) |full_path| {
                    argv.appendAssumeCapacity(full_path);
                    continue;
                }
            }
            if (target.abi == .msvc or target.abi == .itanium) {
                argv.appendAssumeCapacity(lib_basename);
                continue;
            }

            log.err("DLL import library for -l{s} not found", .{key});
            return error.DllImportLibraryNotFound;
        }

        try spawnLld(comp, arena, argv.items);
    }
}
fn findLib(arena: Allocator, name: []const u8, lib_directories: []const Cache.Directory) !?[]const u8 {
    for (lib_directories) |lib_directory| {
        lib_directory.handle.access(name, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        return try lib_directory.join(arena, &.{name});
    }
    return null;
}

fn elfLink(lld: *Lld, arena: Allocator) !void {
    const comp = lld.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;
    const base = &lld.base;
    const elf = &lld.ofmt.elf;

    const directory = base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});

    const zcu_obj_path: ?Cache.Path = if (comp.zcu != null) p: {
        break :p try comp.resolveEmitPathFlush(arena, .temp, base.zcu_object_basename.?);
    } else null;

    const output_mode = comp.config.output_mode;
    const is_obj = output_mode == .Obj;
    const is_lib = output_mode == .Lib;
    const link_mode = comp.config.link_mode;
    const is_dyn_lib = link_mode == .dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or output_mode == .Exe;
    const have_dynamic_linker = link_mode == .dynamic and is_exe_or_dyn_lib;
    const target = comp.root_mod.resolved_target.result;
    const compiler_rt_path: ?Cache.Path = blk: {
        if (comp.compiler_rt_lib) |x| break :blk x.full_object_path;
        if (comp.compiler_rt_obj) |x| break :blk x.full_object_path;
        break :blk null;
    };
    const ubsan_rt_path: ?Cache.Path = blk: {
        if (comp.ubsan_rt_lib) |x| break :blk x.full_object_path;
        if (comp.ubsan_rt_obj) |x| break :blk x.full_object_path;
        break :blk null;
    };

    // Due to a deficiency in LLD, we need to special-case BPF to a simple file
    // copy when generating relocatables. Normally, we would expect `lld -r` to work.
    // However, because LLD wants to resolve BPF relocations which it shouldn't, it fails
    // before even generating the relocatable.
    //
    // For m68k, we go through this path because LLD doesn't support it yet, but LLVM can
    // produce usable object files.
    if (output_mode == .Obj and
        (comp.config.lto != .none or
            target.cpu.arch.isBpf() or
            target.cpu.arch == .lanai or
            target.cpu.arch == .m68k or
            target.cpu.arch.isSPARC() or
            target.cpu.arch == .ve or
            target.cpu.arch == .xcore))
    {
        // In this case we must do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (link.firstObjectInput(comp.link_inputs)) |obj| break :blk obj.path;

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (zcu_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        try std.fs.Dir.copyFile(
            the_object_path.root_dir.handle,
            the_object_path.sub_path,
            directory.handle,
            base.emit.sub_path,
            .{},
        );
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "ld.lld";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });
        if (is_obj) {
            try argv.append("-r");
        }

        try argv.append("--error-limit=0");

        if (comp.sysroot) |sysroot| {
            try argv.append(try std.fmt.allocPrint(arena, "--sysroot={s}", .{sysroot}));
        }

        if (target_util.llvmMachineAbi(target)) |mabi| {
            try argv.appendSlice(&.{
                "-mllvm",
                try std.fmt.allocPrint(arena, "-target-abi={s}", .{mabi}),
            });
        }

        try argv.appendSlice(&.{
            "-mllvm",
            try std.fmt.allocPrint(arena, "-float-abi={s}", .{if (target.abi.float() == .hard) "hard" else "soft"}),
        });

        if (comp.config.lto != .none) {
            switch (comp.root_mod.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("--lto-O2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("--lto-O3"),
            }
        }
        switch (comp.root_mod.optimize_mode) {
            .Debug => {},
            .ReleaseSmall => try argv.append("-O2"),
            .ReleaseFast, .ReleaseSafe => try argv.append("-O3"),
        }

        if (elf.entry_name) |name| {
            try argv.appendSlice(&.{ "--entry", name });
        }

        for (comp.force_undefined_symbols.keys()) |sym| {
            try argv.append("-u");
            try argv.append(sym);
        }

        switch (elf.hash_style) {
            .gnu => try argv.append("--hash-style=gnu"),
            .sysv => try argv.append("--hash-style=sysv"),
            .both => {}, // this is the default
        }

        if (output_mode == .Exe) {
            try argv.appendSlice(&.{
                "-z",
                try std.fmt.allocPrint(arena, "stack-size={d}", .{base.stack_size}),
            });
        }

        switch (base.build_id) {
            .none => try argv.append("--build-id=none"),
            .fast, .uuid, .sha1, .md5 => try argv.append(try std.fmt.allocPrint(arena, "--build-id={s}", .{
                @tagName(base.build_id),
            })),
            .hexstring => |hs| try argv.append(try std.fmt.allocPrint(arena, "--build-id=0x{s}", .{
                std.fmt.fmtSliceHexLower(hs.toSlice()),
            })),
        }

        try argv.append(try std.fmt.allocPrint(arena, "--image-base={d}", .{elf.image_base}));

        if (elf.linker_script) |linker_script| {
            try argv.append("-T");
            try argv.append(linker_script);
        }

        if (elf.sort_section) |how| {
            const arg = try std.fmt.allocPrint(arena, "--sort-section={s}", .{@tagName(how)});
            try argv.append(arg);
        }

        if (base.gc_sections) {
            try argv.append("--gc-sections");
        }

        if (base.print_gc_sections) {
            try argv.append("--print-gc-sections");
        }

        if (elf.print_icf_sections) {
            try argv.append("--print-icf-sections");
        }

        if (elf.print_map) {
            try argv.append("--print-map");
        }

        if (comp.link_eh_frame_hdr) {
            try argv.append("--eh-frame-hdr");
        }

        if (elf.emit_relocs) {
            try argv.append("--emit-relocs");
        }

        if (comp.config.rdynamic) {
            try argv.append("--export-dynamic");
        }

        if (comp.config.debug_format == .strip) {
            try argv.append("-s");
        }

        if (elf.z_nodelete) {
            try argv.append("-z");
            try argv.append("nodelete");
        }
        if (elf.z_notext) {
            try argv.append("-z");
            try argv.append("notext");
        }
        if (elf.z_defs) {
            try argv.append("-z");
            try argv.append("defs");
        }
        if (elf.z_origin) {
            try argv.append("-z");
            try argv.append("origin");
        }
        if (elf.z_nocopyreloc) {
            try argv.append("-z");
            try argv.append("nocopyreloc");
        }
        if (elf.z_now) {
            // LLD defaults to -zlazy
            try argv.append("-znow");
        }
        if (!elf.z_relro) {
            // LLD defaults to -zrelro
            try argv.append("-znorelro");
        }
        if (elf.z_common_page_size) |size| {
            try argv.append("-z");
            try argv.append(try std.fmt.allocPrint(arena, "common-page-size={d}", .{size}));
        }
        if (elf.z_max_page_size) |size| {
            try argv.append("-z");
            try argv.append(try std.fmt.allocPrint(arena, "max-page-size={d}", .{size}));
        }

        if (getLDMOption(target)) |ldm| {
            try argv.append("-m");
            try argv.append(ldm);
        }

        if (link_mode == .static) {
            if (target.cpu.arch.isArm()) {
                try argv.append("-Bstatic");
            } else {
                try argv.append("-static");
            }
        } else if (switch (target.os.tag) {
            else => is_dyn_lib,
            .haiku => is_exe_or_dyn_lib,
        }) {
            try argv.append("-shared");
        }

        if (comp.config.pie and output_mode == .Exe) {
            try argv.append("-pie");
        }

        if (is_exe_or_dyn_lib and target.os.tag == .netbsd) {
            // Add options to produce shared objects with only 2 PT_LOAD segments.
            // NetBSD expects 2 PT_LOAD segments in a shared object, otherwise
            // ld.elf_so fails loading dynamic libraries with "not found" error.
            // See https://github.com/ziglang/zig/issues/9109 .
            try argv.append("--no-rosegment");
            try argv.append("-znorelro");
        }

        try argv.append("-o");
        try argv.append(full_out_path);

        // csu prelude
        const csu = try comp.getCrtPaths(arena);
        if (csu.crt0) |p| try argv.append(try p.toString(arena));
        if (csu.crti) |p| try argv.append(try p.toString(arena));
        if (csu.crtbegin) |p| try argv.append(try p.toString(arena));

        for (elf.rpath_list) |rpath| {
            try argv.appendSlice(&.{ "-rpath", rpath });
        }

        for (elf.symbol_wrap_set) |symbol_name| {
            try argv.appendSlice(&.{ "-wrap", symbol_name });
        }

        if (comp.config.link_libc) {
            if (comp.libc_installation) |libc_installation| {
                try argv.append("-L");
                try argv.append(libc_installation.crt_dir.?);
            }
        }

        if (have_dynamic_linker and
            (comp.config.link_libc or comp.root_mod.resolved_target.is_explicit_dynamic_linker))
        {
            if (target.dynamic_linker.get()) |dynamic_linker| {
                try argv.append("-dynamic-linker");
                try argv.append(dynamic_linker);
            }
        }

        if (is_dyn_lib) {
            if (elf.soname) |soname| {
                try argv.append("-soname");
                try argv.append(soname);
            }
            if (elf.version_script) |version_script| {
                try argv.append("-version-script");
                try argv.append(version_script);
            }
            if (elf.allow_undefined_version) {
                try argv.append("--undefined-version");
            } else {
                try argv.append("--no-undefined-version");
            }
            if (elf.enable_new_dtags) |enable_new_dtags| {
                if (enable_new_dtags) {
                    try argv.append("--enable-new-dtags");
                } else {
                    try argv.append("--disable-new-dtags");
                }
            }
        }

        // Positional arguments to the linker such as object files.
        var whole_archive = false;

        for (base.comp.link_inputs) |link_input| switch (link_input) {
            .res => unreachable, // Windows-only
            .dso => continue,
            .object, .archive => |obj| {
                if (obj.must_link and !whole_archive) {
                    try argv.append("-whole-archive");
                    whole_archive = true;
                } else if (!obj.must_link and whole_archive) {
                    try argv.append("-no-whole-archive");
                    whole_archive = false;
                }
                try argv.append(try obj.path.toString(arena));
            },
            .dso_exact => |dso_exact| {
                assert(dso_exact.name[0] == ':');
                try argv.appendSlice(&.{ "-l", dso_exact.name });
            },
        };

        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }

        if (zcu_obj_path) |p| {
            try argv.append(try p.toString(arena));
        }

        if (comp.tsan_lib) |lib| {
            assert(comp.config.any_sanitize_thread);
            try argv.append(try lib.full_object_path.toString(arena));
        }

        if (comp.fuzzer_lib) |lib| {
            assert(comp.config.any_fuzz);
            try argv.append(try lib.full_object_path.toString(arena));
        }

        if (ubsan_rt_path) |p| {
            try argv.append(try p.toString(arena));
        }

        // Shared libraries.
        if (is_exe_or_dyn_lib) {
            // Worst-case, we need an --as-needed argument for every lib, as well
            // as one before and one after.
            try argv.ensureUnusedCapacity(2 * base.comp.link_inputs.len + 2);
            argv.appendAssumeCapacity("--as-needed");
            var as_needed = true;

            for (base.comp.link_inputs) |link_input| switch (link_input) {
                .res => unreachable, // Windows-only
                .object, .archive, .dso_exact => continue,
                .dso => |dso| {
                    const lib_as_needed = !dso.needed;
                    switch ((@as(u2, @intFromBool(lib_as_needed)) << 1) | @intFromBool(as_needed)) {
                        0b00, 0b11 => {},
                        0b01 => {
                            argv.appendAssumeCapacity("--no-as-needed");
                            as_needed = false;
                        },
                        0b10 => {
                            argv.appendAssumeCapacity("--as-needed");
                            as_needed = true;
                        },
                    }

                    // By this time, we depend on these libs being dynamically linked
                    // libraries and not static libraries (the check for that needs to be earlier),
                    // but they could be full paths to .so files, in which case we
                    // want to avoid prepending "-l".
                    argv.appendAssumeCapacity(try dso.path.toString(arena));
                },
            };

            if (!as_needed) {
                argv.appendAssumeCapacity("--as-needed");
                as_needed = true;
            }

            // libc++ dep
            if (comp.config.link_libcpp) {
                try argv.append(try comp.libcxxabi_static_lib.?.full_object_path.toString(arena));
                try argv.append(try comp.libcxx_static_lib.?.full_object_path.toString(arena));
            }

            // libunwind dep
            if (comp.config.link_libunwind) {
                try argv.append(try comp.libunwind_static_lib.?.full_object_path.toString(arena));
            }

            // libc dep
            diags.flags.missing_libc = false;
            if (comp.config.link_libc) {
                if (comp.libc_installation != null) {
                    const needs_grouping = link_mode == .static;
                    if (needs_grouping) try argv.append("--start-group");
                    try argv.appendSlice(target_util.libcFullLinkFlags(target));
                    if (needs_grouping) try argv.append("--end-group");
                } else if (target.isGnuLibC()) {
                    for (glibc.libs) |lib| {
                        if (lib.removed_in) |rem_in| {
                            if (target.os.versionRange().gnuLibCVersion().?.order(rem_in) != .lt) continue;
                        }

                        const lib_path = try std.fmt.allocPrint(arena, "{}{c}lib{s}.so.{d}", .{
                            comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                        });
                        try argv.append(lib_path);
                    }
                    try argv.append(try comp.crtFileAsString(arena, "libc_nonshared.a"));
                } else if (target.isMuslLibC()) {
                    try argv.append(try comp.crtFileAsString(arena, switch (link_mode) {
                        .static => "libc.a",
                        .dynamic => "libc.so",
                    }));
                } else if (target.isFreeBSDLibC()) {
                    for (freebsd.libs) |lib| {
                        const lib_path = try std.fmt.allocPrint(arena, "{}{c}lib{s}.so.{d}", .{
                            comp.freebsd_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                        });
                        try argv.append(lib_path);
                    }
                } else if (target.isNetBSDLibC()) {
                    for (netbsd.libs) |lib| {
                        const lib_path = try std.fmt.allocPrint(arena, "{}{c}lib{s}.so.{d}", .{
                            comp.netbsd_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                        });
                        try argv.append(lib_path);
                    }
                } else {
                    diags.flags.missing_libc = true;
                }

                if (comp.zigc_static_lib) |zigc| {
                    try argv.append(try zigc.full_object_path.toString(arena));
                }
            }
        }

        // compiler-rt. Since compiler_rt exports symbols like `memset`, it needs
        // to be after the shared libraries, so they are picked up from the shared
        // libraries, not libcompiler_rt.
        if (compiler_rt_path) |p| {
            try argv.append(try p.toString(arena));
        }

        // crt postlude
        if (csu.crtend) |p| try argv.append(try p.toString(arena));
        if (csu.crtn) |p| try argv.append(try p.toString(arena));

        if (base.allow_shlib_undefined) {
            try argv.append("--allow-shlib-undefined");
        }

        switch (elf.compress_debug_sections) {
            .none => {},
            .zlib => try argv.append("--compress-debug-sections=zlib"),
            .zstd => try argv.append("--compress-debug-sections=zstd"),
        }

        if (elf.bind_global_refs_locally) {
            try argv.append("-Bsymbolic");
        }

        try spawnLld(comp, arena, argv.items);
    }
}
fn getLDMOption(target: std.Target) ?[]const u8 {
    // This should only return emulations understood by LLD's parseEmulation().
    return switch (target.cpu.arch) {
        .aarch64 => switch (target.os.tag) {
            .linux => "aarch64linux",
            else => "aarch64elf",
        },
        .aarch64_be => switch (target.os.tag) {
            .linux => "aarch64linuxb",
            else => "aarch64elfb",
        },
        .amdgcn => "elf64_amdgpu",
        .arm, .thumb => switch (target.os.tag) {
            .linux => "armelf_linux_eabi",
            else => "armelf",
        },
        .armeb, .thumbeb => switch (target.os.tag) {
            .linux => "armelfb_linux_eabi",
            else => "armelfb",
        },
        .hexagon => "hexagonelf",
        .loongarch32 => "elf32loongarch",
        .loongarch64 => "elf64loongarch",
        .mips => switch (target.os.tag) {
            .freebsd => "elf32btsmip_fbsd",
            else => "elf32btsmip",
        },
        .mipsel => switch (target.os.tag) {
            .freebsd => "elf32ltsmip_fbsd",
            else => "elf32ltsmip",
        },
        .mips64 => switch (target.os.tag) {
            .freebsd => switch (target.abi) {
                .gnuabin32, .muslabin32 => "elf32btsmipn32_fbsd",
                else => "elf64btsmip_fbsd",
            },
            else => switch (target.abi) {
                .gnuabin32, .muslabin32 => "elf32btsmipn32",
                else => "elf64btsmip",
            },
        },
        .mips64el => switch (target.os.tag) {
            .freebsd => switch (target.abi) {
                .gnuabin32, .muslabin32 => "elf32ltsmipn32_fbsd",
                else => "elf64ltsmip_fbsd",
            },
            else => switch (target.abi) {
                .gnuabin32, .muslabin32 => "elf32ltsmipn32",
                else => "elf64ltsmip",
            },
        },
        .msp430 => "msp430elf",
        .powerpc => switch (target.os.tag) {
            .freebsd => "elf32ppc_fbsd",
            .linux => "elf32ppclinux",
            else => "elf32ppc",
        },
        .powerpcle => switch (target.os.tag) {
            .linux => "elf32lppclinux",
            else => "elf32lppc",
        },
        .powerpc64 => "elf64ppc",
        .powerpc64le => "elf64lppc",
        .riscv32 => "elf32lriscv",
        .riscv64 => "elf64lriscv",
        .s390x => "elf64_s390",
        .sparc64 => "elf64_sparc",
        .x86 => switch (target.os.tag) {
            .freebsd => "elf_i386_fbsd",
            else => "elf_i386",
        },
        .x86_64 => switch (target.abi) {
            .gnux32, .muslx32 => "elf32_x86_64",
            else => "elf_x86_64",
        },
        else => null,
    };
}
fn wasmLink(lld: *Lld, arena: Allocator) !void {
    const comp = lld.base.comp;
    const shared_memory = comp.config.shared_memory;
    const export_memory = comp.config.export_memory;
    const import_memory = comp.config.import_memory;
    const target = comp.root_mod.resolved_target.result;
    const base = &lld.base;
    const wasm = &lld.ofmt.wasm;

    const gpa = comp.gpa;

    const directory = base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});

    const zcu_obj_path: ?Cache.Path = if (comp.zcu != null) p: {
        break :p try comp.resolveEmitPathFlush(arena, .temp, base.zcu_object_basename.?);
    } else null;

    const is_obj = comp.config.output_mode == .Obj;
    const compiler_rt_path: ?Cache.Path = blk: {
        if (comp.compiler_rt_lib) |lib| break :blk lib.full_object_path;
        if (comp.compiler_rt_obj) |obj| break :blk obj.full_object_path;
        break :blk null;
    };
    const ubsan_rt_path: ?Cache.Path = blk: {
        if (comp.ubsan_rt_lib) |lib| break :blk lib.full_object_path;
        if (comp.ubsan_rt_obj) |obj| break :blk obj.full_object_path;
        break :blk null;
    };

    if (is_obj) {
        // LLD's WASM driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (link.firstObjectInput(comp.link_inputs)) |obj| break :blk obj.path;

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (zcu_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        try fs.Dir.copyFile(
            the_object_path.root_dir.handle,
            the_object_path.sub_path,
            directory.handle,
            base.emit.sub_path,
            .{},
        );
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "wasm-ld";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });
        try argv.append("--error-limit=0");

        if (comp.config.lto != .none) {
            switch (comp.root_mod.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("-O2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("-O3"),
            }
        }

        if (import_memory) {
            try argv.append("--import-memory");
        }

        if (export_memory) {
            try argv.append("--export-memory");
        }

        if (wasm.import_table) {
            assert(!wasm.export_table);
            try argv.append("--import-table");
        }

        if (wasm.export_table) {
            assert(!wasm.import_table);
            try argv.append("--export-table");
        }

        // For wasm-ld we only need to specify '--no-gc-sections' when the user explicitly
        // specified it as garbage collection is enabled by default.
        if (!base.gc_sections) {
            try argv.append("--no-gc-sections");
        }

        if (comp.config.debug_format == .strip) {
            try argv.append("-s");
        }

        if (wasm.initial_memory) |initial_memory| {
            const arg = try std.fmt.allocPrint(arena, "--initial-memory={d}", .{initial_memory});
            try argv.append(arg);
        }

        if (wasm.max_memory) |max_memory| {
            const arg = try std.fmt.allocPrint(arena, "--max-memory={d}", .{max_memory});
            try argv.append(arg);
        }

        if (shared_memory) {
            try argv.append("--shared-memory");
        }

        if (wasm.global_base) |global_base| {
            const arg = try std.fmt.allocPrint(arena, "--global-base={d}", .{global_base});
            try argv.append(arg);
        } else {
            // We prepend it by default, so when a stack overflow happens the runtime will trap correctly,
            // rather than silently overwrite all global declarations. See https://github.com/ziglang/zig/issues/4496
            //
            // The user can overwrite this behavior by setting the global-base
            try argv.append("--stack-first");
        }

        // Users are allowed to specify which symbols they want to export to the wasm host.
        for (wasm.export_symbol_names) |symbol_name| {
            const arg = try std.fmt.allocPrint(arena, "--export={s}", .{symbol_name});
            try argv.append(arg);
        }

        if (comp.config.rdynamic) {
            try argv.append("--export-dynamic");
        }

        if (wasm.entry_name) |entry_name| {
            try argv.appendSlice(&.{ "--entry", entry_name });
        } else {
            try argv.append("--no-entry");
        }

        try argv.appendSlice(&.{
            "-z",
            try std.fmt.allocPrint(arena, "stack-size={d}", .{base.stack_size}),
        });

        switch (base.build_id) {
            .none => try argv.append("--build-id=none"),
            .fast, .uuid, .sha1 => try argv.append(try std.fmt.allocPrint(arena, "--build-id={s}", .{
                @tagName(base.build_id),
            })),
            .hexstring => |hs| try argv.append(try std.fmt.allocPrint(arena, "--build-id=0x{s}", .{
                std.fmt.fmtSliceHexLower(hs.toSlice()),
            })),
            .md5 => {},
        }

        if (wasm.import_symbols) {
            try argv.append("--allow-undefined");
        }

        if (comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic) {
            try argv.append("--shared");
        }
        if (comp.config.pie) {
            try argv.append("--pie");
        }

        try argv.appendSlice(&.{ "-o", full_out_path });

        if (target.cpu.arch == .wasm64) {
            try argv.append("-mwasm64");
        }

        const is_exe_or_dyn_lib = comp.config.output_mode == .Exe or
            (comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic);

        if (comp.config.link_libc and is_exe_or_dyn_lib) {
            if (target.os.tag == .wasi) {
                for (comp.wasi_emulated_libs) |crt_file| {
                    try argv.append(try comp.crtFileAsString(
                        arena,
                        wasi_libc.emulatedLibCRFileLibName(crt_file),
                    ));
                }

                try argv.append(try comp.crtFileAsString(
                    arena,
                    wasi_libc.execModelCrtFileFullName(comp.config.wasi_exec_model),
                ));
                try argv.append(try comp.crtFileAsString(arena, "libc.a"));
            }

            if (comp.zigc_static_lib) |zigc| {
                try argv.append(try zigc.full_object_path.toString(arena));
            }

            if (comp.config.link_libcpp) {
                try argv.append(try comp.libcxx_static_lib.?.full_object_path.toString(arena));
                try argv.append(try comp.libcxxabi_static_lib.?.full_object_path.toString(arena));
            }
        }

        // Positional arguments to the linker such as object files.
        var whole_archive = false;
        for (comp.link_inputs) |link_input| switch (link_input) {
            .object, .archive => |obj| {
                if (obj.must_link and !whole_archive) {
                    try argv.append("-whole-archive");
                    whole_archive = true;
                } else if (!obj.must_link and whole_archive) {
                    try argv.append("-no-whole-archive");
                    whole_archive = false;
                }
                try argv.append(try obj.path.toString(arena));
            },
            .dso => |dso| {
                try argv.append(try dso.path.toString(arena));
            },
            .dso_exact => unreachable,
            .res => unreachable,
        };
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }
        if (zcu_obj_path) |p| {
            try argv.append(try p.toString(arena));
        }

        if (compiler_rt_path) |p| {
            try argv.append(try p.toString(arena));
        }

        if (ubsan_rt_path) |p| {
            try argv.append(try p.toStringZ(arena));
        }

        try spawnLld(comp, arena, argv.items);

        // Give +x to the .wasm file if it is an executable and the OS is WASI.
        // Some systems may be configured to execute such binaries directly. Even if that
        // is not the case, it means we will get "exec format error" when trying to run
        // it, and then can react to that in the same way as trying to run an ELF file
        // from a foreign CPU architecture.
        if (fs.has_executable_bit and target.os.tag == .wasi and
            comp.config.output_mode == .Exe)
        {
            // TODO: what's our strategy for reporting linker errors from this function?
            // report a nice error here with the file path if it fails instead of
            // just returning the error code.
            // chmod does not interact with umask, so we use a conservative -rwxr--r-- here.
            std.posix.fchmodat(fs.cwd().fd, full_out_path, 0o744, 0) catch |err| switch (err) {
                error.OperationNotSupported => unreachable, // Not a symlink.
                else => |e| return e,
            };
        }
    }
}

fn spawnLld(
    comp: *Compilation,
    arena: Allocator,
    argv: []const []const u8,
) !void {
    if (comp.verbose_link) {
        // Skip over our own name so that the LLD linker name is the first argv item.
        Compilation.dump_argv(argv[1..]);
    }

    // If possible, we run LLD as a child process because it does not always
    // behave properly as a library, unfortunately.
    // https://github.com/ziglang/zig/issues/3825
    if (!std.process.can_spawn) {
        const exit_code = try lldMain(arena, argv, false);
        if (exit_code == 0) return;
        if (comp.clang_passthrough_mode) std.process.exit(exit_code);
        return error.LinkFailure;
    }

    var stderr: []u8 = &.{};
    defer comp.gpa.free(stderr);

    var child = std.process.Child.init(argv, arena);
    const term = (if (comp.clang_passthrough_mode) term: {
        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        break :term child.spawnAndWait();
    } else term: {
        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| break :term err;
        stderr = try child.stderr.?.reader().readAllAlloc(comp.gpa, std.math.maxInt(usize));
        break :term child.wait();
    }) catch |first_err| term: {
        const err = switch (first_err) {
            error.NameTooLong => err: {
                const s = fs.path.sep_str;
                const rand_int = std.crypto.random.int(u64);
                const rsp_path = "tmp" ++ s ++ std.fmt.hex(rand_int) ++ ".rsp";

                const rsp_file = try comp.dirs.local_cache.handle.createFileZ(rsp_path, .{});
                defer comp.dirs.local_cache.handle.deleteFileZ(rsp_path) catch |err|
                    log.warn("failed to delete response file {s}: {s}", .{ rsp_path, @errorName(err) });
                {
                    defer rsp_file.close();
                    var rsp_buf = std.io.bufferedWriter(rsp_file.writer());
                    const rsp_writer = rsp_buf.writer();
                    for (argv[2..]) |arg| {
                        try rsp_writer.writeByte('"');
                        for (arg) |c| {
                            switch (c) {
                                '\"', '\\' => try rsp_writer.writeByte('\\'),
                                else => {},
                            }
                            try rsp_writer.writeByte(c);
                        }
                        try rsp_writer.writeByte('"');
                        try rsp_writer.writeByte('\n');
                    }
                    try rsp_buf.flush();
                }

                var rsp_child = std.process.Child.init(&.{ argv[0], argv[1], try std.fmt.allocPrint(
                    arena,
                    "@{s}",
                    .{try comp.dirs.local_cache.join(arena, &.{rsp_path})},
                ) }, arena);
                if (comp.clang_passthrough_mode) {
                    rsp_child.stdin_behavior = .Inherit;
                    rsp_child.stdout_behavior = .Inherit;
                    rsp_child.stderr_behavior = .Inherit;

                    break :term rsp_child.spawnAndWait() catch |err| break :err err;
                } else {
                    rsp_child.stdin_behavior = .Ignore;
                    rsp_child.stdout_behavior = .Ignore;
                    rsp_child.stderr_behavior = .Pipe;

                    rsp_child.spawn() catch |err| break :err err;
                    stderr = try rsp_child.stderr.?.reader().readAllAlloc(comp.gpa, std.math.maxInt(usize));
                    break :term rsp_child.wait() catch |err| break :err err;
                }
            },
            else => first_err,
        };
        log.err("unable to spawn LLD {s}: {s}", .{ argv[0], @errorName(err) });
        return error.UnableToSpawnSelf;
    };

    const diags = &comp.link_diags;
    switch (term) {
        .Exited => |code| if (code != 0) {
            if (comp.clang_passthrough_mode) std.process.exit(code);
            diags.lockAndParseLldStderr(argv[1], stderr);
            return error.LinkFailure;
        },
        else => {
            if (comp.clang_passthrough_mode) std.process.abort();
            return diags.fail("{s} terminated with stderr:\n{s}", .{ argv[0], stderr });
        },
    }

    if (stderr.len > 0) log.warn("unexpected LLD stderr:\n{s}", .{stderr});
}

const std = @import("std");
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
const allocPrint = std.fmt.allocPrint;
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const mem = std.mem;

const Compilation = @import("../Compilation.zig");
const Zcu = @import("../Zcu.zig");
const dev = @import("../dev.zig");
const freebsd = @import("../libs/freebsd.zig");
const glibc = @import("../libs/glibc.zig");
const netbsd = @import("../libs/netbsd.zig");
const wasi_libc = @import("../libs/wasi_libc.zig");
const link = @import("../link.zig");
const lldMain = @import("../main.zig").lldMain;
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;
const Lld = @This();
