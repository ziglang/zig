base: link.File,

/// If this is not null, an object file is created by LLVM and emitted to zcu_object_sub_path.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

/// A list of all input files.
/// Index of each input file also encodes the priority or precedence of one input file
/// over another.
files: std.MultiArrayList(File.Entry) = .{},
/// Long-lived list of all file descriptors.
/// We store them globally rather than per actual File so that we can re-use
/// one file handle per every object file within an archive.
file_handles: std.ArrayListUnmanaged(File.Handle) = .{},
zig_object: ?File.Index = null,
internal_object: ?File.Index = null,
objects: std.ArrayListUnmanaged(File.Index) = .{},
dylibs: std.ArrayListUnmanaged(File.Index) = .{},

segments: std.ArrayListUnmanaged(macho.segment_command_64) = .{},
sections: std.MultiArrayList(Section) = .{},

resolver: SymbolResolver = .{},
/// This table will be populated after `scanRelocs` has run.
/// Key is symbol index.
undefs: std.AutoHashMapUnmanaged(SymbolResolver.Index, std.ArrayListUnmanaged(Ref)) = .{},

dyld_info_cmd: macho.dyld_info_command = .{},
symtab_cmd: macho.symtab_command = .{},
dysymtab_cmd: macho.dysymtab_command = .{},
function_starts_cmd: macho.linkedit_data_command = .{ .cmd = .FUNCTION_STARTS },
data_in_code_cmd: macho.linkedit_data_command = .{ .cmd = .DATA_IN_CODE },
uuid_cmd: macho.uuid_command = .{ .uuid = [_]u8{0} ** 16 },
codesig_cmd: macho.linkedit_data_command = .{ .cmd = .CODE_SIGNATURE },

pagezero_seg_index: ?u8 = null,
text_seg_index: ?u8 = null,
linkedit_seg_index: ?u8 = null,
text_sect_index: ?u8 = null,
data_sect_index: ?u8 = null,
got_sect_index: ?u8 = null,
stubs_sect_index: ?u8 = null,
stubs_helper_sect_index: ?u8 = null,
la_symbol_ptr_sect_index: ?u8 = null,
tlv_ptr_sect_index: ?u8 = null,
eh_frame_sect_index: ?u8 = null,
unwind_info_sect_index: ?u8 = null,
objc_stubs_sect_index: ?u8 = null,

thunks: std.ArrayListUnmanaged(Thunk) = .{},

/// Output synthetic sections
symtab: std.ArrayListUnmanaged(macho.nlist_64) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
indsymtab: Indsymtab = .{},
got: GotSection = .{},
zig_got: ZigGotSection = .{},
stubs: StubsSection = .{},
stubs_helper: StubsHelperSection = .{},
objc_stubs: ObjcStubsSection = .{},
la_symbol_ptr: LaSymbolPtrSection = .{},
tlv_ptr: TlvPtrSection = .{},
rebase: Rebase = .{},
bind: Bind = .{},
weak_bind: WeakBind = .{},
lazy_bind: LazyBind = .{},
export_trie: ExportTrie = .{},
unwind_info: UnwindInfo = .{},
data_in_code: DataInCode = .{},

/// Tracked loadable segments during incremental linking.
zig_text_seg_index: ?u8 = null,
zig_got_seg_index: ?u8 = null,
zig_const_seg_index: ?u8 = null,
zig_data_seg_index: ?u8 = null,
zig_bss_seg_index: ?u8 = null,

/// Tracked section headers with incremental updates to Zig object.
zig_text_sect_index: ?u8 = null,
zig_got_sect_index: ?u8 = null,
zig_const_sect_index: ?u8 = null,
zig_data_sect_index: ?u8 = null,
zig_bss_sect_index: ?u8 = null,

/// Tracked DWARF section headers that apply only when we emit relocatable.
/// For executable and loadable images, DWARF is tracked directly by dSYM bundle object.
debug_info_sect_index: ?u8 = null,
debug_abbrev_sect_index: ?u8 = null,
debug_str_sect_index: ?u8 = null,
debug_aranges_sect_index: ?u8 = null,
debug_line_sect_index: ?u8 = null,

has_tlv: bool = false,
binds_to_weak: bool = false,
weak_defines: bool = false,

/// Options
/// SDK layout
sdk_layout: ?SdkLayout,
/// Size of the __PAGEZERO segment.
pagezero_size: ?u64,
/// Minimum space for future expansion of the load commands.
headerpad_size: ?u32,
/// Set enough space as if all paths were MATPATHLEN.
headerpad_max_install_names: bool,
/// Remove dylibs that are unreachable by the entry point or exported symbols.
dead_strip_dylibs: bool,
/// Treatment of undefined symbols
undefined_treatment: UndefinedTreatment,
/// Resolved list of library search directories
lib_dirs: []const []const u8,
/// Resolved list of framework search directories
framework_dirs: []const []const u8,
/// List of input frameworks
frameworks: []const Framework,
/// Install name for the dylib.
/// TODO: unify with soname
install_name: ?[]const u8,
/// Path to entitlements file.
entitlements: ?[]const u8,
compatibility_version: ?std.SemanticVersion,
/// Entry name
entry_name: ?[]const u8,
platform: Platform,
sdk_version: ?std.SemanticVersion,
/// When set to true, the linker will hoist all dylibs including system dependent dylibs.
no_implicit_dylibs: bool = false,
/// Whether the linker should parse and always force load objects containing ObjC in archives.
// TODO: in Zig we currently take -ObjC as always on
force_load_objc: bool = true,

/// Hot-code swapping state.
hot_state: if (is_hot_update_compatible) HotUpdateState else struct {} = .{},

/// When adding a new field, remember to update `hashAddFrameworks`.
pub const Framework = struct {
    needed: bool = false,
    weak: bool = false,
    path: []const u8,
};

pub fn hashAddFrameworks(man: *Cache.Manifest, hm: []const Framework) !void {
    for (hm) |value| {
        man.hash.add(value.needed);
        man.hash.add(value.weak);
        _ = try man.addFile(value.path, null);
    }
}

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*MachO {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .macho);

    const gpa = comp.gpa;
    const use_llvm = comp.config.use_llvm;
    const opt_zcu = comp.module;
    const optimize_mode = comp.root_mod.optimize_mode;
    const output_mode = comp.config.output_mode;
    const link_mode = comp.config.link_mode;

    // If using LLVM to generate the object file for the zig compilation unit,
    // we need a place to put the object file so that it can be subsequently
    // handled.
    const zcu_object_sub_path = if (!use_llvm)
        null
    else
        try std.fmt.allocPrint(arena, "{s}.o", .{emit.sub_path});
    const allow_shlib_undefined = options.allow_shlib_undefined orelse false;

    const self = try arena.create(MachO);
    self.* = .{
        .base = .{
            .tag = .macho,
            .comp = comp,
            .emit = emit,
            .zcu_object_sub_path = zcu_object_sub_path,
            .gc_sections = options.gc_sections orelse (optimize_mode != .Debug),
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 16777216,
            .allow_shlib_undefined = allow_shlib_undefined,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
            .rpath_list = options.rpath_list,
        },
        .pagezero_size = options.pagezero_size,
        .headerpad_size = options.headerpad_size,
        .headerpad_max_install_names = options.headerpad_max_install_names,
        .dead_strip_dylibs = options.dead_strip_dylibs,
        .sdk_layout = options.darwin_sdk_layout,
        .frameworks = options.frameworks,
        .install_name = options.install_name,
        .entitlements = options.entitlements,
        .compatibility_version = options.compatibility_version,
        .entry_name = switch (options.entry) {
            .disabled => null,
            .default => if (output_mode != .Exe) null else default_entry_symbol_name,
            .enabled => default_entry_symbol_name,
            .named => |name| name,
        },
        .platform = Platform.fromTarget(target),
        .sdk_version = if (options.darwin_sdk_layout) |layout| inferSdkVersion(comp, layout) else null,
        .undefined_treatment = if (allow_shlib_undefined) .dynamic_lookup else .@"error",
        .lib_dirs = options.lib_dirs,
        .framework_dirs = options.framework_dirs,
        .force_load_objc = options.force_load_objc,
    };
    if (use_llvm and comp.config.have_zcu) {
        self.llvm_object = try LlvmObject.create(arena, comp);
    }
    errdefer self.base.destroy();

    self.base.file = try emit.directory.handle.createFile(emit.sub_path, .{
        .truncate = true,
        .read = true,
        .mode = link.File.determineMode(false, output_mode, link_mode),
    });

    // Append null file
    try self.files.append(gpa, .null);
    // Append empty string to string tables
    try self.strtab.append(gpa, 0);

    if (opt_zcu) |zcu| {
        if (!use_llvm) {
            const index: File.Index = @intCast(try self.files.addOne(gpa));
            self.files.set(index, .{ .zig_object = .{
                .index = index,
                .path = try std.fmt.allocPrint(arena, "{s}.o", .{fs.path.stem(
                    zcu.main_mod.root_src_path,
                )}),
            } });
            self.zig_object = index;
            const zo = self.getZigObject().?;
            try zo.init(self);

            try self.initMetadata(.{
                .emit = emit,
                .zo = zo,
                .symbol_count_hint = options.symbol_count_hint,
                .program_code_size_hint = options.program_code_size_hint,
            });
        }
    }

    return self;
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*MachO {
    // TODO: restore saved linker state, don't truncate the file, and
    // participate in incremental compilation.
    return createEmpty(arena, comp, emit, options);
}

pub fn deinit(self: *MachO) void {
    const gpa = self.base.comp.gpa;

    if (self.llvm_object) |llvm_object| llvm_object.deinit();

    if (self.d_sym) |*d_sym| {
        d_sym.deinit();
    }

    for (self.file_handles.items) |handle| {
        handle.close();
    }
    self.file_handles.deinit(gpa);

    for (self.files.items(.tags), self.files.items(.data)) |tag, *data| switch (tag) {
        .null => {},
        .zig_object => data.zig_object.deinit(gpa),
        .internal => data.internal.deinit(gpa),
        .object => data.object.deinit(gpa),
        .dylib => data.dylib.deinit(gpa),
    };
    self.files.deinit(gpa);
    self.objects.deinit(gpa);
    self.dylibs.deinit(gpa);

    self.segments.deinit(gpa);
    for (
        self.sections.items(.atoms),
        self.sections.items(.out),
        self.sections.items(.thunks),
        self.sections.items(.relocs),
    ) |*atoms, *out, *thnks, *relocs| {
        atoms.deinit(gpa);
        out.deinit(gpa);
        thnks.deinit(gpa);
        relocs.deinit(gpa);
    }
    self.sections.deinit(gpa);

    self.resolver.deinit(gpa);
    {
        var it = self.undefs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(gpa);
        }
        self.undefs.deinit(gpa);
    }

    self.symtab.deinit(gpa);
    self.strtab.deinit(gpa);
    self.got.deinit(gpa);
    self.zig_got.deinit(gpa);
    self.stubs.deinit(gpa);
    self.objc_stubs.deinit(gpa);
    self.tlv_ptr.deinit(gpa);
    self.rebase.deinit(gpa);
    self.bind.deinit(gpa);
    self.weak_bind.deinit(gpa);
    self.lazy_bind.deinit(gpa);
    self.export_trie.deinit(gpa);
    self.unwind_info.deinit(gpa);
    self.data_in_code.deinit(gpa);

    self.thunks.deinit(gpa);
}

pub fn flush(self: *MachO, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    try self.flushModule(arena, tid, prog_node);
}

