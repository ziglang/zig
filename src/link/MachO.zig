base: link.File,

/// If this is not null, an object file is created by LLVM and emitted to zcu_object_sub_path.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

/// A list of all input files.
/// Index of each input file also encodes the priority or precedence of one input file
/// over another.
files: std.MultiArrayList(File.Entry) = .{},
internal_object: ?File.Index = null,
objects: std.ArrayListUnmanaged(File.Index) = .{},
dylibs: std.ArrayListUnmanaged(File.Index) = .{},

segments: std.ArrayListUnmanaged(macho.segment_command_64) = .{},
sections: std.MultiArrayList(Section) = .{},

symbols: std.ArrayListUnmanaged(Symbol) = .{},
symbols_extra: std.ArrayListUnmanaged(u32) = .{},
globals: std.AutoHashMapUnmanaged(u32, Symbol.Index) = .{},
/// This table will be populated after `scanRelocs` has run.
/// Key is symbol index.
undefs: std.AutoHashMapUnmanaged(Symbol.Index, std.ArrayListUnmanaged(Atom.Index)) = .{},
/// Global symbols we need to resolve for the link to succeed.
undefined_symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
boundary_symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},

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
data_sect_index: ?u8 = null,
got_sect_index: ?u8 = null,
stubs_sect_index: ?u8 = null,
stubs_helper_sect_index: ?u8 = null,
la_symbol_ptr_sect_index: ?u8 = null,
tlv_ptr_sect_index: ?u8 = null,
eh_frame_sect_index: ?u8 = null,
unwind_info_sect_index: ?u8 = null,
objc_stubs_sect_index: ?u8 = null,

mh_execute_header_index: ?Symbol.Index = null,
mh_dylib_header_index: ?Symbol.Index = null,
dyld_private_index: ?Symbol.Index = null,
dyld_stub_binder_index: ?Symbol.Index = null,
dso_handle_index: ?Symbol.Index = null,
objc_msg_send_index: ?Symbol.Index = null,
entry_index: ?Symbol.Index = null,

/// List of atoms that are either synthetic or map directly to the Zig source program.
atoms: std.ArrayListUnmanaged(Atom) = .{},
thunks: std.ArrayListUnmanaged(Thunk) = .{},
unwind_records: std.ArrayListUnmanaged(UnwindInfo.Record) = .{},

/// String interning table
strings: StringTable = .{},

/// Output synthetic sections
symtab: std.ArrayListUnmanaged(macho.nlist_64) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
indsymtab: Indsymtab = .{},
got: GotSection = .{},
stubs: StubsSection = .{},
stubs_helper: StubsHelperSection = .{},
objc_stubs: ObjcStubsSection = .{},
la_symbol_ptr: LaSymbolPtrSection = .{},
tlv_ptr: TlvPtrSection = .{},
rebase: RebaseSection = .{},
bind: BindSection = .{},
weak_bind: WeakBindSection = .{},
lazy_bind: LazyBindSection = .{},
export_trie: ExportTrieSection = .{},
unwind_info: UnwindInfo = .{},

/// Options
/// SDK layout
sdk_layout: ?SdkLayout,
/// Size of the __PAGEZERO segment.
pagezero_vmsize: ?u64,
/// Minimum space for future expansion of the load commands.
headerpad_size: ?u32,
/// Set enough space as if all paths were MATPATHLEN.
headerpad_max_install_names: bool,
/// Remove dylibs that are unreachable by the entry point or exported symbols.
dead_strip_dylibs: bool,
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

