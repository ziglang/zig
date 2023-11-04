base: File,

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

mode: Mode,

dyld_info_cmd: macho.dyld_info_command = .{},
symtab_cmd: macho.symtab_command = .{},
dysymtab_cmd: macho.dysymtab_command = .{},
function_starts_cmd: macho.linkedit_data_command = .{ .cmd = .FUNCTION_STARTS },
data_in_code_cmd: macho.linkedit_data_command = .{ .cmd = .DATA_IN_CODE },
uuid_cmd: macho.uuid_command = .{ .uuid = [_]u8{0} ** 16 },
codesig_cmd: macho.linkedit_data_command = .{ .cmd = .CODE_SIGNATURE },

objects: std.ArrayListUnmanaged(Object) = .{},
archives: std.ArrayListUnmanaged(Archive) = .{},
dylibs: std.ArrayListUnmanaged(Dylib) = .{},
dylibs_map: std.StringHashMapUnmanaged(u16) = .{},
referenced_dylibs: std.AutoArrayHashMapUnmanaged(u16, void) = .{},

segments: std.ArrayListUnmanaged(macho.segment_command_64) = .{},
sections: std.MultiArrayList(Section) = .{},

pagezero_segment_cmd_index: ?u8 = null,
header_segment_cmd_index: ?u8 = null,
text_segment_cmd_index: ?u8 = null,
data_const_segment_cmd_index: ?u8 = null,
data_segment_cmd_index: ?u8 = null,
linkedit_segment_cmd_index: ?u8 = null,

text_section_index: ?u8 = null,
data_const_section_index: ?u8 = null,
data_section_index: ?u8 = null,
bss_section_index: ?u8 = null,
thread_vars_section_index: ?u8 = null,
thread_data_section_index: ?u8 = null,
thread_bss_section_index: ?u8 = null,
eh_frame_section_index: ?u8 = null,
unwind_info_section_index: ?u8 = null,
stubs_section_index: ?u8 = null,
stub_helper_section_index: ?u8 = null,
got_section_index: ?u8 = null,
la_symbol_ptr_section_index: ?u8 = null,
tlv_ptr_section_index: ?u8 = null,

locals: std.ArrayListUnmanaged(macho.nlist_64) = .{},
globals: std.ArrayListUnmanaged(SymbolWithLoc) = .{},
resolver: std.StringHashMapUnmanaged(u32) = .{},
unresolved: std.AutoArrayHashMapUnmanaged(u32, void) = .{},

locals_free_list: std.ArrayListUnmanaged(u32) = .{},
globals_free_list: std.ArrayListUnmanaged(u32) = .{},

dyld_stub_binder_index: ?u32 = null,
dyld_private_atom_index: ?Atom.Index = null,

strtab: StringTable = .{},

got_table: TableSection(SymbolWithLoc) = .{},
stub_table: TableSection(SymbolWithLoc) = .{},
tlv_ptr_table: TableSection(SymbolWithLoc) = .{},

thunk_table: std.AutoHashMapUnmanaged(Atom.Index, thunks.Thunk.Index) = .{},
thunks: std.ArrayListUnmanaged(thunks.Thunk) = .{},

error_flags: File.ErrorFlags = File.ErrorFlags{},
misc_errors: std.ArrayListUnmanaged(File.ErrorMsg) = .{},

segment_table_dirty: bool = false,
got_table_count_dirty: bool = false,
got_table_contents_dirty: bool = false,
stub_table_count_dirty: bool = false,
stub_table_contents_dirty: bool = false,
stub_helper_preamble_allocated: bool = false,

/// A helper var to indicate if we are at the start of the incremental updates, or
/// already somewhere further along the update-and-run chain.
/// TODO once we add opening a prelinked output binary from file, this will become
/// obsolete as we will carry on where we left off.
cold_start: bool = true,

/// List of atoms that are either synthetic or map directly to the Zig source program.
atoms: std.ArrayListUnmanaged(Atom) = .{},

/// Table of atoms indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, Atom.Index) = .{},

/// Table of unnamed constants associated with a parent `Decl`.
/// We store them here so that we can free the constants whenever the `Decl`
/// needs updating or is freed.
///
/// For example,
///
/// ```zig
/// const Foo = struct{
///     a: u8,
/// };
///
/// pub fn main() void {
///     var foo = Foo{ .a = 1 };
///     _ = foo;
/// }
/// ```
///
/// value assigned to label `foo` is an unnamed constant belonging/associated
/// with `Decl` `main`, and lives as long as that `Decl`.
unnamed_const_atoms: UnnamedConstTable = .{},
anon_decls: AnonDeclTable = .{},

/// A table of relocations indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
relocs: RelocationTable = .{},
/// TODO I do not have time to make this right but this will go once
/// MachO linker is rewritten more-or-less to feature the same resolution
/// mechanism as the ELF linker.
actions: ActionTable = .{},

/// A table of rebases indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
rebases: RebaseTable = .{},

/// A table of bindings indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
bindings: BindingTable = .{},

/// Table of tracked LazySymbols.
lazy_syms: LazySymbolTable = .{},

/// Table of tracked Decls.
decls: DeclTable = .{},

/// Table of threadlocal variables descriptors.
/// They are emitted in the `__thread_vars` section.
tlv_table: TlvSymbolTable = .{},

/// Hot-code swapping state.
hot_state: if (is_hot_update_compatible) HotUpdateState else struct {} = .{},

pub fn openPath(allocator: Allocator, options: link.Options) !*MachO {
    assert(options.target.ofmt == .macho);

    if (options.emit == null) {
        return createEmpty(allocator, options);
    }

    const emit = options.emit.?;
    const mode: Mode = mode: {
        if (options.use_llvm or options.module == null or options.cache_mode == .whole)
            break :mode .zld;
        break :mode .incremental;
    };
    const sub_path = if (mode == .zld) blk: {
        if (options.module == null) {
            // No point in opening a file, we would not write anything to it.
            // Initialize with empty.
            return createEmpty(allocator, options);
        }
        // Open a temporary object file, not the final output file because we
        // want to link with LLD.
        break :blk try std.fmt.allocPrint(allocator, "{s}{s}", .{
            emit.sub_path, options.target.ofmt.fileExt(options.target.cpu.arch),
        });
    } else emit.sub_path;
    errdefer if (mode == .zld) allocator.free(sub_path);

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    if (mode == .zld) {
        // TODO this intermediary_basename isn't enough; in the case of `zig build-exe`,
        // we also want to put the intermediary object file in the cache while the
        // main emit directory is the cwd.
        self.base.intermediary_basename = sub_path;
        return self;
    }

    const file = try emit.directory.handle.createFile(sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();
    self.base.file = file;

    if (!options.strip and options.module != null) {
        // Create dSYM bundle.
        log.debug("creating {s}.dSYM bundle", .{sub_path});

        const d_sym_path = try std.fmt.allocPrint(
            allocator,
            "{s}.dSYM" ++ fs.path.sep_str ++ "Contents" ++ fs.path.sep_str ++ "Resources" ++ fs.path.sep_str ++ "DWARF",
            .{sub_path},
        );
        defer allocator.free(d_sym_path);

        var d_sym_bundle = try emit.directory.handle.makeOpenPath(d_sym_path, .{});
        defer d_sym_bundle.close();

        const d_sym_file = try d_sym_bundle.createFile(sub_path, .{
            .truncate = false,
            .read = true,
        });

        self.d_sym = .{
            .allocator = allocator,
            .dwarf = link.File.Dwarf.init(allocator, &self.base, .dwarf32),
            .file = d_sym_file,
        };
    }

    // Index 0 is always a null symbol.
    try self.locals.append(allocator, .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    try self.strtab.buffer.append(allocator, 0);

    try self.populateMissingMetadata();

    if (self.d_sym) |*d_sym| {
        try d_sym.populateMissingMetadata(self);
    }

    return self;
}

pub fn createEmpty(gpa: Allocator, options: link.Options) !*MachO {
    const self = try gpa.create(MachO);
    errdefer gpa.destroy(self);

    self.* = .{
        .base = .{
            .tag = .macho,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .mode = if (options.use_llvm or options.module == null or options.cache_mode == .whole)
            .zld
        else
            .incremental,
    };

    if (options.use_llvm) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }

    log.debug("selected linker mode '{s}'", .{@tagName(self.mode)});

    return self;
}

pub fn flush(self: *MachO, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (self.base.options.emit == null) {
        if (self.llvm_object) |llvm_object| {
            try llvm_object.flushModule(comp, prog_node);
        }
        return;
    }

    if (self.base.options.output_mode == .Lib and self.base.options.link_mode == .Static) {
        if (build_options.have_llvm) {
            return self.base.linkAsArchive(comp, prog_node);
        } else {
            try self.misc_errors.ensureUnusedCapacity(self.base.allocator, 1);
            self.misc_errors.appendAssumeCapacity(.{
                .msg = try self.base.allocator.dupe(u8, "TODO: non-LLVM archiver for MachO object files"),
            });
            return error.FlushFailure;
        }
    }

    switch (self.mode) {
        .zld => return zld.linkWithZld(self, comp, prog_node),
        .incremental => return self.flushModule(comp, prog_node),
    }
}

pub fn flushModule(self: *MachO, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.llvm_object) |llvm_object| {
        return try llvm_object.flushModule(comp, prog_node);
    }

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var sub_prog_node = prog_node.start("MachO Flush", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    const module = self.base.options.module orelse return error.LinkingWithoutZigSourceUnimplemented;

    if (self.lazy_syms.getPtr(.none)) |metadata| {
        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) self.updateLazySymbolAtom(
            File.LazySymbol.initDecl(.code, null, module),
            metadata.text_atom,
            self.text_section_index.?,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
        if (metadata.data_const_state != .unused) self.updateLazySymbolAtom(
            File.LazySymbol.initDecl(.const_data, null, module),
            metadata.data_const_atom,
            self.data_const_section_index.?,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.FlushFailure,
            else => |e| e,
        };
    }
    for (self.lazy_syms.values()) |*metadata| {
        if (metadata.text_state != .unused) metadata.text_state = .flushed;
        if (metadata.data_const_state != .unused) metadata.data_const_state = .flushed;
    }

    if (self.d_sym) |*d_sym| {
        try d_sym.dwarf.flushModule(module);
    }

    var libs = std.StringArrayHashMap(link.SystemLib).init(arena);
    try self.resolveLibSystem(arena, comp, &.{}, &libs);

    const id_symlink_basename = "link.id";

    const cache_dir_handle = module.zig_cache_artifact_directory.handle;
    var man: Cache.Manifest = undefined;
    defer man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;
    man = comp.cache_parent.obtain();
    man.want_shared_lock = false;
    self.base.releaseLock();

    man.hash.addListOfBytes(libs.keys());

    _ = try man.hit();
    digest = man.final();

    var prev_digest_buf: [digest.len]u8 = undefined;
    const prev_digest: []u8 = Cache.readSmallFile(
        cache_dir_handle,
        id_symlink_basename,
        &prev_digest_buf,
    ) catch |err| blk: {
        log.debug("MachO Zld new_digest={s} error: {s}", .{
            std.fmt.fmtSliceHexLower(&digest),
            @errorName(err),
        });
        // Handle this as a cache miss.
        break :blk prev_digest_buf[0..0];
    };
    const cache_miss: bool = cache_miss: {
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("MachO Zld digest={s} match", .{
                std.fmt.fmtSliceHexLower(&digest),
            });
            if (!self.cold_start) {
                log.debug("  skipping parsing linker line objects", .{});
                break :cache_miss false;
            } else {
                log.debug("  TODO parse prelinked binary and continue linking where we left off", .{});
            }
        }
        log.debug("MachO Zld prev_digest={s} new_digest={s}", .{
            std.fmt.fmtSliceHexLower(prev_digest),
            std.fmt.fmtSliceHexLower(&digest),
        });
        // We are about to change the output file to be different, so we invalidate the build hash now.
        cache_dir_handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
        break :cache_miss true;
    };

    if (cache_miss) {
        for (self.dylibs.items) |*dylib| {
            dylib.deinit(self.base.allocator);
        }
        self.dylibs.clearRetainingCapacity();
        self.dylibs_map.clearRetainingCapacity();
        self.referenced_dylibs.clearRetainingCapacity();

        var dependent_libs = std.fifo.LinearFifo(DylibReExportInfo, .Dynamic).init(arena);

        for (libs.keys(), libs.values()) |path, lib| {
            const in_file = try std.fs.cwd().openFile(path, .{});
            defer in_file.close();

            var parse_ctx = ParseErrorCtx.init(self.base.allocator);
            defer parse_ctx.deinit();

            self.parseLibrary(
                in_file,
                path,
                lib,
                false,
                false,
                null,
                &dependent_libs,
                &parse_ctx,
            ) catch |err| try self.handleAndReportParseError(path, err, &parse_ctx);
        }

        try self.parseDependentLibs(&dependent_libs);
    }

    try self.resolveSymbols();

    if (self.getEntryPoint() == null) {
        self.error_flags.no_entry_point_found = true;
    }
    if (self.unresolved.count() > 0) {
        try self.reportUndefined();
        return error.FlushFailure;
    }

    {
        var it = self.actions.iterator();
        while (it.next()) |entry| {
            const global_index = entry.key_ptr.*;
            const global = self.globals.items[global_index];
            const flags = entry.value_ptr.*;
            if (flags.add_got) try self.addGotEntry(global);
            if (flags.add_stub) try self.addStubEntry(global);
        }
    }

    try self.createDyldPrivateAtom();
    try self.writeStubHelperPreamble();

    if (self.base.options.output_mode == .Exe and self.getEntryPoint() != null) {
        const global = self.getEntryPoint().?;
        if (self.getSymbol(global).undf()) {
            // We do one additional check here in case the entry point was found in one of the dylibs.
            // (I actually have no idea what this would imply but it is a possible outcome and so we
            // support it.)
            try self.addStubEntry(global);
        }
    }

    try self.allocateSpecialSymbols();

    for (self.relocs.keys()) |atom_index| {
        const relocs = self.relocs.get(atom_index).?;
        const needs_update = for (relocs.items) |reloc| {
            if (reloc.dirty) break true;
        } else false;

        if (!needs_update) continue;

        const atom = self.getAtom(atom_index);
        const sym = atom.getSymbol(self);
        const section = self.sections.get(sym.n_sect - 1).header;
        const file_offset = section.offset + sym.n_value - section.addr;

        var code = std.ArrayList(u8).init(self.base.allocator);
        defer code.deinit();
        try code.resize(math.cast(usize, atom.size) orelse return error.Overflow);

        const amt = try self.base.file.?.preadAll(code.items, file_offset);
        if (amt != code.items.len) return error.InputOutput;

        try self.writeAtom(atom_index, code.items);
    }

    // Update GOT if it got moved in memory.
    if (self.got_table_contents_dirty) {
        for (self.got_table.entries.items, 0..) |entry, i| {
            if (!self.got_table.lookup.contains(entry)) continue;
            // TODO: write all in one go rather than incrementally.
            try self.writeOffsetTableEntry(i);
        }
        self.got_table_contents_dirty = false;
    }

    // Update stubs if we moved any section in memory.
    // TODO: we probably don't need to update all sections if only one got moved.
    if (self.stub_table_contents_dirty) {
        for (self.stub_table.entries.items, 0..) |entry, i| {
            if (!self.stub_table.lookup.contains(entry)) continue;
            // TODO: write all in one go rather than incrementally.
            try self.writeStubTableEntry(i);
        }
        self.stub_table_contents_dirty = false;
    }

    if (build_options.enable_logging) {
        self.logSymtab();
        self.logSections();
        self.logAtoms();
    }

    try self.writeLinkeditSegmentData();

    var codesig: ?CodeSignature = if (requiresCodeSignature(&self.base.options)) blk: {
        // Preallocate space for the code signature.
        // We need to do this at this stage so that we have the load commands with proper values
        // written out to the file.
        // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
        // where the code signature goes into.
        var codesig = CodeSignature.init(getPageSize(self.base.options.target.cpu.arch));
        codesig.code_directory.ident = self.base.options.emit.?.sub_path;
        if (self.base.options.entitlements) |path| {
            try codesig.addEntitlements(self.base.allocator, path);
        }
        try self.writeCodeSignaturePadding(&codesig);
        break :blk codesig;
    } else null;
    defer if (codesig) |*csig| csig.deinit(self.base.allocator);

    // Write load commands
    var lc_buffer = std.ArrayList(u8).init(arena);
    const lc_writer = lc_buffer.writer();

    try self.writeSegmentHeaders(lc_writer);
    try lc_writer.writeStruct(self.dyld_info_cmd);
    try lc_writer.writeStruct(self.symtab_cmd);
    try lc_writer.writeStruct(self.dysymtab_cmd);
    try load_commands.writeDylinkerLC(lc_writer);

    switch (self.base.options.output_mode) {
        .Exe => blk: {
            const seg_id = self.header_segment_cmd_index.?;
            const seg = self.segments.items[seg_id];
            const global = self.getEntryPoint() orelse break :blk;
            const sym = self.getSymbol(global);

            const addr: u64 = if (sym.undf())
                // In this case, the symbol has been resolved in one of dylibs and so we point
                // to the stub as its vmaddr value.
                self.getStubsEntryAddress(global).?
            else
                sym.n_value;

            try lc_writer.writeStruct(macho.entry_point_command{
                .entryoff = @as(u32, @intCast(addr - seg.vmaddr)),
                .stacksize = self.base.options.stack_size_override orelse 0,
            });
        },
        .Lib => if (self.base.options.link_mode == .Dynamic) {
            try load_commands.writeDylibIdLC(self.base.allocator, &self.base.options, lc_writer);
        },
        else => {},
    }

    try load_commands.writeRpathLCs(self.base.allocator, &self.base.options, lc_writer);
    try lc_writer.writeStruct(macho.source_version_command{
        .version = 0,
    });
    {
        const platform = Platform.fromTarget(self.base.options.target);
        const sdk_version: ?std.SemanticVersion = load_commands.inferSdkVersion(arena, comp);
        if (platform.isBuildVersionCompatible()) {
            try load_commands.writeBuildVersionLC(platform, sdk_version, lc_writer);
        } else if (platform.isVersionMinCompatible()) {
            try load_commands.writeVersionMinLC(platform, sdk_version, lc_writer);
        }
    }

    const uuid_cmd_offset = @sizeOf(macho.mach_header_64) + @as(u32, @intCast(lc_buffer.items.len));
    try lc_writer.writeStruct(self.uuid_cmd);

    try load_commands.writeLoadDylibLCs(self.dylibs.items, self.referenced_dylibs.keys(), lc_writer);

    if (codesig != null) {
        try lc_writer.writeStruct(self.codesig_cmd);
    }

    const ncmds = load_commands.calcNumOfLCs(lc_buffer.items);
    try self.base.file.?.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64));
    try self.writeHeader(ncmds, @as(u32, @intCast(lc_buffer.items.len)));
    try self.writeUuid(comp, uuid_cmd_offset, codesig != null);

    if (codesig) |*csig| {
        try self.writeCodeSignature(comp, csig); // code signing always comes last
        const emit = self.base.options.emit.?;
        try invalidateKernelCache(emit.directory.handle, emit.sub_path);
    }

    if (self.d_sym) |*d_sym| {
        // Flush debug symbols bundle.
        try d_sym.flushModule(self);
    }

    if (cache_miss) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(cache_dir_handle, id_symlink_basename, &digest) catch |err| {
            log.debug("failed to save linking hash digest file: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.debug("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        self.base.lock = man.toOwnedLock();
    }

    self.cold_start = false;
}

/// XNU starting with Big Sur running on arm64 is caching inodes of running binaries.
/// Any change to the binary will effectively invalidate the kernel's cache
/// resulting in a SIGKILL on each subsequent run. Since when doing incremental
/// linking we're modifying a binary in-place, this will end up with the kernel
/// killing it on every subsequent run. To circumvent it, we will copy the file
/// into a new inode, remove the original file, and rename the copy to match
/// the original file. This is super messy, but there doesn't seem any other
/// way to please the XNU.
pub fn invalidateKernelCache(dir: std.fs.Dir, sub_path: []const u8) !void {
    if (comptime builtin.target.isDarwin() and builtin.target.cpu.arch == .aarch64) {
        try dir.copyFile(sub_path, dir, sub_path, .{});
    }
}

inline fn conformUuid(out: *[Md5.digest_length]u8) void {
    // LC_UUID uuids should conform to RFC 4122 UUID version 4 & UUID version 5 formats
    out[6] = (out[6] & 0x0F) | (3 << 4);
    out[8] = (out[8] & 0x3F) | 0x80;
}

pub fn resolveLibSystem(
    self: *MachO,
    arena: Allocator,
    comp: *Compilation,
    search_dirs: []const []const u8,
    out_libs: anytype,
) !void {
    var tmp_arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer tmp_arena_allocator.deinit();
    const tmp_arena = tmp_arena_allocator.allocator();

    var test_path = std.ArrayList(u8).init(tmp_arena);
    var checked_paths = std.ArrayList([]const u8).init(tmp_arena);

    success: {
        for (search_dirs) |dir| if (try accessLibPath(
            tmp_arena,
            &test_path,
            &checked_paths,
            dir,
            "libSystem",
        )) break :success;

        if (self.base.options.darwin_sdk_layout) |sdk_layout| switch (sdk_layout) {
            .sdk => {
                const dir = try fs.path.join(tmp_arena, &[_][]const u8{ self.base.options.sysroot.?, "usr", "lib" });
                if (try accessLibPath(tmp_arena, &test_path, &checked_paths, dir, "libSystem")) break :success;
            },
            .vendored => {
                const dir = try comp.zig_lib_directory.join(tmp_arena, &[_][]const u8{ "libc", "darwin" });
                if (try accessLibPath(tmp_arena, &test_path, &checked_paths, dir, "libSystem")) break :success;
            },
        };

        try self.reportMissingLibraryError(checked_paths.items, "unable to find libSystem system library", .{});
        return;
    }

    const libsystem_path = try arena.dupe(u8, test_path.items);
    try out_libs.put(libsystem_path, .{
        .needed = true,
        .weak = false,
        .path = libsystem_path,
    });
}

fn accessLibPath(
    gpa: Allocator,
    test_path: *std.ArrayList(u8),
    checked_paths: *std.ArrayList([]const u8),
    search_dir: []const u8,
    lib_name: []const u8,
) !bool {
    const sep = fs.path.sep_str;

    tbd: {
        test_path.clearRetainingCapacity();
        try test_path.writer().print("{s}" ++ sep ++ "{s}.tbd", .{ search_dir, lib_name });
        try checked_paths.append(try gpa.dupe(u8, test_path.items));
        fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
            error.FileNotFound => break :tbd,
            else => |e| return e,
        };
        return true;
    }

    dylib: {
        test_path.clearRetainingCapacity();
        try test_path.writer().print("{s}" ++ sep ++ "{s}.dylib", .{ search_dir, lib_name });
        try checked_paths.append(try gpa.dupe(u8, test_path.items));
        fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
            error.FileNotFound => break :dylib,
            else => |e| return e,
        };
        return true;
    }

    noextension: {
        test_path.clearRetainingCapacity();
        try test_path.writer().print("{s}" ++ sep ++ "{s}", .{ search_dir, lib_name });
        try checked_paths.append(try gpa.dupe(u8, test_path.items));
        fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
            error.FileNotFound => break :noextension,
            else => |e| return e,
        };
        return true;
    }

    return false;
}

const ParseError = error{
    UnknownFileType,
    InvalidTarget,
    InvalidTargetFatLibrary,
    DylibAlreadyExists,
    IncompatibleDylibVersion,
    OutOfMemory,
    Overflow,
    InputOutput,
    MalformedArchive,
    NotLibStub,
    EndOfStream,
    FileSystem,
    NotSupported,
} || std.os.SeekError || std.fs.File.OpenError || std.fs.File.ReadError || tapi.TapiError;

pub fn parsePositional(
    self: *MachO,
    file: std.fs.File,
    path: []const u8,
    must_link: bool,
    dependent_libs: anytype,
    ctx: *ParseErrorCtx,
) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    if (Object.isObject(file)) {
        try self.parseObject(file, path, ctx);
    } else {
        try self.parseLibrary(file, path, .{
            .path = null,
            .needed = false,
            .weak = false,
        }, must_link, false, null, dependent_libs, ctx);
    }
}

