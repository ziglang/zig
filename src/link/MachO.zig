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
const codegen = @import("../codegen.zig");
const dead_strip = @import("MachO/dead_strip.zig");
const fat = @import("MachO/fat.zig");
const link = @import("../link.zig");
const llvm_backend = @import("../codegen/llvm.zig");
const load_commands = @import("MachO/load_commands.zig");
const stubs = @import("MachO/stubs.zig");
const target_util = @import("../target.zig");
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
const Dylib = @import("MachO/Dylib.zig");
const File = link.File;
const Object = @import("MachO/Object.zig");
const LibStub = @import("tapi.zig").LibStub;
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Md5 = std.crypto.hash.Md5;
const Module = @import("../Module.zig");
const Relocation = @import("MachO/Relocation.zig");
const StringTable = @import("strtab.zig").StringTable;
const TableSection = @import("table_section.zig").TableSection;
const Trie = @import("MachO/Trie.zig");
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const Value = @import("../value.zig").Value;

pub const DebugSymbols = @import("MachO/DebugSymbols.zig");

const Bind = @import("MachO/dyld_info/bind.zig").Bind(*const MachO, MachO.SymbolWithLoc);
const LazyBind = @import("MachO/dyld_info/bind.zig").LazyBind(*const MachO, MachO.SymbolWithLoc);
const Rebase = @import("MachO/dyld_info/Rebase.zig");

pub const base_tag: File.Tag = File.Tag.macho;

pub const SearchStrategy = enum {
    paths_first,
    dylibs_first,
};

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

const Section = struct {
    header: macho.section_64,
    segment_index: u8,

    // TODO is null here necessary, or can we do away with tracking via section
    // size in incremental context?
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

base: File,

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

/// Page size is dependent on the target cpu architecture.
/// For x86_64 that's 4KB, whereas for aarch64, that's 16KB.
page_size: u16,

mode: Mode,

dyld_info_cmd: macho.dyld_info_command = .{},
symtab_cmd: macho.symtab_command = .{},
dysymtab_cmd: macho.dysymtab_command = .{},
uuid_cmd: macho.uuid_command = .{},
codesig_cmd: macho.linkedit_data_command = .{ .cmd = .CODE_SIGNATURE },

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
stubs_section_index: ?u8 = null,
stub_helper_section_index: ?u8 = null,
got_section_index: ?u8 = null,
data_const_section_index: ?u8 = null,
la_symbol_ptr_section_index: ?u8 = null,
data_section_index: ?u8 = null,
thread_vars_section_index: ?u8 = null,
thread_data_section_index: ?u8 = null,

locals: std.ArrayListUnmanaged(macho.nlist_64) = .{},
globals: std.ArrayListUnmanaged(SymbolWithLoc) = .{},
resolver: std.StringHashMapUnmanaged(u32) = .{},
unresolved: std.AutoArrayHashMapUnmanaged(u32, ResolveAction.Kind) = .{},

locals_free_list: std.ArrayListUnmanaged(u32) = .{},
globals_free_list: std.ArrayListUnmanaged(u32) = .{},

dyld_stub_binder_index: ?u32 = null,
dyld_private_atom_index: ?Atom.Index = null,

strtab: StringTable(.strtab) = .{},

got_table: TableSection(SymbolWithLoc) = .{},
stub_table: TableSection(SymbolWithLoc) = .{},

error_flags: File.ErrorFlags = File.ErrorFlags{},

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

/// A table of relocations indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
relocs: RelocationTable = .{},

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
decls: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, DeclMetadata) = .{},

/// Table of threadlocal variables descriptors.
/// They are emitted in the `__thread_vars` section.
tlv_table: TlvSymbolTable = .{},

/// Hot-code swapping state.
hot_state: if (is_hot_update_compatible) HotUpdateState else struct {} = .{},

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
            if (mem.eql(u8, name, macho_file.getSymbolName(.{
                .sym_index = exp,
                .file = null,
            }))) return exp;
        }
        return null;
    }

    fn getExportPtr(m: *DeclMetadata, macho_file: *MachO, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            if (mem.eql(u8, name, macho_file.getSymbolName(.{
                .sym_index = exp.*,
                .file = null,
            }))) return exp;
        }
        return null;
    }
};

const BindingTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Atom.Binding));
const UnnamedConstTable = std.AutoArrayHashMapUnmanaged(Module.Decl.Index, std.ArrayListUnmanaged(Atom.Index));
const RebaseTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(u32));
const RelocationTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Relocation));

const ResolveAction = struct {
    kind: Kind,
    target: SymbolWithLoc,

    const Kind = enum {
        none,
        add_got,
        add_stub,
    };
};

pub const SymbolWithLoc = struct {
    // Index into the respective symbol table.
    sym_index: u32,

    // null means it's a synthetic global.
    file: ?u32 = null,

    pub fn eql(this: SymbolWithLoc, other: SymbolWithLoc) bool {
        if (this.file == null and other.file == null) {
            return this.sym_index == other.sym_index;
        }
        if (this.file != null and other.file != null) {
            return this.sym_index == other.sym_index and this.file.? == other.file.?;
        }
        return false;
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
            .dwarf = link.File.Dwarf.init(allocator, &self.base, options.target),
            .file = d_sym_file,
            .page_size = self.page_size,
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
        try d_sym.populateMissingMetadata();
    }

    return self;
}

pub fn createEmpty(gpa: Allocator, options: link.Options) !*MachO {
    const cpu_arch = options.target.cpu.arch;
    const page_size: u16 = if (cpu_arch == .aarch64) 0x4000 else 0x1000;
    const use_llvm = build_options.have_llvm and options.use_llvm;

    const self = try gpa.create(MachO);
    errdefer gpa.destroy(self);

    self.* = .{
        .base = .{
            .tag = .macho,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .page_size = page_size,
        .mode = if (use_llvm or options.module == null or options.cache_mode == .whole)
            .zld
        else
            .incremental,
    };

    if (use_llvm) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }

    log.debug("selected linker mode '{s}'", .{@tagName(self.mode)});

    return self;
}

pub fn flush(self: *MachO, comp: *Compilation, prog_node: *std.Progress.Node) link.File.FlushError!void {
    if (self.base.options.emit == null) {
        if (build_options.have_llvm) {
            if (self.llvm_object) |llvm_object| {
                try llvm_object.flushModule(comp, prog_node);
            }
        }
        return;
    }

    if (self.base.options.output_mode == .Lib and self.base.options.link_mode == .Static) {
        if (build_options.have_llvm) {
            return self.base.linkAsArchive(comp, prog_node);
        } else {
            log.err("TODO: non-LLVM archiver for MachO object files", .{});
            return error.TODOImplementWritingStaticLibFiles;
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

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| {
            return try llvm_object.flushModule(comp, prog_node);
        }
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
    try resolveLibSystem(
        arena,
        comp,
        self.base.options.sysroot,
        self.base.options.target,
        &.{},
        &libs,
    );

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

        var dependent_libs = std.fifo.LinearFifo(struct {
            id: Dylib.Id,
            parent: u16,
        }, .Dynamic).init(arena);

        try self.parseLibs(libs.keys(), libs.values(), self.base.options.sysroot, &dependent_libs);
        try self.parseDependentLibs(self.base.options.sysroot, &dependent_libs);
    }

    if (self.dyld_stub_binder_index == null) {
        self.dyld_stub_binder_index = try self.addUndefined("dyld_stub_binder", .add_got);
    }
    if (!self.base.options.single_threaded) {
        _ = try self.addUndefined("__tlv_bootstrap", .none);
    }

    try self.createMhExecuteHeaderSymbol();

    var actions = std.ArrayList(ResolveAction).init(self.base.allocator);
    defer actions.deinit();
    try self.resolveSymbolsInDylibs(&actions);

    if (self.unresolved.count() > 0) {
        for (self.unresolved.keys()) |index| {
            // TODO: convert into compiler errors.
            const global = self.globals.items[index];
            const sym_name = self.getSymbolName(global);
            log.err("undefined symbol reference '{s}'", .{sym_name});
        }
        return error.UndefinedSymbolReference;
    }

    for (actions.items) |action| switch (action.kind) {
        .none => {},
        .add_got => try self.addGotEntry(action.target),
        .add_stub => try self.addStubEntry(action.target),
    };

    try self.createDyldPrivateAtom();
    try self.writeStubHelperPreamble();

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

    const target = self.base.options.target;
    const requires_codesig = blk: {
        if (self.base.options.entitlements) |_| break :blk true;
        if (target.cpu.arch == .aarch64 and (target.os.tag == .macos or target.abi == .simulator))
            break :blk true;
        break :blk false;
    };
    var codesig: ?CodeSignature = if (requires_codesig) blk: {
        // Preallocate space for the code signature.
        // We need to do this at this stage so that we have the load commands with proper values
        // written out to the file.
        // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
        // where the code signature goes into.
        var codesig = CodeSignature.init(self.page_size);
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
            const global = self.getEntryPoint() catch |err| switch (err) {
                error.MissingMainEntrypoint => {
                    self.error_flags.no_entry_point_found = true;
                    break :blk;
                },
                else => |e| return e,
            };
            const sym = self.getSymbol(global);
            try lc_writer.writeStruct(macho.entry_point_command{
                .entryoff = @intCast(u32, sym.n_value - seg.vmaddr),
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
    try load_commands.writeBuildVersionLC(&self.base.options, lc_writer);

    if (self.cold_start) {
        std.crypto.random.bytes(&self.uuid_cmd.uuid);
        Md5.hash(&self.uuid_cmd.uuid, &self.uuid_cmd.uuid, .{});
        conformUuid(&self.uuid_cmd.uuid);
    }
    try lc_writer.writeStruct(self.uuid_cmd);

    try load_commands.writeLoadDylibLCs(self.dylibs.items, self.referenced_dylibs.keys(), lc_writer);

    if (requires_codesig) {
        try lc_writer.writeStruct(self.codesig_cmd);
    }

    try self.base.file.?.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64));

    const ncmds = load_commands.calcNumOfLCs(lc_buffer.items);
    try self.writeHeader(ncmds, @intCast(u32, lc_buffer.items.len));

    if (codesig) |*csig| {
        try self.writeCodeSignature(comp, csig); // code signing always comes last
        const emit = self.base.options.emit.?;
        try invalidateKernelCache(emit.directory.handle, emit.sub_path);
    }

    if (self.d_sym) |*d_sym| {
        // Flush debug symbols bundle.
        try d_sym.flushModule(self);
    }

    // if (build_options.enable_link_snapshots) {
    //     if (self.base.options.enable_link_snapshots)
    //         try self.snapshotState();
    // }

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
    arena: Allocator,
    comp: *Compilation,
    syslibroot: ?[]const u8,
    target: std.Target,
    search_dirs: []const []const u8,
    out_libs: anytype,
) !void {
    // If we were given the sysroot, try to look there first for libSystem.B.{dylib, tbd}.
    var libsystem_available = false;
    if (syslibroot != null) blk: {
        // Try stub file first. If we hit it, then we're done as the stub file
        // re-exports every single symbol definition.
        for (search_dirs) |dir| {
            if (try resolveLib(arena, dir, "System", ".tbd")) |full_path| {
                try out_libs.put(full_path, .{ .needed = true });
                libsystem_available = true;
                break :blk;
            }
        }
        // If we didn't hit the stub file, try .dylib next. However, libSystem.dylib
        // doesn't export libc.dylib which we'll need to resolve subsequently also.
        for (search_dirs) |dir| {
            if (try resolveLib(arena, dir, "System", ".dylib")) |libsystem_path| {
                if (try resolveLib(arena, dir, "c", ".dylib")) |libc_path| {
                    try out_libs.put(libsystem_path, .{ .needed = true });
                    try out_libs.put(libc_path, .{ .needed = true });
                    libsystem_available = true;
                    break :blk;
                }
            }
        }
    }
    if (!libsystem_available) {
        const libsystem_name = try std.fmt.allocPrint(arena, "libSystem.{d}.tbd", .{
            target.os.version_range.semver.min.major,
        });
        const full_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
            "libc", "darwin", libsystem_name,
        });
        try out_libs.put(full_path, .{ .needed = true });
    }
}