/// The filesystem layout of darwin SDK elements.
pub const SdkLayout = enum {
    /// macOS SDK layout: TOP { /usr/include, /usr/lib, /System/Library/Frameworks }.
    sdk,
    /// Shipped libc layout: TOP { /lib/libc/include,  /lib/libc/darwin, <NONE> }.
    vendored,
};

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
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
            .rpath_list = options.rpath_list,
        },
        .pagezero_vmsize = options.pagezero_size,
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
    // Atom at index 0 is reserved as null atom
    try self.atoms.append(gpa, .{});
    // Append empty string to string tables
    try self.strings.buffer.append(gpa, 0);
    try self.strtab.append(gpa, 0);
    // Append null symbols
    try self.symbols.append(gpa, .{});
    try self.symbols_extra.append(gpa, 0);

    // TODO: init

    if (opt_zcu) |zcu| {
        if (!use_llvm) {
            _ = zcu;
            // TODO: create .zig_object

            if (comp.config.debug_format != .strip) {
                // Create dSYM bundle.
                log.debug("creating {s}.dSYM bundle", .{emit.sub_path});

                const d_sym_path = try std.fmt.allocPrint(
                    arena,
                    "{s}.dSYM" ++ fs.path.sep_str ++ "Contents" ++ fs.path.sep_str ++ "Resources" ++ fs.path.sep_str ++ "DWARF",
                    .{emit.sub_path},
                );

                var d_sym_bundle = try emit.directory.handle.makeOpenPath(d_sym_path, .{});
                defer d_sym_bundle.close();

                const d_sym_file = try d_sym_bundle.createFile(emit.sub_path, .{
                    .truncate = false,
                    .read = true,
                });

                self.d_sym = .{
                    .allocator = gpa,
                    .dwarf = link.File.Dwarf.init(&self.base, .dwarf32),
                    .file = d_sym_file,
                };
            }
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

    for (self.files.items(.tags), self.files.items(.data)) |tag, *data| switch (tag) {
        .null => {},
        .internal => data.internal.deinit(gpa),
        .object => data.object.deinit(gpa),
        .dylib => data.dylib.deinit(gpa),
    };
    self.files.deinit(gpa);
    self.objects.deinit(gpa);
    self.dylibs.deinit(gpa);

    self.segments.deinit(gpa);
    for (self.sections.items(.atoms)) |*list| {
        list.deinit(gpa);
    }
    self.sections.deinit(gpa);

    self.symbols.deinit(gpa);
    self.symbols_extra.deinit(gpa);
    self.globals.deinit(gpa);
    {
        var it = self.undefs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(gpa);
        }
        self.undefs.deinit(gpa);
    }
    self.undefined_symbols.deinit(gpa);
    self.boundary_symbols.deinit(gpa);

    self.strings.deinit(gpa);
    self.symtab.deinit(gpa);
    self.strtab.deinit(gpa);
    self.got.deinit(gpa);
    self.stubs.deinit(gpa);
    self.objc_stubs.deinit(gpa);
    self.tlv_ptr.deinit(gpa);
    self.rebase.deinit(gpa);
    self.bind.deinit(gpa);
    self.weak_bind.deinit(gpa);
    self.lazy_bind.deinit(gpa);
    self.export_trie.deinit(gpa);
    self.unwind_info.deinit(gpa);

    self.atoms.deinit(gpa);
    for (self.thunks.items) |*thunk| {
        thunk.deinit(gpa);
    }
    self.thunks.deinit(gpa);
    self.unwind_records.deinit(gpa);
}

pub fn flush(self: *MachO, arena: Allocator, prog_node: *std.Progress.Node) link.File.FlushError!void {
    // TODO: I think this is just a temp and can be removed once we can emit static archives
    if (self.base.isStaticLib() and build_options.have_llvm) {
        return self.base.linkAsArchive(arena, prog_node);
    }
    try self.flushModule(arena, prog_node);
}

