const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.link);
const trace = @import("tracy.zig").trace;
const wasi_libc = @import("wasi_libc.zig");

const Air = @import("Air.zig");
const Allocator = std.mem.Allocator;
const Cache = std.Build.Cache;
const Compilation = @import("Compilation.zig");
const LibCInstallation = std.zig.LibCInstallation;
const Liveness = @import("Liveness.zig");
const Module = @import("Module.zig");
const InternPool = @import("InternPool.zig");
const Type = @import("type.zig").Type;
const Value = @import("Value.zig");
const LlvmObject = @import("codegen/llvm.zig").Object;
const lldMain = @import("main.zig").lldMain;
const Package = @import("Package.zig");

/// When adding a new field, remember to update `hashAddSystemLibs`.
/// These are *always* dynamically linked. Static libraries will be
/// provided as positional arguments.
pub const SystemLib = struct {
    needed: bool,
    weak: bool,
    /// This can be null in two cases right now:
    /// 1. Windows DLLs that zig ships such as advapi32.
    /// 2. extern "foo" fn declarations where we find out about libraries too late
    /// TODO: make this non-optional and resolve those two cases somehow.
    path: ?[]const u8,
};

pub fn hashAddSystemLibs(
    man: *Cache.Manifest,
    hm: std.StringArrayHashMapUnmanaged(SystemLib),
) !void {
    const keys = hm.keys();
    man.hash.addListOfBytes(keys);
    for (hm.values()) |value| {
        man.hash.add(value.needed);
        man.hash.add(value.weak);
        if (value.path) |p| _ = try man.addFile(p, null);
    }
}

pub const producer_string = if (builtin.is_test) "zig test" else "zig " ++ build_options.version;

