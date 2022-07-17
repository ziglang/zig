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
const Cache = @import("Cache.zig");
const Compilation = @import("Compilation.zig");
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const Liveness = @import("Liveness.zig");
const Module = @import("Module.zig");
const Package = @import("Package.zig");
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");

/// When adding a new field, remember to update `hashAddSystemLibs`.
pub const SystemLib = struct {
    needed: bool = false,
    weak: bool = false,
};

pub const CacheMode = enum { incremental, whole };

pub fn hashAddSystemLibs(
    hh: *Cache.HashHelper,
    hm: std.StringArrayHashMapUnmanaged(SystemLib),
) void {
    const keys = hm.keys();
    hh.add(keys.len);
    hh.addListOfBytes(keys);
    for (hm.values()) |value| {
        hh.add(value.needed);
        hh.add(value.weak);
    }
}

pub const producer_string = if (builtin.is_test) "zig test" else "zig " ++ build_options.version;

pub const Emit = struct {
    /// Where the output will go.
    directory: Compilation.Directory,
    /// Path to the output file, relative to `directory`.
    sub_path: []const u8,

    /// Returns the full path to `basename` if it were in the same directory as the
    /// `Emit` sub_path.
    pub fn basenamePath(emit: Emit, arena: Allocator, basename: [:0]const u8) ![:0]const u8 {
        const full_path = if (emit.directory.path) |p|
            try fs.path.join(arena, &[_][]const u8{ p, emit.sub_path })
        else
            emit.sub_path;

        if (fs.path.dirname(full_path)) |dirname| {
            return try fs.path.joinZ(arena, &.{ dirname, basename });
        } else {
            return basename;
        }
    }
};