pub fn flushModule(self: *MachO, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;

    if (self.llvm_object) |llvm_object| {
        try self.base.emitLlvmObject(arena, llvm_object, prog_node);
    }

    const sub_prog_node = prog_node.start("MachO Flush", 0);
    defer sub_prog_node.end();

    const directory = self.base.emit.directory;
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.emit.sub_path});
    const module_obj_path: ?[]const u8 = if (self.base.zcu_object_sub_path) |path| blk: {
        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, path });
        } else {
            break :blk path;
        }
    } else null;

    // --verbose-link
    if (comp.verbose_link) try self.dumpArgv(comp);

    if (self.getZigObject()) |zo| try zo.flushModule(self, tid);
    if (self.base.isStaticLib()) return relocatable.flushStaticLib(self, comp, module_obj_path);
    if (self.base.isObject()) return relocatable.flushObject(self, comp, module_obj_path);

    var positionals = std.ArrayList(Compilation.LinkObject).init(gpa);
    defer positionals.deinit();

    try positionals.ensureUnusedCapacity(comp.objects.len);
    positionals.appendSliceAssumeCapacity(comp.objects);

    // This is a set of object files emitted by clang in a single `build-exe` invocation.
    // For instance, the implicit `a.o` as compiled by `zig build-exe a.c` will end up
    // in this set.
    try positionals.ensureUnusedCapacity(comp.c_object_table.keys().len);
    for (comp.c_object_table.keys()) |key| {
        positionals.appendAssumeCapacity(.{ .path = key.status.success.object_path });
    }

    if (module_obj_path) |path| try positionals.append(.{ .path = path });

    // TSAN
    if (comp.config.any_sanitize_thread) {
        try positionals.append(.{ .path = comp.tsan_lib.?.full_object_path });
    }

    for (positionals.items) |obj| {
        self.parsePositional(obj.path, obj.must_link) catch |err| switch (err) {
            error.MalformedObject,
            error.MalformedArchive,
            error.MalformedDylib,
            error.InvalidCpuArch,
            error.InvalidTarget,
            => continue, // already reported
            error.UnknownFileType => try self.reportParseError(obj.path, "unknown file type for an object file", .{}),
            else => |e| try self.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    var system_libs = std.ArrayList(SystemLib).init(gpa);
    defer system_libs.deinit();

    // libs
    try system_libs.ensureUnusedCapacity(comp.system_libs.values().len);
    for (comp.system_libs.values()) |info| {
        system_libs.appendAssumeCapacity(.{
            .needed = info.needed,
            .weak = info.weak,
            .path = info.path.?,
        });
    }

    // frameworks
    try system_libs.ensureUnusedCapacity(self.frameworks.len);
    for (self.frameworks) |info| {
        system_libs.appendAssumeCapacity(.{
            .needed = info.needed,
            .weak = info.weak,
            .path = info.path,
        });
    }

    // libc++ dep
    if (comp.config.link_libcpp) {
        try system_libs.ensureUnusedCapacity(2);
        system_libs.appendAssumeCapacity(.{ .path = comp.libcxxabi_static_lib.?.full_object_path });
        system_libs.appendAssumeCapacity(.{ .path = comp.libcxx_static_lib.?.full_object_path });
    }

    // libc/libSystem dep
    self.resolveLibSystem(arena, comp, &system_libs) catch |err| switch (err) {
        error.MissingLibSystem => {}, // already reported
        else => |e| return e, // TODO: convert into an error
    };

    for (system_libs.items) |lib| {
        self.parseLibrary(lib, false) catch |err| switch (err) {
            error.MalformedArchive,
            error.MalformedDylib,
            error.InvalidCpuArch,
            => continue, // already reported
            error.UnknownFileType => try self.reportParseError(lib.path, "unknown file type for a library", .{}),
            else => |e| try self.reportParseError(
                lib.path,
                "unexpected error: parsing library failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    // Finally, link against compiler_rt.
    const compiler_rt_path: ?[]const u8 = blk: {
        if (comp.compiler_rt_lib) |x| break :blk x.full_object_path;
        if (comp.compiler_rt_obj) |x| break :blk x.full_object_path;
        break :blk null;
    };
    if (compiler_rt_path) |path| {
        self.parsePositional(path, false) catch |err| switch (err) {
            error.MalformedObject,
            error.MalformedArchive,
            error.InvalidCpuArch,
            error.InvalidTarget,
            => {}, // already reported
            error.UnknownFileType => try self.reportParseError(path, "unknown file type for a library", .{}),
            else => |e| try self.reportParseError(
                path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    if (comp.link_errors.items.len > 0) return error.FlushFailure;

    for (self.dylibs.items) |index| {
        self.getFile(index).?.dylib.umbrella = index;
    }

    if (self.dylibs.items.len > 0) {
        self.parseDependentDylibs() catch |err| {
            switch (err) {
                error.MissingLibraryDependencies => {},
                else => |e| try self.reportUnexpectedError(
                    "unexpected error while parsing dependent libraries: {s}",
                    .{@errorName(e)},
                ),
            }
            return error.FlushFailure;
        };
    }

    for (self.dylibs.items) |index| {
        const dylib = self.getFile(index).?.dylib;
        if (!dylib.explicit and !dylib.hoisted) continue;
        try dylib.initSymbols(self);
    }

    {
        const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
        self.files.set(index, .{ .internal = .{ .index = index } });
        self.internal_object = index;
        const object = self.getInternalObject().?;
        try object.init(gpa);
        try object.initSymbols(self);
    }

    try self.resolveSymbols();
    try self.convertTentativeDefsAndResolveSpecialSymbols();
    try self.dedupLiterals();

    if (self.base.gc_sections) {
        try dead_strip.gcAtoms(self);
    }

    // TODO
    // self.checkDuplicates() catch |err| switch (err) {
    //     error.HasDuplicates => return error.FlushFailure,
    //     else => |e| {
    //         try self.reportUnexpectedError("unexpected error while checking for duplicate symbol definitions", .{});
    //         return e;
    //     },
    // };

    self.markImportsAndExports();
    self.deadStripDylibs();

    for (self.dylibs.items, 1..) |index, ord| {
        const dylib = self.getFile(index).?.dylib;
        dylib.ordinal = @intCast(ord);
    }

    self.claimUnresolved();

    self.scanRelocs() catch |err| switch (err) {
        error.HasUndefinedSymbols => return error.FlushFailure,
        else => |e| {
            try self.reportUnexpectedError("unexpected error while scanning relocations", .{});
            return e;
        },
    };

    try self.initOutputSections();
    try self.initSyntheticSections();
    try self.sortSections();
    try self.addAtomsToSections();
    try self.calcSectionSizes();

    try self.generateUnwindInfo();

    try self.initSegments();
    try self.allocateSections();
    self.allocateSegments();
    self.allocateSyntheticSymbols();

    if (build_options.enable_logging) {
        state_log.debug("{}", .{self.dumpState()});
    }

    // Beyond this point, everything has been allocated a virtual address and we can resolve
    // the relocations, and commit objects to file.
    try self.resizeSections();

    if (self.getZigObject()) |zo| {
        zo.resolveRelocs(self) catch |err| switch (err) {
            error.ResolveFailed => return error.FlushFailure,
            else => |e| return e,
        };
    }
    self.writeSectionsAndUpdateLinkeditSizes() catch |err| {
        switch (err) {
            error.ResolveFailed => return error.FlushFailure,
            else => |e| return e,
        }
    };

    try self.writeSectionsToFile();
    try self.allocateLinkeditSegment();
    try self.writeLinkeditSectionsToFile();

    var codesig: ?CodeSignature = if (self.requiresCodeSig()) blk: {
        // Preallocate space for the code signature.
        // We need to do this at this stage so that we have the load commands with proper values
        // written out to the file.
        // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
        // where the code signature goes into.
        var codesig = CodeSignature.init(self.getPageSize());
        codesig.code_directory.ident = fs.path.basename(full_out_path);
        if (self.entitlements) |path| try codesig.addEntitlements(gpa, path);
        try self.writeCodeSignaturePadding(&codesig);
        break :blk codesig;
    } else null;
    defer if (codesig) |*csig| csig.deinit(gpa);

    self.getLinkeditSegment().vmsize = mem.alignForward(
        u64,
        self.getLinkeditSegment().filesize,
        self.getPageSize(),
    );

    const ncmds, const sizeofcmds, const uuid_cmd_offset = try self.writeLoadCommands();
    try self.writeHeader(ncmds, sizeofcmds);
    try self.writeUuid(uuid_cmd_offset, self.requiresCodeSig());
    if (self.getDebugSymbols()) |dsym| try dsym.flushModule(self);

    if (codesig) |*csig| {
        try self.writeCodeSignature(csig); // code signing always comes last
        const emit = self.base.emit;
        try invalidateKernelCache(emit.directory.handle, emit.sub_path);
    }
}

/// --verbose-link output
fn dumpArgv(self: *MachO, comp: *Compilation) !void {
    const gpa = self.base.comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const directory = self.base.emit.directory;
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.emit.sub_path});
    const module_obj_path: ?[]const u8 = if (self.base.zcu_object_sub_path) |path| blk: {
        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, path });
        } else {
            break :blk path;
        }
    } else null;

    var argv = std.ArrayList([]const u8).init(arena);

    try argv.append("zig");

    if (self.base.isStaticLib()) {
        try argv.append("ar");
    } else {
        try argv.append("ld");
    }

    if (self.base.isObject()) {
        try argv.append("-r");
    }

    if (self.base.isRelocatable()) {
        for (comp.objects) |obj| {
            try argv.append(obj.path);
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }
    } else {
        if (!self.base.isStatic()) {
            try argv.append("-dynamic");
        }

        if (self.base.isDynLib()) {
            try argv.append("-dylib");

            if (self.install_name) |install_name| {
                try argv.append("-install_name");
                try argv.append(install_name);
            }
        }

        try argv.append("-platform_version");
        try argv.append(@tagName(self.platform.os_tag));
        try argv.append(try std.fmt.allocPrint(arena, "{}", .{self.platform.version}));

        if (self.sdk_version) |ver| {
            try argv.append(try std.fmt.allocPrint(arena, "{d}.{d}", .{ ver.major, ver.minor }));
        } else {
            try argv.append(try std.fmt.allocPrint(arena, "{}", .{self.platform.version}));
        }

        if (comp.sysroot) |syslibroot| {
            try argv.append("-syslibroot");
            try argv.append(syslibroot);
        }

        for (self.base.rpath_list) |rpath| {
            try argv.append("-rpath");
            try argv.append(rpath);
        }

        if (self.pagezero_size) |size| {
            try argv.append("-pagezero_size");
            try argv.append(try std.fmt.allocPrint(arena, "0x{x}", .{size}));
        }

        if (self.headerpad_size) |size| {
            try argv.append("-headerpad_size");
            try argv.append(try std.fmt.allocPrint(arena, "0x{x}", .{size}));
        }

        if (self.headerpad_max_install_names) {
            try argv.append("-headerpad_max_install_names");
        }

        if (self.base.gc_sections) {
            try argv.append("-dead_strip");
        }

        if (self.dead_strip_dylibs) {
            try argv.append("-dead_strip_dylibs");
        }

        if (self.force_load_objc) {
            try argv.append("-ObjC");
        }

        if (self.entry_name) |entry_name| {
            try argv.appendSlice(&.{ "-e", entry_name });
        }

        try argv.append("-o");
        try argv.append(full_out_path);

        if (self.base.isDynLib() and self.base.allow_shlib_undefined) {
            try argv.append("-undefined");
            try argv.append("dynamic_lookup");
        }

        for (comp.objects) |obj| {
            // TODO: verify this
            if (obj.must_link) {
                try argv.append("-force_load");
            }
            try argv.append(obj.path);
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (comp.config.any_sanitize_thread) {
            const path = comp.tsan_lib.?.full_object_path;
            try argv.append(path);
            try argv.appendSlice(&.{ "-rpath", std.fs.path.dirname(path) orelse "." });
        }

        for (self.lib_dirs) |lib_dir| {
            const arg = try std.fmt.allocPrint(arena, "-L{s}", .{lib_dir});
            try argv.append(arg);
        }

        for (comp.system_libs.keys()) |l_name| {
            const info = comp.system_libs.get(l_name).?;
            const arg = if (info.needed)
                try std.fmt.allocPrint(arena, "-needed-l{s}", .{l_name})
            else if (info.weak)
                try std.fmt.allocPrint(arena, "-weak-l{s}", .{l_name})
            else
                try std.fmt.allocPrint(arena, "-l{s}", .{l_name});
            try argv.append(arg);
        }

        for (self.framework_dirs) |f_dir| {
            try argv.append("-F");
            try argv.append(f_dir);
        }

        for (self.frameworks) |framework| {
            const name = fs.path.stem(framework.path);
            const arg = if (framework.needed)
                try std.fmt.allocPrint(arena, "-needed_framework {s}", .{name})
            else if (framework.weak)
                try std.fmt.allocPrint(arena, "-weak_framework {s}", .{name})
            else
                try std.fmt.allocPrint(arena, "-framework {s}", .{name});
            try argv.append(arg);
        }

        if (comp.config.link_libcpp) {
            try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
            try argv.append(comp.libcxx_static_lib.?.full_object_path);
        }

        try argv.append("-lSystem");

        if (comp.compiler_rt_lib) |lib| try argv.append(lib.full_object_path);
        if (comp.compiler_rt_obj) |obj| try argv.append(obj.full_object_path);
    }

    Compilation.dump_argv(argv.items);
}

pub fn resolveLibSystem(
    self: *MachO,
    arena: Allocator,
    comp: *Compilation,
    out_libs: anytype,
) !void {
    var test_path = std.ArrayList(u8).init(arena);
    var checked_paths = std.ArrayList([]const u8).init(arena);

    success: {
        if (self.sdk_layout) |sdk_layout| switch (sdk_layout) {
            .sdk => {
                const dir = try fs.path.join(arena, &[_][]const u8{ comp.sysroot.?, "usr", "lib" });
                if (try accessLibPath(arena, &test_path, &checked_paths, dir, "System")) break :success;
            },
            .vendored => {
                const dir = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "darwin" });
                if (try accessLibPath(arena, &test_path, &checked_paths, dir, "System")) break :success;
            },
        };

        for (self.lib_dirs) |dir| {
            if (try accessLibPath(arena, &test_path, &checked_paths, dir, "System")) break :success;
        }

        try self.reportMissingLibraryError(checked_paths.items, "unable to find libSystem system library", .{});
        return error.MissingLibSystem;
    }

    const libsystem_path = try arena.dupe(u8, test_path.items);
    try out_libs.append(.{
        .needed = true,
        .path = libsystem_path,
    });
}

pub const ParseError = error{
    MalformedObject,
    MalformedArchive,
    MalformedDylib,
    MalformedTbd,
    NotLibStub,
    InvalidCpuArch,
    InvalidTarget,
    InvalidTargetFatLibrary,
    IncompatibleDylibVersion,
    OutOfMemory,
    Overflow,
    InputOutput,
    EndOfStream,
    FileSystem,
    NotSupported,
    Unhandled,
    UnknownFileType,
} || fs.File.SeekError || fs.File.OpenError || fs.File.ReadError || tapi.TapiError;

pub fn parsePositional(self: *MachO, path: []const u8, must_link: bool) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();
    if (try Object.isObject(path)) {
        try self.parseObject(path);
    } else {
        try self.parseLibrary(.{ .path = path }, must_link);
    }
}

fn parseLibrary(self: *MachO, lib: SystemLib, must_link: bool) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();
    if (try fat.isFatLibrary(lib.path)) {
        const fat_arch = try self.parseFatLibrary(lib.path);
        if (try Archive.isArchive(lib.path, fat_arch)) {
            try self.parseArchive(lib, must_link, fat_arch);
        } else if (try Dylib.isDylib(lib.path, fat_arch)) {
            _ = try self.parseDylib(lib, true, fat_arch);
        } else return error.UnknownFileType;
    } else if (try Archive.isArchive(lib.path, null)) {
        try self.parseArchive(lib, must_link, null);
    } else if (try Dylib.isDylib(lib.path, null)) {
        _ = try self.parseDylib(lib, true, null);
    } else {
        _ = self.parseTbd(lib, true) catch |err| switch (err) {
            error.MalformedTbd => return error.UnknownFileType,
            else => |e| return e,
        };
    }
}

fn parseObject(self: *MachO, path: []const u8) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const file = try fs.cwd().openFile(path, .{});
    const handle = try self.addFileHandle(file);
    const mtime: u64 = mtime: {
        const stat = file.stat() catch break :mtime 0;
        break :mtime @as(u64, @intCast(@divFloor(stat.mtime, 1_000_000_000)));
    };
    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{
        .object = .{
            .offset = 0, // TODO FAT objects
            .path = try gpa.dupe(u8, path),
            .file_handle = handle,
            .mtime = mtime,
            .index = index,
        },
    });
    try self.objects.append(gpa, index);

    const object = self.getFile(index).?.object;
    try object.parse(self);
}

pub fn parseFatLibrary(self: *MachO, path: []const u8) !fat.Arch {
    var buffer: [2]fat.Arch = undefined;
    const fat_archs = try fat.parseArchs(path, &buffer);
    const cpu_arch = self.getTarget().cpu.arch;
    for (fat_archs) |arch| {
        if (arch.tag == cpu_arch) return arch;
    }
    try self.reportParseError(path, "missing arch in universal file: expected {s}", .{@tagName(cpu_arch)});
    return error.InvalidCpuArch;
}

fn parseArchive(self: *MachO, lib: SystemLib, must_link: bool, fat_arch: ?fat.Arch) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    const file = try fs.cwd().openFile(lib.path, .{});
    const handle = try self.addFileHandle(file);

    var archive = Archive{};
    defer archive.deinit(gpa);
    try archive.parse(self, lib.path, handle, fat_arch);

    var has_parse_error = false;
    for (archive.objects.items) |extracted| {
        const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
        self.files.set(index, .{ .object = extracted });
        const object = &self.files.items(.data)[index].object;
        object.index = index;
        object.alive = must_link or lib.needed; // TODO: or self.options.all_load;
        object.hidden = lib.hidden;
        object.parse(self) catch |err| switch (err) {
            error.MalformedObject,
            error.InvalidCpuArch,
            error.InvalidTarget,
            => has_parse_error = true,
            else => |e| return e,
        };
        try self.objects.append(gpa, index);

        // Finally, we do a post-parse check for -ObjC to see if we need to force load this member
        // anyhow.
        object.alive = object.alive or (self.force_load_objc and object.hasObjc());
    }
    if (has_parse_error) return error.MalformedArchive;
}

fn parseDylib(self: *MachO, lib: SystemLib, explicit: bool, fat_arch: ?fat.Arch) ParseError!File.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    const file = try fs.cwd().openFile(lib.path, .{});
    defer file.close();

    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .dylib = .{
        .path = try gpa.dupe(u8, lib.path),
        .index = index,
        .needed = lib.needed,
        .weak = lib.weak,
        .reexport = lib.reexport,
        .explicit = explicit,
    } });
    const dylib = &self.files.items(.data)[index].dylib;
    try dylib.parse(self, file, fat_arch);

    try self.dylibs.append(gpa, index);

    return index;
}

fn parseTbd(self: *MachO, lib: SystemLib, explicit: bool) ParseError!File.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const file = try fs.cwd().openFile(lib.path, .{});
    defer file.close();

    var lib_stub = LibStub.loadFromFile(gpa, file) catch return error.MalformedTbd; // TODO actually handle different errors
    defer lib_stub.deinit();

    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .dylib = .{
        .path = try gpa.dupe(u8, lib.path),
        .index = index,
        .needed = lib.needed,
        .weak = lib.weak,
        .reexport = lib.reexport,
        .explicit = explicit,
    } });
    const dylib = &self.files.items(.data)[index].dylib;
    try dylib.parseTbd(self.getTarget().cpu.arch, self.platform, lib_stub, self);
    try self.dylibs.append(gpa, index);

    return index;
}

/// According to ld64's manual, public (i.e., system) dylibs/frameworks are hoisted into the final
/// image unless overriden by -no_implicit_dylibs.
fn isHoisted(self: *MachO, install_name: []const u8) bool {
    if (self.no_implicit_dylibs) return true;
    if (fs.path.dirname(install_name)) |dirname| {
        if (mem.startsWith(u8, dirname, "/usr/lib")) return true;
        if (eatPrefix(dirname, "/System/Library/Frameworks/")) |path| {
            const basename = fs.path.basename(install_name);
            if (mem.indexOfScalar(u8, path, '.')) |index| {
                if (mem.eql(u8, basename, path[0..index])) return true;
            }
        }
    }
    return false;
}

fn accessLibPath(
    arena: Allocator,
    test_path: *std.ArrayList(u8),
    checked_paths: *std.ArrayList([]const u8),
    search_dir: []const u8,
    name: []const u8,
) !bool {
    const sep = fs.path.sep_str;

    for (&[_][]const u8{ ".tbd", ".dylib", "" }) |ext| {
        test_path.clearRetainingCapacity();
        try test_path.writer().print("{s}" ++ sep ++ "lib{s}{s}", .{ search_dir, name, ext });
        try checked_paths.append(try arena.dupe(u8, test_path.items));
        fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        return true;
    }

    return false;
}

fn accessFrameworkPath(
    arena: Allocator,
    test_path: *std.ArrayList(u8),
    checked_paths: *std.ArrayList([]const u8),
    search_dir: []const u8,
    name: []const u8,
) !bool {
    const sep = fs.path.sep_str;

    for (&[_][]const u8{ ".tbd", ".dylib", "" }) |ext| {
        test_path.clearRetainingCapacity();
        try test_path.writer().print("{s}" ++ sep ++ "{s}.framework" ++ sep ++ "{s}{s}", .{
            search_dir,
            name,
            name,
            ext,
        });
        try checked_paths.append(try arena.dupe(u8, test_path.items));
        fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        return true;
    }

    return false;
}

fn parseDependentDylibs(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const lib_dirs = self.lib_dirs;
    const framework_dirs = self.framework_dirs;

    var arena_alloc = std.heap.ArenaAllocator.init(gpa);
    defer arena_alloc.deinit();
    const arena = arena_alloc.allocator();

    // TODO handle duplicate dylibs - it is not uncommon to have the same dylib loaded multiple times
    // in which case we should track that and return File.Index immediately instead re-parsing paths.

    var has_errors = false;
    var index: usize = 0;
    while (index < self.dylibs.items.len) : (index += 1) {
        const dylib_index = self.dylibs.items[index];

        var dependents = std.ArrayList(struct { id: Dylib.Id, file: File.Index }).init(gpa);
        defer dependents.deinit();
        try dependents.ensureTotalCapacityPrecise(self.getFile(dylib_index).?.dylib.dependents.items.len);

        const is_weak = self.getFile(dylib_index).?.dylib.weak;
        for (self.getFile(dylib_index).?.dylib.dependents.items) |id| {
            // We will search for the dependent dylibs in the following order:
            // 1. Basename is in search lib directories or framework directories
            // 2. If name is an absolute path, search as-is optionally prepending a syslibroot
            //    if specified.
            // 3. If name is a relative path, substitute @rpath, @loader_path, @executable_path with
            //    dependees list of rpaths, and search there.
            // 4. Finally, just search the provided relative path directly in CWD.
            var test_path = std.ArrayList(u8).init(arena);
            var checked_paths = std.ArrayList([]const u8).init(arena);

            const full_path = full_path: {
                {
                    const stem = fs.path.stem(id.name);

                    // Framework
                    for (framework_dirs) |dir| {
                        test_path.clearRetainingCapacity();
                        if (try accessFrameworkPath(arena, &test_path, &checked_paths, dir, stem)) break :full_path test_path.items;
                    }

                    // Library
                    const lib_name = eatPrefix(stem, "lib") orelse stem;
                    for (lib_dirs) |dir| {
                        test_path.clearRetainingCapacity();
                        if (try accessLibPath(arena, &test_path, &checked_paths, dir, lib_name)) break :full_path test_path.items;
                    }
                }

                if (fs.path.isAbsolute(id.name)) {
                    const existing_ext = fs.path.extension(id.name);
                    const path = if (existing_ext.len > 0) id.name[0 .. id.name.len - existing_ext.len] else id.name;
                    for (&[_][]const u8{ ".tbd", ".dylib", "" }) |ext| {
                        test_path.clearRetainingCapacity();
                        if (self.base.comp.sysroot) |root| {
                            try test_path.writer().print("{s}" ++ fs.path.sep_str ++ "{s}{s}", .{ root, path, ext });
                        } else {
                            try test_path.writer().print("{s}{s}", .{ path, ext });
                        }
                        try checked_paths.append(try arena.dupe(u8, test_path.items));
                        fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
                            error.FileNotFound => continue,
                            else => |e| return e,
                        };
                        break :full_path test_path.items;
                    }
                }

                if (eatPrefix(id.name, "@rpath/")) |path| {
                    const dylib = self.getFile(dylib_index).?.dylib;
                    for (self.getFile(dylib.umbrella).?.dylib.rpaths.keys()) |rpath| {
                        const prefix = eatPrefix(rpath, "@loader_path/") orelse rpath;
                        const rel_path = try fs.path.join(arena, &.{ prefix, path });
                        try checked_paths.append(rel_path);
                        var buffer: [fs.max_path_bytes]u8 = undefined;
                        const full_path = fs.realpath(rel_path, &buffer) catch continue;
                        break :full_path try arena.dupe(u8, full_path);
                    }
                } else if (eatPrefix(id.name, "@loader_path/")) |_| {
                    try self.reportParseError2(dylib_index, "TODO handle install_name '{s}'", .{id.name});
                    return error.Unhandled;
                } else if (eatPrefix(id.name, "@executable_path/")) |_| {
                    try self.reportParseError2(dylib_index, "TODO handle install_name '{s}'", .{id.name});
                    return error.Unhandled;
                }

                try checked_paths.append(try arena.dupe(u8, id.name));
                var buffer: [fs.max_path_bytes]u8 = undefined;
                if (fs.realpath(id.name, &buffer)) |full_path| {
                    break :full_path try arena.dupe(u8, full_path);
                } else |_| {
                    try self.reportMissingDependencyError(
                        self.getFile(dylib_index).?.dylib.getUmbrella(self).index,
                        id.name,
                        checked_paths.items,
                        "unable to resolve dependency",
                        .{},
                    );
                    has_errors = true;
                    continue;
                }
            };
            const lib = SystemLib{
                .path = full_path,
                .weak = is_weak,
            };
            const file_index = file_index: {
                if (try fat.isFatLibrary(lib.path)) {
                    const fat_arch = try self.parseFatLibrary(lib.path);
                    if (try Dylib.isDylib(lib.path, fat_arch)) {
                        break :file_index try self.parseDylib(lib, false, fat_arch);
                    } else break :file_index @as(File.Index, 0);
                } else if (try Dylib.isDylib(lib.path, null)) {
                    break :file_index try self.parseDylib(lib, false, null);
                } else {
                    const file_index = self.parseTbd(lib, false) catch |err| switch (err) {
                        error.MalformedTbd => @as(File.Index, 0),
                        else => |e| return e,
                    };
                    break :file_index file_index;
                }
            };
            dependents.appendAssumeCapacity(.{ .id = id, .file = file_index });
        }

        const dylib = self.getFile(dylib_index).?.dylib;
        for (dependents.items) |entry| {
            const id = entry.id;
            const file_index = entry.file;
            if (self.getFile(file_index)) |file| {
                const dep_dylib = file.dylib;
                dep_dylib.hoisted = self.isHoisted(id.name);
                if (self.getFile(dep_dylib.umbrella) == null) {
                    dep_dylib.umbrella = dylib.umbrella;
                }
                if (!dep_dylib.hoisted) {
                    const umbrella = dep_dylib.getUmbrella(self);
                    for (dep_dylib.exports.items(.name), dep_dylib.exports.items(.flags)) |off, flags| {
                        try umbrella.addExport(gpa, dep_dylib.getString(off), flags);
                    }
                    try umbrella.rpaths.ensureUnusedCapacity(gpa, dep_dylib.rpaths.keys().len);
                    for (dep_dylib.rpaths.keys()) |rpath| {
                        umbrella.rpaths.putAssumeCapacity(try gpa.dupe(u8, rpath), {});
                    }
                }
            } else {
                try self.reportDependencyError(
                    dylib.getUmbrella(self).index,
                    id.name,
                    "unable to resolve dependency",
                    .{},
                );
                has_errors = true;
            }
        }
    }

    if (has_errors) return error.MissingLibraryDependencies;
}