fn parseObject(
    self: *MachO,
    file: std.fs.File,
    path: []const u8,
    ctx: *ParseErrorCtx,
) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;
    const mtime: u64 = mtime: {
        const stat = file.stat() catch break :mtime 0;
        break :mtime @as(u64, @intCast(@divFloor(stat.mtime, 1_000_000_000)));
    };
    const file_stat = try file.stat();
    const file_size = math.cast(usize, file_stat.size) orelse return error.Overflow;
    const contents = try file.readToEndAllocOptions(gpa, file_size, file_size, @alignOf(u64), null);

    var object = Object{
        .name = try gpa.dupe(u8, path),
        .mtime = mtime,
        .contents = contents,
    };
    errdefer object.deinit(gpa);
    try object.parse(gpa);

    const detected_cpu_arch: std.Target.Cpu.Arch = switch (object.header.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => unreachable,
    };
    const detected_platform = object.getPlatform();
    const this_cpu_arch = self.base.options.target.cpu.arch;
    const this_platform = Platform.fromTarget(self.base.options.target);

    if (this_cpu_arch != detected_cpu_arch or
        (detected_platform != null and !detected_platform.?.eqlTarget(this_platform)))
    {
        const platform = detected_platform orelse this_platform;
        try ctx.detected_targets.append(try platform.allocPrintTarget(ctx.arena(), detected_cpu_arch));
        return error.InvalidTarget;
    }

    try self.objects.append(gpa, object);
}

pub fn parseLibrary(
    self: *MachO,
    file: std.fs.File,
    path: []const u8,
    lib: link.SystemLib,
    must_link: bool,
    is_dependent: bool,
    reexport_info: ?DylibReExportInfo,
    dependent_libs: anytype,
    ctx: *ParseErrorCtx,
) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    if (fat.isFatLibrary(file)) {
        const offset = try self.parseFatLibrary(file, self.base.options.target.cpu.arch, ctx);
        try file.seekTo(offset);

        if (Archive.isArchive(file, offset)) {
            try self.parseArchive(path, offset, must_link, ctx);
        } else if (Dylib.isDylib(file, offset)) {
            try self.parseDylib(file, path, offset, dependent_libs, .{
                .needed = lib.needed,
                .weak = lib.weak,
                .dependent = is_dependent,
                .reexport_info = reexport_info,
            }, ctx);
        } else return error.UnknownFileType;
    } else if (Archive.isArchive(file, 0)) {
        try self.parseArchive(path, 0, must_link, ctx);
    } else if (Dylib.isDylib(file, 0)) {
        try self.parseDylib(file, path, 0, dependent_libs, .{
            .needed = lib.needed,
            .weak = lib.weak,
            .dependent = is_dependent,
            .reexport_info = reexport_info,
        }, ctx);
    } else {
        self.parseLibStub(file, path, dependent_libs, .{
            .needed = lib.needed,
            .weak = lib.weak,
            .dependent = is_dependent,
            .reexport_info = reexport_info,
        }, ctx) catch |err| switch (err) {
            error.NotLibStub, error.UnexpectedToken => return error.UnknownFileType,
            else => |e| return e,
        };
    }
}

pub fn parseFatLibrary(
    self: *MachO,
    file: std.fs.File,
    cpu_arch: std.Target.Cpu.Arch,
    ctx: *ParseErrorCtx,
) ParseError!u64 {
    const gpa = self.base.allocator;

    const fat_archs = try fat.parseArchs(gpa, file);
    defer gpa.free(fat_archs);

    const offset = for (fat_archs) |arch| {
        if (arch.tag == cpu_arch) break arch.offset;
    } else {
        try ctx.detected_targets.ensureUnusedCapacity(fat_archs.len);
        for (fat_archs) |arch| {
            ctx.detected_targets.appendAssumeCapacity(try ctx.arena().dupe(u8, @tagName(arch.tag)));
        }
        return error.InvalidTargetFatLibrary;
    };
    return offset;
}

fn parseArchive(
    self: *MachO,
    path: []const u8,
    fat_offset: u64,
    must_link: bool,
    ctx: *ParseErrorCtx,
) ParseError!void {
    const gpa = self.base.allocator;

    // We take ownership of the file so that we can store it for the duration of symbol resolution.
    // TODO we shouldn't need to do that and could pre-parse the archive like we do for zld/ELF?
    const file = try std.fs.cwd().openFile(path, .{});
    try file.seekTo(fat_offset);

    var archive = Archive{
        .file = file,
        .fat_offset = fat_offset,
        .name = try gpa.dupe(u8, path),
    };
    errdefer archive.deinit(gpa);

    try archive.parse(gpa, file.reader());

    // Verify arch and platform
    if (archive.toc.values().len > 0) {
        const offsets = archive.toc.values()[0].items;
        assert(offsets.len > 0);
        const off = offsets[0];
        var object = try archive.parseObject(gpa, off); // TODO we are doing all this work to pull the header only!
        defer object.deinit(gpa);

        const detected_cpu_arch: std.Target.Cpu.Arch = switch (object.header.cputype) {
            macho.CPU_TYPE_ARM64 => .aarch64,
            macho.CPU_TYPE_X86_64 => .x86_64,
            else => unreachable,
        };
        const detected_platform = object.getPlatform();
        const this_cpu_arch = self.base.options.target.cpu.arch;
        const this_platform = Platform.fromTarget(self.base.options.target);

        if (this_cpu_arch != detected_cpu_arch or
            (detected_platform != null and !detected_platform.?.eqlTarget(this_platform)))
        {
            const platform = detected_platform orelse this_platform;
            try ctx.detected_targets.append(try platform.allocPrintTarget(gpa, detected_cpu_arch));
            return error.InvalidTarget;
        }
    }

    if (must_link) {
        // Get all offsets from the ToC
        var offsets = std.AutoArrayHashMap(u32, void).init(gpa);
        defer offsets.deinit();
        for (archive.toc.values()) |offs| {
            for (offs.items) |off| {
                _ = try offsets.getOrPut(off);
            }
        }
        for (offsets.keys()) |off| {
            const object = try archive.parseObject(gpa, off);
            try self.objects.append(gpa, object);
        }
    } else {
        try self.archives.append(gpa, archive);
    }
}

pub const DylibReExportInfo = struct {
    id: Dylib.Id,
    parent: u16,
};

const DylibOpts = struct {
    reexport_info: ?DylibReExportInfo = null,
    dependent: bool = false,
    needed: bool = false,
    weak: bool = false,
};

fn parseDylib(
    self: *MachO,
    file: std.fs.File,
    path: []const u8,
    offset: u64,
    dependent_libs: anytype,
    dylib_options: DylibOpts,
    ctx: *ParseErrorCtx,
) ParseError!void {
    const gpa = self.base.allocator;
    const file_stat = try file.stat();
    const file_size = math.cast(usize, file_stat.size - offset) orelse return error.Overflow;

    const contents = try file.readToEndAllocOptions(gpa, file_size, file_size, @alignOf(u64), null);
    defer gpa.free(contents);

    var dylib = Dylib{ .path = try gpa.dupe(u8, path), .weak = dylib_options.weak };
    errdefer dylib.deinit(gpa);

    try dylib.parseFromBinary(
        gpa,
        @intCast(self.dylibs.items.len), // TODO defer it till later
        dependent_libs,
        path,
        contents,
    );

    const detected_cpu_arch: std.Target.Cpu.Arch = switch (dylib.header.?.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => unreachable,
    };
    const detected_platform = dylib.getPlatform(contents);
    const this_cpu_arch = self.base.options.target.cpu.arch;
    const this_platform = Platform.fromTarget(self.base.options.target);

    if (this_cpu_arch != detected_cpu_arch or
        (detected_platform != null and !detected_platform.?.eqlTarget(this_platform)))
    {
        const platform = detected_platform orelse this_platform;
        try ctx.detected_targets.append(try platform.allocPrintTarget(ctx.arena(), detected_cpu_arch));
        return error.InvalidTarget;
    }

    try self.addDylib(dylib, dylib_options, ctx);
}

fn parseLibStub(
    self: *MachO,
    file: std.fs.File,
    path: []const u8,
    dependent_libs: anytype,
    dylib_options: DylibOpts,
    ctx: *ParseErrorCtx,
) ParseError!void {
    const gpa = self.base.allocator;
    var lib_stub = try LibStub.loadFromFile(gpa, file);
    defer lib_stub.deinit();

    if (lib_stub.inner.len == 0) return error.NotLibStub;

    // Verify target
    {
        var matcher = try Dylib.TargetMatcher.init(gpa, self.base.options.target);
        defer matcher.deinit();

        const first_tbd = lib_stub.inner[0];
        const targets = try first_tbd.targets(gpa);
        defer {
            for (targets) |t| gpa.free(t);
            gpa.free(targets);
        }
        if (!matcher.matchesTarget(targets)) {
            try ctx.detected_targets.ensureUnusedCapacity(targets.len);
            for (targets) |t| {
                ctx.detected_targets.appendAssumeCapacity(try ctx.arena().dupe(u8, t));
            }
            return error.InvalidTarget;
        }
    }

    var dylib = Dylib{ .path = try gpa.dupe(u8, path), .weak = dylib_options.weak };
    errdefer dylib.deinit(gpa);

    try dylib.parseFromStub(
        gpa,
        self.base.options.target,
        lib_stub,
        @intCast(self.dylibs.items.len), // TODO defer it till later
        dependent_libs,
        path,
    );

    try self.addDylib(dylib, dylib_options, ctx);
}

fn addDylib(self: *MachO, dylib: Dylib, dylib_options: DylibOpts, ctx: *ParseErrorCtx) ParseError!void {
    if (dylib_options.reexport_info) |reexport_info| {
        if (dylib.id.?.current_version < reexport_info.id.compatibility_version) {
            ctx.detected_dylib_id = .{
                .parent = reexport_info.parent,
                .required_version = reexport_info.id.compatibility_version,
                .found_version = dylib.id.?.current_version,
            };
            return error.IncompatibleDylibVersion;
        }
    }

    const gpa = self.base.allocator;
    const gop = try self.dylibs_map.getOrPut(gpa, dylib.id.?.name);
    if (gop.found_existing) return error.DylibAlreadyExists;

    gop.value_ptr.* = @as(u16, @intCast(self.dylibs.items.len));
    try self.dylibs.append(gpa, dylib);

    const should_link_dylib_even_if_unreachable = blk: {
        if (self.base.options.dead_strip_dylibs and !dylib_options.needed) break :blk false;
        break :blk !(dylib_options.dependent or self.referenced_dylibs.contains(gop.value_ptr.*));
    };

    if (should_link_dylib_even_if_unreachable) {
        try self.referenced_dylibs.putNoClobber(gpa, gop.value_ptr.*, {});
    }
}

pub fn parseDependentLibs(self: *MachO, dependent_libs: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // At this point, we can now parse dependents of dylibs preserving the inclusion order of:
    // 1) anything on the linker line is parsed first
    // 2) afterwards, we parse dependents of the included dylibs
    // TODO this should not be performed if the user specifies `-flat_namespace` flag.
    // See ld64 manpages.
    const gpa = self.base.allocator;

    while (dependent_libs.readItem()) |dep_id| {
        defer dep_id.id.deinit(gpa);

        if (self.dylibs_map.contains(dep_id.id.name)) continue;

        const parent = &self.dylibs.items[dep_id.parent];
        const weak = parent.weak;
        const dirname = fs.path.dirname(dep_id.id.name) orelse "";
        const stem = fs.path.stem(dep_id.id.name);

        var arena_allocator = std.heap.ArenaAllocator.init(gpa);
        defer arena_allocator.deinit();
        const arena = arena_allocator.allocator();

        var test_path = std.ArrayList(u8).init(arena);
        var checked_paths = std.ArrayList([]const u8).init(arena);

        success: {
            if (self.base.options.sysroot) |root| {
                const dir = try fs.path.join(arena, &[_][]const u8{ root, dirname });
                if (try accessLibPath(gpa, &test_path, &checked_paths, dir, stem)) break :success;
            }

            if (try accessLibPath(gpa, &test_path, &checked_paths, dirname, stem)) break :success;

            try self.reportMissingLibraryError(
                checked_paths.items,
                "missing dynamic library dependency: '{s}'",
                .{dep_id.id.name},
            );
            continue;
        }

        const full_path = test_path.items;
        const file = try std.fs.cwd().openFile(full_path, .{});
        defer file.close();

        log.debug("parsing dependency {s} at fully resolved path {s}", .{ dep_id.id.name, full_path });

        var parse_ctx = ParseErrorCtx.init(gpa);
        defer parse_ctx.deinit();

        self.parseLibrary(file, full_path, .{
            .path = null,
            .needed = false,
            .weak = weak,
        }, false, true, dep_id, dependent_libs, &parse_ctx) catch |err|
            try self.handleAndReportParseError(full_path, err, &parse_ctx);

        // TODO I think that it would be nice to rewrite this error to include metadata for failed dependency
        // in addition to parsing error
    }
}

pub fn writeAtom(self: *MachO, atom_index: Atom.Index, code: []u8) !void {
    const atom = self.getAtom(atom_index);
    const sym = atom.getSymbol(self);
    const section = self.sections.get(sym.n_sect - 1);
    const file_offset = section.header.offset + sym.n_value - section.header.addr;
    log.debug("writing atom for symbol {s} at file offset 0x{x}", .{ atom.getName(self), file_offset });

    // Gather relocs which can be resolved.
    var relocs = std.ArrayList(*Relocation).init(self.base.allocator);
    defer relocs.deinit();

    if (self.relocs.getPtr(atom_index)) |rels| {
        try relocs.ensureTotalCapacityPrecise(rels.items.len);
        for (rels.items) |*reloc| {
            if (reloc.isResolvable(self) and reloc.dirty) {
                relocs.appendAssumeCapacity(reloc);
            }
        }
    }

    Atom.resolveRelocations(self, atom_index, relocs.items, code);

    if (is_hot_update_compatible) {
        if (self.hot_state.mach_task) |task| {
            self.writeToMemory(task, section.segment_index, sym.n_value, code) catch |err| {
                log.warn("cannot hot swap: writing to memory failed: {s}", .{@errorName(err)});
            };
        }
    }

    try self.base.file.?.pwriteAll(code, file_offset);

    // Now we can mark the relocs as resolved.
    while (relocs.popOrNull()) |reloc| {
        reloc.dirty = false;
    }
}

fn writeToMemory(self: *MachO, task: std.os.darwin.MachTask, segment_index: u8, addr: u64, code: []const u8) !void {
    const segment = self.segments.items[segment_index];
    const cpu_arch = self.base.options.target.cpu.arch;
    const nwritten = if (!segment.isWriteable())
        try task.writeMemProtected(addr, code, cpu_arch)
    else
        try task.writeMem(addr, code, cpu_arch);
    if (nwritten != code.len) return error.InputOutput;
}

fn writeOffsetTableEntry(self: *MachO, index: usize) !void {
    const sect_id = self.got_section_index.?;

    if (self.got_table_count_dirty) {
        const needed_size = self.got_table.entries.items.len * @sizeOf(u64);
        try self.growSection(sect_id, needed_size);
        self.got_table_count_dirty = false;
    }

    const header = &self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const entry = self.got_table.entries.items[index];
    const entry_value = self.getSymbol(entry).n_value;
    const entry_offset = index * @sizeOf(u64);
    const file_offset = header.offset + entry_offset;
    const vmaddr = header.addr + entry_offset;

    log.debug("writing GOT entry {d}: @{x} => {x}", .{ index, vmaddr, entry_value });

    var buf: [@sizeOf(u64)]u8 = undefined;
    mem.writeInt(u64, &buf, entry_value, .little);
    try self.base.file.?.pwriteAll(&buf, file_offset);

    if (is_hot_update_compatible) {
        if (self.hot_state.mach_task) |task| {
            self.writeToMemory(task, segment_index, vmaddr, &buf) catch |err| {
                log.warn("cannot hot swap: writing to memory failed: {s}", .{@errorName(err)});
            };
        }
    }
}

fn writeStubHelperPreamble(self: *MachO) !void {
    if (self.stub_helper_preamble_allocated) return;

    const gpa = self.base.allocator;
    const cpu_arch = self.base.options.target.cpu.arch;
    const size = stubs.stubHelperPreambleSize(cpu_arch);

    var buf = try std.ArrayList(u8).initCapacity(gpa, size);
    defer buf.deinit();

    const dyld_private_addr = self.getAtom(self.dyld_private_atom_index.?).getSymbol(self).n_value;
    const dyld_stub_binder_got_addr = blk: {
        const index = self.got_table.lookup.get(self.getGlobalByIndex(self.dyld_stub_binder_index.?)).?;
        const header = self.sections.items(.header)[self.got_section_index.?];
        break :blk header.addr + @sizeOf(u64) * index;
    };
    const header = self.sections.items(.header)[self.stub_helper_section_index.?];

    try stubs.writeStubHelperPreambleCode(.{
        .cpu_arch = cpu_arch,
        .source_addr = header.addr,
        .dyld_private_addr = dyld_private_addr,
        .dyld_stub_binder_got_addr = dyld_stub_binder_got_addr,
    }, buf.writer());
    try self.base.file.?.pwriteAll(buf.items, header.offset);

    self.stub_helper_preamble_allocated = true;
}

fn writeStubTableEntry(self: *MachO, index: usize) !void {
    const stubs_sect_id = self.stubs_section_index.?;
    const stub_helper_sect_id = self.stub_helper_section_index.?;
    const laptr_sect_id = self.la_symbol_ptr_section_index.?;

    const cpu_arch = self.base.options.target.cpu.arch;
    const stub_entry_size = stubs.stubSize(cpu_arch);
    const stub_helper_entry_size = stubs.stubHelperSize(cpu_arch);
    const stub_helper_preamble_size = stubs.stubHelperPreambleSize(cpu_arch);

    if (self.stub_table_count_dirty) {
        // We grow all 3 sections one by one.
        {
            const needed_size = stub_entry_size * self.stub_table.entries.items.len;
            try self.growSection(stubs_sect_id, needed_size);
        }
        {
            const needed_size = stub_helper_preamble_size + stub_helper_entry_size * self.stub_table.entries.items.len;
            try self.growSection(stub_helper_sect_id, needed_size);
        }
        {
            const needed_size = @sizeOf(u64) * self.stub_table.entries.items.len;
            try self.growSection(laptr_sect_id, needed_size);
        }
        self.stub_table_count_dirty = false;
    }

    const gpa = self.base.allocator;

    const stubs_header = self.sections.items(.header)[stubs_sect_id];
    const stub_helper_header = self.sections.items(.header)[stub_helper_sect_id];
    const laptr_header = self.sections.items(.header)[laptr_sect_id];

    const entry = self.stub_table.entries.items[index];
    const stub_addr: u64 = stubs_header.addr + stub_entry_size * index;
    const stub_helper_addr: u64 = stub_helper_header.addr + stub_helper_preamble_size + stub_helper_entry_size * index;
    const laptr_addr: u64 = laptr_header.addr + @sizeOf(u64) * index;

    log.debug("writing stub entry {d}: @{x} => '{s}'", .{ index, stub_addr, self.getSymbolName(entry) });

    {
        var buf = try std.ArrayList(u8).initCapacity(gpa, stub_entry_size);
        defer buf.deinit();
        try stubs.writeStubCode(.{
            .cpu_arch = cpu_arch,
            .source_addr = stub_addr,
            .target_addr = laptr_addr,
        }, buf.writer());
        const off = stubs_header.offset + stub_entry_size * index;
        try self.base.file.?.pwriteAll(buf.items, off);
    }

    {
        var buf = try std.ArrayList(u8).initCapacity(gpa, stub_helper_entry_size);
        defer buf.deinit();
        try stubs.writeStubHelperCode(.{
            .cpu_arch = cpu_arch,
            .source_addr = stub_helper_addr,
            .target_addr = stub_helper_header.addr,
        }, buf.writer());
        const off = stub_helper_header.offset + stub_helper_preamble_size + stub_helper_entry_size * index;
        try self.base.file.?.pwriteAll(buf.items, off);
    }

    {
        var buf: [@sizeOf(u64)]u8 = undefined;
        mem.writeInt(u64, &buf, stub_helper_addr, .little);
        const off = laptr_header.offset + @sizeOf(u64) * index;
        try self.base.file.?.pwriteAll(&buf, off);
    }

    // TODO: generating new stub entry will require pulling the address of the symbol from the
    // target dylib when updating directly in memory.
    if (is_hot_update_compatible) {
        if (self.hot_state.mach_task) |_| {
            @panic("TODO: update a stub entry in memory");
        }
    }
}

fn markRelocsDirtyByTarget(self: *MachO, target: SymbolWithLoc) void {
    log.debug("marking relocs dirty by target: {}", .{target});
    // TODO: reverse-lookup might come in handy here
    for (self.relocs.values()) |*relocs| {
        for (relocs.items) |*reloc| {
            if (!reloc.target.eql(target)) continue;
            reloc.dirty = true;
        }
    }
}

fn markRelocsDirtyByAddress(self: *MachO, addr: u64) void {
    log.debug("marking relocs dirty by address: {x}", .{addr});

    const got_moved = blk: {
        const sect_id = self.got_section_index orelse break :blk false;
        break :blk self.sections.items(.header)[sect_id].addr > addr;
    };
    const stubs_moved = blk: {
        const sect_id = self.stubs_section_index orelse break :blk false;
        break :blk self.sections.items(.header)[sect_id].addr > addr;
    };

    for (self.relocs.values()) |*relocs| {
        for (relocs.items) |*reloc| {
            if (reloc.isGotIndirection()) {
                reloc.dirty = reloc.dirty or got_moved;
            } else if (reloc.isStubTrampoline(self)) {
                reloc.dirty = reloc.dirty or stubs_moved;
            } else {
                const target_addr = reloc.getTargetBaseAddress(self) orelse continue;
                if (target_addr > addr) reloc.dirty = true;
            }
        }
    }

    // TODO: dirty only really affected GOT cells
    for (self.got_table.entries.items) |entry| {
        const target_addr = self.getSymbol(entry).n_value;
        if (target_addr > addr) {
            self.got_table_contents_dirty = true;
            break;
        }
    }

    {
        const stubs_addr = self.getSegment(self.stubs_section_index.?).vmaddr;
        const stub_helper_addr = self.getSegment(self.stub_helper_section_index.?).vmaddr;
        const laptr_addr = self.getSegment(self.la_symbol_ptr_section_index.?).vmaddr;
        if (stubs_addr > addr or stub_helper_addr > addr or laptr_addr > addr)
            self.stub_table_contents_dirty = true;
    }
}

pub fn allocateSpecialSymbols(self: *MachO) !void {
    for (&[_][]const u8{
        "___dso_handle",
        "__mh_execute_header",
    }) |name| {
        const global = self.getGlobal(name) orelse continue;
        if (global.getFile() != null) continue;
        const sym = self.getSymbolPtr(global);
        const seg = self.getSegment(self.text_section_index.?);
        sym.n_sect = self.text_section_index.? + 1;
        sym.n_value = seg.vmaddr;

        log.debug("allocating {s}(@0x{x},sect({d})) at the start of {s}", .{
            name,
            sym.n_value,
            sym.n_sect,
            seg.segName(),
        });
    }
}

const CreateAtomOpts = struct {
    size: u64 = 0,
    alignment: Alignment = .@"1",
};

pub fn createAtom(self: *MachO, sym_index: u32, opts: CreateAtomOpts) !Atom.Index {
    const gpa = self.base.allocator;
    const index = @as(Atom.Index, @intCast(self.atoms.items.len));
    const atom = try self.atoms.addOne(gpa);
    atom.* = .{};
    atom.sym_index = sym_index;
    atom.size = opts.size;
    atom.alignment = opts.alignment;
    log.debug("creating ATOM(%{d}) at index {d}", .{ sym_index, index });
    return index;
}