pub const Options = struct {
    /// This is `null` when `-fno-emit-bin` is used.
    emit: ?Emit,
    /// This is `null` not building a Windows DLL, or when `-fno-emit-implib` is used.
    implib_emit: ?Emit,
    target: std.Target,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    object_format: std.Target.ObjectFormat,
    optimize_mode: std.builtin.Mode,
    machine_code_model: std.builtin.CodeModel,
    root_name: [:0]const u8,
    /// Not every Compilation compiles .zig code! For example you could do `zig build-exe foo.o`.
    module: ?*Module,
    dynamic_linker: ?[]const u8,
    /// The root path for the dynamic linker and system libraries (as well as frameworks on Darwin)
    sysroot: ?[]const u8,
    /// Used for calculating how much space to reserve for symbols in case the binary file
    /// does not already have a symbol table.
    symbol_count_hint: u64 = 32,
    /// Used for calculating how much space to reserve for executable program code in case
    /// the binary file does not already have such a section.
    program_code_size_hint: u64 = 256 * 1024,
    entry_addr: ?u64 = null,
    entry: ?[]const u8,
    stack_size_override: ?u64,
    image_base_override: ?u64,
    cache_mode: CacheMode,
    include_compiler_rt: bool,
    /// Set to `true` to omit debug info.
    strip: bool,
    /// If this is true then this link code is responsible for outputting an object
    /// file and then using LLD to link it together with the link options and other objects.
    /// Otherwise (depending on `use_llvm`) this link code directly outputs and updates the final binary.
    use_lld: bool,
    /// If this is true then this link code is responsible for making an LLVM IR Module,
    /// outputting it to an object file, and then linking that together with link options and
    /// other objects.
    /// Otherwise (depending on `use_lld`) this link code directly outputs and updates the final binary.
    use_llvm: bool,
    link_libc: bool,
    link_libcpp: bool,
    link_libunwind: bool,
    function_sections: bool,
    no_builtin: bool,
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
    tsaware: bool,
    nxcompat: bool,
    dynamicbase: bool,
    linker_optimization: u8,
    compress_debug_sections: CompressDebugSections,
    bind_global_refs_locally: bool,
    import_memory: bool,
    import_table: bool,
    export_table: bool,
    initial_memory: ?u64,
    max_memory: ?u64,
    shared_memory: bool,
    export_symbol_names: []const []const u8,
    global_base: ?u64,
    is_native_os: bool,
    is_native_abi: bool,
    pic: bool,
    pie: bool,
    lto: bool,
    valgrind: bool,
    tsan: bool,
    stack_check: bool,
    red_zone: bool,
    omit_frame_pointer: bool,
    single_threaded: bool,
    verbose_link: bool,
    dll_export_fns: bool,
    error_return_tracing: bool,
    skip_linker_dependencies: bool,
    parent_compilation_link_libc: bool,
    each_lib_rpath: bool,
    build_id: bool,
    disable_lld_caching: bool,
    is_test: bool,
    use_stage1: bool,
    hash_style: HashStyle,
    major_subsystem_version: ?u32,
    minor_subsystem_version: ?u32,
    gc_sections: ?bool = null,
    allow_shlib_undefined: ?bool,
    subsystem: ?std.Target.SubSystem,
    linker_script: ?[]const u8,
    version_script: ?[]const u8,
    soname: ?[]const u8,
    llvm_cpu_features: ?[*:0]const u8,

    objects: []Compilation.LinkObject,
    framework_dirs: []const []const u8,
    frameworks: std.StringArrayHashMapUnmanaged(SystemLib),
    system_libs: std.StringArrayHashMapUnmanaged(SystemLib),
    wasi_emulated_libs: []const wasi_libc.CRTFile,
    lib_dirs: []const []const u8,
    rpath_list: []const []const u8,

    version: ?std.builtin.Version,
    compatibility_version: ?std.builtin.Version,
    libc_installation: ?*const LibCInstallation,

    /// WASI-only. Type of WASI execution model ("command" or "reactor").
    wasi_exec_model: std.builtin.WasiExecModel = undefined,

    /// (Zig compiler development) Enable dumping of linker's state as JSON.
    enable_link_snapshots: bool = false,

    /// (Darwin) Path and version of the native SDK if detected.
    native_darwin_sdk: ?std.zig.system.darwin.DarwinSDK = null,

    /// (Darwin) Install name for the dylib
    install_name: ?[]const u8 = null,

    /// (Darwin) Path to entitlements file
    entitlements: ?[]const u8 = null,

    /// (Darwin) size of the __PAGEZERO segment
    pagezero_size: ?u64 = null,

    /// (Darwin) search strategy for system libraries
    search_strategy: ?File.MachO.SearchStrategy = null,

    /// (Darwin) set minimum space for future expansion of the load commands
    headerpad_size: ?u32 = null,

    /// (Darwin) set enough space as if all paths were MATPATHLEN
    headerpad_max_install_names: bool = false,

    /// (Darwin) remove dylibs that are unreachable by the entry point or exported symbols
    dead_strip_dylibs: bool = false,

    pub fn effectiveOutputMode(options: Options) std.builtin.OutputMode {
        return if (options.use_lld) .Obj else options.output_mode;
    }

    pub fn move(self: *Options) Options {
        const copied_state = self.*;
        self.system_libs = .{};
        return copied_state;
    }
};

pub const HashStyle = enum { sysv, gnu, both };

pub const CompressDebugSections = enum { none, zlib };