/// When resolving symbols, we approach the problem similarly to `mold`.
/// 1. Resolve symbols across all objects (including those preemptively extracted archives).
/// 2. Resolve symbols across all shared objects.
/// 3. Mark live objects (see `MachO.markLive`)
/// 4. Reset state of all resolved globals since we will redo this bit on the pruned set.
/// 5. Remove references to dead objects/shared objects
/// 6. Re-run symbol resolution on pruned objects and shared objects sets.
pub fn resolveSymbols(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    // Resolve symbols in the ZigObject. For now, we assume that it's always live.
    if (self.getZigObject()) |zo| try zo.asFile().resolveSymbols(self);
    // Resolve symbols on the set of all objects and shared objects (even if some are unneeded).
    for (self.objects.items) |index| try self.getFile(index).?.resolveSymbols(self);
    for (self.dylibs.items) |index| try self.getFile(index).?.resolveSymbols(self);
    if (self.getInternalObject()) |obj| try obj.resolveSymbols(self);

    // Mark live objects.
    self.markLive();

    // Reset state of all globals after marking live objects.
    self.resolver.reset();

    // Prune dead objects.
    var i: usize = 0;
    while (i < self.objects.items.len) {
        const index = self.objects.items[i];
        if (!self.getFile(index).?.object.alive) {
            _ = self.objects.orderedRemove(i);
            self.files.items(.data)[index].object.deinit(self.base.comp.gpa);
            self.files.set(index, .null);
        } else i += 1;
    }

    // Re-resolve the symbols.
    if (self.getZigObject()) |zo| try zo.resolveSymbols(self);
    for (self.objects.items) |index| try self.getFile(index).?.resolveSymbols(self);
    for (self.dylibs.items) |index| try self.getFile(index).?.resolveSymbols(self);
    if (self.getInternalObject()) |obj| try obj.resolveSymbols(self);

    // Merge symbol visibility
    if (self.getZigObject()) |zo| zo.mergeSymbolVisibility(self);
    for (self.objects.items) |index| self.getFile(index).?.object.mergeSymbolVisibility(self);
}

fn markLive(self: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.getZigObject()) |zo| zo.markLive(self);
    for (self.objects.items) |index| {
        const object = self.getFile(index).?.object;
        if (object.alive) object.markLive(self);
    }
    if (self.getInternalObject()) |obj| obj.markLive(self);
}

fn resolveSyntheticSymbols(self: *MachO) !void {
    const internal = self.getInternalObject() orelse return;

    if (!self.base.isDynLib()) {
        self.mh_execute_header_index = try internal.addSymbol("__mh_execute_header", self);
        const sym = self.getSymbol(self.mh_execute_header_index.?);
        sym.flags.@"export" = true;
        sym.flags.dyn_ref = true;
        sym.visibility = .global;
    } else {
        self.mh_dylib_header_index = try internal.addSymbol("__mh_dylib_header", self);
    }

    self.dso_handle_index = try internal.addSymbol("___dso_handle", self);
    self.dyld_private_index = try internal.addSymbol("dyld_private", self);

    {
        const gpa = self.base.comp.gpa;
        var boundary_symbols = std.AutoHashMap(Symbol.Index, void).init(gpa);
        defer boundary_symbols.deinit();

        for (self.objects.items) |index| {
            const object = self.getFile(index).?.object;
            for (object.symbols.items, 0..) |sym_index, i| {
                const nlist = object.symtab.items(.nlist)[i];
                const name = self.getSymbol(sym_index).getName(self);
                if (!nlist.undf() or !nlist.ext()) continue;
                if (mem.startsWith(u8, name, "segment$start$") or
                    mem.startsWith(u8, name, "segment$stop$") or
                    mem.startsWith(u8, name, "section$start$") or
                    mem.startsWith(u8, name, "section$stop$"))
                {
                    _ = try boundary_symbols.put(sym_index, {});
                }
            }
        }

        try self.boundary_symbols.ensureTotalCapacityPrecise(gpa, boundary_symbols.count());

        var it = boundary_symbols.iterator();
        while (it.next()) |entry| {
            _ = try internal.addSymbol(self.getSymbol(entry.key_ptr.*).getName(self), self);
            self.boundary_symbols.appendAssumeCapacity(entry.key_ptr.*);
        }
    }
}

fn convertTentativeDefsAndResolveSpecialSymbols(self: *MachO) !void {
    for (self.objects.items) |index| {
        try self.getFile(index).?.object.convertTentativeDefinitions(self);
    }
    if (self.getInternalObject()) |obj| {
        try obj.resolveBoundarySymbols(self);
        try obj.resolveObjcMsgSendSymbols(self);
    }
}

fn createObjcSections(self: *MachO) !void {
    const gpa = self.base.comp.gpa;
    var objc_msgsend_syms = std.AutoArrayHashMap(Symbol.Index, void).init(gpa);
    defer objc_msgsend_syms.deinit();

    for (self.objects.items) |index| {
        const object = self.getFile(index).?.object;

        for (object.symbols.items, 0..) |sym_index, i| {
            const nlist_idx = @as(Symbol.Index, @intCast(i));
            const nlist = object.symtab.items(.nlist)[nlist_idx];
            if (!nlist.ext()) continue;
            if (!nlist.undf()) continue;

            const sym = self.getSymbol(sym_index);
            if (sym.getFile(self) != null) continue;
            if (mem.startsWith(u8, sym.getName(self), "_objc_msgSend$")) {
                _ = try objc_msgsend_syms.put(sym_index, {});
            }
        }
    }

    for (objc_msgsend_syms.keys()) |sym_index| {
        const internal = self.getInternalObject().?;
        const sym = self.getSymbol(sym_index);
        _ = try internal.addSymbol(sym.getName(self), self);
        sym.visibility = .hidden;
        const name = eatPrefix(sym.getName(self), "_objc_msgSend$").?;
        const selrefs_index = try internal.addObjcMsgsendSections(name, self);
        try sym.addExtra(.{ .objc_selrefs = selrefs_index }, self);
        sym.flags.objc_stubs = true;
    }
}

pub fn dedupLiterals(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    var lp: LiteralPool = .{};
    defer lp.deinit(gpa);

    if (self.getZigObject()) |zo| {
        try zo.resolveLiterals(&lp, self);
    }
    for (self.objects.items) |index| {
        try self.getFile(index).?.object.resolveLiterals(&lp, self);
    }
    if (self.getInternalObject()) |object| {
        try object.resolveLiterals(&lp, self);
    }

    if (self.getZigObject()) |zo| {
        zo.dedupLiterals(lp, self);
    }
    for (self.objects.items) |index| {
        self.getFile(index).?.object.dedupLiterals(lp, self);
    }
    if (self.getInternalObject()) |object| {
        object.dedupLiterals(lp, self);
    }
}

fn claimUnresolved(self: *MachO) void {
    if (self.getZigObject()) |zo| {
        zo.asFile().claimUnresolved(self);
    }
    for (self.objects.items) |index| {
        self.getFile(index).?.claimUnresolved(self);
    }
}

fn checkDuplicates(self: *MachO) !void {
    const gpa = self.base.comp.gpa;

    var dupes = std.AutoArrayHashMap(Symbol.Index, std.ArrayListUnmanaged(File.Index)).init(gpa);
    defer {
        for (dupes.values()) |*list| {
            list.deinit(gpa);
        }
        dupes.deinit();
    }

    if (self.getZigObject()) |zo| {
        try zo.checkDuplicates(&dupes, self);
    }

    for (self.objects.items) |index| {
        try self.getFile(index).?.object.checkDuplicates(&dupes, self);
    }

    try self.reportDuplicates(dupes);
}

fn markImportsAndExports(self: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.getZigObject()) |zo| {
        zo.asFile().markImportsExports(self);
    }
    for (self.objects.items) |index| {
        self.getFile(index).?.markImportsExports(self);
    }
    if (self.getInternalObject()) |obj| {
        obj.asFile().markImportsExports(self);
    }
}

fn deadStripDylibs(self: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.dylibs.items) |index| {
        self.getFile(index).?.dylib.markReferenced(self);
    }

    var i: usize = 0;
    while (i < self.dylibs.items.len) {
        const index = self.dylibs.items[i];
        if (!self.getFile(index).?.dylib.isAlive(self)) {
            _ = self.dylibs.orderedRemove(i);
            self.files.items(.data)[index].dylib.deinit(self.base.comp.gpa);
            self.files.set(index, .null);
        } else i += 1;
    }
}

fn scanRelocs(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.getZigObject()) |zo| {
        try zo.scanRelocs(self);
    }
    for (self.objects.items) |index| {
        try self.getFile(index).?.object.scanRelocs(self);
    }
    if (self.getInternalObject()) |obj| {
        obj.scanRelocs(self);
    }

    try self.reportUndefs();

    if (self.getZigObject()) |zo| {
        try zo.asFile().createSymbolIndirection(self);
    }
    for (self.objects.items) |index| {
        try self.getFile(index).?.createSymbolIndirection(self);
    }
    for (self.dylibs.items) |index| {
        try self.getFile(index).?.createSymbolIndirection(self);
    }
    if (self.getInternalObject()) |obj| {
        try obj.asFile().createSymbolIndirection(self);
    }
}

fn reportUndefs(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.undefined_treatment == .suppress or
        self.undefined_treatment == .dynamic_lookup) return;

    const max_notes = 4;

    var has_undefs = false;
    var it = self.undefs.iterator();
    while (it.next()) |entry| {
        const undef_sym = self.resolver.keys.items[entry.key_ptr.* - 1];
        const notes = entry.value_ptr.*;
        const nnotes = @min(notes.items.len, max_notes) + @intFromBool(notes.items.len > max_notes);

        var err = try self.addErrorWithNotes(nnotes);
        try err.addMsg(self, "undefined symbol: {s}", .{undef_sym.getName(self)});
        has_undefs = true;

        var inote: usize = 0;
        while (inote < @min(notes.items.len, max_notes)) : (inote += 1) {
            const note = notes.items[inote];
            const file = self.getFile(note.file).?;
            const atom = note.getAtom(self).?;
            try err.addNote(self, "referenced by {}:{s}", .{ file.fmtPath(), atom.getName(self) });
        }

        if (notes.items.len > max_notes) {
            const remaining = notes.items.len - max_notes;
            try err.addNote(self, "referenced {d} more times", .{remaining});
        }
    }
    if (has_undefs) return error.HasUndefinedSymbols;
}

fn initOutputSections(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.objects.items) |index| {
        try self.getFile(index).?.initOutputSections(self);
    }
    if (self.getInternalObject()) |obj| {
        try obj.asFile().initOutputSections(self);
    }
    self.text_sect_index = self.getSectionByName("__TEXT", "__text") orelse
        try self.addSection("__TEXT", "__text", .{
        .alignment = switch (self.getTarget().cpu.arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable,
        },
        .flags = macho.S_REGULAR |
            macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
    });
    self.data_sect_index = self.getSectionByName("__DATA", "__data") orelse
        try self.addSection("__DATA", "__data", .{});
}

fn initSyntheticSections(self: *MachO) !void {
    const cpu_arch = self.getTarget().cpu.arch;

    if (self.got.symbols.items.len > 0) {
        self.got_sect_index = try self.addSection("__DATA_CONST", "__got", .{
            .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
            .reserved1 = @intCast(self.stubs.symbols.items.len),
        });
    }

    if (self.stubs.symbols.items.len > 0) {
        self.stubs_sect_index = try self.addSection("__TEXT", "__stubs", .{
            .flags = macho.S_SYMBOL_STUBS |
                macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved1 = 0,
            .reserved2 = switch (cpu_arch) {
                .x86_64 => 6,
                .aarch64 => 3 * @sizeOf(u32),
                else => 0,
            },
        });
        self.stubs_helper_sect_index = try self.addSection("__TEXT", "__stub_helper", .{
            .flags = macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        });
        self.la_symbol_ptr_sect_index = try self.addSection("__DATA", "__la_symbol_ptr", .{
            .flags = macho.S_LAZY_SYMBOL_POINTERS,
            .reserved1 = @intCast(self.stubs.symbols.items.len + self.got.symbols.items.len),
        });
    }

    if (self.objc_stubs.symbols.items.len > 0) {
        self.objc_stubs_sect_index = try self.addSection("__TEXT", "__objc_stubs", .{
            .flags = macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        });
    }

    if (self.tlv_ptr.symbols.items.len > 0) {
        self.tlv_ptr_sect_index = try self.addSection("__DATA", "__thread_ptrs", .{
            .flags = macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
        });
    }

    const needs_unwind_info = for (self.objects.items) |index| {
        if (self.getFile(index).?.object.hasUnwindRecords()) break true;
    } else false;
    if (needs_unwind_info) {
        self.unwind_info_sect_index = try self.addSection("__TEXT", "__unwind_info", .{});
    }

    const needs_eh_frame = for (self.objects.items) |index| {
        if (self.getFile(index).?.object.hasEhFrameRecords()) break true;
    } else false;
    if (needs_eh_frame) {
        assert(needs_unwind_info);
        self.eh_frame_sect_index = try self.addSection("__TEXT", "__eh_frame", .{});
    }

    if (self.getInternalObject()) |obj| {
        const gpa = self.base.comp.gpa;

        for (obj.boundary_symbols.items) |sym_index| {
            const ref = obj.getSymbolRef(sym_index, self);
            const sym = ref.getSymbol(self).?;
            const name = sym.getName(self);

            if (eatPrefix(name, "segment$start$")) |segname| {
                if (self.getSegmentByName(segname) == null) { // TODO check segname is valid
                    const prot = getSegmentProt(segname);
                    _ = try self.segments.append(gpa, .{
                        .cmdsize = @sizeOf(macho.segment_command_64),
                        .segname = makeStaticString(segname),
                        .initprot = prot,
                        .maxprot = prot,
                    });
                }
            } else if (eatPrefix(name, "segment$stop$")) |segname| {
                if (self.getSegmentByName(segname) == null) { // TODO check segname is valid
                    const prot = getSegmentProt(segname);
                    _ = try self.segments.append(gpa, .{
                        .cmdsize = @sizeOf(macho.segment_command_64),
                        .segname = makeStaticString(segname),
                        .initprot = prot,
                        .maxprot = prot,
                    });
                }
            } else if (eatPrefix(name, "section$start$")) |actual_name| {
                const sep = mem.indexOfScalar(u8, actual_name, '$').?; // TODO error rather than a panic
                const segname = actual_name[0..sep]; // TODO check segname is valid
                const sectname = actual_name[sep + 1 ..]; // TODO check sectname is valid
                if (self.getSectionByName(segname, sectname) == null) {
                    _ = try self.addSection(segname, sectname, .{});
                }
            } else if (eatPrefix(name, "section$stop$")) |actual_name| {
                const sep = mem.indexOfScalar(u8, actual_name, '$').?; // TODO error rather than a panic
                const segname = actual_name[0..sep]; // TODO check segname is valid
                const sectname = actual_name[sep + 1 ..]; // TODO check sectname is valid
                if (self.getSectionByName(segname, sectname) == null) {
                    _ = try self.addSection(segname, sectname, .{});
                }
            } else unreachable;
        }
    }
}

fn getSegmentProt(segname: []const u8) macho.vm_prot_t {
    if (mem.eql(u8, segname, "__PAGEZERO")) return macho.PROT.NONE;
    if (mem.eql(u8, segname, "__TEXT")) return macho.PROT.READ | macho.PROT.EXEC;
    if (mem.eql(u8, segname, "__LINKEDIT")) return macho.PROT.READ;
    return macho.PROT.READ | macho.PROT.WRITE;
}

fn getSegmentRank(segname: []const u8) u8 {
    if (mem.eql(u8, segname, "__PAGEZERO")) return 0x0;
    if (mem.eql(u8, segname, "__LINKEDIT")) return 0xf;
    if (mem.indexOf(u8, segname, "ZIG")) |_| return 0xe;
    if (mem.startsWith(u8, segname, "__TEXT")) return 0x1;
    if (mem.startsWith(u8, segname, "__DATA_CONST")) return 0x2;
    if (mem.startsWith(u8, segname, "__DATA")) return 0x3;
    return 0x4;
}

fn segmentLessThan(ctx: void, lhs: []const u8, rhs: []const u8) bool {
    _ = ctx;
    const lhs_rank = getSegmentRank(lhs);
    const rhs_rank = getSegmentRank(rhs);
    if (lhs_rank == rhs_rank) {
        return mem.order(u8, lhs, rhs) == .lt;
    }
    return lhs_rank < rhs_rank;
}