pub fn flushModule(self: *MachO, arena: Allocator, prog_node: *std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;

    if (self.llvm_object) |llvm_object| {
        try self.base.emitLlvmObject(arena, llvm_object, prog_node);
        // TODO: I think this is just a temp and can be removed once we can emit static archives
        if (self.base.isStaticLib() and build_options.have_llvm) return;
    }

    var sub_prog_node = prog_node.start("MachO Flush", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    const target = comp.root_mod.resolved_target.result;
    _ = target;
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

    if (self.base.isStaticLib()) return self.flushStaticLib(comp, module_obj_path);
    if (self.base.isObject()) return self.flushObject(comp, module_obj_path);

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

    // rpaths
    var rpath_table = std.StringArrayHashMap(void).init(gpa);
    defer rpath_table.deinit();
    try rpath_table.ensureUnusedCapacity(self.base.rpath_list.len);

    for (self.base.rpath_list) |rpath| {
        _ = rpath_table.putAssumeCapacity(rpath, {});
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

    // try self.parseDependentDylibs();

    for (self.dylibs.items) |index| {
        const dylib = self.getFile(index).?.dylib;
        if (!dylib.explicit and !dylib.hoisted) continue;
        try dylib.initSymbols(self);
    }

    {
        const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
        self.files.set(index, .{ .internal = .{ .index = index } });
        self.internal_object = index;
    }

    try self.addUndefinedGlobals();
    try self.resolveSymbols();

    state_log.debug("{}", .{self.dumpState()});

    @panic("TODO");
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

    try argv.append("-o");
    try argv.append(full_out_path);

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

        if (self.pagezero_vmsize) |size| {
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

        if (self.entry_name) |entry_name| {
            try argv.appendSlice(&.{ "-e", entry_name });
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

        if (comp.compiler_rt_lib) |lib| try argv.append(lib.full_object_path);
        if (comp.compiler_rt_obj) |obj| try argv.append(obj.full_object_path);

        if (comp.config.link_libcpp) {
            try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
            try argv.append(comp.libcxx_static_lib.?.full_object_path);
        }

        try argv.append("-o");
        try argv.append(full_out_path);

        try argv.append("-lSystem");

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

        for (self.frameworks) |framework| {
            const name = std.fs.path.stem(framework.path);
            const arg = if (framework.needed)
                try std.fmt.allocPrint(arena, "-needed_framework {s}", .{name})
            else if (framework.weak)
                try std.fmt.allocPrint(arena, "-weak_framework {s}", .{name})
            else
                try std.fmt.allocPrint(arena, "-framework {s}", .{name});
            try argv.append(arg);
        }

        if (self.base.isDynLib() and self.base.allow_shlib_undefined) {
            try argv.append("-undefined");
            try argv.append("dynamic_lookup");
        }
    }

    Compilation.dump_argv(argv.items);
}

fn flushStaticLib(self: *MachO, comp: *Compilation, module_obj_path: ?[]const u8) link.File.FlushError!void {
    _ = comp;
    _ = module_obj_path;

    var err = try self.addErrorWithNotes(0);
    try err.addMsg(self, "TODO implement flushStaticLib", .{});

    return error.FlushFailure;
}

fn flushObject(self: *MachO, comp: *Compilation, module_obj_path: ?[]const u8) link.File.FlushError!void {
    _ = comp;
    _ = module_obj_path;

    var err = try self.addErrorWithNotes(0);
    try err.addMsg(self, "TODO implement flushObject", .{});

    return error.FlushFailure;
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
    out_libs: anytype,
) !void {
    var test_path = std.ArrayList(u8).init(arena);
    var checked_paths = std.ArrayList([]const u8).init(arena);

    success: {
        if (self.sdk_layout) |sdk_layout| switch (sdk_layout) {
            .sdk => {
                const dir = try fs.path.join(arena, &[_][]const u8{ comp.sysroot.?, "usr", "lib" });
                if (try accessLibPath(arena, &test_path, &checked_paths, dir, "libSystem")) break :success;
            },
            .vendored => {
                const dir = try comp.zig_lib_directory.join(arena, &[_][]const u8{ "libc", "darwin" });
                if (try accessLibPath(arena, &test_path, &checked_paths, dir, "libSystem")) break :success;
            },
        };

        try self.reportMissingLibraryError(checked_paths.items, "unable to find libSystem system library", .{});
        return error.MissingLibSystem;
    }

    const libsystem_path = try arena.dupe(u8, test_path.items);
    try out_libs.append(.{
        .needed = true,
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
} || std.os.SeekError || std.fs.File.OpenError || std.fs.File.ReadError || tapi.TapiError;

fn parsePositional(self: *MachO, path: []const u8, must_link: bool) ParseError!void {
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
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const mtime: u64 = mtime: {
        const stat = file.stat() catch break :mtime 0;
        break :mtime @as(u64, @intCast(@divFloor(stat.mtime, 1_000_000_000)));
    };
    const data = try file.readToEndAlloc(gpa, std.math.maxInt(u32));
    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .object = .{
        .path = try gpa.dupe(u8, path),
        .mtime = mtime,
        .data = data,
        .index = index,
    } });
    try self.objects.append(gpa, index);

    const object = self.getFile(index).?.object;
    try object.parse(self);
}

fn parseFatLibrary(self: *MachO, path: []const u8) !fat.Arch {
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

    const file = try std.fs.cwd().openFile(lib.path, .{});
    defer file.close();

    const data = if (fat_arch) |arch| blk: {
        try file.seekTo(arch.offset);
        const data = try gpa.alloc(u8, arch.size);
        const nread = try file.readAll(data);
        if (nread != arch.size) return error.InputOutput;
        break :blk data;
    } else try file.readToEndAlloc(gpa, std.math.maxInt(u32));

    var archive = Archive{ .path = try gpa.dupe(u8, lib.path), .data = data };
    defer archive.deinit(gpa);
    try archive.parse(self);

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
        // TODO: object.alive = object.alive or (self.options.force_load_objc and object.hasObjc());
    }
    if (has_parse_error) return error.MalformedArchive;
}

fn parseDylib(self: *MachO, lib: SystemLib, explicit: bool, fat_arch: ?fat.Arch) ParseError!File.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;

    const file = try std.fs.cwd().openFile(lib.path, .{});
    defer file.close();

    const data = if (fat_arch) |arch| blk: {
        try file.seekTo(arch.offset);
        const data = try gpa.alloc(u8, arch.size);
        const nread = try file.readAll(data);
        if (nread != arch.size) return error.InputOutput;
        break :blk data;
    } else try file.readToEndAlloc(gpa, std.math.maxInt(u32));

    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .dylib = .{
        .path = try gpa.dupe(u8, lib.path),
        .data = data,
        .index = index,
        .needed = lib.needed,
        .weak = lib.weak,
        .reexport = lib.reexport,
        .explicit = explicit,
    } });
    const dylib = &self.files.items(.data)[index].dylib;
    try dylib.parse(self);

    try self.dylibs.append(gpa, index);

    return index;
}