pub const File = struct {
    tag: Tag,
    options: Options,
    file: ?fs.File,
    allocator: Allocator,
    /// When linking with LLD, this linker code will output an object file only at
    /// this location, and then this path can be placed on the LLD linker line.
    intermediary_basename: ?[]const u8 = null,

    /// Prevents other processes from clobbering files in the output directory
    /// of this linking operation.
    lock: ?Cache.Lock = null,

    pub const LinkBlock = union {
        elf: Elf.TextBlock,
        coff: Coff.TextBlock,
        macho: MachO.TextBlock,
        plan9: Plan9.DeclBlock,
        c: void,
        wasm: Wasm.DeclBlock,
        spirv: void,
        nvptx: void,
    };

    pub const LinkFn = union {
        elf: Dwarf.SrcFn,
        coff: Coff.SrcFn,
        macho: Dwarf.SrcFn,
        plan9: void,
        c: void,
        wasm: Wasm.FnData,
        spirv: SpirV.FnData,
        nvptx: void,
    };

    pub const Export = union {
        elf: Elf.Export,
        coff: void,
        macho: MachO.Export,
        plan9: Plan9.Export,
        c: void,
        wasm: Wasm.Export,
        spirv: void,
        nvptx: void,
    };

    /// Attempts incremental linking, if the file already exists. If
    /// incremental linking fails, falls back to truncating the file and
    /// rewriting it. A malicious file is detected as incremental link failure
    /// and does not cause Illegal Behavior. This operation is not atomic.
    pub fn openPath(allocator: Allocator, options: Options) !*File {
        if (options.object_format == .macho) {
            return &(try MachO.openPath(allocator, options)).base;
        }

        const use_stage1 = build_options.is_stage1 and options.use_stage1;
        if (use_stage1 or options.emit == null) {
            return switch (options.object_format) {
                .coff => &(try Coff.createEmpty(allocator, options)).base,
                .elf => &(try Elf.createEmpty(allocator, options)).base,
                .macho => unreachable,
                .wasm => &(try Wasm.createEmpty(allocator, options)).base,
                .plan9 => return &(try Plan9.createEmpty(allocator, options)).base,
                .c => unreachable, // Reported error earlier.
                .spirv => &(try SpirV.createEmpty(allocator, options)).base,
                .nvptx => &(try NvPtx.createEmpty(allocator, options)).base,
                .hex => return error.HexObjectFormatUnimplemented,
                .raw => return error.RawObjectFormatUnimplemented,
            };
        }
        const emit = options.emit.?;
        const use_lld = build_options.have_llvm and options.use_lld; // comptime known false when !have_llvm
        const sub_path = if (use_lld) blk: {
            if (options.module == null) {
                // No point in opening a file, we would not write anything to it.
                // Initialize with empty.
                return switch (options.object_format) {
                    .coff => &(try Coff.createEmpty(allocator, options)).base,
                    .elf => &(try Elf.createEmpty(allocator, options)).base,
                    .macho => unreachable,
                    .plan9 => &(try Plan9.createEmpty(allocator, options)).base,
                    .wasm => &(try Wasm.createEmpty(allocator, options)).base,
                    .c => unreachable, // Reported error earlier.
                    .spirv => &(try SpirV.createEmpty(allocator, options)).base,
                    .nvptx => &(try NvPtx.createEmpty(allocator, options)).base,
                    .hex => return error.HexObjectFormatUnimplemented,
                    .raw => return error.RawObjectFormatUnimplemented,
                };
            }
            // Open a temporary object file, not the final output file because we
            // want to link with LLD.
            break :blk try std.fmt.allocPrint(allocator, "{s}{s}", .{
                emit.sub_path, options.object_format.fileExt(options.target.cpu.arch),
            });
        } else emit.sub_path;
        errdefer if (use_lld) allocator.free(sub_path);

        const file: *File = switch (options.object_format) {
            .coff => &(try Coff.openPath(allocator, sub_path, options)).base,
            .elf => &(try Elf.openPath(allocator, sub_path, options)).base,
            .macho => unreachable,
            .plan9 => &(try Plan9.openPath(allocator, sub_path, options)).base,
            .wasm => &(try Wasm.openPath(allocator, sub_path, options)).base,
            .c => &(try C.openPath(allocator, sub_path, options)).base,
            .spirv => &(try SpirV.openPath(allocator, sub_path, options)).base,
            .nvptx => &(try NvPtx.openPath(allocator, sub_path, options)).base,
            .hex => return error.HexObjectFormatUnimplemented,
            .raw => return error.RawObjectFormatUnimplemented,
        };

        if (use_lld) {
            // TODO this intermediary_basename isn't enough; in the case of `zig build-exe`,
            // we also want to put the intermediary object file in the cache while the
            // main emit directory is the cwd.
            file.intermediary_basename = sub_path;
        }

        return file;
    }

    pub fn cast(base: *File, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub fn makeWritable(base: *File) !void {
        switch (base.tag) {
            .coff, .elf, .macho, .plan9, .wasm => {
                if (base.file != null) return;
                const emit = base.options.emit orelse return;
                base.file = try emit.directory.handle.createFile(emit.sub_path, .{
                    .truncate = false,
                    .read = true,
                    .mode = determineMode(base.options),
                });
            },
            .c, .spirv, .nvptx => {},
        }
    }

    pub fn makeExecutable(base: *File) !void {
        switch (base.options.output_mode) {
            .Obj => return,
            .Lib => switch (base.options.link_mode) {
                .Static => return,
                .Dynamic => {},
            },
            .Exe => {},
        }
        switch (base.tag) {
            .macho => if (base.file) |f| {
                if (comptime builtin.target.isDarwin() and builtin.target.cpu.arch == .aarch64) {
                    if (base.options.target.cpu.arch == .aarch64) {
                        // XNU starting with Big Sur running on arm64 is caching inodes of running binaries.
                        // Any change to the binary will effectively invalidate the kernel's cache
                        // resulting in a SIGKILL on each subsequent run. Since when doing incremental
                        // linking we're modifying a binary in-place, this will end up with the kernel
                        // killing it on every subsequent run. To circumvent it, we will copy the file
                        // into a new inode, remove the original file, and rename the copy to match
                        // the original file. This is super messy, but there doesn't seem any other
                        // way to please the XNU.
                        const emit = base.options.emit orelse return;
                        try emit.directory.handle.copyFile(emit.sub_path, emit.directory.handle, emit.sub_path, .{});
                    }
                }
                if (base.intermediary_basename == null) {
                    f.close();
                    base.file = null;
                }
            },
            .coff, .elf, .plan9, .wasm => if (base.file) |f| {
                if (base.intermediary_basename != null) {
                    // The file we have open is not the final file that we want to
                    // make executable, so we don't have to close it.
                    return;
                }
                f.close();
                base.file = null;
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
        FileBusy,
        SystemResources,
        OperationAborted,
        BrokenPipe,
        ConnectionResetByPeer,
        ConnectionTimedOut,
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
    };

    /// Called from within the CodeGen to lower a local variable instantion as an unnamed
    /// constant. Returns the symbol index of the lowered constant in the read-only section
    /// of the final binary.
    pub fn lowerUnnamedConst(base: *File, tv: TypedValue, decl_index: Module.Decl.Index) UpdateDeclError!u32 {
        const decl = base.options.module.?.declPtr(decl_index);
        log.debug("lowerUnnamedConst {*} ({s})", .{ decl, decl.name });
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
    pub fn getGlobalSymbol(base: *File, name: []const u8) UpdateDeclError!u32 {
        log.debug("getGlobalSymbol '{s}'", .{name});
        switch (base.tag) {
            // zig fmt: off
            .coff  => unreachable,
            .elf   => unreachable,
            .macho => return @fieldParentPtr(MachO, "base", base).getGlobalSymbol(name),
            .plan9 => unreachable,
            .spirv => unreachable,
            .c     => unreachable,
            .wasm  => return @fieldParentPtr(Wasm,  "base", base).getGlobalSymbol(name),
            .nvptx => unreachable,
            // zig fmt: on
        }
    }

    /// May be called before or after updateDeclExports but must be called
    /// after allocateDeclIndexes for any given Decl.
    pub fn updateDecl(base: *File, module: *Module, decl_index: Module.Decl.Index) UpdateDeclError!void {
        const decl = module.declPtr(decl_index);
        log.debug("updateDecl {*} ({s}), type={}", .{ decl, decl.name, decl.ty.fmtDebug() });
        assert(decl.has_tv);
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

    /// May be called before or after updateDeclExports but must be called
    /// after allocateDeclIndexes for any given Decl.
    pub fn updateFunc(base: *File, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) UpdateDeclError!void {
        const owner_decl = module.declPtr(func.owner_decl);
        log.debug("updateFunc {*} ({s}), type={}", .{
            owner_decl, owner_decl.name, owner_decl.ty.fmtDebug(),
        });
        switch (base.tag) {
            // zig fmt: off
            .coff  => return @fieldParentPtr(Coff,  "base", base).updateFunc(module, func, air, liveness),
            .elf   => return @fieldParentPtr(Elf,   "base", base).updateFunc(module, func, air, liveness),
            .macho => return @fieldParentPtr(MachO, "base", base).updateFunc(module, func, air, liveness),
            .c     => return @fieldParentPtr(C,     "base", base).updateFunc(module, func, air, liveness),
            .wasm  => return @fieldParentPtr(Wasm,  "base", base).updateFunc(module, func, air, liveness),
            .spirv => return @fieldParentPtr(SpirV, "base", base).updateFunc(module, func, air, liveness),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).updateFunc(module, func, air, liveness),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).updateFunc(module, func, air, liveness),
            // zig fmt: on
        }
    }

    pub fn updateDeclLineNumber(base: *File, module: *Module, decl: *Module.Decl) UpdateDeclError!void {
        log.debug("updateDeclLineNumber {*} ({s}), line={}", .{
            decl, decl.name, decl.src_line + 1,
        });
        assert(decl.has_tv);
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateDeclLineNumber(module, decl),
            .elf => return @fieldParentPtr(Elf, "base", base).updateDeclLineNumber(module, decl),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDeclLineNumber(module, decl),
            .c => return @fieldParentPtr(C, "base", base).updateDeclLineNumber(module, decl),
            .wasm => return @fieldParentPtr(Wasm, "base", base).updateDeclLineNumber(module, decl),
            .plan9 => @panic("TODO: implement updateDeclLineNumber for plan9"),
            .spirv, .nvptx => {},
        }
    }

    /// Must be called before any call to updateDecl or updateDeclExports for
    /// any given Decl.
    /// TODO we're transitioning to deleting this function and instead having
    /// each linker backend notice the first time updateDecl or updateFunc is called, or
    /// a callee referenced from AIR.
    pub fn allocateDeclIndexes(base: *File, decl_index: Module.Decl.Index) error{OutOfMemory}!void {
        const decl = base.options.module.?.declPtr(decl_index);
        log.debug("allocateDeclIndexes {*} ({s})", .{ decl, decl.name });
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).allocateDeclIndexes(decl_index),
            .elf => return @fieldParentPtr(Elf, "base", base).allocateDeclIndexes(decl_index),
            .macho => return @fieldParentPtr(MachO, "base", base).allocateDeclIndexes(decl_index) catch |err| switch (err) {
                // remap this error code because we are transitioning away from
                // `allocateDeclIndexes`.
                error.Overflow => return error.OutOfMemory,
                error.OutOfMemory => return error.OutOfMemory,
            },
            .wasm => return @fieldParentPtr(Wasm, "base", base).allocateDeclIndexes(decl_index),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).allocateDeclIndexes(decl_index),
            .c, .spirv, .nvptx => {},
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
        if (base.intermediary_basename) |sub_path| base.allocator.free(sub_path);
        base.options.system_libs.deinit(base.allocator);
        switch (base.tag) {
            .coff => {
                const parent = @fieldParentPtr(Coff, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .elf => {
                const parent = @fieldParentPtr(Elf, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .macho => {
                const parent = @fieldParentPtr(MachO, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .c => {
                const parent = @fieldParentPtr(C, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .wasm => {
                const parent = @fieldParentPtr(Wasm, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .spirv => {
                const parent = @fieldParentPtr(SpirV, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .plan9 => {
                const parent = @fieldParentPtr(Plan9, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .nvptx => {
                const parent = @fieldParentPtr(NvPtx, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
        }
    }

    /// Commit pending changes and write headers. Takes into account final output mode
    /// and `use_lld`, not only `effectiveOutputMode`.
    pub fn flush(base: *File, comp: *Compilation, prog_node: *std.Progress.Node) !void {
        if (comp.clang_preprocessor_mode == .yes) {
            const emit = base.options.emit orelse return; // -fno-emit-bin
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

        const use_lld = build_options.have_llvm and base.options.use_lld;
        if (use_lld and base.options.output_mode == .Lib and base.options.link_mode == .Static) {
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
    pub fn flushModule(base: *File, comp: *Compilation, prog_node: *std.Progress.Node) !void {
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
    pub fn freeDecl(base: *File, decl_index: Module.Decl.Index) void {
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

    pub fn errorFlags(base: *File) ErrorFlags {
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).error_flags,
            .elf => return @fieldParentPtr(Elf, "base", base).error_flags,
            .macho => return @fieldParentPtr(MachO, "base", base).error_flags,
            .plan9 => return @fieldParentPtr(Plan9, "base", base).error_flags,
            .c => return .{ .no_entry_point_found = false },
            .wasm, .spirv, .nvptx => return ErrorFlags{},
        }
    }

    pub const UpdateDeclExportsError = error{
        OutOfMemory,
        AnalysisFail,
    };

    /// May be called before or after updateDecl, but must be called after
    /// allocateDeclIndexes for any given Decl.
    pub fn updateDeclExports(
        base: *File,
        module: *Module,
        decl_index: Module.Decl.Index,
        exports: []const *Module.Export,
    ) UpdateDeclExportsError!void {
        const decl = module.declPtr(decl_index);
        log.debug("updateDeclExports {*} ({s})", .{ decl, decl.name });
        assert(decl.has_tv);
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateDeclExports(module, decl_index, exports),
            .elf => return @fieldParentPtr(Elf, "base", base).updateDeclExports(module, decl_index, exports),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDeclExports(module, decl_index, exports),
            .c => return @fieldParentPtr(C, "base", base).updateDeclExports(module, decl_index, exports),
            .wasm => return @fieldParentPtr(Wasm, "base", base).updateDeclExports(module, decl_index, exports),
            .spirv => return @fieldParentPtr(SpirV, "base", base).updateDeclExports(module, decl_index, exports),
            .plan9 => return @fieldParentPtr(Plan9, "base", base).updateDeclExports(module, decl_index, exports),
            .nvptx => return @fieldParentPtr(NvPtx, "base", base).updateDeclExports(module, decl_index, exports),
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
    pub fn getDeclVAddr(base: *File, decl_index: Module.Decl.Index, reloc_info: RelocInfo) !u64 {
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

    /// This function is called by the frontend before flush(). It communicates that
    /// `options.bin_file.emit` directory needs to be renamed from
    /// `[zig-cache]/tmp/[random]` to `[zig-cache]/o/[digest]`.
    /// The frontend would like to simply perform a file system rename, however,
    /// some linker backends care about the file paths of the objects they are linking.
    /// So this function call tells linker backends to rename the paths of object files
    /// to observe the new directory path.
    /// Linker backends which do not have this requirement can fall back to the simple
    /// implementation at the bottom of this function.
    /// This function is only called when CacheMode is `whole`.
    pub fn renameTmpIntoCache(
        base: *File,
        cache_directory: Compilation.Directory,
        tmp_dir_sub_path: []const u8,
        o_sub_path: []const u8,
    ) !void {
        // So far, none of the linker backends need to respond to this event, however,
        // it makes sense that they might want to. So we leave this mechanism here
        // for now. Once the linker backends get more mature, if it turns out this
        // is not needed we can refactor this into having the frontend do the rename
        // directly, and remove this function from link.zig.
        _ = base;
        while (true) {
            if (builtin.os.tag == .windows) {
                // workaround windows `renameW` can't fail with `PathAlreadyExists`
                // See https://github.com/ziglang/zig/issues/8362
                if (cache_directory.handle.access(o_sub_path, .{})) |_| {
                    try cache_directory.handle.deleteTree(o_sub_path);
                    continue;
                } else |err| switch (err) {
                    error.FileNotFound => {},
                    else => |e| return e,
                }
                try std.fs.rename(
                    cache_directory.handle,
                    tmp_dir_sub_path,
                    cache_directory.handle,
                    o_sub_path,
                );
                break;
            } else {
                std.fs.rename(
                    cache_directory.handle,
                    tmp_dir_sub_path,
                    cache_directory.handle,
                    o_sub_path,
                ) catch |err| switch (err) {
                    error.PathAlreadyExists => {
                        try cache_directory.handle.deleteTree(o_sub_path);
                        continue;
                    },
                    else => |e| return e,
                };
                break;
            }
        }
    }

    pub fn linkAsArchive(base: *File, comp: *Compilation, prog_node: *std.Progress.Node) !void {
        const tracy = trace(@src());
        defer tracy.end();

        var arena_allocator = std.heap.ArenaAllocator.init(base.allocator);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        const directory = base.options.emit.?.directory; // Just an alias to make it shorter to type.
        const full_out_path = try directory.join(arena, &[_][]const u8{base.options.emit.?.sub_path});
        const full_out_path_z = try arena.dupeZ(u8, full_out_path);

        // If there is no Zig code to compile, then we should skip flushing the output file
        // because it will not be part of the linker line anyway.
        const module_obj_path: ?[]const u8 = if (base.options.module) |module| blk: {
            const use_stage1 = build_options.is_stage1 and base.options.use_stage1;
            if (use_stage1) {
                const obj_basename = try std.zig.binNameAlloc(arena, .{
                    .root_name = base.options.root_name,
                    .target = base.options.target,
                    .output_mode = .Obj,
                });
                switch (base.options.cache_mode) {
                    .incremental => break :blk try module.zig_cache_artifact_directory.join(
                        arena,
                        &[_][]const u8{obj_basename},
                    ),
                    .whole => break :blk try fs.path.join(arena, &.{
                        fs.path.dirname(full_out_path_z).?, obj_basename,
                    }),
                }
            }
            try base.flushModule(comp, prog_node);

            const dirname = fs.path.dirname(full_out_path_z) orelse ".";
            break :blk try fs.path.join(arena, &.{ dirname, base.intermediary_basename.? });
        } else null;

        log.debug("module_obj_path={s}", .{if (module_obj_path) |s| s else "(null)"});

        const compiler_rt_path: ?[]const u8 = if (base.options.include_compiler_rt)
            comp.compiler_rt_obj.?.full_object_path
        else
            null;

        // This function follows the same pattern as link.Elf.linkWithLLD so if you want some
        // insight as to what's going on here you can read that function body which is more
        // well-commented.

        const id_symlink_basename = "llvm-ar.id";

        var man: Cache.Manifest = undefined;
        defer if (!base.options.disable_lld_caching) man.deinit();

        var digest: [Cache.hex_digest_len]u8 = undefined;

        if (!base.options.disable_lld_caching) {
            man = comp.cache_parent.obtain();

            // We are about to obtain this lock, so here we give other processes a chance first.
            base.releaseLock();

            for (base.options.objects) |obj| {
                _ = try man.addFile(obj.path, null);
                man.hash.add(obj.must_link);
            }
            for (comp.c_object_table.keys()) |key| {
                _ = try man.addFile(key.status.success.object_path, null);
            }
            try man.addOptionalFile(module_obj_path);
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

        const num_object_files = base.options.objects.len + comp.c_object_table.count() + 2;
        var object_files = try std.ArrayList([*:0]const u8).initCapacity(base.allocator, num_object_files);
        defer object_files.deinit();

        for (base.options.objects) |obj| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, obj.path));
        }
        for (comp.c_object_table.keys()) |key| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, key.status.success.object_path));
        }
        if (module_obj_path) |p| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, p));
        }
        if (compiler_rt_path) |p| {
            object_files.appendAssumeCapacity(try arena.dupeZ(u8, p));
        }

        if (base.options.verbose_link) {
            std.debug.print("ar rcs {s}", .{full_out_path_z});
            for (object_files.items) |arg| {
                std.debug.print(" {s}", .{arg});
            }
            std.debug.print("\n", .{});
        }

        const llvm = @import("codegen/llvm/bindings.zig");
        const os_type = @import("target.zig").osToLLVM(base.options.target.os.tag);
        const bad = llvm.WriteArchive(full_out_path_z, object_files.items.ptr, object_files.items.len, os_type);
        if (bad) return error.UnableToWriteArchive;

        if (!base.options.disable_lld_caching) {
            Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
                log.warn("failed to save archive hash digest file: {s}", .{@errorName(err)});
            };

            man.writeManifest() catch |err| {
                log.warn("failed to write cache manifest when archiving: {s}", .{@errorName(err)});
            };

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
    };

    pub const ErrorFlags = struct {
        no_entry_point_found: bool = false,
        missing_libc: bool = false,
    };

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

pub fn determineMode(options: Options) fs.File.Mode {
    // On common systems with a 0o022 umask, 0o777 will still result in a file created
    // with 0o755 permissions, but it works appropriately if the system is configured
    // more leniently. As another data point, C's fopen seems to open files with the
    // 666 mode.
    const executable_mode = if (builtin.target.os.tag == .windows) 0 else 0o777;
    switch (options.effectiveOutputMode()) {
        .Lib => return switch (options.link_mode) {
            .Dynamic => executable_mode,
            .Static => fs.File.default_mode,
        },
        .Exe => return executable_mode,
        .Obj => return fs.File.default_mode,
    }
}