pub fn resolveSearchDir(
    arena: Allocator,
    dir: []const u8,
    syslibroot: ?[]const u8,
) !?[]const u8 {
    var candidates = std.ArrayList([]const u8).init(arena);

    if (fs.path.isAbsolute(dir)) {
        if (syslibroot) |root| {
            const common_dir = if (builtin.os.tag == .windows) blk: {
                // We need to check for disk designator and strip it out from dir path so
                // that we can concat dir with syslibroot.
                // TODO we should backport this mechanism to 'MachO.Dylib.parseDependentLibs()'
                const disk_designator = fs.path.diskDesignatorWindows(dir);

                if (mem.indexOf(u8, dir, disk_designator)) |where| {
                    break :blk dir[where + disk_designator.len ..];
                }

                break :blk dir;
            } else dir;
            const full_path = try fs.path.join(arena, &[_][]const u8{ root, common_dir });
            try candidates.append(full_path);
        }
    }

    try candidates.append(dir);

    for (candidates.items) |candidate| {
        // Verify that search path actually exists
        var tmp = fs.cwd().openDir(candidate, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        defer tmp.close();

        return candidate;
    }

    return null;
}

pub fn resolveLib(
    arena: Allocator,
    search_dir: []const u8,
    name: []const u8,
    ext: []const u8,
) !?[]const u8 {
    const search_name = try std.fmt.allocPrint(arena, "lib{s}{s}", .{ name, ext });
    const full_path = try fs.path.join(arena, &[_][]const u8{ search_dir, search_name });

    // Check if the file exists.
    const tmp = fs.cwd().openFile(full_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |e| return e,
    };
    defer tmp.close();

    return full_path;
}

pub fn resolveFramework(
    arena: Allocator,
    search_dir: []const u8,
    name: []const u8,
    ext: []const u8,
) !?[]const u8 {
    const search_name = try std.fmt.allocPrint(arena, "{s}{s}", .{ name, ext });
    const prefix_path = try std.fmt.allocPrint(arena, "{s}.framework", .{name});
    const full_path = try fs.path.join(arena, &[_][]const u8{ search_dir, prefix_path, search_name });

    // Check if the file exists.
    const tmp = fs.cwd().openFile(full_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |e| return e,
    };
    defer tmp.close();

    return full_path;
}

const ParseDylibError = error{
    OutOfMemory,
    EmptyStubFile,
    MismatchedCpuArchitecture,
    UnsupportedCpuArchitecture,
    EndOfStream,
} || fs.File.OpenError || std.os.PReadError || Dylib.Id.ParseError;

const DylibCreateOpts = struct {
    syslibroot: ?[]const u8,
    id: ?Dylib.Id = null,
    dependent: bool = false,
    needed: bool = false,
    weak: bool = false,
};

pub fn parseDylib(
    self: *MachO,
    path: []const u8,
    dependent_libs: anytype,
    opts: DylibCreateOpts,
) ParseDylibError!bool {
    const gpa = self.base.allocator;
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    defer file.close();

    const cpu_arch = self.base.options.target.cpu.arch;
    const file_stat = try file.stat();
    var file_size = math.cast(usize, file_stat.size) orelse return error.Overflow;

    const reader = file.reader();
    const fat_offset = math.cast(usize, try fat.getLibraryOffset(reader, cpu_arch)) orelse
        return error.Overflow;
    try file.seekTo(fat_offset);
    file_size -= fat_offset;

    const contents = try file.readToEndAllocOptions(gpa, file_size, file_size, @alignOf(u64), null);
    defer gpa.free(contents);

    const dylib_id = @intCast(u16, self.dylibs.items.len);
    var dylib = Dylib{ .weak = opts.weak };

    dylib.parseFromBinary(
        gpa,
        cpu_arch,
        dylib_id,
        dependent_libs,
        path,
        contents,
    ) catch |err| switch (err) {
        error.EndOfStream, error.NotDylib => {
            try file.seekTo(0);

            var lib_stub = LibStub.loadFromFile(gpa, file) catch {
                dylib.deinit(gpa);
                return false;
            };
            defer lib_stub.deinit();

            try dylib.parseFromStub(
                gpa,
                self.base.options.target,
                lib_stub,
                dylib_id,
                dependent_libs,
                path,
            );
        },
        else => |e| return e,
    };

    if (opts.id) |id| {
        if (dylib.id.?.current_version < id.compatibility_version) {
            log.warn("found dylib is incompatible with the required minimum version", .{});
            log.warn("  dylib: {s}", .{id.name});
            log.warn("  required minimum version: {}", .{id.compatibility_version});
            log.warn("  dylib version: {}", .{dylib.id.?.current_version});

            // TODO maybe this should be an error and facilitate auto-cleanup?
            dylib.deinit(gpa);
            return false;
        }
    }

    try self.dylibs.append(gpa, dylib);
    try self.dylibs_map.putNoClobber(gpa, dylib.id.?.name, dylib_id);

    const should_link_dylib_even_if_unreachable = blk: {
        if (self.base.options.dead_strip_dylibs and !opts.needed) break :blk false;
        break :blk !(opts.dependent or self.referenced_dylibs.contains(dylib_id));
    };

    if (should_link_dylib_even_if_unreachable) {
        try self.referenced_dylibs.putNoClobber(gpa, dylib_id, {});
    }

    return true;
}

pub fn parseInputFiles(self: *MachO, files: []const []const u8, syslibroot: ?[]const u8, dependent_libs: anytype) !void {
    for (files) |file_name| {
        const full_path = full_path: {
            var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
            break :full_path try fs.realpath(file_name, &buffer);
        };
        log.debug("parsing input file path '{s}'", .{full_path});

        if (try self.parseObject(full_path)) continue;
        if (try self.parseArchive(full_path, false)) continue;
        if (try self.parseDylib(full_path, dependent_libs, .{
            .syslibroot = syslibroot,
        })) continue;

        log.debug("unknown filetype for positional input file: '{s}'", .{file_name});
    }
}

pub fn parseAndForceLoadStaticArchives(self: *MachO, files: []const []const u8) !void {
    for (files) |file_name| {
        const full_path = full_path: {
            var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
            break :full_path try fs.realpath(file_name, &buffer);
        };
        log.debug("parsing and force loading static archive '{s}'", .{full_path});

        if (try self.parseArchive(full_path, true)) continue;
        log.debug("unknown filetype: expected static archive: '{s}'", .{file_name});
    }
}

pub fn parseLibs(
    self: *MachO,
    lib_names: []const []const u8,
    lib_infos: []const link.SystemLib,
    syslibroot: ?[]const u8,
    dependent_libs: anytype,
) !void {
    for (lib_names, 0..) |lib, i| {
        const lib_info = lib_infos[i];
        log.debug("parsing lib path '{s}'", .{lib});
        if (try self.parseDylib(lib, dependent_libs, .{
            .syslibroot = syslibroot,
            .needed = lib_info.needed,
            .weak = lib_info.weak,
        })) continue;

        log.debug("unknown filetype for a library: '{s}'", .{lib});
    }
}

pub fn parseDependentLibs(self: *MachO, syslibroot: ?[]const u8, dependent_libs: anytype) !void {
    // At this point, we can now parse dependents of dylibs preserving the inclusion order of:
    // 1) anything on the linker line is parsed first
    // 2) afterwards, we parse dependents of the included dylibs
    // TODO this should not be performed if the user specifies `-flat_namespace` flag.
    // See ld64 manpages.
    var arena_alloc = std.heap.ArenaAllocator.init(self.base.allocator);
    const arena = arena_alloc.allocator();
    defer arena_alloc.deinit();

    while (dependent_libs.readItem()) |*dep_id| {
        defer dep_id.id.deinit(self.base.allocator);

        if (self.dylibs_map.contains(dep_id.id.name)) continue;

        const weak = self.dylibs.items[dep_id.parent].weak;
        const has_ext = blk: {
            const basename = fs.path.basename(dep_id.id.name);
            break :blk mem.lastIndexOfScalar(u8, basename, '.') != null;
        };
        const extension = if (has_ext) fs.path.extension(dep_id.id.name) else "";
        const without_ext = if (has_ext) blk: {
            const index = mem.lastIndexOfScalar(u8, dep_id.id.name, '.') orelse unreachable;
            break :blk dep_id.id.name[0..index];
        } else dep_id.id.name;

        for (&[_][]const u8{ extension, ".tbd" }) |ext| {
            const with_ext = try std.fmt.allocPrint(arena, "{s}{s}", .{ without_ext, ext });
            const full_path = if (syslibroot) |root| try fs.path.join(arena, &.{ root, with_ext }) else with_ext;

            log.debug("trying dependency at fully resolved path {s}", .{full_path});

            const did_parse_successfully = try self.parseDylib(full_path, dependent_libs, .{
                .id = dep_id.id,
                .syslibroot = syslibroot,
                .dependent = true,
                .weak = weak,
            });
            if (did_parse_successfully) break;
        } else {
            log.debug("unable to resolve dependency {s}", .{dep_id.id.name});
        }
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
    mem.writeIntLittle(u64, &buf, entry_value);
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
    const size = stubs.calcStubHelperPreambleSize(cpu_arch);

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
    const stub_entry_size = stubs.calcStubEntrySize(cpu_arch);
    const stub_helper_entry_size = stubs.calcStubHelperEntrySize(cpu_arch);
    const stub_helper_preamble_size = stubs.calcStubHelperPreambleSize(cpu_arch);

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
        mem.writeIntLittle(u64, &buf, stub_helper_addr);
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
        if (global.file != null) continue;
        const sym = self.getSymbolPtr(global);
        const seg = self.getSegment(self.text_section_index.?);
        sym.n_sect = 1;
        sym.n_value = seg.vmaddr;

        log.debug("allocating {s} at the start of {s}", .{
            name,
            seg.segName(),
        });
    }
}

pub fn createAtom(self: *MachO) !Atom.Index {
    const gpa = self.base.allocator;
    const atom_index = @intCast(Atom.Index, self.atoms.items.len);
    const atom = try self.atoms.addOne(gpa);
    const sym_index = try self.allocateSymbol();
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom_index);
    atom.* = .{
        .sym_index = sym_index,
        .file = null,
        .size = 0,
        .prev_index = null,
        .next_index = null,
    };
    log.debug("creating ATOM(%{d}) at index {d}", .{ sym_index, atom_index });
    return atom_index;
}