fn parseTbd(self: *MachO, lib: SystemLib, explicit: bool) ParseError!File.Index {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const file = try std.fs.cwd().openFile(lib.path, .{});
    defer file.close();

    var lib_stub = LibStub.loadFromFile(gpa, file) catch return error.MalformedTbd; // TODO actually handle different errors
    defer lib_stub.deinit();

    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .dylib = .{
        .path = try gpa.dupe(u8, lib.path),
        .data = &[0]u8{},
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

// /// According to ld64's manual, public (i.e., system) dylibs/frameworks are hoisted into the final
// /// image unless overriden by -no_implicit_dylibs.
// fn isHoisted(self: *MachO, install_name: []const u8) bool {
//     _ = self;
//     // TODO: if (self.options.no_implicit_dylibs) return true;
//     if (std.fs.path.dirname(install_name)) |dirname| {
//         if (mem.startsWith(u8, dirname, "/usr/lib")) return true;
//         if (eatPrefix(dirname, "/System/Library/Frameworks/")) |path| {
//             const basename = std.fs.path.basename(install_name);
//             if (mem.indexOfScalar(u8, path, '.')) |index| {
//                 if (mem.eql(u8, basename, path[0..index])) return true;
//             }
//         }
//     }
//     return false;
// }

// fn parseDependentDylibs(
//     self: *MachO
// ) !void {
//     const tracy = trace(@src());
//     defer tracy.end();

//     const gpa = self.base.comp.gpa;
//     const lib_dirs = self.base.comp.lib_dirs;
//     const framework_dirs = self.base.comp.framework_dirs;

//     if (self.dylibs.items.len == 0) return;

//     var arena = std.heap.ArenaAllocator.init(gpa);
//     defer arena.deinit();

//     // TODO handle duplicate dylibs - it is not uncommon to have the same dylib loaded multiple times
//     // in which case we should track that and return File.Index immediately instead re-parsing paths.

//     var index: usize = 0;
//     while (index < self.dylibs.items.len) : (index += 1) {
//         const dylib_index = self.dylibs.items[index];

//         var dependents = std.ArrayList(File.Index).init(gpa);
//         defer dependents.deinit();
//         try dependents.ensureTotalCapacityPrecise(self.getFile(dylib_index).?.dylib.dependents.items.len);

//         const is_weak = self.getFile(dylib_index).?.dylib.weak;
//         for (self.getFile(dylib_index).?.dylib.dependents.items) |id| {
//             // We will search for the dependent dylibs in the following order:
//             // 1. Basename is in search lib directories or framework directories
//             // 2. If name is an absolute path, search as-is optionally prepending a syslibroot
//             //    if specified.
//             // 3. If name is a relative path, substitute @rpath, @loader_path, @executable_path with
//             //    dependees list of rpaths, and search there.
//             // 4. Finally, just search the provided relative path directly in CWD.
//             const full_path = full_path: {
//                 fail: {
//                     const stem = std.fs.path.stem(id.name);
//                     const framework_name = try std.fmt.allocPrint(gpa, "{s}.framework" ++ std.fs.path.sep_str ++ "{s}", .{
//                         stem,
//                         stem,
//                     });
//                     defer gpa.free(framework_name);

//                     if (mem.endsWith(u8, id.name, framework_name)) {
//                         // Framework
//                         const full_path = (try self.resolveFramework(arena, framework_dirs, stem)) orelse break :fail;
//                         break :full_path full_path;
//                     }

//                     // Library
//                     const lib_name = eatPrefix(stem, "lib") orelse stem;
//                     const full_path = (try self.resolveLib(arena, lib_dirs, lib_name)) orelse break :fail;
//                     break :full_path full_path;
//                 }

//                 if (std.fs.path.isAbsolute(id.name)) {
//                     const path = if (self.options.syslibroot) |root|
//                         try std.fs.path.join(arena, &.{ root, id.name })
//                     else
//                         id.name;
//                     for (&[_][]const u8{ "", ".tbd", ".dylib" }) |ext| {
//                         const full_path = try std.fmt.allocPrint(arena, "{s}{s}", .{ path, ext });
//                         if (try accessLibPath(full_path)) break :full_path full_path;
//                     }
//                 }

//                 if (eatPrefix(id.name, "@rpath/")) |path| {
//                     const dylib = self.getFile(dylib_index).?.dylib;
//                     for (self.getFile(dylib.umbrella).?.dylib.rpaths.keys()) |rpath| {
//                         const prefix = eatPrefix(rpath, "@loader_path/") orelse rpath;
//                         const rel_path = try std.fs.path.join(arena, &.{ prefix, path });
//                         var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
//                         const full_path = std.fs.realpath(rel_path, &buffer) catch continue;
//                         break :full_path full_path;
//                     }
//                 } else if (eatPrefix(id.name, "@loader_path/")) |_| {
//                     return self.base.fatal("{s}: TODO handle install_name '{s}'", .{
//                         self.getFile(dylib_index).?.dylib.path, id.name,
//                     });
//                 } else if (eatPrefix(id.name, "@executable_path/")) |_| {
//                     return self.base.fatal("{s}: TODO handle install_name '{s}'", .{
//                         self.getFile(dylib_index).?.dylib.path, id.name,
//                     });
//                 }

//                 var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
//                 const full_path = std.fs.realpath(id.name, &buffer) catch {
//                     dependents.appendAssumeCapacity(0);
//                     continue;
//                 };
//                 break :full_path full_path;
//             };
//             const link_obj = LinkObject{
//                 .path = full_path,
//                 .tag = .obj,
//                 .weak = is_weak,
//             };
//             const file_index = file_index: {
//                 if (try self.parseDylib(arena, link_obj, false)) |file| break :file_index file;
//                 if (try self.parseTbd(link_obj, false)) |file| break :file_index file;
//                 break :file_index @as(File.Index, 0);
//             };
//             dependents.appendAssumeCapacity(file_index);
//         }

//         const dylib = self.getFile(dylib_index).?.dylib;
//         for (dylib.dependents.items, dependents.items) |id, file_index| {
//             if (self.getFile(file_index)) |file| {
//                 const dep_dylib = file.dylib;
//                 dep_dylib.hoisted = self.isHoisted(id.name);
//                 if (self.getFile(dep_dylib.umbrella) == null) {
//                     dep_dylib.umbrella = dylib.umbrella;
//                 }
//                 if (!dep_dylib.hoisted) {
//                     const umbrella = dep_dylib.getUmbrella(self);
//                     for (dep_dylib.exports.items(.name), dep_dylib.exports.items(.flags)) |off, flags| {
//                         try umbrella.addExport(gpa, dep_dylib.getString(off), flags);
//                     }
//                     try umbrella.rpaths.ensureUnusedCapacity(gpa, dep_dylib.rpaths.keys().len);
//                     for (dep_dylib.rpaths.keys()) |rpath| {
//                         umbrella.rpaths.putAssumeCapacity(rpath, {});
//                     }
//                 }
//             } else self.base.fatal("{s}: unable to resolve dependency {s}", .{ dylib.getUmbrella(self).path, id.name });
//         }
//     }
// }

fn addUndefinedGlobals(self: *MachO) !void {
    const gpa = self.base.comp.gpa;

    try self.undefined_symbols.ensureUnusedCapacity(gpa, self.base.comp.force_undefined_symbols.keys().len);
    for (self.base.comp.force_undefined_symbols.keys()) |name| {
        const off = try self.strings.insert(gpa, name);
        const gop = try self.getOrCreateGlobal(off);
        self.undefined_symbols.appendAssumeCapacity(gop.index);
    }

    if (!self.base.isDynLib() and self.entry_name != null) {
        const off = try self.strings.insert(gpa, self.entry_name.?);
        const gop = try self.getOrCreateGlobal(off);
        self.entry_index = gop.index;
    }

    {
        const off = try self.strings.insert(gpa, "dyld_stub_binder");
        const gop = try self.getOrCreateGlobal(off);
        self.dyld_stub_binder_index = gop.index;
    }

    {
        const off = try self.strings.insert(gpa, "_objc_msgSend");
        const gop = try self.getOrCreateGlobal(off);
        self.objc_msg_send_index = gop.index;
    }
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

    // Resolve symbols on the set of all objects and shared objects (even if some are unneeded).
    for (self.objects.items) |index| self.getFile(index).?.resolveSymbols(self);
    for (self.dylibs.items) |index| self.getFile(index).?.resolveSymbols(self);

    // Mark live objects.
    self.markLive();

    // Reset state of all globals after marking live objects.
    for (self.objects.items) |index| self.getFile(index).?.resetGlobals(self);
    for (self.dylibs.items) |index| self.getFile(index).?.resetGlobals(self);

    // Prune dead objects.
    var i: usize = 0;
    while (i < self.objects.items.len) {
        const index = self.objects.items[i];
        if (!self.getFile(index).?.object.alive) {
            _ = self.objects.orderedRemove(i);
        } else i += 1;
    }

    // Re-resolve the symbols.
    for (self.objects.items) |index| self.getFile(index).?.resolveSymbols(self);
    for (self.dylibs.items) |index| self.getFile(index).?.resolveSymbols(self);
}

fn markLive(self: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.undefined_symbols.items) |index| {
        if (self.getSymbol(index).getFile(self)) |file| {
            if (file == .object) file.object.alive = true;
        }
    }
    if (self.entry_index) |index| {
        const sym = self.getSymbol(index);
        if (sym.getFile(self)) |file| {
            if (file == .object) file.object.alive = true;
        }
    }
    for (self.objects.items) |index| {
        const object = self.getFile(index).?.object;
        if (object.alive) object.markLive(self);
    }
}

fn shrinkAtom(self: *MachO, atom_index: Atom.Index, new_block_size: u64) void {
    _ = self;
    _ = atom_index;
    _ = new_block_size;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn growAtom(self: *MachO, atom_index: Atom.Index, new_atom_size: u64, alignment: Alignment) !u64 {
    _ = self;
    _ = atom_index;
    _ = new_atom_size;
    _ = alignment;
    @panic("TODO growAtom");
}

pub fn updateFunc(self: *MachO, mod: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(mod, func_index, air, liveness);

    @panic("TODO updateFunc");
}

pub fn lowerUnnamedConst(self: *MachO, typed_value: TypedValue, decl_index: InternPool.DeclIndex) !u32 {
    _ = self;
    _ = typed_value;
    _ = decl_index;

    @panic("TODO lowerUnnamedConst");
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
    _ = self;
    _ = name;
    _ = tv;
    _ = required_alignment;
    _ = sect_id;
    _ = src_loc;

    @panic("TODO lowerConst");
}

pub fn updateDecl(self: *MachO, mod: *Module, decl_index: InternPool.DeclIndex) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(mod, decl_index);

    const tracy = trace(@src());
    defer tracy.end();

    @panic("TODO updateDecl");
}

fn updateLazySymbolAtom(
    self: *MachO,
    sym: link.File.LazySymbol,
    atom_index: Atom.Index,
    section_index: u8,
) !void {
    _ = self;
    _ = sym;
    _ = atom_index;
    _ = section_index;
    @panic("TODO updateLazySymbolAtom");
}

pub fn getOrCreateAtomForLazySymbol(self: *MachO, sym: link.File.LazySymbol) !Atom.Index {
    _ = self;
    _ = sym;
    @panic("TODO getOrCreateAtomForLazySymbol");
}

pub fn getOrCreateAtomForDecl(self: *MachO, decl_index: InternPool.DeclIndex) !Atom.Index {
    _ = self;
    _ = decl_index;
    @panic("TODO getOrCreateAtomForDecl");
}

fn getDeclOutputSection(self: *MachO, decl_index: InternPool.DeclIndex) u8 {
    _ = self;
    _ = decl_index;
    @panic("TODO getDeclOutputSection");
}

fn updateDeclCode(self: *MachO, decl_index: InternPool.DeclIndex, code: []u8) !u64 {
    _ = self;
    _ = decl_index;
    _ = code;
    @panic("TODO updateDeclCode");
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl_index: InternPool.DeclIndex) !void {
    if (self.d_sym) |*d_sym| {
        try d_sym.dwarf.updateDeclLineNumber(module, decl_index);
    }
}

pub fn updateExports(
    self: *MachO,
    mod: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) link.File.UpdateExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object|
        return llvm_object.updateExports(mod, exported, exports);

    @panic("TODO updateExports");
}

