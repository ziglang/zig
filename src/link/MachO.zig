base: File,
entry_name: ?[]const u8,

/// If this is not null, an object file is created by LLVM and emitted to zcu_object_sub_path.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

dyld_info_cmd: macho.dyld_info_command = .{},
symtab_cmd: macho.symtab_command = .{},
dysymtab_cmd: macho.dysymtab_command = .{},
function_starts_cmd: macho.linkedit_data_command = .{ .cmd = .FUNCTION_STARTS },
data_in_code_cmd: macho.linkedit_data_command = .{ .cmd = .DATA_IN_CODE },
uuid_cmd: macho.uuid_command = .{ .uuid = [_]u8{0} ** 16 },
codesig_cmd: macho.linkedit_data_command = .{ .cmd = .CODE_SIGNATURE },

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

strtab: StringTable = .{},

/// List of atoms that are either synthetic or map directly to the Zig source program.
atoms: std.ArrayListUnmanaged(Atom) = .{},

sdk_layout: ?SdkLayout,
/// Size of the __PAGEZERO segment.
pagezero_vmsize: u64,
/// Minimum space for future expansion of the load commands.
headerpad_size: u32,
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
        .pagezero_vmsize = options.pagezero_size orelse default_pagezero_vmsize,
        .headerpad_size = options.headerpad_size orelse default_headerpad_size,
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

    // Index 0 is always a null symbol.
    // try self.locals.append(gpa, null_sym);
    try self.strtab.buffer.append(gpa, 0);

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

pub fn flush(self: *MachO, arena: Allocator, prog_node: *std.Progress.Node) link.File.FlushError!void {
    // TODO: what else should we do in flush? Is it actually needed at all?
    try self.flushModule(arena, prog_node);
}