fn getSectionRank(section: macho.section_64) u8 {
    if (section.isCode()) {
        if (mem.eql(u8, "__text", section.sectName())) return 0x0;
        if (section.type() == macho.S_SYMBOL_STUBS) return 0x1;
        return 0x2;
    }
    switch (section.type()) {
        macho.S_NON_LAZY_SYMBOL_POINTERS,
        macho.S_LAZY_SYMBOL_POINTERS,
        => return 0x0,

        macho.S_MOD_INIT_FUNC_POINTERS => return 0x1,
        macho.S_MOD_TERM_FUNC_POINTERS => return 0x2,
        macho.S_ZEROFILL => return 0xf,
        macho.S_THREAD_LOCAL_REGULAR => return 0xd,
        macho.S_THREAD_LOCAL_ZEROFILL => return 0xe,

        else => {
            if (mem.eql(u8, "__unwind_info", section.sectName())) return 0xe;
            if (mem.eql(u8, "__compact_unwind", section.sectName())) return 0xe;
            if (mem.eql(u8, "__eh_frame", section.sectName())) return 0xf;
            return 0x3;
        },
    }
}

fn sectionLessThan(ctx: void, lhs: macho.section_64, rhs: macho.section_64) bool {
    if (mem.eql(u8, lhs.segName(), rhs.segName())) {
        const lhs_rank = getSectionRank(lhs);
        const rhs_rank = getSectionRank(rhs);
        if (lhs_rank == rhs_rank) {
            return mem.order(u8, lhs.sectName(), rhs.sectName()) == .lt;
        }
        return lhs_rank < rhs_rank;
    }
    return segmentLessThan(ctx, lhs.segName(), rhs.segName());
}

pub fn sortSections(self: *MachO) !void {
    const Entry = struct {
        index: u8,

        pub fn lessThan(macho_file: *MachO, lhs: @This(), rhs: @This()) bool {
            return sectionLessThan(
                {},
                macho_file.sections.items(.header)[lhs.index],
                macho_file.sections.items(.header)[rhs.index],
            );
        }
    };

    const gpa = self.base.comp.gpa;

    var entries = try std.ArrayList(Entry).initCapacity(gpa, self.sections.slice().len);
    defer entries.deinit();
    for (0..self.sections.slice().len) |index| {
        entries.appendAssumeCapacity(.{ .index = @intCast(index) });
    }

    mem.sort(Entry, entries.items, self, Entry.lessThan);

    const backlinks = try gpa.alloc(u8, entries.items.len);
    defer gpa.free(backlinks);
    for (entries.items, 0..) |entry, i| {
        backlinks[entry.index] = @intCast(i);
    }

    var slice = self.sections.toOwnedSlice();
    defer slice.deinit(gpa);

    try self.sections.ensureTotalCapacity(gpa, slice.len);
    for (entries.items) |sorted| {
        self.sections.appendAssumeCapacity(slice.get(sorted.index));
    }

    if (self.getZigObject()) |zo| {
        for (zo.getAtoms()) |atom_index| {
            const atom = zo.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            atom.out_n_sect = backlinks[atom.out_n_sect];
        }
    }

    for (self.objects.items) |index| {
        const file = self.getFile(index).?;
        for (file.getAtoms()) |atom_index| {
            const atom = file.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            atom.out_n_sect = backlinks[atom.out_n_sect];
        }
    }

    if (self.getInternalObject()) |object| {
        for (object.getAtoms()) |atom_index| {
            const atom = object.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            atom.out_n_sect = backlinks[atom.out_n_sect];
        }
    }

    for (&[_]*?u8{
        &self.data_sect_index,
        &self.got_sect_index,
        &self.zig_text_sect_index,
        &self.zig_got_sect_index,
        &self.zig_const_sect_index,
        &self.zig_data_sect_index,
        &self.zig_bss_sect_index,
        &self.stubs_sect_index,
        &self.stubs_helper_sect_index,
        &self.la_symbol_ptr_sect_index,
        &self.tlv_ptr_sect_index,
        &self.eh_frame_sect_index,
        &self.unwind_info_sect_index,
        &self.objc_stubs_sect_index,
        &self.debug_info_sect_index,
        &self.debug_str_sect_index,
        &self.debug_line_sect_index,
        &self.debug_abbrev_sect_index,
        &self.debug_info_sect_index,
    }) |maybe_index| {
        if (maybe_index.*) |*index| {
            index.* = backlinks[index.*];
        }
    }
}

pub fn addAtomsToSections(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    if (self.getZigObject()) |zo| {
        for (zo.getAtoms()) |atom_index| {
            const atom = zo.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            if (self.isZigSection(atom.out_n_sect)) continue;
            const atoms = &self.sections.items(.atoms)[atom.out_n_sect];
            try atoms.append(gpa, .{ .index = atom_index, .file = zo.index });
        }
    }
    for (self.objects.items) |index| {
        const file = self.getFile(index).?;
        for (file.getAtoms()) |atom_index| {
            const atom = file.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            const atoms = &self.sections.items(.atoms)[atom.out_n_sect];
            try atoms.append(gpa, .{ .index = atom_index, .file = index });
        }
    }
    if (self.getInternalObject()) |object| {
        for (object.getAtoms()) |atom_index| {
            const atom = object.getAtom(atom_index) orelse continue;
            if (!atom.flags.alive) continue;
            const atoms = &self.sections.items(.atoms)[atom.out_n_sect];
            try atoms.append(gpa, .{ .index = atom_index, .file = object.index });
        }
    }
}

fn calcSectionSizes(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const cpu_arch = self.getTarget().cpu.arch;

    if (self.data_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size += @sizeOf(u64);
        header.@"align" = 3;
    }

    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.atoms)) |*header, atoms| {
        if (atoms.items.len == 0) continue;
        if (self.requiresThunks() and header.isCode()) continue;

        for (atoms.items) |ref| {
            const atom = ref.getAtom(self).?;
            const atom_alignment = atom.alignment.toByteUnits() orelse 1;
            const offset = mem.alignForward(u64, header.size, atom_alignment);
            const padding = offset - header.size;
            atom.value = offset;
            header.size += padding + atom.size;
            header.@"align" = @max(header.@"align", atom.alignment.toLog2Units());
        }
    }

    if (self.requiresThunks()) {
        for (slice.items(.header), slice.items(.atoms), 0..) |header, atoms, i| {
            if (!header.isCode()) continue;
            if (atoms.items.len == 0) continue;

            // Create jump/branch range extenders if needed.
            try thunks.createThunks(@intCast(i), self);
        }
    }

    // At this point, we can also calculate symtab and data-in-code linkedit section sizes
    if (self.getZigObject()) |zo| {
        zo.asFile().calcSymtabSize(self);
    }
    for (self.objects.items) |index| {
        self.getFile(index).?.calcSymtabSize(self);
    }
    for (self.dylibs.items) |index| {
        self.getFile(index).?.calcSymtabSize(self);
    }
    if (self.getInternalObject()) |obj| {
        obj.asFile().calcSymtabSize(self);
    }

    try self.calcSymtabSize();

    if (self.got_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size = self.got.size();
        header.@"align" = 3;
    }

    if (self.stubs_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size = self.stubs.size(self);
        header.@"align" = switch (cpu_arch) {
            .x86_64 => 1,
            .aarch64 => 2,
            else => 0,
        };
    }

    if (self.stubs_helper_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size = self.stubs_helper.size(self);
        header.@"align" = 2;
    }

    if (self.la_symbol_ptr_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size = self.la_symbol_ptr.size(self);
        header.@"align" = 3;
    }

    if (self.tlv_ptr_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size = self.tlv_ptr.size();
        header.@"align" = 3;
    }

    if (self.objc_stubs_sect_index) |idx| {
        const header = &self.sections.items(.header)[idx];
        header.size = self.objc_stubs.size(self);
        header.@"align" = switch (cpu_arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => 0,
        };
    }
}

fn generateUnwindInfo(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.eh_frame_sect_index) |index| {
        const sect = &self.sections.items(.header)[index];
        sect.size = try eh_frame.calcSize(self);
        sect.@"align" = 3;
    }
    if (self.unwind_info_sect_index) |index| {
        const sect = &self.sections.items(.header)[index];
        self.unwind_info.generate(self) catch |err| switch (err) {
            error.TooManyPersonalities => return self.reportUnexpectedError(
                "too many personalities in unwind info",
                .{},
            ),
            else => |e| return e,
        };
        sect.size = self.unwind_info.calcSize();
        sect.@"align" = 2;
    }
}

fn initSegments(self: *MachO) !void {
    const gpa = self.base.comp.gpa;
    const slice = self.sections.slice();

    // Add __PAGEZERO if required
    const pagezero_size = self.pagezero_size orelse default_pagezero_size;
    const aligned_pagezero_size = mem.alignBackward(u64, pagezero_size, self.getPageSize());
    if (!self.base.isDynLib() and aligned_pagezero_size > 0) {
        if (aligned_pagezero_size != pagezero_size) {
            // TODO convert into a warning
            log.warn("requested __PAGEZERO size (0x{x}) is not page aligned", .{pagezero_size});
            log.warn("  rounding down to 0x{x}", .{aligned_pagezero_size});
        }
        self.pagezero_seg_index = try self.addSegment("__PAGEZERO", .{ .vmsize = aligned_pagezero_size });
    }

    // __TEXT segment is non-optional
    self.text_seg_index = try self.addSegment("__TEXT", .{ .prot = getSegmentProt("__TEXT") });

    // Next, create segments required by sections
    for (slice.items(.header)) |header| {
        const segname = header.segName();
        if (self.getSegmentByName(segname) == null) {
            _ = try self.addSegment(segname, .{ .prot = getSegmentProt(segname) });
        }
    }

    // Add __LINKEDIT
    self.linkedit_seg_index = try self.addSegment("__LINKEDIT", .{ .prot = getSegmentProt("__LINKEDIT") });

    // Sort segments
    const Entry = struct {
        index: u8,

        pub fn lessThan(macho_file: *MachO, lhs: @This(), rhs: @This()) bool {
            return segmentLessThan(
                {},
                macho_file.segments.items[lhs.index].segName(),
                macho_file.segments.items[rhs.index].segName(),
            );
        }
    };

    var entries = try std.ArrayList(Entry).initCapacity(gpa, self.segments.items.len);
    defer entries.deinit();
    for (0..self.segments.items.len) |index| {
        entries.appendAssumeCapacity(.{ .index = @intCast(index) });
    }

    mem.sort(Entry, entries.items, self, Entry.lessThan);

    const backlinks = try gpa.alloc(u8, entries.items.len);
    defer gpa.free(backlinks);
    for (entries.items, 0..) |entry, i| {
        backlinks[entry.index] = @intCast(i);
    }

    const segments = try self.segments.toOwnedSlice(gpa);
    defer gpa.free(segments);

    try self.segments.ensureTotalCapacityPrecise(gpa, segments.len);
    for (entries.items) |sorted| {
        self.segments.appendAssumeCapacity(segments[sorted.index]);
    }

    for (&[_]*?u8{
        &self.pagezero_seg_index,
        &self.text_seg_index,
        &self.linkedit_seg_index,
        &self.zig_text_seg_index,
        &self.zig_got_seg_index,
        &self.zig_const_seg_index,
        &self.zig_data_seg_index,
        &self.zig_bss_seg_index,
    }) |maybe_index| {
        if (maybe_index.*) |*index| {
            index.* = backlinks[index.*];
        }
    }

    // Attach sections to segments
    for (slice.items(.header), slice.items(.segment_id)) |header, *seg_id| {
        const segname = header.segName();
        const segment_id = self.getSegmentByName(segname) orelse blk: {
            const segment_id = @as(u8, @intCast(self.segments.items.len));
            const protection = getSegmentProt(segname);
            try self.segments.append(gpa, .{
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString(segname),
                .maxprot = protection,
                .initprot = protection,
            });
            break :blk segment_id;
        };
        const segment = &self.segments.items[segment_id];
        segment.cmdsize += @sizeOf(macho.section_64);
        segment.nsects += 1;
        seg_id.* = segment_id;
    }

    // Set __DATA_CONST as READ_ONLY
    if (self.getSegmentByName("__DATA_CONST")) |seg_id| {
        const seg = &self.segments.items[seg_id];
        seg.flags |= macho.SG_READ_ONLY;
    }
}

fn allocateSections(self: *MachO) !void {
    const headerpad = try load_commands.calcMinHeaderPadSize(self);
    var vmaddr: u64 = if (self.pagezero_seg_index) |index|
        self.segments.items[index].vmaddr + self.segments.items[index].vmsize
    else
        0;
    vmaddr += headerpad;
    var fileoff = headerpad;
    var prev_seg_id: u8 = if (self.pagezero_seg_index) |index| index + 1 else 0;

    const page_size = self.getPageSize();
    const slice = self.sections.slice();
    const last_index = for (0..slice.items(.header).len) |i| {
        if (self.isZigSection(@intCast(i))) break i;
    } else slice.items(.header).len;

    for (slice.items(.header)[0..last_index], slice.items(.segment_id)[0..last_index]) |*header, curr_seg_id| {
        if (prev_seg_id != curr_seg_id) {
            vmaddr = mem.alignForward(u64, vmaddr, page_size);
            fileoff = mem.alignForward(u32, fileoff, page_size);
        }

        const alignment = try math.powi(u32, 2, header.@"align");

        vmaddr = mem.alignForward(u64, vmaddr, alignment);
        header.addr = vmaddr;
        vmaddr += header.size;

        if (!header.isZerofill()) {
            fileoff = mem.alignForward(u32, fileoff, alignment);
            header.offset = fileoff;
            fileoff += @intCast(header.size);
        }

        prev_seg_id = curr_seg_id;
    }

    fileoff = mem.alignForward(u32, fileoff, page_size);
    for (slice.items(.header)[last_index..], slice.items(.segment_id)[last_index..]) |*header, seg_id| {
        if (header.isZerofill()) continue;
        if (header.offset < fileoff) {
            const existing_size = header.size;
            header.size = 0;

            // Must move the entire section.
            const new_offset = self.findFreeSpace(existing_size, page_size);

            log.debug("moving '{s},{s}' from 0x{x} to 0x{x}", .{
                header.segName(),
                header.sectName(),
                header.offset,
                new_offset,
            });

            try self.copyRangeAllZeroOut(header.offset, new_offset, existing_size);

            header.offset = @intCast(new_offset);
            header.size = existing_size;
            self.segments.items[seg_id].fileoff = new_offset;
        }
    }
}

/// We allocate segments in a separate step to also consider segments that have no sections.
fn allocateSegments(self: *MachO) void {
    const first_index = if (self.pagezero_seg_index) |index| index + 1 else 0;
    const last_index = for (0..self.segments.items.len) |i| {
        if (self.isZigSegment(@intCast(i))) break i;
    } else self.segments.items.len;

    var vmaddr: u64 = if (self.pagezero_seg_index) |index|
        self.segments.items[index].vmaddr + self.segments.items[index].vmsize
    else
        0;
    var fileoff: u64 = 0;

    const page_size = self.getPageSize();
    const slice = self.sections.slice();

    var next_sect_id: u8 = 0;
    for (self.segments.items[first_index..last_index], first_index..last_index) |*seg, seg_id| {
        seg.vmaddr = vmaddr;
        seg.fileoff = fileoff;

        while (next_sect_id < slice.items(.header).len) : (next_sect_id += 1) {
            const header = slice.items(.header)[next_sect_id];
            const sid = slice.items(.segment_id)[next_sect_id];

            if (seg_id != sid) break;

            vmaddr = header.addr + header.size;
            if (!header.isZerofill()) {
                fileoff = header.offset + header.size;
            }
        }

        seg.vmsize = vmaddr - seg.vmaddr;
        seg.filesize = fileoff - seg.fileoff;

        vmaddr = mem.alignForward(u64, vmaddr, page_size);
        fileoff = mem.alignForward(u64, fileoff, page_size);
    }
}

fn allocateSyntheticSymbols(self: *MachO) void {
    if (self.getInternalObject()) |obj| {
        obj.allocateSyntheticSymbols(self);

        const text_seg = self.getTextSegment();

        for (obj.boundary_symbols.items) |sym_index| {
            const ref = obj.getSymbolRef(sym_index, self);
            const sym = ref.getSymbol(self).?;
            const name = sym.getName(self);

            sym.value = text_seg.vmaddr;

            if (mem.startsWith(u8, name, "segment$start$")) {
                const segname = name["segment$start$".len..];
                if (self.getSegmentByName(segname)) |seg_id| {
                    const seg = self.segments.items[seg_id];
                    sym.value = seg.vmaddr;
                }
            } else if (mem.startsWith(u8, name, "segment$stop$")) {
                const segname = name["segment$stop$".len..];
                if (self.getSegmentByName(segname)) |seg_id| {
                    const seg = self.segments.items[seg_id];
                    sym.value = seg.vmaddr + seg.vmsize;
                }
            } else if (mem.startsWith(u8, name, "section$start$")) {
                const actual_name = name["section$start$".len..];
                const sep = mem.indexOfScalar(u8, actual_name, '$').?; // TODO error rather than a panic
                const segname = actual_name[0..sep];
                const sectname = actual_name[sep + 1 ..];
                if (self.getSectionByName(segname, sectname)) |sect_id| {
                    const sect = self.sections.items(.header)[sect_id];
                    sym.value = sect.addr;
                    sym.out_n_sect = sect_id;
                }
            } else if (mem.startsWith(u8, name, "section$stop$")) {
                const actual_name = name["section$stop$".len..];
                const sep = mem.indexOfScalar(u8, actual_name, '$').?; // TODO error rather than a panic
                const segname = actual_name[0..sep];
                const sectname = actual_name[sep + 1 ..];
                if (self.getSectionByName(segname, sectname)) |sect_id| {
                    const sect = self.sections.items(.header)[sect_id];
                    sym.value = sect.addr + sect.size;
                    sym.out_n_sect = sect_id;
                }
            } else unreachable;
        }

        if (self.objc_stubs.symbols.items.len > 0) {
            const addr = self.sections.items(.header)[self.objc_stubs_sect_index.?].addr;

            for (self.objc_stubs.symbols.items, 0..) |ref, idx| {
                const sym = ref.getSymbol(self).?;
                sym.value = addr + idx * ObjcStubsSection.entrySize(self.getTarget().cpu.arch);
                sym.out_n_sect = self.objc_stubs_sect_index.?;
            }
        }
    }
}