pub fn createTentativeDefAtoms(self: *MachO) !void {
    const gpa = self.base.allocator;

    for (self.globals.items) |global| {
        const sym = self.getSymbolPtr(global);
        if (!sym.tentative()) continue;
        if (sym.n_desc == N_DEAD) continue;

        log.debug("creating tentative definition for ATOM(%{d}, '{s}') in object({?})", .{
            global.sym_index, self.getSymbolName(global), global.file,
        });

        // Convert any tentative definition into a regular symbol and allocate
        // text blocks for each tentative definition.
        const size = sym.n_value;
        const alignment = (sym.n_desc >> 8) & 0x0f;

        if (self.bss_section_index == null) {
            self.bss_section_index = try self.initSection("__DATA", "__bss", .{
                .flags = macho.S_ZEROFILL,
            });
        }

        sym.* = .{
            .n_strx = sym.n_strx,
            .n_type = macho.N_SECT | macho.N_EXT,
            .n_sect = self.bss_section_index.? + 1,
            .n_desc = 0,
            .n_value = 0,
        };

        const atom_index = try self.createAtom(global.sym_index, .{
            .size = size,
            .alignment = @enumFromInt(alignment),
        });
        const atom = self.getAtomPtr(atom_index);
        atom.file = global.file;

        self.addAtomToSection(atom_index);

        assert(global.getFile() != null);
        const object = &self.objects.items[global.getFile().?];
        try object.atoms.append(gpa, atom_index);
        object.atom_by_index_table[global.sym_index] = atom_index;
    }
}

pub fn createDyldPrivateAtom(self: *MachO) !void {
    if (self.dyld_private_atom_index != null) return;

    const sym_index = try self.allocateSymbol();
    const atom_index = try self.createAtom(sym_index, .{
        .size = @sizeOf(u64),
        .alignment = .@"8",
    });
    try self.atom_by_index_table.putNoClobber(self.base.allocator, sym_index, atom_index);

    if (self.data_section_index == null) {
        self.data_section_index = try self.initSection("__DATA", "__data", .{});
    }

    const atom = self.getAtom(atom_index);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.data_section_index.? + 1;
    self.dyld_private_atom_index = atom_index;

    switch (self.mode) {
        .zld => self.addAtomToSection(atom_index),
        .incremental => {
            sym.n_value = try self.allocateAtom(atom_index, atom.size, .@"8");
            log.debug("allocated dyld_private atom at 0x{x}", .{sym.n_value});
            var buffer: [@sizeOf(u64)]u8 = [_]u8{0} ** @sizeOf(u64);
            try self.writeAtom(atom_index, &buffer);
        },
    }
}

fn createThreadLocalDescriptorAtom(self: *MachO, sym_name: []const u8, target: SymbolWithLoc) !Atom.Index {
    const gpa = self.base.allocator;
    const size = 3 * @sizeOf(u64);
    const required_alignment: Alignment = .@"1";
    const sym_index = try self.allocateSymbol();
    const atom_index = try self.createAtom(sym_index, .{});
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom_index);
    self.getAtomPtr(atom_index).size = size;

    const sym = self.getAtom(atom_index).getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.thread_vars_section_index.? + 1;
    sym.n_strx = try self.strtab.insert(gpa, sym_name);
    sym.n_value = try self.allocateAtom(atom_index, size, required_alignment);

    log.debug("allocated threadlocal descriptor atom '{s}' at 0x{x}", .{ sym_name, sym.n_value });

    try Atom.addRelocation(self, atom_index, .{
        .type = .tlv_initializer,
        .target = target,
        .offset = 0x10,
        .addend = 0,
        .pcrel = false,
        .length = 3,
    });

    var code: [size]u8 = undefined;
    @memset(&code, 0);
    try self.writeAtom(atom_index, &code);

    return atom_index;
}

pub fn createMhExecuteHeaderSymbol(self: *MachO) !void {
    if (self.base.options.output_mode != .Exe) return;

    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index };
    const sym = self.getSymbolPtr(sym_loc);
    sym.* = .{
        .n_strx = try self.strtab.insert(gpa, "__mh_execute_header"),
        .n_type = macho.N_SECT | macho.N_EXT,
        .n_sect = 0,
        .n_desc = macho.REFERENCED_DYNAMICALLY,
        .n_value = 0,
    };

    const gop = try self.getOrPutGlobalPtr("__mh_execute_header");
    if (gop.found_existing) {
        const global = gop.value_ptr.*;
        if (global.getFile()) |file| {
            const global_object = &self.objects.items[file];
            global_object.globals_lookup[global.sym_index] = self.getGlobalIndex("__mh_execute_header").?;
        }
    }
    gop.value_ptr.* = sym_loc;
}

pub fn createDsoHandleSymbol(self: *MachO) !void {
    const global = self.getGlobalPtr("___dso_handle") orelse return;
    if (!self.getSymbol(global.*).undf()) return;

    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index };
    const sym = self.getSymbolPtr(sym_loc);
    sym.* = .{
        .n_strx = try self.strtab.insert(gpa, "___dso_handle"),
        .n_type = macho.N_SECT | macho.N_EXT,
        .n_sect = 0,
        .n_desc = macho.N_WEAK_DEF,
        .n_value = 0,
    };
    const global_index = self.getGlobalIndex("___dso_handle").?;
    if (global.getFile()) |file| {
        const global_object = &self.objects.items[file];
        global_object.globals_lookup[global.sym_index] = global_index;
    }
    global.* = sym_loc;
    _ = self.unresolved.swapRemove(self.getGlobalIndex("___dso_handle").?);
}

pub fn resolveSymbols(self: *MachO) !void {
    // We add the specified entrypoint as the first unresolved symbols so that
    // we search for it in libraries should there be no object files specified
    // on the linker line.
    if (self.base.options.output_mode == .Exe) {
        const entry_name = self.base.options.entry orelse load_commands.default_entry_point;
        _ = try self.addUndefined(entry_name, .{});
    }

    // Force resolution of any symbols requested by the user.
    for (self.base.options.force_undefined_symbols.keys()) |sym_name| {
        _ = try self.addUndefined(sym_name, .{});
    }

    for (self.objects.items, 0..) |_, object_id| {
        try self.resolveSymbolsInObject(@as(u32, @intCast(object_id)));
    }

    try self.resolveSymbolsInArchives();

    // Finally, force resolution of dyld_stub_binder if there are imports
    // requested.
    if (self.unresolved.count() > 0 and self.dyld_stub_binder_index == null) {
        self.dyld_stub_binder_index = try self.addUndefined("dyld_stub_binder", .{ .add_got = true });
    }
    if (!self.base.options.single_threaded and self.mode == .incremental) {
        _ = try self.addUndefined("__tlv_bootstrap", .{});
    }

    try self.resolveSymbolsInDylibs();

    try self.createMhExecuteHeaderSymbol();
    try self.createDsoHandleSymbol();
    try self.resolveSymbolsAtLoading();
}

fn resolveGlobalSymbol(self: *MachO, current: SymbolWithLoc) !void {
    const gpa = self.base.allocator;
    const sym = self.getSymbol(current);
    const sym_name = self.getSymbolName(current);

    const gop = try self.getOrPutGlobalPtr(sym_name);
    if (!gop.found_existing) {
        gop.value_ptr.* = current;
        if (sym.undf() and !sym.tentative()) {
            try self.unresolved.putNoClobber(gpa, self.getGlobalIndex(sym_name).?, {});
        }
        return;
    }
    const global_index = self.getGlobalIndex(sym_name).?;
    const global = gop.value_ptr.*;
    const global_sym = self.getSymbol(global);

    // Cases to consider: sym vs global_sym
    // 1.  strong(sym) and strong(global_sym) => error
    // 2.  strong(sym) and weak(global_sym) => sym
    // 3.  strong(sym) and tentative(global_sym) => sym
    // 4.  strong(sym) and undf(global_sym) => sym
    // 5.  weak(sym) and strong(global_sym) => global_sym
    // 6.  weak(sym) and tentative(global_sym) => sym
    // 7.  weak(sym) and undf(global_sym) => sym
    // 8.  tentative(sym) and strong(global_sym) => global_sym
    // 9.  tentative(sym) and weak(global_sym) => global_sym
    // 10. tentative(sym) and tentative(global_sym) => pick larger
    // 11. tentative(sym) and undf(global_sym) => sym
    // 12. undf(sym) and * => global_sym
    //
    // Reduces to:
    // 1. strong(sym) and strong(global_sym) => error
    // 2. * and strong(global_sym) => global_sym
    // 3. weak(sym) and weak(global_sym) => global_sym
    // 4. tentative(sym) and tentative(global_sym) => pick larger
    // 5. undf(sym) and * => global_sym
    // 6. else => sym

    const sym_is_strong = sym.sect() and !(sym.weakDef() or sym.pext());
    const global_is_strong = global_sym.sect() and !(global_sym.weakDef() or global_sym.pext());
    const sym_is_weak = sym.sect() and (sym.weakDef() or sym.pext());
    const global_is_weak = global_sym.sect() and (global_sym.weakDef() or global_sym.pext());

    if (sym_is_strong and global_is_strong) {
        // TODO redo this logic with corresponding logic in updateExports to avoid this
        // ugly check.
        if (self.mode == .zld) {
            try self.reportSymbolCollision(global, current);
        }
        return error.MultipleSymbolDefinitions;
    }

    if (current.getFile()) |file| {
        const object = &self.objects.items[file];
        object.globals_lookup[current.sym_index] = global_index;
    }

    if (global_is_strong) return;
    if (sym_is_weak and global_is_weak) return;
    if (sym.tentative() and global_sym.tentative()) {
        if (global_sym.n_value >= sym.n_value) return;
    }
    if (sym.undf() and !sym.tentative()) return;

    if (global.getFile()) |file| {
        const global_object = &self.objects.items[file];
        global_object.globals_lookup[global.sym_index] = global_index;
    }
    _ = self.unresolved.swapRemove(global_index);

    gop.value_ptr.* = current;
}

fn resolveSymbolsInObject(self: *MachO, object_id: u32) !void {
    const object = &self.objects.items[object_id];
    const in_symtab = object.in_symtab orelse return;

    log.debug("resolving symbols in '{s}'", .{object.name});

    var sym_index: u32 = 0;
    while (sym_index < in_symtab.len) : (sym_index += 1) {
        const sym = &object.symtab[sym_index];
        const sym_name = object.getSymbolName(sym_index);
        const sym_with_loc = SymbolWithLoc{
            .sym_index = sym_index,
            .file = object_id + 1,
        };

        if (sym.stab() or sym.indr() or sym.abs()) {
            try self.reportUnhandledSymbolType(sym_with_loc);
            continue;
        }

        if (sym.sect() and !sym.ext()) {
            log.debug("symbol '{s}' local to object {s}; skipping...", .{
                sym_name,
                object.name,
            });
            continue;
        }

        self.resolveGlobalSymbol(.{
            .sym_index = sym_index,
            .file = object_id + 1,
        }) catch |err| switch (err) {
            error.MultipleSymbolDefinitions => return error.FlushFailure,
            else => |e| return e,
        };
    }
}

fn resolveSymbolsInArchives(self: *MachO) !void {
    if (self.archives.items.len == 0) return;

    const gpa = self.base.allocator;
    var next_sym: usize = 0;
    loop: while (next_sym < self.unresolved.count()) {
        const global = self.globals.items[self.unresolved.keys()[next_sym]];
        const sym_name = self.getSymbolName(global);

        for (self.archives.items) |archive| {
            // Check if the entry exists in a static archive.
            const offsets = archive.toc.get(sym_name) orelse {
                // No hit.
                continue;
            };
            assert(offsets.items.len > 0);

            const object_id = @as(u16, @intCast(self.objects.items.len));
            const object = try archive.parseObject(gpa, offsets.items[0]);
            try self.objects.append(gpa, object);
            try self.resolveSymbolsInObject(object_id);

            continue :loop;
        }

        next_sym += 1;
    }
}

fn resolveSymbolsInDylibs(self: *MachO) !void {
    if (self.dylibs.items.len == 0) return;

    const gpa = self.base.allocator;
    var next_sym: usize = 0;
    loop: while (next_sym < self.unresolved.count()) {
        const global_index = self.unresolved.keys()[next_sym];
        const global = self.globals.items[global_index];
        const sym = self.getSymbolPtr(global);
        const sym_name = self.getSymbolName(global);

        for (self.dylibs.items, 0..) |dylib, id| {
            if (!dylib.symbols.contains(sym_name)) continue;

            const dylib_id = @as(u16, @intCast(id));
            if (!self.referenced_dylibs.contains(dylib_id)) {
                try self.referenced_dylibs.putNoClobber(gpa, dylib_id, {});
            }

            const ordinal = self.referenced_dylibs.getIndex(dylib_id) orelse unreachable;
            sym.n_type |= macho.N_EXT;
            sym.n_desc = @as(u16, @intCast(ordinal + 1)) * macho.N_SYMBOL_RESOLVER;

            if (dylib.weak) {
                sym.n_desc |= macho.N_WEAK_REF;
            }

            _ = self.unresolved.swapRemove(global_index);

            continue :loop;
        }

        next_sym += 1;
    }
}

fn resolveSymbolsAtLoading(self: *MachO) !void {
    const is_lib = self.base.options.output_mode == .Lib;
    const is_dyn_lib = self.base.options.link_mode == .Dynamic and is_lib;
    const allow_undef = is_dyn_lib and (self.base.options.allow_shlib_undefined orelse false);

    var next_sym: usize = 0;
    while (next_sym < self.unresolved.count()) {
        const global_index = self.unresolved.keys()[next_sym];
        const global = self.globals.items[global_index];
        const sym = self.getSymbolPtr(global);

        if (sym.discarded()) {
            sym.* = .{
                .n_strx = 0,
                .n_type = macho.N_UNDF,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            };
            _ = self.unresolved.swapRemove(global_index);
            continue;
        } else if (allow_undef) {
            const n_desc = @as(
                u16,
                @bitCast(macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP * @as(i16, @intCast(macho.N_SYMBOL_RESOLVER))),
            );
            sym.n_type = macho.N_EXT;
            sym.n_desc = n_desc;
            _ = self.unresolved.swapRemove(global_index);
            continue;
        }

        next_sym += 1;
    }
}

pub fn deinit(self: *MachO) void {
    const gpa = self.base.allocator;

    if (self.llvm_object) |llvm_object| llvm_object.destroy(gpa);

    if (self.d_sym) |*d_sym| {
        d_sym.deinit();
    }

    self.got_table.deinit(gpa);
    self.stub_table.deinit(gpa);
    self.tlv_ptr_table.deinit(gpa);
    self.thunk_table.deinit(gpa);

    for (self.thunks.items) |*thunk| {
        thunk.deinit(gpa);
    }
    self.thunks.deinit(gpa);

    self.strtab.deinit(gpa);
    self.locals.deinit(gpa);
    self.globals.deinit(gpa);
    self.locals_free_list.deinit(gpa);
    self.globals_free_list.deinit(gpa);
    self.unresolved.deinit(gpa);

    {
        var it = self.resolver.keyIterator();
        while (it.next()) |key_ptr| {
            gpa.free(key_ptr.*);
        }
        self.resolver.deinit(gpa);
    }

    for (self.objects.items) |*object| {
        object.deinit(gpa);
    }
    self.objects.deinit(gpa);
    for (self.archives.items) |*archive| {
        archive.deinit(gpa);
    }
    self.archives.deinit(gpa);
    for (self.dylibs.items) |*dylib| {
        dylib.deinit(gpa);
    }
    self.dylibs.deinit(gpa);
    self.dylibs_map.deinit(gpa);
    self.referenced_dylibs.deinit(gpa);

    self.segments.deinit(gpa);

    for (self.sections.items(.free_list)) |*list| {
        list.deinit(gpa);
    }
    self.sections.deinit(gpa);

    self.atoms.deinit(gpa);

    for (self.decls.values()) |*m| {
        m.exports.deinit(gpa);
    }
    self.decls.deinit(gpa);

    self.lazy_syms.deinit(gpa);
    self.tlv_table.deinit(gpa);

    for (self.unnamed_const_atoms.values()) |*atoms| {
        atoms.deinit(gpa);
    }
    self.unnamed_const_atoms.deinit(gpa);

    {
        var it = self.anon_decls.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(gpa);
        }
        self.anon_decls.deinit(gpa);
    }

    self.atom_by_index_table.deinit(gpa);

    for (self.relocs.values()) |*relocs| {
        relocs.deinit(gpa);
    }
    self.relocs.deinit(gpa);
    self.actions.deinit(gpa);

    for (self.rebases.values()) |*rebases| {
        rebases.deinit(gpa);
    }
    self.rebases.deinit(gpa);

    for (self.bindings.values()) |*bindings| {
        bindings.deinit(gpa);
    }
    self.bindings.deinit(gpa);

    for (self.misc_errors.items) |*err| {
        err.deinit(gpa);
    }
    self.misc_errors.deinit(gpa);
}

fn freeAtom(self: *MachO, atom_index: Atom.Index) void {
    const gpa = self.base.allocator;
    log.debug("freeAtom {d}", .{atom_index});

    // Remove any relocs and base relocs associated with this Atom
    Atom.freeRelocations(self, atom_index);

    const atom = self.getAtom(atom_index);
    const sect_id = atom.getSymbol(self).n_sect - 1;
    const free_list = &self.sections.items(.free_list)[sect_id];
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn free_list into a hash map
        while (i < free_list.items.len) {
            if (free_list.items[i] == atom_index) {
                _ = free_list.swapRemove(i);
                continue;
            }
            if (free_list.items[i] == atom.prev_index) {
                already_have_free_list_node = true;
            }
            i += 1;
        }
    }

    const maybe_last_atom_index = &self.sections.items(.last_atom_index)[sect_id];
    if (maybe_last_atom_index.*) |last_atom_index| {
        if (last_atom_index == atom_index) {
            if (atom.prev_index) |prev_index| {
                // TODO shrink the section size here
                maybe_last_atom_index.* = prev_index;
            } else {
                maybe_last_atom_index.* = null;
            }
        }
    }

    if (atom.prev_index) |prev_index| {
        const prev = self.getAtomPtr(prev_index);
        prev.next_index = atom.next_index;

        if (!already_have_free_list_node and prev.*.freeListEligible(self)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can ignore
            // the OOM here.
            free_list.append(gpa, prev_index) catch {};
        }
    } else {
        self.getAtomPtr(atom_index).prev_index = null;
    }

    if (atom.next_index) |next_index| {
        self.getAtomPtr(next_index).prev_index = atom.prev_index;
    } else {
        self.getAtomPtr(atom_index).next_index = null;
    }

    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    const sym_index = atom.getSymbolIndex().?;

    self.locals_free_list.append(gpa, sym_index) catch {};

    // Try freeing GOT atom if this decl had one
    self.got_table.freeEntry(gpa, .{ .sym_index = sym_index });

    if (self.d_sym) |*d_sym| {
        d_sym.swapRemoveRelocs(sym_index);
    }

    self.locals.items[sym_index].n_type = 0;
    _ = self.atom_by_index_table.remove(sym_index);
    log.debug("  adding local symbol index {d} to free list", .{sym_index});
    self.getAtomPtr(atom_index).sym_index = 0;
}

