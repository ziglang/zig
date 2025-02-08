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
const Path = std.Build.Cache.Path;
const Directory = std.Build.Cache.Directory;
const Compilation = @import("Compilation.zig");
const LibCInstallation = std.zig.LibCInstallation;
const Liveness = @import("Liveness.zig");
const Zcu = @import("Zcu.zig");
const InternPool = @import("InternPool.zig");
const Type = @import("Type.zig");
const Value = @import("Value.zig");
const LlvmObject = @import("codegen/llvm.zig").Object;
const lldMain = @import("main.zig").lldMain;
const Package = @import("Package.zig");
const dev = @import("dev.zig");
const ThreadSafeQueue = @import("ThreadSafeQueue.zig").ThreadSafeQueue;
const target_util = @import("target.zig");

pub const LdScript = @import("link/LdScript.zig");

pub const Diags = struct {
    /// Stored here so that function definitions can distinguish between
    /// needing an allocator for things besides error reporting.
    gpa: Allocator,
    mutex: std.Thread.Mutex,
    msgs: std.ArrayListUnmanaged(Msg),
    flags: Flags,
    lld: std.ArrayListUnmanaged(Lld),

    pub const SourceLocation = union(enum) {
        none,
        wasm: File.Wasm.SourceLocation,
    };

    pub const Flags = packed struct {
        no_entry_point_found: bool = false,
        missing_libc: bool = false,
        alloc_failure_occurred: bool = false,

        const Int = blk: {
            const bits = @typeInfo(@This()).@"struct".fields.len;
            break :blk @Type(.{ .int = .{
                .signedness = .unsigned,
                .bits = bits,
            } });
        };

        pub fn anySet(ef: Flags) bool {
            return @as(Int, @bitCast(ef)) > 0;
        }
    };

    pub const Lld = struct {
        /// Allocated with gpa.
        msg: []const u8,
        context_lines: []const []const u8 = &.{},

        pub fn deinit(self: *Lld, gpa: Allocator) void {
            for (self.context_lines) |line| gpa.free(line);
            gpa.free(self.context_lines);
            gpa.free(self.msg);
            self.* = undefined;
        }
    };

    pub const Msg = struct {
        source_location: SourceLocation = .none,
        msg: []const u8,
        notes: []Msg = &.{},

        fn string(
            msg: *const Msg,
            bundle: *std.zig.ErrorBundle.Wip,
            base: ?*File,
        ) Allocator.Error!std.zig.ErrorBundle.String {
            return switch (msg.source_location) {
                .none => try bundle.addString(msg.msg),
                .wasm => |sl| {
                    dev.check(.wasm_linker);
                    const wasm = base.?.cast(.wasm).?;
                    return sl.string(msg.msg, bundle, wasm);
                },
            };
        }

        pub fn deinit(self: *Msg, gpa: Allocator) void {
            for (self.notes) |*note| note.deinit(gpa);
            gpa.free(self.notes);
            gpa.free(self.msg);
        }
    };

    pub const ErrorWithNotes = struct {
        diags: *Diags,
        /// Allocated index in diags.msgs array.
        index: usize,
        /// Next available note slot.
        note_slot: usize = 0,

        pub fn addMsg(
            err: ErrorWithNotes,
            comptime format: []const u8,
            args: anytype,
        ) error{OutOfMemory}!void {
            const gpa = err.diags.gpa;
            const err_msg = &err.diags.msgs.items[err.index];
            err_msg.msg = try std.fmt.allocPrint(gpa, format, args);
        }

        pub fn addNote(err: *ErrorWithNotes, comptime format: []const u8, args: anytype) void {
            const gpa = err.diags.gpa;
            const msg = std.fmt.allocPrint(gpa, format, args) catch return err.diags.setAllocFailure();
            const err_msg = &err.diags.msgs.items[err.index];
            assert(err.note_slot < err_msg.notes.len);
            err_msg.notes[err.note_slot] = .{ .msg = msg };
            err.note_slot += 1;
        }
    };

    pub fn init(gpa: Allocator) Diags {
        return .{
            .gpa = gpa,
            .mutex = .{},
            .msgs = .empty,
            .flags = .{},
            .lld = .empty,
        };
    }

    pub fn deinit(diags: *Diags) void {
        const gpa = diags.gpa;

        for (diags.msgs.items) |*item| item.deinit(gpa);
        diags.msgs.deinit(gpa);

        for (diags.lld.items) |*item| item.deinit(gpa);
        diags.lld.deinit(gpa);

        diags.* = undefined;
    }

    pub fn hasErrors(diags: *Diags) bool {
        return diags.msgs.items.len > 0 or diags.flags.anySet();
    }

    pub fn lockAndParseLldStderr(diags: *Diags, prefix: []const u8, stderr: []const u8) void {
        diags.mutex.lock();
        defer diags.mutex.unlock();

        diags.parseLldStderr(prefix, stderr) catch diags.setAllocFailure();
    }

    fn parseLldStderr(
        diags: *Diags,
        prefix: []const u8,
        stderr: []const u8,
    ) Allocator.Error!void {
        const gpa = diags.gpa;

        var context_lines = std.ArrayList([]const u8).init(gpa);
        defer context_lines.deinit();

        var current_err: ?*Lld = null;
        var lines = mem.splitSequence(u8, stderr, if (builtin.os.tag == .windows) "\r\n" else "\n");
        while (lines.next()) |line| {
            if (line.len > prefix.len + ":".len and
                mem.eql(u8, line[0..prefix.len], prefix) and line[prefix.len] == ':')
            {
                if (current_err) |err| {
                    err.context_lines = try context_lines.toOwnedSlice();
                }

                var split = mem.splitSequence(u8, line, "error: ");
                _ = split.first();

                const duped_msg = try std.fmt.allocPrint(gpa, "{s}: {s}", .{ prefix, split.rest() });
                errdefer gpa.free(duped_msg);

                current_err = try diags.lld.addOne(gpa);
                current_err.?.* = .{ .msg = duped_msg };
            } else if (current_err != null) {
                const context_prefix = ">>> ";
                var trimmed = mem.trimRight(u8, line, &std.ascii.whitespace);
                if (mem.startsWith(u8, trimmed, context_prefix)) {
                    trimmed = trimmed[context_prefix.len..];
                }

                if (trimmed.len > 0) {
                    const duped_line = try gpa.dupe(u8, trimmed);
                    try context_lines.append(duped_line);
                }
            }
        }

        if (current_err) |err| {
            err.context_lines = try context_lines.toOwnedSlice();
        }
    }

    pub fn fail(diags: *Diags, comptime format: []const u8, args: anytype) error{LinkFailure} {
        @branchHint(.cold);
        addError(diags, format, args);
        return error.LinkFailure;
    }

    pub fn failSourceLocation(diags: *Diags, sl: SourceLocation, comptime format: []const u8, args: anytype) error{LinkFailure} {
        @branchHint(.cold);
        addErrorSourceLocation(diags, sl, format, args);
        return error.LinkFailure;
    }

    pub fn addError(diags: *Diags, comptime format: []const u8, args: anytype) void {
        return addErrorSourceLocation(diags, .none, format, args);
    }

    pub fn addErrorSourceLocation(diags: *Diags, sl: SourceLocation, comptime format: []const u8, args: anytype) void {
        @branchHint(.cold);
        const gpa = diags.gpa;
        const eu_main_msg = std.fmt.allocPrint(gpa, format, args);
        diags.mutex.lock();
        defer diags.mutex.unlock();
        addErrorLockedFallible(diags, sl, eu_main_msg) catch |err| switch (err) {
            error.OutOfMemory => diags.setAllocFailureLocked(),
        };
    }

    fn addErrorLockedFallible(diags: *Diags, sl: SourceLocation, eu_main_msg: Allocator.Error![]u8) Allocator.Error!void {
        const gpa = diags.gpa;
        const main_msg = try eu_main_msg;
        errdefer gpa.free(main_msg);
        try diags.msgs.append(gpa, .{
            .msg = main_msg,
            .source_location = sl,
        });
    }

    pub fn addErrorWithNotes(diags: *Diags, note_count: usize) error{OutOfMemory}!ErrorWithNotes {
        @branchHint(.cold);
        const gpa = diags.gpa;
        diags.mutex.lock();
        defer diags.mutex.unlock();
        try diags.msgs.ensureUnusedCapacity(gpa, 1);
        return addErrorWithNotesAssumeCapacity(diags, note_count);
    }

    pub fn addErrorWithNotesAssumeCapacity(diags: *Diags, note_count: usize) error{OutOfMemory}!ErrorWithNotes {
        @branchHint(.cold);
        const gpa = diags.gpa;
        const index = diags.msgs.items.len;
        const err = diags.msgs.addOneAssumeCapacity();
        err.* = .{
            .msg = undefined,
            .notes = try gpa.alloc(Msg, note_count),
        };
        return .{
            .diags = diags,
            .index = index,
        };
    }

    pub fn addMissingLibraryError(
        diags: *Diags,
        checked_paths: []const []const u8,
        comptime format: []const u8,
        args: anytype,
    ) void {
        @branchHint(.cold);
        const gpa = diags.gpa;
        const eu_main_msg = std.fmt.allocPrint(gpa, format, args);
        diags.mutex.lock();
        defer diags.mutex.unlock();
        addMissingLibraryErrorLockedFallible(diags, checked_paths, eu_main_msg) catch |err| switch (err) {
            error.OutOfMemory => diags.setAllocFailureLocked(),
        };
    }

    fn addMissingLibraryErrorLockedFallible(
        diags: *Diags,
        checked_paths: []const []const u8,
        eu_main_msg: Allocator.Error![]u8,
    ) Allocator.Error!void {
        const gpa = diags.gpa;
        const main_msg = try eu_main_msg;
        errdefer gpa.free(main_msg);
        try diags.msgs.ensureUnusedCapacity(gpa, 1);
        const notes = try gpa.alloc(Msg, checked_paths.len);
        errdefer gpa.free(notes);
        for (checked_paths, notes) |path, *note| {
            note.* = .{ .msg = try std.fmt.allocPrint(gpa, "tried {s}", .{path}) };
        }
        diags.msgs.appendAssumeCapacity(.{
            .msg = main_msg,
            .notes = notes,
        });
    }

    pub fn addParseError(
        diags: *Diags,
        path: Path,
        comptime format: []const u8,
        args: anytype,
    ) void {
        @branchHint(.cold);
        const gpa = diags.gpa;
        const eu_main_msg = std.fmt.allocPrint(gpa, format, args);
        diags.mutex.lock();
        defer diags.mutex.unlock();
        addParseErrorLockedFallible(diags, path, eu_main_msg) catch |err| switch (err) {
            error.OutOfMemory => diags.setAllocFailureLocked(),
        };
    }

    fn addParseErrorLockedFallible(diags: *Diags, path: Path, m: Allocator.Error![]u8) Allocator.Error!void {
        const gpa = diags.gpa;
        const main_msg = try m;
        errdefer gpa.free(main_msg);
        try diags.msgs.ensureUnusedCapacity(gpa, 1);
        const note = try std.fmt.allocPrint(gpa, "while parsing {}", .{path});
        errdefer gpa.free(note);
        const notes = try gpa.create([1]Msg);
        errdefer gpa.destroy(notes);
        notes.* = .{.{ .msg = note }};
        diags.msgs.appendAssumeCapacity(.{
            .msg = main_msg,
            .notes = notes,
        });
    }

    pub fn failParse(
        diags: *Diags,
        path: Path,
        comptime format: []const u8,
        args: anytype,
    ) error{LinkFailure} {
        @branchHint(.cold);
        addParseError(diags, path, format, args);
        return error.LinkFailure;
    }

    pub fn setAllocFailure(diags: *Diags) void {
        @branchHint(.cold);
        diags.mutex.lock();
        defer diags.mutex.unlock();
        setAllocFailureLocked(diags);
    }

    fn setAllocFailureLocked(diags: *Diags) void {
        log.debug("memory allocation failure", .{});
        diags.flags.alloc_failure_occurred = true;
    }

    pub fn addMessagesToBundle(diags: *const Diags, bundle: *std.zig.ErrorBundle.Wip, base: ?*File) Allocator.Error!void {
        for (diags.msgs.items) |link_err| {
            try bundle.addRootErrorMessage(.{
                .msg = try link_err.string(bundle, base),
                .notes_len = @intCast(link_err.notes.len),
            });
            const notes_start = try bundle.reserveNotes(@intCast(link_err.notes.len));
            for (link_err.notes, 0..) |note, i| {
                bundle.extra.items[notes_start + i] = @intFromEnum(try bundle.addErrorMessage(.{
                    .msg = try note.string(bundle, base),
                }));
            }
        }
    }
};