pub fn flushModule(self: *MachO, arena: Allocator, prog_node: *std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;
    _ = gpa;

    if (self.llvm_object) |llvm_object| {
        try self.base.emitLlvmObject(arena, llvm_object, prog_node);
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
    _ = module_obj_path;

    // --verbose-link
    if (comp.verbose_link) try self.dumpArgv(comp);

    @panic("TODO");
}

/// --verbose-link output
fn dumpArgv(self: *MachO, comp: *Compilation) !void {
    _ = self;
    _ = comp;
    @panic("TODO dumpArgv");
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

    _ = self;
    _ = file;
    _ = path;
    _ = must_link;
    _ = dependent_libs;
    _ = ctx;
}

pub fn deinit(self: *MachO) void {
    const gpa = self.base.comp.gpa;

    if (self.llvm_object) |llvm_object| llvm_object.deinit();

    if (self.d_sym) |*d_sym| {
        d_sym.deinit();
    }

    self.strtab.deinit(gpa);

    self.segments.deinit(gpa);

    for (self.sections.items(.free_list)) |*list| {
        list.deinit(gpa);
    }
    self.sections.deinit(gpa);
}

fn freeAtom(self: *MachO, atom_index: Atom.Index) void {
    const gpa = self.base.comp.gpa;
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
    sym: File.LazySymbol,
    atom_index: Atom.Index,
    section_index: u8,
) !void {
    _ = self;
    _ = sym;
    _ = atom_index;
    _ = section_index;
    @panic("TODO updateLazySymbolAtom");
}

pub fn getOrCreateAtomForLazySymbol(self: *MachO, sym: File.LazySymbol) !Atom.Index {
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
) File.UpdateExportsError!void {
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

pub fn getDeclVAddr(self: *MachO, decl_index: InternPool.DeclIndex, reloc_info: File.RelocInfo) !u64 {
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

pub fn makeStaticString(bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    @memcpy(buf[0..bytes.len], bytes);
    return buf;
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
    const target = self.base.comp.root_mod.resolved_target.result;
    const gpa = self.base.comp.gpa;
    const cpu_arch = target.cpu.arch;
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
            var targets_string = std.ArrayList(u8).init(gpa);
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
                    .{ Platform.fromTarget(target).fmtTarget(cpu_arch), targets_string.items },
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
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    const notes = try gpa.alloc(File.ErrorMsg, checked_paths.len);
    errdefer gpa.free(notes);
    for (checked_paths, notes) |path, *note| {
        note.* = .{ .msg = try std.fmt.allocPrint(gpa, "tried {s}", .{path}) };
    }
    comp.link_errors.appendAssumeCapacity(.{
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
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try std.ArrayList(File.ErrorMsg).initCapacity(gpa, 2);
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

pub fn reportParseError(
    self: *MachO,
    path: []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try gpa.alloc(File.ErrorMsg, 1);
    errdefer gpa.free(notes);
    notes[0] = .{ .msg = try std.fmt.allocPrint(gpa, "while parsing {s}", .{path}) };
    comp.link_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, format, args),
        .notes = notes,
    });
}

pub fn reportUnresolvedBoundarySymbol(
    self: *MachO,
    sym_name: []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    var notes = try gpa.alloc(File.ErrorMsg, 1);
    errdefer gpa.free(notes);
    notes[0] = .{ .msg = try std.fmt.allocPrint(gpa, "while resolving {s}", .{sym_name}) };
    comp.link_errors.appendAssumeCapacity(.{
        .msg = try std.fmt.allocPrint(gpa, format, args),
        .notes = notes,
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

const is_hot_update_compatible = switch (builtin.target.os.tag) {
    .macos => true,
    else => false,
};

const default_entry_symbol_name = "_main";

pub const base_tag: File.Tag = File.Tag.macho;
pub const N_DEAD: u16 = @as(u16, @bitCast(@as(i16, -1)));
pub const N_BOUNDARY: u16 = @as(u16, @bitCast(@as(i16, -2)));

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

const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.OptionalDeclIndex, LazySymbolMetadata);

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_atom: Atom.Index = undefined,
    data_const_atom: Atom.Index = undefined,
    text_state: State = .unused,
    data_const_state: State = .unused,
};

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
    platform: macho.PLATFORM,
    version: Version,

    /// Using Apple's ld64 as our blueprint, `min_version` as well as `sdk_version` are set to
    /// the extracted minimum platform version.
    pub fn fromLoadCommand(lc: macho.LoadCommandIterator.LoadCommand) Platform {
        switch (lc.cmd()) {
            .BUILD_VERSION => {
                const lc_cmd = lc.cast(macho.build_version_command).?;
                return .{
                    .platform = lc_cmd.platform,
                    .version = .{ .value = lc_cmd.minos },
                };
            },
            .VERSION_MIN_MACOSX,
            .VERSION_MIN_IPHONEOS,
            .VERSION_MIN_TVOS,
            .VERSION_MIN_WATCHOS,
            => {
                const lc_cmd = lc.cast(macho.version_min_command).?;
                return .{
                    .platform = switch (lc.cmd()) {
                        .VERSION_MIN_MACOSX => .MACOS,
                        .VERSION_MIN_IPHONEOS => .IOS,
                        .VERSION_MIN_TVOS => .TVOS,
                        .VERSION_MIN_WATCHOS => .WATCHOS,
                        else => unreachable,
                    },
                    .version = .{ .value = lc_cmd.version },
                };
            },
            else => unreachable,
        }
    }

    pub fn isBuildVersionCompatible(plat: Platform) bool {
        inline for (supported_platforms) |sup_plat| {
            if (sup_plat[0] == plat.platform) {
                return sup_plat[1] <= plat.version.value;
            }
        }
        return false;
    }
};

pub const Version = struct {
    value: u32,

    pub fn major(v: Version) u16 {
        return @as(u16, @truncate(v.value >> 16));
    }

    pub fn minor(v: Version) u8 {
        return @as(u8, @truncate(v.value >> 8));
    }

    pub fn patch(v: Version) u8 {
        return @as(u8, @truncate(v.value));
    }

    pub fn parse(raw: []const u8) ?Version {
        var parsed: [3]u16 = [_]u16{0} ** 3;
        var count: usize = 0;
        var it = std.mem.splitAny(u8, raw, ".");
        while (it.next()) |comp| {
            if (count >= 3) return null;
            parsed[count] = std.fmt.parseInt(u16, comp, 10) catch return null;
            count += 1;
        }
        if (count == 0) return null;
        const maj = parsed[0];
        const min = std.math.cast(u8, parsed[1]) orelse return null;
        const pat = std.math.cast(u8, parsed[2]) orelse return null;
        return Version.new(maj, min, pat);
    }

    pub fn new(maj: u16, min: u8, pat: u8) Version {
        return .{ .value = (@as(u32, @intCast(maj)) << 16) | (@as(u32, @intCast(min)) << 8) | pat };
    }

    pub fn format(
        v: Version,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("{d}.{d}.{d}", .{
            v.major(),
            v.minor(),
            v.patch(),
        });
    }
};

const SupportedPlatforms = struct {
    macho.PLATFORM, // Platform identifier
    u32, // Min platform version for which to emit LC_BUILD_VERSION
    u32, // Min supported platform version
    ?[]const u8, // Env var to look for
};

// Source: https://github.com/apple-oss-distributions/ld64/blob/59a99ab60399c5e6c49e6945a9e1049c42b71135/src/ld/PlatformSupport.cpp#L52
const supported_platforms = [_]SupportedPlatforms{
    .{ .MACOS, 0xA0E00, 0xA0800, "MACOSX_DEPLOYMENT_TARGET" },
    .{ .IOS, 0xC0000, 0x70000, "IPHONEOS_DEPLOYMENT_TARGET" },
    .{ .TVOS, 0xC0000, 0x70000, "TVOS_DEPLOYMENT_TARGET" },
    .{ .WATCHOS, 0x50000, 0x20000, "WATCHOS_DEPLOYMENT_TARGET" },
    .{ .IOSSIMULATOR, 0xD0000, 0x80000, null },
    .{ .TVOSSIMULATOR, 0xD0000, 0x80000, null },
    .{ .WATCHOSSIMULATOR, 0x60000, 0x20000, null },
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
const tapi = @import("tapi.zig");
const target_util = @import("../target.zig");
const thunks = @import("MachO/thunks.zig");
const trace = @import("../tracy.zig").trace;

const Air = @import("../Air.zig");
const Alignment = Atom.Alignment;
const Allocator = mem.Allocator;
const Archive = @import("MachO/Archive.zig");
pub const Atom = @import("MachO/Atom.zig");
const Cache = std.Build.Cache;
const CodeSignature = @import("MachO/CodeSignature.zig");
const Compilation = @import("../Compilation.zig");
pub const DebugSymbols = @import("MachO/DebugSymbols.zig");
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
const Relocation = @import("MachO/Relocation.zig");
const StringTable = @import("StringTable.zig");
const TableSection = @import("table_section.zig").TableSection;
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const Value = @import("../value.zig").Value;