fn shrinkAtom(self: *MachO, atom_index: Atom.Index, new_block_size: u64) void {
    _ = self;
    _ = atom_index;
    _ = new_block_size;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn growAtom(self: *MachO, atom_index: Atom.Index, new_atom_size: u64, alignment: Alignment) !u64 {
    const atom = self.getAtom(atom_index);
    const sym = atom.getSymbol(self);
    const align_ok = alignment.check(sym.n_value);
    const need_realloc = !align_ok or new_atom_size > atom.capacity(self);
    if (!need_realloc) return sym.n_value;
    return self.allocateAtom(atom_index, new_atom_size, alignment);
}

pub fn allocateSymbol(self: *MachO) !u32 {
    try self.locals.ensureUnusedCapacity(self.base.allocator, 1);

    const index = blk: {
        if (self.locals_free_list.popOrNull()) |index| {
            log.debug("  (reusing symbol index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{self.locals.items.len});
            const index = @as(u32, @intCast(self.locals.items.len));
            _ = self.locals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.locals.items[index] = .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };

    return index;
}

fn allocateGlobal(self: *MachO) !u32 {
    try self.globals.ensureUnusedCapacity(self.base.allocator, 1);

    const index = blk: {
        if (self.globals_free_list.popOrNull()) |index| {
            log.debug("  (reusing global index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{self.globals.items.len});
            const index = @as(u32, @intCast(self.globals.items.len));
            _ = self.globals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.globals.items[index] = .{ .sym_index = 0 };

    return index;
}

pub fn addGotEntry(self: *MachO, target: SymbolWithLoc) !void {
    if (self.got_table.lookup.contains(target)) return;
    const got_index = try self.got_table.allocateEntry(self.base.allocator, target);
    if (self.got_section_index == null) {
        self.got_section_index = try self.initSection("__DATA_CONST", "__got", .{
            .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
        });
    }
    if (self.mode == .incremental) {
        try self.writeOffsetTableEntry(got_index);
        self.got_table_count_dirty = true;
        self.markRelocsDirtyByTarget(target);
    }
}

pub fn addStubEntry(self: *MachO, target: SymbolWithLoc) !void {
    if (self.stub_table.lookup.contains(target)) return;
    const stub_index = try self.stub_table.allocateEntry(self.base.allocator, target);
    if (self.stubs_section_index == null) {
        self.stubs_section_index = try self.initSection("__TEXT", "__stubs", .{
            .flags = macho.S_SYMBOL_STUBS |
                macho.S_ATTR_PURE_INSTRUCTIONS |
                macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved2 = stubs.stubSize(self.base.options.target.cpu.arch),
        });
        self.stub_helper_section_index = try self.initSection("__TEXT", "__stub_helper", .{
            .flags = macho.S_REGULAR |
                macho.S_ATTR_PURE_INSTRUCTIONS |
                macho.S_ATTR_SOME_INSTRUCTIONS,
        });
        self.la_symbol_ptr_section_index = try self.initSection("__DATA", "__la_symbol_ptr", .{
            .flags = macho.S_LAZY_SYMBOL_POINTERS,
        });
    }
    if (self.mode == .incremental) {
        try self.writeStubTableEntry(stub_index);
        self.stub_table_count_dirty = true;
        self.markRelocsDirtyByTarget(target);
    }
}

pub fn addTlvPtrEntry(self: *MachO, target: SymbolWithLoc) !void {
    if (self.tlv_ptr_table.lookup.contains(target)) return;
    _ = try self.tlv_ptr_table.allocateEntry(self.base.allocator, target);
    if (self.tlv_ptr_section_index == null) {
        self.tlv_ptr_section_index = try self.initSection("__DATA", "__thread_ptrs", .{
            .flags = macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
        });
    }
}

pub fn updateFunc(self: *MachO, mod: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(mod, func_index, air, liveness);
    const tracy = trace(@src());
    defer tracy.end();

    const func = mod.funcInfo(func_index);
    const decl_index = func.owner_decl;
    const decl = mod.declPtr(decl_index);

    const atom_index = try self.getOrCreateAtomForDecl(decl_index);
    self.freeUnnamedConsts(decl_index);
    Atom.freeRelocations(self, atom_index);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(mod, decl_index)
    else
        null;
    defer if (decl_state) |*ds| ds.deinit();

    const res = if (decl_state) |*ds|
        try codegen.generateFunction(&self.base, decl.srcLoc(mod), func_index, air, liveness, &code_buffer, .{
            .dwarf = ds,
        })
    else
        try codegen.generateFunction(&self.base, decl.srcLoc(mod), func_index, air, liveness, &code_buffer, .none);

    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            return;
        },
    };

    const addr = try self.updateDeclCode(decl_index, code);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            mod,
            decl_index,
            addr,
            self.getAtom(atom_index).size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    try self.updateExports(mod, .{ .decl_index = decl_index }, mod.getDeclExports(decl_index));
}

pub fn lowerUnnamedConst(self: *MachO, typed_value: TypedValue, decl_index: Module.Decl.Index) !u32 {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const gop = try self.unnamed_const_atoms.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const unnamed_consts = gop.value_ptr;
    const decl = mod.declPtr(decl_index);
    const decl_name = mod.intern_pool.stringToSlice(try decl.getFullyQualifiedName(mod));
    const index = unnamed_consts.items.len;
    const name = try std.fmt.allocPrint(gpa, "___unnamed_{s}_{d}", .{ decl_name, index });
    defer gpa.free(name);
    const atom_index = switch (try self.lowerConst(name, typed_value, typed_value.ty.abiAlignment(mod), self.data_const_section_index.?, decl.srcLoc(mod))) {
        .ok => |atom_index| atom_index,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            log.debug("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };
    try unnamed_consts.append(gpa, atom_index);
    const atom = self.getAtomPtr(atom_index);
    return atom.getSymbolIndex().?;
}

const LowerConstResult = union(enum) {
    ok: Atom.Index,
    fail: *Module.ErrorMsg,
};

fn lowerConst(
    self: *MachO,
    name: []const u8,
    tv: TypedValue,
    required_alignment: InternPool.Alignment,
    sect_id: u8,
    src_loc: Module.SrcLoc,
) !LowerConstResult {
    const gpa = self.base.allocator;

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    log.debug("allocating symbol indexes for {s}", .{name});

    const sym_index = try self.allocateSymbol();
    const atom_index = try self.createAtom(sym_index, .{});
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom_index);

    const res = try codegen.generateSymbol(&self.base, src_loc, tv, &code_buffer, .none, .{
        .parent_atom_index = self.getAtom(atom_index).getSymbolIndex().?,
    });
    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| return .{ .fail = em },
    };

    const atom = self.getAtomPtr(atom_index);
    atom.size = code.len;
    // TODO: work out logic for disambiguating functions from function pointers
    // const sect_id = self.getDeclOutputSection(decl_index);
    const symbol = atom.getSymbolPtr(self);
    const name_str_index = try self.strtab.insert(gpa, name);
    symbol.n_strx = name_str_index;
    symbol.n_type = macho.N_SECT;
    symbol.n_sect = sect_id + 1;
    symbol.n_value = try self.allocateAtom(atom_index, code.len, required_alignment);
    errdefer self.freeAtom(atom_index);

    log.debug("allocated atom for {s} at 0x{x}", .{ name, symbol.n_value });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    try self.writeAtom(atom_index, code);
    self.markRelocsDirtyByTarget(atom.getSymbolWithLoc());

    return .{ .ok = atom_index };
}

pub fn updateDecl(self: *MachO, mod: *Module, decl_index: Module.Decl.Index) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(mod, decl_index);
    const tracy = trace(@src());
    defer tracy.end();

    const decl = mod.declPtr(decl_index);

    if (decl.val.getExternFunc(mod)) |_| {
        return;
    }

    if (decl.isExtern(mod)) {
        // TODO make this part of getGlobalSymbol
        const name = mod.intern_pool.stringToSlice(decl.name);
        const sym_name = try std.fmt.allocPrint(self.base.allocator, "_{s}", .{name});
        defer self.base.allocator.free(sym_name);
        _ = try self.addUndefined(sym_name, .{ .add_got = true });
        return;
    }

    const is_threadlocal = if (decl.val.getVariable(mod)) |variable|
        variable.is_threadlocal and !self.base.options.single_threaded
    else
        false;
    if (is_threadlocal) return self.updateThreadlocalVariable(mod, decl_index);

    const atom_index = try self.getOrCreateAtomForDecl(decl_index);
    const sym_index = self.getAtom(atom_index).getSymbolIndex().?;
    Atom.freeRelocations(self, atom_index);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(mod, decl_index)
    else
        null;
    defer if (decl_state) |*ds| ds.deinit();

    const decl_val = if (decl.val.getVariable(mod)) |variable| variable.init.toValue() else decl.val;
    const res = if (decl_state) |*ds|
        try codegen.generateSymbol(&self.base, decl.srcLoc(mod), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .{
            .dwarf = ds,
        }, .{
            .parent_atom_index = sym_index,
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(mod), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .none, .{
            .parent_atom_index = sym_index,
        });

    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            return;
        },
    };
    const addr = try self.updateDeclCode(decl_index, code);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            mod,
            decl_index,
            addr,
            self.getAtom(atom_index).size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    try self.updateExports(mod, .{ .decl_index = decl_index }, mod.getDeclExports(decl_index));
}

fn updateLazySymbolAtom(
    self: *MachO,
    sym: File.LazySymbol,
    atom_index: Atom.Index,
    section_index: u8,
) !void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;

    var required_alignment: Alignment = .none;
    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const name_str_index = blk: {
        const name = try std.fmt.allocPrint(gpa, "___lazy_{s}_{}", .{
            @tagName(sym.kind),
            sym.ty.fmt(mod),
        });
        defer gpa.free(name);
        break :blk try self.strtab.insert(gpa, name);
    };
    const name = self.strtab.get(name_str_index).?;

    const atom = self.getAtomPtr(atom_index);
    const local_sym_index = atom.getSymbolIndex().?;

    const src = if (sym.ty.getOwnerDeclOrNull(mod)) |owner_decl|
        mod.declPtr(owner_decl).srcLoc(mod)
    else
        Module.SrcLoc{
            .file_scope = undefined,
            .parent_decl_node = undefined,
            .lazy = .unneeded,
        };
    const res = try codegen.generateLazySymbol(
        &self.base,
        src,
        sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .parent_atom_index = local_sym_index },
    );
    const code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            log.debug("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };

    const symbol = atom.getSymbolPtr(self);
    symbol.n_strx = name_str_index;
    symbol.n_type = macho.N_SECT;
    symbol.n_sect = section_index + 1;
    symbol.n_desc = 0;

    const vaddr = try self.allocateAtom(atom_index, code.len, required_alignment);
    errdefer self.freeAtom(atom_index);

    log.debug("allocated atom for {s} at 0x{x}", .{ name, vaddr });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    atom.size = code.len;
    symbol.n_value = vaddr;

    try self.addGotEntry(.{ .sym_index = local_sym_index });
    try self.writeAtom(atom_index, code);
}

pub fn getOrCreateAtomForLazySymbol(self: *MachO, sym: File.LazySymbol) !Atom.Index {
    const mod = self.base.options.module.?;
    const gop = try self.lazy_syms.getOrPut(self.base.allocator, sym.getDecl(mod));
    errdefer _ = if (!gop.found_existing) self.lazy_syms.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const metadata: struct { atom: *Atom.Index, state: *LazySymbolMetadata.State } = switch (sym.kind) {
        .code => .{ .atom = &gop.value_ptr.text_atom, .state = &gop.value_ptr.text_state },
        .const_data => .{
            .atom = &gop.value_ptr.data_const_atom,
            .state = &gop.value_ptr.data_const_state,
        },
    };
    switch (metadata.state.*) {
        .unused => {
            const sym_index = try self.allocateSymbol();
            metadata.atom.* = try self.createAtom(sym_index, .{});
            try self.atom_by_index_table.putNoClobber(self.base.allocator, sym_index, metadata.atom.*);
        },
        .pending_flush => return metadata.atom.*,
        .flushed => {},
    }
    metadata.state.* = .pending_flush;
    const atom = metadata.atom.*;
    // anyerror needs to be deferred until flushModule
    if (sym.getDecl(mod) != .none) try self.updateLazySymbolAtom(sym, atom, switch (sym.kind) {
        .code => self.text_section_index.?,
        .const_data => self.data_const_section_index.?,
    });
    return atom;
}

fn updateThreadlocalVariable(self: *MachO, module: *Module, decl_index: Module.Decl.Index) !void {
    const mod = self.base.options.module.?;
    // Lowering a TLV on macOS involves two stages:
    // 1. first we lower the initializer into appopriate section (__thread_data or __thread_bss)
    // 2. next, we create a corresponding threadlocal variable descriptor in __thread_vars

    // 1. Lower the initializer value.
    const init_atom_index = try self.getOrCreateAtomForDecl(decl_index);
    const init_atom = self.getAtomPtr(init_atom_index);
    const init_sym_index = init_atom.getSymbolIndex().?;
    Atom.freeRelocations(self, init_atom_index);

    const gpa = self.base.allocator;

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(module, decl_index)
    else
        null;
    defer if (decl_state) |*ds| ds.deinit();

    const decl = module.declPtr(decl_index);
    const decl_metadata = self.decls.get(decl_index).?;
    const decl_val = decl.val.getVariable(mod).?.init.toValue();
    const res = if (decl_state) |*ds|
        try codegen.generateSymbol(&self.base, decl.srcLoc(mod), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .{
            .dwarf = ds,
        }, .{
            .parent_atom_index = init_sym_index,
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(mod), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .none, .{
            .parent_atom_index = init_sym_index,
        });

    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };

    const required_alignment = decl.getAlignment(mod);

    const decl_name = mod.intern_pool.stringToSlice(try decl.getFullyQualifiedName(module));

    const init_sym_name = try std.fmt.allocPrint(gpa, "{s}$tlv$init", .{decl_name});
    defer gpa.free(init_sym_name);

    const sect_id = decl_metadata.section;
    const init_sym = init_atom.getSymbolPtr(self);
    init_sym.n_strx = try self.strtab.insert(gpa, init_sym_name);
    init_sym.n_type = macho.N_SECT;
    init_sym.n_sect = sect_id + 1;
    init_sym.n_desc = 0;
    init_atom.size = code.len;

    init_sym.n_value = try self.allocateAtom(init_atom_index, code.len, required_alignment);
    errdefer self.freeAtom(init_atom_index);

    log.debug("allocated atom for {s} at 0x{x}", .{ init_sym_name, init_sym.n_value });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    try self.writeAtom(init_atom_index, code);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            module,
            decl_index,
            init_sym.n_value,
            self.getAtom(init_atom_index).size,
            ds,
        );
    }

    try self.updateExports(module, .{ .decl_index = decl_index }, module.getDeclExports(decl_index));

    // 2. Create a TLV descriptor.
    const init_atom_sym_loc = init_atom.getSymbolWithLoc();
    const gop = try self.tlv_table.getOrPut(gpa, init_atom_sym_loc);
    assert(!gop.found_existing);
    gop.value_ptr.* = try self.createThreadLocalDescriptorAtom(decl_name, init_atom_sym_loc);
    self.markRelocsDirtyByTarget(init_atom_sym_loc);
}

pub fn getOrCreateAtomForDecl(self: *MachO, decl_index: Module.Decl.Index) !Atom.Index {
    const gop = try self.decls.getOrPut(self.base.allocator, decl_index);
    if (!gop.found_existing) {
        const sym_index = try self.allocateSymbol();
        const atom_index = try self.createAtom(sym_index, .{});
        try self.atom_by_index_table.putNoClobber(self.base.allocator, sym_index, atom_index);
        gop.value_ptr.* = .{
            .atom = atom_index,
            .section = self.getDeclOutputSection(decl_index),
            .exports = .{},
        };
    }
    return gop.value_ptr.atom;
}

fn getDeclOutputSection(self: *MachO, decl_index: Module.Decl.Index) u8 {
    const decl = self.base.options.module.?.declPtr(decl_index);
    const ty = decl.ty;
    const val = decl.val;
    const mod = self.base.options.module.?;
    const zig_ty = ty.zigTypeTag(mod);
    const mode = self.base.options.optimize_mode;
    const single_threaded = self.base.options.single_threaded;
    const sect_id: u8 = blk: {
        // TODO finish and audit this function
        if (val.isUndefDeep(mod)) {
            if (mode == .ReleaseFast or mode == .ReleaseSmall) {
                @panic("TODO __DATA,__bss");
            } else {
                break :blk self.data_section_index.?;
            }
        }

        if (val.getVariable(mod)) |variable| {
            if (variable.is_threadlocal and !single_threaded) {
                break :blk self.thread_data_section_index.?;
            }
            break :blk self.data_section_index.?;
        }

        switch (zig_ty) {
            // TODO: what if this is a function pointer?
            .Fn => break :blk self.text_section_index.?,
            else => {
                if (val.getVariable(mod)) |_| {
                    break :blk self.data_section_index.?;
                }
                break :blk self.data_const_section_index.?;
            },
        }
    };
    return sect_id;
}

fn updateDeclCode(self: *MachO, decl_index: Module.Decl.Index, code: []u8) !u64 {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const required_alignment = decl.getAlignment(mod);

    const decl_name = mod.intern_pool.stringToSlice(try decl.getFullyQualifiedName(mod));

    const decl_metadata = self.decls.get(decl_index).?;
    const atom_index = decl_metadata.atom;
    const atom = self.getAtom(atom_index);
    const sym_index = atom.getSymbolIndex().?;
    const sect_id = decl_metadata.section;
    const header = &self.sections.items(.header)[sect_id];
    const segment = self.getSegment(sect_id);
    const code_len = code.len;

    if (atom.size != 0) {
        const sym = atom.getSymbolPtr(self);
        sym.n_strx = try self.strtab.insert(gpa, decl_name);
        sym.n_type = macho.N_SECT;
        sym.n_sect = sect_id + 1;
        sym.n_desc = 0;

        const capacity = atom.capacity(self);
        const need_realloc = code_len > capacity or !required_alignment.check(sym.n_value);

        if (need_realloc) {
            const vaddr = try self.growAtom(atom_index, code_len, required_alignment);
            log.debug("growing {s} and moving from 0x{x} to 0x{x}", .{ decl_name, sym.n_value, vaddr });
            log.debug("  (required alignment 0x{x})", .{required_alignment});

            if (vaddr != sym.n_value) {
                sym.n_value = vaddr;
                log.debug("  (updating GOT entry)", .{});
                const got_atom_index = self.got_table.lookup.get(.{ .sym_index = sym_index }).?;
                try self.writeOffsetTableEntry(got_atom_index);
                self.markRelocsDirtyByTarget(.{ .sym_index = sym_index });
            }
        } else if (code_len < atom.size) {
            self.shrinkAtom(atom_index, code_len);
        } else if (atom.next_index == null) {
            const needed_size = (sym.n_value + code_len) - segment.vmaddr;
            header.size = needed_size;
        }
        self.getAtomPtr(atom_index).size = code_len;
    } else {
        const sym = atom.getSymbolPtr(self);
        sym.n_strx = try self.strtab.insert(gpa, decl_name);
        sym.n_type = macho.N_SECT;
        sym.n_sect = sect_id + 1;
        sym.n_desc = 0;

        const vaddr = try self.allocateAtom(atom_index, code_len, required_alignment);
        errdefer self.freeAtom(atom_index);

        log.debug("allocated atom for {s} at 0x{x}", .{ decl_name, vaddr });
        log.debug("  (required alignment 0x{x})", .{required_alignment});

        self.getAtomPtr(atom_index).size = code_len;
        sym.n_value = vaddr;

        try self.addGotEntry(.{ .sym_index = sym_index });
    }

    try self.writeAtom(atom_index, code);

    return atom.getSymbol(self).n_value;
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl_index: Module.Decl.Index) !void {
    if (self.d_sym) |*d_sym| {
        try d_sym.dwarf.updateDeclLineNumber(module, decl_index);
    }
}

pub fn updateExports(
    self: *MachO,
    mod: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) File.UpdateExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object|
        return llvm_object.updateExports(mod, exported, exports);

    if (self.base.options.emit == null) return;

    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;

    const metadata = switch (exported) {
        .decl_index => |decl_index| blk: {
            _ = try self.getOrCreateAtomForDecl(decl_index);
            break :blk self.decls.getPtr(decl_index).?;
        },
        .value => |value| self.anon_decls.getPtr(value) orelse blk: {
            const first_exp = exports[0];
            const res = try self.lowerAnonDecl(value, .none, first_exp.getSrcLoc(mod));
            switch (res) {
                .ok => {},
                .fail => |em| {
                    // TODO maybe it's enough to return an error here and let Module.processExportsInner
                    // handle the error?
                    try mod.failed_exports.ensureUnusedCapacity(mod.gpa, 1);
                    mod.failed_exports.putAssumeCapacityNoClobber(first_exp, em);
                    return;
                },
            }
            break :blk self.anon_decls.getPtr(value).?;
        },
    };
    const atom_index = metadata.atom;
    const atom = self.getAtom(atom_index);
    const sym = atom.getSymbol(self);

    for (exports) |exp| {
        const exp_name = try std.fmt.allocPrint(gpa, "_{}", .{
            exp.opts.name.fmt(&mod.intern_pool),
        });
        defer gpa.free(exp_name);

        log.debug("adding new export '{s}'", .{exp_name});

        if (exp.opts.section.unwrap()) |section_name| {
            if (!mod.intern_pool.stringEqlSlice(section_name, "__text")) {
                try mod.failed_exports.putNoClobber(mod.gpa, exp, try Module.ErrorMsg.create(
                    gpa,
                    exp.getSrcLoc(mod),
                    "Unimplemented: ExportOptions.section",
                    .{},
                ));
                continue;
            }
        }

        if (exp.opts.linkage == .LinkOnce) {
            try mod.failed_exports.putNoClobber(mod.gpa, exp, try Module.ErrorMsg.create(
                gpa,
                exp.getSrcLoc(mod),
                "Unimplemented: GlobalLinkage.LinkOnce",
                .{},
            ));
            continue;
        }

        const global_sym_index = metadata.getExport(self, exp_name) orelse blk: {
            const global_sym_index = if (self.getGlobalIndex(exp_name)) |global_index| ind: {
                const global = self.globals.items[global_index];
                // TODO this is just plain wrong as it all should happen in a single `resolveSymbols`
                // pass. This will go away once we abstact away Zig's incremental compilation into
                // its own module.
                if (global.getFile() == null and self.getSymbol(global).undf()) {
                    _ = self.unresolved.swapRemove(global_index);
                    break :ind global.sym_index;
                }
                break :ind try self.allocateSymbol();
            } else try self.allocateSymbol();
            try metadata.exports.append(gpa, global_sym_index);
            break :blk global_sym_index;
        };
        const global_sym_loc = SymbolWithLoc{ .sym_index = global_sym_index };
        const global_sym = self.getSymbolPtr(global_sym_loc);
        global_sym.* = .{
            .n_strx = try self.strtab.insert(gpa, exp_name),
            .n_type = macho.N_SECT | macho.N_EXT,
            .n_sect = metadata.section + 1,
            .n_desc = 0,
            .n_value = sym.n_value,
        };

        switch (exp.opts.linkage) {
            .Internal => {
                // Symbol should be hidden, or in MachO lingo, private extern.
                // We should also mark the symbol as Weak: n_desc == N_WEAK_DEF.
                global_sym.n_type |= macho.N_PEXT;
                global_sym.n_desc |= macho.N_WEAK_DEF;
            },
            .Strong => {},
            .Weak => {
                // Weak linkage is specified as part of n_desc field.
                // Symbol's n_type is like for a symbol with strong linkage.
                global_sym.n_desc |= macho.N_WEAK_DEF;
            },
            else => unreachable,
        }

        self.resolveGlobalSymbol(global_sym_loc) catch |err| switch (err) {
            error.MultipleSymbolDefinitions => {
                // TODO: this needs rethinking
                const global = self.getGlobal(exp_name).?;
                if (global_sym_loc.sym_index != global.sym_index and global.getFile() != null) {
                    _ = try mod.failed_exports.put(mod.gpa, exp, try Module.ErrorMsg.create(
                        gpa,
                        exp.getSrcLoc(mod),
                        \\LinkError: symbol '{s}' defined multiple times
                    ,
                        .{exp_name},
                    ));
                }
            },
            else => |e| return e,
        };
    }
}

pub fn deleteDeclExport(
    self: *MachO,
    decl_index: Module.Decl.Index,
    name: InternPool.NullTerminatedString,
) Allocator.Error!void {
    if (self.llvm_object) |_| return;
    const metadata = self.decls.getPtr(decl_index) orelse return;

    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const exp_name = try std.fmt.allocPrint(gpa, "_{s}", .{mod.intern_pool.stringToSlice(name)});
    defer gpa.free(exp_name);
    const sym_index = metadata.getExportPtr(self, exp_name) orelse return;

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index.* };
    const sym = self.getSymbolPtr(sym_loc);
    log.debug("deleting export '{s}'", .{exp_name});
    assert(sym.sect() and sym.ext());
    sym.* = .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    self.locals_free_list.append(gpa, sym_index.*) catch {};

    if (self.resolver.fetchRemove(exp_name)) |entry| {
        defer gpa.free(entry.key);
        self.globals_free_list.append(gpa, entry.value) catch {};
        self.globals.items[entry.value] = .{ .sym_index = 0 };
    }

    sym_index.* = 0;
}

fn freeUnnamedConsts(self: *MachO, decl_index: Module.Decl.Index) void {
    const gpa = self.base.allocator;
    const unnamed_consts = self.unnamed_const_atoms.getPtr(decl_index) orelse return;
    for (unnamed_consts.items) |atom| {
        self.freeAtom(atom);
    }
    unnamed_consts.clearAndFree(gpa);
}

pub fn freeDecl(self: *MachO, decl_index: Module.Decl.Index) void {
    if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    log.debug("freeDecl {*}", .{decl});

    if (self.decls.fetchSwapRemove(decl_index)) |const_kv| {
        var kv = const_kv;
        self.freeAtom(kv.value.atom);
        self.freeUnnamedConsts(decl_index);
        kv.value.exports.deinit(self.base.allocator);
    }

    if (self.d_sym) |*d_sym| {
        d_sym.dwarf.freeDecl(decl_index);
    }
}

pub fn getDeclVAddr(self: *MachO, decl_index: Module.Decl.Index, reloc_info: File.RelocInfo) !u64 {
    assert(self.llvm_object == null);

    const this_atom_index = try self.getOrCreateAtomForDecl(decl_index);
    const sym_index = self.getAtom(this_atom_index).getSymbolIndex().?;
    const atom_index = self.getAtomIndexForSymbol(.{ .sym_index = reloc_info.parent_atom_index }).?;
    try Atom.addRelocation(self, atom_index, .{
        .type = .unsigned,
        .target = .{ .sym_index = sym_index },
        .offset = @as(u32, @intCast(reloc_info.offset)),
        .addend = reloc_info.addend,
        .pcrel = false,
        .length = 3,
    });
    try Atom.addRebase(self, atom_index, @as(u32, @intCast(reloc_info.offset)));

    return 0;
}

pub fn lowerAnonDecl(
    self: *MachO,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.SrcLoc,
) !codegen.Result {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;
    const ty = mod.intern_pool.typeOf(decl_val).toType();
    const decl_alignment = switch (explicit_alignment) {
        .none => ty.abiAlignment(mod),
        else => explicit_alignment,
    };
    if (self.anon_decls.get(decl_val)) |metadata| {
        const existing_addr = self.getAtom(metadata.atom).getSymbol(self).n_value;
        if (decl_alignment.check(existing_addr))
            return .ok;
    }

    const val = decl_val.toValue();
    const tv = TypedValue{ .ty = ty, .val = val };
    var name_buf: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "__anon_{d}", .{
        @intFromEnum(decl_val),
    }) catch unreachable;
    const res = self.lowerConst(
        name,
        tv,
        decl_alignment,
        self.data_const_section_index.?,
        src_loc,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Module.ErrorMsg.create(
            gpa,
            src_loc,
            "unable to lower constant value: {s}",
            .{@errorName(e)},
        ) },
    };
    const atom_index = switch (res) {
        .ok => |atom_index| atom_index,
        .fail => |em| return .{ .fail = em },
    };
    try self.anon_decls.put(gpa, decl_val, .{
        .atom = atom_index,
        .section = self.data_const_section_index.?,
    });
    return .ok;
}

pub fn getAnonDeclVAddr(self: *MachO, decl_val: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);

    const this_atom_index = self.anon_decls.get(decl_val).?.atom;
    const sym_index = self.getAtom(this_atom_index).getSymbolIndex().?;
    const atom_index = self.getAtomIndexForSymbol(.{ .sym_index = reloc_info.parent_atom_index }).?;
    try Atom.addRelocation(self, atom_index, .{
        .type = .unsigned,
        .target = .{ .sym_index = sym_index },
        .offset = @as(u32, @intCast(reloc_info.offset)),
        .addend = reloc_info.addend,
        .pcrel = false,
        .length = 3,
    });
    try Atom.addRebase(self, atom_index, @as(u32, @intCast(reloc_info.offset)));

    return 0;
}