pub fn deleteDeclExport(
    self: *MachO,
    decl_index: InternPool.DeclIndex,
    name: InternPool.NullTerminatedString,
) Allocator.Error!void {
    if (self.llvm_object) |_| return;
    _ = decl_index;
    _ = name;
    @panic("TODO deleteDeclExport");
}

fn freeUnnamedConsts(self: *MachO, decl_index: InternPool.DeclIndex) void {
    _ = self;
    _ = decl_index;
    @panic("TODO freeUnnamedConst");
}

pub fn freeDecl(self: *MachO, decl_index: InternPool.DeclIndex) void {
    if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    @panic("TODO freeDecl");
}

pub fn getDeclVAddr(self: *MachO, decl_index: InternPool.DeclIndex, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    _ = decl_index;
    _ = reloc_info;
    @panic("TODO getDeclVAddr");
}

pub fn lowerAnonDecl(
    self: *MachO,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.SrcLoc,
) !codegen.Result {
    _ = self;
    _ = decl_val;
    _ = explicit_alignment;
    _ = src_loc;
    @panic("TODO lowerAnonDecl");
}

pub fn getAnonDeclVAddr(self: *MachO, decl_val: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    _ = decl_val;
    _ = reloc_info;
    @panic("TODO getAnonDeclVAddr");
}