fn allocateLinkeditSegment(self: *MachO) !void {
    var fileoff: u64 = 0;
    var vmaddr: u64 = 0;

    for (self.segments.items) |seg| {
        if (fileoff < seg.fileoff + seg.filesize) fileoff = seg.fileoff + seg.filesize;
        if (vmaddr < seg.vmaddr + seg.vmsize) vmaddr = seg.vmaddr + seg.vmsize;
    }

    const page_size = self.getPageSize();
    const seg = self.getLinkeditSegment();
    seg.vmaddr = mem.alignForward(u64, vmaddr, page_size);
    seg.fileoff = mem.alignForward(u64, fileoff, page_size);

    var off = math.cast(u32, seg.fileoff) orelse return error.Overflow;
    // DYLD_INFO_ONLY
    {
        const cmd = &self.dyld_info_cmd;
        cmd.rebase_off = off;
        off += cmd.rebase_size;
        cmd.bind_off = off;
        off += cmd.bind_size;
        cmd.weak_bind_off = off;
        off += cmd.weak_bind_size;
        cmd.lazy_bind_off = off;
        off += cmd.lazy_bind_size;
        cmd.export_off = off;
        off += cmd.export_size;
        off = mem.alignForward(u32, off, @alignOf(u64));
    }

    // FUNCTION_STARTS
    {
        const cmd = &self.function_starts_cmd;
        cmd.dataoff = off;
        off += cmd.datasize;
        off = mem.alignForward(u32, off, @alignOf(u64));
    }

    // DATA_IN_CODE
    {
        const cmd = &self.data_in_code_cmd;
        cmd.dataoff = off;
        off += cmd.datasize;
        off = mem.alignForward(u32, off, @alignOf(u64));
    }

    // SYMTAB (symtab)
    {
        const cmd = &self.symtab_cmd;
        cmd.symoff = off;
        off += cmd.nsyms * @sizeOf(macho.nlist_64);
        off = mem.alignForward(u32, off, @alignOf(u32));
    }

    // DYSYMTAB
    {
        const cmd = &self.dysymtab_cmd;
        cmd.indirectsymoff = off;
        off += cmd.nindirectsyms * @sizeOf(u32);
        off = mem.alignForward(u32, off, @alignOf(u64));
    }

    // SYMTAB (strtab)
    {
        const cmd = &self.symtab_cmd;
        cmd.stroff = off;
        off += cmd.strsize;
    }

    seg.filesize = off - seg.fileoff;
}

fn resizeSections(self: *MachO) !void {
    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.out), 0..) |header, *out, n_sect| {
        if (header.isZerofill()) continue;
        if (self.isZigSection(@intCast(n_sect))) continue; // TODO this is horrible
        const cpu_arch = self.getTarget().cpu.arch;
        const size = math.cast(usize, header.size) orelse return error.Overflow;
        try out.resize(self.base.comp.gpa, size);
        const padding_byte: u8 = if (header.isCode() and cpu_arch == .x86_64) 0xcc else 0;
        @memset(out.items, padding_byte);
    }
}

fn writeSectionsAndUpdateLinkeditSizes(self: *MachO) !void {
    const gpa = self.base.comp.gpa;

    const cmd = self.symtab_cmd;
    try self.symtab.resize(gpa, cmd.nsyms);
    try self.strtab.resize(gpa, cmd.strsize);
    self.strtab.items[0] = 0;

    for (self.objects.items) |index| {
        try self.getFile(index).?.writeAtoms(self);
    }
    if (self.getZigObject()) |zo| {
        try zo.writeAtoms(self);
    }
    if (self.getInternalObject()) |obj| {
        try obj.asFile().writeAtoms(self);
    }
    for (self.thunks.items) |thunk| {
        const out = self.sections.items(.out)[thunk.out_n_sect].items;
        const off = math.cast(usize, thunk.value) orelse return error.Overflow;
        const size = thunk.size();
        var stream = std.io.fixedBufferStream(out[off..][0..size]);
        try thunk.write(self, stream.writer());
    }

    const slice = self.sections.slice();
    for (&[_]?u8{
        self.eh_frame_sect_index,
        self.unwind_info_sect_index,
        self.got_sect_index,
        self.stubs_sect_index,
        self.la_symbol_ptr_sect_index,
        self.tlv_ptr_sect_index,
        self.objc_stubs_sect_index,
    }) |maybe_sect_id| {
        if (maybe_sect_id) |sect_id| {
            const out = slice.items(.out)[sect_id].items;
            try self.writeSyntheticSection(sect_id, out);
        }
    }

    if (self.la_symbol_ptr_sect_index) |_| {
        try self.updateLazyBindSize();
    }

    try self.rebase.updateSize(self);
    try self.bind.updateSize(self);
    try self.weak_bind.updateSize(self);
    try self.export_trie.updateSize(self);
    try self.data_in_code.updateSize(self);

    if (self.getZigObject()) |zo| {
        zo.asFile().writeSymtab(self, self);
    }
    for (self.objects.items) |index| {
        self.getFile(index).?.writeSymtab(self, self);
    }
    for (self.dylibs.items) |index| {
        self.getFile(index).?.writeSymtab(self, self);
    }
    if (self.getInternalObject()) |obj| {
        obj.asFile().writeSymtab(self, self);
    }
}

fn writeSyntheticSection(self: *MachO, sect_id: u8, out: []u8) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const Tag = enum {
        eh_frame,
        unwind_info,
        got,
        stubs,
        la_symbol_ptr,
        tlv_ptr,
        objc_stubs,
    };

    const tag: Tag = tag: {
        if (self.eh_frame_sect_index != null and
            self.eh_frame_sect_index.? == sect_id) break :tag .eh_frame;
        if (self.unwind_info_sect_index != null and
            self.unwind_info_sect_index.? == sect_id) break :tag .unwind_info;
        if (self.got_sect_index != null and
            self.got_sect_index.? == sect_id) break :tag .got;
        if (self.stubs_sect_index != null and
            self.stubs_sect_index.? == sect_id) break :tag .stubs;
        if (self.la_symbol_ptr_sect_index != null and
            self.la_symbol_ptr_sect_index.? == sect_id) break :tag .la_symbol_ptr;
        if (self.tlv_ptr_sect_index != null and
            self.tlv_ptr_sect_index.? == sect_id) break :tag .tlv_ptr;
        if (self.objc_stubs_sect_index != null and
            self.objc_stubs_sect_index.? == sect_id) break :tag .objc_stubs;
        unreachable;
    };
    var stream = std.io.fixedBufferStream(out);
    switch (tag) {
        .eh_frame => eh_frame.write(self, out),
        .unwind_info => try self.unwind_info.write(self, out),
        .got => try self.got.write(self, stream.writer()),
        .stubs => try self.stubs.write(self, stream.writer()),
        .la_symbol_ptr => try self.la_symbol_ptr.write(self, stream.writer()),
        .tlv_ptr => try self.tlv_ptr.write(self, stream.writer()),
        .objc_stubs => try self.objc_stubs.write(self, stream.writer()),
    }
}

fn updateLazyBindSize(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    try self.lazy_bind.updateSize(self);
    const sect_id = self.stubs_helper_sect_index.?;
    const out = &self.sections.items(.out)[sect_id];
    var stream = std.io.fixedBufferStream(out.items);
    try self.stubs_helper.write(self, stream.writer());
}

fn writeSectionsToFile(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.out)) |header, out| {
        try self.base.file.?.pwriteAll(out.items, header.offset);
    }
}

fn writeLinkeditSectionsToFile(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    try self.writeDyldInfo();
    try self.writeDataInCode();
    try self.writeSymtabToFile();
    try self.writeIndsymtab();
}

fn writeDyldInfo(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const base_off = self.getLinkeditSegment().fileoff;
    const cmd = self.dyld_info_cmd;
    var needed_size: u32 = 0;
    needed_size += cmd.rebase_size;
    needed_size += cmd.bind_size;
    needed_size += cmd.weak_bind_size;
    needed_size += cmd.lazy_bind_size;
    needed_size += cmd.export_size;

    const buffer = try gpa.alloc(u8, needed_size);
    defer gpa.free(buffer);
    @memset(buffer, 0);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try self.rebase.write(writer);
    try stream.seekTo(cmd.bind_off - base_off);
    try self.bind.write(writer);
    try stream.seekTo(cmd.weak_bind_off - base_off);
    try self.weak_bind.write(writer);
    try stream.seekTo(cmd.lazy_bind_off - base_off);
    try self.lazy_bind.write(writer);
    try stream.seekTo(cmd.export_off - base_off);
    try self.export_trie.write(writer);
    try self.base.file.?.pwriteAll(buffer, cmd.rebase_off);
}

pub fn writeDataInCode(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const cmd = self.data_in_code_cmd;
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.data_in_code.entries.items), cmd.dataoff);
}

fn writeIndsymtab(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = self.base.comp.gpa;
    const cmd = self.dysymtab_cmd;
    const needed_size = cmd.nindirectsyms * @sizeOf(u32);
    var buffer = try std.ArrayList(u8).initCapacity(gpa, needed_size);
    defer buffer.deinit();
    try self.indsymtab.write(self, buffer.writer());
    try self.base.file.?.pwriteAll(buffer.items, cmd.indirectsymoff);
}

pub fn writeSymtabToFile(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const cmd = self.symtab_cmd;
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.symtab.items), cmd.symoff);
    try self.base.file.?.pwriteAll(self.strtab.items, cmd.stroff);
}

fn writeUnwindInfo(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    if (self.eh_frame_sect_index) |index| {
        const header = self.sections.items(.header)[index];
        const size = math.cast(usize, header.size) orelse return error.Overflow;
        const buffer = try gpa.alloc(u8, size);
        defer gpa.free(buffer);
        eh_frame.write(self, buffer);
        try self.base.file.?.pwriteAll(buffer, header.offset);
    }

    if (self.unwind_info_sect_index) |index| {
        const header = self.sections.items(.header)[index];
        const size = math.cast(usize, header.size) orelse return error.Overflow;
        const buffer = try gpa.alloc(u8, size);
        defer gpa.free(buffer);
        try self.unwind_info.write(self, buffer);
        try self.base.file.?.pwriteAll(buffer, header.offset);
    }
}

fn calcSymtabSize(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    var files = std.ArrayList(File.Index).init(gpa);
    defer files.deinit();
    try files.ensureTotalCapacityPrecise(self.objects.items.len + self.dylibs.items.len + 2);
    if (self.zig_object) |index| files.appendAssumeCapacity(index);
    for (self.objects.items) |index| files.appendAssumeCapacity(index);
    for (self.dylibs.items) |index| files.appendAssumeCapacity(index);
    if (self.internal_object) |index| files.appendAssumeCapacity(index);

    var nlocals: u32 = 0;
    var nstabs: u32 = 0;
    var nexports: u32 = 0;
    var nimports: u32 = 0;
    var strsize: u32 = 1;

    for (files.items) |index| {
        const file = self.getFile(index).?;
        const ctx = switch (file) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.ilocal = nlocals;
        ctx.istab = nstabs;
        ctx.iexport = nexports;
        ctx.iimport = nimports;
        ctx.stroff = strsize;
        nlocals += ctx.nlocals;
        nstabs += ctx.nstabs;
        nexports += ctx.nexports;
        nimports += ctx.nimports;
        strsize += ctx.strsize;
    }

    for (files.items) |index| {
        const file = self.getFile(index).?;
        const ctx = switch (file) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.istab += nlocals;
        ctx.iexport += nlocals + nstabs;
        ctx.iimport += nlocals + nstabs + nexports;
    }

    try self.indsymtab.updateSize(self);

    {
        const cmd = &self.symtab_cmd;
        cmd.nsyms = nlocals + nstabs + nexports + nimports;
        cmd.strsize = strsize;
    }

    {
        const cmd = &self.dysymtab_cmd;
        cmd.ilocalsym = 0;
        cmd.nlocalsym = nlocals + nstabs;
        cmd.iextdefsym = nlocals + nstabs;
        cmd.nextdefsym = nexports;
        cmd.iundefsym = nlocals + nstabs + nexports;
        cmd.nundefsym = nimports;
    }
}

fn writeLoadCommands(self: *MachO) !struct { usize, usize, u64 } {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    const needed_size = try load_commands.calcLoadCommandsSize(self, false);
    const buffer = try gpa.alloc(u8, needed_size);
    defer gpa.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    var ncmds: usize = 0;

    // Segment and section load commands
    {
        const slice = self.sections.slice();
        var sect_id: usize = 0;
        for (self.segments.items) |seg| {
            try writer.writeStruct(seg);
            for (slice.items(.header)[sect_id..][0..seg.nsects]) |header| {
                try writer.writeStruct(header);
            }
            sect_id += seg.nsects;
        }
        ncmds += self.segments.items.len;
    }

    try writer.writeStruct(self.dyld_info_cmd);
    ncmds += 1;
    try writer.writeStruct(self.function_starts_cmd);
    ncmds += 1;
    try writer.writeStruct(self.data_in_code_cmd);
    ncmds += 1;
    try writer.writeStruct(self.symtab_cmd);
    ncmds += 1;
    try writer.writeStruct(self.dysymtab_cmd);
    ncmds += 1;
    try load_commands.writeDylinkerLC(writer);
    ncmds += 1;

    if (self.getInternalObject()) |obj| {
        if (obj.getEntryRef(self)) |ref| {
            const sym = ref.getSymbol(self).?;
            const seg = self.getTextSegment();
            const entryoff: u32 = if (sym.getFile(self) == null)
                0
            else
                @as(u32, @intCast(sym.getAddress(.{ .stubs = true }, self) - seg.vmaddr));
            try writer.writeStruct(macho.entry_point_command{
                .entryoff = entryoff,
                .stacksize = self.base.stack_size,
            });
            ncmds += 1;
        }
    }

    if (self.base.isDynLib()) {
        try load_commands.writeDylibIdLC(self, writer);
        ncmds += 1;
    }

    for (self.base.rpath_list) |rpath| {
        try load_commands.writeRpathLC(rpath, writer);
        ncmds += 1;
    }
    if (comp.config.any_sanitize_thread) {
        const path = comp.tsan_lib.?.full_object_path;
        const rpath = std.fs.path.dirname(path) orelse ".";
        try load_commands.writeRpathLC(rpath, writer);
        ncmds += 1;
    }

    try writer.writeStruct(macho.source_version_command{ .version = 0 });
    ncmds += 1;

    if (self.platform.isBuildVersionCompatible()) {
        try load_commands.writeBuildVersionLC(self.platform, self.sdk_version, writer);
        ncmds += 1;
    } else {
        try load_commands.writeVersionMinLC(self.platform, self.sdk_version, writer);
        ncmds += 1;
    }

    const uuid_cmd_offset = @sizeOf(macho.mach_header_64) + stream.pos;
    try writer.writeStruct(self.uuid_cmd);
    ncmds += 1;

    for (self.dylibs.items) |index| {
        const dylib = self.getFile(index).?.dylib;
        assert(dylib.isAlive(self));
        const dylib_id = dylib.id.?;
        try load_commands.writeDylibLC(.{
            .cmd = if (dylib.weak)
                .LOAD_WEAK_DYLIB
            else if (dylib.reexport)
                .REEXPORT_DYLIB
            else
                .LOAD_DYLIB,
            .name = dylib_id.name,
            .timestamp = dylib_id.timestamp,
            .current_version = dylib_id.current_version,
            .compatibility_version = dylib_id.compatibility_version,
        }, writer);
        ncmds += 1;
    }

    if (self.requiresCodeSig()) {
        try writer.writeStruct(self.codesig_cmd);
        ncmds += 1;
    }

    assert(stream.pos == needed_size);

    try self.base.file.?.pwriteAll(buffer, @sizeOf(macho.mach_header_64));

    return .{ ncmds, buffer.len, uuid_cmd_offset };
}

fn writeHeader(self: *MachO, ncmds: usize, sizeofcmds: usize) !void {
    var header: macho.mach_header_64 = .{};
    header.flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK;

    // TODO: if (self.options.namespace == .two_level) {
    header.flags |= macho.MH_TWOLEVEL;
    // }

    switch (self.getTarget().cpu.arch) {
        .aarch64 => {
            header.cputype = macho.CPU_TYPE_ARM64;
            header.cpusubtype = macho.CPU_SUBTYPE_ARM_ALL;
        },
        .x86_64 => {
            header.cputype = macho.CPU_TYPE_X86_64;
            header.cpusubtype = macho.CPU_SUBTYPE_X86_64_ALL;
        },
        else => {},
    }

    if (self.base.isDynLib()) {
        header.filetype = macho.MH_DYLIB;
    } else {
        header.filetype = macho.MH_EXECUTE;
        header.flags |= macho.MH_PIE;
    }

    const has_reexports = for (self.dylibs.items) |index| {
        if (self.getFile(index).?.dylib.reexport) break true;
    } else false;
    if (!has_reexports) {
        header.flags |= macho.MH_NO_REEXPORTED_DYLIBS;
    }

    if (self.has_tlv) {
        header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;
    }
    if (self.binds_to_weak) {
        header.flags |= macho.MH_BINDS_TO_WEAK;
    }
    if (self.weak_defines) {
        header.flags |= macho.MH_WEAK_DEFINES;
    }

    header.ncmds = @intCast(ncmds);
    header.sizeofcmds = @intCast(sizeofcmds);

    log.debug("writing Mach-O header {}", .{header});

    try self.base.file.?.pwriteAll(mem.asBytes(&header), 0);
}

fn writeUuid(self: *MachO, uuid_cmd_offset: u64, has_codesig: bool) !void {
    const file_size = if (!has_codesig) blk: {
        const seg = self.getLinkeditSegment();
        break :blk seg.fileoff + seg.filesize;
    } else self.codesig_cmd.dataoff;
    try calcUuid(self.base.comp, self.base.file.?, file_size, &self.uuid_cmd.uuid);
    const offset = uuid_cmd_offset + @sizeOf(macho.load_command);
    try self.base.file.?.pwriteAll(&self.uuid_cmd.uuid, offset);
}

pub fn writeCodeSignaturePadding(self: *MachO, code_sig: *CodeSignature) !void {
    const seg = self.getLinkeditSegment();
    // Code signature data has to be 16-bytes aligned for Apple tools to recognize the file
    // https://github.com/opensource-apple/cctools/blob/fdb4825f303fd5c0751be524babd32958181b3ed/libstuff/checkout.c#L271
    const offset = mem.alignForward(u64, seg.fileoff + seg.filesize, 16);
    const needed_size = code_sig.estimateSize(offset);
    seg.filesize = offset + needed_size - seg.fileoff;
    seg.vmsize = mem.alignForward(u64, seg.filesize, self.getPageSize());
    log.debug("writing code signature padding from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    // Pad out the space. We need to do this to calculate valid hashes for everything in the file
    // except for code signature data.
    try self.base.file.?.pwriteAll(&[_]u8{0}, offset + needed_size - 1);

    self.codesig_cmd.dataoff = @as(u32, @intCast(offset));
    self.codesig_cmd.datasize = @as(u32, @intCast(needed_size));
}

pub fn writeCodeSignature(self: *MachO, code_sig: *CodeSignature) !void {
    const seg = self.getTextSegment();
    const offset = self.codesig_cmd.dataoff;

    var buffer = std.ArrayList(u8).init(self.base.comp.gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(code_sig.size());
    try code_sig.writeAdhocSignature(self, .{
        .file = self.base.file.?,
        .exec_seg_base = seg.fileoff,
        .exec_seg_limit = seg.filesize,
        .file_size = offset,
        .dylib = self.base.isDynLib(),
    }, buffer.writer());
    assert(buffer.items.len == code_sig.size());

    log.debug("writing code signature from 0x{x} to 0x{x}", .{
        offset,
        offset + buffer.items.len,
    });

    try self.base.file.?.pwriteAll(buffer.items, offset);
}

pub fn updateFunc(self: *MachO, pt: Zcu.PerThread, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(pt, func_index, air, liveness);
    return self.getZigObject().?.updateFunc(self, pt, func_index, air, liveness);
}

pub fn lowerUnnamedConst(self: *MachO, pt: Zcu.PerThread, val: Value, decl_index: InternPool.DeclIndex) !u32 {
    return self.getZigObject().?.lowerUnnamedConst(self, pt, val, decl_index);
}

pub fn updateDecl(self: *MachO, pt: Zcu.PerThread, decl_index: InternPool.DeclIndex) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(pt, decl_index);
    return self.getZigObject().?.updateDecl(self, pt, decl_index);
}

pub fn updateDeclLineNumber(self: *MachO, pt: Zcu.PerThread, decl_index: InternPool.DeclIndex) !void {
    if (self.llvm_object) |_| return;
    return self.getZigObject().?.updateDeclLineNumber(pt, decl_index);
}

pub fn updateExports(
    self: *MachO,
    pt: Zcu.PerThread,
    exported: Module.Exported,
    export_indices: []const u32,
) link.File.UpdateExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateExports(pt, exported, export_indices);
    return self.getZigObject().?.updateExports(self, pt, exported, export_indices);
}