fn populateMissingMetadata(self: *MachO) !void {
    assert(self.mode == .incremental);

    const gpa = self.base.allocator;
    const cpu_arch = self.base.options.target.cpu.arch;
    const pagezero_vmsize = self.calcPagezeroSize();

    if (self.pagezero_segment_cmd_index == null) {
        if (pagezero_vmsize > 0) {
            self.pagezero_segment_cmd_index = @as(u8, @intCast(self.segments.items.len));
            try self.segments.append(gpa, .{
                .segname = makeStaticString("__PAGEZERO"),
                .vmsize = pagezero_vmsize,
                .cmdsize = @sizeOf(macho.segment_command_64),
            });
        }
    }

    if (self.header_segment_cmd_index == null) {
        // The first __TEXT segment is immovable and covers MachO header and load commands.
        self.header_segment_cmd_index = @as(u8, @intCast(self.segments.items.len));
        const ideal_size = @max(self.base.options.headerpad_size orelse 0, default_headerpad_size);
        const needed_size = mem.alignForward(u64, padToIdeal(ideal_size), getPageSize(cpu_arch));

        log.debug("found __TEXT segment (header-only) free space 0x{x} to 0x{x}", .{ 0, needed_size });

        try self.segments.append(gpa, .{
            .segname = makeStaticString("__TEXT"),
            .vmaddr = pagezero_vmsize,
            .vmsize = needed_size,
            .filesize = needed_size,
            .maxprot = macho.PROT.READ | macho.PROT.EXEC,
            .initprot = macho.PROT.READ | macho.PROT.EXEC,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
        self.segment_table_dirty = true;
    }

    if (self.text_section_index == null) {
        // Sadly, segments need unique string identfiers for some reason.
        self.text_section_index = try self.allocateSection("__TEXT1", "__text", .{
            .size = self.base.options.program_code_size_hint,
            .alignment = switch (cpu_arch) {
                .x86_64 => 1,
                .aarch64 => @sizeOf(u32),
                else => unreachable, // unhandled architecture type
            },
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .prot = macho.PROT.READ | macho.PROT.EXEC,
        });
        self.segment_table_dirty = true;
    }

    if (self.stubs_section_index == null) {
        const stub_size = stubs.stubSize(cpu_arch);
        self.stubs_section_index = try self.allocateSection("__TEXT2", "__stubs", .{
            .size = stub_size,
            .alignment = stubs.stubAlignment(cpu_arch),
            .flags = macho.S_SYMBOL_STUBS | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved2 = stub_size,
            .prot = macho.PROT.READ | macho.PROT.EXEC,
        });
        self.segment_table_dirty = true;
    }

    if (self.stub_helper_section_index == null) {
        self.stub_helper_section_index = try self.allocateSection("__TEXT3", "__stub_helper", .{
            .size = @sizeOf(u32),
            .alignment = stubs.stubAlignment(cpu_arch),
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .prot = macho.PROT.READ | macho.PROT.EXEC,
        });
        self.segment_table_dirty = true;
    }

    if (self.got_section_index == null) {
        self.got_section_index = try self.allocateSection("__DATA_CONST", "__got", .{
            .size = @sizeOf(u64) * self.base.options.symbol_count_hint,
            .alignment = @alignOf(u64),
            .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
            .prot = macho.PROT.READ | macho.PROT.WRITE,
        });
        self.segment_table_dirty = true;
    }

    if (self.data_const_section_index == null) {
        self.data_const_section_index = try self.allocateSection("__DATA_CONST1", "__const", .{
            .size = @sizeOf(u64),
            .alignment = @alignOf(u64),
            .flags = macho.S_REGULAR,
            .prot = macho.PROT.READ | macho.PROT.WRITE,
        });
        self.segment_table_dirty = true;
    }

    if (self.la_symbol_ptr_section_index == null) {
        self.la_symbol_ptr_section_index = try self.allocateSection("__DATA", "__la_symbol_ptr", .{
            .size = @sizeOf(u64),
            .alignment = @alignOf(u64),
            .flags = macho.S_LAZY_SYMBOL_POINTERS,
            .prot = macho.PROT.READ | macho.PROT.WRITE,
        });
        self.segment_table_dirty = true;
    }

    if (self.data_section_index == null) {
        self.data_section_index = try self.allocateSection("__DATA1", "__data", .{
            .size = @sizeOf(u64),
            .alignment = @alignOf(u64),
            .flags = macho.S_REGULAR,
            .prot = macho.PROT.READ | macho.PROT.WRITE,
        });
        self.segment_table_dirty = true;
    }

    if (!self.base.options.single_threaded) {
        if (self.thread_vars_section_index == null) {
            self.thread_vars_section_index = try self.allocateSection("__DATA2", "__thread_vars", .{
                .size = @sizeOf(u64) * 3,
                .alignment = @sizeOf(u64),
                .flags = macho.S_THREAD_LOCAL_VARIABLES,
                .prot = macho.PROT.READ | macho.PROT.WRITE,
            });
            self.segment_table_dirty = true;
        }

        if (self.thread_data_section_index == null) {
            self.thread_data_section_index = try self.allocateSection("__DATA3", "__thread_data", .{
                .size = @sizeOf(u64),
                .alignment = @alignOf(u64),
                .flags = macho.S_THREAD_LOCAL_REGULAR,
                .prot = macho.PROT.READ | macho.PROT.WRITE,
            });
            self.segment_table_dirty = true;
        }
    }

    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @as(u8, @intCast(self.segments.items.len));

        try self.segments.append(gpa, .{
            .segname = makeStaticString("__LINKEDIT"),
            .maxprot = macho.PROT.READ,
            .initprot = macho.PROT.READ,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }
}

fn calcPagezeroSize(self: *MachO) u64 {
    const pagezero_vmsize = self.base.options.pagezero_size orelse default_pagezero_vmsize;
    const page_size = getPageSize(self.base.options.target.cpu.arch);
    const aligned_pagezero_vmsize = mem.alignBackward(u64, pagezero_vmsize, page_size);
    if (self.base.options.output_mode == .Lib) return 0;
    if (aligned_pagezero_vmsize == 0) return 0;
    if (aligned_pagezero_vmsize != pagezero_vmsize) {
        log.warn("requested __PAGEZERO size (0x{x}) is not page aligned", .{pagezero_vmsize});
        log.warn("  rounding down to 0x{x}", .{aligned_pagezero_vmsize});
    }
    return aligned_pagezero_vmsize;
}

const InitSectionOpts = struct {
    flags: u32 = macho.S_REGULAR,
    reserved1: u32 = 0,
    reserved2: u32 = 0,
};

pub fn initSection(self: *MachO, segname: []const u8, sectname: []const u8, opts: InitSectionOpts) !u8 {
    log.debug("creating section '{s},{s}'", .{ segname, sectname });
    const index = @as(u8, @intCast(self.sections.slice().len));
    try self.sections.append(self.base.allocator, .{
        .segment_index = undefined, // Segments will be created automatically later down the pipeline
        .header = .{
            .sectname = makeStaticString(sectname),
            .segname = makeStaticString(segname),
            .flags = opts.flags,
            .reserved1 = opts.reserved1,
            .reserved2 = opts.reserved2,
        },
    });
    return index;
}

fn allocateSection(self: *MachO, segname: []const u8, sectname: []const u8, opts: struct {
    size: u64 = 0,
    alignment: u32 = 0,
    prot: macho.vm_prot_t = macho.PROT.NONE,
    flags: u32 = macho.S_REGULAR,
    reserved2: u32 = 0,
}) !u8 {
    const gpa = self.base.allocator;
    const page_size = getPageSize(self.base.options.target.cpu.arch);
    // In incremental context, we create one section per segment pairing. This way,
    // we can move the segment in raw file as we please.
    const segment_id = @as(u8, @intCast(self.segments.items.len));
    const vmaddr = blk: {
        const prev_segment = self.segments.items[segment_id - 1];
        break :blk mem.alignForward(u64, prev_segment.vmaddr + prev_segment.vmsize, page_size);
    };
    // We commit more memory than needed upfront so that we don't have to reallocate too soon.
    const vmsize = mem.alignForward(u64, opts.size, page_size);
    const off = self.findFreeSpace(opts.size, page_size);

    log.debug("found {s},{s} free space 0x{x} to 0x{x} (0x{x} - 0x{x})", .{
        segname,
        sectname,
        off,
        off + opts.size,
        vmaddr,
        vmaddr + vmsize,
    });

    const seg = try self.segments.addOne(gpa);
    seg.* = .{
        .segname = makeStaticString(segname),
        .vmaddr = vmaddr,
        .vmsize = vmsize,
        .fileoff = off,
        .filesize = vmsize,
        .maxprot = opts.prot,
        .initprot = opts.prot,
        .nsects = 1,
        .cmdsize = @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64),
    };

    const sect_id = try self.initSection(segname, sectname, .{
        .flags = opts.flags,
        .reserved2 = opts.reserved2,
    });
    const section = &self.sections.items(.header)[sect_id];
    section.addr = mem.alignForward(u64, vmaddr, opts.alignment);
    section.offset = mem.alignForward(u32, @as(u32, @intCast(off)), opts.alignment);
    section.size = opts.size;
    section.@"align" = math.log2(opts.alignment);
    self.sections.items(.segment_index)[sect_id] = segment_id;
    assert(!section.isZerofill()); // TODO zerofill sections

    return sect_id;
}

fn growSection(self: *MachO, sect_id: u8, needed_size: u64) !void {
    const header = &self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const segment = &self.segments.items[segment_index];
    const maybe_last_atom_index = self.sections.items(.last_atom_index)[sect_id];
    const sect_capacity = self.allocatedSize(header.offset);
    const page_size = getPageSize(self.base.options.target.cpu.arch);

    if (needed_size > sect_capacity) {
        const new_offset = self.findFreeSpace(needed_size, page_size);
        const current_size = if (maybe_last_atom_index) |last_atom_index| blk: {
            const last_atom = self.getAtom(last_atom_index);
            const sym = last_atom.getSymbol(self);
            break :blk (sym.n_value + last_atom.size) - segment.vmaddr;
        } else header.size;

        log.debug("moving {s},{s} from 0x{x} to 0x{x}", .{
            header.segName(),
            header.sectName(),
            header.offset,
            new_offset,
        });

        const amt = try self.base.file.?.copyRangeAll(
            header.offset,
            self.base.file.?,
            new_offset,
            current_size,
        );
        if (amt != current_size) return error.InputOutput;
        header.offset = @as(u32, @intCast(new_offset));
        segment.fileoff = new_offset;
    }

    const sect_vm_capacity = self.allocatedVirtualSize(segment.vmaddr);
    if (needed_size > sect_vm_capacity) {
        self.markRelocsDirtyByAddress(segment.vmaddr + segment.vmsize);
        try self.growSectionVirtualMemory(sect_id, needed_size);
    }

    header.size = needed_size;
    segment.filesize = mem.alignForward(u64, needed_size, page_size);
    segment.vmsize = mem.alignForward(u64, needed_size, page_size);
}

fn growSectionVirtualMemory(self: *MachO, sect_id: u8, needed_size: u64) !void {
    const page_size = getPageSize(self.base.options.target.cpu.arch);
    const header = &self.sections.items(.header)[sect_id];
    const segment = self.getSegmentPtr(sect_id);
    const increased_size = padToIdeal(needed_size);
    const old_aligned_end = segment.vmaddr + segment.vmsize;
    const new_aligned_end = segment.vmaddr + mem.alignForward(u64, increased_size, page_size);
    const diff = new_aligned_end - old_aligned_end;
    log.debug("shifting every segment after {s},{s} in virtual memory by {x}", .{
        header.segName(),
        header.sectName(),
        diff,
    });

    // TODO: enforce order by increasing VM addresses in self.sections container.
    for (self.sections.items(.header)[sect_id + 1 ..], 0..) |*next_header, next_sect_id| {
        const index = @as(u8, @intCast(sect_id + 1 + next_sect_id));
        const next_segment = self.getSegmentPtr(index);
        next_header.addr += diff;
        next_segment.vmaddr += diff;

        const maybe_last_atom_index = &self.sections.items(.last_atom_index)[index];
        if (maybe_last_atom_index.*) |last_atom_index| {
            var atom_index = last_atom_index;
            while (true) {
                const atom = self.getAtom(atom_index);
                const sym = atom.getSymbolPtr(self);
                sym.n_value += diff;

                if (atom.prev_index) |prev_index| {
                    atom_index = prev_index;
                } else break;
            }
        }
    }
}

pub fn addAtomToSection(self: *MachO, atom_index: Atom.Index) void {
    assert(self.mode == .zld);
    const atom = self.getAtomPtr(atom_index);
    const sym = self.getSymbol(atom.getSymbolWithLoc());
    var section = self.sections.get(sym.n_sect - 1);
    if (section.header.size > 0) {
        const last_atom = self.getAtomPtr(section.last_atom_index.?);
        last_atom.next_index = atom_index;
        atom.prev_index = section.last_atom_index;
    } else {
        section.first_atom_index = atom_index;
    }
    section.last_atom_index = atom_index;
    section.header.size += atom.size;
    self.sections.set(sym.n_sect - 1, section);
}

fn allocateAtom(self: *MachO, atom_index: Atom.Index, new_atom_size: u64, alignment: Alignment) !u64 {
    const tracy = trace(@src());
    defer tracy.end();

    assert(self.mode == .incremental);

    const atom = self.getAtom(atom_index);
    const sect_id = atom.getSymbol(self).n_sect - 1;
    const segment = self.getSegmentPtr(sect_id);
    const header = &self.sections.items(.header)[sect_id];
    const free_list = &self.sections.items(.free_list)[sect_id];
    const maybe_last_atom_index = &self.sections.items(.last_atom_index)[sect_id];
    const requires_padding = blk: {
        if (!header.isCode()) break :blk false;
        if (header.isSymbolStubs()) break :blk false;
        if (mem.eql(u8, "__stub_helper", header.sectName())) break :blk false;
        break :blk true;
    };
    const new_atom_ideal_capacity = if (requires_padding) padToIdeal(new_atom_size) else new_atom_size;

    // We use these to indicate our intention to update metadata, placing the new atom,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var atom_placement: ?Atom.Index = null;
    var free_list_removal: ?usize = null;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    var vaddr = blk: {
        var i: usize = 0;
        while (i < free_list.items.len) {
            const big_atom_index = free_list.items[i];
            const big_atom = self.getAtom(big_atom_index);
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const sym = big_atom.getSymbol(self);
            const capacity = big_atom.capacity(self);
            const ideal_capacity = if (requires_padding) padToIdeal(capacity) else capacity;
            const ideal_capacity_end_vaddr = math.add(u64, sym.n_value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = sym.n_value + capacity;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = alignment.backward(new_start_vaddr_unaligned);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the atom that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(self)) {
                    _ = free_list.swapRemove(i);
                } else {
                    i += 1;
                }
                continue;
            }
            // At this point we know that we will place the new atom here. But the
            // remaining question is whether there is still yet enough capacity left
            // over for there to still be a free list node.
            const remaining_capacity = new_start_vaddr - ideal_capacity_end_vaddr;
            const keep_free_list_node = remaining_capacity >= min_text_capacity;

            // Set up the metadata to be updated, after errors are no longer possible.
            atom_placement = big_atom_index;
            if (!keep_free_list_node) {
                free_list_removal = i;
            }
            break :blk new_start_vaddr;
        } else if (maybe_last_atom_index.*) |last_index| {
            const last = self.getAtom(last_index);
            const last_symbol = last.getSymbol(self);
            const ideal_capacity = if (requires_padding) padToIdeal(last.size) else last.size;
            const ideal_capacity_end_vaddr = last_symbol.n_value + ideal_capacity;
            const new_start_vaddr = alignment.forward(ideal_capacity_end_vaddr);
            atom_placement = last_index;
            break :blk new_start_vaddr;
        } else {
            break :blk alignment.forward(segment.vmaddr);
        }
    };

    const expand_section = if (atom_placement) |placement_index|
        self.getAtom(placement_index).next_index == null
    else
        true;
    if (expand_section) {
        const needed_size = (vaddr + new_atom_size) - segment.vmaddr;
        try self.growSection(sect_id, needed_size);
        maybe_last_atom_index.* = atom_index;
        self.segment_table_dirty = true;
    }

    assert(alignment != .none);
    header.@"align" = @min(header.@"align", @intFromEnum(alignment));
    self.getAtomPtr(atom_index).size = new_atom_size;

    if (atom.prev_index) |prev_index| {
        const prev = self.getAtomPtr(prev_index);
        prev.next_index = atom.next_index;
    }
    if (atom.next_index) |next_index| {
        const next = self.getAtomPtr(next_index);
        next.prev_index = atom.prev_index;
    }

    if (atom_placement) |big_atom_index| {
        const big_atom = self.getAtomPtr(big_atom_index);
        const atom_ptr = self.getAtomPtr(atom_index);
        atom_ptr.prev_index = big_atom_index;
        atom_ptr.next_index = big_atom.next_index;
        big_atom.next_index = atom_index;
    } else {
        const atom_ptr = self.getAtomPtr(atom_index);
        atom_ptr.prev_index = null;
        atom_ptr.next_index = null;
    }
    if (free_list_removal) |i| {
        _ = free_list.swapRemove(i);
    }

    return vaddr;
}

pub fn getGlobalSymbol(self: *MachO, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = lib_name;
    const gpa = self.base.allocator;
    const sym_name = try std.fmt.allocPrint(gpa, "_{s}", .{name});
    defer gpa.free(sym_name);
    return self.addUndefined(sym_name, .{ .add_stub = true });
}

pub fn writeSegmentHeaders(self: *MachO, writer: anytype) !void {
    for (self.segments.items, 0..) |seg, i| {
        const indexes = self.getSectionIndexes(@intCast(i));
        var out_seg = seg;
        out_seg.cmdsize = @sizeOf(macho.segment_command_64);
        out_seg.nsects = 0;

        // Update section headers count; any section with size of 0 is excluded
        // since it doesn't have any data in the final binary file.
        for (self.sections.items(.header)[indexes.start..indexes.end]) |header| {
            if (header.size == 0) continue;
            out_seg.cmdsize += @sizeOf(macho.section_64);
            out_seg.nsects += 1;
        }

        if (out_seg.nsects == 0 and
            (mem.eql(u8, out_seg.segName(), "__DATA_CONST") or
            mem.eql(u8, out_seg.segName(), "__DATA"))) continue;

        try writer.writeStruct(out_seg);
        for (self.sections.items(.header)[indexes.start..indexes.end]) |header| {
            if (header.size == 0) continue;
            try writer.writeStruct(header);
        }
    }
}

pub fn writeLinkeditSegmentData(self: *MachO) !void {
    const page_size = getPageSize(self.base.options.target.cpu.arch);
    const seg = self.getLinkeditSegmentPtr();
    seg.filesize = 0;
    seg.vmsize = 0;

    for (self.segments.items, 0..) |segment, id| {
        if (self.linkedit_segment_cmd_index.? == @as(u8, @intCast(id))) continue;
        if (seg.vmaddr < segment.vmaddr + segment.vmsize) {
            seg.vmaddr = mem.alignForward(u64, segment.vmaddr + segment.vmsize, page_size);
        }
        if (seg.fileoff < segment.fileoff + segment.filesize) {
            seg.fileoff = mem.alignForward(u64, segment.fileoff + segment.filesize, page_size);
        }
    }

    try self.writeDyldInfoData();
    // TODO handle this better
    if (self.mode == .zld) {
        try self.writeFunctionStarts();
        try self.writeDataInCode();
    }
    try self.writeSymtabs();

    seg.vmsize = mem.alignForward(u64, seg.filesize, page_size);
}

fn collectRebaseDataFromTableSection(self: *MachO, sect_id: u8, rebase: *Rebase, table: anytype) !void {
    const gpa = self.base.allocator;
    const header = self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const segment = self.segments.items[segment_index];
    const base_offset = header.addr - segment.vmaddr;
    const is_got = if (self.got_section_index) |index| index == sect_id else false;

    try rebase.entries.ensureUnusedCapacity(gpa, table.entries.items.len);

    for (table.entries.items, 0..) |entry, i| {
        if (!table.lookup.contains(entry)) continue;
        const sym = self.getSymbol(entry);
        if (is_got and sym.undf()) continue;
        const offset = i * @sizeOf(u64);
        log.debug("    | rebase at {x}", .{base_offset + offset});
        rebase.entries.appendAssumeCapacity(.{
            .offset = base_offset + offset,
            .segment_id = segment_index,
        });
    }
}

fn collectRebaseData(self: *MachO, rebase: *Rebase) !void {
    const gpa = self.base.allocator;
    const slice = self.sections.slice();

    for (self.rebases.keys(), 0..) |atom_index, i| {
        const atom = self.getAtom(atom_index);
        log.debug("  ATOM(%{?d}, '{s}')", .{ atom.getSymbolIndex(), atom.getName(self) });

        const sym = atom.getSymbol(self);
        const segment_index = slice.items(.segment_index)[sym.n_sect - 1];
        const seg = self.getSegment(sym.n_sect - 1);

        const base_offset = sym.n_value - seg.vmaddr;

        const rebases = self.rebases.values()[i];
        try rebase.entries.ensureUnusedCapacity(gpa, rebases.items.len);

        for (rebases.items) |offset| {
            log.debug("    | rebase at {x}", .{base_offset + offset});

            rebase.entries.appendAssumeCapacity(.{
                .offset = base_offset + offset,
                .segment_id = segment_index,
            });
        }
    }

    // Unpack GOT entries
    if (self.got_section_index) |sect_id| {
        try self.collectRebaseDataFromTableSection(sect_id, rebase, self.got_table);
    }

    // Next, unpack __la_symbol_ptr entries
    if (self.la_symbol_ptr_section_index) |sect_id| {
        try self.collectRebaseDataFromTableSection(sect_id, rebase, self.stub_table);
    }

    // Finally, unpack the rest.
    const cpu_arch = self.base.options.target.cpu.arch;
    for (self.objects.items) |*object| {
        for (object.atoms.items) |atom_index| {
            const atom = self.getAtom(atom_index);
            const sym = self.getSymbol(atom.getSymbolWithLoc());
            if (sym.n_desc == N_DEAD) continue;

            const sect_id = sym.n_sect - 1;
            const section = self.sections.items(.header)[sect_id];
            const segment_id = self.sections.items(.segment_index)[sect_id];
            const segment = self.segments.items[segment_id];
            if (segment.maxprot & macho.PROT.WRITE == 0) continue;
            switch (section.type()) {
                macho.S_LITERAL_POINTERS,
                macho.S_REGULAR,
                macho.S_MOD_INIT_FUNC_POINTERS,
                macho.S_MOD_TERM_FUNC_POINTERS,
                => {},
                else => continue,
            }

            log.debug("  ATOM({d}, %{d}, '{s}')", .{
                atom_index,
                atom.sym_index,
                self.getSymbolName(atom.getSymbolWithLoc()),
            });

            const code = Atom.getAtomCode(self, atom_index);
            const relocs = Atom.getAtomRelocs(self, atom_index);
            const ctx = Atom.getRelocContext(self, atom_index);

            for (relocs) |rel| {
                switch (cpu_arch) {
                    .aarch64 => {
                        const rel_type = @as(macho.reloc_type_arm64, @enumFromInt(rel.r_type));
                        if (rel_type != .ARM64_RELOC_UNSIGNED) continue;
                        if (rel.r_length != 3) continue;
                    },
                    .x86_64 => {
                        const rel_type = @as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type));
                        if (rel_type != .X86_64_RELOC_UNSIGNED) continue;
                        if (rel.r_length != 3) continue;
                    },
                    else => unreachable,
                }
                const target = Atom.parseRelocTarget(self, .{
                    .object_id = atom.getFile().?,
                    .rel = rel,
                    .code = code,
                    .base_offset = ctx.base_offset,
                    .base_addr = ctx.base_addr,
                });
                const target_sym = self.getSymbol(target);
                if (target_sym.undf()) continue;

                const base_offset = @as(i32, @intCast(sym.n_value - segment.vmaddr));
                const rel_offset = rel.r_address - ctx.base_offset;
                const offset = @as(u64, @intCast(base_offset + rel_offset));
                log.debug("    | rebase at {x}", .{offset});

                try rebase.entries.append(gpa, .{
                    .offset = offset,
                    .segment_id = segment_id,
                });
            }
        }
    }

    try rebase.finalize(gpa);
}

fn collectBindDataFromTableSection(self: *MachO, sect_id: u8, bind: anytype, table: anytype) !void {
    const gpa = self.base.allocator;
    const header = self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const segment = self.segments.items[segment_index];
    const base_offset = header.addr - segment.vmaddr;

    try bind.entries.ensureUnusedCapacity(gpa, table.entries.items.len);

    for (table.entries.items, 0..) |entry, i| {
        if (!table.lookup.contains(entry)) continue;
        const bind_sym = self.getSymbol(entry);
        if (!bind_sym.undf()) continue;
        const offset = i * @sizeOf(u64);
        log.debug("    | bind at {x}, import('{s}') in dylib({d})", .{
            base_offset + offset,
            self.getSymbolName(entry),
            @divTrunc(@as(i16, @bitCast(bind_sym.n_desc)), macho.N_SYMBOL_RESOLVER),
        });
        if (bind_sym.weakRef()) {
            log.debug("    | marking as weak ref ", .{});
        }
        bind.entries.appendAssumeCapacity(.{
            .target = entry,
            .offset = base_offset + offset,
            .segment_id = segment_index,
            .addend = 0,
        });
    }
}

