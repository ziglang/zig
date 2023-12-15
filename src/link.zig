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
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const Liveness = @import("Liveness.zig");
const Module = @import("Module.zig");
const InternPool = @import("InternPool.zig");
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");

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
    intermediary_basename: ?[]const u8 = null,
    disable_lld_caching: bool,
    gc_sections: bool,
    build_id: std.zig.BuildId,
    rpath_list: []const []const u8,
    /// List of symbols forced as undefined in the symbol table
    /// thus forcing their resolution by the linker.
    /// Corresponds to `-u <symbol>` for ELF/MachO and `/include:<symbol>` for COFF/PE.
    force_undefined_symbols: std.StringArrayHashMapUnmanaged(void),
    allow_shlib_undefined: bool,
    stack_size: u64,

    error_flags: ErrorFlags = .{},
    misc_errors: std.ArrayListUnmanaged(ErrorMsg) = .{},

    /// Prevents other processes from clobbering files in the output directory
    /// of this linking operation.
    lock: ?Cache.Lock = null,
    child_pid: ?std.ChildProcess.Id = null,

    pub const OpenOptions = struct {
        symbol_count_hint: u64 = 32,
        program_code_size_hint: u64 = 256 * 1024,

        /// Virtual address of the entry point procedure relative to image base.
        entry_addr: ?u64,
        stack_size: ?u64,
        image_base: ?u64,
        eh_frame_hdr: bool,
        emit_relocs: bool,
        rdynamic: bool,
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
        dll_export_fns: bool,
        each_lib_rpath: bool,
        build_id: std.zig.BuildId,
        disable_lld_caching: bool,
        hash_style: Elf.HashStyle,
        sort_section: ?Elf.SortSection,
        major_subsystem_version: ?u32,
        minor_subsystem_version: ?u32,
        gc_sections: ?bool,
        allow_shlib_undefined: ?bool,
        subsystem: ?std.Target.SubSystem,
        linker_script: ?[]const u8,
        version_script: ?[]const u8,
        soname: ?[]const u8,
        print_gc_sections: bool,
        print_icf_sections: bool,
        print_map: bool,

        force_undefined_symbols: std.StringArrayHashMapUnmanaged(void),
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
        rpath_list: []const []const u8,

        /// (Zig compiler development) Enable dumping of linker's state as JSON.
        enable_link_snapshots: bool,

        /// (Darwin) Install name for the dylib
        install_name: ?[]const u8,
        /// (Darwin) Path to entitlements file
        entitlements: ?[]const u8,
        /// (Darwin) size of the __PAGEZERO segment
        pagezero_size: ?u64,
        /// (Darwin) set minimum space for future expansion of the load commands
        headerpad_size: ?u32,
        /// (Darwin) set enough space as if all paths were MATPATHLEN
        headerpad_max_install_names: bool,
        /// (Darwin) remove dylibs that are unreachable by the entry point or exported symbols
        dead_strip_dylibs: bool,
        frameworks: []const MachO.Framework,
        darwin_sdk_layout: ?MachO.SdkLayout,

        /// (Windows) PDB source path prefix to instruct the linker how to resolve relative
        /// paths when consolidating CodeView streams into a single PDB file.
        pdb_source_path: ?[]const u8,
        /// (Windows) PDB output path
        pdb_out_path: ?[]const u8,
        /// (Windows) .def file to specify when linking
        module_definition_file: ?[]const u8,

        wasi_emulated_libs: []const wasi_libc.CRTFile,
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
                const ptr = try tag.Type().createEmpty(arena, comp, emit, options);
                return &ptr.base;
            },
        }
    }

    pub fn cast(base: *File, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
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
                            .linux => std.os.ptrace(std.os.linux.PTRACE.ATTACH, pid, 0, 0) catch |err| {
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
                .Static => return,
                .Dynamic => {},
            },
            .Exe => {},
        }
        switch (base.tag) {
            .elf => if (base.file) |f| {
                if (build_options.only_c) unreachable;
                if (base.intermediary_basename != null and use_lld) {
                    // The file we have open is not the final file that we want to
                    // make executable, so we don't have to close it.
                    return;
                }
                f.close();
                base.file = null;

                if (base.child_pid) |pid| {
                    switch (builtin.os.tag) {
                        .linux => std.os.ptrace(std.os.linux.PTRACE.DETACH, pid, 0, 0) catch |err| {
                            log.warn("ptrace failure: {s}", .{@errorName(err)});
                        },
                        else => return error.HotSwapUnavailableOnHostOperatingSystem,
                    }
                }
            },
            .coff, .macho, .plan9, .wasm => if (base.file) |f| {
                if (build_options.only_c) unreachable;
                if (base.intermediary_basename != null) {
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
    pub fn lowerUnnamedConst(base: *File, tv: TypedValue, decl_index: InternPool.DeclIndex) UpdateDeclError!u32 {
        if (build_options.only_c) @compileError("unreachable");
        switch (base.tag) {
            // zig fmt: off
            .coff  => return @fieldParentPtr(Coff,  "base", base).lowerUnnamedConst(tv, decl_index),
            .elf   => return @fieldParentPtr(Elf,   "base", base).lowerUnnamedConst(tv, decl_index),
            .macho => return @fieldParentPtr(MachO, "base", base).lowerUnnamedConst(tv, decl_index),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).lowerUnnamedConst(tv, decl_index),
            .spirv => unreachable,
            .c     => unreachable,
            .wasm  => return @fieldParentPtr(Wasm,  "base", base).lowerUnnamedConst(tv, decl_index),
            .nvptx => unreachable,
            // zig fmt: on
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
            // zig fmt: off
            .coff  => return @fieldParentPtr(Coff, "base", base).getGlobalSymbol(name, lib_name),
            .elf   => return @fieldParentPtr(Elf, "base", base).getGlobalSymbol(name, lib_name),
            .macho => return @fieldParentPtr(MachO, "base", base).getGlobalSymbol(name, lib_name),
            .plan9 => unreachable,
            .spirv => unreachable,
            .c     => unreachable,
            .wasm  => return @fieldParentPtr(Wasm,  "base", base).getGlobalSymbol(name, lib_name),
            .nvptx => unreachable,
            // zig fmt: on
        }
    }

    /// May be called before or after updateExports for any given Decl.
    pub fn updateDecl(base: *File, module: *Module, decl_index: InternPool.DeclIndex) UpdateDeclError!void {
        const decl = module.declPtr(decl_index);
        assert(decl.has_tv);
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).updateDecl(module, decl_index);
        }
        switch (base.tag) {
            // zig fmt: off
            .coff  => return @fieldParentPtr(Coff,  "base", base).updateDecl(module, decl_index),
            .elf   => return @fieldParentPtr(Elf,   "base", base).updateDecl(module, decl_index),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDecl(module, decl_index),
            .c     => return @fieldParentPtr(C,     "base", base).updateDecl(module, decl_index),
            .wasm  => return @fieldParentPtr(Wasm,  "base", base).updateDecl(module, decl_index),
            .spirv => return @fieldParentPtr(SpirV, "base", base).updateDecl(module, decl_index),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).updateDecl(module, decl_index),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).updateDecl(module, decl_index),
            // zig fmt: on
        }
    }

    /// May be called before or after updateExports for any given Decl.
    pub fn updateFunc(base: *File, module: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) UpdateDeclError!void {
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).updateFunc(module, func_index, air, liveness);
        }
        switch (base.tag) {
            // zig fmt: off
            .coff  => return @fieldParentPtr(Coff,  "base", base).updateFunc(module, func_index, air, liveness),
            .elf   => return @fieldParentPtr(Elf,   "base", base).updateFunc(module, func_index, air, liveness),
            .macho => return @fieldParentPtr(MachO, "base", base).updateFunc(module, func_index, air, liveness),
            .c     => return @fieldParentPtr(C,     "base", base).updateFunc(module, func_index, air, liveness),
            .wasm  => return @fieldParentPtr(Wasm,  "base", base).updateFunc(module, func_index, air, liveness),
            .spirv => return @fieldParentPtr(SpirV, "base", base).updateFunc(module, func_index, air, liveness),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).updateFunc(module, func_index, air, liveness),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).updateFunc(module, func_index, air, liveness),
            // zig fmt: on
        }
    }

    pub fn updateDeclLineNumber(base: *File, module: *Module, decl_index: InternPool.DeclIndex) UpdateDeclError!void {
        const decl = module.declPtr(decl_index);
        assert(decl.has_tv);
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).updateDeclLineNumber(module, decl_index);
        }
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateDeclLineNumber(module, decl_index),
            .elf => return @fieldParentPtr(Elf, "base", base).updateDeclLineNumber(module, decl_index),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDeclLineNumber(module, decl_index),
            .c => return @fieldParentPtr(C, "base", base).updateDeclLineNumber(module, decl_index),
            .wasm => return @fieldParentPtr(Wasm, "base", base).updateDeclLineNumber(module, decl_index),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).updateDeclLineNumber(module, decl_index),
            .spirv, .nvptx => {},
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
        const gpa = base.comp.gpa;
        base.releaseLock();
        if (base.file) |f| f.close();
        {
            for (base.misc_errors.items) |*item| item.deinit(gpa);
            base.misc_errors.deinit(gpa);
        }
        switch (base.tag) {
            .coff => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(Coff, "base", base);
                parent.deinit();
            },
            .elf => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(Elf, "base", base);
                parent.deinit();
            },
            .macho => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(MachO, "base", base);
                parent.deinit();
            },
            .c => {
                const parent = @fieldParentPtr(C, "base", base);
                parent.deinit();
            },
            .wasm => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(Wasm, "base", base);
                parent.deinit();
            },
            .spirv => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(SpirV, "base", base);
                parent.deinit();
            },
            .plan9 => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(Plan9, "base", base);
                parent.deinit();
            },
            .nvptx => {
                if (build_options.only_c) unreachable;
                const parent = @fieldParentPtr(NvPtx, "base", base);
                parent.deinit();
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
        Unseekable,
        UnsupportedCpuArchitecture,
        UnsupportedVersion,
    } ||
        fs.File.WriteFileError ||
        fs.File.OpenError ||
        std.ChildProcess.SpawnError ||
        fs.Dir.CopyFileError;

    /// Commit pending changes and write headers. Takes into account final output mode
    /// and `use_lld`, not only `effectiveOutputMode`.
    pub fn flush(base: *File, comp: *Compilation, prog_node: *std.Progress.Node) FlushError!void {
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).flush(comp, prog_node);
        }
        if (comp.clang_preprocessor_mode == .yes) {
            const emit = base.emit;
            // TODO: avoid extra link step when it's just 1 object file (the `zig cc -c` case)
            // Until then, we do `lld -r -o output.o input.o` even though the output is the same
            // as the input. For the preprocessing case (`zig cc -E -o foo`) we copy the file
            // to the final location. See also the corresponding TODO in Coff linking.
            const full_out_path = try emit.directory.join(comp.gpa, &[_][]const u8{emit.sub_path});
            defer comp.gpa.free(full_out_path);
            assert(comp.c_object_table.count() == 1);
            const the_key = comp.c_object_table.keys()[0];
            const cached_pp_file_path = the_key.status.success.object_path;
            try fs.cwd().copyFile(cached_pp_file_path, fs.cwd(), full_out_path, .{});
            return;
        }

        const use_lld = build_options.have_llvm and comp.config.use_lld;
        const output_mode = comp.config.output_mode;
        const link_mode = comp.config.link_mode;
        if (use_lld and output_mode == .Lib and link_mode == .Static) {
            return base.linkAsArchive(comp, prog_node);
        }
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).flush(comp, prog_node),
            .elf => return @fieldParentPtr(Elf, "base", base).flush(comp, prog_node),
            .macho => return @fieldParentPtr(MachO, "base", base).flush(comp, prog_node),
            .c => return @fieldParentPtr(C, "base", base).flush(comp, prog_node),
            .wasm => return @fieldParentPtr(Wasm, "base", base).flush(comp, prog_node),
            .spirv => return @fieldParentPtr(SpirV, "base", base).flush(comp, prog_node),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).flush(comp, prog_node),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).flush(comp, prog_node),
        }
    }

    /// Commit pending changes and write headers. Works based on `effectiveOutputMode`
    /// rather than final output mode.
    pub fn flushModule(base: *File, comp: *Compilation, prog_node: *std.Progress.Node) FlushError!void {
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).flushModule(comp, prog_node);
        }
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).flushModule(comp, prog_node),
            .elf => return @fieldParentPtr(Elf, "base", base).flushModule(comp, prog_node),
            .macho => return @fieldParentPtr(MachO, "base", base).flushModule(comp, prog_node),
            .c => return @fieldParentPtr(C, "base", base).flushModule(comp, prog_node),
            .wasm => return @fieldParentPtr(Wasm, "base", base).flushModule(comp, prog_node),
            .spirv => return @fieldParentPtr(SpirV, "base", base).flushModule(comp, prog_node),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).flushModule(comp, prog_node),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).flushModule(comp, prog_node),
        }
    }

    /// Called when a Decl is deleted from the Module.
    pub fn freeDecl(base: *File, decl_index: InternPool.DeclIndex) void {
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).freeDecl(decl_index);
        }
        switch (base.tag) {
            .coff => @fieldParentPtr(Coff, "base", base).freeDecl(decl_index),
            .elf => @fieldParentPtr(Elf, "base", base).freeDecl(decl_index),
            .macho => @fieldParentPtr(MachO, "base", base).freeDecl(decl_index),
            .c => @fieldParentPtr(C, "base", base).freeDecl(decl_index),
            .wasm => @fieldParentPtr(Wasm, "base", base).freeDecl(decl_index),
            .spirv => @fieldParentPtr(SpirV, "base", base).freeDecl(decl_index),
            .plan9 => @fieldParentPtr(Plan9, "base", base).freeDecl(decl_index),
            .nvptx => @fieldParentPtr(NvPtx, "base", base).freeDecl(decl_index),
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
        if (build_options.only_c) {
            assert(base.tag == .c);
            return @fieldParentPtr(C, "base", base).updateExports(module, exported, exports);
        }
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateExports(module, exported, exports),
            .elf => return @fieldParentPtr(Elf, "base", base).updateExports(module, exported, exports),
            .macho => return @fieldParentPtr(MachO, "base", base).updateExports(module, exported, exports),
            .c => return @fieldParentPtr(C, "base", base).updateExports(module, exported, exports),
            .wasm => return @fieldParentPtr(Wasm, "base", base).updateExports(module, exported, exports),
            .spirv => return @fieldParentPtr(SpirV, "base", base).updateExports(module, exported, exports),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).updateExports(module, exported, exports),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).updateExports(module, exported, exports),
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
        if (build_options.only_c) unreachable;
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).getDeclVAddr(decl_index, reloc_info),
            .elf => return @fieldParentPtr(Elf, "base", base).getDeclVAddr(decl_index, reloc_info),
            .macho => return @fieldParentPtr(MachO, "base", base).getDeclVAddr(decl_index, reloc_info),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).getDeclVAddr(decl_index, reloc_info),
            .c => unreachable,
            .wasm => return @fieldParentPtr(Wasm, "base", base).getDeclVAddr(decl_index, reloc_info),
            .spirv => unreachable,
            .nvptx => unreachable,
        }
    }

    pub const LowerResult = @import("codegen.zig").Result;

    pub fn lowerAnonDecl(base: *File, decl_val: InternPool.Index, decl_align: InternPool.Alignment, src_loc: Module.SrcLoc) !LowerResult {
        if (build_options.only_c) unreachable;
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).lowerAnonDecl(decl_val, decl_align, src_loc),
            .elf => return @fieldParentPtr(Elf, "base", base).lowerAnonDecl(decl_val, decl_align, src_loc),
            .macho => return @fieldParentPtr(MachO, "base", base).lowerAnonDecl(decl_val, decl_align, src_loc),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).lowerAnonDecl(decl_val, src_loc),
            .c => unreachable,
            .wasm => return @fieldParentPtr(Wasm, "base", base).lowerAnonDecl(decl_val, decl_align, src_loc),
            .spirv => unreachable,
            .nvptx => unreachable,
        }
    }

    pub fn getAnonDeclVAddr(base: *File, decl_val: InternPool.Index, reloc_info: RelocInfo) !u64 {
        if (build_options.only_c) unreachable;
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).getAnonDeclVAddr(decl_val, reloc_info),
            .elf => return @fieldParentPtr(Elf, "base", base).getAnonDeclVAddr(decl_val, reloc_info),
            .macho => return @fieldParentPtr(MachO, "base", base).getAnonDeclVAddr(decl_val, reloc_info),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).getAnonDeclVAddr(decl_val, reloc_info),
            .c => unreachable,
            .wasm => return @fieldParentPtr(Wasm, "base", base).getAnonDeclVAddr(decl_val, reloc_info),
            .spirv => unreachable,
            .nvptx => unreachable,
        }
    }

    pub fn deleteDeclExport(base: *File, decl_index: InternPool.DeclIndex, name: InternPool.NullTerminatedString) !void {
        if (build_options.only_c) unreachable;
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).deleteDeclExport(decl_index, name),
            .elf => return @fieldParentPtr(Elf, "base", base).deleteDeclExport(decl_index, name),
            .macho => return @fieldParentPtr(MachO, "base", base).deleteDeclExport(decl_index, name),
            .plan9 => {},
            .c => {},
            .wasm => return @fieldParentPtr(Wasm, "base", base).deleteDeclExport(decl_index),
            .spirv => {},
            .nvptx => {},
        }
    }

    pub fn linkAsArchive(base: *File, comp: *Compilation, prog_node: *std.Progress.Node) FlushError!void {
        const tracy = trace(@src());
        defer tracy.end();

        const gpa = comp.gpa;
        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const directory = base.emit.directory; // Just an alias to make it shorter to type.
        const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});
        const full_out_path_z = try arena.dupeZ(u8, full_out_path);
        const opt_zcu = comp.module;

        // If there is no Zig code to compile, then we should skip flushing the output file
        // because it will not be part of the linker line anyway.
        const zcu_obj_path: ?[]const u8 = if (opt_zcu != null) blk: {
            try base.flushModule(comp, prog_node);

            const dirname = fs.path.dirname(full_out_path_z) orelse ".";
            break :blk try fs.path.join(arena, &.{ dirname, base.intermediary_basename.? });
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
        const Builder = @import("codegen/llvm/Builder.zig");
        const llvm = @import("codegen/llvm.zig");
        const target = comp.root_mod.resolved_target.result;
        Builder.initializeLLVMTarget(target.cpu.arch);
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
                .Dynamic => executable_mode,
                .Static => fs.File.default_mode,
            },
            .Exe => return executable_mode,
            .Obj => return fs.File.default_mode,
        }
    }

    pub fn isStatic(self: File) bool {
        return self.comp.config.link_mode == .Static;
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