pub fn deleteExport(
    self: *MachO,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    if (self.llvm_object) |_| return;
    return self.getZigObject().?.deleteExport(self, exported, name);
}

pub fn freeDecl(self: *MachO, decl_index: InternPool.DeclIndex) void {
    if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    return self.getZigObject().?.freeDecl(decl_index);
}

pub fn getDeclVAddr(self: *MachO, _: Zcu.PerThread, decl_index: InternPool.DeclIndex, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    return self.getZigObject().?.getDeclVAddr(self, decl_index, reloc_info);
}

pub fn lowerAnonDecl(
    self: *MachO,
    pt: Zcu.PerThread,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.LazySrcLoc,
) !codegen.Result {
    return self.getZigObject().?.lowerAnonDecl(self, pt, decl_val, explicit_alignment, src_loc);
}

pub fn getAnonDeclVAddr(self: *MachO, decl_val: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    return self.getZigObject().?.getAnonDeclVAddr(self, decl_val, reloc_info);
}

pub fn getGlobalSymbol(self: *MachO, name: []const u8, lib_name: ?[]const u8) !u32 {
    return self.getZigObject().?.getGlobalSymbol(self, name, lib_name);
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

fn detectAllocCollision(self: *MachO, start: u64, size: u64) ?u64 {
    // Conservatively commit one page size as reserved space for the headers as we
    // expect it to grow and everything else be moved in flush anyhow.
    const header_size = self.getPageSize();
    if (start < header_size)
        return header_size;

    const end = start + padToIdeal(size);

    for (self.sections.items(.header)) |header| {
        if (header.isZerofill()) continue;
        const increased_size = padToIdeal(header.size);
        const test_end = header.offset +| increased_size;
        if (end > header.offset and start < test_end) {
            return test_end;
        }
    }

    for (self.segments.items) |seg| {
        const increased_size = padToIdeal(seg.filesize);
        const test_end = seg.fileoff +| increased_size;
        if (end > seg.fileoff and start < test_end) {
            return test_end;
        }
    }

    return null;
}

fn detectAllocCollisionVirtual(self: *MachO, start: u64, size: u64) ?u64 {
    // Conservatively commit one page size as reserved space for the headers as we
    // expect it to grow and everything else be moved in flush anyhow.
    const header_size = self.getPageSize();
    if (start < header_size)
        return header_size;

    const end = start + padToIdeal(size);

    for (self.sections.items(.header)) |header| {
        const increased_size = padToIdeal(header.size);
        const test_end = header.addr +| increased_size;
        if (end > header.addr and start < test_end) {
            return test_end;
        }
    }

    for (self.segments.items) |seg| {
        const increased_size = padToIdeal(seg.vmsize);
        const test_end = seg.vmaddr +| increased_size;
        if (end > seg.vmaddr and start < test_end) {
            return test_end;
        }
    }

    return null;
}

pub fn allocatedSize(self: *MachO, start: u64) u64 {
    if (start == 0) return 0;

    var min_pos: u64 = std.math.maxInt(u64);

    for (self.sections.items(.header)) |header| {
        if (header.offset <= start) continue;
        if (header.offset < min_pos) min_pos = header.offset;
    }

    for (self.segments.items) |seg| {
        if (seg.fileoff <= start) continue;
        if (seg.fileoff < min_pos) min_pos = seg.fileoff;
    }

    return min_pos - start;
}

pub fn allocatedSizeVirtual(self: *MachO, start: u64) u64 {
    if (start == 0) return 0;

    var min_pos: u64 = std.math.maxInt(u64);

    for (self.sections.items(.header)) |header| {
        if (header.addr <= start) continue;
        if (header.addr < min_pos) min_pos = header.addr;
    }

    for (self.segments.items) |seg| {
        if (seg.vmaddr <= start) continue;
        if (seg.vmaddr < min_pos) min_pos = seg.vmaddr;
    }

    return min_pos - start;
}

pub fn findFreeSpace(self: *MachO, object_size: u64, min_alignment: u32) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForward(u64, item_end, min_alignment);
    }
    return start;
}

pub fn findFreeSpaceVirtual(self: *MachO, object_size: u64, min_alignment: u32) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollisionVirtual(start, object_size)) |item_end| {
        start = mem.alignForward(u64, item_end, min_alignment);
    }
    return start;
}

pub fn copyRangeAll(self: *MachO, old_offset: u64, new_offset: u64, size: u64) !void {
    const file = self.base.file.?;
    const amt = try file.copyRangeAll(old_offset, file, new_offset, size);
    if (amt != size) return error.InputOutput;
}

/// Like File.copyRangeAll but also ensures the source region is zeroed out after copy.
/// This is so that we guarantee zeroed out regions for mapping of zerofill sections by the loader.
fn copyRangeAllZeroOut(self: *MachO, old_offset: u64, new_offset: u64, size: u64) !void {
    const gpa = self.base.comp.gpa;
    try self.copyRangeAll(old_offset, new_offset, size);
    const size_u = math.cast(usize, size) orelse return error.Overflow;
    const zeroes = try gpa.alloc(u8, size_u);
    defer gpa.free(zeroes);
    @memset(zeroes, 0);
    try self.base.file.?.pwriteAll(zeroes, old_offset);
}

const InitMetadataOptions = struct {
    emit: Compilation.Emit,
    zo: *ZigObject,
    symbol_count_hint: u64,
    program_code_size_hint: u64,
};

// TODO: move to ZigObject
fn initMetadata(self: *MachO, options: InitMetadataOptions) !void {
    if (!self.base.isRelocatable()) {
        const base_vmaddr = blk: {
            const pagezero_size = self.pagezero_size orelse default_pagezero_size;
            break :blk mem.alignBackward(u64, pagezero_size, self.getPageSize());
        };

        {
            const filesize = options.program_code_size_hint;
            const off = self.findFreeSpace(filesize, self.getPageSize());
            self.zig_text_seg_index = try self.addSegment("__TEXT_ZIG", .{
                .fileoff = off,
                .filesize = filesize,
                .vmaddr = base_vmaddr + 0x8000000,
                .vmsize = filesize,
                .prot = macho.PROT.READ | macho.PROT.EXEC,
            });
        }

        {
            const filesize = options.symbol_count_hint * @sizeOf(u64);
            const off = self.findFreeSpace(filesize, self.getPageSize());
            self.zig_got_seg_index = try self.addSegment("__GOT_ZIG", .{
                .fileoff = off,
                .filesize = filesize,
                .vmaddr = base_vmaddr + 0x4000000,
                .vmsize = filesize,
                .prot = macho.PROT.READ | macho.PROT.WRITE,
            });
        }

        {
            const filesize: u64 = 1024;
            const off = self.findFreeSpace(filesize, self.getPageSize());
            self.zig_const_seg_index = try self.addSegment("__CONST_ZIG", .{
                .fileoff = off,
                .filesize = filesize,
                .vmaddr = base_vmaddr + 0xc000000,
                .vmsize = filesize,
                .prot = macho.PROT.READ | macho.PROT.WRITE,
            });
        }

        {
            const filesize: u64 = 1024;
            const off = self.findFreeSpace(filesize, self.getPageSize());
            self.zig_data_seg_index = try self.addSegment("__DATA_ZIG", .{
                .fileoff = off,
                .filesize = filesize,
                .vmaddr = base_vmaddr + 0x10000000,
                .vmsize = filesize,
                .prot = macho.PROT.READ | macho.PROT.WRITE,
            });
        }

        {
            const memsize: u64 = 1024;
            self.zig_bss_seg_index = try self.addSegment("__BSS_ZIG", .{
                .vmaddr = base_vmaddr + 0x14000000,
                .vmsize = memsize,
                .prot = macho.PROT.READ | macho.PROT.WRITE,
            });
        }

        if (options.zo.dwarf) |_| {
            // Create dSYM bundle.
            log.debug("creating {s}.dSYM bundle", .{options.emit.sub_path});

            const gpa = self.base.comp.gpa;
            const sep = fs.path.sep_str;
            const d_sym_path = try std.fmt.allocPrint(
                gpa,
                "{s}.dSYM" ++ sep ++ "Contents" ++ sep ++ "Resources" ++ sep ++ "DWARF",
                .{options.emit.sub_path},
            );
            defer gpa.free(d_sym_path);

            var d_sym_bundle = try options.emit.directory.handle.makeOpenPath(d_sym_path, .{});
            defer d_sym_bundle.close();

            const d_sym_file = try d_sym_bundle.createFile(options.emit.sub_path, .{
                .truncate = false,
                .read = true,
            });

            self.d_sym = .{ .allocator = gpa, .file = d_sym_file };
            try self.d_sym.?.initMetadata(self);
        }
    }

    const appendSect = struct {
        fn appendSect(macho_file: *MachO, sect_id: u8, seg_id: u8) void {
            const sect = &macho_file.sections.items(.header)[sect_id];
            const seg = macho_file.segments.items[seg_id];
            sect.addr = seg.vmaddr;
            sect.offset = @intCast(seg.fileoff);
            sect.size = seg.vmsize;
            macho_file.sections.items(.segment_id)[sect_id] = seg_id;
        }
    }.appendSect;

    const allocSect = struct {
        fn allocSect(macho_file: *MachO, sect_id: u8, size: u64) !void {
            const sect = &macho_file.sections.items(.header)[sect_id];
            const alignment = try math.powi(u32, 2, sect.@"align");
            if (!sect.isZerofill()) {
                sect.offset = math.cast(u32, macho_file.findFreeSpace(size, alignment)) orelse
                    return error.Overflow;
            }
            sect.addr = macho_file.findFreeSpaceVirtual(size, alignment);
            sect.size = size;
        }
    }.allocSect;

    {
        self.zig_text_sect_index = try self.addSection("__TEXT_ZIG", "__text_zig", .{
            .alignment = switch (self.getTarget().cpu.arch) {
                .aarch64 => 2,
                .x86_64 => 0,
                else => unreachable,
            },
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        });
        if (self.base.isRelocatable()) {
            try allocSect(self, self.zig_text_sect_index.?, options.program_code_size_hint);
        } else {
            appendSect(self, self.zig_text_sect_index.?, self.zig_text_seg_index.?);
        }
    }

    if (!self.base.isRelocatable()) {
        self.zig_got_sect_index = try self.addSection("__GOT_ZIG", "__got_zig", .{
            .alignment = 3,
        });
        appendSect(self, self.zig_got_sect_index.?, self.zig_got_seg_index.?);
    }

    {
        self.zig_const_sect_index = try self.addSection("__CONST_ZIG", "__const_zig", .{});
        if (self.base.isRelocatable()) {
            try allocSect(self, self.zig_const_sect_index.?, 1024);
        } else {
            appendSect(self, self.zig_const_sect_index.?, self.zig_const_seg_index.?);
        }
    }

    {
        self.zig_data_sect_index = try self.addSection("__DATA_ZIG", "__data_zig", .{});
        if (self.base.isRelocatable()) {
            try allocSect(self, self.zig_data_sect_index.?, 1024);
        } else {
            appendSect(self, self.zig_data_sect_index.?, self.zig_data_seg_index.?);
        }
    }

    {
        self.zig_bss_sect_index = try self.addSection("__BSS_ZIG", "__bss_zig", .{
            .flags = macho.S_ZEROFILL,
        });
        if (self.base.isRelocatable()) {
            try allocSect(self, self.zig_bss_sect_index.?, 1024);
        } else {
            appendSect(self, self.zig_bss_sect_index.?, self.zig_bss_seg_index.?);
        }
    }

    if (self.base.isRelocatable() and options.zo.dwarf != null) {
        {
            self.debug_str_sect_index = try self.addSection("__DWARF", "__debug_str", .{
                .flags = macho.S_ATTR_DEBUG,
            });
            try allocSect(self, self.debug_str_sect_index.?, 200);
        }

        {
            self.debug_info_sect_index = try self.addSection("__DWARF", "__debug_info", .{
                .flags = macho.S_ATTR_DEBUG,
            });
            try allocSect(self, self.debug_info_sect_index.?, 200);
        }

        {
            self.debug_abbrev_sect_index = try self.addSection("__DWARF", "__debug_abbrev", .{
                .flags = macho.S_ATTR_DEBUG,
            });
            try allocSect(self, self.debug_abbrev_sect_index.?, 128);
        }

        {
            self.debug_aranges_sect_index = try self.addSection("__DWARF", "__debug_aranges", .{
                .alignment = 4,
                .flags = macho.S_ATTR_DEBUG,
            });
            try allocSect(self, self.debug_aranges_sect_index.?, 160);
        }

        {
            self.debug_line_sect_index = try self.addSection("__DWARF", "__debug_line", .{
                .flags = macho.S_ATTR_DEBUG,
            });
            try allocSect(self, self.debug_line_sect_index.?, 250);
        }
    }
}

pub fn growSection(self: *MachO, sect_index: u8, needed_size: u64) !void {
    if (self.base.isRelocatable()) {
        try self.growSectionRelocatable(sect_index, needed_size);
    } else {
        try self.growSectionNonRelocatable(sect_index, needed_size);
    }
}

fn growSectionNonRelocatable(self: *MachO, sect_index: u8, needed_size: u64) !void {
    const sect = &self.sections.items(.header)[sect_index];

    if (needed_size > self.allocatedSize(sect.offset) and !sect.isZerofill()) {
        const existing_size = sect.size;
        sect.size = 0;

        // Must move the entire section.
        const alignment = self.getPageSize();
        const new_offset = self.findFreeSpace(needed_size, alignment);

        log.debug("moving '{s},{s}' from 0x{x} to 0x{x}", .{
            sect.segName(),
            sect.sectName(),
            sect.offset,
            new_offset,
        });

        try self.copyRangeAllZeroOut(sect.offset, new_offset, existing_size);

        sect.offset = @intCast(new_offset);
    }

    sect.size = needed_size;

    const seg_id = self.sections.items(.segment_id)[sect_index];
    const seg = &self.segments.items[seg_id];
    seg.fileoff = sect.offset;

    if (!sect.isZerofill()) {
        seg.filesize = needed_size;
    }

    const mem_capacity = self.allocatedSizeVirtual(seg.vmaddr);
    if (needed_size > mem_capacity) {
        var err = try self.addErrorWithNotes(2);
        try err.addMsg(self, "fatal linker error: cannot expand segment seg({d})({s}) in virtual memory", .{
            seg_id,
            seg.segName(),
        });
        try err.addNote(self, "TODO: emit relocations to memory locations in self-hosted backends", .{});
        try err.addNote(self, "as a workaround, try increasing pre-allocated virtual memory of each segment", .{});
    }

    seg.vmsize = needed_size;
}

fn growSectionRelocatable(self: *MachO, sect_index: u8, needed_size: u64) !void {
    const sect = &self.sections.items(.header)[sect_index];

    if (needed_size > self.allocatedSize(sect.offset) and !sect.isZerofill()) {
        const existing_size = sect.size;
        sect.size = 0;

        // Must move the entire section.
        const alignment = try math.powi(u32, 2, sect.@"align");
        const new_offset = self.findFreeSpace(needed_size, alignment);
        const new_addr = self.findFreeSpaceVirtual(needed_size, alignment);

        log.debug("new '{s},{s}' file offset 0x{x} to 0x{x} (0x{x} - 0x{x})", .{
            sect.segName(),
            sect.sectName(),
            new_offset,
            new_offset + existing_size,
            new_addr,
            new_addr + existing_size,
        });

        try self.copyRangeAll(sect.offset, new_offset, existing_size);

        sect.offset = @intCast(new_offset);
        sect.addr = new_addr;
    }

    sect.size = needed_size;
}

pub fn markDirty(self: *MachO, sect_index: u8) void {
    if (self.getZigObject()) |zo| {
        if (self.debug_info_sect_index.? == sect_index) {
            zo.debug_info_header_dirty = true;
        } else if (self.debug_line_sect_index.? == sect_index) {
            zo.debug_line_header_dirty = true;
        } else if (self.debug_abbrev_sect_index.? == sect_index) {
            zo.debug_abbrev_dirty = true;
        } else if (self.debug_str_sect_index.? == sect_index) {
            zo.debug_strtab_dirty = true;
        } else if (self.debug_aranges_sect_index.? == sect_index) {
            zo.debug_aranges_dirty = true;
        }
    }
}

pub fn getTarget(self: MachO) std.Target {
    return self.base.comp.root_mod.resolved_target.result;
}

/// XNU starting with Big Sur running on arm64 is caching inodes of running binaries.
/// Any change to the binary will effectively invalidate the kernel's cache
/// resulting in a SIGKILL on each subsequent run. Since when doing incremental
/// linking we're modifying a binary in-place, this will end up with the kernel
/// killing it on every subsequent run. To circumvent it, we will copy the file
/// into a new inode, remove the original file, and rename the copy to match
/// the original file. This is super messy, but there doesn't seem any other
/// way to please the XNU.
pub fn invalidateKernelCache(dir: fs.Dir, sub_path: []const u8) !void {
    if (comptime builtin.target.isDarwin() and builtin.target.cpu.arch == .aarch64) {
        try dir.copyFile(sub_path, dir, sub_path, .{});
    }
}

inline fn conformUuid(out: *[Md5.digest_length]u8) void {
    // LC_UUID uuids should conform to RFC 4122 UUID version 4 & UUID version 5 formats
    out[6] = (out[6] & 0x0F) | (3 << 4);
    out[8] = (out[8] & 0x3F) | 0x80;
}

pub inline fn getPageSize(self: MachO) u16 {
    return switch (self.getTarget().cpu.arch) {
        .aarch64 => 0x4000,
        .x86_64 => 0x1000,
        else => unreachable,
    };
}