fn createDyldPrivateAtom(self: *MachO) !void {
    if (self.dyld_private_atom_index != null) return;

    const atom_index = try self.createAtom();
    const atom = self.getAtomPtr(atom_index);
    atom.size = @sizeOf(u64);

    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.data_section_index.? + 1;
    self.dyld_private_atom_index = atom_index;

    sym.n_value = try self.allocateAtom(atom_index, atom.size, @alignOf(u64));
    log.debug("allocated dyld_private atom at 0x{x}", .{sym.n_value});
    var buffer: [@sizeOf(u64)]u8 = [_]u8{0} ** @sizeOf(u64);
    try self.writeAtom(atom_index, &buffer);
}

fn createThreadLocalDescriptorAtom(self: *MachO, sym_name: []const u8, target: SymbolWithLoc) !Atom.Index {
    const gpa = self.base.allocator;
    const size = 3 * @sizeOf(u64);
    const required_alignment: u32 = 1;
    const atom_index = try self.createAtom();
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

fn createMhExecuteHeaderSymbol(self: *MachO) !void {
    if (self.base.options.output_mode != .Exe) return;
    if (self.getGlobal("__mh_execute_header")) |global| {
        const sym = self.getSymbol(global);
        if (!sym.undf() and !(sym.pext() or sym.weakDef())) return;
    }

    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    const sym = self.getSymbolPtr(sym_loc);
    sym.* = .{
        .n_strx = try self.strtab.insert(gpa, "__mh_execute_header"),
        .n_type = macho.N_SECT | macho.N_EXT,
        .n_sect = 0,
        .n_desc = macho.REFERENCED_DYNAMICALLY,
        .n_value = 0,
    };

    const gop = try self.getOrPutGlobalPtr("__mh_execute_header");
    gop.value_ptr.* = sym_loc;
}

fn createDsoHandleSymbol(self: *MachO) !void {
    const global = self.getGlobalPtr("___dso_handle") orelse return;
    if (!self.getSymbol(global.*).undf()) return;

    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    const sym = self.getSymbolPtr(sym_loc);
    sym.* = .{
        .n_strx = try self.strtab.insert(gpa, "___dso_handle"),
        .n_type = macho.N_SECT | macho.N_EXT,
        .n_sect = 0,
        .n_desc = macho.N_WEAK_DEF,
        .n_value = 0,
    };
    global.* = sym_loc;
    _ = self.unresolved.swapRemove(self.getGlobalIndex("___dso_handle").?);
}

fn resolveGlobalSymbol(self: *MachO, current: SymbolWithLoc) !void {
    const gpa = self.base.allocator;
    const sym = self.getSymbol(current);
    const sym_name = self.getSymbolName(current);

    const gop = try self.getOrPutGlobalPtr(sym_name);
    if (!gop.found_existing) {
        gop.value_ptr.* = current;
        if (sym.undf() and !sym.tentative()) {
            try self.unresolved.putNoClobber(gpa, self.getGlobalIndex(sym_name).?, .none);
        }
        return;
    }
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

    if (sym_is_strong and global_is_strong) return error.MultipleSymbolDefinitions;
    if (global_is_strong) return;
    if (sym_is_weak and global_is_weak) return;
    if (sym.tentative() and global_sym.tentative()) {
        if (global_sym.n_value >= sym.n_value) return;
    }
    if (sym.undf() and !sym.tentative()) return;

    _ = self.unresolved.swapRemove(self.getGlobalIndex(sym_name).?);

    gop.value_ptr.* = current;
}

fn resolveSymbolsInDylibs(self: *MachO, actions: *std.ArrayList(ResolveAction)) !void {
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

            const dylib_id = @intCast(u16, id);
            if (!self.referenced_dylibs.contains(dylib_id)) {
                try self.referenced_dylibs.putNoClobber(gpa, dylib_id, {});
            }

            const ordinal = self.referenced_dylibs.getIndex(dylib_id) orelse unreachable;
            sym.n_type |= macho.N_EXT;
            sym.n_desc = @intCast(u16, ordinal + 1) * macho.N_SYMBOL_RESOLVER;

            if (dylib.weak) {
                sym.n_desc |= macho.N_WEAK_REF;
            }

            if (self.unresolved.fetchSwapRemove(global_index)) |entry| blk: {
                if (!sym.undf()) break :blk;
                try actions.append(.{ .kind = entry.value, .target = global });
            }

            continue :loop;
        }

        next_sym += 1;
    }
}

pub fn deinit(self: *MachO) void {
    const gpa = self.base.allocator;

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(gpa);
    }

    if (self.d_sym) |*d_sym| {
        d_sym.deinit();
    }

    self.got_table.deinit(gpa);
    self.stub_table.deinit(gpa);
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

    self.atom_by_index_table.deinit(gpa);

    for (self.relocs.values()) |*relocs| {
        relocs.deinit(gpa);
    }
    self.relocs.deinit(gpa);

    for (self.rebases.values()) |*rebases| {
        rebases.deinit(gpa);
    }
    self.rebases.deinit(gpa);

    for (self.bindings.values()) |*bindings| {
        bindings.deinit(gpa);
    }
    self.bindings.deinit(gpa);
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