pub const File = struct {
    tag: Tag,

    /// The owner of this output File.
    comp: *Compilation,
    emit: Compilation.Emit,

    file: ?fs.File,
    /// When linking with LLD, this linker code will output an object file only at
    /// this location, and then this path can be placed on the LLD linker line.
    zcu_object_sub_path: ?[]const u8 = null,
    disable_lld_caching: bool,
    gc_sections: bool,
    print_gc_sections: bool,
    build_id: std.zig.BuildId,
    rpath_list: []const []const u8,
    allow_shlib_undefined: bool,
    stack_size: u64,

    /// Prevents other processes from clobbering files in the output directory
    /// of this linking operation.
    lock: ?Cache.Lock = null,
    child_pid: ?std.process.Child.Id = null,

    pub const OpenOptions = struct {
        symbol_count_hint: u64 = 32,
        program_code_size_hint: u64 = 256 * 1024,

        /// This may depend on what symbols are found during the linking process.
        entry: Entry,
        /// Virtual address of the entry point procedure relative to image base.
        entry_addr: ?u64,
        stack_size: ?u64,
        image_base: ?u64,
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
        tsaware: bool,
        nxcompat: bool,
        dynamicbase: bool,
        compress_debug_sections: Elf.CompressDebugSections,
        bind_global_refs_locally: bool,
        import_symbols: bool,
        import_table: bool,
        export_table: bool,
        initial_memory: ?u64,
        max_memory: ?u64,
        export_symbol_names: []const []const u8,
        global_base: ?u64,
        build_id: std.zig.BuildId,
        disable_lld_caching: bool,
        hash_style: Elf.HashStyle,
        sort_section: ?Elf.SortSection,
        major_subsystem_version: ?u16,
        minor_subsystem_version: ?u16,
        gc_sections: ?bool,
        allow_shlib_undefined: ?bool,
        allow_undefined_version: bool,
        enable_new_dtags: ?bool,
        subsystem: ?std.Target.SubSystem,
        linker_script: ?[]const u8,
        version_script: ?[]const u8,
        soname: ?[]const u8,
        print_gc_sections: bool,
        print_icf_sections: bool,
        print_map: bool,

        /// Use a wrapper function for symbol. Any undefined reference to symbol
        /// will be resolved to __wrap_symbol. Any undefined reference to
        /// __real_symbol will be resolved to symbol. This can be used to provide a
        /// wrapper for a system function. The wrapper function should be called
        /// __wrap_symbol. If it wishes to call the system function, it should call
        /// __real_symbol.
        symbol_wrap_set: std.StringArrayHashMapUnmanaged(void),

        compatibility_version: ?std.SemanticVersion,

        // TODO: remove this. libraries are resolved by the frontend.
        lib_dirs: []const []const u8,
        framework_dirs: []const []const u8,
        rpath_list: []const []const u8,

        /// Zig compiler development linker flags.
        /// Enable dumping of linker's state as JSON.
        enable_link_snapshots: bool,

        /// Darwin-specific linker flags:
        /// Install name for the dylib
        install_name: ?[]const u8,
        /// Path to entitlements file
        entitlements: ?[]const u8,
        /// size of the __PAGEZERO segment
        pagezero_size: ?u64,
        /// Set minimum space for future expansion of the load commands
        headerpad_size: ?u32,
        /// Set enough space as if all paths were MATPATHLEN
        headerpad_max_install_names: bool,
        /// Remove dylibs that are unreachable by the entry point or exported symbols
        dead_strip_dylibs: bool,
        frameworks: []const MachO.Framework,
        darwin_sdk_layout: ?MachO.SdkLayout,
        /// Force load all members of static archives that implement an
        /// Objective-C class or category
        force_load_objc: bool,

        /// Windows-specific linker flags:
        /// PDB source path prefix to instruct the linker how to resolve relative
        /// paths when consolidating CodeView streams into a single PDB file.
        pdb_source_path: ?[]const u8,
        /// PDB output path
        pdb_out_path: ?[]const u8,
        /// .def file to specify when linking
        module_definition_file: ?[]const u8,

        pub const Entry = union(enum) {
            default,
            disabled,
            enabled,
            named: []const u8,
        };
    };

    /// Attempts incremental linking, if the file already exists. If
    /// incremental linking fails, falls back to truncating the file and
    /// rewriting it. A malicious file is detected as incremental link failure
    /// and does not cause Illegal Behavior. This operation is not atomic.
    /// `arena` is used for allocations with the same lifetime as the created File.
    pub fn open(
        arena: Allocator,
        comp: *Compilation,
        emit: Compilation.Emit,
        options: OpenOptions,
    ) !*File {
        switch (Tag.fromObjectFormat(comp.root_mod.resolved_target.result.ofmt)) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                const ptr = try tag.Type().open(arena, comp, emit, options);
                return &ptr.base;
            },
        }
    }

    pub fn createEmpty(
        arena: Allocator,
        comp: *Compilation,
        emit: Compilation.Emit,
        options: OpenOptions,
    ) !*File {
        switch (Tag.fromObjectFormat(comp.root_mod.resolved_target.result.ofmt)) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                const ptr = try tag.Type().createEmpty(arena, comp, emit, options);
                return &ptr.base;
            },
        }
    }

    pub fn cast(base: *File, comptime T: type) ?*T {
        return if (base.tag == T.base_tag) @fieldParentPtr("base", base) else null;
    }

    pub fn makeWritable(base: *File) !void {
        const comp = base.comp;
        const gpa = comp.gpa;
        switch (base.tag) {
            .coff, .elf, .macho, .plan9, .wasm => {
                if (build_options.only_c) unreachable;
                if (base.file != null) return;
                const emit = base.emit;
                if (base.child_pid) |pid| {
                    if (builtin.os.tag == .windows) {
                        base.cast(Coff).?.ptraceAttach(pid) catch |err| {
                            log.warn("attaching failed with error: {s}", .{@errorName(err)});
                        };
                    } else {
                        // If we try to open the output file in write mode while it is running,
                        // it will return ETXTBSY. So instead, we copy the file, atomically rename it
                        // over top of the exe path, and then proceed normally. This changes the inode,
                        // avoiding the error.
                        const tmp_sub_path = try std.fmt.allocPrint(gpa, "{s}-{x}", .{
                            emit.sub_path, std.crypto.random.int(u32),
                        });
                        defer gpa.free(tmp_sub_path);
                        try emit.directory.handle.copyFile(emit.sub_path, emit.directory.handle, tmp_sub_path, .{});
                        try emit.directory.handle.rename(tmp_sub_path, emit.sub_path);
                        switch (builtin.os.tag) {
                            .linux => std.posix.ptrace(std.os.linux.PTRACE.ATTACH, pid, 0, 0) catch |err| {
                                log.warn("ptrace failure: {s}", .{@errorName(err)});
                            },
                            .macos => base.cast(MachO).?.ptraceAttach(pid) catch |err| {
                                log.warn("attaching failed with error: {s}", .{@errorName(err)});
                            },
                            .windows => unreachable,
                            else => return error.HotSwapUnavailableOnHostOperatingSystem,
                        }
                    }
                }
                const use_lld = build_options.have_llvm and comp.config.use_lld;
                const output_mode = comp.config.output_mode;
                const link_mode = comp.config.link_mode;
                base.file = try emit.directory.handle.createFile(emit.sub_path, .{
                    .truncate = false,
                    .read = true,
                    .mode = determineMode(use_lld, output_mode, link_mode),
                });
            },
            .c, .spirv, .nvptx => {},
        }
    }

    pub fn makeExecutable(base: *File) !void {
        const comp = base.comp;
        const output_mode = comp.config.output_mode;
        const link_mode = comp.config.link_mode;
        const use_lld = build_options.have_llvm and comp.config.use_lld;

        switch (output_mode) {
            .Obj => return,
            .Lib => switch (link_mode) {
                .static => return,
                .dynamic => {},
            },
            .Exe => {},
        }
        switch (base.tag) {
            .elf => if (base.file) |f| {
                if (build_options.only_c) unreachable;
                if (base.zcu_object_sub_path != null and use_lld) {
                    // The file we have open is not the final file that we want to
                    // make executable, so we don't have to close it.
                    return;
                }
                f.close();
                base.file = null;

                if (base.child_pid) |pid| {
                    switch (builtin.os.tag) {
                        .linux => std.posix.ptrace(std.os.linux.PTRACE.DETACH, pid, 0, 0) catch |err| {
                            log.warn("ptrace failure: {s}", .{@errorName(err)});
                        },
                        else => return error.HotSwapUnavailableOnHostOperatingSystem,
                    }
                }
            },
            .coff, .macho, .plan9, .wasm => if (base.file) |f| {
                if (build_options.only_c) unreachable;
                if (base.zcu_object_sub_path != null) {
                    // The file we have open is not the final file that we want to
                    // make executable, so we don't have to close it.
                    return;
                }
                f.close();
                base.file = null;

                if (base.child_pid) |pid| {
                    switch (builtin.os.tag) {
                        .macos => base.cast(MachO).?.ptraceDetach(pid) catch |err| {
                            log.warn("detaching failed with error: {s}", .{@errorName(err)});
                        },
                        .windows => base.cast(Coff).?.ptraceDetach(pid),
                        else => return error.HotSwapUnavailableOnHostOperatingSystem,
                    }
                }
            },
            .c, .spirv, .nvptx => {},
        }
    }

    pub const UpdateDeclError = error{
        OutOfMemory,
        Overflow,
        Underflow,
        FileTooBig,
        InputOutput,
        FilesOpenedWithWrongFlags,
        IsDir,
        NoSpaceLeft,
        Unseekable,
        PermissionDenied,
        SwapFile,
        CorruptedData,
        SystemResources,
        OperationAborted,
        BrokenPipe,
        ConnectionResetByPeer,
        ConnectionTimedOut,
        SocketNotConnected,
        NotOpenForReading,
        WouldBlock,
        AccessDenied,
        Unexpected,
        DiskQuota,
        NotOpenForWriting,
        AnalysisFail,
        CodegenFail,
        EmitFail,
        NameTooLong,
        CurrentWorkingDirectoryUnlinked,
        LockViolation,
        NetNameDeleted,
        DeviceBusy,
        InvalidArgument,
        HotSwapUnavailableOnHostOperatingSystem,
    };

    /// Called from within the CodeGen to lower a local variable instantion as an unnamed
    /// constant. Returns the symbol index of the lowered constant in the read-only section
    /// of the final binary.
    pub fn lowerUnnamedConst(base: *File, val: Value, decl_index: InternPool.DeclIndex) UpdateDeclError!u32 {
        if (build_options.only_c) @compileError("unreachable");
        switch (base.tag) {
            .spirv => unreachable,
            .c => unreachable,
            .nvptx => unreachable,
            inline else => |t| {
                return @as(*t.Type(), @fieldParentPtr("base", base)).lowerUnnamedConst(val, decl_index);
            },
        }
    }

    /// Called from within CodeGen to retrieve the symbol index of a global symbol.
    /// If no symbol exists yet with this name, a new undefined global symbol will
    /// be created. This symbol may get resolved once all relocatables are (re-)linked.
    /// Optionally, it is possible to specify where to expect the symbol defined if it
    /// is an import.
    pub fn getGlobalSymbol(base: *File, name: []const u8, lib_name: ?[]const u8) UpdateDeclError!u32 {
        if (build_options.only_c) @compileError("unreachable");
        log.debug("getGlobalSymbol '{s}' (expected in '{?s}')", .{ name, lib_name });
        switch (base.tag) {
            .plan9 => unreachable,
            .spirv => unreachable,
            .c => unreachable,
            .nvptx => unreachable,
            inline else => |t| {
                return @as(*t.Type(), @fieldParentPtr("base", base)).getGlobalSymbol(name, lib_name);
            },
        }
    }

    /// May be called before or after updateExports for any given Decl.
    pub fn updateDecl(base: *File, module: *Module, decl_index: InternPool.DeclIndex) UpdateDeclError!void {
        const decl = module.declPtr(decl_index);
        assert(decl.has_tv);
        switch (base.tag) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateDecl(module, decl_index);
            },
        }
    }

    /// May be called before or after updateExports for any given Decl.
    pub fn updateFunc(
        base: *File,
        module: *Module,
        func_index: InternPool.Index,
        air: Air,
        liveness: Liveness,
    ) UpdateDeclError!void {
        switch (base.tag) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateFunc(module, func_index, air, liveness);
            },
        }
    }

    pub fn updateDeclLineNumber(base: *File, module: *Module, decl_index: InternPool.DeclIndex) UpdateDeclError!void {
        const decl = module.declPtr(decl_index);
        assert(decl.has_tv);
        switch (base.tag) {
            .spirv, .nvptx => {},
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateDeclLineNumber(module, decl_index);
            },
        }
    }

    pub fn releaseLock(self: *File) void {
        if (self.lock) |*lock| {
            lock.release();
            self.lock = null;
        }
    }

    pub fn toOwnedLock(self: *File) Cache.Lock {
        const lock = self.lock.?;
        self.lock = null;
        return lock;
    }

    pub fn destroy(base: *File) void {
        base.releaseLock();
        if (base.file) |f| f.close();
        switch (base.tag) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                @as(*tag.Type(), @fieldParentPtr("base", base)).deinit();
            },
        }
    }

    /// TODO audit this error set. most of these should be collapsed into one error,
    /// and ErrorFlags should be updated to convey the meaning to the user.
    pub const FlushError = error{
        CacheUnavailable,
        CurrentWorkingDirectoryUnlinked,
        DivisionByZero,
        DllImportLibraryNotFound,
        ExpectedFuncType,
        FailedToEmit,
        FileSystem,
        FilesOpenedWithWrongFlags,
        FlushFailure,
        FunctionSignatureMismatch,
        GlobalTypeMismatch,
        HotSwapUnavailableOnHostOperatingSystem,
        InvalidCharacter,
        InvalidEntryKind,
        InvalidFeatureSet,
        InvalidFormat,
        InvalidIndex,
        InvalidInitFunc,
        InvalidMagicByte,
        InvalidWasmVersion,
        LLDCrashed,
        LLDReportedFailure,
        LLD_LinkingIsTODO_ForSpirV,
        LibCInstallationMissingCRTDir,
        LibCInstallationNotAvailable,
        LinkingWithoutZigSourceUnimplemented,
        MalformedArchive,
        MalformedDwarf,
        MalformedSection,
        MemoryTooBig,
        MemoryTooSmall,
        MissAlignment,
        MissingEndForBody,
        MissingEndForExpression,
        MissingSymbol,
        MissingTableSymbols,
        ModuleNameMismatch,
        NoObjectsToLink,
        NotObjectFile,
        NotSupported,
        OutOfMemory,
        Overflow,
        PermissionDenied,
        StreamTooLong,
        SwapFile,
        SymbolCollision,
        SymbolMismatchingType,
        TODOImplementPlan9Objs,
        TODOImplementWritingLibFiles,
        UnableToSpawnSelf,
        UnableToSpawnWasm,
        UnableToWriteArchive,
        UndefinedLocal,
        UndefinedSymbol,
        Underflow,
        UnexpectedRemainder,
        UnexpectedTable,
        UnexpectedValue,
        UnknownFeature,
        UnrecognizedVolume,
        Unseekable,
        UnsupportedCpuArchitecture,
        UnsupportedVersion,
    } ||
        fs.File.WriteFileError ||
        fs.File.OpenError ||
        std.process.Child.SpawnError ||
        fs.Dir.CopyFileError;

    /// Commit pending changes and write headers. Takes into account final output mode
    /// and `use_lld`, not only `effectiveOutputMode`.
    /// `arena` has the lifetime of the call to `Compilation.update`.
    pub fn flush(base: *File, arena: Allocator, prog_node: std.Progress.Node) FlushError!void {
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @as(*C, @fieldParentPtr("base", base)).flush(arena, prog_node);
        }
        const comp = base.comp;
        if (comp.clang_preprocessor_mode == .yes or comp.clang_preprocessor_mode == .pch) {
            const gpa = comp.gpa;
            const emit = base.emit;
            // TODO: avoid extra link step when it's just 1 object file (the `zig cc -c` case)
            // Until then, we do `lld -r -o output.o input.o` even though the output is the same
            // as the input. For the preprocessing case (`zig cc -E -o foo`) we copy the file
            // to the final location. See also the corresponding TODO in Coff linking.
            const full_out_path = try emit.directory.join(gpa, &[_][]const u8{emit.sub_path});
            defer gpa.free(full_out_path);
            assert(comp.c_object_table.count() == 1);
            const the_key = comp.c_object_table.keys()[0];
            const cached_pp_file_path = the_key.status.success.object_path;
            try fs.cwd().copyFile(cached_pp_file_path, fs.cwd(), full_out_path, .{});
            return;
        }

        const use_lld = build_options.have_llvm and comp.config.use_lld;
        const output_mode = comp.config.output_mode;
        const link_mode = comp.config.link_mode;
        if (use_lld and output_mode == .Lib and link_mode == .static) {
            return base.linkAsArchive(arena, prog_node);
        }
        switch (base.tag) {
            inline else => |tag| {
                return @as(*tag.Type(), @fieldParentPtr("base", base)).flush(arena, prog_node);
            },
        }
    }

    /// Commit pending changes and write headers. Works based on `effectiveOutputMode`
    /// rather than final output mode.
    pub fn flushModule(base: *File, arena: Allocator, prog_node: std.Progress.Node) FlushError!void {
        switch (base.tag) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                return @as(*tag.Type(), @fieldParentPtr("base", base)).flushModule(arena, prog_node);
            },
        }
    }

    /// Called when a Decl is deleted from the Module.
    pub fn freeDecl(base: *File, decl_index: InternPool.DeclIndex) void {
        switch (base.tag) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                @as(*tag.Type(), @fieldParentPtr("base", base)).freeDecl(decl_index);
            },
        }
    }

    pub const UpdateExportsError = error{
        OutOfMemory,
        AnalysisFail,
    };

    /// This is called for every exported thing. `exports` is almost always
    /// a list of size 1, meaning that `exported` is exported once. However, it is possible
    /// to export the same thing with multiple different symbol names (aliases).
    /// May be called before or after updateDecl for any given Decl.
    pub fn updateExports(
        base: *File,
        module: *Module,
        exported: Module.Exported,
        exports: []const *Module.Export,
    ) UpdateExportsError!void {
        switch (base.tag) {
            inline else => |tag| {
                if (tag != .c and build_options.only_c) unreachable;
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateExports(module, exported, exports);
            },
        }
    }

    pub const RelocInfo = struct {
        parent_atom_index: u32,
        offset: u64,
        addend: u32,
    };

    /// Get allocated `Decl`'s address in virtual memory.
    /// The linker is passed information about the containing atom, `parent_atom_index`, and offset within it's
    /// memory buffer, `offset`, so that it can make a note of potential relocation sites, should the
    /// `Decl`'s address was not yet resolved, or the containing atom gets moved in virtual memory.
    /// May be called before or after updateFunc/updateDecl therefore it is up to the linker to allocate
    /// the block/atom.
    pub fn getDeclVAddr(base: *File, decl_index: InternPool.DeclIndex, reloc_info: RelocInfo) !u64 {
        if (build_options.only_c) @compileError("unreachable");
        switch (base.tag) {
            .c => unreachable,
            .spirv => unreachable,
            .nvptx => unreachable,
            inline else => |tag| {
                return @as(*tag.Type(), @fieldParentPtr("base", base)).getDeclVAddr(decl_index, reloc_info);
            },
        }
    }

    pub const LowerResult = @import("codegen.zig").Result;

    pub fn lowerAnonDecl(
        base: *File,
        decl_val: InternPool.Index,
        decl_align: InternPool.Alignment,
        src_loc: Module.SrcLoc,
    ) !LowerResult {
        if (build_options.only_c) @compileError("unreachable");
        switch (base.tag) {
            .c => unreachable,
            .spirv => unreachable,
            .nvptx => unreachable,
            inline else => |tag| {
                return @as(*tag.Type(), @fieldParentPtr("base", base)).lowerAnonDecl(decl_val, decl_align, src_loc);
            },
        }
    }

    pub fn getAnonDeclVAddr(base: *File, decl_val: InternPool.Index, reloc_info: RelocInfo) !u64 {
        if (build_options.only_c) @compileError("unreachable");
        switch (base.tag) {
            .c => unreachable,
            .spirv => unreachable,
            .nvptx => unreachable,
            inline else => |tag| {
                return @as(*tag.Type(), @fieldParentPtr("base", base)).getAnonDeclVAddr(decl_val, reloc_info);
            },
        }
    }

    pub fn deleteDeclExport(
        base: *File,
        decl_index: InternPool.DeclIndex,
        name: InternPool.NullTerminatedString,
    ) !void {
        if (build_options.only_c) @compileError("unreachable");
        switch (base.tag) {
            .plan9,
            .c,
            .spirv,
            .nvptx,
            => {},

            inline else => |tag| {
                return @as(*tag.Type(), @fieldParentPtr("base", base)).deleteDeclExport(decl_index, name);
            },
        }
    }

    pub fn linkAsArchive(base: *File, arena: Allocator, prog_node: std.Progress.Node) FlushError!void {
        const tracy = trace(@src());
        defer tracy.end();

        const comp = base.comp;
        const gpa = comp.gpa;

        const directory = base.emit.directory; // Just an alias to make it shorter to type.
        const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});
        const full_out_path_z = try arena.dupeZ(u8, full_out_path);
        const opt_zcu = comp.module;

        // If there is no Zig code to compile, then we should skip flushing the output file
        // because it will not be part of the linker line anyway.
        const zcu_obj_path: ?[]const u8 = if (opt_zcu != null) blk: {
            try base.flushModule(arena, prog_node);

            const dirname = fs.path.dirname(full_out_path_z) orelse ".";
            break :blk try fs.path.join(arena, &.{ dirname, base.zcu_object_sub_path.? });
        } else null;

        log.debug("zcu_obj_path={s}", .{if (zcu_obj_path) |s| s else "(null)"});

        const compiler_rt_path: ?[]const u8 = if (comp.include_compiler_rt)
            comp.compiler_rt_obj.?.full_object_path
        else
            null;

        // This function follows the same pattern as link.Elf.linkWithLLD so if you want some
        // insight as to what's going on here you can read that function body which is more
        // well-commented.

        const id_symlink_basename = "llvm-ar.id";

        var man: Cache.Manifest = undefined;
        defer if (!base.disable_lld_caching) man.deinit();

        const objects = comp.objects;

        var digest: [Cache.hex_digest_len]u8 = undefined;

        if (!base.disable_lld_caching) {
            man = comp.cache_parent.obtain();

            // We are about to obtain this lock, so here we give other processes a chance first.
            base.releaseLock();

            for (objects) |obj| {
                _ = try man.addFile(obj.path, null);
                man.hash.add(obj.must_link);
                man.hash.add(obj.loption);
            }
            for (comp.c_object_table.keys()) |key| {
                _ = try man.addFile(key.status.success.object_path, null);
            }
            if (!build_options.only_core_functionality) {
                for (comp.win32_resource_table.keys()) |key| {
                    _ = try man.addFile(key.status.success.res_path, null);
                }
            }
            try man.addOptionalFile(zcu_obj_path);
            try man.addOptionalFile(compiler_rt_path);

            // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
            _ = try man.hit();
            digest = man.final();

            var prev_digest_buf: [digest.len]u8 = undefined;
            const prev_digest: []u8 = Cache.readSmallFile(
                directory.handle,
                id_symlink_basename,
                &prev_digest_buf,
            ) catch |err| b: {
                log.debug("archive new_digest={s} readFile error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
                break :b prev_digest_buf[0..0];
            };
            if (mem.eql(u8, prev_digest, &digest)) {
                log.debug("archive digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
                base.lock = man.toOwnedLock();
                return;
            }

            // We are about to change the output file to be different, so we invalidate the build hash now.
            directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
                error.FileNotFound => {},
                else => |e| return e,
            };
        }

        const win32_resource_table_len = if (build_options.only_core_functionality) 0 else comp.win32_resource_table.count();
        const num_object_files = objects.len + comp.c_object_table.count() + win32_resource_table_len + 2;
        var object_files = try std.ArrayList([*:0]const u8).initCapacity(gpa, num_object_files);
        defer object_files.deinit();

        for (objects) |obj| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, obj.path));
        }
        for (comp.c_object_table.keys()) |key| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, key.status.success.object_path));
        }
        if (!build_options.only_core_functionality) {
            for (comp.win32_resource_table.keys()) |key| {
                object_files.appendAssumeCapacity(try arena.dupeZ(u8, key.status.success.res_path));
            }
        }
        if (zcu_obj_path) |p| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, p));
        }
        if (compiler_rt_path) |p| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, p));
        }

        if (comp.verbose_link) {
            std.debug.print("ar rcs {s}", .{full_out_path_z});
            for (object_files.items) |arg| {
                std.debug.print(" {s}", .{arg});
            }
            std.debug.print("\n", .{});
        }

        const llvm_bindings = @import("codegen/llvm/bindings.zig");
        const llvm = @import("codegen/llvm.zig");
        const target = comp.root_mod.resolved_target.result;
        llvm.initializeLLVMTarget(target.cpu.arch);
        const os_tag = llvm.targetOs(target.os.tag);
        const bad = llvm_bindings.WriteArchive(full_out_path_z, object_files.items.ptr, object_files.items.len, os_tag);
        if (bad) return error.UnableToWriteArchive;

        if (!base.disable_lld_caching) {
            Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
                log.warn("failed to save archive hash digest file: {s}", .{@errorName(err)});
            };

            if (man.have_exclusive_lock) {
                man.writeManifest() catch |err| {
                    log.warn("failed to write cache manifest when archiving: {s}", .{@errorName(err)});
                };
            }

            base.lock = man.toOwnedLock();
        }
    }

    pub const Tag = enum {
        coff,
        elf,
        macho,
        c,
        wasm,
        spirv,
        plan9,
        nvptx,

        pub fn Type(comptime tag: Tag) type {
            return switch (tag) {
                .coff => Coff,
                .elf => Elf,
                .macho => MachO,
                .c => C,
                .wasm => Wasm,
                .spirv => SpirV,
                .plan9 => Plan9,
                .nvptx => NvPtx,
            };
        }

        pub fn fromObjectFormat(ofmt: std.Target.ObjectFormat) Tag {
            return switch (ofmt) {
                .coff => .coff,
                .elf => .elf,
                .macho => .macho,
                .wasm => .wasm,
                .plan9 => .plan9,
                .c => .c,
                .spirv => .spirv,
                .nvptx => .nvptx,
                .hex => @panic("TODO implement hex object format"),
                .raw => @panic("TODO implement raw object format"),
                .dxcontainer => @panic("TODO implement dxcontainer object format"),
            };
        }
    };

    pub const ErrorFlags = struct {
        no_entry_point_found: bool = false,
        missing_libc: bool = false,
    };

    pub const ErrorMsg = struct {
        msg: []const u8,
        notes: []ErrorMsg = &.{},

        pub fn deinit(self: *ErrorMsg, gpa: Allocator) void {
            for (self.notes) |*note| {
                note.deinit(gpa);
            }
            gpa.free(self.notes);
            gpa.free(self.msg);
        }
    };

    pub const LazySymbol = struct {
        pub const Kind = enum { code, const_data };

        kind: Kind,
        ty: Type,

        pub fn initDecl(kind: Kind, decl: ?InternPool.DeclIndex, mod: *Module) LazySymbol {
            return .{ .kind = kind, .ty = if (decl) |decl_index|
                mod.declPtr(decl_index).val.toType()
            else
                Type.anyerror };
        }

        pub fn getDecl(self: LazySymbol, mod: *Module) InternPool.OptionalDeclIndex {
            return InternPool.OptionalDeclIndex.init(self.ty.getOwnerDeclOrNull(mod));
        }
    };

    pub fn effectiveOutputMode(
        use_lld: bool,
        output_mode: std.builtin.OutputMode,
    ) std.builtin.OutputMode {
        return if (use_lld) .Obj else output_mode;
    }

    pub fn determineMode(
        use_lld: bool,
        output_mode: std.builtin.OutputMode,
        link_mode: std.builtin.LinkMode,
    ) fs.File.Mode {
        // On common systems with a 0o022 umask, 0o777 will still result in a file created
        // with 0o755 permissions, but it works appropriately if the system is configured
        // more leniently. As another data point, C's fopen seems to open files with the
        // 666 mode.
        const executable_mode = if (builtin.target.os.tag == .windows) 0 else 0o777;
        switch (effectiveOutputMode(use_lld, output_mode)) {
            .Lib => return switch (link_mode) {
                .dynamic => executable_mode,
                .static => fs.File.default_mode,
            },
            .Exe => return executable_mode,
            .Obj => return fs.File.default_mode,
        }
    }

    pub fn isStatic(self: File) bool {
        return self.comp.config.link_mode == .static;
    }

    pub fn isObject(self: File) bool {
        const output_mode = self.comp.config.output_mode;
        return output_mode == .Obj;
    }

    pub fn isExe(self: File) bool {
        const output_mode = self.comp.config.output_mode;
        return output_mode == .Exe;
    }

    pub fn isStaticLib(self: File) bool {
        const output_mode = self.comp.config.output_mode;
        return output_mode == .Lib and self.isStatic();
    }

    pub fn isRelocatable(self: File) bool {
        return self.isObject() or self.isStaticLib();
    }

    pub fn isDynLib(self: File) bool {
        const output_mode = self.comp.config.output_mode;
        return output_mode == .Lib and !self.isStatic();
    }

    pub fn emitLlvmObject(
        base: File,
        arena: Allocator,
        llvm_object: *LlvmObject,
        prog_node: std.Progress.Node,
    ) !void {
        return base.comp.emitLlvmObject(arena, base.emit, .{
            .directory = null,
            .basename = base.zcu_object_sub_path.?,
        }, llvm_object, prog_node);
    }

    pub const C = @import("link/C.zig");
    pub const Coff = @import("link/Coff.zig");
    pub const Plan9 = @import("link/Plan9.zig");
    pub const Elf = @import("link/Elf.zig");
    pub const MachO = @import("link/MachO.zig");
    pub const SpirV = @import("link/SpirV.zig");
    pub const Wasm = @import("link/Wasm.zig");
    pub const NvPtx = @import("link/NvPtx.zig");
    pub const Dwarf = @import("link/Dwarf.zig");
};

pub fn spawnLld(
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
        return error.LLDReportedFailure;
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
                const rsp_path = "tmp" ++ s ++ Package.Manifest.hex64(rand_int) ++ ".rsp";

                const rsp_file = try comp.local_cache_directory.handle.createFileZ(rsp_path, .{});
                defer comp.local_cache_directory.handle.deleteFileZ(rsp_path) catch |err|
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
                    .{try comp.local_cache_directory.join(arena, &.{rsp_path})},
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
        log.err("unable to spawn {s}: {s}", .{ argv[0], @errorName(err) });
        return error.UnableToSpawnSelf;
    };

    switch (term) {
        .Exited => |code| if (code != 0) {
            if (comp.clang_passthrough_mode) std.process.exit(code);
            comp.lockAndParseLldStderr(argv[1], stderr);
            return error.LLDReportedFailure;
        },
        else => {
            if (comp.clang_passthrough_mode) std.process.abort();
            log.err("{s} terminated with stderr:\n{s}", .{ argv[0], stderr });
            return error.LLDCrashed;
        },
    }

    if (stderr.len > 0) log.warn("unexpected LLD stderr:\n{s}", .{stderr});
}