pub fn requiresCodeSig(self: MachO) bool {
    if (self.entitlements) |_| return true;
    // TODO: enable once we support this linker option
    // if (self.options.adhoc_codesign) |cs| return cs;
    const target = self.getTarget();
    return switch (target.cpu.arch) {
        .aarch64 => switch (target.os.tag) {
            .macos => true,
            .watchos, .tvos, .ios, .visionos => target.abi == .simulator,
            else => false,
        },
        .x86_64 => false,
        else => unreachable,
    };
}

inline fn requiresThunks(self: MachO) bool {
    return self.getTarget().cpu.arch == .aarch64;
}

pub fn isZigSegment(self: MachO, seg_id: u8) bool {
    inline for (&[_]?u8{
        self.zig_text_seg_index,
        self.zig_got_seg_index,
        self.zig_const_seg_index,
        self.zig_data_seg_index,
        self.zig_bss_seg_index,
    }) |maybe_index| {
        if (maybe_index) |index| {
            if (index == seg_id) return true;
        }
    }
    return false;
}

pub fn isZigSection(self: MachO, sect_id: u8) bool {
    inline for (&[_]?u8{
        self.zig_text_sect_index,
        self.zig_got_sect_index,
        self.zig_const_sect_index,
        self.zig_data_sect_index,
        self.zig_bss_sect_index,
    }) |maybe_index| {
        if (maybe_index) |index| {
            if (index == sect_id) return true;
        }
    }
    return false;
}

pub fn isDebugSection(self: MachO, sect_id: u8) bool {
    inline for (&[_]?u8{
        self.debug_info_sect_index,
        self.debug_abbrev_sect_index,
        self.debug_str_sect_index,
        self.debug_aranges_sect_index,
        self.debug_line_sect_index,
    }) |maybe_index| {
        if (maybe_index) |index| {
            if (index == sect_id) return true;
        }
    }
    return false;
}

pub fn addSegment(self: *MachO, name: []const u8, opts: struct {
    vmaddr: u64 = 0,
    vmsize: u64 = 0,
    fileoff: u64 = 0,
    filesize: u64 = 0,
    prot: macho.vm_prot_t = macho.PROT.NONE,
}) error{OutOfMemory}!u8 {
    const gpa = self.base.comp.gpa;
    const index = @as(u8, @intCast(self.segments.items.len));
    try self.segments.append(gpa, .{
        .segname = makeStaticString(name),
        .vmaddr = opts.vmaddr,
        .vmsize = opts.vmsize,
        .fileoff = opts.fileoff,
        .filesize = opts.filesize,
        .maxprot = opts.prot,
        .initprot = opts.prot,
        .nsects = 0,
        .cmdsize = @sizeOf(macho.segment_command_64),
    });
    return index;
}

const AddSectionOpts = struct {
    alignment: u32 = 0,
    flags: u32 = macho.S_REGULAR,
    reserved1: u32 = 0,
    reserved2: u32 = 0,
};

pub fn addSection(
    self: *MachO,
    segname: []const u8,
    sectname: []const u8,
    opts: AddSectionOpts,
) !u8 {
    const gpa = self.base.comp.gpa;
    const index = @as(u8, @intCast(try self.sections.addOne(gpa)));
    self.sections.set(index, .{
        .segment_id = 0, // Segments will be created automatically later down the pipeline.
        .header = .{
            .sectname = makeStaticString(sectname),
            .segname = makeStaticString(segname),
            .@"align" = opts.alignment,
            .flags = opts.flags,
            .reserved1 = opts.reserved1,
            .reserved2 = opts.reserved2,
        },
    });
    return index;
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

pub fn getSectionByName(self: MachO, segname: []const u8, sectname: []const u8) ?u8 {
    for (self.sections.items(.header), 0..) |header, i| {
        if (mem.eql(u8, header.segName(), segname) and mem.eql(u8, header.sectName(), sectname))
            return @as(u8, @intCast(i));
    } else return null;
}

pub fn getTlsAddress(self: MachO) u64 {
    for (self.sections.items(.header)) |header| switch (header.type()) {
        macho.S_THREAD_LOCAL_REGULAR,
        macho.S_THREAD_LOCAL_ZEROFILL,
        => return header.addr,
        else => {},
    };
    return 0;
}

pub inline fn getTextSegment(self: *MachO) *macho.segment_command_64 {
    return &self.segments.items[self.text_seg_index.?];
}

pub inline fn getLinkeditSegment(self: *MachO) *macho.segment_command_64 {
    return &self.segments.items[self.linkedit_seg_index.?];
}

pub fn getFile(self: *MachO, index: File.Index) ?File {
    const tag = self.files.items(.tags)[index];
    return switch (tag) {
        .null => null,
        .zig_object => .{ .zig_object = &self.files.items(.data)[index].zig_object },
        .internal => .{ .internal = &self.files.items(.data)[index].internal },
        .object => .{ .object = &self.files.items(.data)[index].object },
        .dylib => .{ .dylib = &self.files.items(.data)[index].dylib },
    };
}

pub fn getZigObject(self: *MachO) ?*ZigObject {
    const index = self.zig_object orelse return null;
    return self.getFile(index).?.zig_object;
}

pub fn getInternalObject(self: *MachO) ?*InternalObject {
    const index = self.internal_object orelse return null;
    return self.getFile(index).?.internal;
}

pub fn addFileHandle(self: *MachO, file: fs.File) !File.HandleIndex {
    const gpa = self.base.comp.gpa;
    const index: File.HandleIndex = @intCast(self.file_handles.items.len);
    const fh = try self.file_handles.addOne(gpa);
    fh.* = file;
    return index;
}

pub fn getFileHandle(self: MachO, index: File.HandleIndex) File.Handle {
    assert(index < self.file_handles.items.len);
    return self.file_handles.items[index];
}

pub fn addThunk(self: *MachO) !Thunk.Index {
    const index = @as(Thunk.Index, @intCast(self.thunks.items.len));
    const thunk = try self.thunks.addOne(self.base.comp.gpa);
    thunk.* = .{};
    return index;
}

pub fn getThunk(self: *MachO, index: Thunk.Index) *Thunk {
    assert(index < self.thunks.items.len);
    return &self.thunks.items[index];
}

pub fn eatPrefix(path: []const u8, prefix: []const u8) ?[]const u8 {
    if (mem.startsWith(u8, path, prefix)) return path[prefix.len..];
    return null;
}

const ErrorWithNotes = struct {
    /// Allocated index in comp.link_errors array.
    index: usize,

    /// Next available note slot.
    note_slot: usize = 0,

    pub fn addMsg(
        err: ErrorWithNotes,
        macho_file: *MachO,
        comptime format: []const u8,
        args: anytype,
    ) error{OutOfMemory}!void {
        const comp = macho_file.base.comp;
        const gpa = comp.gpa;
        const err_msg = &comp.link_errors.items[err.index];
        err_msg.msg = try std.fmt.allocPrint(gpa, format, args);
    }

    pub fn addNote(
        err: *ErrorWithNotes,
        macho_file: *MachO,
        comptime format: []const u8,
        args: anytype,
    ) error{OutOfMemory}!void {
        const comp = macho_file.base.comp;
        const gpa = comp.gpa;
        const err_msg = &comp.link_errors.items[err.index];
        assert(err.note_slot < err_msg.notes.len);
        err_msg.notes[err.note_slot] = .{ .msg = try std.fmt.allocPrint(gpa, format, args) };
        err.note_slot += 1;
    }
};

pub fn addErrorWithNotes(self: *MachO, note_count: usize) error{OutOfMemory}!ErrorWithNotes {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    return self.addErrorWithNotesAssumeCapacity(note_count);
}

fn addErrorWithNotesAssumeCapacity(self: *MachO, note_count: usize) error{OutOfMemory}!ErrorWithNotes {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    const index = comp.link_errors.items.len;
    const err = comp.link_errors.addOneAssumeCapacity();
    err.* = .{ .msg = undefined, .notes = try gpa.alloc(link.File.ErrorMsg, note_count) };
    return .{ .index = index };
}

pub fn reportParseError(
    self: *MachO,
    path: []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(1);
    try err.addMsg(self, format, args);
    try err.addNote(self, "while parsing {s}", .{path});
}

pub fn reportParseError2(
    self: *MachO,
    file_index: File.Index,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(1);
    try err.addMsg(self, format, args);
    try err.addNote(self, "while parsing {}", .{self.getFile(file_index).?.fmtPath()});
}

fn reportMissingLibraryError(
    self: *MachO,
    checked_paths: []const []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(checked_paths.len);
    try err.addMsg(self, format, args);
    for (checked_paths) |path| {
        try err.addNote(self, "tried {s}", .{path});
    }
}

fn reportMissingDependencyError(
    self: *MachO,
    parent: File.Index,
    path: []const u8,
    checked_paths: []const []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(2 + checked_paths.len);
    try err.addMsg(self, format, args);
    try err.addNote(self, "while resolving {s}", .{path});
    try err.addNote(self, "a dependency of {}", .{self.getFile(parent).?.fmtPath()});
    for (checked_paths) |p| {
        try err.addNote(self, "tried {s}", .{p});
    }
}

fn reportDependencyError(
    self: *MachO,
    parent: File.Index,
    path: []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(2);
    try err.addMsg(self, format, args);
    try err.addNote(self, "while parsing {s}", .{path});
    try err.addNote(self, "a dependency of {}", .{self.getFile(parent).?.fmtPath()});
}

pub fn reportUnexpectedError(self: *MachO, comptime format: []const u8, args: anytype) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(1);
    try err.addMsg(self, format, args);
    try err.addNote(self, "please report this as a linker bug on https://github.com/ziglang/zig/issues/new/choose", .{});
}

fn reportDuplicates(self: *MachO, dupes: anytype) error{ HasDuplicates, OutOfMemory }!void {
    const tracy = trace(@src());
    defer tracy.end();

    const max_notes = 3;

    var has_dupes = false;
    var it = dupes.iterator();
    while (it.next()) |entry| {
        const sym = self.getSymbol(entry.key_ptr.*);
        const notes = entry.value_ptr.*;
        const nnotes = @min(notes.items.len, max_notes) + @intFromBool(notes.items.len > max_notes);

        var err = try self.addErrorWithNotes(nnotes + 1);
        try err.addMsg(self, "duplicate symbol definition: {s}", .{sym.getName(self)});
        try err.addNote(self, "defined by {}", .{sym.getFile(self).?.fmtPath()});

        var inote: usize = 0;
        while (inote < @min(notes.items.len, max_notes)) : (inote += 1) {
            const file = self.getFile(notes.items[inote]).?;
            try err.addNote(self, "defined by {}", .{file.fmtPath()});
        }

        if (notes.items.len > max_notes) {
            const remaining = notes.items.len - max_notes;
            try err.addNote(self, "defined {d} more times", .{remaining});
        }

        has_dupes = true;
    }

    if (has_dupes) return error.HasDuplicates;
}

pub fn getDebugSymbols(self: *MachO) ?*DebugSymbols {
    if (self.d_sym) |*ds| return ds;
    return null;
}

pub fn ptraceAttach(self: *MachO, pid: std.posix.pid_t) !void {
    if (!is_hot_update_compatible) return;

    const mach_task = try std.c.machTaskForPid(pid);
    log.debug("Mach task for pid {d}: {any}", .{ pid, mach_task });
    self.hot_state.mach_task = mach_task;

    // TODO start exception handler in another thread

    // TODO enable ones we register for exceptions
    // try std.os.ptrace(std.os.darwin.PT.ATTACHEXC, pid, 0, 0);
}

pub fn ptraceDetach(self: *MachO, pid: std.posix.pid_t) !void {
    if (!is_hot_update_compatible) return;

    _ = pid;

    // TODO stop exception handler

    // TODO see comment in ptraceAttach
    // try std.os.ptrace(std.os.darwin.PT.DETACH, pid, 0, 0);

    self.hot_state.mach_task = null;
}

pub fn dumpState(self: *MachO) std.fmt.Formatter(fmtDumpState) {
    return .{ .data = self };
}

fn fmtDumpState(
    self: *MachO,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    if (self.getZigObject()) |zo| {
        try writer.print("zig_object({d}) : {s}\n", .{ zo.index, zo.path });
        try writer.print("{}{}\n", .{
            zo.fmtAtoms(self),
            zo.fmtSymtab(self),
        });
    }
    for (self.objects.items) |index| {
        const object = self.getFile(index).?.object;
        try writer.print("object({d}) : {} : has_debug({})", .{
            index,
            object.fmtPath(),
            object.hasDebugInfo(),
        });
        if (!object.alive) try writer.writeAll(" : ([*])");
        try writer.writeByte('\n');
        try writer.print("{}{}{}{}{}\n", .{
            object.fmtAtoms(self),
            object.fmtCies(self),
            object.fmtFdes(self),
            object.fmtUnwindRecords(self),
            object.fmtSymtab(self),
        });
    }
    for (self.dylibs.items) |index| {
        const dylib = self.getFile(index).?.dylib;
        try writer.print("dylib({d}) : {s} : needed({}) : weak({})", .{
            index,
            dylib.path,
            dylib.needed,
            dylib.weak,
        });
        if (!dylib.isAlive(self)) try writer.writeAll(" : ([*])");
        try writer.writeByte('\n');
        try writer.print("{}\n", .{dylib.fmtSymtab(self)});
    }
    if (self.getInternalObject()) |internal| {
        try writer.print("internal({d}) : internal\n", .{internal.index});
        try writer.print("{}{}\n", .{ internal.fmtAtoms(self), internal.fmtSymtab(self) });
    }
    try writer.writeAll("thunks\n");
    for (self.thunks.items, 0..) |thunk, index| {
        try writer.print("thunk({d}) : {}\n", .{ index, thunk.fmt(self) });
    }
    try writer.print("stubs\n{}\n", .{self.stubs.fmt(self)});
    try writer.print("objc_stubs\n{}\n", .{self.objc_stubs.fmt(self)});
    try writer.print("got\n{}\n", .{self.got.fmt(self)});
    try writer.print("zig_got\n{}\n", .{self.zig_got.fmt(self)});
    try writer.print("tlv_ptr\n{}\n", .{self.tlv_ptr.fmt(self)});
    try writer.writeByte('\n');
    try writer.print("sections\n{}\n", .{self.fmtSections()});
    try writer.print("segments\n{}\n", .{self.fmtSegments()});
}

fn fmtSections(self: *MachO) std.fmt.Formatter(formatSections) {
    return .{ .data = self };
}

fn formatSections(
    self: *MachO,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const slice = self.sections.slice();
    for (slice.items(.header), slice.items(.segment_id), 0..) |header, seg_id, i| {
        try writer.print(
            "sect({d}) : seg({d}) : {s},{s} : @{x} ({x}) : align({x}) : size({x}) : relocs({x};{d})\n",
            .{
                i,               seg_id,      header.segName(), header.sectName(), header.addr, header.offset,
                header.@"align", header.size, header.reloff,    header.nreloc,
            },
        );
    }
}

fn fmtSegments(self: *MachO) std.fmt.Formatter(formatSegments) {
    return .{ .data = self };
}

fn formatSegments(
    self: *MachO,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    for (self.segments.items, 0..) |seg, i| {
        try writer.print("seg({d}) : {s} : @{x}-{x} ({x}-{x})\n", .{
            i,           seg.segName(),              seg.vmaddr, seg.vmaddr + seg.vmsize,
            seg.fileoff, seg.fileoff + seg.filesize,
        });
    }
}

pub fn fmtSectType(tt: u8) std.fmt.Formatter(formatSectType) {
    return .{ .data = tt };
}

fn formatSectType(
    tt: u8,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const name = switch (tt) {
        macho.S_REGULAR => "REGULAR",
        macho.S_ZEROFILL => "ZEROFILL",
        macho.S_CSTRING_LITERALS => "CSTRING_LITERALS",
        macho.S_4BYTE_LITERALS => "4BYTE_LITERALS",
        macho.S_8BYTE_LITERALS => "8BYTE_LITERALS",
        macho.S_16BYTE_LITERALS => "16BYTE_LITERALS",
        macho.S_LITERAL_POINTERS => "LITERAL_POINTERS",
        macho.S_NON_LAZY_SYMBOL_POINTERS => "NON_LAZY_SYMBOL_POINTERS",
        macho.S_LAZY_SYMBOL_POINTERS => "LAZY_SYMBOL_POINTERS",
        macho.S_SYMBOL_STUBS => "SYMBOL_STUBS",
        macho.S_MOD_INIT_FUNC_POINTERS => "MOD_INIT_FUNC_POINTERS",
        macho.S_MOD_TERM_FUNC_POINTERS => "MOD_TERM_FUNC_POINTERS",
        macho.S_COALESCED => "COALESCED",
        macho.S_GB_ZEROFILL => "GB_ZEROFILL",
        macho.S_INTERPOSING => "INTERPOSING",
        macho.S_DTRACE_DOF => "DTRACE_DOF",
        macho.S_THREAD_LOCAL_REGULAR => "THREAD_LOCAL_REGULAR",
        macho.S_THREAD_LOCAL_ZEROFILL => "THREAD_LOCAL_ZEROFILL",
        macho.S_THREAD_LOCAL_VARIABLES => "THREAD_LOCAL_VARIABLES",
        macho.S_THREAD_LOCAL_VARIABLE_POINTERS => "THREAD_LOCAL_VARIABLE_POINTERS",
        macho.S_THREAD_LOCAL_INIT_FUNCTION_POINTERS => "THREAD_LOCAL_INIT_FUNCTION_POINTERS",
        macho.S_INIT_FUNC_OFFSETS => "INIT_FUNC_OFFSETS",
        else => |x| return writer.print("UNKNOWN({x})", .{x}),
    };
    try writer.print("{s}", .{name});
}

const is_hot_update_compatible = switch (builtin.target.os.tag) {
    .macos => true,
    else => false,
};

const default_entry_symbol_name = "_main";

pub const base_tag: link.File.Tag = link.File.Tag.macho;

const Section = struct {
    header: macho.section_64,
    segment_id: u8,
    atoms: std.ArrayListUnmanaged(Ref) = .{},
    free_list: std.ArrayListUnmanaged(Atom.Index) = .{},
    last_atom_index: Atom.Index = 0,
    thunks: std.ArrayListUnmanaged(Thunk.Index) = .{},
    out: std.ArrayListUnmanaged(u8) = .{},
    relocs: std.ArrayListUnmanaged(macho.relocation_info) = .{},
};