fn growAtom(self: *MachO, atom_index: Atom.Index, new_atom_size: u64, alignment: u64) !u64 {
    const atom = self.getAtom(atom_index);
    const sym = atom.getSymbol(self);
    const align_ok = mem.alignBackwardGeneric(u64, sym.n_value, alignment) == sym.n_value;
    const need_realloc = !align_ok or new_atom_size > atom.capacity(self);
    if (!need_realloc) return sym.n_value;
    return self.allocateAtom(atom_index, new_atom_size, alignment);
}

fn allocateSymbol(self: *MachO) !u32 {
    try self.locals.ensureUnusedCapacity(self.base.allocator, 1);

    const index = blk: {
        if (self.locals_free_list.popOrNull()) |index| {
            log.debug("  (reusing symbol index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{self.locals.items.len});
            const index = @intCast(u32, self.locals.items.len);
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
            const index = @intCast(u32, self.globals.items.len);
            _ = self.globals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.globals.items[index] = .{
        .sym_index = 0,
        .file = null,
    };

    return index;
}

fn addGotEntry(self: *MachO, target: SymbolWithLoc) !void {
    if (self.got_table.lookup.contains(target)) return;
    const got_index = try self.got_table.allocateEntry(self.base.allocator, target);
    try self.writeOffsetTableEntry(got_index);
    self.got_table_count_dirty = true;
    self.markRelocsDirtyByTarget(target);
}

fn addStubEntry(self: *MachO, target: SymbolWithLoc) !void {
    if (self.stub_table.lookup.contains(target)) return;
    const stub_index = try self.stub_table.allocateEntry(self.base.allocator, target);
    try self.writeStubTableEntry(stub_index);
    self.stub_table_count_dirty = true;
    self.markRelocsDirtyByTarget(target);
}

pub fn updateFunc(self: *MachO, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(module, func, air, liveness);
    }
    const tracy = trace(@src());
    defer tracy.end();

    const decl_index = func.owner_decl;
    const decl = module.declPtr(decl_index);

    const atom_index = try self.getOrCreateAtomForDecl(decl_index);
    self.freeUnnamedConsts(decl_index);
    Atom.freeRelocations(self, atom_index);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(module, decl_index)
    else
        null;
    defer if (decl_state) |*ds| ds.deinit();

    const res = if (decl_state) |*ds|
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .{
            .dwarf = ds,
        })
    else
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .none);

    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };

    const addr = try self.updateDeclCode(decl_index, code);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            module,
            decl_index,
            addr,
            self.getAtom(atom_index).size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    try self.updateDeclExports(module, decl_index, module.getDeclExports(decl_index));
}

pub fn lowerUnnamedConst(self: *MachO, typed_value: TypedValue, decl_index: Module.Decl.Index) !u32 {
    const gpa = self.base.allocator;

    var code_buffer = std.ArrayList(u8).init(gpa);
    defer code_buffer.deinit();

    const module = self.base.options.module.?;
    const gop = try self.unnamed_const_atoms.getOrPut(gpa, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const unnamed_consts = gop.value_ptr;

    const decl = module.declPtr(decl_index);
    const decl_name = try decl.getFullyQualifiedName(module);
    defer gpa.free(decl_name);

    const name_str_index = blk: {
        const index = unnamed_consts.items.len;
        const name = try std.fmt.allocPrint(gpa, "___unnamed_{s}_{d}", .{ decl_name, index });
        defer gpa.free(name);
        break :blk try self.strtab.insert(gpa, name);
    };
    const name = self.strtab.get(name_str_index).?;

    log.debug("allocating symbol indexes for {s}", .{name});

    const atom_index = try self.createAtom();

    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), typed_value, &code_buffer, .none, .{
        .parent_atom_index = self.getAtom(atom_index).getSymbolIndex().?,
    });
    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            log.err("{s}", .{em.msg});
            return error.CodegenFail;
        },
    };

    const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);
    const atom = self.getAtomPtr(atom_index);
    atom.size = code.len;
    // TODO: work out logic for disambiguating functions from function pointers
    // const sect_id = self.getDeclOutputSection(decl_index);
    const sect_id = self.data_const_section_index.?;
    const symbol = atom.getSymbolPtr(self);
    symbol.n_strx = name_str_index;
    symbol.n_type = macho.N_SECT;
    symbol.n_sect = sect_id + 1;
    symbol.n_value = try self.allocateAtom(atom_index, code.len, required_alignment);
    errdefer self.freeAtom(atom_index);

    try unnamed_consts.append(gpa, atom_index);

    log.debug("allocated atom for {s} at 0x{x}", .{ name, symbol.n_value });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    try self.writeAtom(atom_index, code);

    return atom.getSymbolIndex().?;
}

pub fn updateDecl(self: *MachO, module: *Module, decl_index: Module.Decl.Index) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(module, decl_index);
    }
    const tracy = trace(@src());
    defer tracy.end();

    const decl = module.declPtr(decl_index);

    if (decl.val.tag() == .extern_fn) {
        return; // TODO Should we do more when front-end analyzed extern decl?
    }
    if (decl.val.castTag(.variable)) |payload| {
        const variable = payload.data;
        if (variable.is_extern) {
            return; // TODO Should we do more when front-end analyzed extern decl?
        }
    }

    const is_threadlocal = if (decl.val.castTag(.variable)) |payload|
        payload.data.is_threadlocal and !self.base.options.single_threaded
    else
        false;
    if (is_threadlocal) return self.updateThreadlocalVariable(module, decl_index);

    const atom_index = try self.getOrCreateAtomForDecl(decl_index);
    const sym_index = self.getAtom(atom_index).getSymbolIndex().?;
    Atom.freeRelocations(self, atom_index);

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(module, decl_index)
    else
        null;
    defer if (decl_state) |*ds| ds.deinit();

    const decl_val = if (decl.val.castTag(.variable)) |payload| payload.data.init else decl.val;
    const res = if (decl_state) |*ds|
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .{
            .dwarf = ds,
        }, .{
            .parent_atom_index = sym_index,
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .none, .{
            .parent_atom_index = sym_index,
        });

    var code = switch (res) {
        .ok => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };
    const addr = try self.updateDeclCode(decl_index, code);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            module,
            decl_index,
            addr,
            self.getAtom(atom_index).size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    try self.updateDeclExports(module, decl_index, module.getDeclExports(decl_index));
}

fn updateLazySymbolAtom(
    self: *MachO,
    sym: File.LazySymbol,
    atom_index: Atom.Index,
    section_index: u8,
) !void {
    const gpa = self.base.allocator;
    const mod = self.base.options.module.?;

    var required_alignment: u32 = undefined;
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

    const src = if (sym.ty.getOwnerDeclOrNull()) |owner_decl|
        mod.declPtr(owner_decl).srcLoc()
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
            log.err("{s}", .{em.msg});
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
    const gop = try self.lazy_syms.getOrPut(self.base.allocator, sym.getDecl());
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
        .unused => metadata.atom.* = try self.createAtom(),
        .pending_flush => return metadata.atom.*,
        .flushed => {},
    }
    metadata.state.* = .pending_flush;
    const atom = metadata.atom.*;
    // anyerror needs to be deferred until flushModule
    if (sym.getDecl() != .none) try self.updateLazySymbolAtom(sym, atom, switch (sym.kind) {
        .code => self.text_section_index.?,
        .const_data => self.data_const_section_index.?,
    });
    return atom;
}