pub const producer_string = if (builtin.is_test) "zig test" else "zig " ++ build_options.version;

pub const File = struct {
    tag: Tag,

    /// The owner of this output File.
    comp: *Compilation,
    emit: Path,

    file: ?fs.File,
    /// When linking with LLD, this linker code will output an object file only at
    /// this location, and then this path can be placed on the LLD linker line.
    zcu_object_sub_path: ?[]const u8 = null,
    disable_lld_caching: bool,
    gc_sections: bool,
    print_gc_sections: bool,
    build_id: std.zig.BuildId,
    allow_shlib_undefined: bool,
    stack_size: u64,
    post_prelink: bool = false,

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
        object_host_name: ?[]const u8,
        export_symbol_names: []const []const u8,
        global_base: ?u64,
        build_id: std.zig.BuildId,
        disable_lld_caching: bool,
        hash_style: Elf.HashStyle,
        sort_section: ?Elf.SortSection,
        major_subsystem_version: ?u16,
        minor_subsystem_version: ?u16,
        gc_sections: ?bool,
        repro: bool,
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
        lib_directories: []const Directory,
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
        emit: Path,
        options: OpenOptions,
    ) !*File {
        switch (Tag.fromObjectFormat(comp.root_mod.resolved_target.result.ofmt)) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                const ptr = try tag.Type().open(arena, comp, emit, options);
                return &ptr.base;
            },
        }
    }

    pub fn createEmpty(
        arena: Allocator,
        comp: *Compilation,
        emit: Path,
        options: OpenOptions,
    ) !*File {
        switch (Tag.fromObjectFormat(comp.root_mod.resolved_target.result.ofmt)) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                const ptr = try tag.Type().createEmpty(arena, comp, emit, options);
                return &ptr.base;
            },
        }
    }

    pub fn cast(base: *File, comptime tag: Tag) if (dev.env.supports(tag.devFeature())) ?*tag.Type() else ?noreturn {
        return if (dev.env.supports(tag.devFeature()) and base.tag == tag) @fieldParentPtr("base", base) else null;
    }

    pub fn makeWritable(base: *File) !void {
        dev.check(.make_writable);
        const comp = base.comp;
        const gpa = comp.gpa;
        switch (base.tag) {
            .coff, .elf, .macho, .plan9, .wasm => {
                if (base.file != null) return;
                dev.checkAny(&.{ .coff_linker, .elf_linker, .macho_linker, .plan9_linker, .wasm_linker });
                const emit = base.emit;
                if (base.child_pid) |pid| {
                    if (builtin.os.tag == .windows) {
                        base.cast(.coff).?.ptraceAttach(pid) catch |err| {
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
                        try emit.root_dir.handle.copyFile(emit.sub_path, emit.root_dir.handle, tmp_sub_path, .{});
                        try emit.root_dir.handle.rename(tmp_sub_path, emit.sub_path);
                        switch (builtin.os.tag) {
                            .linux => std.posix.ptrace(std.os.linux.PTRACE.ATTACH, pid, 0, 0) catch |err| {
                                log.warn("ptrace failure: {s}", .{@errorName(err)});
                            },
                            .macos => base.cast(.macho).?.ptraceAttach(pid) catch |err| {
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
                base.file = try emit.root_dir.handle.createFile(emit.sub_path, .{
                    .truncate = false,
                    .read = true,
                    .mode = determineMode(use_lld, output_mode, link_mode),
                });
            },
            .c, .spirv, .nvptx => dev.checkAny(&.{ .c_linker, .spirv_linker, .nvptx_linker }),
        }
    }

    pub fn makeExecutable(base: *File) !void {
        dev.check(.make_executable);
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
                dev.check(.elf_linker);
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
                dev.checkAny(&.{ .coff_linker, .macho_linker, .plan9_linker, .wasm_linker });
                if (base.zcu_object_sub_path != null) {
                    // The file we have open is not the final file that we want to
                    // make executable, so we don't have to close it.
                    return;
                }
                f.close();
                base.file = null;

                if (base.child_pid) |pid| {
                    switch (builtin.os.tag) {
                        .macos => base.cast(.macho).?.ptraceDetach(pid) catch |err| {
                            log.warn("detaching failed with error: {s}", .{@errorName(err)});
                        },
                        .windows => base.cast(.coff).?.ptraceDetach(pid),
                        else => return error.HotSwapUnavailableOnHostOperatingSystem,
                    }
                }
            },
            .c, .spirv, .nvptx => dev.checkAny(&.{ .c_linker, .spirv_linker, .nvptx_linker }),
        }
    }

    pub const DebugInfoOutput = union(enum) {
        dwarf: *Dwarf.WipNav,
        plan9: *Plan9.DebugInfoOutput,
        none,
    };
    pub const UpdateDebugInfoError = Dwarf.UpdateError;
    pub const FlushDebugInfoError = Dwarf.FlushError;

    /// Note that `LinkFailure` is not a member of this error set because the error message
    /// must be attached to `Zcu.failed_codegen` rather than `Compilation.link_diags`.
    pub const UpdateNavError = error{
        Overflow,
        OutOfMemory,
        /// Indicates the error is already reported and stored in
        /// `failed_codegen` on the Zcu.
        CodegenFail,
    };

    /// Called from within CodeGen to retrieve the symbol index of a global symbol.
    /// If no symbol exists yet with this name, a new undefined global symbol will
    /// be created. This symbol may get resolved once all relocatables are (re-)linked.
    /// Optionally, it is possible to specify where to expect the symbol defined if it
    /// is an import.
    pub fn getGlobalSymbol(base: *File, name: []const u8, lib_name: ?[]const u8) UpdateNavError!u32 {
        log.debug("getGlobalSymbol '{s}' (expected in '{?s}')", .{ name, lib_name });
        switch (base.tag) {
            .plan9 => unreachable,
            .spirv => unreachable,
            .c => unreachable,
            .nvptx => unreachable,
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).getGlobalSymbol(name, lib_name);
            },
        }
    }

    /// May be called before or after updateExports for any given Nav.
    pub fn updateNav(base: *File, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) UpdateNavError!void {
        const nav = pt.zcu.intern_pool.getNav(nav_index);
        assert(nav.status == .fully_resolved);
        switch (base.tag) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateNav(pt, nav_index);
            },
        }
    }

    pub const UpdateContainerTypeError = error{
        OutOfMemory,
        /// `Zcu.failed_types` is already populated with the error message.
        TypeFailureReported,
    };

    pub fn updateContainerType(base: *File, pt: Zcu.PerThread, ty: InternPool.Index) UpdateContainerTypeError!void {
        switch (base.tag) {
            else => {},
            inline .elf => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateContainerType(pt, ty);
            },
        }
    }

    /// May be called before or after updateExports for any given Decl.
    pub fn updateFunc(
        base: *File,
        pt: Zcu.PerThread,
        func_index: InternPool.Index,
        air: Air,
        liveness: Liveness,
    ) UpdateNavError!void {
        switch (base.tag) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateFunc(pt, func_index, air, liveness);
            },
        }
    }

    pub const UpdateLineNumberError = error{
        OutOfMemory,
        Overflow,
        LinkFailure,
    };

    /// On an incremental update, fixup the line number of all `Nav`s at the given `TrackedInst`, because
    /// its line number has changed. The ZIR instruction `ti_id` has tag `.declaration`.
    pub fn updateLineNumber(base: *File, pt: Zcu.PerThread, ti_id: InternPool.TrackedInst.Index) UpdateLineNumberError!void {
        {
            const ti = ti_id.resolveFull(&pt.zcu.intern_pool).?;
            const file = pt.zcu.fileByIndex(ti.file);
            const inst = file.zir.?.instructions.get(@intFromEnum(ti.inst));
            assert(inst.tag == .declaration);
        }

        switch (base.tag) {
            .spirv, .nvptx => {},
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateLineNumber(pt, ti_id);
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
                dev.check(tag.devFeature());
                @as(*tag.Type(), @fieldParentPtr("base", base)).deinit();
            },
        }
    }

    pub const FlushError = error{
        /// Indicates an error will be present in `Compilation.link_diags`.
        LinkFailure,
        OutOfMemory,
    };

    /// Commit pending changes and write headers. Takes into account final output mode
    /// and `use_lld`, not only `effectiveOutputMode`.
    /// `arena` has the lifetime of the call to `Compilation.update`.
    pub fn flush(base: *File, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) FlushError!void {
        const comp = base.comp;
        if (comp.clang_preprocessor_mode == .yes or comp.clang_preprocessor_mode == .pch) {
            dev.check(.clang_command);
            const emit = base.emit;
            // TODO: avoid extra link step when it's just 1 object file (the `zig cc -c` case)
            // Until then, we do `lld -r -o output.o input.o` even though the output is the same
            // as the input. For the preprocessing case (`zig cc -E -o foo`) we copy the file
            // to the final location. See also the corresponding TODO in Coff linking.
            assert(comp.c_object_table.count() == 1);
            const the_key = comp.c_object_table.keys()[0];
            const cached_pp_file_path = the_key.status.success.object_path;
            cached_pp_file_path.root_dir.handle.copyFile(cached_pp_file_path.sub_path, emit.root_dir.handle, emit.sub_path, .{}) catch |err| {
                const diags = &base.comp.link_diags;
                return diags.fail("failed to copy '{'}' to '{'}': {s}", .{
                    @as(Path, cached_pp_file_path), @as(Path, emit), @errorName(err),
                });
            };
            return;
        }

        assert(base.post_prelink);

        const use_lld = build_options.have_llvm and comp.config.use_lld;
        const output_mode = comp.config.output_mode;
        const link_mode = comp.config.link_mode;
        if (use_lld and output_mode == .Lib and link_mode == .static) {
            return base.linkAsArchive(arena, tid, prog_node);
        }
        switch (base.tag) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).flush(arena, tid, prog_node);
            },
        }
    }

    /// Commit pending changes and write headers. Works based on `effectiveOutputMode`
    /// rather than final output mode.
    pub fn flushModule(base: *File, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) FlushError!void {
        switch (base.tag) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).flushModule(arena, tid, prog_node);
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
        pt: Zcu.PerThread,
        exported: Zcu.Exported,
        export_indices: []const Zcu.Export.Index,
    ) UpdateExportsError!void {
        switch (base.tag) {
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).updateExports(pt, exported, export_indices);
            },
        }
    }

    pub const RelocInfo = struct {
        parent: Parent,
        offset: u64,
        addend: u32,

        pub const Parent = union(enum) {
            none,
            atom_index: u32,
            debug_output: DebugInfoOutput,
        };
    };

    /// Get allocated `Nav`'s address in virtual memory.
    /// The linker is passed information about the containing atom, `parent_atom_index`, and offset within it's
    /// memory buffer, `offset`, so that it can make a note of potential relocation sites, should the
    /// `Nav`'s address was not yet resolved, or the containing atom gets moved in virtual memory.
    /// May be called before or after updateFunc/updateNav therefore it is up to the linker to allocate
    /// the block/atom.
    pub fn getNavVAddr(base: *File, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index, reloc_info: RelocInfo) !u64 {
        switch (base.tag) {
            .c => unreachable,
            .spirv => unreachable,
            .nvptx => unreachable,
            .wasm => unreachable,
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).getNavVAddr(pt, nav_index, reloc_info);
            },
        }
    }

    pub fn lowerUav(
        base: *File,
        pt: Zcu.PerThread,
        decl_val: InternPool.Index,
        decl_align: InternPool.Alignment,
        src_loc: Zcu.LazySrcLoc,
    ) !@import("codegen.zig").GenResult {
        switch (base.tag) {
            .c => unreachable,
            .spirv => unreachable,
            .nvptx => unreachable,
            .wasm => unreachable,
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).lowerUav(pt, decl_val, decl_align, src_loc);
            },
        }
    }

    pub fn getUavVAddr(base: *File, decl_val: InternPool.Index, reloc_info: RelocInfo) !u64 {
        switch (base.tag) {
            .c => unreachable,
            .spirv => unreachable,
            .nvptx => unreachable,
            .wasm => unreachable,
            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).getUavVAddr(decl_val, reloc_info);
            },
        }
    }

    pub fn deleteExport(
        base: *File,
        exported: Zcu.Exported,
        name: InternPool.NullTerminatedString,
    ) void {
        switch (base.tag) {
            .plan9,
            .spirv,
            .nvptx,
            => {},

            inline else => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).deleteExport(exported, name);
            },
        }
    }

    /// Opens a path as an object file and parses it into the linker.
    fn openLoadObject(base: *File, path: Path) anyerror!void {
        const diags = &base.comp.link_diags;
        const input = try openObjectInput(diags, path);
        errdefer input.object.file.close();
        try loadInput(base, input);
    }

    /// Opens a path as a static library and parses it into the linker.
    /// If `query` is non-null, allows GNU ld scripts.
    fn openLoadArchive(base: *File, path: Path, opt_query: ?UnresolvedInput.Query) anyerror!void {
        if (opt_query) |query| {
            const archive = try openObject(path, query.must_link, query.hidden);
            errdefer archive.file.close();
            loadInput(base, .{ .archive = archive }) catch |err| switch (err) {
                error.BadMagic, error.UnexpectedEndOfFile => {
                    if (base.tag != .elf) return err;
                    try loadGnuLdScript(base, path, query, archive.file);
                    archive.file.close();
                    return;
                },
                else => return err,
            };
        } else {
            const archive = try openObject(path, false, false);
            errdefer archive.file.close();
            try loadInput(base, .{ .archive = archive });
        }
    }

    /// Opens a path as a shared library and parses it into the linker.
    /// Handles GNU ld scripts.
    fn openLoadDso(base: *File, path: Path, query: UnresolvedInput.Query) anyerror!void {
        const dso = try openDso(path, query.needed, query.weak, query.reexport);
        errdefer dso.file.close();
        loadInput(base, .{ .dso = dso }) catch |err| switch (err) {
            error.BadMagic, error.UnexpectedEndOfFile => {
                if (base.tag != .elf) return err;
                try loadGnuLdScript(base, path, query, dso.file);
                dso.file.close();
                return;
            },
            else => return err,
        };
    }

    fn loadGnuLdScript(base: *File, path: Path, parent_query: UnresolvedInput.Query, file: fs.File) anyerror!void {
        const diags = &base.comp.link_diags;
        const gpa = base.comp.gpa;
        const stat = try file.stat();
        const size = std.math.cast(u32, stat.size) orelse return error.FileTooBig;
        const buf = try gpa.alloc(u8, size);
        defer gpa.free(buf);
        const n = try file.preadAll(buf, 0);
        if (buf.len != n) return error.UnexpectedEndOfFile;
        var ld_script = try LdScript.parse(gpa, diags, path, buf);
        defer ld_script.deinit(gpa);
        for (ld_script.args) |arg| {
            const query: UnresolvedInput.Query = .{
                .needed = arg.needed or parent_query.needed,
                .weak = parent_query.weak,
                .reexport = parent_query.reexport,
                .preferred_mode = parent_query.preferred_mode,
                .search_strategy = parent_query.search_strategy,
                .allow_so_scripts = parent_query.allow_so_scripts,
            };
            if (mem.startsWith(u8, arg.path, "-l")) {
                @panic("TODO");
            } else {
                if (fs.path.isAbsolute(arg.path)) {
                    const new_path = Path.initCwd(try gpa.dupe(u8, arg.path));
                    switch (Compilation.classifyFileExt(arg.path)) {
                        .shared_library => try openLoadDso(base, new_path, query),
                        .object => try openLoadObject(base, new_path),
                        .static_library => try openLoadArchive(base, new_path, query),
                        else => diags.addParseError(path, "GNU ld script references file with unrecognized extension: {s}", .{arg.path}),
                    }
                } else {
                    @panic("TODO");
                }
            }
        }
    }

    pub fn loadInput(base: *File, input: Input) anyerror!void {
        const use_lld = build_options.have_llvm and base.comp.config.use_lld;
        if (use_lld) return;
        switch (base.tag) {
            inline .elf, .wasm => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).loadInput(input);
            },
            else => {},
        }
    }

    /// Called when all linker inputs have been sent via `loadInput`. After
    /// this, `loadInput` will not be called anymore.
    pub fn prelink(base: *File, prog_node: std.Progress.Node) FlushError!void {
        assert(!base.post_prelink);
        const use_lld = build_options.have_llvm and base.comp.config.use_lld;
        if (use_lld) return;

        // In this case, an object file is created by the LLVM backend, so
        // there is no prelink phase. The Zig code is linked as a standard
        // object along with the others.
        if (base.zcu_object_sub_path != null) return;

        switch (base.tag) {
            inline .wasm => |tag| {
                dev.check(tag.devFeature());
                return @as(*tag.Type(), @fieldParentPtr("base", base)).prelink(prog_node);
            },
            else => {},
        }
    }

    pub fn linkAsArchive(base: *File, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) FlushError!void {
        dev.check(.lld_linker);

        const tracy = trace(@src());
        defer tracy.end();

        const comp = base.comp;
        const diags = &comp.link_diags;

        return linkAsArchiveInner(base, arena, tid, prog_node) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.LinkFailure => return error.LinkFailure,
            else => |e| return diags.fail("failed to link as archive: {s}", .{@errorName(e)}),
        };
    }

    fn linkAsArchiveInner(base: *File, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) !void {
        const comp = base.comp;

        const directory = base.emit.root_dir; // Just an alias to make it shorter to type.
        const full_out_path = try directory.join(arena, &[_][]const u8{base.emit.sub_path});
        const full_out_path_z = try arena.dupeZ(u8, full_out_path);
        const opt_zcu = comp.zcu;

        // If there is no Zig code to compile, then we should skip flushing the output file
        // because it will not be part of the linker line anyway.
        const zcu_obj_path: ?[]const u8 = if (opt_zcu != null) blk: {
            try base.flushModule(arena, tid, prog_node);

            const dirname = fs.path.dirname(full_out_path_z) orelse ".";
            break :blk try fs.path.join(arena, &.{ dirname, base.zcu_object_sub_path.? });
        } else null;

        log.debug("zcu_obj_path={s}", .{if (zcu_obj_path) |s| s else "(null)"});

        const compiler_rt_path: ?Path = if (comp.include_compiler_rt)
            comp.compiler_rt_obj.?.full_object_path
        else
            null;

        // This function follows the same pattern as link.Elf.linkWithLLD so if you want some
        // insight as to what's going on here you can read that function body which is more
        // well-commented.

        const id_symlink_basename = "llvm-ar.id";

        var man: Cache.Manifest = undefined;
        defer if (!base.disable_lld_caching) man.deinit();

        const link_inputs = comp.link_inputs;

        var digest: [Cache.hex_digest_len]u8 = undefined;

        if (!base.disable_lld_caching) {
            man = comp.cache_parent.obtain();

            // We are about to obtain this lock, so here we give other processes a chance first.
            base.releaseLock();

            try hashInputs(&man, link_inputs);

            for (comp.c_object_table.keys()) |key| {
                _ = try man.addFilePath(key.status.success.object_path, null);
            }
            for (comp.win32_resource_table.keys()) |key| {
                _ = try man.addFile(key.status.success.res_path, null);
            }
            try man.addOptionalFile(zcu_obj_path);
            try man.addOptionalFilePath(compiler_rt_path);

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
        if (zcu_obj_path) |p| object_files.appendAssumeCapacity(try arena.dupeZ(u8, p));
        if (compiler_rt_path) |p| object_files.appendAssumeCapacity(try p.toStringZ(arena));

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
                .goff => @panic("TODO implement goff object format"),
                .xcoff => @panic("TODO implement xcoff object format"),
                .hex => @panic("TODO implement hex object format"),
                .raw => @panic("TODO implement raw object format"),
            };
        }

        pub fn devFeature(tag: Tag) dev.Feature {
            return @field(dev.Feature, @tagName(tag) ++ "_linker");
        }
    };

    pub const LazySymbol = struct {
        pub const Kind = enum { code, const_data };

        kind: Kind,
        ty: InternPool.Index,
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
        llvm_object: LlvmObject.Ptr,
        prog_node: std.Progress.Node,
    ) !void {
        return base.comp.emitLlvmObject(arena, .{
            .root_dir = base.emit.root_dir,
            .sub_path = std.fs.path.dirname(base.emit.sub_path) orelse "",
        }, .{
            .directory = null,
            .basename = base.zcu_object_sub_path.?,
        }, llvm_object, prog_node);
    }

    pub fn cgFail(
        base: *File,
        nav_index: InternPool.Nav.Index,
        comptime format: []const u8,
        args: anytype,
    ) error{ CodegenFail, OutOfMemory } {
        @branchHint(.cold);
        return base.comp.zcu.?.codegenFail(nav_index, format, args);
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

/// Does all the tasks in the queue. Runs in exactly one separate thread
/// from the rest of compilation. All tasks performed here are
/// single-threaded with respect to one another.
pub fn flushTaskQueue(tid: usize, comp: *Compilation) void {
    const diags = &comp.link_diags;
    // As soon as check() is called, another `flushTaskQueue` call could occur,
    // so the safety lock must go after the check.
    while (comp.link_task_queue.check()) |tasks| {
        comp.link_task_queue_safety.lock();
        defer comp.link_task_queue_safety.unlock();

        if (comp.remaining_prelink_tasks > 0) {
            comp.link_task_queue_postponed.ensureUnusedCapacity(comp.gpa, tasks.len) catch |err| switch (err) {
                error.OutOfMemory => return diags.setAllocFailure(),
            };
        }

        for (tasks) |task| doTask(comp, tid, task);

        if (comp.remaining_prelink_tasks == 0) {
            if (comp.bin_file) |base| if (!base.post_prelink) {
                base.prelink(comp.work_queue_progress_node) catch |err| switch (err) {
                    error.OutOfMemory => diags.setAllocFailure(),
                    error.LinkFailure => continue,
                };
                base.post_prelink = true;
                for (comp.link_task_queue_postponed.items) |task| doTask(comp, tid, task);
                comp.link_task_queue_postponed.clearRetainingCapacity();
            };
        }
    }
}

pub const Task = union(enum) {
    /// Loads the objects, shared objects, and archives that are already
    /// known from the command line.
    load_explicitly_provided,
    /// Loads the shared objects and archives by resolving
    /// `target_util.libcFullLinkFlags()` against the host libc
    /// installation.
    load_host_libc,
    /// Tells the linker to load an object file by path.
    load_object: Path,
    /// Tells the linker to load a static library by path.
    load_archive: Path,
    /// Tells the linker to load a shared library, possibly one that is a
    /// GNU ld script.
    load_dso: Path,
    /// Tells the linker to load an input which could be an object file,
    /// archive, or shared library.
    load_input: Input,

    /// Write the constant value for a Decl to the output file.
    codegen_nav: InternPool.Nav.Index,
    /// Write the machine code for a function to the output file.
    codegen_func: CodegenFunc,
    codegen_type: InternPool.Index,

    update_line_number: InternPool.TrackedInst.Index,

    pub const CodegenFunc = struct {
        /// This will either be a non-generic `func_decl` or a `func_instance`.
        func: InternPool.Index,
        /// This `Air` is owned by the `Job` and allocated with `gpa`.
        /// It must be deinited when the job is processed.
        air: Air,
    };
};

pub fn doTask(comp: *Compilation, tid: usize, task: Task) void {
    const diags = &comp.link_diags;
    switch (task) {
        .load_explicitly_provided => if (comp.bin_file) |base| {
            comp.remaining_prelink_tasks -= 1;
            const prog_node = comp.work_queue_progress_node.start("Parse Linker Inputs", comp.link_inputs.len);
            defer prog_node.end();
            for (comp.link_inputs) |input| {
                base.loadInput(input) catch |err| switch (err) {
                    error.LinkFailure => return, // error reported via diags
                    else => |e| switch (input) {
                        .dso => |dso| diags.addParseError(dso.path, "failed to parse shared library: {s}", .{@errorName(e)}),
                        .object => |obj| diags.addParseError(obj.path, "failed to parse object: {s}", .{@errorName(e)}),
                        .archive => |obj| diags.addParseError(obj.path, "failed to parse archive: {s}", .{@errorName(e)}),
                        .res => |res| diags.addParseError(res.path, "failed to parse Windows resource: {s}", .{@errorName(e)}),
                        .dso_exact => diags.addError("failed to handle dso_exact: {s}", .{@errorName(e)}),
                    },
                };
                prog_node.completeOne();
            }
        },
        .load_host_libc => if (comp.bin_file) |base| {
            comp.remaining_prelink_tasks -= 1;
            const prog_node = comp.work_queue_progress_node.start("Linker Parse Host libc", 0);
            defer prog_node.end();

            const target = comp.root_mod.resolved_target.result;
            const flags = target_util.libcFullLinkFlags(target);
            const crt_dir = comp.libc_installation.?.crt_dir.?;
            const sep = std.fs.path.sep_str;
            for (flags) |flag| {
                assert(mem.startsWith(u8, flag, "-l"));
                const lib_name = flag["-l".len..];
                switch (comp.config.link_mode) {
                    .dynamic => {
                        const dso_path = Path.initCwd(
                            std.fmt.allocPrint(comp.arena, "{s}" ++ sep ++ "{s}{s}{s}", .{
                                crt_dir, target.libPrefix(), lib_name, target.dynamicLibSuffix(),
                            }) catch return diags.setAllocFailure(),
                        );
                        base.openLoadDso(dso_path, .{
                            .preferred_mode = .dynamic,
                            .search_strategy = .paths_first,
                        }) catch |err| switch (err) {
                            error.FileNotFound => {
                                // Also try static.
                                const archive_path = Path.initCwd(
                                    std.fmt.allocPrint(comp.arena, "{s}" ++ sep ++ "{s}{s}{s}", .{
                                        crt_dir, target.libPrefix(), lib_name, target.staticLibSuffix(),
                                    }) catch return diags.setAllocFailure(),
                                );
                                base.openLoadArchive(archive_path, .{
                                    .preferred_mode = .dynamic,
                                    .search_strategy = .paths_first,
                                }) catch |archive_err| switch (archive_err) {
                                    error.LinkFailure => return, // error reported via diags
                                    else => |e| diags.addParseError(dso_path, "failed to parse archive {}: {s}", .{ archive_path, @errorName(e) }),
                                };
                            },
                            error.LinkFailure => return, // error reported via diags
                            else => |e| diags.addParseError(dso_path, "failed to parse shared library: {s}", .{@errorName(e)}),
                        };
                    },
                    .static => {
                        const path = Path.initCwd(
                            std.fmt.allocPrint(comp.arena, "{s}" ++ sep ++ "{s}{s}{s}", .{
                                crt_dir, target.libPrefix(), lib_name, target.staticLibSuffix(),
                            }) catch return diags.setAllocFailure(),
                        );
                        // glibc sometimes makes even archive files GNU ld scripts.
                        base.openLoadArchive(path, .{
                            .preferred_mode = .static,
                            .search_strategy = .no_fallback,
                        }) catch |err| switch (err) {
                            error.LinkFailure => return, // error reported via diags
                            else => |e| diags.addParseError(path, "failed to parse archive: {s}", .{@errorName(e)}),
                        };
                    },
                }
            }
        },
        .load_object => |path| if (comp.bin_file) |base| {
            comp.remaining_prelink_tasks -= 1;
            const prog_node = comp.work_queue_progress_node.start("Linker Parse Object", 0);
            defer prog_node.end();
            base.openLoadObject(path) catch |err| switch (err) {
                error.LinkFailure => return, // error reported via diags
                else => |e| diags.addParseError(path, "failed to parse object: {s}", .{@errorName(e)}),
            };
        },
        .load_archive => |path| if (comp.bin_file) |base| {
            comp.remaining_prelink_tasks -= 1;
            const prog_node = comp.work_queue_progress_node.start("Linker Parse Archive", 0);
            defer prog_node.end();
            base.openLoadArchive(path, null) catch |err| switch (err) {
                error.LinkFailure => return, // error reported via link_diags
                else => |e| diags.addParseError(path, "failed to parse archive: {s}", .{@errorName(e)}),
            };
        },
        .load_dso => |path| if (comp.bin_file) |base| {
            comp.remaining_prelink_tasks -= 1;
            const prog_node = comp.work_queue_progress_node.start("Linker Parse Shared Library", 0);
            defer prog_node.end();
            base.openLoadDso(path, .{
                .preferred_mode = .dynamic,
                .search_strategy = .paths_first,
            }) catch |err| switch (err) {
                error.LinkFailure => return, // error reported via link_diags
                else => |e| diags.addParseError(path, "failed to parse shared library: {s}", .{@errorName(e)}),
            };
        },
        .load_input => |input| if (comp.bin_file) |base| {
            comp.remaining_prelink_tasks -= 1;
            const prog_node = comp.work_queue_progress_node.start("Linker Parse Input", 0);
            defer prog_node.end();
            base.loadInput(input) catch |err| switch (err) {
                error.LinkFailure => return, // error reported via link_diags
                else => |e| {
                    if (input.path()) |path| {
                        diags.addParseError(path, "failed to parse linker input: {s}", .{@errorName(e)});
                    } else {
                        diags.addError("failed to {s}: {s}", .{ input.taskName(), @errorName(e) });
                    }
                },
            };
        },
        .codegen_nav => |nav_index| {
            if (comp.remaining_prelink_tasks == 0) {
                const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
                defer pt.deactivate();
                pt.linkerUpdateNav(nav_index) catch |err| switch (err) {
                    error.OutOfMemory => diags.setAllocFailure(),
                };
            } else {
                comp.link_task_queue_postponed.appendAssumeCapacity(task);
            }
        },
        .codegen_func => |func| {
            if (comp.remaining_prelink_tasks == 0) {
                const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
                defer pt.deactivate();
                // This call takes ownership of `func.air`.
                pt.linkerUpdateFunc(func.func, func.air) catch |err| switch (err) {
                    error.OutOfMemory => diags.setAllocFailure(),
                };
            } else {
                comp.link_task_queue_postponed.appendAssumeCapacity(task);
            }
        },
        .codegen_type => |ty| {
            if (comp.remaining_prelink_tasks == 0) {
                const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
                defer pt.deactivate();
                pt.linkerUpdateContainerType(ty) catch |err| switch (err) {
                    error.OutOfMemory => diags.setAllocFailure(),
                };
            } else {
                comp.link_task_queue_postponed.appendAssumeCapacity(task);
            }
        },
        .update_line_number => |ti| {
            const pt: Zcu.PerThread = .activate(comp.zcu.?, @enumFromInt(tid));
            defer pt.deactivate();
            pt.linkerUpdateLineNumber(ti) catch |err| switch (err) {
                error.OutOfMemory => diags.setAllocFailure(),
            };
        },
    }
}

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

/// Provided by the CLI, processed into `LinkInput` instances at the start of
/// the compilation pipeline.
pub const UnresolvedInput = union(enum) {
    /// A library name that could potentially be dynamic or static depending on
    /// query parameters, resolved according to library directories.
    /// This could potentially resolve to a GNU ld script, resulting in more
    /// library dependencies.
    name_query: NameQuery,
    /// When a file path is provided, query info is still needed because the
    /// path may point to a .so file which may actually be a GNU ld script that
    /// references library names which need to be resolved.
    path_query: PathQuery,
    /// Strings that come from GNU ld scripts. Is it a filename? Is it a path?
    /// Who knows! Fuck around and find out.
    ambiguous_name: NameQuery,
    /// Put exactly this string in the dynamic section, no rpath.
    dso_exact: Input.DsoExact,

    pub const NameQuery = struct {
        name: []const u8,
        query: Query,
    };

    pub const PathQuery = struct {
        path: Path,
        query: Query,
    };

    pub const Query = struct {
        needed: bool = false,
        weak: bool = false,
        reexport: bool = false,
        must_link: bool = false,
        hidden: bool = false,
        allow_so_scripts: bool = false,
        preferred_mode: std.builtin.LinkMode,
        search_strategy: SearchStrategy,

        fn fallbackMode(q: Query) std.builtin.LinkMode {
            assert(q.search_strategy != .no_fallback);
            return switch (q.preferred_mode) {
                .dynamic => .static,
                .static => .dynamic,
            };
        }
    };

    pub const SearchStrategy = enum {
        paths_first,
        mode_first,
        no_fallback,
    };
};

pub const Input = union(enum) {
    object: Object,
    archive: Object,
    res: Res,
    /// May not be a GNU ld script. Those are resolved when converting from
    /// `UnresolvedInput` to `Input` values.
    dso: Dso,
    dso_exact: DsoExact,

    pub const Object = struct {
        path: Path,
        file: fs.File,
        must_link: bool,
        hidden: bool,
    };

    pub const Res = struct {
        path: Path,
        file: fs.File,
    };

    pub const Dso = struct {
        path: Path,
        file: fs.File,
        needed: bool,
        weak: bool,
        reexport: bool,
    };

    pub const DsoExact = struct {
        /// Includes the ":" prefix. This is intended to be put into the DSO
        /// section verbatim with no corresponding rpaths.
        name: []const u8,
    };

    /// Returns `null` in the case of `dso_exact`.
    pub fn path(input: Input) ?Path {
        return switch (input) {
            .object, .archive => |obj| obj.path,
            inline .res, .dso => |x| x.path,
            .dso_exact => null,
        };
    }

    /// Returns `null` in the case of `dso_exact`.
    pub fn pathAndFile(input: Input) ?struct { Path, fs.File } {
        return switch (input) {
            .object, .archive => |obj| .{ obj.path, obj.file },
            inline .res, .dso => |x| .{ x.path, x.file },
            .dso_exact => null,
        };
    }

    pub fn taskName(input: Input) []const u8 {
        return switch (input) {
            .object, .archive => |obj| obj.path.basename(),
            inline .res, .dso => |x| x.path.basename(),
            .dso_exact => "dso_exact",
        };
    }
};

pub fn hashInputs(man: *Cache.Manifest, link_inputs: []const Input) !void {
    for (link_inputs) |link_input| {
        man.hash.add(@as(@typeInfo(Input).@"union".tag_type.?, link_input));
        switch (link_input) {
            .object, .archive => |obj| {
                _ = try man.addOpenedFile(obj.path, obj.file, null);
                man.hash.add(obj.must_link);
                man.hash.add(obj.hidden);
            },
            .res => |res| {
                _ = try man.addOpenedFile(res.path, res.file, null);
            },
            .dso => |dso| {
                _ = try man.addOpenedFile(dso.path, dso.file, null);
                man.hash.add(dso.needed);
                man.hash.add(dso.weak);
                man.hash.add(dso.reexport);
            },
            .dso_exact => |dso_exact| {
                man.hash.addBytes(dso_exact.name);
            },
        }
    }
}

pub fn resolveInputs(
    gpa: Allocator,
    arena: Allocator,
    target: std.Target,
    /// This function mutates this array but does not take ownership.
    /// Allocated with `gpa`.
    unresolved_inputs: *std.ArrayListUnmanaged(UnresolvedInput),
    /// Allocated with `gpa`.
    resolved_inputs: *std.ArrayListUnmanaged(Input),
    lib_directories: []const Cache.Directory,
    color: std.zig.Color,
) Allocator.Error!void {
    var checked_paths: std.ArrayListUnmanaged(u8) = .empty;
    defer checked_paths.deinit(gpa);

    var ld_script_bytes: std.ArrayListUnmanaged(u8) = .empty;
    defer ld_script_bytes.deinit(gpa);

    var failed_libs: std.ArrayListUnmanaged(struct {
        name: []const u8,
        strategy: UnresolvedInput.SearchStrategy,
        checked_paths: []const u8,
        preferred_mode: std.builtin.LinkMode,
    }) = .empty;

    // Convert external system libs into a stack so that items can be
    // pushed to it.
    //
    // This is necessary because shared objects might turn out to be
    // "linker scripts" that in fact resolve to one or more other
    // external system libs, including parameters such as "needed".
    //
    // Unfortunately, such files need to be detected immediately, so
    // that this library search logic can be applied to them.
    mem.reverse(UnresolvedInput, unresolved_inputs.items);

    syslib: while (unresolved_inputs.pop()) |unresolved_input| {
        const name_query: UnresolvedInput.NameQuery = switch (unresolved_input) {
            .name_query => |nq| nq,
            .ambiguous_name => |an| an: {
                const lib_name, const link_mode = stripLibPrefixAndSuffix(an.name, target) orelse {
                    try resolvePathInput(gpa, arena, unresolved_inputs, resolved_inputs, &ld_script_bytes, target, .{
                        .path = Path.initCwd(an.name),
                        .query = an.query,
                    }, color);
                    continue;
                };
                break :an .{
                    .name = lib_name,
                    .query = .{
                        .needed = an.query.needed,
                        .weak = an.query.weak,
                        .reexport = an.query.reexport,
                        .must_link = an.query.must_link,
                        .hidden = an.query.hidden,
                        .allow_so_scripts = an.query.allow_so_scripts,
                        .preferred_mode = link_mode,
                        .search_strategy = .no_fallback,
                    },
                };
            },
            .path_query => |pq| {
                try resolvePathInput(gpa, arena, unresolved_inputs, resolved_inputs, &ld_script_bytes, target, pq, color);
                continue;
            },
            .dso_exact => |dso_exact| {
                try resolved_inputs.append(gpa, .{ .dso_exact = dso_exact });
                continue;
            },
        };
        const query = name_query.query;

        // Checked in the first pass above while looking for libc libraries.
        assert(!fs.path.isAbsolute(name_query.name));

        checked_paths.clearRetainingCapacity();

        switch (query.search_strategy) {
            .mode_first, .no_fallback => {
                // check for preferred mode
                for (lib_directories) |lib_directory| switch (try resolveLibInput(
                    gpa,
                    arena,
                    unresolved_inputs,
                    resolved_inputs,
                    &checked_paths,
                    &ld_script_bytes,
                    lib_directory,
                    name_query,
                    target,
                    query.preferred_mode,
                    color,
                )) {
                    .ok => continue :syslib,
                    .no_match => {},
                };
                // check for fallback mode
                if (query.search_strategy == .no_fallback) {
                    try failed_libs.append(arena, .{
                        .name = name_query.name,
                        .strategy = query.search_strategy,
                        .checked_paths = try arena.dupe(u8, checked_paths.items),
                        .preferred_mode = query.preferred_mode,
                    });
                    continue :syslib;
                }
                for (lib_directories) |lib_directory| switch (try resolveLibInput(
                    gpa,
                    arena,
                    unresolved_inputs,
                    resolved_inputs,
                    &checked_paths,
                    &ld_script_bytes,
                    lib_directory,
                    name_query,
                    target,
                    query.fallbackMode(),
                    color,
                )) {
                    .ok => continue :syslib,
                    .no_match => {},
                };
                try failed_libs.append(arena, .{
                    .name = name_query.name,
                    .strategy = query.search_strategy,
                    .checked_paths = try arena.dupe(u8, checked_paths.items),
                    .preferred_mode = query.preferred_mode,
                });
                continue :syslib;
            },
            .paths_first => {
                for (lib_directories) |lib_directory| {
                    // check for preferred mode
                    switch (try resolveLibInput(
                        gpa,
                        arena,
                        unresolved_inputs,
                        resolved_inputs,
                        &checked_paths,
                        &ld_script_bytes,
                        lib_directory,
                        name_query,
                        target,
                        query.preferred_mode,
                        color,
                    )) {
                        .ok => continue :syslib,
                        .no_match => {},
                    }

                    // check for fallback mode
                    switch (try resolveLibInput(
                        gpa,
                        arena,
                        unresolved_inputs,
                        resolved_inputs,
                        &checked_paths,
                        &ld_script_bytes,
                        lib_directory,
                        name_query,
                        target,
                        query.fallbackMode(),
                        color,
                    )) {
                        .ok => continue :syslib,
                        .no_match => {},
                    }
                }
                try failed_libs.append(arena, .{
                    .name = name_query.name,
                    .strategy = query.search_strategy,
                    .checked_paths = try arena.dupe(u8, checked_paths.items),
                    .preferred_mode = query.preferred_mode,
                });
                continue :syslib;
            },
        }
        @compileError("unreachable");
    }

    if (failed_libs.items.len > 0) {
        for (failed_libs.items) |f| {
            const searched_paths = if (f.checked_paths.len == 0) " none" else f.checked_paths;
            std.log.err("unable to find {s} system library '{s}' using strategy '{s}'. searched paths:{s}", .{
                @tagName(f.preferred_mode), f.name, @tagName(f.strategy), searched_paths,
            });
        }
        std.process.exit(1);
    }
}

const ResolveLibInputResult = enum { ok, no_match };
const fatal = std.process.fatal;

fn resolveLibInput(
    gpa: Allocator,
    arena: Allocator,
    /// Allocated via `gpa`.
    unresolved_inputs: *std.ArrayListUnmanaged(UnresolvedInput),
    /// Allocated via `gpa`.
    resolved_inputs: *std.ArrayListUnmanaged(Input),
    /// Allocated via `gpa`.
    checked_paths: *std.ArrayListUnmanaged(u8),
    /// Allocated via `gpa`.
    ld_script_bytes: *std.ArrayListUnmanaged(u8),
    lib_directory: Directory,
    name_query: UnresolvedInput.NameQuery,
    target: std.Target,
    link_mode: std.builtin.LinkMode,
    color: std.zig.Color,
) Allocator.Error!ResolveLibInputResult {
    try resolved_inputs.ensureUnusedCapacity(gpa, 1);

    const lib_name = name_query.name;

    if (target.isDarwin() and link_mode == .dynamic) tbd: {
        // Prefer .tbd over .dylib.
        const test_path: Path = .{
            .root_dir = lib_directory,
            .sub_path = try std.fmt.allocPrint(arena, "lib{s}.tbd", .{lib_name}),
        };
        try checked_paths.writer(gpa).print("\n  {}", .{test_path});
        var file = test_path.root_dir.handle.openFile(test_path.sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :tbd,
            else => |e| fatal("unable to search for tbd library '{}': {s}", .{ test_path, @errorName(e) }),
        };
        errdefer file.close();
        return finishResolveLibInput(resolved_inputs, test_path, file, link_mode, name_query.query);
    }

    {
        const test_path: Path = .{
            .root_dir = lib_directory,
            .sub_path = try std.fmt.allocPrint(arena, "{s}{s}{s}", .{
                target.libPrefix(), lib_name, switch (link_mode) {
                    .static => target.staticLibSuffix(),
                    .dynamic => target.dynamicLibSuffix(),
                },
            }),
        };
        try checked_paths.writer(gpa).print("\n  {}", .{test_path});
        switch (try resolvePathInputLib(gpa, arena, unresolved_inputs, resolved_inputs, ld_script_bytes, target, .{
            .path = test_path,
            .query = name_query.query,
        }, link_mode, color)) {
            .no_match => {},
            .ok => return .ok,
        }
    }

    // In the case of Darwin, the main check will be .dylib, so here we
    // additionally check for .so files.
    if (target.isDarwin() and link_mode == .dynamic) so: {
        const test_path: Path = .{
            .root_dir = lib_directory,
            .sub_path = try std.fmt.allocPrint(arena, "lib{s}.so", .{lib_name}),
        };
        try checked_paths.writer(gpa).print("\n  {}", .{test_path});
        var file = test_path.root_dir.handle.openFile(test_path.sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :so,
            else => |e| fatal("unable to search for so library '{}': {s}", .{
                test_path, @errorName(e),
            }),
        };
        errdefer file.close();
        return finishResolveLibInput(resolved_inputs, test_path, file, link_mode, name_query.query);
    }

    // In the case of MinGW, the main check will be .lib but we also need to
    // look for `libfoo.a`.
    if (target.isMinGW() and link_mode == .static) mingw: {
        const test_path: Path = .{
            .root_dir = lib_directory,
            .sub_path = try std.fmt.allocPrint(arena, "lib{s}.a", .{lib_name}),
        };
        try checked_paths.writer(gpa).print("\n  {}", .{test_path});
        var file = test_path.root_dir.handle.openFile(test_path.sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => break :mingw,
            else => |e| fatal("unable to search for static library '{}': {s}", .{ test_path, @errorName(e) }),
        };
        errdefer file.close();
        return finishResolveLibInput(resolved_inputs, test_path, file, link_mode, name_query.query);
    }

    return .no_match;
}

fn finishResolveLibInput(
    resolved_inputs: *std.ArrayListUnmanaged(Input),
    path: Path,
    file: std.fs.File,
    link_mode: std.builtin.LinkMode,
    query: UnresolvedInput.Query,
) ResolveLibInputResult {
    switch (link_mode) {
        .static => resolved_inputs.appendAssumeCapacity(.{ .archive = .{
            .path = path,
            .file = file,
            .must_link = query.must_link,
            .hidden = query.hidden,
        } }),
        .dynamic => resolved_inputs.appendAssumeCapacity(.{ .dso = .{
            .path = path,
            .file = file,
            .needed = query.needed,
            .weak = query.weak,
            .reexport = query.reexport,
        } }),
    }
    return .ok;
}

fn resolvePathInput(
    gpa: Allocator,
    arena: Allocator,
    /// Allocated with `gpa`.
    unresolved_inputs: *std.ArrayListUnmanaged(UnresolvedInput),
    /// Allocated with `gpa`.
    resolved_inputs: *std.ArrayListUnmanaged(Input),
    /// Allocated via `gpa`.
    ld_script_bytes: *std.ArrayListUnmanaged(u8),
    target: std.Target,
    pq: UnresolvedInput.PathQuery,
    color: std.zig.Color,
) Allocator.Error!void {
    switch (switch (Compilation.classifyFileExt(pq.path.sub_path)) {
        .static_library => try resolvePathInputLib(gpa, arena, unresolved_inputs, resolved_inputs, ld_script_bytes, target, pq, .static, color),
        .shared_library => try resolvePathInputLib(gpa, arena, unresolved_inputs, resolved_inputs, ld_script_bytes, target, pq, .dynamic, color),
        .object => {
            var file = pq.path.root_dir.handle.openFile(pq.path.sub_path, .{}) catch |err|
                fatal("failed to open object {}: {s}", .{ pq.path, @errorName(err) });
            errdefer file.close();
            try resolved_inputs.append(gpa, .{ .object = .{
                .path = pq.path,
                .file = file,
                .must_link = pq.query.must_link,
                .hidden = pq.query.hidden,
            } });
            return;
        },
        .res => {
            var file = pq.path.root_dir.handle.openFile(pq.path.sub_path, .{}) catch |err|
                fatal("failed to open windows resource {}: {s}", .{ pq.path, @errorName(err) });
            errdefer file.close();
            try resolved_inputs.append(gpa, .{ .res = .{
                .path = pq.path,
                .file = file,
            } });
            return;
        },
        else => fatal("{}: unrecognized file extension", .{pq.path}),
    }) {
        .ok => {},
        .no_match => fatal("{}: file not found", .{pq.path}),
    }
}

fn resolvePathInputLib(
    gpa: Allocator,
    arena: Allocator,
    /// Allocated with `gpa`.
    unresolved_inputs: *std.ArrayListUnmanaged(UnresolvedInput),
    /// Allocated with `gpa`.
    resolved_inputs: *std.ArrayListUnmanaged(Input),
    /// Allocated via `gpa`.
    ld_script_bytes: *std.ArrayListUnmanaged(u8),
    target: std.Target,
    pq: UnresolvedInput.PathQuery,
    link_mode: std.builtin.LinkMode,
    color: std.zig.Color,
) Allocator.Error!ResolveLibInputResult {
    try resolved_inputs.ensureUnusedCapacity(gpa, 1);

    const test_path: Path = pq.path;
    // In the case of .so files, they might actually be "linker scripts"
    // that contain references to other libraries.
    if (pq.query.allow_so_scripts and target.ofmt == .elf and mem.endsWith(u8, test_path.sub_path, ".so")) {
        var file = test_path.root_dir.handle.openFile(test_path.sub_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return .no_match,
            else => |e| fatal("unable to search for {s} library '{'}': {s}", .{
                @tagName(link_mode), test_path, @errorName(e),
            }),
        };
        errdefer file.close();
        try ld_script_bytes.resize(gpa, @sizeOf(std.elf.Elf64_Ehdr));
        const n = file.preadAll(ld_script_bytes.items, 0) catch |err| fatal("failed to read '{'}': {s}", .{
            test_path, @errorName(err),
        });
        elf_file: {
            if (n != ld_script_bytes.items.len) break :elf_file;
            if (!mem.eql(u8, ld_script_bytes.items[0..4], "\x7fELF")) break :elf_file;
            // Appears to be an ELF file.
            return finishResolveLibInput(resolved_inputs, test_path, file, link_mode, pq.query);
        }
        const stat = file.stat() catch |err|
            fatal("failed to stat {}: {s}", .{ test_path, @errorName(err) });
        const size = std.math.cast(u32, stat.size) orelse
            fatal("{}: linker script too big", .{test_path});
        try ld_script_bytes.resize(gpa, size);
        const buf = ld_script_bytes.items[n..];
        const n2 = file.preadAll(buf, n) catch |err|
            fatal("failed to read {}: {s}", .{ test_path, @errorName(err) });
        if (n2 != buf.len) fatal("failed to read {}: unexpected end of file", .{test_path});
        var diags = Diags.init(gpa);
        defer diags.deinit();
        const ld_script_result = LdScript.parse(gpa, &diags, test_path, ld_script_bytes.items);
        if (diags.hasErrors()) {
            var wip_errors: std.zig.ErrorBundle.Wip = undefined;
            try wip_errors.init(gpa);
            defer wip_errors.deinit();

            try diags.addMessagesToBundle(&wip_errors, null);

            var error_bundle = try wip_errors.toOwnedBundle("");
            defer error_bundle.deinit(gpa);

            error_bundle.renderToStdErr(color.renderOptions());

            std.process.exit(1);
        }

        var ld_script = ld_script_result catch |err|
            fatal("{}: failed to parse linker script: {s}", .{ test_path, @errorName(err) });
        defer ld_script.deinit(gpa);

        try unresolved_inputs.ensureUnusedCapacity(gpa, ld_script.args.len);
        for (ld_script.args) |arg| {
            const query: UnresolvedInput.Query = .{
                .needed = arg.needed or pq.query.needed,
                .weak = pq.query.weak,
                .reexport = pq.query.reexport,
                .preferred_mode = pq.query.preferred_mode,
                .search_strategy = pq.query.search_strategy,
                .allow_so_scripts = pq.query.allow_so_scripts,
            };
            if (mem.startsWith(u8, arg.path, "-l")) {
                unresolved_inputs.appendAssumeCapacity(.{ .name_query = .{
                    .name = try arena.dupe(u8, arg.path["-l".len..]),
                    .query = query,
                } });
            } else {
                unresolved_inputs.appendAssumeCapacity(.{ .ambiguous_name = .{
                    .name = try arena.dupe(u8, arg.path),
                    .query = query,
                } });
            }
        }
        file.close();
        return .ok;
    }

    var file = test_path.root_dir.handle.openFile(test_path.sub_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return .no_match,
        else => |e| fatal("unable to search for {s} library {}: {s}", .{
            @tagName(link_mode), test_path, @errorName(e),
        }),
    };
    errdefer file.close();
    return finishResolveLibInput(resolved_inputs, test_path, file, link_mode, pq.query);
}

pub fn openObject(path: Path, must_link: bool, hidden: bool) !Input.Object {
    var file = try path.root_dir.handle.openFile(path.sub_path, .{});
    errdefer file.close();
    return .{
        .path = path,
        .file = file,
        .must_link = must_link,
        .hidden = hidden,
    };
}

pub fn openDso(path: Path, needed: bool, weak: bool, reexport: bool) !Input.Dso {
    var file = try path.root_dir.handle.openFile(path.sub_path, .{});
    errdefer file.close();
    return .{
        .path = path,
        .file = file,
        .needed = needed,
        .weak = weak,
        .reexport = reexport,
    };
}

pub fn openObjectInput(diags: *Diags, path: Path) error{LinkFailure}!Input {
    return .{ .object = openObject(path, false, false) catch |err| {
        return diags.failParse(path, "failed to open {}: {s}", .{ path, @errorName(err) });
    } };
}

pub fn openArchiveInput(diags: *Diags, path: Path, must_link: bool, hidden: bool) error{LinkFailure}!Input {
    return .{ .archive = openObject(path, must_link, hidden) catch |err| {
        return diags.failParse(path, "failed to open {}: {s}", .{ path, @errorName(err) });
    } };
}

pub fn openDsoInput(diags: *Diags, path: Path, needed: bool, weak: bool, reexport: bool) error{LinkFailure}!Input {
    return .{ .dso = openDso(path, needed, weak, reexport) catch |err| {
        return diags.failParse(path, "failed to open {}: {s}", .{ path, @errorName(err) });
    } };
}

fn stripLibPrefixAndSuffix(path: []const u8, target: std.Target) ?struct { []const u8, std.builtin.LinkMode } {
    const prefix = target.libPrefix();
    const static_suffix = target.staticLibSuffix();
    const dynamic_suffix = target.dynamicLibSuffix();
    const basename = fs.path.basename(path);
    const unlibbed = if (mem.startsWith(u8, basename, prefix)) basename[prefix.len..] else return null;
    if (mem.endsWith(u8, unlibbed, static_suffix)) return .{
        unlibbed[0 .. unlibbed.len - static_suffix.len], .static,
    };
    if (mem.endsWith(u8, unlibbed, dynamic_suffix)) return .{
        unlibbed[0 .. unlibbed.len - dynamic_suffix.len], .dynamic,
    };
    return null;
}

/// Returns true if and only if there is at least one input of type object,
/// archive, or Windows resource file.
pub fn anyObjectInputs(inputs: []const Input) bool {
    return countObjectInputs(inputs) != 0;
}

/// Returns the number of inputs of type object, archive, or Windows resource file.
pub fn countObjectInputs(inputs: []const Input) usize {
    var count: usize = 0;
    for (inputs) |input| switch (input) {
        .dso, .dso_exact => continue,
        .res, .object, .archive => count += 1,
    };
    return count;
}

/// Returns the first input of type object or archive.
pub fn firstObjectInput(inputs: []const Input) ?Input.Object {
    for (inputs) |input| switch (input) {
        .object, .archive => |obj| return obj,
        .res, .dso, .dso_exact => continue,
    };
    return null;
}