pub const LiteralPool = struct {
    table: std.AutoArrayHashMapUnmanaged(void, void) = .{},
    keys: std.ArrayListUnmanaged(Key) = .{},
    values: std.ArrayListUnmanaged(MachO.Ref) = .{},
    data: std.ArrayListUnmanaged(u8) = .{},

    pub fn deinit(lp: *LiteralPool, allocator: Allocator) void {
        lp.table.deinit(allocator);
        lp.keys.deinit(allocator);
        lp.values.deinit(allocator);
        lp.data.deinit(allocator);
    }

    const InsertResult = struct {
        found_existing: bool,
        index: Index,
        ref: *MachO.Ref,
    };

    pub fn getSymbolRef(lp: LiteralPool, index: Index) MachO.Ref {
        assert(index < lp.values.items.len);
        return lp.values.items[index];
    }

    pub fn getSymbol(lp: LiteralPool, index: Index, macho_file: *MachO) *Symbol {
        return lp.getSymbolRef(index).getSymbol(macho_file).?;
    }

    pub fn insert(lp: *LiteralPool, allocator: Allocator, @"type": u8, string: []const u8) !InsertResult {
        const size: u32 = @intCast(string.len);
        try lp.data.ensureUnusedCapacity(allocator, size);
        const off: u32 = @intCast(lp.data.items.len);
        lp.data.appendSliceAssumeCapacity(string);
        const adapter = Adapter{ .lp = lp };
        const key = Key{ .off = off, .size = size, .seed = @"type" };
        const gop = try lp.table.getOrPutAdapted(allocator, key, adapter);
        if (!gop.found_existing) {
            try lp.keys.append(allocator, key);
            _ = try lp.values.addOne(allocator);
        }
        return .{
            .found_existing = gop.found_existing,
            .index = @intCast(gop.index),
            .ref = &lp.values.items[gop.index],
        };
    }

    const Key = struct {
        off: u32,
        size: u32,
        seed: u8,

        fn getData(key: Key, lp: *const LiteralPool) []const u8 {
            return lp.data.items[key.off..][0..key.size];
        }

        fn eql(key: Key, other: Key, lp: *const LiteralPool) bool {
            const key_data = key.getData(lp);
            const other_data = other.getData(lp);
            return mem.eql(u8, key_data, other_data);
        }

        fn hash(key: Key, lp: *const LiteralPool) u32 {
            const data = key.getData(lp);
            return @truncate(Hash.hash(key.seed, data));
        }
    };

    const Adapter = struct {
        lp: *const LiteralPool,

        pub fn eql(ctx: @This(), key: Key, b_void: void, b_map_index: usize) bool {
            _ = b_void;
            const other = ctx.lp.keys.items[b_map_index];
            return key.eql(other, ctx.lp);
        }

        pub fn hash(ctx: @This(), key: Key) u32 {
            return key.hash(ctx.lp);
        }
    };

    pub const Index = u32;
};

const HotUpdateState = struct {
    mach_task: ?std.c.MachTask = null,
};

pub const SymtabCtx = struct {
    ilocal: u32 = 0,
    istab: u32 = 0,
    iexport: u32 = 0,
    iimport: u32 = 0,
    nlocals: u32 = 0,
    nstabs: u32 = 0,
    nexports: u32 = 0,
    nimports: u32 = 0,
    stroff: u32 = 0,
    strsize: u32 = 0,
};

pub const null_sym = macho.nlist_64{
    .n_strx = 0,
    .n_type = 0,
    .n_sect = 0,
    .n_desc = 0,
    .n_value = 0,
};

pub const Platform = struct {
    os_tag: std.Target.Os.Tag,
    abi: std.Target.Abi,
    version: std.SemanticVersion,

    /// Using Apple's ld64 as our blueprint, `min_version` as well as `sdk_version` are set to
    /// the extracted minimum platform version.
    pub fn fromLoadCommand(lc: macho.LoadCommandIterator.LoadCommand) Platform {
        switch (lc.cmd()) {
            .BUILD_VERSION => {
                const cmd = lc.cast(macho.build_version_command).?;
                return .{
                    .os_tag = switch (cmd.platform) {
                        .MACOS => .macos,
                        .IOS, .IOSSIMULATOR => .ios,
                        .TVOS, .TVOSSIMULATOR => .tvos,
                        .WATCHOS, .WATCHOSSIMULATOR => .watchos,
                        .MACCATALYST => .ios,
                        .VISIONOS, .VISIONOSSIMULATOR => .visionos,
                        else => @panic("TODO"),
                    },
                    .abi = switch (cmd.platform) {
                        .MACCATALYST => .macabi,
                        .IOSSIMULATOR,
                        .TVOSSIMULATOR,
                        .WATCHOSSIMULATOR,
                        .VISIONOSSIMULATOR,
                        => .simulator,
                        else => .none,
                    },
                    .version = appleVersionToSemanticVersion(cmd.minos),
                };
            },
            .VERSION_MIN_MACOSX,
            .VERSION_MIN_IPHONEOS,
            .VERSION_MIN_TVOS,
            .VERSION_MIN_WATCHOS,
            => {
                const cmd = lc.cast(macho.version_min_command).?;
                return .{
                    .os_tag = switch (lc.cmd()) {
                        .VERSION_MIN_MACOSX => .macos,
                        .VERSION_MIN_IPHONEOS => .ios,
                        .VERSION_MIN_TVOS => .tvos,
                        .VERSION_MIN_WATCHOS => .watchos,
                        else => unreachable,
                    },
                    .abi = .none,
                    .version = appleVersionToSemanticVersion(cmd.version),
                };
            },
            else => unreachable,
        }
    }

    pub fn fromTarget(target: std.Target) Platform {
        return .{
            .os_tag = target.os.tag,
            .abi = target.abi,
            .version = target.os.version_range.semver.min,
        };
    }

    pub fn toAppleVersion(plat: Platform) u32 {
        return semanticVersionToAppleVersion(plat.version);
    }

    pub fn toApplePlatform(plat: Platform) macho.PLATFORM {
        return switch (plat.os_tag) {
            .macos => .MACOS,
            .ios => switch (plat.abi) {
                .simulator => .IOSSIMULATOR,
                .macabi => .MACCATALYST,
                else => .IOS,
            },
            .tvos => if (plat.abi == .simulator) .TVOSSIMULATOR else .TVOS,
            .watchos => if (plat.abi == .simulator) .WATCHOSSIMULATOR else .WATCHOS,
            .visionos => if (plat.abi == .simulator) .VISIONOSSIMULATOR else .VISIONOS,
            else => unreachable,
        };
    }

    pub fn isBuildVersionCompatible(plat: Platform) bool {
        inline for (supported_platforms) |sup_plat| {
            if (sup_plat[0] == plat.os_tag and sup_plat[1] == plat.abi) {
                return sup_plat[2] <= plat.toAppleVersion();
            }
        }
        return false;
    }

    pub fn isVersionMinCompatible(plat: Platform) bool {
        inline for (supported_platforms) |sup_plat| {
            if (sup_plat[0] == plat.os_tag and sup_plat[1] == plat.abi) {
                return sup_plat[3] <= plat.toAppleVersion();
            }
        }
        return false;
    }

    pub fn fmtTarget(plat: Platform, cpu_arch: std.Target.Cpu.Arch) std.fmt.Formatter(formatTarget) {
        return .{ .data = .{ .platform = plat, .cpu_arch = cpu_arch } };
    }

    const FmtCtx = struct {
        platform: Platform,
        cpu_arch: std.Target.Cpu.Arch,
    };

    pub fn formatTarget(
        ctx: FmtCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("{s}-{s}", .{ @tagName(ctx.cpu_arch), @tagName(ctx.platform.os_tag) });
        if (ctx.platform.abi != .none) {
            try writer.print("-{s}", .{@tagName(ctx.platform.abi)});
        }
    }

    /// Caller owns the memory.
    pub fn allocPrintTarget(plat: Platform, gpa: Allocator, cpu_arch: std.Target.Cpu.Arch) error{OutOfMemory}![]u8 {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();
        try buffer.writer().print("{}", .{plat.fmtTarget(cpu_arch)});
        return buffer.toOwnedSlice();
    }

    pub fn eqlTarget(plat: Platform, other: Platform) bool {
        return plat.os_tag == other.os_tag and plat.abi == other.abi;
    }
};

const SupportedPlatforms = struct {
    std.Target.Os.Tag,
    std.Target.Abi,
    u32, // Min platform version for which to emit LC_BUILD_VERSION
    u32, // Min supported platform version
};

// Source: https://github.com/apple-oss-distributions/ld64/blob/59a99ab60399c5e6c49e6945a9e1049c42b71135/src/ld/PlatformSupport.cpp#L52
// zig fmt: off
const supported_platforms = [_]SupportedPlatforms{
    .{ .macos,    .none,      0xA0E00, 0xA0800 },
    .{ .ios,      .none,      0xC0000, 0x70000 },
    .{ .tvos,     .none,      0xC0000, 0x70000 },
    .{ .watchos,  .none,      0x50000, 0x20000 },
    .{ .visionos, .none,      0x10000, 0x10000 },
    .{ .ios,      .simulator, 0xD0000, 0x80000 },
    .{ .tvos,     .simulator, 0xD0000, 0x80000 },
    .{ .watchos,  .simulator, 0x60000, 0x20000 },
    .{ .visionos, .simulator, 0x10000, 0x10000 },
};
// zig fmt: on

pub inline fn semanticVersionToAppleVersion(version: std.SemanticVersion) u32 {
    const major = version.major;
    const minor = version.minor;
    const patch = version.patch;
    return (@as(u32, @intCast(major)) << 16) | (@as(u32, @intCast(minor)) << 8) | @as(u32, @intCast(patch));
}

pub inline fn appleVersionToSemanticVersion(version: u32) std.SemanticVersion {
    return .{
        .major = @as(u16, @truncate(version >> 16)),
        .minor = @as(u8, @truncate(version >> 8)),
        .patch = @as(u8, @truncate(version)),
    };
}

fn inferSdkVersion(comp: *Compilation, sdk_layout: SdkLayout) ?std.SemanticVersion {
    const gpa = comp.gpa;

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const sdk_dir = switch (sdk_layout) {
        .sdk => comp.sysroot.?,
        .vendored => fs.path.join(arena, &.{ comp.zig_lib_directory.path.?, "libc", "darwin" }) catch return null,
    };
    if (readSdkVersionFromSettings(arena, sdk_dir)) |ver| {
        return parseSdkVersion(ver);
    } else |_| {
        // Read from settings should always succeed when vendored.
        // TODO: convert to fatal linker error
        if (sdk_layout == .vendored) @panic("zig installation bug: unable to parse SDK version");
    }

    // infer from pathname
    const stem = fs.path.stem(sdk_dir);
    const start = for (stem, 0..) |c, i| {
        if (std.ascii.isDigit(c)) break i;
    } else stem.len;
    const end = for (stem[start..], start..) |c, i| {
        if (std.ascii.isDigit(c) or c == '.') continue;
        break i;
    } else stem.len;
    return parseSdkVersion(stem[start..end]);
}

// Official Apple SDKs ship with a `SDKSettings.json` located at the top of SDK fs layout.
// Use property `MinimalDisplayName` to determine version.
// The file/property is also available with vendored libc.
fn readSdkVersionFromSettings(arena: Allocator, dir: []const u8) ![]const u8 {
    const sdk_path = try fs.path.join(arena, &.{ dir, "SDKSettings.json" });
    const contents = try fs.cwd().readFileAlloc(arena, sdk_path, std.math.maxInt(u16));
    const parsed = try std.json.parseFromSlice(std.json.Value, arena, contents, .{});
    if (parsed.value.object.get("MinimalDisplayName")) |ver| return ver.string;
    return error.SdkVersionFailure;
}

// Versions reported by Apple aren't exactly semantically valid as they usually omit
// the patch component, so we parse SDK value by hand.
fn parseSdkVersion(raw: []const u8) ?std.SemanticVersion {
    var parsed: std.SemanticVersion = .{
        .major = 0,
        .minor = 0,
        .patch = 0,
    };

    const parseNext = struct {
        fn parseNext(it: anytype) ?u16 {
            const nn = it.next() orelse return null;
            return std.fmt.parseInt(u16, nn, 10) catch null;
        }
    }.parseNext;

    var it = std.mem.splitAny(u8, raw, ".");
    parsed.major = parseNext(&it) orelse return null;
    parsed.minor = parseNext(&it) orelse return null;
    parsed.patch = parseNext(&it) orelse 0;
    return parsed;
}

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
pub const default_pagezero_size: u64 = 0x100000000;

/// We commit 0x1000 = 4096 bytes of space to the header and
/// the table of load commands. This should be plenty for any
/// potential future extensions.
pub const default_headerpad_size: u32 = 0x1000;

const SystemLib = struct {
    path: []const u8,
    needed: bool = false,
    weak: bool = false,
    hidden: bool = false,
    reexport: bool = false,
    must_link: bool = false,
};

pub const SdkLayout = std.zig.LibCDirs.DarwinSdkLayout;

const UndefinedTreatment = enum {
    @"error",
    warn,
    suppress,
    dynamic_lookup,
};

/// A reference to atom or symbol in an input file.
/// If file == 0, symbol is an undefined global.
pub const Ref = struct {
    index: u32,
    file: File.Index,

    pub fn eql(ref: Ref, other: Ref) bool {
        return ref.index == other.index and ref.file == other.file;
    }

    pub fn getFile(ref: Ref, macho_file: *MachO) ?File {
        return macho_file.getFile(ref.file);
    }

    pub fn getAtom(ref: Ref, macho_file: *MachO) ?*Atom {
        const file = ref.getFile(macho_file) orelse return null;
        return file.getAtom(ref.index);
    }

    pub fn getSymbol(ref: Ref, macho_file: *MachO) ?*Symbol {
        const file = ref.getFile(macho_file) orelse return null;
        return switch (file) {
            inline else => |x| &x.symbols.items[ref.index],
        };
    }

    pub fn format(
        ref: Ref,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("%{d} in file({d})", .{ ref.index, ref.file });
    }
};

pub const SymbolResolver = struct {
    keys: std.ArrayListUnmanaged(Key) = .{},
    values: std.ArrayListUnmanaged(Ref) = .{},
    table: std.AutoArrayHashMapUnmanaged(void, void) = .{},

    const Result = struct {
        found_existing: bool,
        index: Index,
        ref: *Ref,
    };

    pub fn deinit(resolver: *SymbolResolver, allocator: Allocator) void {
        resolver.keys.deinit(allocator);
        resolver.values.deinit(allocator);
        resolver.table.deinit(allocator);
    }

    pub fn getOrPut(
        resolver: *SymbolResolver,
        allocator: Allocator,
        ref: Ref,
        macho_file: *MachO,
    ) !Result {
        const adapter = Adapter{ .keys = resolver.keys.items, .macho_file = macho_file };
        const key = Key{ .index = ref.index, .file = ref.file };
        const gop = try resolver.table.getOrPutAdapted(allocator, key, adapter);
        if (!gop.found_existing) {
            try resolver.keys.append(allocator, key);
            _ = try resolver.values.addOne(allocator);
        }
        return .{
            .found_existing = gop.found_existing,
            .index = @intCast(gop.index + 1),
            .ref = &resolver.values.items[gop.index],
        };
    }

    pub fn get(resolver: SymbolResolver, index: Index) ?Ref {
        if (index == 0) return null;
        return resolver.values.items[index - 1];
    }

    pub fn reset(resolver: *SymbolResolver) void {
        resolver.keys.clearRetainingCapacity();
        resolver.values.clearRetainingCapacity();
        resolver.table.clearRetainingCapacity();
    }

    const Key = struct {
        index: Symbol.Index,
        file: File.Index,

        fn getName(key: Key, macho_file: *MachO) [:0]const u8 {
            const ref = Ref{ .index = key.index, .file = key.file };
            return ref.getSymbol(macho_file).?.getName(macho_file);
        }

        fn eql(key: Key, other: Key, macho_file: *MachO) bool {
            const key_name = key.getName(macho_file);
            const other_name = other.getName(macho_file);
            return mem.eql(u8, key_name, other_name);
        }

        fn hash(key: Key, macho_file: *MachO) u32 {
            const name = key.getName(macho_file);
            return @truncate(Hash.hash(0, name));
        }
    };

    const Adapter = struct {
        keys: []const Key,
        macho_file: *MachO,

        pub fn eql(ctx: @This(), key: Key, b_void: void, b_map_index: usize) bool {
            _ = b_void;
            const other = ctx.keys[b_map_index];
            return key.eql(other, ctx.macho_file);
        }

        pub fn hash(ctx: @This(), key: Key) u32 {
            return key.hash(ctx.macho_file);
        }
    };

    pub const Index = u32;
};

const MachO = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const fs = std.fs;
const log = std.log.scoped(.link);
const state_log = std.log.scoped(.link_state);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const aarch64 = @import("../arch/aarch64/bits.zig");
const bind = @import("MachO/dyld_info/bind.zig");
const calcUuid = @import("MachO/uuid.zig").calcUuid;
const codegen = @import("../codegen.zig");
const dead_strip = @import("MachO/dead_strip.zig");
const eh_frame = @import("MachO/eh_frame.zig");
const fat = @import("MachO/fat.zig");
const link = @import("../link.zig");
const llvm_backend = @import("../codegen/llvm.zig");
const load_commands = @import("MachO/load_commands.zig");
const relocatable = @import("MachO/relocatable.zig");
const tapi = @import("tapi.zig");
const target_util = @import("../target.zig");
const thunks = @import("MachO/thunks.zig");
const trace = @import("../tracy.zig").trace;
const synthetic = @import("MachO/synthetic.zig");

const Air = @import("../Air.zig");
const Alignment = Atom.Alignment;
const Allocator = mem.Allocator;
const Archive = @import("MachO/Archive.zig");
pub const Atom = @import("MachO/Atom.zig");
const Bind = bind.Bind;
const Cache = std.Build.Cache;
const CodeSignature = @import("MachO/CodeSignature.zig");
const Compilation = @import("../Compilation.zig");
const DataInCode = synthetic.DataInCode;
pub const DebugSymbols = @import("MachO/DebugSymbols.zig");
const Dylib = @import("MachO/Dylib.zig");
const ExportTrie = @import("MachO/dyld_info/Trie.zig");
const File = @import("MachO/file.zig").File;
const GotSection = synthetic.GotSection;
const Hash = std.hash.Wyhash;
const Indsymtab = synthetic.Indsymtab;
const InternalObject = @import("MachO/InternalObject.zig");
const ObjcStubsSection = synthetic.ObjcStubsSection;
const Object = @import("MachO/Object.zig");
const LazyBind = bind.LazyBind;
const LaSymbolPtrSection = synthetic.LaSymbolPtrSection;
const LibStub = tapi.LibStub;
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Md5 = std.crypto.hash.Md5;
const Zcu = @import("../Zcu.zig");
/// Deprecated.
const Module = Zcu;
const InternPool = @import("../InternPool.zig");
const Rebase = @import("MachO/dyld_info/Rebase.zig");
pub const Relocation = @import("MachO/Relocation.zig");
const StringTable = @import("StringTable.zig");
const StubsSection = synthetic.StubsSection;
const StubsHelperSection = synthetic.StubsHelperSection;
const Symbol = @import("MachO/Symbol.zig");
const Thunk = thunks.Thunk;
const TlvPtrSection = synthetic.TlvPtrSection;
const Value = @import("../Value.zig");
const UnwindInfo = @import("MachO/UnwindInfo.zig");
const WeakBind = bind.WeakBind;
const ZigGotSection = synthetic.ZigGotSection;
const ZigObject = @import("MachO/ZigObject.zig");