fn updateThreadlocalVariable(self: *MachO, module: *Module, decl_index: Module.Decl.Index) !void {
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
    const decl_val = decl.val.castTag(.variable).?.data.init;
    const res = if (decl_state) |*ds|
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .{
            .dwarf = ds,
        }, .{
            .parent_atom_index = init_sym_index,
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
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

    const required_alignment = decl.getAlignment(self.base.options.target);

    const decl_name = try decl.getFullyQualifiedName(module);
    defer gpa.free(decl_name);

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

    try self.updateDeclExports(module, decl_index, module.getDeclExports(decl_index));

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
        gop.value_ptr.* = .{
            .atom = try self.createAtom(),
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
    const zig_ty = ty.zigTypeTag();
    const mode = self.base.options.optimize_mode;
    const single_threaded = self.base.options.single_threaded;
    const sect_id: u8 = blk: {
        // TODO finish and audit this function
        if (val.isUndefDeep()) {
            if (mode == .ReleaseFast or mode == .ReleaseSmall) {
                @panic("TODO __DATA,__bss");
            } else {
                break :blk self.data_section_index.?;
            }
        }

        if (val.castTag(.variable)) |variable| {
            if (variable.data.is_threadlocal and !single_threaded) {
                break :blk self.thread_data_section_index.?;
            }
            break :blk self.data_section_index.?;
        }

        switch (zig_ty) {
            // TODO: what if this is a function pointer?
            .Fn => break :blk self.text_section_index.?,
            else => {
                if (val.castTag(.variable)) |_| {
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

    const required_alignment = decl.getAlignment(self.base.options.target);

    const decl_name = try decl.getFullyQualifiedName(mod);
    defer gpa.free(decl_name);

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
        const need_realloc = code_len > capacity or !mem.isAlignedGeneric(u64, sym.n_value, required_alignment);

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

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) File.UpdateDeclExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object|
            return llvm_object.updateDeclExports(module, decl_index, exports);
    }

    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;

    const decl = module.declPtr(decl_index);
    const atom_index = try self.getOrCreateAtomForDecl(decl_index);
    const atom = self.getAtom(atom_index);
    const decl_sym = atom.getSymbol(self);
    const decl_metadata = self.decls.getPtr(decl_index).?;

    for (exports) |exp| {
        const exp_name = try std.fmt.allocPrint(gpa, "_{s}", .{exp.options.name});
        defer gpa.free(exp_name);

        log.debug("adding new export '{s}'", .{exp_name});

        if (exp.options.section) |section_name| {
            if (!mem.eql(u8, section_name, "__text")) {
                try module.failed_exports.putNoClobber(
                    module.gpa,
                    exp,
                    try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(),
                        "Unimplemented: ExportOptions.section",
                        .{},
                    ),
                );
                continue;
            }
        }

        if (exp.options.linkage == .LinkOnce) {
            try module.failed_exports.putNoClobber(
                module.gpa,
                exp,
                try Module.ErrorMsg.create(
                    gpa,
                    decl.srcLoc(),
                    "Unimplemented: GlobalLinkage.LinkOnce",
                    .{},
                ),
            );
            continue;
        }

        const sym_index = decl_metadata.getExport(self, exp_name) orelse blk: {
            const sym_index = try self.allocateSymbol();
            try decl_metadata.exports.append(gpa, sym_index);
            break :blk sym_index;
        };
        const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
        const sym = self.getSymbolPtr(sym_loc);
        sym.* = .{
            .n_strx = try self.strtab.insert(gpa, exp_name),
            .n_type = macho.N_SECT | macho.N_EXT,
            .n_sect = self.text_section_index.? + 1, // TODO what if we export a variable?
            .n_desc = 0,
            .n_value = decl_sym.n_value,
        };

        switch (exp.options.linkage) {
            .Internal => {
                // Symbol should be hidden, or in MachO lingo, private extern.
                // We should also mark the symbol as Weak: n_desc == N_WEAK_DEF.
                sym.n_type |= macho.N_PEXT;
                sym.n_desc |= macho.N_WEAK_DEF;
            },
            .Strong => {},
            .Weak => {
                // Weak linkage is specified as part of n_desc field.
                // Symbol's n_type is like for a symbol with strong linkage.
                sym.n_desc |= macho.N_WEAK_DEF;
            },
            else => unreachable,
        }

        self.resolveGlobalSymbol(sym_loc) catch |err| switch (err) {
            error.MultipleSymbolDefinitions => {
                // TODO: this needs rethinking
                const global = self.getGlobal(exp_name).?;
                if (sym_loc.sym_index != global.sym_index and global.file != null) {
                    _ = try module.failed_exports.put(module.gpa, exp, try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(),
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

pub fn deleteDeclExport(self: *MachO, decl_index: Module.Decl.Index, name: []const u8) Allocator.Error!void {
    if (self.llvm_object) |_| return;
    const metadata = self.decls.getPtr(decl_index) orelse return;

    const gpa = self.base.allocator;
    const exp_name = try std.fmt.allocPrint(gpa, "_{s}", .{name});
    defer gpa.free(exp_name);
    const sym_index = metadata.getExportPtr(self, exp_name) orelse return;

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index.*, .file = null };
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
        self.globals.items[entry.value] = .{
            .sym_index = 0,
            .file = null,
        };
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
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    }
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
    const atom_index = self.getAtomIndexForSymbol(.{ .sym_index = reloc_info.parent_atom_index, .file = null }).?;
    try Atom.addRelocation(self, atom_index, .{
        .type = .unsigned,
        .target = .{ .sym_index = sym_index, .file = null },
        .offset = @intCast(u32, reloc_info.offset),
        .addend = reloc_info.addend,
        .pcrel = false,
        .length = 3,
    });
    try Atom.addRebase(self, atom_index, @intCast(u32, reloc_info.offset));

    return 0;
}

fn populateMissingMetadata(self: *MachO) !void {
    assert(self.mode == .incremental);

    const gpa = self.base.allocator;
    const cpu_arch = self.base.options.target.cpu.arch;
    const pagezero_vmsize = self.calcPagezeroSize();

    if (self.pagezero_segment_cmd_index == null) {
        if (pagezero_vmsize > 0) {
            self.pagezero_segment_cmd_index = @intCast(u8, self.segments.items.len);
            try self.segments.append(gpa, .{
                .segname = makeStaticString("__PAGEZERO"),
                .vmsize = pagezero_vmsize,
                .cmdsize = @sizeOf(macho.segment_command_64),
            });
        }
    }

    if (self.header_segment_cmd_index == null) {
        // The first __TEXT segment is immovable and covers MachO header and load commands.
        self.header_segment_cmd_index = @intCast(u8, self.segments.items.len);
        const ideal_size = @max(self.base.options.headerpad_size orelse 0, default_headerpad_size);
        const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);

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
        const stub_size = stubs.calcStubEntrySize(cpu_arch);
        self.stubs_section_index = try self.allocateSection("__TEXT2", "__stubs", .{
            .size = stub_size,
            .alignment = switch (cpu_arch) {
                .x86_64 => 1,
                .aarch64 => @sizeOf(u32),
                else => unreachable, // unhandled architecture type
            },
            .flags = macho.S_SYMBOL_STUBS | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved2 = stub_size,
            .prot = macho.PROT.READ | macho.PROT.EXEC,
        });
        self.segment_table_dirty = true;
    }

    if (self.stub_helper_section_index == null) {
        self.stub_helper_section_index = try self.allocateSection("__TEXT3", "__stub_helper", .{
            .size = @sizeOf(u32),
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
        self.linkedit_segment_cmd_index = @intCast(u8, self.segments.items.len);

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
    const aligned_pagezero_vmsize = mem.alignBackwardGeneric(u64, pagezero_vmsize, self.page_size);
    if (self.base.options.output_mode == .Lib) return 0;
    if (aligned_pagezero_vmsize == 0) return 0;
    if (aligned_pagezero_vmsize != pagezero_vmsize) {
        log.warn("requested __PAGEZERO size (0x{x}) is not page aligned", .{pagezero_vmsize});
        log.warn("  rounding down to 0x{x}", .{aligned_pagezero_vmsize});
    }
    return aligned_pagezero_vmsize;
}

fn allocateSection(self: *MachO, segname: []const u8, sectname: []const u8, opts: struct {
    size: u64 = 0,
    alignment: u32 = 0,
    prot: macho.vm_prot_t = macho.PROT.NONE,
    flags: u32 = macho.S_REGULAR,
    reserved2: u32 = 0,
}) !u8 {
    const gpa = self.base.allocator;
    // In incremental context, we create one section per segment pairing. This way,
    // we can move the segment in raw file as we please.
    const segment_id = @intCast(u8, self.segments.items.len);
    const section_id = @intCast(u8, self.sections.slice().len);
    const vmaddr = blk: {
        const prev_segment = self.segments.items[segment_id - 1];
        break :blk mem.alignForwardGeneric(u64, prev_segment.vmaddr + prev_segment.vmsize, self.page_size);
    };
    // We commit more memory than needed upfront so that we don't have to reallocate too soon.
    const vmsize = mem.alignForwardGeneric(u64, opts.size, self.page_size);
    const off = self.findFreeSpace(opts.size, self.page_size);

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

    var section = macho.section_64{
        .sectname = makeStaticString(sectname),
        .segname = makeStaticString(segname),
        .addr = mem.alignForwardGeneric(u64, vmaddr, opts.alignment),
        .offset = mem.alignForwardGeneric(u32, @intCast(u32, off), opts.alignment),
        .size = opts.size,
        .@"align" = math.log2(opts.alignment),
        .flags = opts.flags,
        .reserved2 = opts.reserved2,
    };
    assert(!section.isZerofill()); // TODO zerofill sections

    try self.sections.append(gpa, .{
        .segment_index = segment_id,
        .header = section,
    });
    return section_id;
}

fn growSection(self: *MachO, sect_id: u8, needed_size: u64) !void {
    const header = &self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const segment = &self.segments.items[segment_index];
    const maybe_last_atom_index = self.sections.items(.last_atom_index)[sect_id];
    const sect_capacity = self.allocatedSize(header.offset);

    if (needed_size > sect_capacity) {
        const new_offset = self.findFreeSpace(needed_size, self.page_size);
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
        header.offset = @intCast(u32, new_offset);
        segment.fileoff = new_offset;
    }

    const sect_vm_capacity = self.allocatedVirtualSize(segment.vmaddr);
    if (needed_size > sect_vm_capacity) {
        self.markRelocsDirtyByAddress(segment.vmaddr + segment.vmsize);
        try self.growSectionVirtualMemory(sect_id, needed_size);
    }

    header.size = needed_size;
    segment.filesize = mem.alignForwardGeneric(u64, needed_size, self.page_size);
    segment.vmsize = mem.alignForwardGeneric(u64, needed_size, self.page_size);
}

fn growSectionVirtualMemory(self: *MachO, sect_id: u8, needed_size: u64) !void {
    const header = &self.sections.items(.header)[sect_id];
    const segment = self.getSegmentPtr(sect_id);
    const increased_size = padToIdeal(needed_size);
    const old_aligned_end = segment.vmaddr + segment.vmsize;
    const new_aligned_end = segment.vmaddr + mem.alignForwardGeneric(u64, increased_size, self.page_size);
    const diff = new_aligned_end - old_aligned_end;
    log.debug("shifting every segment after {s},{s} in virtual memory by {x}", .{
        header.segName(),
        header.sectName(),
        diff,
    });

    // TODO: enforce order by increasing VM addresses in self.sections container.
    for (self.sections.items(.header)[sect_id + 1 ..], 0..) |*next_header, next_sect_id| {
        const index = @intCast(u8, sect_id + 1 + next_sect_id);
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

fn allocateAtom(self: *MachO, atom_index: Atom.Index, new_atom_size: u64, alignment: u64) !u64 {
    const tracy = trace(@src());
    defer tracy.end();

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
            const new_start_vaddr = mem.alignBackwardGeneric(u64, new_start_vaddr_unaligned, alignment);
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
            const new_start_vaddr = mem.alignForwardGeneric(u64, ideal_capacity_end_vaddr, alignment);
            atom_placement = last_index;
            break :blk new_start_vaddr;
        } else {
            break :blk mem.alignForwardGeneric(u64, segment.vmaddr, alignment);
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

    const align_pow = @intCast(u32, math.log2(alignment));
    if (header.@"align" < align_pow) {
        header.@"align" = align_pow;
    }
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
    return self.addUndefined(sym_name, .add_stub);
}

fn writeSegmentHeaders(self: *MachO, writer: anytype) !void {
    for (self.segments.items, 0..) |seg, i| {
        const indexes = self.getSectionIndexes(@intCast(u8, i));
        try writer.writeStruct(seg);
        for (self.sections.items(.header)[indexes.start..indexes.end]) |header| {
            try writer.writeStruct(header);
        }
    }
}

fn writeLinkeditSegmentData(self: *MachO) !void {
    const seg = self.getLinkeditSegmentPtr();
    seg.filesize = 0;
    seg.vmsize = 0;

    for (self.segments.items, 0..) |segment, id| {
        if (self.linkedit_segment_cmd_index.? == @intCast(u8, id)) continue;
        if (seg.vmaddr < segment.vmaddr + segment.vmsize) {
            seg.vmaddr = mem.alignForwardGeneric(u64, segment.vmaddr + segment.vmsize, self.page_size);
        }
        if (seg.fileoff < segment.fileoff + segment.filesize) {
            seg.fileoff = mem.alignForwardGeneric(u64, segment.fileoff + segment.filesize, self.page_size);
        }
    }

    try self.writeDyldInfoData();
    try self.writeSymtabs();

    seg.vmsize = mem.alignForwardGeneric(u64, seg.filesize, self.page_size);
}

fn collectRebaseDataFromTableSection(self: *MachO, sect_id: u8, rebase: *Rebase, table: anytype) !void {
    const header = self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const segment = self.segments.items[segment_index];
    const base_offset = header.addr - segment.vmaddr;
    const is_got = if (self.got_section_index) |index| index == sect_id else false;

    try rebase.entries.ensureUnusedCapacity(self.base.allocator, table.entries.items.len);

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

    try self.collectRebaseDataFromTableSection(self.got_section_index.?, rebase, self.got_table);
    try self.collectRebaseDataFromTableSection(self.la_symbol_ptr_section_index.?, rebase, self.stub_table);

    try rebase.finalize(gpa);
}

fn collectBindDataFromTableSection(self: *MachO, sect_id: u8, bind: anytype, table: anytype) !void {
    const header = self.sections.items(.header)[sect_id];
    const segment_index = self.sections.items(.segment_index)[sect_id];
    const segment = self.segments.items[segment_index];
    const base_offset = header.addr - segment.vmaddr;

    try bind.entries.ensureUnusedCapacity(self.base.allocator, table.entries.items.len);

    for (table.entries.items, 0..) |entry, i| {
        if (!table.lookup.contains(entry)) continue;
        const bind_sym = self.getSymbol(entry);
        if (!bind_sym.undf()) continue;
        const offset = i * @sizeOf(u64);
        log.debug("    | bind at {x}, import('{s}') in dylib({d})", .{
            base_offset + offset,
            self.getSymbolName(entry),
            @divTrunc(@bitCast(i16, bind_sym.n_desc), macho.N_SYMBOL_RESOLVER),
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
                @bitCast(i16, bind_sym.n_desc),
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

    // Gather GOT pointers
    try self.collectBindDataFromTableSection(self.got_section_index.?, bind, self.got_table);
    try bind.finalize(gpa, self);
}

fn collectLazyBindData(self: *MachO, bind: anytype) !void {
    try self.collectBindDataFromTableSection(self.la_symbol_ptr_section_index.?, bind, self.stub_table);
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
        if (!sym.ext()) continue;

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
    try self.collectExportData(&trie);

    const link_seg = self.getLinkeditSegmentPtr();
    assert(mem.isAlignedGeneric(u64, link_seg.fileoff, @alignOf(u64)));
    const rebase_off = link_seg.fileoff;
    const rebase_size = rebase.size();
    const rebase_size_aligned = mem.alignForwardGeneric(u64, rebase_size, @alignOf(u64));
    log.debug("writing rebase info from 0x{x} to 0x{x}", .{ rebase_off, rebase_off + rebase_size_aligned });

    const bind_off = rebase_off + rebase_size_aligned;
    const bind_size = bind.size();
    const bind_size_aligned = mem.alignForwardGeneric(u64, bind_size, @alignOf(u64));
    log.debug("writing bind info from 0x{x} to 0x{x}", .{ bind_off, bind_off + bind_size_aligned });

    const lazy_bind_off = bind_off + bind_size_aligned;
    const lazy_bind_size = lazy_bind.size();
    const lazy_bind_size_aligned = mem.alignForwardGeneric(u64, lazy_bind_size, @alignOf(u64));
    log.debug("writing lazy bind info from 0x{x} to 0x{x}", .{
        lazy_bind_off,
        lazy_bind_off + lazy_bind_size_aligned,
    });

    const export_off = lazy_bind_off + lazy_bind_size_aligned;
    const export_size = trie.size;
    const export_size_aligned = mem.alignForwardGeneric(u64, export_size, @alignOf(u64));
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

    self.dyld_info_cmd.rebase_off = @intCast(u32, rebase_off);
    self.dyld_info_cmd.rebase_size = @intCast(u32, rebase_size_aligned);
    self.dyld_info_cmd.bind_off = @intCast(u32, bind_off);
    self.dyld_info_cmd.bind_size = @intCast(u32, bind_size_aligned);
    self.dyld_info_cmd.lazy_bind_off = @intCast(u32, lazy_bind_off);
    self.dyld_info_cmd.lazy_bind_size = @intCast(u32, lazy_bind_size_aligned);
    self.dyld_info_cmd.export_off = @intCast(u32, export_off);
    self.dyld_info_cmd.export_size = @intCast(u32, export_size_aligned);
}

fn populateLazyBindOffsetsInStubHelper(self: *MachO, lazy_bind: LazyBind) !void {
    if (lazy_bind.size() == 0) return;

    const stub_helper_section_index = self.stub_helper_section_index.?;
    assert(self.stub_helper_preamble_allocated);

    const header = self.sections.items(.header)[stub_helper_section_index];

    const cpu_arch = self.base.options.target.cpu.arch;
    const preamble_size = stubs.calcStubHelperPreambleSize(cpu_arch);
    const stub_size = stubs.calcStubHelperEntrySize(cpu_arch);
    const stub_offset = stubs.calcStubOffsetInStubHelper(cpu_arch);
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

fn writeSymtabs(self: *MachO) !void {
    var ctx = try self.writeSymtab();
    defer ctx.imports_table.deinit();
    try self.writeDysymtab(ctx);
    try self.writeStrtab();
}

fn writeSymtab(self: *MachO) !SymtabCtx {
    const gpa = self.base.allocator;

    var locals = std.ArrayList(macho.nlist_64).init(gpa);
    defer locals.deinit();

    for (self.locals.items, 0..) |sym, sym_id| {
        if (sym.n_strx == 0) continue; // no name, skip
        const sym_loc = SymbolWithLoc{ .sym_index = @intCast(u32, sym_id), .file = null };
        if (self.symbolIsTemp(sym_loc)) continue; // local temp symbol, skip
        if (self.getGlobal(self.getSymbolName(sym_loc)) != null) continue; // global symbol is either an export or import, skip
        try locals.append(sym);
    }

    var exports = std.ArrayList(macho.nlist_64).init(gpa);
    defer exports.deinit();

    for (self.globals.items) |global| {
        const sym = self.getSymbol(global);
        if (sym.undf()) continue; // import, skip
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
        const new_index = @intCast(u32, imports.items.len);
        var out_sym = sym;
        out_sym.n_strx = try self.strtab.insert(gpa, self.getSymbolName(global));
        try imports.append(out_sym);
        try imports_table.putNoClobber(global, new_index);
    }

    const nlocals = @intCast(u32, locals.items.len);
    const nexports = @intCast(u32, exports.items.len);
    const nimports = @intCast(u32, imports.items.len);
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

    self.symtab_cmd.symoff = @intCast(u32, offset);
    self.symtab_cmd.nsyms = nsyms;

    return SymtabCtx{
        .nlocalsym = nlocals,
        .nextdefsym = nexports,
        .nundefsym = nimports,
        .imports_table = imports_table,
    };
}

fn writeStrtab(self: *MachO) !void {
    const gpa = self.base.allocator;
    const seg = self.getLinkeditSegmentPtr();
    const offset = seg.fileoff + seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = self.strtab.buffer.items.len;
    const needed_size_aligned = mem.alignForwardGeneric(u64, needed_size, @alignOf(u64));
    seg.filesize = offset + needed_size_aligned - seg.fileoff;

    log.debug("writing string table from 0x{x} to 0x{x}", .{ offset, offset + needed_size_aligned });

    const buffer = try gpa.alloc(u8, math.cast(usize, needed_size_aligned) orelse return error.Overflow);
    defer gpa.free(buffer);
    @memcpy(buffer[0..self.strtab.buffer.items.len], self.strtab.buffer.items);
    @memset(buffer[self.strtab.buffer.items.len..], 0);

    try self.base.file.?.pwriteAll(buffer, offset);

    self.symtab_cmd.stroff = @intCast(u32, offset);
    self.symtab_cmd.strsize = @intCast(u32, needed_size_aligned);
}

const SymtabCtx = struct {
    nlocalsym: u32,
    nextdefsym: u32,
    nundefsym: u32,
    imports_table: std.AutoHashMap(SymbolWithLoc, u32),
};

fn writeDysymtab(self: *MachO, ctx: SymtabCtx) !void {
    const gpa = self.base.allocator;
    const nstubs = @intCast(u32, self.stub_table.lookup.count());
    const ngot_entries = @intCast(u32, self.got_table.lookup.count());
    const nindirectsyms = nstubs * 2 + ngot_entries;
    const iextdefsym = ctx.nlocalsym;
    const iundefsym = iextdefsym + ctx.nextdefsym;

    const seg = self.getLinkeditSegmentPtr();
    const offset = seg.fileoff + seg.filesize;
    assert(mem.isAlignedGeneric(u64, offset, @alignOf(u64)));
    const needed_size = nindirectsyms * @sizeOf(u32);
    const needed_size_aligned = mem.alignForwardGeneric(u64, needed_size, @alignOf(u64));
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
            try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry).?);
        }
    }

    if (self.got_section_index) |sect_id| {
        const got = &self.sections.items(.header)[sect_id];
        got.reserved1 = nstubs;
        for (self.got_table.entries.items) |entry| {
            if (!self.got_table.lookup.contains(entry)) continue;
            const target_sym = self.getSymbol(entry);
            if (target_sym.undf()) {
                try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry).?);
            } else {
                try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL);
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
            try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry).?);
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
    self.dysymtab_cmd.indirectsymoff = @intCast(u32, offset);
    self.dysymtab_cmd.nindirectsyms = nindirectsyms;
}

fn writeCodeSignaturePadding(self: *MachO, code_sig: *CodeSignature) !void {
    const seg = self.getLinkeditSegmentPtr();
    // Code signature data has to be 16-bytes aligned for Apple tools to recognize the file
    // https://github.com/opensource-apple/cctools/blob/fdb4825f303fd5c0751be524babd32958181b3ed/libstuff/checkout.c#L271
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, 16);
    const needed_size = code_sig.estimateSize(offset);
    seg.filesize = offset + needed_size - seg.fileoff;
    seg.vmsize = mem.alignForwardGeneric(u64, seg.filesize, self.page_size);
    log.debug("writing code signature padding from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    // Pad out the space. We need to do this to calculate valid hashes for everything in the file
    // except for code signature data.
    try self.base.file.?.pwriteAll(&[_]u8{0}, offset + needed_size - 1);

    self.codesig_cmd.dataoff = @intCast(u32, offset);
    self.codesig_cmd.datasize = @intCast(u32, needed_size);
}

fn writeCodeSignature(self: *MachO, comp: *const Compilation, code_sig: *CodeSignature) !void {
    const seg = self.getSegment(self.text_section_index.?);
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
fn writeHeader(self: *MachO, ncmds: u32, sizeofcmds: u32) !void {
    var header: macho.mach_header_64 = .{};
    header.flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK | macho.MH_PIE | macho.MH_TWOLEVEL;

    if (!self.base.options.single_threaded) {
        header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;
    }

    switch (self.base.options.target.cpu.arch) {
        .aarch64 => {
            header.cputype = macho.CPU_TYPE_ARM64;
            header.cpusubtype = macho.CPU_SUBTYPE_ARM_ALL;
        },
        .x86_64 => {
            header.cputype = macho.CPU_TYPE_X86_64;
            header.cpusubtype = macho.CPU_SUBTYPE_X86_64_ALL;
        },
        else => return error.UnsupportedCpuArchitecture,
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
        start = mem.alignForwardGeneric(u64, item_end, min_alignment);
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

fn addUndefined(self: *MachO, name: []const u8, action: ResolveAction.Kind) !u32 {
    const gpa = self.base.allocator;

    const gop = try self.getOrPutGlobalPtr(name);
    const global_index = self.getGlobalIndex(name).?;

    if (gop.found_existing) {
        return global_index;
    }

    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index };
    gop.value_ptr.* = sym_loc;

    const sym = self.getSymbolPtr(sym_loc);
    sym.n_strx = try self.strtab.insert(gpa, name);
    sym.n_type = macho.N_UNDF;

    try self.unresolved.putNoClobber(gpa, global_index, action);

    return global_index;
}

pub fn makeStaticString(bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    @memcpy(buf[0..bytes.len], bytes);
    return buf;
}

fn getSegmentByName(self: MachO, segname: []const u8) ?u8 {
    for (self.segments.items, 0..) |seg, i| {
        if (mem.eql(u8, segname, seg.segName())) return @intCast(u8, i);
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
            return @intCast(u8, i);
    } else return null;
}

pub fn getSectionIndexes(self: MachO, segment_index: u8) struct { start: u8, end: u8 } {
    var start: u8 = 0;
    const nsects = for (self.segments.items, 0..) |seg, i| {
        if (i == segment_index) break @intCast(u8, seg.nsects);
        start += @intCast(u8, seg.nsects);
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
    assert(sym_with_loc.file == null);
    return &self.locals.items[sym_with_loc.sym_index];
}

/// Returns symbol described by `sym_with_loc` descriptor.
pub fn getSymbol(self: *const MachO, sym_with_loc: SymbolWithLoc) macho.nlist_64 {
    assert(sym_with_loc.file == null);
    return self.locals.items[sym_with_loc.sym_index];
}

/// Returns name of the symbol described by `sym_with_loc` descriptor.
pub fn getSymbolName(self: *const MachO, sym_with_loc: SymbolWithLoc) []const u8 {
    const sym = self.getSymbol(sym_with_loc);
    return self.strtab.get(sym.n_strx).?;
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
    assert(sym_with_loc.file == null);
    return self.atom_by_index_table.get(sym_with_loc.sym_index);
}

/// Returns symbol location corresponding to the set entrypoint.
/// Asserts output mode is executable.
pub fn getEntryPoint(self: MachO) error{MissingMainEntrypoint}!SymbolWithLoc {
    const entry_name = self.base.options.entry orelse load_commands.default_entry_point;
    const global = self.getGlobal(entry_name) orelse {
        log.err("entrypoint '{s}' not found", .{entry_name});
        return error.MissingMainEntrypoint;
    };
    return global;
}

pub fn getDebugSymbols(self: *MachO) ?*DebugSymbols {
    if (self.d_sym == null) return null;
    return &self.d_sym.?;
}

pub fn findFirst(comptime T: type, haystack: []align(1) const T, start: usize, predicate: anytype) usize {
    if (!@hasDecl(@TypeOf(predicate), "predicate"))
        @compileError("Predicate is required to define fn predicate(@This(), T) bool");

    if (start == haystack.len) return start;

    var i = start;
    while (i < haystack.len) : (i += 1) {
        if (predicate.predicate(haystack[i])) break;
    }
    return i;
}

// fn snapshotState(self: *MachO) !void {
//     const emit = self.base.options.emit orelse {
//         log.debug("no emit directory found; skipping snapshot...", .{});
//         return;
//     };

//     const Snapshot = struct {
//         const Node = struct {
//             const Tag = enum {
//                 section_start,
//                 section_end,
//                 atom_start,
//                 atom_end,
//                 relocation,

//                 pub fn jsonStringify(
//                     tag: Tag,
//                     options: std.json.StringifyOptions,
//                     out_stream: anytype,
//                 ) !void {
//                     _ = options;
//                     switch (tag) {
//                         .section_start => try out_stream.writeAll("\"section_start\""),
//                         .section_end => try out_stream.writeAll("\"section_end\""),
//                         .atom_start => try out_stream.writeAll("\"atom_start\""),
//                         .atom_end => try out_stream.writeAll("\"atom_end\""),
//                         .relocation => try out_stream.writeAll("\"relocation\""),
//                     }
//                 }
//             };
//             const Payload = struct {
//                 name: []const u8 = "",
//                 aliases: [][]const u8 = &[0][]const u8{},
//                 is_global: bool = false,
//                 target: u64 = 0,
//             };
//             address: u64,
//             tag: Tag,
//             payload: Payload,
//         };
//         timestamp: i128,
//         nodes: []Node,
//     };

//     var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
//     defer arena_allocator.deinit();
//     const arena = arena_allocator.allocator();

//     const out_file = try emit.directory.handle.createFile("snapshots.json", .{
//         .truncate = false,
//         .read = true,
//     });
//     defer out_file.close();

//     if (out_file.seekFromEnd(-1)) {
//         try out_file.writer().writeByte(',');
//     } else |err| switch (err) {
//         error.Unseekable => try out_file.writer().writeByte('['),
//         else => |e| return e,
//     }
//     const writer = out_file.writer();

//     var snapshot = Snapshot{
//         .timestamp = std.time.nanoTimestamp(),
//         .nodes = undefined,
//     };
//     var nodes = std.ArrayList(Snapshot.Node).init(arena);

//     for (self.section_ordinals.keys()) |key| {
//         const sect = self.getSection(key);
//         const sect_name = try std.fmt.allocPrint(arena, "{s},{s}", .{ sect.segName(), sect.sectName() });
//         try nodes.append(.{
//             .address = sect.addr,
//             .tag = .section_start,
//             .payload = .{ .name = sect_name },
//         });

//         const is_tlv = sect.type_() == macho.S_THREAD_LOCAL_VARIABLES;

//         var atom: *Atom = self.atoms.get(key) orelse {
//             try nodes.append(.{
//                 .address = sect.addr + sect.size,
//                 .tag = .section_end,
//                 .payload = .{},
//             });
//             continue;
//         };

//         while (atom.prev) |prev| {
//             atom = prev;
//         }

//         while (true) {
//             const atom_sym = atom.getSymbol(self);
//             var node = Snapshot.Node{
//                 .address = atom_sym.n_value,
//                 .tag = .atom_start,
//                 .payload = .{
//                     .name = atom.getName(self),
//                     .is_global = self.globals.contains(atom.getName(self)),
//                 },
//             };

//             var aliases = std.ArrayList([]const u8).init(arena);
//             for (atom.contained.items) |sym_off| {
//                 if (sym_off.offset == 0) {
//                     try aliases.append(self.getSymbolName(.{
//                         .sym_index = sym_off.sym_index,
//                         .file = atom.file,
//                     }));
//                 }
//             }
//             node.payload.aliases = aliases.toOwnedSlice();
//             try nodes.append(node);

//             var relocs = try std.ArrayList(Snapshot.Node).initCapacity(arena, atom.relocs.items.len);
//             for (atom.relocs.items) |rel| {
//                 const source_addr = blk: {
//                     const source_sym = atom.getSymbol(self);
//                     break :blk source_sym.n_value + rel.offset;
//                 };
//                 const target_addr = blk: {
//                     const target_atom = rel.getTargetAtom(self) orelse {
//                         // If there is no atom for target, we still need to check for special, atom-less
//                         // symbols such as `___dso_handle`.
//                         const target_name = self.getSymbolName(rel.target);
//                         if (self.globals.contains(target_name)) {
//                             const atomless_sym = self.getSymbol(rel.target);
//                             break :blk atomless_sym.n_value;
//                         }
//                         break :blk 0;
//                     };
//                     const target_sym = if (target_atom.isSymbolContained(rel.target, self))
//                         self.getSymbol(rel.target)
//                     else
//                         target_atom.getSymbol(self);
//                     const base_address: u64 = if (is_tlv) base_address: {
//                         const sect_id: u16 = sect_id: {
//                             if (self.tlv_data_section_index) |i| {
//                                 break :sect_id i;
//                             } else if (self.tlv_bss_section_index) |i| {
//                                 break :sect_id i;
//                             } else unreachable;
//                         };
//                         break :base_address self.getSection(.{
//                             .seg = self.data_segment_cmd_index.?,
//                             .sect = sect_id,
//                         }).addr;
//                     } else 0;
//                     break :blk target_sym.n_value - base_address;
//                 };

//                 relocs.appendAssumeCapacity(.{
//                     .address = source_addr,
//                     .tag = .relocation,
//                     .payload = .{ .target = target_addr },
//                 });
//             }

//             if (atom.contained.items.len == 0) {
//                 try nodes.appendSlice(relocs.items);
//             } else {
//                 // Need to reverse iteration order of relocs since by default for relocatable sources
//                 // they come in reverse. For linking, this doesn't matter in any way, however, for
//                 // arranging the memoryline for displaying it does.
//                 std.mem.reverse(Snapshot.Node, relocs.items);

//                 var next_i: usize = 0;
//                 var last_rel: usize = 0;
//                 while (next_i < atom.contained.items.len) : (next_i += 1) {
//                     const loc = SymbolWithLoc{
//                         .sym_index = atom.contained.items[next_i].sym_index,
//                         .file = atom.file,
//                     };
//                     const cont_sym = self.getSymbol(loc);
//                     const cont_sym_name = self.getSymbolName(loc);
//                     var contained_node = Snapshot.Node{
//                         .address = cont_sym.n_value,
//                         .tag = .atom_start,
//                         .payload = .{
//                             .name = cont_sym_name,
//                             .is_global = self.globals.contains(cont_sym_name),
//                         },
//                     };

//                     // Accumulate aliases
//                     var inner_aliases = std.ArrayList([]const u8).init(arena);
//                     while (true) {
//                         if (next_i + 1 >= atom.contained.items.len) break;
//                         const next_sym_loc = SymbolWithLoc{
//                             .sym_index = atom.contained.items[next_i + 1].sym_index,
//                             .file = atom.file,
//                         };
//                         const next_sym = self.getSymbol(next_sym_loc);
//                         if (next_sym.n_value != cont_sym.n_value) break;
//                         const next_sym_name = self.getSymbolName(next_sym_loc);
//                         if (self.globals.contains(next_sym_name)) {
//                             try inner_aliases.append(contained_node.payload.name);
//                             contained_node.payload.name = next_sym_name;
//                             contained_node.payload.is_global = true;
//                         } else try inner_aliases.append(next_sym_name);
//                         next_i += 1;
//                     }

//                     const cont_size = if (next_i + 1 < atom.contained.items.len)
//                         self.getSymbol(.{
//                             .sym_index = atom.contained.items[next_i + 1].sym_index,
//                             .file = atom.file,
//                         }).n_value - cont_sym.n_value
//                     else
//                         atom_sym.n_value + atom.size - cont_sym.n_value;

//                     contained_node.payload.aliases = inner_aliases.toOwnedSlice();
//                     try nodes.append(contained_node);

//                     for (relocs.items[last_rel..]) |rel| {
//                         if (rel.address >= cont_sym.n_value + cont_size) {
//                             break;
//                         }
//                         try nodes.append(rel);
//                         last_rel += 1;
//                     }

//                     try nodes.append(.{
//                         .address = cont_sym.n_value + cont_size,
//                         .tag = .atom_end,
//                         .payload = .{},
//                     });
//                 }
//             }

//             try nodes.append(.{
//                 .address = atom_sym.n_value + atom.size,
//                 .tag = .atom_end,
//                 .payload = .{},
//             });

//             if (atom.next) |next| {
//                 atom = next;
//             } else break;
//         }

//         try nodes.append(.{
//             .address = sect.addr + sect.size,
//             .tag = .section_end,
//             .payload = .{},
//         });
//     }

//     snapshot.nodes = nodes.toOwnedSlice();

//     try std.json.stringify(snapshot, .{}, writer);
//     try writer.writeByte(']');
// }

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

fn logSymAttributes(sym: macho.nlist_64, buf: *[4]u8) []const u8 {
    @memset(buf[0..4], '_');
    @memset(buf[4..], ' ');
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

    log.debug("symtab:", .{});
    for (self.locals.items, 0..) |sym, sym_id| {
        const where = if (sym.undf() and !sym.tentative()) "ord" else "sect";
        const def_index = if (sym.undf() and !sym.tentative())
            @divTrunc(sym.n_desc, macho.N_SYMBOL_RESOLVER)
        else
            sym.n_sect + 1;
        log.debug("    %{d}: {?s} @{x} in {s}({d}), {s}", .{
            sym_id,
            self.strtab.get(sym.n_strx),
            sym.n_value,
            where,
            def_index,
            logSymAttributes(sym, &buf),
        });
    }

    log.debug("globals table:", .{});
    for (self.globals.items) |global| {
        const name = self.getSymbolName(global);
        log.debug("  {s} => %{d} in object({?d})", .{ name, global.sym_index, global.file });
    }

    log.debug("GOT entries:", .{});
    log.debug("{}", .{self.got_table});

    log.debug("stubs entries:", .{});
    log.debug("{}", .{self.stub_table});
}

pub fn logAtoms(self: *MachO) void {
    log.debug("atoms:", .{});

    const slice = self.sections.slice();
    for (slice.items(.last_atom_index), 0..) |last_atom_index, i| {
        var atom_index = last_atom_index orelse continue;
        const header = slice.items(.header)[i];

        while (true) {
            const atom = self.getAtom(atom_index);
            if (atom.prev_index) |prev_index| {
                atom_index = prev_index;
            } else break;
        }

        log.debug("{s},{s}", .{ header.segName(), header.sectName() });

        while (true) {
            self.logAtom(atom_index);
            const atom = self.getAtom(atom_index);
            if (atom.next_index) |next_index| {
                atom_index = next_index;
            } else break;
        }
    }
}

pub fn logAtom(self: *MachO, atom_index: Atom.Index) void {
    const atom = self.getAtom(atom_index);
    const sym = atom.getSymbol(self);
    const sym_name = atom.getName(self);
    log.debug("  ATOM(%{?d}, '{s}') @ {x} sizeof({x}) in object({?d}) in sect({d})", .{
        atom.getSymbolIndex(),
        sym_name,
        sym.n_value,
        atom.size,
        atom.file,
        sym.n_sect + 1,
    });
}