fn collectBindData(self: *MachO, bind: anytype, raw_bindings: anytype) !void {
    const gpa = self.base.allocator;
    const slice = self.sections.slice();

    for (raw_bindings.keys(), 0..) |atom_index, i| {
        const atom = self.getAtom(atom_index);
        log.debug("  ATOM(%{?d}, '{s}')", .{ atom.getSymbolIndex(), atom.getName(self) });

        const sym = atom.getSymbol(self);
        const segment_index = slice.items(.segment_index)[sym.n_sect - 1];
        const seg = self.getSegment(sym.n_sect - 1);

        const base_offset = sym.n_value - seg.vmaddr;

        const bindings = raw_bindings.values()[i];
        try bind.entries.ensureUnusedCapacity(gpa, bindings.items.len);

        for (bindings.items) |binding| {
            const bind_sym = self.getSymbol(binding.target);
            const bind_sym_name = self.getSymbolName(binding.target);
            const dylib_ordinal = @divTrunc(
                @as(i16, @bitCast(bind_sym.n_desc)),
                macho.N_SYMBOL_RESOLVER,
            );
            log.debug("    | bind at {x}, import('{s}') in dylib({d})", .{
                binding.offset + base_offset,
                bind_sym_name,
                dylib_ordinal,
            });
            if (bind_sym.weakRef()) {
                log.debug("    | marking as weak ref ", .{});
            }
            bind.entries.appendAssumeCapacity(.{
                .target = binding.target,
                .offset = binding.offset + base_offset,
                .segment_id = segment_index,
                .addend = 0,
            });
        }
    }

    // Unpack GOT pointers
    if (self.got_section_index) |sect_id| {
        try self.collectBindDataFromTableSection(sect_id, bind, self.got_table);
    }

    // Next, unpack TLV pointers section
    if (self.tlv_ptr_section_index) |sect_id| {
        try self.collectBindDataFromTableSection(sect_id, bind, self.tlv_ptr_table);
    }

    // Finally, unpack the rest.
    const cpu_arch = self.base.options.target.cpu.arch;
    for (self.objects.items) |*object| {
        for (object.atoms.items) |atom_index| {
            const atom = self.getAtom(atom_index);
            const sym = self.getSymbol(atom.getSymbolWithLoc());
            if (sym.n_desc == N_DEAD) continue;

            const sect_id = sym.n_sect - 1;
            const section = self.sections.items(.header)[sect_id];
            const segment_id = self.sections.items(.segment_index)[sect_id];
            const segment = self.segments.items[segment_id];
            if (segment.maxprot & macho.PROT.WRITE == 0) continue;
            switch (section.type()) {
                macho.S_LITERAL_POINTERS,
                macho.S_REGULAR,
                macho.S_MOD_INIT_FUNC_POINTERS,
                macho.S_MOD_TERM_FUNC_POINTERS,
                => {},
                else => continue,
            }

            log.debug("  ATOM({d}, %{d}, '{s}')", .{
                atom_index,
                atom.sym_index,
                self.getSymbolName(atom.getSymbolWithLoc()),
            });

            const code = Atom.getAtomCode(self, atom_index);
            const relocs = Atom.getAtomRelocs(self, atom_index);
            const ctx = Atom.getRelocContext(self, atom_index);

            for (relocs) |rel| {
                switch (cpu_arch) {
                    .aarch64 => {
                        const rel_type = @as(macho.reloc_type_arm64, @enumFromInt(rel.r_type));
                        if (rel_type != .ARM64_RELOC_UNSIGNED) continue;
                        if (rel.r_length != 3) continue;
                    },
                    .x86_64 => {
                        const rel_type = @as(macho.reloc_type_x86_64, @enumFromInt(rel.r_type));
                        if (rel_type != .X86_64_RELOC_UNSIGNED) continue;
                        if (rel.r_length != 3) continue;
                    },
                    else => unreachable,
                }

                const global = Atom.parseRelocTarget(self, .{
                    .object_id = atom.getFile().?,
                    .rel = rel,
                    .code = code,
                    .base_offset = ctx.base_offset,
                    .base_addr = ctx.base_addr,
                });
                const bind_sym_name = self.getSymbolName(global);
                const bind_sym = self.getSymbol(global);
                if (!bind_sym.undf()) continue;

                const base_offset = sym.n_value - segment.vmaddr;
                const rel_offset = @as(u32, @intCast(rel.r_address - ctx.base_offset));
                const offset = @as(u64, @intCast(base_offset + rel_offset));
                const addend = mem.readInt(i64, code[rel_offset..][0..8], .little);

                const dylib_ordinal = @divTrunc(@as(i16, @bitCast(bind_sym.n_desc)), macho.N_SYMBOL_RESOLVER);
                log.debug("    | bind at {x}, import('{s}') in dylib({d})", .{
                    base_offset,
                    bind_sym_name,
                    dylib_ordinal,
                });
                log.debug("    | with addend {x}", .{addend});
                if (bind_sym.weakRef()) {
                    log.debug("    | marking as weak ref ", .{});
                }
                try bind.entries.append(gpa, .{
                    .target = global,
                    .offset = offset,
                    .segment_id = segment_id,
                    .addend = addend,
                });
            }
        }
    }

    try bind.finalize(gpa, self);
}

fn collectLazyBindData(self: *MachO, bind: anytype) !void {
    const sect_id = self.la_symbol_ptr_section_index orelse return;
    try self.collectBindDataFromTableSection(sect_id, bind, self.stub_table);
    try bind.finalize(self.base.allocator, self);
}

fn collectExportData(self: *MachO, trie: *Trie) !void {
    const gpa = self.base.allocator;

    // TODO handle macho.EXPORT_SYMBOL_FLAGS_REEXPORT and macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER.
    log.debug("generating export trie", .{});

    const exec_segment = self.segments.items[self.header_segment_cmd_index.?];
    const base_address = exec_segment.vmaddr;

    for (self.globals.items) |global| {
        const sym = self.getSymbol(global);

        if (sym.undf()) continue;
        assert(sym.ext());
        if (sym.n_desc == N_DEAD) continue;

        const sym_name = self.getSymbolName(global);
        log.debug("  (putting '{s}' defined at 0x{x})", .{ sym_name, sym.n_value });
        try trie.put(gpa, .{
            .name = sym_name,
            .vmaddr_offset = sym.n_value - base_address,
            .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
        });
    }

    try trie.finalize(gpa);
}

fn writeDyldInfoData(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;

    var rebase = Rebase{};
    defer rebase.deinit(gpa);
    try self.collectRebaseData(&rebase);

    var bind = Bind{};
    defer bind.deinit(gpa);
    try self.collectBindData(&bind, self.bindings);

    var lazy_bind = LazyBind{};
    defer lazy_bind.deinit(gpa);
    try self.collectLazyBindData(&lazy_bind);

    var trie: Trie = .{};
    defer trie.deinit(gpa);
    try trie.init(gpa);
    try self.collectExportData(&trie);

    const link_seg = self.getLinkeditSegmentPtr();
    assert(mem.isAlignedGeneric(u64, link_seg.fileoff, @alignOf(u64)));
    const rebase_off = link_seg.fileoff;
    const rebase_size = rebase.size();
    const rebase_size_aligned = mem.alignForward(u64, rebase_size, @alignOf(u64));
    log.debug("writing rebase info from 0x{x} to 0x{x}", .{ rebase_off, rebase_off + rebase_size_aligned });

    const bind_off = rebase_off + rebase_size_aligned;
    const bind_size = bind.size();
    const bind_size_aligned = mem.alignForward(u64, bind_size, @alignOf(u64));
    log.debug("writing bind info from 0x{x} to 0x{x}", .{ bind_off, bind_off + bind_size_aligned });

    const lazy_bind_off = bind_off + bind_size_aligned;
    const lazy_bind_size = lazy_bind.size();
    const lazy_bind_size_aligned = mem.alignForward(u64, lazy_bind_size, @alignOf(u64));
    log.debug("writing lazy bind info from 0x{x} to 0x{x}", .{
        lazy_bind_off,
        lazy_bind_off + lazy_bind_size_aligned,
    });

    const export_off = lazy_bind_off + lazy_bind_size_aligned;
    const export_size = trie.size;
    const export_size_aligned = mem.alignForward(u64, export_size, @alignOf(u64));
    log.debug("writing export trie from 0x{x} to 0x{x}", .{ export_off, export_off + export_size_aligned });

    const needed_size = math.cast(usize, export_off + export_size_aligned - rebase_off) orelse
        return error.Overflow;
    link_seg.filesize = needed_size;
    assert(mem.isAlignedGeneric(u64, link_seg.fileoff + link_seg.filesize, @alignOf(u64)));

    var buffer = try gpa.alloc(u8, needed_size);
    defer gpa.free(buffer);
    @memset(buffer, 0);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try rebase.write(writer);
    try stream.seekTo(bind_off - rebase_off);

    try bind.write(writer);
    try stream.seekTo(lazy_bind_off - rebase_off);

    try lazy_bind.write(writer);
    try stream.seekTo(export_off - rebase_off);

    _ = try trie.write(writer);

    log.debug("writing dyld info from 0x{x} to 0x{x}", .{
        rebase_off,
        rebase_off + needed_size,
    });

    try self.base.file.?.pwriteAll(buffer, rebase_off);
    try self.populateLazyBindOffsetsInStubHelper(lazy_bind);

    self.dyld_info_cmd.rebase_off = @as(u32, @intCast(rebase_off));
    self.dyld_info_cmd.rebase_size = @as(u32, @intCast(rebase_size_aligned));
    self.dyld_info_cmd.bind_off = @as(u32, @intCast(bind_off));
    self.dyld_info_cmd.bind_size = @as(u32, @intCast(bind_size_aligned));
    self.dyld_info_cmd.lazy_bind_off = @as(u32, @intCast(lazy_bind_off));
    self.dyld_info_cmd.lazy_bind_size = @as(u32, @intCast(lazy_bind_size_aligned));
    self.dyld_info_cmd.export_off = @as(u32, @intCast(export_off));
    self.dyld_info_cmd.export_size = @as(u32, @intCast(export_size_aligned));
}

fn populateLazyBindOffsetsInStubHelper(self: *MachO, lazy_bind: anytype) !void {
    if (lazy_bind.size() == 0) return;

    const stub_helper_section_index = self.stub_helper_section_index.?;
    // assert(ctx.stub_helper_preamble_allocated);

    const header = self.sections.items(.header)[stub_helper_section_index];

    const cpu_arch = self.base.options.target.cpu.arch;
    const preamble_size = stubs.stubHelperPreambleSize(cpu_arch);
    const stub_size = stubs.stubHelperSize(cpu_arch);
    const stub_offset = stubs.stubOffsetInStubHelper(cpu_arch);
    const base_offset = header.offset + preamble_size;

    for (lazy_bind.offsets.items, 0..) |bind_offset, index| {
        const file_offset = base_offset + index * stub_size + stub_offset;

        log.debug("writing lazy bind offset 0x{x} ({s}) in stub helper at 0x{x}", .{
            bind_offset,
            self.getSymbolName(lazy_bind.entries.items[index].target),
            file_offset,
        });

        try self.base.file.?.pwriteAll(mem.asBytes(&bind_offset), file_offset);
    }
}

const asc_u64 = std.sort.asc(u64);

fn addSymbolToFunctionStarts(self: *MachO, sym_loc: SymbolWithLoc, addresses: *std.ArrayList(u64)) !void {
    const sym = self.getSymbol(sym_loc);
    if (sym.n_strx == 0) return;
    if (sym.n_desc == MachO.N_DEAD) return;
    if (self.symbolIsTemp(sym_loc)) return;
    try addresses.append(sym.n_value);
}

fn writeFunctionStarts(self: *MachO) !void {
    const gpa = self.base.allocator;
    const seg = self.segments.items[self.header_segment_cmd_index.?];

    // We need to sort by address first
    var addresses = std.ArrayList(u64).init(gpa);
    defer addresses.deinit();

    for (self.objects.items) |object| {
        for (object.exec_atoms.items) |atom_index| {
            const atom = self.getAtom(atom_index);
            const sym_loc = atom.getSymbolWithLoc();
            try self.addSymbolToFunctionStarts(sym_loc, &addresses);

            var it = Atom.getInnerSymbolsIterator(self, atom_index);
            while (it.next()) |inner_sym_loc| {
                try self.addSymbolToFunctionStarts(inner_sym_loc, &addresses);
            }
        }
    }

    mem.sort(u64, addresses.items, {}, asc_u64);

    var offsets = std.ArrayList(u32).init(gpa);
    defer offsets.deinit();
    try offsets.ensureTotalCapacityPrecise(addresses.items.len);

    var last_off: u32 = 0;
    for (addresses.items) |addr| {
        const offset = @as(u32, @intCast(addr - seg.vmaddr));
        const diff = offset - last_off;

        if (diff == 0) continue;

        offsets.appendAssumeCapacity(diff);
        last_off = offset;
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const max_size = @as(usize, @intCast(offsets.items.len * @sizeOf(u64)));
    try buffer.ensureTotalCapacity(max_size);

    for (offsets.items) |offset| {
        try std.leb.writeULEB128(buffer.writer(), offset);
    }

    const link_seg = self.getLinkeditSegmentPtr();
    const offset = link_seg.fileoff + link_seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = buffer.items.len;
    const needed_size_aligned = mem.alignForward(u64, needed_size, @alignOf(u64));
    const padding = math.cast(usize, needed_size_aligned - needed_size) orelse return error.Overflow;
    if (padding > 0) {
        try buffer.ensureUnusedCapacity(padding);
        buffer.appendNTimesAssumeCapacity(0, padding);
    }
    link_seg.filesize = offset + needed_size_aligned - link_seg.fileoff;

    log.debug("writing function starts info from 0x{x} to 0x{x}", .{ offset, offset + needed_size_aligned });

    try self.base.file.?.pwriteAll(buffer.items, offset);

    self.function_starts_cmd.dataoff = @as(u32, @intCast(offset));
    self.function_starts_cmd.datasize = @as(u32, @intCast(needed_size_aligned));
}

fn filterDataInCode(
    dices: []const macho.data_in_code_entry,
    start_addr: u64,
    end_addr: u64,
) []const macho.data_in_code_entry {
    const Predicate = struct {
        addr: u64,

        pub fn predicate(self: @This(), dice: macho.data_in_code_entry) bool {
            return dice.offset >= self.addr;
        }
    };

    const start = MachO.lsearch(macho.data_in_code_entry, dices, Predicate{ .addr = start_addr });
    const end = MachO.lsearch(macho.data_in_code_entry, dices[start..], Predicate{ .addr = end_addr }) + start;

    return dices[start..end];
}

pub fn writeDataInCode(self: *MachO) !void {
    const gpa = self.base.allocator;
    var out_dice = std.ArrayList(macho.data_in_code_entry).init(gpa);
    defer out_dice.deinit();

    const text_sect_id = self.text_section_index orelse return;
    const text_sect_header = self.sections.items(.header)[text_sect_id];

    for (self.objects.items) |object| {
        if (!object.hasDataInCode()) continue;
        const dice = object.data_in_code.items;
        try out_dice.ensureUnusedCapacity(dice.len);

        for (object.exec_atoms.items) |atom_index| {
            const atom = self.getAtom(atom_index);
            const sym = self.getSymbol(atom.getSymbolWithLoc());
            if (sym.n_desc == MachO.N_DEAD) continue;

            const source_addr = if (object.getSourceSymbol(atom.sym_index)) |source_sym|
                source_sym.n_value
            else blk: {
                const nbase = @as(u32, @intCast(object.in_symtab.?.len));
                const source_sect_id = @as(u8, @intCast(atom.sym_index - nbase));
                break :blk object.getSourceSection(source_sect_id).addr;
            };
            const filtered_dice = filterDataInCode(dice, source_addr, source_addr + atom.size);
            const base = math.cast(u32, sym.n_value - text_sect_header.addr + text_sect_header.offset) orelse
                return error.Overflow;

            for (filtered_dice) |single| {
                const offset = math.cast(u32, single.offset - source_addr + base) orelse
                    return error.Overflow;
                out_dice.appendAssumeCapacity(.{
                    .offset = offset,
                    .length = single.length,
                    .kind = single.kind,
                });
            }
        }
    }

    const seg = self.getLinkeditSegmentPtr();
    const offset = seg.fileoff + seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = out_dice.items.len * @sizeOf(macho.data_in_code_entry);
    const needed_size_aligned = mem.alignForward(u64, needed_size, @alignOf(u64));
    seg.filesize = offset + needed_size_aligned - seg.fileoff;

    const buffer = try gpa.alloc(u8, math.cast(usize, needed_size_aligned) orelse return error.Overflow);
    defer gpa.free(buffer);
    {
        const src = mem.sliceAsBytes(out_dice.items);
        @memcpy(buffer[0..src.len], src);
        @memset(buffer[src.len..], 0);
    }

    log.debug("writing data-in-code from 0x{x} to 0x{x}", .{ offset, offset + needed_size_aligned });

    try self.base.file.?.pwriteAll(buffer, offset);

    self.data_in_code_cmd.dataoff = @as(u32, @intCast(offset));
    self.data_in_code_cmd.datasize = @as(u32, @intCast(needed_size_aligned));
}

fn writeSymtabs(self: *MachO) !void {
    var ctx = try self.writeSymtab();
    defer ctx.imports_table.deinit();
    try self.writeDysymtab(ctx);
    try self.writeStrtab();
}

fn addLocalToSymtab(self: *MachO, sym_loc: SymbolWithLoc, locals: *std.ArrayList(macho.nlist_64)) !void {
    const sym = self.getSymbol(sym_loc);
    if (sym.n_strx == 0) return; // no name, skip
    if (sym.n_desc == MachO.N_DEAD) return; // garbage-collected, skip
    if (sym.ext()) return; // an export lands in its own symtab section, skip
    if (self.symbolIsTemp(sym_loc)) return; // local temp symbol, skip
    var out_sym = sym;
    out_sym.n_strx = try self.strtab.insert(self.base.allocator, self.getSymbolName(sym_loc));
    try locals.append(out_sym);
}

fn writeSymtab(self: *MachO) !SymtabCtx {
    const gpa = self.base.allocator;

    var locals = std.ArrayList(macho.nlist_64).init(gpa);
    defer locals.deinit();

    for (0..self.locals.items.len) |sym_id| {
        try self.addLocalToSymtab(.{ .sym_index = @intCast(sym_id) }, &locals);
    }

    for (self.objects.items) |object| {
        for (object.atoms.items) |atom_index| {
            const atom = self.getAtom(atom_index);
            const sym_loc = atom.getSymbolWithLoc();
            try self.addLocalToSymtab(sym_loc, &locals);

            var it = Atom.getInnerSymbolsIterator(self, atom_index);
            while (it.next()) |inner_sym_loc| {
                try self.addLocalToSymtab(inner_sym_loc, &locals);
            }
        }
    }

    var exports = std.ArrayList(macho.nlist_64).init(gpa);
    defer exports.deinit();

    for (self.globals.items) |global| {
        const sym = self.getSymbol(global);
        if (sym.undf()) continue; // import, skip
        if (sym.n_desc == N_DEAD) continue;
        var out_sym = sym;
        out_sym.n_strx = try self.strtab.insert(gpa, self.getSymbolName(global));
        try exports.append(out_sym);
    }

    var imports = std.ArrayList(macho.nlist_64).init(gpa);
    defer imports.deinit();

    var imports_table = std.AutoHashMap(SymbolWithLoc, u32).init(gpa);

    for (self.globals.items) |global| {
        const sym = self.getSymbol(global);
        if (sym.n_strx == 0) continue; // no name, skip
        if (!sym.undf()) continue; // not an import, skip
        if (sym.n_desc == N_DEAD) continue;
        const new_index = @as(u32, @intCast(imports.items.len));
        var out_sym = sym;
        out_sym.n_strx = try self.strtab.insert(gpa, self.getSymbolName(global));
        try imports.append(out_sym);
        try imports_table.putNoClobber(global, new_index);
    }

    // We generate stabs last in order to ensure that the strtab always has debug info
    // strings trailing
    if (!self.base.options.strip) {
        for (self.objects.items) |object| {
            assert(self.d_sym == null); // TODO
            try self.generateSymbolStabs(object, &locals);
        }
    }

    const nlocals = @as(u32, @intCast(locals.items.len));
    const nexports = @as(u32, @intCast(exports.items.len));
    const nimports = @as(u32, @intCast(imports.items.len));
    const nsyms = nlocals + nexports + nimports;

    const seg = self.getLinkeditSegmentPtr();
    const offset = seg.fileoff + seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = nsyms * @sizeOf(macho.nlist_64);
    seg.filesize = offset + needed_size - seg.fileoff;
    assert(mem.isAlignedGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64)));

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(needed_size);
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(locals.items));
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(exports.items));
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(imports.items));

    log.debug("writing symtab from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    try self.base.file.?.pwriteAll(buffer.items, offset);

    self.symtab_cmd.symoff = @as(u32, @intCast(offset));
    self.symtab_cmd.nsyms = nsyms;

    return SymtabCtx{
        .nlocalsym = nlocals,
        .nextdefsym = nexports,
        .nundefsym = nimports,
        .imports_table = imports_table,
    };
}