pub fn getGlobalSymbol(self: *MachO, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = self;
    _ = name;
    _ = lib_name;
    @panic("TODO getGlobalSymbol");
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

pub fn getTarget(self: MachO) std.Target {
    return self.base.comp.root_mod.resolved_target.result;
}

pub fn makeStaticString(bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    @memcpy(buf[0..bytes.len], bytes);
    return buf;
}

pub fn getFile(self: *MachO, index: File.Index) ?File {
    const tag = self.files.items(.tags)[index];
    return switch (tag) {
        .null => null,
        .internal => .{ .internal = &self.files.items(.data)[index].internal },
        .object => .{ .object = &self.files.items(.data)[index].object },
        .dylib => .{ .dylib = &self.files.items(.data)[index].dylib },
    };
}

pub fn getInternalObject(self: *MachO) ?*InternalObject {
    const index = self.internal_object orelse return null;
    return self.getFile(index).?.internal;
}

pub fn addAtom(self: *MachO) error{OutOfMemory}!Atom.Index {
    const index = @as(Atom.Index, @intCast(self.atoms.items.len));
    const atom = try self.atoms.addOne(self.base.comp.gpa);
    atom.* = .{};
    return index;
}

pub fn getAtom(self: *MachO, index: Atom.Index) ?*Atom {
    if (index == 0) return null;
    assert(index < self.atoms.items.len);
    return &self.atoms.items[index];
}

pub fn addSymbol(self: *MachO) !Symbol.Index {
    const index = @as(Symbol.Index, @intCast(self.symbols.items.len));
    const symbol = try self.symbols.addOne(self.base.comp.gpa);
    symbol.* = .{};
    return index;
}

pub fn getSymbol(self: *MachO, index: Symbol.Index) *Symbol {
    assert(index < self.symbols.items.len);
    return &self.symbols.items[index];
}

pub fn addSymbolExtra(self: *MachO, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    try self.symbols_extra.ensureUnusedCapacity(self.base.comp.gpa, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

pub fn addSymbolExtraAssumeCapacity(self: *MachO, extra: Symbol.Extra) u32 {
    const index = @as(u32, @intCast(self.symbols_extra.items.len));
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    inline for (fields) |field| {
        self.symbols_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn getSymbolExtra(self: MachO, index: u32) ?Symbol.Extra {
    if (index == 0) return null;
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    var i: usize = index;
    var result: Symbol.Extra = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => self.symbols_extra.items[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return result;
}

pub fn setSymbolExtra(self: *MachO, index: u32, extra: Symbol.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

const GetOrCreateGlobalResult = struct {
    found_existing: bool,
    index: Symbol.Index,
};

pub fn getOrCreateGlobal(self: *MachO, off: u32) !GetOrCreateGlobalResult {
    const gpa = self.base.comp.gpa;
    const gop = try self.globals.getOrPut(gpa, off);
    if (!gop.found_existing) {
        const index = try self.addSymbol();
        const global = self.getSymbol(index);
        global.name = off;
        gop.value_ptr.* = index;
    }
    return .{
        .found_existing = gop.found_existing,
        .index = gop.value_ptr.*,
    };
}

pub fn getGlobalByName(self: *MachO, name: []const u8) ?Symbol.Index {
    const off = self.strings.getOffset(name) orelse return null;
    return self.globals.get(off);
}

pub fn addUnwindRecord(self: *MachO) !UnwindInfo.Record.Index {
    const index = @as(UnwindInfo.Record.Index, @intCast(self.unwind_records.items.len));
    const rec = try self.unwind_records.addOne(self.base.comp.gpa);
    rec.* = .{};
    return index;
}

pub fn getUnwindRecord(self: *MachO, index: UnwindInfo.Record.Index) *UnwindInfo.Record {
    assert(index < self.unwind_records.items.len);
    return &self.unwind_records.items[index];
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

fn reportDependencyError(
    self: *MachO,
    parent: []const u8,
    path: ?[]const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try std.ArrayList(link.File.ErrorMsg).initCapacity(gpa, 2);
    defer notes.deinit();
    if (path) |p| {
        notes.appendAssumeCapacity(.{ .msg = try std.fmt.allocPrint(gpa, "while parsing {s}", .{p}) });
    }
    notes.appendAssumeCapacity(.{ .msg = try std.fmt.allocPrint(gpa, "a dependency of {s}", .{parent}) });
    comp.link_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, format, args),
        .notes = try notes.toOwnedSlice(),
    });
}

pub fn reportUndefined(self: *MachO) error{OutOfMemory}!void {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    const count = self.unresolved.count();
    try comp.link_errors.ensureUnusedCapacity(gpa, count);

    for (self.unresolved.keys()) |global_index| {
        const global = self.globals.items[global_index];
        const sym_name = self.getSymbolName(global);

        var notes = try std.ArrayList(link.File.ErrorMsg).initCapacity(gpa, 1);
        defer notes.deinit();

        if (global.getFile()) |file| {
            const note = try std.fmt.allocPrint(gpa, "referenced in {s}", .{
                self.objects.items[file].name,
            });
            notes.appendAssumeCapacity(.{ .msg = note });
        }

        var err_msg = link.File.ErrorMsg{
            .msg = try std.fmt.allocPrint(gpa, "undefined reference to symbol {s}", .{sym_name}),
        };
        err_msg.notes = try notes.toOwnedSlice();

        comp.link_errors.appendAssumeCapacity(err_msg);
    }
}

// fn reportSymbolCollision(
//     self: *MachO,
//     first: SymbolWithLoc,
//     other: SymbolWithLoc,
// ) error{OutOfMemory}!void {
//     const comp = self.base.comp;
//     const gpa = comp.gpa;
//     try comp.link_errors.ensureUnusedCapacity(gpa, 1);

//     var notes = try std.ArrayList(File.ErrorMsg).initCapacity(gpa, 2);
//     defer notes.deinit();

//     if (first.getFile()) |file| {
//         const note = try std.fmt.allocPrint(gpa, "first definition in {s}", .{
//             self.objects.items[file].name,
//         });
//         notes.appendAssumeCapacity(.{ .msg = note });
//     }
//     if (other.getFile()) |file| {
//         const note = try std.fmt.allocPrint(gpa, "next definition in {s}", .{
//             self.objects.items[file].name,
//         });
//         notes.appendAssumeCapacity(.{ .msg = note });
//     }

//     var err_msg = File.ErrorMsg{ .msg = try std.fmt.allocPrint(gpa, "symbol {s} defined multiple times", .{
//         self.getSymbolName(first),
//     }) };
//     err_msg.notes = try notes.toOwnedSlice();

//     comp.link_errors.appendAssumeCapacity(err_msg);
// }

// fn reportUnhandledSymbolType(self: *MachO, sym_with_loc: SymbolWithLoc) error{OutOfMemory}!void {
//     const comp = self.base.comp;
//     const gpa = comp.gpa;
//     try comp.link_errors.ensureUnusedCapacity(gpa, 1);

//     const notes = try gpa.alloc(File.ErrorMsg, 1);
//     errdefer gpa.free(notes);

//     const file = sym_with_loc.getFile().?;
//     notes[0] = .{ .msg = try std.fmt.allocPrint(gpa, "defined in {s}", .{self.objects.items[file].name}) };

//     const sym = self.getSymbol(sym_with_loc);
//     const sym_type = if (sym.stab())
//         "stab"
//     else if (sym.indr())
//         "indirect"
//     else if (sym.abs())
//         "absolute"
//     else
//         unreachable;

//     comp.link_errors.appendAssumeCapacity(.{
//         .msg = try std.fmt.allocPrint(gpa, "unhandled symbol type: '{s}' has type {s}", .{
//             self.getSymbolName(sym_with_loc),
//             sym_type,
//         }),
//         .notes = notes,
//     });
// }

pub fn getDebugSymbols(self: *MachO) ?*DebugSymbols {
    if (self.d_sym) |*ds| {
        return ds;
    } else return null;
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
        try writer.print("sect({d}) : seg({d}) : {s},{s} : @{x} ({x}) : align({x}) : size({x})\n", .{
            i,               seg_id,      header.segName(), header.sectName(), header.offset, header.addr,
            header.@"align", header.size,
        });
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
pub const N_DEAD: u16 = @as(u16, @bitCast(@as(i16, -1)));
pub const N_BOUNDARY: u16 = @as(u16, @bitCast(@as(i16, -2)));

const Section = struct {
    header: macho.section_64,
    segment_id: u8,
    atoms: std.ArrayListUnmanaged(Atom.Index) = .{},
};

const HotUpdateState = struct {
    mach_task: ?std.os.darwin.MachTask = null,
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
                        else => @panic("TODO"),
                    },
                    .abi = switch (cmd.platform) {
                        .IOSSIMULATOR,
                        .TVOSSIMULATOR,
                        .WATCHOSSIMULATOR,
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
            .ios => if (plat.abi == .simulator) .IOSSIMULATOR else .IOS,
            .tvos => if (plat.abi == .simulator) .TVOSSIMULATOR else .TVOS,
            .watchos => if (plat.abi == .simulator) .WATCHOSSIMULATOR else .WATCHOS,
            else => unreachable,
        };
    }

    pub fn isBuildVersionCompatible(plat: Platform) bool {
        inline for (supported_platforms) |sup_plat| {
            if (sup_plat[0] == plat.platform) {
                return sup_plat[1] <= plat.version.value;
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
    .{ .macos,   .none,      0xA0E00, 0xA0800 },
    .{ .ios,     .none,      0xC0000, 0x70000 },
    .{ .tvos,    .none,      0xC0000, 0x70000 },
    .{ .watchos, .none,      0x50000, 0x20000 },
    .{ .ios,     .simulator, 0xD0000, 0x80000 },
    .{ .tvos,    .simulator, 0xD0000, 0x80000 },
    .{ .watchos, .simulator, 0x60000, 0x20000 },
};
// zig fmt: on

inline fn semanticVersionToAppleVersion(version: std.SemanticVersion) u32 {
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
        .vendored => std.fs.path.join(arena, &.{ comp.zig_lib_directory.path.?, "libc", "darwin" }) catch return null,
    };
    if (readSdkVersionFromSettings(arena, sdk_dir)) |ver| {
        return parseSdkVersion(ver);
    } else |_| {
        // Read from settings should always succeed when vendored.
        // TODO: convert to fatal linker error
        if (sdk_layout == .vendored) @panic("zig installation bug: unable to parse SDK version");
    }

    // infer from pathname
    const stem = std.fs.path.stem(sdk_dir);
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
    const sdk_path = try std.fs.path.join(arena, &.{ dir, "SDKSettings.json" });
    const contents = try std.fs.cwd().readFileAlloc(arena, sdk_path, std.math.maxInt(u16));
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
pub const default_pagezero_vmsize: u64 = 0x100000000;

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
const calcUuid = @import("MachO/uuid.zig").calcUuid;
const codegen = @import("../codegen.zig");
const dead_strip = @import("MachO/dead_strip.zig");
const eh_frame = @import("MachO/eh_frame.zig");
const fat = @import("MachO/fat.zig");
const link = @import("../link.zig");
const llvm_backend = @import("../codegen/llvm.zig");
const load_commands = @import("MachO/load_commands.zig");
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
const BindSection = synthetic.BindSection;
const Cache = std.Build.Cache;
const CodeSignature = @import("MachO/CodeSignature.zig");
const Compilation = @import("../Compilation.zig");
pub const DebugSymbols = @import("MachO/DebugSymbols.zig");
const Dwarf = File.Dwarf;
const DwarfInfo = @import("MachO/DwarfInfo.zig");
const Dylib = @import("MachO/Dylib.zig");
const ExportTrieSection = synthetic.ExportTrieSection;
const File = @import("MachO/file.zig").File;
const GotSection = synthetic.GotSection;
const Indsymtab = synthetic.Indsymtab;
const InternalObject = @import("MachO/InternalObject.zig");
const ObjcStubsSection = synthetic.ObjcStubsSection;
const Object = @import("MachO/Object.zig");
const LazyBindSection = synthetic.LazyBindSection;
const LaSymbolPtrSection = synthetic.LaSymbolPtrSection;
const LibStub = tapi.LibStub;
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Md5 = std.crypto.hash.Md5;
const Module = @import("../Module.zig");
const InternPool = @import("../InternPool.zig");
const RebaseSection = synthetic.RebaseSection;
const Relocation = @import("MachO/Relocation.zig");
const StringTable = @import("StringTable.zig");
const StubsSection = synthetic.StubsSection;
const StubsHelperSection = synthetic.StubsHelperSection;
const Symbol = @import("MachO/Symbol.zig");
const Thunk = thunks.Thunk;
const TlvPtrSection = synthetic.TlvPtrSection;
const TypedValue = @import("../TypedValue.zig");
const UnwindInfo = @import("MachO/UnwindInfo.zig");
const WeakBindSection = synthetic.WeakBindSection;