// TODO this function currently skips generating symbol stabs in case errors are encountered in DWARF data.
// I think we should actually report those errors to the user and let them decide if they want to strip debug info
// in that case or not.
fn generateSymbolStabs(
    self: *MachO,
    object: Object,
    locals: *std.ArrayList(macho.nlist_64),
) !void {
    log.debug("generating stabs for '{s}'", .{object.name});

    const gpa = self.base.allocator;
    var debug_info = object.parseDwarfInfo();

    var lookup = DwarfInfo.AbbrevLookupTable.init(gpa);
    defer lookup.deinit();
    try lookup.ensureUnusedCapacity(std.math.maxInt(u8));

    // We assume there is only one CU.
    var cu_it = debug_info.getCompileUnitIterator();
    const compile_unit = while (try cu_it.next()) |cu| {
        const offset = math.cast(usize, cu.cuh.debug_abbrev_offset) orelse return error.Overflow;
        try debug_info.genAbbrevLookupByKind(offset, &lookup);
        break cu;
    } else {
        log.debug("no compile unit found in debug info in {s}; skipping", .{object.name});
        return;
    };

    var abbrev_it = compile_unit.getAbbrevEntryIterator(debug_info);
    const maybe_cu_entry: ?DwarfInfo.AbbrevEntry = blk: {
        while (abbrev_it.next(lookup) catch break :blk null) |entry| switch (entry.tag) {
            dwarf.TAG.compile_unit => break :blk entry,
            else => continue,
        } else break :blk null;
    };

    const cu_entry = maybe_cu_entry orelse {
        log.debug("missing DWARF_TAG_compile_unit tag in {s}; skipping", .{object.name});
        return;
    };

    var maybe_tu_name: ?[]const u8 = null;
    var maybe_tu_comp_dir: ?[]const u8 = null;
    var attr_it = cu_entry.getAttributeIterator(debug_info, compile_unit.cuh);

    blk: {
        while (attr_it.next() catch break :blk) |attr| switch (attr.name) {
            dwarf.AT.comp_dir => maybe_tu_comp_dir = attr.getString(debug_info, compile_unit.cuh) orelse continue,
            dwarf.AT.name => maybe_tu_name = attr.getString(debug_info, compile_unit.cuh) orelse continue,
            else => continue,
        };
    }

    if (maybe_tu_name == null or maybe_tu_comp_dir == null) {
        log.debug("missing DWARF_AT_comp_dir and DWARF_AT_name attributes {s}; skipping", .{object.name});
        return;
    }

    const tu_name = maybe_tu_name.?;
    const tu_comp_dir = maybe_tu_comp_dir.?;

    // Open scope
    try locals.ensureUnusedCapacity(3);
    locals.appendAssumeCapacity(.{
        .n_strx = try self.strtab.insert(gpa, tu_comp_dir),
        .n_type = macho.N_SO,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    locals.appendAssumeCapacity(.{
        .n_strx = try self.strtab.insert(gpa, tu_name),
        .n_type = macho.N_SO,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    locals.appendAssumeCapacity(.{
        .n_strx = try self.strtab.insert(gpa, object.name),
        .n_type = macho.N_OSO,
        .n_sect = 0,
        .n_desc = 1,
        .n_value = object.mtime,
    });

    var stabs_buf: [4]macho.nlist_64 = undefined;

    var name_lookup: ?DwarfInfo.SubprogramLookupByName = if (object.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS == 0) blk: {
        var name_lookup = DwarfInfo.SubprogramLookupByName.init(gpa);
        errdefer name_lookup.deinit();
        try name_lookup.ensureUnusedCapacity(@as(u32, @intCast(object.atoms.items.len)));
        debug_info.genSubprogramLookupByName(compile_unit, lookup, &name_lookup) catch |err| switch (err) {
            error.UnhandledDwFormValue => {}, // TODO I don't like the fact we constantly re-iterate and hit this; we should validate once a priori
            else => |e| return e,
        };
        break :blk name_lookup;
    } else null;
    defer if (name_lookup) |*nl| nl.deinit();

    for (object.atoms.items) |atom_index| {
        const atom = self.getAtom(atom_index);
        const stabs = try self.generateSymbolStabsForSymbol(
            atom_index,
            atom.getSymbolWithLoc(),
            name_lookup,
            &stabs_buf,
        );
        try locals.appendSlice(stabs);

        var it = Atom.getInnerSymbolsIterator(self, atom_index);
        while (it.next()) |sym_loc| {
            const contained_stabs = try self.generateSymbolStabsForSymbol(
                atom_index,
                sym_loc,
                name_lookup,
                &stabs_buf,
            );
            try locals.appendSlice(contained_stabs);
        }
    }

    // Close scope
    try locals.append(.{
        .n_strx = 0,
        .n_type = macho.N_SO,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
}

fn generateSymbolStabsForSymbol(
    self: *MachO,
    atom_index: Atom.Index,
    sym_loc: SymbolWithLoc,
    lookup: ?DwarfInfo.SubprogramLookupByName,
    buf: *[4]macho.nlist_64,
) ![]const macho.nlist_64 {
    const gpa = self.base.allocator;
    const object = self.objects.items[sym_loc.getFile().?];
    const sym = self.getSymbol(sym_loc);
    const sym_name = self.getSymbolName(sym_loc);
    const header = self.sections.items(.header)[sym.n_sect - 1];

    if (sym.n_strx == 0) return buf[0..0];
    if (self.symbolIsTemp(sym_loc)) return buf[0..0];

    if (!header.isCode()) {
        // Since we are not dealing with machine code, it's either a global or a static depending
        // on the linkage scope.
        if (sym.sect() and sym.ext()) {
            // Global gets an N_GSYM stab type.
            buf[0] = .{
                .n_strx = try self.strtab.insert(gpa, sym_name),
                .n_type = macho.N_GSYM,
                .n_sect = sym.n_sect,
                .n_desc = 0,
                .n_value = 0,
            };
        } else {
            // Local static gets an N_STSYM stab type.
            buf[0] = .{
                .n_strx = try self.strtab.insert(gpa, sym_name),
                .n_type = macho.N_STSYM,
                .n_sect = sym.n_sect,
                .n_desc = 0,
                .n_value = sym.n_value,
            };
        }
        return buf[0..1];
    }

    const size: u64 = size: {
        if (object.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0) {
            break :size self.getAtom(atom_index).size;
        }

        // Since we don't have subsections to work with, we need to infer the size of each function
        // the slow way by scanning the debug info for matching symbol names and extracting
        // the symbol's DWARF_AT_low_pc and DWARF_AT_high_pc values.
        const source_sym = object.getSourceSymbol(sym_loc.sym_index) orelse return buf[0..0];
        const subprogram = lookup.?.get(sym_name[1..]) orelse return buf[0..0];

        if (subprogram.addr <= source_sym.n_value and source_sym.n_value < subprogram.addr + subprogram.size) {
            break :size subprogram.size;
        } else {
            log.debug("no stab found for {s}", .{sym_name});
            return buf[0..0];
        }
    };

    buf[0] = .{
        .n_strx = 0,
        .n_type = macho.N_BNSYM,
        .n_sect = sym.n_sect,
        .n_desc = 0,
        .n_value = sym.n_value,
    };
    buf[1] = .{
        .n_strx = try self.strtab.insert(gpa, sym_name),
        .n_type = macho.N_FUN,
        .n_sect = sym.n_sect,
        .n_desc = 0,
        .n_value = sym.n_value,
    };
    buf[2] = .{
        .n_strx = 0,
        .n_type = macho.N_FUN,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = size,
    };
    buf[3] = .{
        .n_strx = 0,
        .n_type = macho.N_ENSYM,
        .n_sect = sym.n_sect,
        .n_desc = 0,
        .n_value = size,
    };

    return buf;
}

pub fn writeStrtab(self: *MachO) !void {
    const gpa = self.base.allocator;
    const seg = self.getLinkeditSegmentPtr();
    const offset = seg.fileoff + seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = self.strtab.buffer.items.len;
    const needed_size_aligned = mem.alignForward(u64, needed_size, @alignOf(u64));
    seg.filesize = offset + needed_size_aligned - seg.fileoff;

    log.debug("writing string table from 0x{x} to 0x{x}", .{ offset, offset + needed_size_aligned });

    const buffer = try gpa.alloc(u8, math.cast(usize, needed_size_aligned) orelse return error.Overflow);
    defer gpa.free(buffer);
    @memcpy(buffer[0..self.strtab.buffer.items.len], self.strtab.buffer.items);
    @memset(buffer[self.strtab.buffer.items.len..], 0);

    try self.base.file.?.pwriteAll(buffer, offset);

    self.symtab_cmd.stroff = @as(u32, @intCast(offset));
    self.symtab_cmd.strsize = @as(u32, @intCast(needed_size_aligned));
}

const SymtabCtx = struct {
    nlocalsym: u32,
    nextdefsym: u32,
    nundefsym: u32,
    imports_table: std.AutoHashMap(SymbolWithLoc, u32),
};

pub fn writeDysymtab(self: *MachO, ctx: SymtabCtx) !void {
    const gpa = self.base.allocator;
    const nstubs = @as(u32, @intCast(self.stub_table.lookup.count()));
    const ngot_entries = @as(u32, @intCast(self.got_table.lookup.count()));
    const nindirectsyms = nstubs * 2 + ngot_entries;
    const iextdefsym = ctx.nlocalsym;
    const iundefsym = iextdefsym + ctx.nextdefsym;

    const seg = self.getLinkeditSegmentPtr();
    const offset = seg.fileoff + seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = nindirectsyms * @sizeOf(u32);
    const needed_size_aligned = mem.alignForward(u64, needed_size, @alignOf(u64));
    seg.filesize = offset + needed_size_aligned - seg.fileoff;

    log.debug("writing indirect symbol table from 0x{x} to 0x{x}", .{ offset, offset + needed_size_aligned });

    var buf = std.ArrayList(u8).init(gpa);
    defer buf.deinit();
    try buf.ensureTotalCapacity(math.cast(usize, needed_size_aligned) orelse return error.Overflow);
    const writer = buf.writer();

    if (self.stubs_section_index) |sect_id| {
        const stubs_header = &self.sections.items(.header)[sect_id];
        stubs_header.reserved1 = 0;
        for (self.stub_table.entries.items) |entry| {
            if (!self.stub_table.lookup.contains(entry)) continue;
            const target_sym = self.getSymbol(entry);
            assert(target_sym.undf());
            try writer.writeInt(u32, iundefsym + ctx.imports_table.get(entry).?, .little);
        }
    }

    if (self.got_section_index) |sect_id| {
        const got = &self.sections.items(.header)[sect_id];
        got.reserved1 = nstubs;
        for (self.got_table.entries.items) |entry| {
            if (!self.got_table.lookup.contains(entry)) continue;
            const target_sym = self.getSymbol(entry);
            if (target_sym.undf()) {
                try writer.writeInt(u32, iundefsym + ctx.imports_table.get(entry).?, .little);
            } else {
                try writer.writeInt(u32, macho.INDIRECT_SYMBOL_LOCAL, .little);
            }
        }
    }

    if (self.la_symbol_ptr_section_index) |sect_id| {
        const la_symbol_ptr = &self.sections.items(.header)[sect_id];
        la_symbol_ptr.reserved1 = nstubs + ngot_entries;
        for (self.stub_table.entries.items) |entry| {
            if (!self.stub_table.lookup.contains(entry)) continue;
            const target_sym = self.getSymbol(entry);
            assert(target_sym.undf());
            try writer.writeInt(u32, iundefsym + ctx.imports_table.get(entry).?, .little);
        }
    }

    const padding = math.cast(usize, needed_size_aligned - needed_size) orelse return error.Overflow;
    if (padding > 0) {
        buf.appendNTimesAssumeCapacity(0, padding);
    }

    assert(buf.items.len == needed_size_aligned);
    try self.base.file.?.pwriteAll(buf.items, offset);

    self.dysymtab_cmd.nlocalsym = ctx.nlocalsym;
    self.dysymtab_cmd.iextdefsym = iextdefsym;
    self.dysymtab_cmd.nextdefsym = ctx.nextdefsym;
    self.dysymtab_cmd.iundefsym = iundefsym;
    self.dysymtab_cmd.nundefsym = ctx.nundefsym;
    self.dysymtab_cmd.indirectsymoff = @as(u32, @intCast(offset));
    self.dysymtab_cmd.nindirectsyms = nindirectsyms;
}

pub fn writeUuid(self: *MachO, comp: *const Compilation, uuid_cmd_offset: u32, has_codesig: bool) !void {
    const file_size = if (!has_codesig) blk: {
        const seg = self.getLinkeditSegmentPtr();
        break :blk seg.fileoff + seg.filesize;
    } else self.codesig_cmd.dataoff;
    try calcUuid(comp, self.base.file.?, file_size, &self.uuid_cmd.uuid);
    const offset = uuid_cmd_offset + @sizeOf(macho.load_command);
    try self.base.file.?.pwriteAll(&self.uuid_cmd.uuid, offset);
}

pub fn writeCodeSignaturePadding(self: *MachO, code_sig: *CodeSignature) !void {
    const seg = self.getLinkeditSegmentPtr();
    // Code signature data has to be 16-bytes aligned for Apple tools to recognize the file
    // https://github.com/opensource-apple/cctools/blob/fdb4825f303fd5c0751be524babd32958181b3ed/libstuff/checkout.c#L271
    const offset = mem.alignForward(u64, seg.fileoff + seg.filesize, 16);
    const needed_size = code_sig.estimateSize(offset);
    seg.filesize = offset + needed_size - seg.fileoff;
    seg.vmsize = mem.alignForward(u64, seg.filesize, getPageSize(self.base.options.target.cpu.arch));
    log.debug("writing code signature padding from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    // Pad out the space. We need to do this to calculate valid hashes for everything in the file
    // except for code signature data.
    try self.base.file.?.pwriteAll(&[_]u8{0}, offset + needed_size - 1);

    self.codesig_cmd.dataoff = @as(u32, @intCast(offset));
    self.codesig_cmd.datasize = @as(u32, @intCast(needed_size));
}

pub fn writeCodeSignature(self: *MachO, comp: *const Compilation, code_sig: *CodeSignature) !void {
    const seg_id = self.header_segment_cmd_index.?;
    const seg = self.segments.items[seg_id];
    const offset = self.codesig_cmd.dataoff;

    var buffer = std.ArrayList(u8).init(self.base.allocator);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(code_sig.size());
    try code_sig.writeAdhocSignature(comp, .{
        .file = self.base.file.?,
        .exec_seg_base = seg.fileoff,
        .exec_seg_limit = seg.filesize,
        .file_size = offset,
        .output_mode = self.base.options.output_mode,
    }, buffer.writer());
    assert(buffer.items.len == code_sig.size());

    log.debug("writing code signature from 0x{x} to 0x{x}", .{
        offset,
        offset + buffer.items.len,
    });

    try self.base.file.?.pwriteAll(buffer.items, offset);
}

/// Writes Mach-O file header.
pub fn writeHeader(self: *MachO, ncmds: u32, sizeofcmds: u32) !void {
    var header: macho.mach_header_64 = .{};
    header.flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK | macho.MH_PIE | macho.MH_TWOLEVEL;

    switch (self.base.options.target.cpu.arch) {
        .aarch64 => {
            header.cputype = macho.CPU_TYPE_ARM64;
            header.cpusubtype = macho.CPU_SUBTYPE_ARM_ALL;
        },
        .x86_64 => {
            header.cputype = macho.CPU_TYPE_X86_64;
            header.cpusubtype = macho.CPU_SUBTYPE_X86_64_ALL;
        },
        else => unreachable,
    }

    switch (self.base.options.output_mode) {
        .Exe => {
            header.filetype = macho.MH_EXECUTE;
        },
        .Lib => {
            // By this point, it can only be a dylib.
            header.filetype = macho.MH_DYLIB;
            header.flags |= macho.MH_NO_REEXPORTED_DYLIBS;
        },
        else => unreachable,
    }

    if (self.thread_vars_section_index) |sect_id| {
        header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;
        if (self.sections.items(.header)[sect_id].size > 0) {
            header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;
        }
    }

    header.ncmds = ncmds;
    header.sizeofcmds = sizeofcmds;

    log.debug("writing Mach-O header {}", .{header});

    try self.base.file.?.pwriteAll(mem.asBytes(&header), 0);
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

fn detectAllocCollision(self: *MachO, start: u64, size: u64) ?u64 {
    // TODO: header and load commands have to be part of the __TEXT segment
    const header_size = self.segments.items[self.header_segment_cmd_index.?].filesize;
    if (start < header_size)
        return header_size;

    const end = start + padToIdeal(size);

    for (self.sections.items(.header)) |header| {
        const tight_size = header.size;
        const increased_size = padToIdeal(tight_size);
        const test_end = header.offset + increased_size;
        if (end > header.offset and start < test_end) {
            return test_end;
        }
    }

    return null;
}

fn allocatedSize(self: *MachO, start: u64) u64 {
    if (start == 0)
        return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    for (self.sections.items(.header)) |header| {
        if (header.offset <= start) continue;
        if (header.offset < min_pos) min_pos = header.offset;
    }
    return min_pos - start;
}

fn findFreeSpace(self: *MachO, object_size: u64, min_alignment: u32) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForward(u64, item_end, min_alignment);
    }
    return start;
}

pub fn allocatedVirtualSize(self: *MachO, start: u64) u64 {
    if (start == 0)
        return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    for (self.sections.items(.segment_index)) |seg_id| {
        const segment = self.segments.items[seg_id];
        if (segment.vmaddr <= start) continue;
        if (segment.vmaddr < min_pos) min_pos = segment.vmaddr;
    }
    return min_pos - start;
}

pub fn ptraceAttach(self: *MachO, pid: std.os.pid_t) !void {
    if (!is_hot_update_compatible) return;

    const mach_task = try std.os.darwin.machTaskForPid(pid);
    log.debug("Mach task for pid {d}: {any}", .{ pid, mach_task });
    self.hot_state.mach_task = mach_task;

    // TODO start exception handler in another thread

    // TODO enable ones we register for exceptions
    // try std.os.ptrace(std.os.darwin.PT.ATTACHEXC, pid, 0, 0);
}

pub fn ptraceDetach(self: *MachO, pid: std.os.pid_t) !void {
    if (!is_hot_update_compatible) return;

    _ = pid;

    // TODO stop exception handler

    // TODO see comment in ptraceAttach
    // try std.os.ptrace(std.os.darwin.PT.DETACH, pid, 0, 0);

    self.hot_state.mach_task = null;
}

pub fn addUndefined(self: *MachO, name: []const u8, flags: RelocFlags) !u32 {
    const gpa = self.base.allocator;

    const gop = try self.getOrPutGlobalPtr(name);
    const global_index = self.getGlobalIndex(name).?;

    if (gop.found_existing) {
        try self.updateRelocActions(global_index, flags);
        return global_index;
    }

    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index };
    gop.value_ptr.* = sym_loc;

    const sym = self.getSymbolPtr(sym_loc);
    sym.n_strx = try self.strtab.insert(gpa, name);
    sym.n_type = macho.N_EXT | macho.N_UNDF;

    try self.unresolved.putNoClobber(gpa, global_index, {});
    try self.updateRelocActions(global_index, flags);

    return global_index;
}

fn updateRelocActions(self: *MachO, global_index: u32, flags: RelocFlags) !void {
    const act_gop = try self.actions.getOrPut(self.base.allocator, global_index);
    if (!act_gop.found_existing) {
        act_gop.value_ptr.* = .{};
    }
    act_gop.value_ptr.add_got = act_gop.value_ptr.add_got or flags.add_got;
    act_gop.value_ptr.add_stub = act_gop.value_ptr.add_stub or flags.add_stub;
}

pub fn makeStaticString(bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    @memcpy(buf[0..bytes.len], bytes);
    return buf;
}

pub fn getSegmentByName(self: MachO, segname: []const u8) ?u8 {
    for (self.segments.items, 0..) |seg, i| {
        if (mem.eql(u8, segname, seg.segName())) return @as(u8, @intCast(i));
    } else return null;
}

pub fn getSegment(self: MachO, sect_id: u8) macho.segment_command_64 {
    const index = self.sections.items(.segment_index)[sect_id];
    return self.segments.items[index];
}

pub fn getSegmentPtr(self: *MachO, sect_id: u8) *macho.segment_command_64 {
    const index = self.sections.items(.segment_index)[sect_id];
    return &self.segments.items[index];
}

pub fn getLinkeditSegmentPtr(self: *MachO) *macho.segment_command_64 {
    const index = self.linkedit_segment_cmd_index.?;
    return &self.segments.items[index];
}

pub fn getSectionByName(self: MachO, segname: []const u8, sectname: []const u8) ?u8 {
    // TODO investigate caching with a hashmap
    for (self.sections.items(.header), 0..) |header, i| {
        if (mem.eql(u8, header.segName(), segname) and mem.eql(u8, header.sectName(), sectname))
            return @as(u8, @intCast(i));
    } else return null;
}

pub fn getSectionIndexes(self: MachO, segment_index: u8) struct { start: u8, end: u8 } {
    var start: u8 = 0;
    const nsects = for (self.segments.items, 0..) |seg, i| {
        if (i == segment_index) break @as(u8, @intCast(seg.nsects));
        start += @as(u8, @intCast(seg.nsects));
    } else 0;
    return .{ .start = start, .end = start + nsects };
}

pub fn symbolIsTemp(self: *MachO, sym_with_loc: SymbolWithLoc) bool {
    const sym = self.getSymbol(sym_with_loc);
    if (!sym.sect()) return false;
    if (sym.ext()) return false;
    const sym_name = self.getSymbolName(sym_with_loc);
    return mem.startsWith(u8, sym_name, "l") or mem.startsWith(u8, sym_name, "L");
}

/// Returns pointer-to-symbol described by `sym_with_loc` descriptor.
pub fn getSymbolPtr(self: *MachO, sym_with_loc: SymbolWithLoc) *macho.nlist_64 {
    if (sym_with_loc.getFile()) |file| {
        const object = &self.objects.items[file];
        return &object.symtab[sym_with_loc.sym_index];
    } else {
        return &self.locals.items[sym_with_loc.sym_index];
    }
}

/// Returns symbol described by `sym_with_loc` descriptor.
pub fn getSymbol(self: *const MachO, sym_with_loc: SymbolWithLoc) macho.nlist_64 {
    if (sym_with_loc.getFile()) |file| {
        const object = &self.objects.items[file];
        return object.symtab[sym_with_loc.sym_index];
    } else {
        return self.locals.items[sym_with_loc.sym_index];
    }
}

/// Returns name of the symbol described by `sym_with_loc` descriptor.
pub fn getSymbolName(self: *const MachO, sym_with_loc: SymbolWithLoc) []const u8 {
    if (sym_with_loc.getFile()) |file| {
        const object = self.objects.items[file];
        return object.getSymbolName(sym_with_loc.sym_index);
    } else {
        const sym = self.locals.items[sym_with_loc.sym_index];
        return self.strtab.get(sym.n_strx).?;
    }
}

/// Returns pointer to the global entry for `name` if one exists.
pub fn getGlobalPtr(self: *MachO, name: []const u8) ?*SymbolWithLoc {
    const global_index = self.resolver.get(name) orelse return null;
    return &self.globals.items[global_index];
}

/// Returns the global entry for `name` if one exists.
pub fn getGlobal(self: *const MachO, name: []const u8) ?SymbolWithLoc {
    const global_index = self.resolver.get(name) orelse return null;
    return self.globals.items[global_index];
}

/// Returns the index of the global entry for `name` if one exists.
pub fn getGlobalIndex(self: *const MachO, name: []const u8) ?u32 {
    return self.resolver.get(name);
}

/// Returns global entry at `index`.
pub fn getGlobalByIndex(self: *const MachO, index: u32) SymbolWithLoc {
    assert(index < self.globals.items.len);
    return self.globals.items[index];
}

const GetOrPutGlobalPtrResult = struct {
    found_existing: bool,
    value_ptr: *SymbolWithLoc,
};

/// Used only for disambiguating local from global at relocation level.
/// TODO this must go away.
pub const global_symbol_bit: u32 = 0x80000000;
pub const global_symbol_mask: u32 = 0x7fffffff;

/// Return pointer to the global entry for `name` if one exists.
/// Puts a new global entry for `name` if one doesn't exist, and
/// returns a pointer to it.
pub fn getOrPutGlobalPtr(self: *MachO, name: []const u8) !GetOrPutGlobalPtrResult {
    if (self.getGlobalPtr(name)) |ptr| {
        return GetOrPutGlobalPtrResult{ .found_existing = true, .value_ptr = ptr };
    }
    const gpa = self.base.allocator;
    const global_index = try self.allocateGlobal();
    const global_name = try gpa.dupe(u8, name);
    _ = try self.resolver.put(gpa, global_name, global_index);
    const ptr = &self.globals.items[global_index];
    return GetOrPutGlobalPtrResult{ .found_existing = false, .value_ptr = ptr };
}

pub fn getAtom(self: *MachO, atom_index: Atom.Index) Atom {
    assert(atom_index < self.atoms.items.len);
    return self.atoms.items[atom_index];
}

pub fn getAtomPtr(self: *MachO, atom_index: Atom.Index) *Atom {
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

/// Returns atom if there is an atom referenced by the symbol described by `sym_with_loc` descriptor.
/// Returns null on failure.
pub fn getAtomIndexForSymbol(self: *MachO, sym_with_loc: SymbolWithLoc) ?Atom.Index {
    assert(sym_with_loc.getFile() == null);
    return self.atom_by_index_table.get(sym_with_loc.sym_index);
}

pub fn getGotEntryAddress(self: *MachO, sym_with_loc: SymbolWithLoc) ?u64 {
    const index = self.got_table.lookup.get(sym_with_loc) orelse return null;
    const header = self.sections.items(.header)[self.got_section_index.?];
    return header.addr + @sizeOf(u64) * index;
}

pub fn getTlvPtrEntryAddress(self: *MachO, sym_with_loc: SymbolWithLoc) ?u64 {
    const index = self.tlv_ptr_table.lookup.get(sym_with_loc) orelse return null;
    const header = self.sections.items(.header)[self.tlv_ptr_section_index.?];
    return header.addr + @sizeOf(u64) * index;
}

pub fn getStubsEntryAddress(self: *MachO, sym_with_loc: SymbolWithLoc) ?u64 {
    const index = self.stub_table.lookup.get(sym_with_loc) orelse return null;
    const header = self.sections.items(.header)[self.stubs_section_index.?];
    return header.addr + stubs.stubSize(self.base.options.target.cpu.arch) * index;
}

/// Returns symbol location corresponding to the set entrypoint if any.
/// Asserts output mode is executable.
pub fn getEntryPoint(self: MachO) ?SymbolWithLoc {
    const entry_name = self.base.options.entry orelse load_commands.default_entry_point;
    const global = self.getGlobal(entry_name) orelse return null;
    return global;
}

pub fn getDebugSymbols(self: *MachO) ?*DebugSymbols {
    if (self.d_sym == null) return null;
    return &self.d_sym.?;
}

pub inline fn getPageSize(cpu_arch: std.Target.Cpu.Arch) u16 {
    return switch (cpu_arch) {
        .aarch64 => 0x4000,
        .x86_64 => 0x1000,
        else => unreachable,
    };
}

pub fn requiresCodeSignature(options: *const link.Options) bool {
    if (options.entitlements) |_| return true;
    const cpu_arch = options.target.cpu.arch;
    const os_tag = options.target.os.tag;
    const abi = options.target.abi;
    if (cpu_arch == .aarch64 and (os_tag == .macos or abi == .simulator)) return true;
    return false;
}

pub fn getSegmentPrecedence(segname: []const u8) u4 {
    if (mem.eql(u8, segname, "__PAGEZERO")) return 0x0;
    if (mem.eql(u8, segname, "__TEXT")) return 0x1;
    if (mem.eql(u8, segname, "__DATA_CONST")) return 0x2;
    if (mem.eql(u8, segname, "__DATA")) return 0x3;
    if (mem.eql(u8, segname, "__LINKEDIT")) return 0x5;
    return 0x4;
}

pub fn getSegmentMemoryProtection(segname: []const u8) macho.vm_prot_t {
    if (mem.eql(u8, segname, "__PAGEZERO")) return macho.PROT.NONE;
    if (mem.eql(u8, segname, "__TEXT")) return macho.PROT.READ | macho.PROT.EXEC;
    if (mem.eql(u8, segname, "__LINKEDIT")) return macho.PROT.READ;
    return macho.PROT.READ | macho.PROT.WRITE;
}

pub fn getSectionPrecedence(header: macho.section_64) u8 {
    const segment_precedence: u4 = getSegmentPrecedence(header.segName());
    const section_precedence: u4 = blk: {
        if (header.isCode()) {
            if (mem.eql(u8, "__text", header.sectName())) break :blk 0x0;
            if (header.type() == macho.S_SYMBOL_STUBS) break :blk 0x1;
            break :blk 0x2;
        }
        switch (header.type()) {
            macho.S_NON_LAZY_SYMBOL_POINTERS,
            macho.S_LAZY_SYMBOL_POINTERS,
            => break :blk 0x0,
            macho.S_MOD_INIT_FUNC_POINTERS => break :blk 0x1,
            macho.S_MOD_TERM_FUNC_POINTERS => break :blk 0x2,
            macho.S_ZEROFILL => break :blk 0xf,
            macho.S_THREAD_LOCAL_REGULAR => break :blk 0xd,
            macho.S_THREAD_LOCAL_ZEROFILL => break :blk 0xe,
            else => {
                if (mem.eql(u8, "__unwind_info", header.sectName())) break :blk 0xe;
                if (mem.eql(u8, "__eh_frame", header.sectName())) break :blk 0xf;
                break :blk 0x3;
            },
        }
    };
    return (@as(u8, @intCast(segment_precedence)) << 4) + section_precedence;
}

pub const ParseErrorCtx = struct {
    arena_allocator: std.heap.ArenaAllocator,
    detected_dylib_id: struct {
        parent: u16,
        required_version: u32,
        found_version: u32,
    },
    detected_targets: std.ArrayList([]const u8),

    pub fn init(gpa: Allocator) ParseErrorCtx {
        return .{
            .arena_allocator = std.heap.ArenaAllocator.init(gpa),
            .detected_dylib_id = undefined,
            .detected_targets = std.ArrayList([]const u8).init(gpa),
        };
    }

    pub fn deinit(ctx: *ParseErrorCtx) void {
        ctx.arena_allocator.deinit();
        ctx.detected_targets.deinit();
    }

    pub fn arena(ctx: *ParseErrorCtx) Allocator {
        return ctx.arena_allocator.allocator();
    }
};

pub fn handleAndReportParseError(
    self: *MachO,
    path: []const u8,
    err: ParseError,
    ctx: *const ParseErrorCtx,
) error{OutOfMemory}!void {
    const cpu_arch = self.base.options.target.cpu.arch;
    switch (err) {
        error.DylibAlreadyExists => {},
        error.IncompatibleDylibVersion => {
            const parent = &self.dylibs.items[ctx.detected_dylib_id.parent];
            try self.reportDependencyError(
                if (parent.id) |id| id.name else parent.path,
                path,
                "incompatible dylib version: expected at least '{}', but found '{}'",
                .{
                    load_commands.appleVersionToSemanticVersion(ctx.detected_dylib_id.required_version),
                    load_commands.appleVersionToSemanticVersion(ctx.detected_dylib_id.found_version),
                },
            );
        },
        error.UnknownFileType => try self.reportParseError(path, "unknown file type", .{}),
        error.InvalidTarget, error.InvalidTargetFatLibrary => {
            var targets_string = std.ArrayList(u8).init(self.base.allocator);
            defer targets_string.deinit();

            if (ctx.detected_targets.items.len > 1) {
                try targets_string.writer().writeAll("(");
                for (ctx.detected_targets.items) |t| {
                    try targets_string.writer().print("{s}, ", .{t});
                }
                try targets_string.resize(targets_string.items.len - 2);
                try targets_string.writer().writeAll(")");
            } else {
                try targets_string.writer().writeAll(ctx.detected_targets.items[0]);
            }

            switch (err) {
                error.InvalidTarget => try self.reportParseError(
                    path,
                    "invalid target: expected '{}', but found '{s}'",
                    .{ Platform.fromTarget(self.base.options.target).fmtTarget(cpu_arch), targets_string.items },
                ),
                error.InvalidTargetFatLibrary => try self.reportParseError(
                    path,
                    "invalid architecture in universal library: expected '{s}', but found '{s}'",
                    .{ @tagName(cpu_arch), targets_string.items },
                ),
                else => unreachable,
            }
        },
        else => |e| try self.reportParseError(path, "{s}: parsing object failed", .{@errorName(e)}),
    }
}

fn reportMissingLibraryError(
    self: *MachO,
    checked_paths: []const []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const gpa = self.base.allocator;
    try self.misc_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try gpa.alloc(File.ErrorMsg, checked_paths.len);
    errdefer gpa.free(notes);
    for (checked_paths, notes) |path, *note| {
        note.* = .{ .msg = try std.fmt.allocPrint(gpa, "tried {s}", .{path}) };
    }
    self.misc_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, format, args),
        .notes = notes,
    });
}

fn reportDependencyError(
    self: *MachO,
    parent: []const u8,
    path: ?[]const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const gpa = self.base.allocator;
    try self.misc_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try std.ArrayList(File.ErrorMsg).initCapacity(gpa, 2);
    defer notes.deinit();
    if (path) |p| {
        notes.appendAssumeCapacity(.{ .msg = try std.fmt.allocPrint(gpa, "while parsing {s}", .{p}) });
    }
    notes.appendAssumeCapacity(.{ .msg = try std.fmt.allocPrint(gpa, "a dependency of {s}", .{parent}) });
    self.misc_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, format, args),
        .notes = try notes.toOwnedSlice(),
    });
}

pub fn reportParseError(
    self: *MachO,
    path: []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const gpa = self.base.allocator;
    try self.misc_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try gpa.alloc(File.ErrorMsg, 1);
    errdefer gpa.free(notes);
    notes[0] = .{ .msg = try std.fmt.allocPrint(gpa, "while parsing {s}", .{path}) };
    self.misc_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, format, args),
        .notes = notes,
    });
}

pub fn reportUndefined(self: *MachO) error{OutOfMemory}!void {
    const gpa = self.base.allocator;
    const count = self.unresolved.count();
    try self.misc_errors.ensureUnusedCapacity(gpa, count);

    for (self.unresolved.keys()) |global_index| {
        const global = self.globals.items[global_index];
        const sym_name = self.getSymbolName(global);

        var notes = try std.ArrayList(File.ErrorMsg).initCapacity(gpa, 1);
        defer notes.deinit();

        if (global.getFile()) |file| {
            const note = try std.fmt.allocPrint(gpa, "referenced in {s}", .{
                self.objects.items[file].name,
            });
            notes.appendAssumeCapacity(.{ .msg = note });
        }

        var err_msg = File.ErrorMsg{
            .msg = try std.fmt.allocPrint(gpa, "undefined reference to symbol {s}", .{sym_name}),
        };
        err_msg.notes = try notes.toOwnedSlice();

        self.misc_errors.appendAssumeCapacity(err_msg);
    }
}

fn reportSymbolCollision(
    self: *MachO,
    first: SymbolWithLoc,
    other: SymbolWithLoc,
) error{OutOfMemory}!void {
    const gpa = self.base.allocator;
    try self.misc_errors.ensureUnusedCapacity(gpa, 1);

    var notes = try std.ArrayList(File.ErrorMsg).initCapacity(gpa, 2);
    defer notes.deinit();

    if (first.getFile()) |file| {
        const note = try std.fmt.allocPrint(gpa, "first definition in {s}", .{
            self.objects.items[file].name,
        });
        notes.appendAssumeCapacity(.{ .msg = note });
    }
    if (other.getFile()) |file| {
        const note = try std.fmt.allocPrint(gpa, "next definition in {s}", .{
            self.objects.items[file].name,
        });
        notes.appendAssumeCapacity(.{ .msg = note });
    }

    var err_msg = File.ErrorMsg{ .msg = try std.fmt.allocPrint(gpa, "symbol {s} defined multiple times", .{
        self.getSymbolName(first),
    }) };
    err_msg.notes = try notes.toOwnedSlice();

    self.misc_errors.appendAssumeCapacity(err_msg);
}

fn reportUnhandledSymbolType(self: *MachO, sym_with_loc: SymbolWithLoc) error{OutOfMemory}!void {
    const gpa = self.base.allocator;
    try self.misc_errors.ensureUnusedCapacity(gpa, 1);

    const notes = try gpa.alloc(File.ErrorMsg, 1);
    errdefer gpa.free(notes);

    const file = sym_with_loc.getFile().?;
    notes[0] = .{ .msg = try std.fmt.allocPrint(gpa, "defined in {s}", .{self.objects.items[file].name}) };

    const sym = self.getSymbol(sym_with_loc);
    const sym_type = if (sym.stab())
        "stab"
    else if (sym.indr())
        "indirect"
    else if (sym.abs())
        "absolute"
    else
        unreachable;

    self.misc_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, "unhandled symbol type: '{s}' has type {s}", .{
            self.getSymbolName(sym_with_loc),
            sym_type,
        }),
        .notes = notes,
    });
}

/// Binary search
pub fn bsearch(comptime T: type, haystack: []align(1) const T, predicate: anytype) usize {
    if (!@hasDecl(@TypeOf(predicate), "predicate"))
        @compileError("Predicate is required to define fn predicate(@This(), T) bool");

    var min: usize = 0;
    var max: usize = haystack.len;
    while (min < max) {
        const index = (min + max) / 2;
        const curr = haystack[index];
        if (predicate.predicate(curr)) {
            min = index + 1;
        } else {
            max = index;
        }
    }
    return min;
}

/// Linear search
pub fn lsearch(comptime T: type, haystack: []align(1) const T, predicate: anytype) usize {
    if (!@hasDecl(@TypeOf(predicate), "predicate"))
        @compileError("Predicate is required to define fn predicate(@This(), T) bool");

    var i: usize = 0;
    while (i < haystack.len) : (i += 1) {
        if (predicate.predicate(haystack[i])) break;
    }
    return i;
}

pub fn logSegments(self: *MachO) void {
    log.debug("segments:", .{});
    for (self.segments.items, 0..) |segment, i| {
        log.debug("  segment({d}): {s} @{x} ({x}), sizeof({x})", .{
            i,
            segment.segName(),
            segment.fileoff,
            segment.vmaddr,
            segment.vmsize,
        });
    }
}

pub fn logSections(self: *MachO) void {
    log.debug("sections:", .{});
    for (self.sections.items(.header), 0..) |header, i| {
        log.debug("  sect({d}): {s},{s} @{x} ({x}), sizeof({x})", .{
            i + 1,
            header.segName(),
            header.sectName(),
            header.offset,
            header.addr,
            header.size,
        });
    }
}

fn logSymAttributes(sym: macho.nlist_64, buf: []u8) []const u8 {
    if (sym.sect()) {
        buf[0] = 's';
    }
    if (sym.ext()) {
        if (sym.weakDef() or sym.pext()) {
            buf[1] = 'w';
        } else {
            buf[1] = 'e';
        }
    }
    if (sym.tentative()) {
        buf[2] = 't';
    }
    if (sym.undf()) {
        buf[3] = 'u';
    }
    return buf[0..];
}

pub fn logSymtab(self: *MachO) void {
    var buf: [4]u8 = undefined;

    const scoped_log = std.log.scoped(.symtab);

    scoped_log.debug("locals:", .{});
    for (self.objects.items, 0..) |object, id| {
        scoped_log.debug("  object({d}): {s}", .{ id, object.name });
        if (object.in_symtab == null) continue;
        for (object.symtab, 0..) |sym, sym_id| {
            @memset(&buf, '_');
            scoped_log.debug("    %{d}: {s} @{x} in sect({d}), {s}", .{
                sym_id,
                object.getSymbolName(@as(u32, @intCast(sym_id))),
                sym.n_value,
                sym.n_sect,
                logSymAttributes(sym, &buf),
            });
        }
    }
    scoped_log.debug("  object(-1)", .{});
    for (self.locals.items, 0..) |sym, sym_id| {
        if (sym.undf()) continue;
        scoped_log.debug("    %{d}: {s} @{x} in sect({d}), {s}", .{
            sym_id,
            self.strtab.get(sym.n_strx).?,
            sym.n_value,
            sym.n_sect,
            logSymAttributes(sym, &buf),
        });
    }

    scoped_log.debug("exports:", .{});
    for (self.globals.items, 0..) |global, i| {
        const sym = self.getSymbol(global);
        if (sym.undf()) continue;
        if (sym.n_desc == MachO.N_DEAD) continue;
        scoped_log.debug("    %{d}: {s} @{x} in sect({d}), {s} (def in object({?}))", .{
            i,
            self.getSymbolName(global),
            sym.n_value,
            sym.n_sect,
            logSymAttributes(sym, &buf),
            global.file,
        });
    }

    scoped_log.debug("imports:", .{});
    for (self.globals.items, 0..) |global, i| {
        const sym = self.getSymbol(global);
        if (!sym.undf()) continue;
        if (sym.n_desc == MachO.N_DEAD) continue;
        const ord = @divTrunc(sym.n_desc, macho.N_SYMBOL_RESOLVER);
        scoped_log.debug("    %{d}: {s} @{x} in ord({d}), {s}", .{
            i,
            self.getSymbolName(global),
            sym.n_value,
            ord,
            logSymAttributes(sym, &buf),
        });
    }

    scoped_log.debug("GOT entries:", .{});
    scoped_log.debug("{}", .{self.got_table});

    scoped_log.debug("TLV pointers:", .{});
    scoped_log.debug("{}", .{self.tlv_ptr_table});

    scoped_log.debug("stubs entries:", .{});
    scoped_log.debug("{}", .{self.stub_table});

    scoped_log.debug("thunks:", .{});
    for (self.thunks.items, 0..) |thunk, i| {
        scoped_log.debug("  thunk({d})", .{i});
        const slice = thunk.targets.slice();
        for (slice.items(.tag), slice.items(.target), 0..) |tag, target, j| {
            const atom_index = @as(u32, @intCast(thunk.getStartAtomIndex() + j));
            const atom = self.getAtom(atom_index);
            const atom_sym = self.getSymbol(atom.getSymbolWithLoc());
            const target_addr = switch (tag) {
                .stub => self.getStubsEntryAddress(target).?,
                .atom => self.getSymbol(target).n_value,
            };
            scoped_log.debug("    {d}@{x} => {s}({s}@{x})", .{
                j,
                atom_sym.n_value,
                @tagName(tag),
                self.getSymbolName(target),
                target_addr,
            });
        }
    }
}

pub fn logAtoms(self: *MachO) void {
    log.debug("atoms:", .{});
    const slice = self.sections.slice();
    for (slice.items(.first_atom_index), 0..) |first_atom_index, sect_id| {
        var atom_index = first_atom_index orelse continue;
        const header = slice.items(.header)[sect_id];

        log.debug("{s},{s}", .{ header.segName(), header.sectName() });

        while (true) {
            const atom = self.getAtom(atom_index);
            self.logAtom(atom_index, log);

            if (atom.next_index) |next_index| {
                atom_index = next_index;
            } else break;
        }
    }
}

pub fn logAtom(self: *MachO, atom_index: Atom.Index, logger: anytype) void {
    if (!build_options.enable_logging) return;

    const atom = self.getAtom(atom_index);
    const sym = self.getSymbol(atom.getSymbolWithLoc());
    const sym_name = self.getSymbolName(atom.getSymbolWithLoc());
    logger.debug("  ATOM({d}, %{d}, '{s}') @ {x} (sizeof({x}), alignof({x})) in object({?}) in sect({d})", .{
        atom_index,
        atom.sym_index,
        sym_name,
        sym.n_value,
        atom.size,
        atom.alignment,
        atom.getFile(),
        sym.n_sect,
    });

    if (atom.getFile() != null) {
        var it = Atom.getInnerSymbolsIterator(self, atom_index);
        while (it.next()) |sym_loc| {
            const inner = self.getSymbol(sym_loc);
            const inner_name = self.getSymbolName(sym_loc);
            const offset = Atom.calcInnerSymbolOffset(self, atom_index, sym_loc.sym_index);

            logger.debug("    (%{d}, '{s}') @ {x} ({x})", .{
                sym_loc.sym_index,
                inner_name,
                inner.n_value,
                offset,
            });
        }

        if (Atom.getSectionAlias(self, atom_index)) |sym_loc| {
            const alias = self.getSymbol(sym_loc);
            const alias_name = self.getSymbolName(sym_loc);

            logger.debug("    (%{d}, '{s}') @ {x} ({x})", .{
                sym_loc.sym_index,
                alias_name,
                alias.n_value,
                0,
            });
        }
    }
}

pub const base_tag: File.Tag = File.Tag.macho;
pub const N_DEAD: u16 = @as(u16, @bitCast(@as(i16, -1)));

/// Mode of operation of the linker.
pub const Mode = enum {
    /// Incremental mode will preallocate segments/sections and is compatible with
    /// watch and HCS modes of operation.
    incremental,
    /// Zld mode will link relocatables in a traditional, one-shot
    /// fashion (default for LLVM backend). It acts as a drop-in replacement for
    /// LLD.
    zld,
};

pub const Section = struct {
    header: macho.section_64,
    segment_index: u8,
    first_atom_index: ?Atom.Index = null,
    last_atom_index: ?Atom.Index = null,

    /// A list of atoms that have surplus capacity. This list can have false
    /// positives, as functions grow and shrink over time, only sometimes being added
    /// or removed from the freelist.
    ///
    /// An atom has surplus capacity when its overcapacity value is greater than
    /// padToIdeal(minimum_atom_size). That is, when it has so
    /// much extra capacity, that we could fit a small new symbol in it, itself with
    /// ideal_capacity or more.
    ///
    /// Ideal capacity is defined by size + (size / ideal_factor).
    ///
    /// Overcapacity is measured by actual_capacity - ideal_capacity. Note that
    /// overcapacity can be negative. A simple way to have negative overcapacity is to
    /// allocate a fresh atom, which will have ideal capacity, and then grow it
    /// by 1 byte. It will then have -1 overcapacity.
    free_list: std.ArrayListUnmanaged(Atom.Index) = .{},
};

const is_hot_update_compatible = switch (builtin.target.os.tag) {
    .macos => true,
    else => false,
};

const LazySymbolTable = std.AutoArrayHashMapUnmanaged(Module.Decl.OptionalIndex, LazySymbolMetadata);

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_atom: Atom.Index = undefined,
    data_const_atom: Atom.Index = undefined,
    text_state: State = .unused,
    data_const_state: State = .unused,
};

const TlvSymbolTable = std.AutoArrayHashMapUnmanaged(SymbolWithLoc, Atom.Index);

const DeclMetadata = struct {
    atom: Atom.Index,
    section: u8,
    /// A list of all exports aliases of this Decl.
    /// TODO do we actually need this at all?
    exports: std.ArrayListUnmanaged(u32) = .{},

    fn getExport(m: DeclMetadata, macho_file: *const MachO, name: []const u8) ?u32 {
        for (m.exports.items) |exp| {
            if (mem.eql(u8, name, macho_file.getSymbolName(.{ .sym_index = exp }))) return exp;
        }
        return null;
    }

    fn getExportPtr(m: *DeclMetadata, macho_file: *MachO, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            if (mem.eql(u8, name, macho_file.getSymbolName(.{ .sym_index = exp.* }))) return exp;
        }
        return null;
    }
};

const DeclTable = std.AutoArrayHashMapUnmanaged(Module.Decl.Index, DeclMetadata);
const AnonDeclTable = std.AutoHashMapUnmanaged(InternPool.Index, DeclMetadata);
const BindingTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Atom.Binding));
const UnnamedConstTable = std.AutoArrayHashMapUnmanaged(Module.Decl.Index, std.ArrayListUnmanaged(Atom.Index));
const RebaseTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(u32));
const RelocationTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Relocation));
const ActionTable = std.AutoHashMapUnmanaged(u32, RelocFlags);

pub const RelocFlags = packed struct {
    add_got: bool = false,
    add_stub: bool = false,
};

pub const SymbolWithLoc = extern struct {
    // Index into the respective symbol table.
    sym_index: u32,

    // 0 means it's a synthetic global.
    file: u32 = 0,

    pub fn getFile(self: SymbolWithLoc) ?u32 {
        if (self.file == 0) return null;
        return self.file - 1;
    }

    pub fn eql(self: SymbolWithLoc, other: SymbolWithLoc) bool {
        return self.file == other.file and self.sym_index == other.sym_index;
    }
};

const HotUpdateState = struct {
    mach_task: ?std.os.darwin.MachTask = null,
};

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_text_block_size = 64;
pub const min_text_capacity = padToIdeal(minimum_text_block_size);

/// Default virtual memory offset corresponds to the size of __PAGEZERO segment and
/// start of __TEXT segment.
pub const default_pagezero_vmsize: u64 = 0x100000000;

/// We commit 0x1000 = 4096 bytes of space to the header and
/// the table of load commands. This should be plenty for any
/// potential future extensions.
pub const default_headerpad_size: u32 = 0x1000;

const MachO = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const aarch64 = @import("../arch/aarch64/bits.zig");
const calcUuid = @import("MachO/uuid.zig").calcUuid;
const codegen = @import("../codegen.zig");
const dead_strip = @import("MachO/dead_strip.zig");
const fat = @import("MachO/fat.zig");
const link = @import("../link.zig");
const llvm_backend = @import("../codegen/llvm.zig");
const load_commands = @import("MachO/load_commands.zig");
const stubs = @import("MachO/stubs.zig");
const tapi = @import("tapi.zig");
const target_util = @import("../target.zig");
const thunks = @import("MachO/thunks.zig");
const trace = @import("../tracy.zig").trace;
const zld = @import("MachO/zld.zig");

const Air = @import("../Air.zig");
const Allocator = mem.Allocator;
const Archive = @import("MachO/Archive.zig");
pub const Atom = @import("MachO/Atom.zig");
const Cache = std.Build.Cache;
const CodeSignature = @import("MachO/CodeSignature.zig");
const Compilation = @import("../Compilation.zig");
const Dwarf = File.Dwarf;
const DwarfInfo = @import("MachO/DwarfInfo.zig");
const Dylib = @import("MachO/Dylib.zig");
const File = link.File;
const Object = @import("MachO/Object.zig");
const LibStub = tapi.LibStub;
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Md5 = std.crypto.hash.Md5;
const Module = @import("../Module.zig");
const InternPool = @import("../InternPool.zig");
const Platform = load_commands.Platform;
const Relocation = @import("MachO/Relocation.zig");
const StringTable = @import("StringTable.zig");
const TableSection = @import("table_section.zig").TableSection;
const Trie = @import("MachO/Trie.zig");
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const Value = @import("../value.zig").Value;
const Alignment = Atom.Alignment;

pub const DebugSymbols = @import("MachO/DebugSymbols.zig");
pub const Bind = @import("MachO/dyld_info/bind.zig").Bind(*const MachO, SymbolWithLoc);
pub const LazyBind = @import("MachO/dyld_info/bind.zig").LazyBind(*const MachO, SymbolWithLoc);
pub const Rebase = @import("MachO/dyld_info/Rebase.zig");
