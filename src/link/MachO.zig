const MachO = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const fmt = std.fmt;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const aarch64 = @import("../arch/aarch64/bits.zig");
const bind = @import("MachO/bind.zig");
const codegen = @import("../codegen.zig");
const dead_strip = @import("MachO/dead_strip.zig");
const fat = @import("MachO/fat.zig");
const link = @import("../link.zig");
const llvm_backend = @import("../codegen/llvm.zig");
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;
const zld = @import("MachO/zld.zig");

const Air = @import("../Air.zig");
const Allocator = mem.Allocator;
const Archive = @import("MachO/Archive.zig");
pub const Atom = @import("MachO/Atom.zig");
const Cache = @import("../Cache.zig");
const CodeSignature = @import("MachO/CodeSignature.zig");
const Compilation = @import("../Compilation.zig");
const Dwarf = File.Dwarf;
const Dylib = @import("MachO/Dylib.zig");
const File = link.File;
const Object = @import("MachO/Object.zig");
const LibStub = @import("tapi.zig").LibStub;
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Module = @import("../Module.zig");
const Relocation = @import("MachO/Relocation.zig");
const RelocationTable = Relocation.Table;
const StringTable = @import("strtab.zig").StringTable;
const Trie = @import("MachO/Trie.zig");
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const Value = @import("../value.zig").Value;

pub const DebugSymbols = @import("MachO/DebugSymbols.zig");

pub const base_tag: File.Tag = File.Tag.macho;

pub const SearchStrategy = enum {
    paths_first,
    dylibs_first,
};

pub const N_DESC_GCED: u16 = @bitCast(u16, @as(i16, -1));

const Section = struct {
    header: macho.section_64,
    segment_index: u8,

    // TODO is null here necessary, or can we do away with tracking via section
    // size in incremental context?
    last_atom: ?*Atom = null,

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
    free_list: std.ArrayListUnmanaged(*Atom) = .{},
};

base: File,

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

/// Page size is dependent on the target cpu architecture.
/// For x86_64 that's 4KB, whereas for aarch64, that's 16KB.
page_size: u16,

/// Mode of operation: incremental - will preallocate segments/sections and is compatible with
/// watch and HCS modes of operation; one_shot - will link relocatables in a traditional, one-shot
/// fashion (default for LLVM backend).
mode: enum { incremental, one_shot },

uuid: macho.uuid_command = .{
    .cmdsize = @sizeOf(macho.uuid_command),
    .uuid = undefined,
},

objects: std.ArrayListUnmanaged(Object) = .{},
archives: std.ArrayListUnmanaged(Archive) = .{},
dylibs: std.ArrayListUnmanaged(Dylib) = .{},
dylibs_map: std.StringHashMapUnmanaged(u16) = .{},
referenced_dylibs: std.AutoArrayHashMapUnmanaged(u16, void) = .{},

segments: std.ArrayListUnmanaged(macho.segment_command_64) = .{},
sections: std.MultiArrayList(Section) = .{},

pagezero_segment_cmd_index: ?u8 = null,
text_segment_cmd_index: ?u8 = null,
data_const_segment_cmd_index: ?u8 = null,
data_segment_cmd_index: ?u8 = null,
linkedit_segment_cmd_index: ?u8 = null,

text_section_index: ?u8 = null,
stubs_section_index: ?u8 = null,
stub_helper_section_index: ?u8 = null,
got_section_index: ?u8 = null,
la_symbol_ptr_section_index: ?u8 = null,
data_section_index: ?u8 = null,

locals: std.ArrayListUnmanaged(macho.nlist_64) = .{},
globals: std.ArrayListUnmanaged(SymbolWithLoc) = .{},
resolver: std.StringHashMapUnmanaged(u32) = .{},
unresolved: std.AutoArrayHashMapUnmanaged(u32, bool) = .{},

locals_free_list: std.ArrayListUnmanaged(u32) = .{},
globals_free_list: std.ArrayListUnmanaged(u32) = .{},

dyld_stub_binder_index: ?u32 = null,
dyld_private_atom: ?*Atom = null,
stub_helper_preamble_atom: ?*Atom = null,

strtab: StringTable(.strtab) = .{},

// TODO I think synthetic tables are a perfect match for some generic refactoring,
// and probably reusable between linker backends too.
tlv_ptr_entries: std.ArrayListUnmanaged(Entry) = .{},
tlv_ptr_entries_free_list: std.ArrayListUnmanaged(u32) = .{},
tlv_ptr_entries_table: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

got_entries: std.ArrayListUnmanaged(Entry) = .{},
got_entries_free_list: std.ArrayListUnmanaged(u32) = .{},
got_entries_table: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

stubs: std.ArrayListUnmanaged(Entry) = .{},
stubs_free_list: std.ArrayListUnmanaged(u32) = .{},
stubs_table: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

error_flags: File.ErrorFlags = File.ErrorFlags{},

/// A helper var to indicate if we are at the start of the incremental updates, or
/// already somewhere further along the update-and-run chain.
/// TODO once we add opening a prelinked output binary from file, this will become
/// obsolete as we will carry on where we left off.
cold_start: bool = true,

/// List of atoms that are either synthetic or map directly to the Zig source program.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

/// Table of atoms indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, *Atom) = .{},

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

/// Table of Decls that are currently alive.
/// We store them here so that we can properly dispose of any allocated
/// memory within the atom in the incremental linker.
/// TODO consolidate this.
decls: std.AutoArrayHashMapUnmanaged(Module.Decl.Index, ?u8) = .{},

const Entry = struct {
    target: SymbolWithLoc,
    // Index into the synthetic symbol table (i.e., file == null).
    sym_index: u32,

    pub fn getSymbol(entry: Entry, macho_file: *MachO) macho.nlist_64 {
        return macho_file.getSymbol(.{ .sym_index = entry.sym_index, .file = null });
    }

    pub fn getSymbolPtr(entry: Entry, macho_file: *MachO) *macho.nlist_64 {
        return macho_file.getSymbolPtr(.{ .sym_index = entry.sym_index, .file = null });
    }

    pub fn getAtom(entry: Entry, macho_file: *MachO) *Atom {
        return macho_file.getAtomForSymbol(.{ .sym_index = entry.sym_index, .file = null }).?;
    }

    pub fn getName(entry: Entry, macho_file: *MachO) []const u8 {
        return macho_file.getSymbolName(.{ .sym_index = entry.sym_index, .file = null });
    }
};

const UnnamedConstTable = std.AutoHashMapUnmanaged(Module.Decl.Index, std.ArrayListUnmanaged(*Atom));

const PendingUpdate = union(enum) {
    resolve_undef: u32,
    add_stub_entry: u32,
    add_got_entry: u32,
};

pub const SymbolWithLoc = struct {
    // Index into the respective symbol table.
    sym_index: u32,

    // null means it's a synthetic global.
    file: ?u32 = null,
};

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 4;

/// Default path to dyld
const default_dyld_path: [*:0]const u8 = "/usr/lib/dyld";

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_text_block_size = 64;
pub const min_text_capacity = padToIdeal(minimum_text_block_size);

/// Default virtual memory offset corresponds to the size of __PAGEZERO segment and
/// start of __TEXT segment.
const default_pagezero_vmsize: u64 = 0x100000000;

/// We commit 0x1000 = 4096 bytes of space to the header and
/// the table of load commands. This should be plenty for any
/// potential future extensions.
const default_headerpad_size: u32 = 0x1000;

pub const Export = struct {
    sym_index: ?u32 = null,
};

pub fn openPath(allocator: Allocator, options: link.Options) !*MachO {
    assert(options.target.ofmt == .macho);

    const use_stage1 = build_options.have_stage1 and options.use_stage1;
    if (use_stage1 or options.emit == null or options.module == null) {
        return createEmpty(allocator, options);
    }

    const emit = options.emit.?;
    const self = try createEmpty(allocator, options);
    errdefer {
        self.base.file = null;
        self.base.destroy();
    }

    if (build_options.have_llvm and options.use_llvm and options.module != null) {
        // TODO this intermediary_basename isn't enough; in the case of `zig build-exe`,
        // we also want to put the intermediary object file in the cache while the
        // main emit directory is the cwd.
        self.base.intermediary_basename = try std.fmt.allocPrint(allocator, "{s}{s}", .{
            emit.sub_path, options.target.ofmt.fileExt(options.target.cpu.arch),
        });
    }

    if (self.base.intermediary_basename != null) switch (options.output_mode) {
        .Obj => return self,
        .Lib => if (options.link_mode == .Static) return self,
        else => {},
    };

    const file = try emit.directory.handle.createFile(emit.sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();
    self.base.file = file;

    if (!options.strip and options.module != null) blk: {
        // TODO once I add support for converting (and relocating) DWARF info from relocatable
        // object files, this check becomes unnecessary.
        // For now, for LLVM backend we fallback to the old-fashioned stabs approach used by
        // stage1.
        if (build_options.have_llvm and options.use_llvm) break :blk;

        // Create dSYM bundle.
        const dir = options.module.?.zig_cache_artifact_directory;
        log.debug("creating {s}.dSYM bundle in {?s}", .{ emit.sub_path, dir.path });

        const d_sym_path = try fmt.allocPrint(
            allocator,
            "{s}.dSYM" ++ fs.path.sep_str ++ "Contents" ++ fs.path.sep_str ++ "Resources" ++ fs.path.sep_str ++ "DWARF",
            .{emit.sub_path},
        );
        defer allocator.free(d_sym_path);

        var d_sym_bundle = try dir.handle.makeOpenPath(d_sym_path, .{});
        defer d_sym_bundle.close();

        const d_sym_file = try d_sym_bundle.createFile(emit.sub_path, .{
            .truncate = false,
            .read = true,
        });

        self.d_sym = .{
            .base = self,
            .dwarf = link.File.Dwarf.init(allocator, .macho, options.target),
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
        try d_sym.populateMissingMetadata(allocator);
    }

    return self;
}

pub fn createEmpty(gpa: Allocator, options: link.Options) !*MachO {
    const cpu_arch = options.target.cpu.arch;
    const page_size: u16 = if (cpu_arch == .aarch64) 0x4000 else 0x1000;
    const use_llvm = build_options.have_llvm and options.use_llvm;
    const use_stage1 = build_options.have_stage1 and options.use_stage1;

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
        .mode = if (use_stage1 or use_llvm or options.module == null or options.cache_mode == .whole)
            .one_shot
        else
            .incremental,
    };

    if (use_llvm and !use_stage1) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }

    log.debug("selected linker mode '{s}'", .{@tagName(self.mode)});

    return self;
}

pub fn flush(self: *MachO, comp: *Compilation, prog_node: *std.Progress.Node) !void {
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
        .one_shot => return zld.linkWithZld(self, comp, prog_node),
        .incremental => return self.flushModule(comp, prog_node),
    }
}

pub fn flushModule(self: *MachO, comp: *Compilation, prog_node: *std.Progress.Node) !void {
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

    if (self.d_sym) |*d_sym| {
        try d_sym.dwarf.flushModule(&self.base, module);
    }

    var libs = std.StringArrayHashMap(link.SystemLib).init(arena);
    try self.resolveLibSystem(arena, comp, &.{}, &libs);

    const id_symlink_basename = "zld.id";

    const cache_dir_handle = module.zig_cache_artifact_directory.handle;
    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;
    man = comp.cache_parent.obtain();
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

    try self.createMhExecuteHeaderSymbol();
    try self.resolveDyldStubBinder();
    try self.createDyldPrivateAtom();
    try self.createStubHelperPreambleAtom();
    try self.resolveSymbolsInDylibs();

    if (self.unresolved.count() > 0) {
        return error.UndefinedSymbolReference;
    }

    try self.allocateSpecialSymbols();

    if (build_options.enable_logging) {
        self.logSymtab();
        self.logSections();
        self.logAtoms();
    }

    try self.writeAtoms();

    var lc_buffer = std.ArrayList(u8).init(arena);
    const lc_writer = lc_buffer.writer();
    var ncmds: u32 = 0;

    try self.writeLinkeditSegmentData(&ncmds, lc_writer);
    try writeDylinkerLC(&ncmds, lc_writer);

    self.writeMainLC(&ncmds, lc_writer) catch |err| switch (err) {
        error.MissingMainEntrypoint => {
            self.error_flags.no_entry_point_found = true;
        },
        else => |e| return e,
    };

    try self.writeDylibIdLC(&ncmds, lc_writer);
    try self.writeRpathLCs(&ncmds, lc_writer);

    {
        try lc_writer.writeStruct(macho.source_version_command{
            .cmdsize = @sizeOf(macho.source_version_command),
            .version = 0x0,
        });
        ncmds += 1;
    }

    try self.writeBuildVersionLC(&ncmds, lc_writer);

    {
        std.crypto.random.bytes(&self.uuid.uuid);
        try lc_writer.writeStruct(self.uuid);
        ncmds += 1;
    }

    try self.writeLoadDylibLCs(&ncmds, lc_writer);

    const target = self.base.options.target;
    const requires_codesig = blk: {
        if (self.base.options.entitlements) |_| break :blk true;
        if (target.cpu.arch == .aarch64 and (target.os.tag == .macos or target.abi == .simulator))
            break :blk true;
        break :blk false;
    };
    var codesig_offset: ?u32 = null;
    var codesig: ?CodeSignature = if (requires_codesig) blk: {
        // Preallocate space for the code signature.
        // We need to do this at this stage so that we have the load commands with proper values
        // written out to the file.
        // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
        // where the code signature goes into.
        var codesig = CodeSignature.init(self.page_size);
        codesig.code_directory.ident = self.base.options.emit.?.sub_path;
        if (self.base.options.entitlements) |path| {
            try codesig.addEntitlements(arena, path);
        }
        codesig_offset = try self.writeCodeSignaturePadding(&codesig, &ncmds, lc_writer);
        break :blk codesig;
    } else null;

    var headers_buf = std.ArrayList(u8).init(arena);
    try self.writeSegmentHeaders(&ncmds, headers_buf.writer());

    try self.base.file.?.pwriteAll(headers_buf.items, @sizeOf(macho.mach_header_64));
    try self.base.file.?.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64) + headers_buf.items.len);

    try self.writeHeader(ncmds, @intCast(u32, lc_buffer.items.len + headers_buf.items.len));

    if (codesig) |*csig| {
        try self.writeCodeSignature(csig, codesig_offset.?); // code signing always comes last
    }

    if (self.d_sym) |*d_sym| {
        // Flush debug symbols bundle.
        try d_sym.flushModule(self.base.allocator, self.base.options);
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

pub fn resolveLibSystem(
    self: *MachO,
    arena: Allocator,
    comp: *Compilation,
    search_dirs: []const []const u8,
    out_libs: anytype,
) !void {
    // If we were given the sysroot, try to look there first for libSystem.B.{dylib, tbd}.
    var libsystem_available = false;
    if (self.base.options.sysroot != null) blk: {
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
            self.base.options.target.os.version_range.semver.min.major,
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

fn parseObject(self: *MachO, path: []const u8) !bool {
    const gpa = self.base.allocator;
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    defer file.close();

    const name = try gpa.dupe(u8, path);
    errdefer gpa.free(name);
    const cpu_arch = self.base.options.target.cpu.arch;
    const mtime: u64 = mtime: {
        const stat = file.stat() catch break :mtime 0;
        break :mtime @intCast(u64, @divFloor(stat.mtime, 1_000_000_000));
    };
    const file_stat = try file.stat();
    const file_size = math.cast(usize, file_stat.size) orelse return error.Overflow;
    const contents = try file.readToEndAllocOptions(gpa, file_size, file_size, @alignOf(u64), null);

    var object = Object{
        .name = name,
        .mtime = mtime,
        .contents = contents,
    };

    object.parse(gpa, cpu_arch) catch |err| switch (err) {
        error.EndOfStream, error.NotObject => {
            object.deinit(gpa);
            return false;
        },
        else => |e| return e,
    };

    try self.objects.append(gpa, object);

    return true;
}

fn parseArchive(self: *MachO, path: []const u8, force_load: bool) !bool {
    const gpa = self.base.allocator;
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    errdefer file.close();

    const name = try gpa.dupe(u8, path);
    errdefer gpa.free(name);
    const cpu_arch = self.base.options.target.cpu.arch;
    const reader = file.reader();
    const fat_offset = try fat.getLibraryOffset(reader, cpu_arch);
    try reader.context.seekTo(fat_offset);

    var archive = Archive{
        .name = name,
        .fat_offset = fat_offset,
        .file = file,
    };

    archive.parse(gpa, reader) catch |err| switch (err) {
        error.EndOfStream, error.NotArchive => {
            archive.deinit(gpa);
            return false;
        },
        else => |e| return e,
    };

    if (force_load) {
        defer archive.deinit(gpa);
        // Get all offsets from the ToC
        var offsets = std.AutoArrayHashMap(u32, void).init(gpa);
        defer offsets.deinit();
        for (archive.toc.values()) |offs| {
            for (offs.items) |off| {
                _ = try offsets.getOrPut(off);
            }
        }
        for (offsets.keys()) |off| {
            const object = try archive.parseObject(gpa, cpu_arch, off);
            try self.objects.append(gpa, object);
        }
    } else {
        try self.archives.append(gpa, archive);
    }

    return true;
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
    for (lib_names) |lib, i| {
        const lib_info = lib_infos[i];
        log.debug("parsing lib path '{s}'", .{lib});
        if (try self.parseDylib(lib, dependent_libs, .{
            .syslibroot = syslibroot,
            .needed = lib_info.needed,
            .weak = lib_info.weak,
        })) continue;
        if (try self.parseArchive(lib, false)) continue;

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

pub fn getOutputSection(self: *MachO, sect: macho.section_64) !?u8 {
    const segname = sect.segName();
    const sectname = sect.sectName();
    const res: ?u8 = blk: {
        if (mem.eql(u8, "__LLVM", segname)) {
            log.debug("TODO LLVM section: type 0x{x}, name '{s},{s}'", .{
                sect.flags, segname, sectname,
            });
            break :blk null;
        }

        if (sect.isCode()) {
            if (self.text_section_index == null) {
                self.text_section_index = try self.initSection(
                    "__TEXT",
                    "__text",
                    sect.size,
                    sect.@"align",
                    .{
                        .flags = macho.S_REGULAR |
                            macho.S_ATTR_PURE_INSTRUCTIONS |
                            macho.S_ATTR_SOME_INSTRUCTIONS,
                    },
                );
            }
            break :blk self.text_section_index.?;
        }

        if (sect.isDebug()) {
            // TODO debug attributes
            if (mem.eql(u8, "__LD", segname) and mem.eql(u8, "__compact_unwind", sectname)) {
                log.debug("TODO compact unwind section: type 0x{x}, name '{s},{s}'", .{
                    sect.flags, segname, sectname,
                });
            }
            break :blk null;
        }

        switch (sect.@"type"()) {
            macho.S_4BYTE_LITERALS,
            macho.S_8BYTE_LITERALS,
            macho.S_16BYTE_LITERALS,
            => {
                break :blk self.getSectionByName("__TEXT", "__const") orelse try self.initSection(
                    "__TEXT",
                    "__const",
                    sect.size,
                    sect.@"align",
                    .{},
                );
            },
            macho.S_CSTRING_LITERALS => {
                if (mem.startsWith(u8, sectname, "__objc")) {
                    break :blk self.getSectionByName(segname, sectname) orelse try self.initSection(
                        segname,
                        sectname,
                        sect.size,
                        sect.@"align",
                        .{},
                    );
                }
                break :blk self.getSectionByName("__TEXT", "__cstring") orelse try self.initSection(
                    "__TEXT",
                    "__cstring",
                    sect.size,
                    sect.@"align",
                    .{ .flags = macho.S_CSTRING_LITERALS },
                );
            },
            macho.S_MOD_INIT_FUNC_POINTERS,
            macho.S_MOD_TERM_FUNC_POINTERS,
            => {
                break :blk self.getSectionByName("__DATA_CONST", sectname) orelse try self.initSection(
                    "__DATA_CONST",
                    sectname,
                    sect.size,
                    sect.@"align",
                    .{ .flags = sect.flags },
                );
            },
            macho.S_LITERAL_POINTERS,
            macho.S_ZEROFILL,
            macho.S_THREAD_LOCAL_VARIABLES,
            macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
            macho.S_THREAD_LOCAL_REGULAR,
            macho.S_THREAD_LOCAL_ZEROFILL,
            => {
                break :blk self.getSectionByName(segname, sectname) orelse try self.initSection(
                    segname,
                    sectname,
                    sect.size,
                    sect.@"align",
                    .{ .flags = sect.flags },
                );
            },
            macho.S_COALESCED => {
                break :blk self.getSectionByName(segname, sectname) orelse try self.initSection(
                    segname,
                    sectname,
                    sect.size,
                    sect.@"align",
                    .{},
                );
            },
            macho.S_REGULAR => {
                if (mem.eql(u8, segname, "__TEXT")) {
                    if (mem.eql(u8, sectname, "__rodata") or
                        mem.eql(u8, sectname, "__typelink") or
                        mem.eql(u8, sectname, "__itablink") or
                        mem.eql(u8, sectname, "__gosymtab") or
                        mem.eql(u8, sectname, "__gopclntab"))
                    {
                        break :blk self.getSectionByName("__DATA_CONST", "__const") orelse try self.initSection(
                            "__DATA_CONST",
                            "__const",
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    }
                }
                if (mem.eql(u8, segname, "__DATA")) {
                    if (mem.eql(u8, sectname, "__const") or
                        mem.eql(u8, sectname, "__cfstring") or
                        mem.eql(u8, sectname, "__objc_classlist") or
                        mem.eql(u8, sectname, "__objc_imageinfo"))
                    {
                        break :blk self.getSectionByName("__DATA_CONST", sectname) orelse
                            try self.initSection(
                            "__DATA_CONST",
                            sectname,
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    } else if (mem.eql(u8, sectname, "__data")) {
                        if (self.data_section_index == null) {
                            self.data_section_index = try self.initSection(
                                segname,
                                sectname,
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }
                        break :blk self.data_section_index.?;
                    }
                }
                break :blk self.getSectionByName(segname, sectname) orelse try self.initSection(
                    segname,
                    sectname,
                    sect.size,
                    sect.@"align",
                    .{},
                );
            },
            else => break :blk null,
        }
    };
    return res;
}

pub fn createEmptyAtom(gpa: Allocator, sym_index: u32, size: u64, alignment: u32) !*Atom {
    const size_usize = math.cast(usize, size) orelse return error.Overflow;
    const atom = try gpa.create(Atom);
    errdefer gpa.destroy(atom);
    atom.* = Atom.empty;
    atom.sym_index = sym_index;
    atom.size = size;
    atom.alignment = alignment;

    try atom.code.resize(gpa, size_usize);
    mem.set(u8, atom.code.items, 0);

    return atom;
}

pub fn writeAtom(self: *MachO, atom: *Atom) !void {
    const sym = atom.getSymbol(self);
    const section = self.sections.get(sym.n_sect - 1);
    const file_offset = section.header.offset + sym.n_value - section.header.addr;
    try atom.resolveRelocs(self);
    log.debug("writing atom for symbol {s} at file offset 0x{x}", .{ atom.getName(self), file_offset });
    try self.base.file.?.pwriteAll(atom.code.items, file_offset);
}

// fn markRelocsDirtyByTarget(self: *MachO, target: SymbolWithLoc) void {
//     // TODO: reverse-lookup might come in handy here
//     var it = self.relocs.valueIterator();
//     while (it.next()) |relocs| {
//         for (relocs.items) |*reloc| {
//             if (!reloc.target.eql(target)) continue;
//             reloc.dirty = true;
//         }
//     }
// }

// fn markRelocsDirtyByAddress(self: *MachO, addr: u32) void {
//     var it = self.relocs.valueIterator();
//     while (it.next()) |relocs| {
//         for (relocs.items) |*reloc| {
//             const target_atom = reloc.getTargetAtom(self) orelse continue;
//             const target_sym = target_atom.getSymbol(self);
//             if (target_sym.value < addr) continue;
//             reloc.dirty = true;
//         }
//     }
// }

// fn resolveRelocs(self: *MachO, atom: *Atom) !void {
//     const relocs = self.relocs.get(atom) orelse return;
//     const source_sym = atom.getSymbol(self);
//     const source_section = self.sections.get(@enumToInt(source_sym.section_number) - 1).header;
//     const file_offset = section.offset + source_sym.n_value - section.addr;

//     log.debug("relocating '{s}'", .{atom.getName(self)});

//     for (relocs.items) |*reloc| {
//         if (!reloc.dirty) continue;

//         const target_atom = reloc.getTargetAtom(self) orelse continue;
//         const target_vaddr = target_atom.getSymbol(self).value;
//         const target_vaddr_with_addend = target_vaddr + reloc.addend;

//         log.debug("  ({x}: [() => 0x{x} ({s})) ({s}) (in file at 0x{x})", .{
//             source_sym.value + reloc.offset,
//             target_vaddr_with_addend,
//             self.getSymbolName(reloc.target),
//             @tagName(reloc.@"type"),
//             file_offset + reloc.offset,
//         });

//         reloc.dirty = false;

//         if (reloc.pcrel) {
//             const source_vaddr = source_sym.value + reloc.offset;
//             const disp =
//                 @intCast(i32, target_vaddr_with_addend) - @intCast(i32, source_vaddr) - 4;
//             try self.base.file.?.pwriteAll(mem.asBytes(&disp), file_offset + reloc.offset);
//             continue;
//         }

//         switch (reloc.length) {
//             2 => try self.base.file.?.pwriteAll(
//                 mem.asBytes(&@truncate(u32, target_vaddr_with_addend)),
//                 file_offset + reloc.offset,
//             ),
//             3 => try self.base.file.?.pwriteAll(
//                 mem.asBytes(&(target_vaddr_with_addend)),
//                 file_offset + reloc.offset,
//             ),
//             else => unreachable,
//         }
//     }
// }

pub fn allocateSpecialSymbols(self: *MachO) !void {
    for (&[_][]const u8{
        "___dso_handle",
        "__mh_execute_header",
    }) |name| {
        const global = self.getGlobal(name) orelse continue;
        if (global.file != null) continue;
        const sym = self.getSymbolPtr(global);
        const seg = self.segments.items[self.text_segment_cmd_index.?];
        sym.n_sect = 1;
        sym.n_value = seg.vmaddr;

        log.debug("allocating {s} at the start of {s}", .{
            name,
            seg.segName(),
        });
    }
}

fn writeAtoms(self: *MachO) !void {
    assert(self.mode == .incremental);

    const slice = self.sections.slice();
    for (slice.items(.last_atom)) |last, i| {
        var atom: *Atom = last orelse continue;
        const sect_i = @intCast(u8, i);
        const header = slice.items(.header)[sect_i];

        if (header.isZerofill()) continue;

        log.debug("writing atoms in {s},{s}", .{ header.segName(), header.sectName() });

        while (true) {
            if (atom.dirty) {
                try self.writeAtom(atom);
                atom.dirty = false;
            }

            if (atom.prev) |prev| {
                atom = prev;
            } else break;
        }
    }
}

pub fn createGotAtom(self: *MachO, target: SymbolWithLoc) !*Atom {
    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, @sizeOf(u64), 3);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.got_section_index.? + 1;

    try atom.relocs.append(gpa, .{
        .offset = 0,
        .target = target,
        .addend = 0,
        .subtractor = null,
        .pcrel = false,
        .length = 3,
        .@"type" = switch (self.base.options.target.cpu.arch) {
            .aarch64 => @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_UNSIGNED),
            .x86_64 => @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_UNSIGNED),
            else => unreachable,
        },
    });

    const target_sym = self.getSymbol(target);
    if (target_sym.undf()) {
        const global = self.getGlobal(self.getSymbolName(target)).?;
        try atom.bindings.append(gpa, .{
            .target = global,
            .offset = 0,
        });
    } else {
        try atom.rebases.append(gpa, 0);
    }

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);

    try self.allocateAtomCommon(atom);

    return atom;
}

pub fn createTlvPtrAtom(self: *MachO, target: SymbolWithLoc) !*Atom {
    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, @sizeOf(u64), 3);

    const target_sym = self.getSymbol(target);
    assert(target_sym.undf());

    const global = self.getGlobal(self.getSymbolName(target)).?;
    try atom.bindings.append(gpa, .{
        .target = global,
        .offset = 0,
    });

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);

    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    const sect_id = (try self.getOutputSection(.{
        .segname = makeStaticString("__DATA"),
        .sectname = makeStaticString("__thread_ptrs"),
        .flags = macho.S_THREAD_LOCAL_VARIABLE_POINTERS,
    })).?;
    sym.n_sect = sect_id + 1;

    try self.allocateAtomCommon(atom);

    return atom;
}

pub fn createDyldPrivateAtom(self: *MachO) !void {
    if (self.dyld_stub_binder_index == null) return;
    if (self.dyld_private_atom != null) return;

    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, @sizeOf(u64), 3);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.data_section_index.? + 1;
    self.dyld_private_atom = atom;

    try self.allocateAtomCommon(atom);

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);
}

pub fn createStubHelperPreambleAtom(self: *MachO) !void {
    if (self.dyld_stub_binder_index == null) return;
    if (self.stub_helper_preamble_atom != null) return;

    const gpa = self.base.allocator;
    const arch = self.base.options.target.cpu.arch;
    const size: u64 = switch (arch) {
        .x86_64 => 15,
        .aarch64 => 6 * @sizeOf(u32),
        else => unreachable,
    };
    const alignment: u32 = switch (arch) {
        .x86_64 => 0,
        .aarch64 => 2,
        else => unreachable,
    };
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, size, alignment);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.stub_helper_section_index.? + 1;

    const dyld_private_sym_index = self.dyld_private_atom.?.sym_index;
    switch (arch) {
        .x86_64 => {
            try atom.relocs.ensureUnusedCapacity(self.base.allocator, 2);
            // lea %r11, [rip + disp]
            atom.code.items[0] = 0x4c;
            atom.code.items[1] = 0x8d;
            atom.code.items[2] = 0x1d;
            atom.relocs.appendAssumeCapacity(.{
                .offset = 3,
                .target = .{ .sym_index = dyld_private_sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_SIGNED),
            });
            // push %r11
            atom.code.items[7] = 0x41;
            atom.code.items[8] = 0x53;
            // jmp [rip + disp]
            atom.code.items[9] = 0xff;
            atom.code.items[10] = 0x25;
            atom.relocs.appendAssumeCapacity(.{
                .offset = 11,
                .target = .{ .sym_index = self.dyld_stub_binder_index.?, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_GOT),
            });
        },
        .aarch64 => {
            try atom.relocs.ensureUnusedCapacity(self.base.allocator, 4);
            // adrp x17, 0
            mem.writeIntLittle(u32, atom.code.items[0..][0..4], aarch64.Instruction.adrp(.x17, 0).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 0,
                .target = .{ .sym_index = dyld_private_sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_PAGE21),
            });
            // add x17, x17, 0
            mem.writeIntLittle(u32, atom.code.items[4..][0..4], aarch64.Instruction.add(.x17, .x17, 0, false).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 4,
                .target = .{ .sym_index = dyld_private_sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = false,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_PAGEOFF12),
            });
            // stp x16, x17, [sp, #-16]!
            mem.writeIntLittle(u32, atom.code.items[8..][0..4], aarch64.Instruction.stp(
                .x16,
                .x17,
                aarch64.Register.sp,
                aarch64.Instruction.LoadStorePairOffset.pre_index(-16),
            ).toU32());
            // adrp x16, 0
            mem.writeIntLittle(u32, atom.code.items[12..][0..4], aarch64.Instruction.adrp(.x16, 0).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 12,
                .target = .{ .sym_index = self.dyld_stub_binder_index.?, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGE21),
            });
            // ldr x16, [x16, 0]
            mem.writeIntLittle(u32, atom.code.items[16..][0..4], aarch64.Instruction.ldr(
                .x16,
                .x16,
                aarch64.Instruction.LoadStoreOffset.imm(0),
            ).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 16,
                .target = .{ .sym_index = self.dyld_stub_binder_index.?, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = false,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_GOT_LOAD_PAGEOFF12),
            });
            // br x16
            mem.writeIntLittle(u32, atom.code.items[20..][0..4], aarch64.Instruction.br(.x16).toU32());
        },
        else => unreachable,
    }
    self.stub_helper_preamble_atom = atom;

    try self.allocateAtomCommon(atom);

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);
}

pub fn createStubHelperAtom(self: *MachO) !*Atom {
    const gpa = self.base.allocator;
    const arch = self.base.options.target.cpu.arch;
    const stub_size: u4 = switch (arch) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable,
    };
    const alignment: u2 = switch (arch) {
        .x86_64 => 0,
        .aarch64 => 2,
        else => unreachable,
    };
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, stub_size, alignment);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.stub_helper_section_index.? + 1;

    try atom.relocs.ensureTotalCapacity(gpa, 1);

    switch (arch) {
        .x86_64 => {
            // pushq
            atom.code.items[0] = 0x68;
            // Next 4 bytes 1..4 are just a placeholder populated in `populateLazyBindOffsetsInStubHelper`.
            // jmpq
            atom.code.items[5] = 0xe9;
            atom.relocs.appendAssumeCapacity(.{
                .offset = 6,
                .target = .{ .sym_index = self.stub_helper_preamble_atom.?.sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_BRANCH),
            });
        },
        .aarch64 => {
            const literal = blk: {
                const div_res = try math.divExact(u64, stub_size - @sizeOf(u32), 4);
                break :blk math.cast(u18, div_res) orelse return error.Overflow;
            };
            // ldr w16, literal
            mem.writeIntLittle(u32, atom.code.items[0..4], aarch64.Instruction.ldrLiteral(
                .w16,
                literal,
            ).toU32());
            // b disp
            mem.writeIntLittle(u32, atom.code.items[4..8], aarch64.Instruction.b(0).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 4,
                .target = .{ .sym_index = self.stub_helper_preamble_atom.?.sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_BRANCH26),
            });
            // Next 4 bytes 8..12 are just a placeholder populated in `populateLazyBindOffsetsInStubHelper`.
        },
        else => unreachable,
    }

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);

    try self.allocateAtomCommon(atom);

    return atom;
}

pub fn createLazyPointerAtom(self: *MachO, stub_sym_index: u32, target: SymbolWithLoc) !*Atom {
    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, @sizeOf(u64), 3);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.la_symbol_ptr_section_index.? + 1;

    try atom.relocs.append(gpa, .{
        .offset = 0,
        .target = .{ .sym_index = stub_sym_index, .file = null },
        .addend = 0,
        .subtractor = null,
        .pcrel = false,
        .length = 3,
        .@"type" = switch (self.base.options.target.cpu.arch) {
            .aarch64 => @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_UNSIGNED),
            .x86_64 => @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_UNSIGNED),
            else => unreachable,
        },
    });
    try atom.rebases.append(gpa, 0);

    const global = self.getGlobal(self.getSymbolName(target)).?;
    try atom.lazy_bindings.append(gpa, .{
        .target = global,
        .offset = 0,
    });

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);

    try self.allocateAtomCommon(atom);

    return atom;
}

pub fn createStubAtom(self: *MachO, laptr_sym_index: u32) !*Atom {
    const gpa = self.base.allocator;
    const arch = self.base.options.target.cpu.arch;
    const alignment: u2 = switch (arch) {
        .x86_64 => 0,
        .aarch64 => 2,
        else => unreachable, // unhandled architecture type
    };
    const stub_size: u4 = switch (arch) {
        .x86_64 => 6,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable, // unhandled architecture type
    };
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(gpa, sym_index, stub_size, alignment);
    const sym = atom.getSymbolPtr(self);
    sym.n_type = macho.N_SECT;
    sym.n_sect = self.stubs_section_index.? + 1;

    switch (arch) {
        .x86_64 => {
            // jmp
            atom.code.items[0] = 0xff;
            atom.code.items[1] = 0x25;
            try atom.relocs.append(gpa, .{
                .offset = 2,
                .target = .{ .sym_index = laptr_sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_BRANCH),
            });
        },
        .aarch64 => {
            try atom.relocs.ensureTotalCapacity(gpa, 2);
            // adrp x16, pages
            mem.writeIntLittle(u32, atom.code.items[0..4], aarch64.Instruction.adrp(.x16, 0).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 0,
                .target = .{ .sym_index = laptr_sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_PAGE21),
            });
            // ldr x16, x16, offset
            mem.writeIntLittle(u32, atom.code.items[4..8], aarch64.Instruction.ldr(
                .x16,
                .x16,
                aarch64.Instruction.LoadStoreOffset.imm(0),
            ).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 4,
                .target = .{ .sym_index = laptr_sym_index, .file = null },
                .addend = 0,
                .subtractor = null,
                .pcrel = false,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_PAGEOFF12),
            });
            // br x16
            mem.writeIntLittle(u32, atom.code.items[8..12], aarch64.Instruction.br(.x16).toU32());
        },
        else => unreachable,
    }

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);

    try self.allocateAtomCommon(atom);

    return atom;
}

pub fn createTentativeDefAtoms(self: *MachO) !void {
    const gpa = self.base.allocator;

    for (self.globals.items) |global| {
        const sym = self.getSymbolPtr(global);
        if (!sym.tentative()) continue;

        log.debug("creating tentative definition for ATOM(%{d}, '{s}') in object({?d})", .{
            global.sym_index, self.getSymbolName(global), global.file,
        });

        // Convert any tentative definition into a regular symbol and allocate
        // text blocks for each tentative definition.
        const size = sym.n_value;
        const alignment = (sym.n_desc >> 8) & 0x0f;
        const n_sect = (try self.getOutputSection(.{
            .segname = makeStaticString("__DATA"),
            .sectname = makeStaticString("__bss"),
            .flags = macho.S_ZEROFILL,
        })).?;

        sym.* = .{
            .n_strx = sym.n_strx,
            .n_type = macho.N_SECT | macho.N_EXT,
            .n_sect = n_sect,
            .n_desc = 0,
            .n_value = 0,
        };

        const atom = try MachO.createEmptyAtom(gpa, global.sym_index, size, alignment);
        atom.file = global.file;

        try self.allocateAtomCommon(atom);

        if (global.file) |file| {
            const object = &self.objects.items[file];
            try object.managed_atoms.append(gpa, atom);
            try object.atom_by_index_table.putNoClobber(gpa, global.sym_index, atom);
        } else {
            try self.managed_atoms.append(gpa, atom);
            try self.atom_by_index_table.putNoClobber(gpa, global.sym_index, atom);
        }
    }
}

pub fn createMhExecuteHeaderSymbol(self: *MachO) !void {
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

pub fn createDsoHandleSymbol(self: *MachO) !void {
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
            try self.unresolved.putNoClobber(gpa, self.getGlobalIndex(sym_name).?, false);
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

pub fn resolveSymbolsInObject(self: *MachO, object_id: u16) !void {
    const object = &self.objects.items[object_id];
    log.debug("resolving symbols in '{s}'", .{object.name});

    for (object.symtab.items) |sym, index| {
        const sym_index = @intCast(u32, index);
        const sym_name = object.getString(sym.n_strx);

        if (sym.stab()) {
            log.err("unhandled symbol type: stab", .{});
            log.err("  symbol '{s}'", .{sym_name});
            log.err("  first definition in '{s}'", .{object.name});
            return error.UnhandledSymbolType;
        }

        if (sym.indr()) {
            log.err("unhandled symbol type: indirect", .{});
            log.err("  symbol '{s}'", .{sym_name});
            log.err("  first definition in '{s}'", .{object.name});
            return error.UnhandledSymbolType;
        }

        if (sym.abs()) {
            log.err("unhandled symbol type: absolute", .{});
            log.err("  symbol '{s}'", .{sym_name});
            log.err("  first definition in '{s}'", .{object.name});
            return error.UnhandledSymbolType;
        }

        if (sym.sect() and !sym.ext()) {
            log.debug("symbol '{s}' local to object {s}; skipping...", .{
                sym_name,
                object.name,
            });
            continue;
        }

        const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = object_id };
        self.resolveGlobalSymbol(sym_loc) catch |err| switch (err) {
            error.MultipleSymbolDefinitions => {
                const global = self.getGlobal(sym_name).?;
                log.err("symbol '{s}' defined multiple times", .{sym_name});
                if (global.file) |file| {
                    log.err("  first definition in '{s}'", .{self.objects.items[file].name});
                }
                log.err("  next definition in '{s}'", .{self.objects.items[object_id].name});
                return error.MultipleSymbolDefinitions;
            },
            else => |e| return e,
        };
    }
}

pub fn resolveSymbolsInArchives(self: *MachO) !void {
    if (self.archives.items.len == 0) return;

    const gpa = self.base.allocator;
    const cpu_arch = self.base.options.target.cpu.arch;
    var next_sym: usize = 0;
    loop: while (next_sym < self.unresolved.count()) {
        const global_index = self.unresolved.keys()[next_sym];
        const global = self.globals.items[global_index];
        const sym_name = self.getSymbolName(global);

        for (self.archives.items) |archive| {
            // Check if the entry exists in a static archive.
            const offsets = archive.toc.get(sym_name) orelse {
                // No hit.
                continue;
            };
            assert(offsets.items.len > 0);

            const object_id = @intCast(u16, self.objects.items.len);
            const object = try archive.parseObject(gpa, cpu_arch, offsets.items[0]);
            try self.objects.append(gpa, object);
            try self.resolveSymbolsInObject(object_id);

            continue :loop;
        }

        next_sym += 1;
    }
}

pub fn resolveSymbolsInDylibs(self: *MachO) !void {
    if (self.dylibs.items.len == 0) return;

    const gpa = self.base.allocator;
    var next_sym: usize = 0;
    loop: while (next_sym < self.unresolved.count()) {
        const global_index = self.unresolved.keys()[next_sym];
        const global = self.globals.items[global_index];
        const sym = self.getSymbolPtr(global);
        const sym_name = self.getSymbolName(global);

        for (self.dylibs.items) |dylib, id| {
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
                if (!entry.value) break :blk;
                if (!sym.undf()) break :blk;
                if (self.stubs_table.contains(global)) break :blk;

                const stub_index = try self.allocateStubEntry(global);
                const stub_helper_atom = try self.createStubHelperAtom();
                const laptr_atom = try self.createLazyPointerAtom(stub_helper_atom.sym_index, global);
                const stub_atom = try self.createStubAtom(laptr_atom.sym_index);
                self.stubs.items[stub_index].sym_index = stub_atom.sym_index;
            }

            continue :loop;
        }

        next_sym += 1;
    }
}

pub fn resolveSymbolsAtLoading(self: *MachO) !void {
    const is_lib = self.base.options.output_mode == .Lib;
    const is_dyn_lib = self.base.options.link_mode == .Dynamic and is_lib;
    const allow_undef = is_dyn_lib and (self.base.options.allow_shlib_undefined orelse false);

    var next_sym: usize = 0;
    while (next_sym < self.unresolved.count()) {
        const global_index = self.unresolved.keys()[next_sym];
        const global = self.globals.items[global_index];
        const sym = self.getSymbolPtr(global);
        const sym_name = self.getSymbolName(global);

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
            const n_desc = @bitCast(
                u16,
                macho.BIND_SPECIAL_DYLIB_FLAT_LOOKUP * @intCast(i16, macho.N_SYMBOL_RESOLVER),
            );
            // TODO allow_shlib_undefined is an ELF flag so figure out macOS specific flags too.
            sym.n_type = macho.N_EXT;
            sym.n_desc = n_desc;
            _ = self.unresolved.swapRemove(global_index);
            continue;
        }

        log.err("undefined reference to symbol '{s}'", .{sym_name});
        if (global.file) |file| {
            log.err("  first referenced in '{s}'", .{self.objects.items[file].name});
        }

        next_sym += 1;
    }
}

pub fn resolveDyldStubBinder(self: *MachO) !void {
    if (self.dyld_stub_binder_index != null) return;
    if (self.unresolved.count() == 0) return; // no need for a stub binder if we don't have any imports

    const gpa = self.base.allocator;
    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    const sym = self.getSymbolPtr(sym_loc);
    const sym_name = "dyld_stub_binder";
    sym.* = .{
        .n_strx = try self.strtab.insert(gpa, sym_name),
        .n_type = macho.N_UNDF,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    const gop = try self.getOrPutGlobalPtr(sym_name);
    gop.value_ptr.* = sym_loc;
    const global = gop.value_ptr.*;

    for (self.dylibs.items) |dylib, id| {
        if (!dylib.symbols.contains(sym_name)) continue;

        const dylib_id = @intCast(u16, id);
        if (!self.referenced_dylibs.contains(dylib_id)) {
            try self.referenced_dylibs.putNoClobber(gpa, dylib_id, {});
        }

        const ordinal = self.referenced_dylibs.getIndex(dylib_id) orelse unreachable;
        sym.n_type |= macho.N_EXT;
        sym.n_desc = @intCast(u16, ordinal + 1) * macho.N_SYMBOL_RESOLVER;
        self.dyld_stub_binder_index = sym_index;

        break;
    }

    if (self.dyld_stub_binder_index == null) {
        log.err("undefined reference to symbol '{s}'", .{sym_name});
        return error.UndefinedSymbolReference;
    }

    // Add dyld_stub_binder as the final GOT entry.
    const got_index = try self.allocateGotEntry(global);
    const got_atom = try self.createGotAtom(global);
    self.got_entries.items[got_index].sym_index = got_atom.sym_index;
}

pub fn writeDylinkerLC(ncmds: *u32, lc_writer: anytype) !void {
    const name_len = mem.sliceTo(default_dyld_path, 0).len;
    const cmdsize = @intCast(u32, mem.alignForwardGeneric(
        u64,
        @sizeOf(macho.dylinker_command) + name_len,
        @sizeOf(u64),
    ));
    try lc_writer.writeStruct(macho.dylinker_command{
        .cmd = .LOAD_DYLINKER,
        .cmdsize = cmdsize,
        .name = @sizeOf(macho.dylinker_command),
    });
    try lc_writer.writeAll(mem.sliceTo(default_dyld_path, 0));
    const padding = cmdsize - @sizeOf(macho.dylinker_command) - name_len;
    if (padding > 0) {
        try lc_writer.writeByteNTimes(0, padding);
    }
    ncmds.* += 1;
}

pub fn writeMainLC(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    if (self.base.options.output_mode != .Exe) return;
    const seg = self.segments.items[self.text_segment_cmd_index.?];
    const global = try self.getEntryPoint();
    const sym = self.getSymbol(global);
    try lc_writer.writeStruct(macho.entry_point_command{
        .cmd = .MAIN,
        .cmdsize = @sizeOf(macho.entry_point_command),
        .entryoff = @intCast(u32, sym.n_value - seg.vmaddr),
        .stacksize = self.base.options.stack_size_override orelse 0,
    });
    ncmds.* += 1;
}

const WriteDylibLCCtx = struct {
    cmd: macho.LC,
    name: []const u8,
    timestamp: u32 = 2,
    current_version: u32 = 0x10000,
    compatibility_version: u32 = 0x10000,
};

pub fn writeDylibLC(ctx: WriteDylibLCCtx, ncmds: *u32, lc_writer: anytype) !void {
    const name_len = ctx.name.len + 1;
    const cmdsize = @intCast(u32, mem.alignForwardGeneric(
        u64,
        @sizeOf(macho.dylib_command) + name_len,
        @sizeOf(u64),
    ));
    try lc_writer.writeStruct(macho.dylib_command{
        .cmd = ctx.cmd,
        .cmdsize = cmdsize,
        .dylib = .{
            .name = @sizeOf(macho.dylib_command),
            .timestamp = ctx.timestamp,
            .current_version = ctx.current_version,
            .compatibility_version = ctx.compatibility_version,
        },
    });
    try lc_writer.writeAll(ctx.name);
    try lc_writer.writeByte(0);
    const padding = cmdsize - @sizeOf(macho.dylib_command) - name_len;
    if (padding > 0) {
        try lc_writer.writeByteNTimes(0, padding);
    }
    ncmds.* += 1;
}

pub fn writeDylibIdLC(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    if (self.base.options.output_mode != .Lib) return;
    const install_name = self.base.options.install_name orelse self.base.options.emit.?.sub_path;
    const curr = self.base.options.version orelse std.builtin.Version{
        .major = 1,
        .minor = 0,
        .patch = 0,
    };
    const compat = self.base.options.compatibility_version orelse std.builtin.Version{
        .major = 1,
        .minor = 0,
        .patch = 0,
    };
    try writeDylibLC(.{
        .cmd = .ID_DYLIB,
        .name = install_name,
        .current_version = curr.major << 16 | curr.minor << 8 | curr.patch,
        .compatibility_version = compat.major << 16 | compat.minor << 8 | compat.patch,
    }, ncmds, lc_writer);
}

const RpathIterator = struct {
    buffer: []const []const u8,
    table: std.StringHashMap(void),
    count: usize = 0,

    fn init(gpa: Allocator, rpaths: []const []const u8) RpathIterator {
        return .{ .buffer = rpaths, .table = std.StringHashMap(void).init(gpa) };
    }

    fn deinit(it: *RpathIterator) void {
        it.table.deinit();
    }

    fn next(it: *RpathIterator) !?[]const u8 {
        while (true) {
            if (it.count >= it.buffer.len) return null;
            const rpath = it.buffer[it.count];
            it.count += 1;
            const gop = try it.table.getOrPut(rpath);
            if (gop.found_existing) continue;
            return rpath;
        }
    }
};

pub fn writeRpathLCs(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const gpa = self.base.allocator;

    var it = RpathIterator.init(gpa, self.base.options.rpath_list);
    defer it.deinit();

    while (try it.next()) |rpath| {
        const rpath_len = rpath.len + 1;
        const cmdsize = @intCast(u32, mem.alignForwardGeneric(
            u64,
            @sizeOf(macho.rpath_command) + rpath_len,
            @sizeOf(u64),
        ));
        try lc_writer.writeStruct(macho.rpath_command{
            .cmdsize = cmdsize,
            .path = @sizeOf(macho.rpath_command),
        });
        try lc_writer.writeAll(rpath);
        try lc_writer.writeByte(0);
        const padding = cmdsize - @sizeOf(macho.rpath_command) - rpath_len;
        if (padding > 0) {
            try lc_writer.writeByteNTimes(0, padding);
        }
        ncmds.* += 1;
    }
}

pub fn writeBuildVersionLC(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const cmdsize = @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    const platform_version = blk: {
        const ver = self.base.options.target.os.version_range.semver.min;
        const platform_version = ver.major << 16 | ver.minor << 8;
        break :blk platform_version;
    };
    const sdk_version = if (self.base.options.native_darwin_sdk) |sdk| blk: {
        const ver = sdk.version;
        const sdk_version = ver.major << 16 | ver.minor << 8;
        break :blk sdk_version;
    } else platform_version;
    const is_simulator_abi = self.base.options.target.abi == .simulator;
    try lc_writer.writeStruct(macho.build_version_command{
        .cmdsize = cmdsize,
        .platform = switch (self.base.options.target.os.tag) {
            .macos => .MACOS,
            .ios => if (is_simulator_abi) macho.PLATFORM.IOSSIMULATOR else macho.PLATFORM.IOS,
            .watchos => if (is_simulator_abi) macho.PLATFORM.WATCHOSSIMULATOR else macho.PLATFORM.WATCHOS,
            .tvos => if (is_simulator_abi) macho.PLATFORM.TVOSSIMULATOR else macho.PLATFORM.TVOS,
            else => unreachable,
        },
        .minos = platform_version,
        .sdk = sdk_version,
        .ntools = 1,
    });
    try lc_writer.writeAll(mem.asBytes(&macho.build_tool_version{
        .tool = .LD,
        .version = 0x0,
    }));
    ncmds.* += 1;
}

pub fn writeLoadDylibLCs(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    for (self.referenced_dylibs.keys()) |id| {
        const dylib = self.dylibs.items[id];
        const dylib_id = dylib.id orelse unreachable;
        try writeDylibLC(.{
            .cmd = if (dylib.weak) .LOAD_WEAK_DYLIB else .LOAD_DYLIB,
            .name = dylib_id.name,
            .timestamp = dylib_id.timestamp,
            .current_version = dylib_id.current_version,
            .compatibility_version = dylib_id.compatibility_version,
        }, ncmds, lc_writer);
    }
}

pub fn deinit(self: *MachO) void {
    const gpa = self.base.allocator;

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(gpa);
    }

    if (self.d_sym) |*d_sym| {
        d_sym.deinit(gpa);
    }

    self.tlv_ptr_entries.deinit(gpa);
    self.tlv_ptr_entries_free_list.deinit(gpa);
    self.tlv_ptr_entries_table.deinit(gpa);
    self.got_entries.deinit(gpa);
    self.got_entries_free_list.deinit(gpa);
    self.got_entries_table.deinit(gpa);
    self.stubs.deinit(gpa);
    self.stubs_free_list.deinit(gpa);
    self.stubs_table.deinit(gpa);
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

    for (self.managed_atoms.items) |atom| {
        atom.deinit(gpa);
        gpa.destroy(atom);
    }
    self.managed_atoms.deinit(gpa);

    if (self.base.options.module) |mod| {
        for (self.decls.keys()) |decl_index| {
            const decl = mod.declPtr(decl_index);
            decl.link.macho.deinit(gpa);
        }
        self.decls.deinit(gpa);
    } else {
        assert(self.decls.count() == 0);
    }

    {
        var it = self.unnamed_const_atoms.valueIterator();
        while (it.next()) |atoms| {
            atoms.deinit(gpa);
        }
        self.unnamed_const_atoms.deinit(gpa);
    }

    self.atom_by_index_table.deinit(gpa);

    {
        var it = self.relocs.valueIterator();
        while (it.next()) |relocs| {
            relocs.deinit(gpa);
        }
        self.relocs.deinit(gpa);
    }
}

fn freeAtom(self: *MachO, atom: *Atom, owns_atom: bool) void {
    log.debug("freeAtom {*}", .{atom});
    if (!owns_atom) {
        atom.deinit(self.base.allocator);
    }

    const sect_id = atom.getSymbol(self).n_sect - 1;
    const free_list = &self.sections.items(.free_list)[sect_id];
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn free_list into a hash map
        while (i < free_list.items.len) {
            if (free_list.items[i] == atom) {
                _ = free_list.swapRemove(i);
                continue;
            }
            if (free_list.items[i] == atom.prev) {
                already_have_free_list_node = true;
            }
            i += 1;
        }
    }

    const maybe_last_atom = &self.sections.items(.last_atom)[sect_id];
    if (maybe_last_atom.*) |last_atom| {
        if (last_atom == atom) {
            if (atom.prev) |prev| {
                // TODO shrink the section size here
                maybe_last_atom.* = prev;
            } else {
                maybe_last_atom.* = null;
            }
        }
    }

    if (atom.prev) |prev| {
        prev.next = atom.next;

        if (!already_have_free_list_node and prev.freeListEligible(self)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can ignore
            // the OOM here.
            free_list.append(self.base.allocator, prev) catch {};
        }
    } else {
        atom.prev = null;
    }

    if (atom.next) |next| {
        next.prev = atom.prev;
    } else {
        atom.next = null;
    }

    if (self.d_sym) |*d_sym| {
        d_sym.dwarf.freeAtom(&atom.dbg_info_atom);
    }
}

fn shrinkAtom(self: *MachO, atom: *Atom, new_block_size: u64) void {
    _ = self;
    _ = atom;
    _ = new_block_size;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn growAtom(self: *MachO, atom: *Atom, new_atom_size: u64, alignment: u64) !u64 {
    const sym = atom.getSymbol(self);
    const align_ok = mem.alignBackwardGeneric(u64, sym.n_value, alignment) == sym.n_value;
    const need_realloc = !align_ok or new_atom_size > atom.capacity(self);
    if (!need_realloc) return sym.n_value;
    return self.allocateAtom(atom, new_atom_size, alignment);
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

pub fn allocateGotEntry(self: *MachO, target: SymbolWithLoc) !u32 {
    const gpa = self.base.allocator;
    try self.got_entries.ensureUnusedCapacity(gpa, 1);

    const index = blk: {
        if (self.got_entries_free_list.popOrNull()) |index| {
            log.debug("  (reusing GOT entry index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating GOT entry at index {d})", .{self.got_entries.items.len});
            const index = @intCast(u32, self.got_entries.items.len);
            _ = self.got_entries.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.got_entries.items[index] = .{ .target = target, .sym_index = 0 };
    try self.got_entries_table.putNoClobber(gpa, target, index);

    return index;
}

pub fn allocateStubEntry(self: *MachO, target: SymbolWithLoc) !u32 {
    try self.stubs.ensureUnusedCapacity(self.base.allocator, 1);

    const index = blk: {
        if (self.stubs_free_list.popOrNull()) |index| {
            log.debug("  (reusing stub entry index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating stub entry at index {d})", .{self.stubs.items.len});
            const index = @intCast(u32, self.stubs.items.len);
            _ = self.stubs.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.stubs.items[index] = .{ .target = target, .sym_index = 0 };
    try self.stubs_table.putNoClobber(self.base.allocator, target, index);

    return index;
}

pub fn allocateTlvPtrEntry(self: *MachO, target: SymbolWithLoc) !u32 {
    try self.tlv_ptr_entries.ensureUnusedCapacity(self.base.allocator, 1);

    const index = blk: {
        if (self.tlv_ptr_entries_free_list.popOrNull()) |index| {
            log.debug("  (reusing TLV ptr entry index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating TLV ptr entry at index {d})", .{self.tlv_ptr_entries.items.len});
            const index = @intCast(u32, self.tlv_ptr_entries.items.len);
            _ = self.tlv_ptr_entries.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.tlv_ptr_entries.items[index] = .{ .target = target, .sym_index = 0 };
    try self.tlv_ptr_entries_table.putNoClobber(self.base.allocator, target, index);

    return index;
}

pub fn allocateDeclIndexes(self: *MachO, decl_index: Module.Decl.Index) !void {
    if (self.llvm_object) |_| return;
    const decl = self.base.options.module.?.declPtr(decl_index);
    if (decl.link.macho.sym_index != 0) return;

    decl.link.macho.sym_index = try self.allocateSymbol();
    try self.atom_by_index_table.putNoClobber(self.base.allocator, decl.link.macho.sym_index, &decl.link.macho);
    try self.decls.putNoClobber(self.base.allocator, decl_index, null);
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
    self.freeUnnamedConsts(decl_index);

    // TODO clearing the code and relocs buffer should probably be orchestrated
    // in a different, smarter, more automatic way somewhere else, in a more centralised
    // way than this.
    // If we don't clear the buffers here, we are up for some nasty surprises when
    // this atom is reused later on and was not freed by freeAtom().
    decl.link.macho.clearRetainingCapacity();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(module, decl)
    else
        null;
    defer if (decl_state) |*ds| ds.deinit();

    const res = if (decl_state) |*ds|
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .{
            .dwarf = ds,
        })
    else
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .none);

    switch (res) {
        .appended => {
            try decl.link.macho.code.appendSlice(self.base.allocator, code_buffer.items);
        },
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    }

    const addr = try self.placeDecl(decl_index, decl.link.macho.code.items.len);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            &self.base,
            module,
            decl,
            addr,
            decl.link.macho.size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
    try self.updateDeclExports(module, decl_index, decl_exports);
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
        const name = try std.fmt.allocPrint(gpa, "__unnamed_{s}_{d}", .{ decl_name, index });
        defer gpa.free(name);
        break :blk try self.strtab.insert(gpa, name);
    };
    const name = self.strtab.get(name_str_index);

    log.debug("allocating symbol indexes for {?s}", .{name});

    const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);
    const sym_index = try self.allocateSymbol();
    const atom = try MachO.createEmptyAtom(
        gpa,
        sym_index,
        @sizeOf(u64),
        math.log2(required_alignment),
    );

    try self.managed_atoms.append(gpa, atom);
    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);

    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), typed_value, &code_buffer, .none, .{
        .parent_atom_index = sym_index,
    });
    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            log.err("{s}", .{em.msg});
            return error.AnalysisFail;
        },
    };

    atom.code.clearRetainingCapacity();
    try atom.code.appendSlice(gpa, code);

    const sect_id = try self.getOutputSectionAtom(
        atom,
        decl_name,
        typed_value.ty,
        typed_value.val,
        required_alignment,
    );
    const symbol = atom.getSymbolPtr(self);
    symbol.n_strx = name_str_index;
    symbol.n_type = macho.N_SECT;
    symbol.n_sect = sect_id + 1;
    symbol.n_value = try self.allocateAtom(atom, code.len, required_alignment);

    log.debug("allocated atom for {?s} at 0x{x}", .{ name, symbol.n_value });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    errdefer self.freeAtom(atom, true);

    try unnamed_consts.append(gpa, atom);

    return atom.sym_index;
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

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.d_sym) |*d_sym|
        try d_sym.dwarf.initDeclState(module, decl)
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
            .parent_atom_index = decl.link.macho.sym_index,
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .none, .{
            .parent_atom_index = decl.link.macho.sym_index,
        });

    const code = blk: {
        switch (res) {
            .externally_managed => |x| break :blk x,
            .appended => {
                // TODO clearing the code and relocs buffer should probably be orchestrated
                // in a different, smarter, more automatic way somewhere else, in a more centralised
                // way than this.
                // If we don't clear the buffers here, we are up for some nasty surprises when
                // this atom is reused later on and was not freed by freeAtom().
                decl.link.macho.code.clearAndFree(self.base.allocator);
                try decl.link.macho.code.appendSlice(self.base.allocator, code_buffer.items);
                break :blk decl.link.macho.code.items;
            },
            .fail => |em| {
                decl.analysis = .codegen_failure;
                try module.failed_decls.put(module.gpa, decl_index, em);
                return;
            },
        }
    };
    const addr = try self.placeDecl(decl_index, code.len);

    if (decl_state) |*ds| {
        try self.d_sym.?.dwarf.commitDeclState(
            &self.base,
            module,
            decl,
            addr,
            decl.link.macho.size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
    try self.updateDeclExports(module, decl_index, decl_exports);
}

/// Checks if the value, or any of its embedded values stores a pointer, and thus requires
/// a rebase opcode for the dynamic linker.
fn needsPointerRebase(ty: Type, val: Value, mod: *Module) bool {
    if (ty.zigTypeTag() == .Fn) {
        return false;
    }
    if (val.pointerDecl()) |_| {
        return true;
    }

    switch (ty.zigTypeTag()) {
        .Fn => unreachable,
        .Pointer => return true,
        .Array, .Vector => {
            if (ty.arrayLen() == 0) return false;
            const elem_ty = ty.childType();
            var elem_value_buf: Value.ElemValueBuffer = undefined;
            const elem_val = val.elemValueBuffer(mod, 0, &elem_value_buf);
            return needsPointerRebase(elem_ty, elem_val, mod);
        },
        .Struct => {
            const fields = ty.structFields().values();
            if (fields.len == 0) return false;
            if (val.castTag(.aggregate)) |payload| {
                const field_values = payload.data;
                for (field_values) |field_val, i| {
                    if (needsPointerRebase(fields[i].ty, field_val, mod)) return true;
                } else return false;
            } else return false;
        },
        .Optional => {
            if (val.castTag(.opt_payload)) |payload| {
                const sub_val = payload.data;
                var buffer: Type.Payload.ElemType = undefined;
                const sub_ty = ty.optionalChild(&buffer);
                return needsPointerRebase(sub_ty, sub_val, mod);
            } else return false;
        },
        .Union => {
            const union_obj = val.cast(Value.Payload.Union).?.data;
            const active_field_ty = ty.unionFieldType(union_obj.tag, mod);
            return needsPointerRebase(active_field_ty, union_obj.val, mod);
        },
        .ErrorUnion => {
            if (val.castTag(.eu_payload)) |payload| {
                const payload_ty = ty.errorUnionPayload();
                return needsPointerRebase(payload_ty, payload.data, mod);
            } else return false;
        },
        else => return false,
    }
}

fn getOutputSectionAtom(
    self: *MachO,
    atom: *Atom,
    name: []const u8,
    ty: Type,
    val: Value,
    alignment: u32,
) !u8 {
    const code = atom.code.items;
    const mod = self.base.options.module.?;
    const align_log_2 = math.log2(alignment);
    const zig_ty = ty.zigTypeTag();
    const mode = self.base.options.optimize_mode;
    const sect_id: u8 = blk: {
        // TODO finish and audit this function
        if (val.isUndefDeep()) {
            if (mode == .ReleaseFast or mode == .ReleaseSmall) {
                break :blk (try self.getOutputSection(.{
                    .segname = makeStaticString("__DATA"),
                    .sectname = makeStaticString("__bss"),
                    .size = code.len,
                    .@"align" = align_log_2,
                })).?;
            } else {
                break :blk self.data_section_index.?;
            }
        }

        if (val.castTag(.variable)) |_| {
            break :blk self.data_section_index.?;
        }

        if (needsPointerRebase(ty, val, mod)) {
            break :blk (try self.getOutputSection(.{
                .segname = makeStaticString("__DATA_CONST"),
                .sectname = makeStaticString("__const"),
                .size = code.len,
                .@"align" = align_log_2,
            })).?;
        }

        switch (zig_ty) {
            .Fn => {
                break :blk self.text_section_index.?;
            },
            .Array => {
                if (val.tag() == .bytes) {
                    switch (ty.tag()) {
                        .array_u8_sentinel_0,
                        .const_slice_u8_sentinel_0,
                        .manyptr_const_u8_sentinel_0,
                        => {
                            break :blk (try self.getOutputSection(.{
                                .segname = makeStaticString("__TEXT"),
                                .sectname = makeStaticString("__cstring"),
                                .flags = macho.S_CSTRING_LITERALS,
                                .size = code.len,
                                .@"align" = align_log_2,
                            })).?;
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }
        break :blk (try self.getOutputSection(.{
            .segname = makeStaticString("__TEXT"),
            .sectname = makeStaticString("__const"),
            .size = code.len,
            .@"align" = align_log_2,
        })).?;
    };
    const header = self.sections.items(.header)[sect_id];
    log.debug("  allocating atom '{s}' in '{s},{s}', ord({d})", .{
        name,
        header.segName(),
        header.sectName(),
        sect_id,
    });
    return sect_id;
}

fn placeDecl(self: *MachO, decl_index: Module.Decl.Index, code_len: usize) !u64 {
    const module = self.base.options.module.?;
    const decl = module.declPtr(decl_index);
    const required_alignment = decl.getAlignment(self.base.options.target);
    assert(decl.link.macho.sym_index != 0); // Caller forgot to call allocateDeclIndexes()

    const sym_name = try decl.getFullyQualifiedName(module);
    defer self.base.allocator.free(sym_name);

    const decl_ptr = self.decls.getPtr(decl_index).?;
    if (decl_ptr.* == null) {
        decl_ptr.* = try self.getOutputSectionAtom(
            &decl.link.macho,
            sym_name,
            decl.ty,
            decl.val,
            required_alignment,
        );
    }
    const sect_id = decl_ptr.*.?;

    if (decl.link.macho.size != 0) {
        const symbol = decl.link.macho.getSymbolPtr(self);
        symbol.n_strx = try self.strtab.insert(self.base.allocator, sym_name);
        symbol.n_type = macho.N_SECT;
        symbol.n_sect = sect_id + 1;
        symbol.n_desc = 0;

        const capacity = decl.link.macho.capacity(self);
        const need_realloc = code_len > capacity or !mem.isAlignedGeneric(u64, symbol.n_value, required_alignment);

        if (need_realloc) {
            const vaddr = try self.growAtom(&decl.link.macho, code_len, required_alignment);
            log.debug("growing {s} and moving from 0x{x} to 0x{x}", .{ sym_name, symbol.n_value, vaddr });
            log.debug("  (required alignment 0x{x})", .{required_alignment});
            symbol.n_value = vaddr;

            const got_atom = self.getGotAtomForSymbol(.{
                .sym_index = decl.link.macho.sym_index,
                .file = null,
            }).?;
            got_atom.dirty = true;
        } else if (code_len < decl.link.macho.size) {
            self.shrinkAtom(&decl.link.macho, code_len);
        }

        decl.link.macho.size = code_len;
        decl.link.macho.dirty = true;
    } else {
        const name_str_index = try self.strtab.insert(self.base.allocator, sym_name);
        const symbol = decl.link.macho.getSymbolPtr(self);
        symbol.n_strx = name_str_index;
        symbol.n_type = macho.N_SECT;
        symbol.n_sect = sect_id + 1;
        symbol.n_desc = 0;
        symbol.n_value = try self.allocateAtom(&decl.link.macho, code_len, required_alignment);

        log.debug("allocated atom for {s} at 0x{x}", .{ sym_name, symbol.n_value });
        log.debug("  (required alignment 0x{x})", .{required_alignment});

        errdefer self.freeAtom(&decl.link.macho, false);

        const got_target = SymbolWithLoc{ .sym_index = decl.link.macho.sym_index, .file = null };
        const got_index = try self.allocateGotEntry(got_target);
        const got_atom = try self.createGotAtom(got_target);
        self.got_entries.items[got_index].sym_index = got_atom.sym_index;
    }

    return decl.link.macho.getSymbol(self).n_value;
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {
    _ = module;
    if (self.d_sym) |*d_sym| {
        try d_sym.dwarf.updateDeclLineNumber(&self.base, decl);
    }
}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
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
    if (decl.link.macho.sym_index == 0) return;
    const decl_sym = decl.link.macho.getSymbol(self);

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

        const sym_index = exp.link.macho.sym_index orelse blk: {
            const sym_index = try self.allocateSymbol();
            exp.link.macho.sym_index = sym_index;
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
                const global = self.getGlobal(exp_name).?;
                if (sym_loc.sym_index != global.sym_index and global.file != null) {
                    _ = try module.failed_exports.put(module.gpa, exp, try Module.ErrorMsg.create(
                        gpa,
                        decl.srcLoc(),
                        \\LinkError: symbol '{s}' defined multiple times
                        \\  first definition in '{s}'
                    ,
                        .{ exp_name, self.objects.items[global.file.?].name },
                    ));
                }
            },
            else => |e| return e,
        };
    }
}

pub fn deleteExport(self: *MachO, exp: Export) void {
    if (self.llvm_object) |_| return;
    const sym_index = exp.sym_index orelse return;

    const gpa = self.base.allocator;

    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    const sym = self.getSymbolPtr(sym_loc);
    const sym_name = self.getSymbolName(sym_loc);
    log.debug("deleting export '{s}'", .{sym_name});
    assert(sym.sect() and sym.ext());
    sym.* = .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    self.locals_free_list.append(gpa, sym_index) catch {};

    if (self.resolver.fetchRemove(sym_name)) |entry| {
        defer gpa.free(entry.key);
        self.globals_free_list.append(gpa, entry.value) catch {};
        self.globals.items[entry.value] = .{
            .sym_index = 0,
            .file = null,
        };
    }
}

fn freeUnnamedConsts(self: *MachO, decl_index: Module.Decl.Index) void {
    const unnamed_consts = self.unnamed_const_atoms.getPtr(decl_index) orelse return;
    for (unnamed_consts.items) |atom| {
        self.freeAtom(atom, true);
        self.locals_free_list.append(self.base.allocator, atom.sym_index) catch {};
        self.locals.items[atom.sym_index].n_type = 0;
        _ = self.atom_by_index_table.remove(atom.sym_index);
        log.debug("  adding local symbol index {d} to free list", .{atom.sym_index});
        atom.sym_index = 0;
    }
    unnamed_consts.clearAndFree(self.base.allocator);
}

pub fn freeDecl(self: *MachO, decl_index: Module.Decl.Index) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    }
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    log.debug("freeDecl {*}", .{decl});
    const kv = self.decls.fetchSwapRemove(decl_index);
    if (kv.?.value) |_| {
        self.freeAtom(&decl.link.macho, false);
        self.freeUnnamedConsts(decl_index);
    }
    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    if (decl.link.macho.sym_index != 0) {
        self.locals_free_list.append(self.base.allocator, decl.link.macho.sym_index) catch {};

        // Try freeing GOT atom if this decl had one
        const got_target = SymbolWithLoc{ .sym_index = decl.link.macho.sym_index, .file = null };
        if (self.got_entries_table.get(got_target)) |got_index| {
            self.got_entries_free_list.append(self.base.allocator, @intCast(u32, got_index)) catch {};
            self.got_entries.items[got_index] = .{
                .target = .{ .sym_index = 0, .file = null },
                .sym_index = 0,
            };
            _ = self.got_entries_table.remove(got_target);

            if (self.d_sym) |*d_sym| {
                d_sym.swapRemoveRelocs(decl.link.macho.sym_index);
            }

            log.debug("  adding GOT index {d} to free list (target local@{d})", .{
                got_index,
                decl.link.macho.sym_index,
            });
        }

        self.locals.items[decl.link.macho.sym_index].n_type = 0;
        _ = self.atom_by_index_table.remove(decl.link.macho.sym_index);
        log.debug("  adding local symbol index {d} to free list", .{decl.link.macho.sym_index});
        decl.link.macho.sym_index = 0;
    }
    if (self.d_sym) |*d_sym| {
        d_sym.dwarf.freeDecl(decl);
    }
}

pub fn getDeclVAddr(self: *MachO, decl_index: Module.Decl.Index, reloc_info: File.RelocInfo) !u64 {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    assert(self.llvm_object == null);
    assert(decl.link.macho.sym_index != 0);

    const atom = self.atom_by_index_table.get(reloc_info.parent_atom_index).?;
    try atom.relocs.append(self.base.allocator, .{
        .offset = @intCast(u32, reloc_info.offset),
        .target = .{ .sym_index = decl.link.macho.sym_index, .file = null },
        .addend = reloc_info.addend,
        .subtractor = null,
        .pcrel = false,
        .length = 3,
        .@"type" = switch (self.base.options.target.cpu.arch) {
            .aarch64 => @enumToInt(macho.reloc_type_arm64.ARM64_RELOC_UNSIGNED),
            .x86_64 => @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_UNSIGNED),
            else => unreachable,
        },
    });
    try atom.rebases.append(self.base.allocator, reloc_info.offset);

    return 0;
}

pub fn populateMissingMetadata(self: *MachO) !void {
    const gpa = self.base.allocator;
    const cpu_arch = self.base.options.target.cpu.arch;
    const pagezero_vmsize = self.base.options.pagezero_size orelse default_pagezero_vmsize;
    const aligned_pagezero_vmsize = mem.alignBackwardGeneric(u64, pagezero_vmsize, self.page_size);

    if (self.pagezero_segment_cmd_index == null) blk: {
        if (self.base.options.output_mode == .Lib) break :blk;
        if (aligned_pagezero_vmsize == 0) break :blk;
        if (aligned_pagezero_vmsize != pagezero_vmsize) {
            log.warn("requested __PAGEZERO size (0x{x}) is not page aligned", .{pagezero_vmsize});
            log.warn("  rounding down to 0x{x}", .{aligned_pagezero_vmsize});
        }
        self.pagezero_segment_cmd_index = @intCast(u8, self.segments.items.len);
        try self.segments.append(gpa, .{
            .segname = makeStaticString("__PAGEZERO"),
            .vmsize = aligned_pagezero_vmsize,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (self.text_segment_cmd_index == null) {
        self.text_segment_cmd_index = @intCast(u8, self.segments.items.len);
        const needed_size = if (self.mode == .incremental) blk: {
            const headerpad_size = @maximum(self.base.options.headerpad_size orelse 0, default_headerpad_size);
            const program_code_size_hint = self.base.options.program_code_size_hint;
            const got_size_hint = @sizeOf(u64) * self.base.options.symbol_count_hint;
            const ideal_size = headerpad_size + program_code_size_hint + got_size_hint;
            const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);
            log.debug("found __TEXT segment free space 0x{x} to 0x{x}", .{ 0, needed_size });
            break :blk needed_size;
        } else 0;
        try self.segments.append(gpa, .{
            .segname = makeStaticString("__TEXT"),
            .vmaddr = aligned_pagezero_vmsize,
            .vmsize = needed_size,
            .filesize = needed_size,
            .maxprot = macho.PROT.READ | macho.PROT.EXEC,
            .initprot = macho.PROT.READ | macho.PROT.EXEC,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (self.text_section_index == null) {
        const alignment: u2 = switch (cpu_arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const needed_size = if (self.mode == .incremental) self.base.options.program_code_size_hint else 0;
        self.text_section_index = try self.initSection(
            "__TEXT",
            "__text",
            needed_size,
            alignment,
            .{
                .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            },
        );
    }

    if (self.stubs_section_index == null) {
        const alignment: u2 = switch (cpu_arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const stub_size: u4 = switch (cpu_arch) {
            .x86_64 => 6,
            .aarch64 => 3 * @sizeOf(u32),
            else => unreachable, // unhandled architecture type
        };
        const needed_size = if (self.mode == .incremental) stub_size * self.base.options.symbol_count_hint else 0;
        self.stubs_section_index = try self.initSection(
            "__TEXT",
            "__stubs",
            needed_size,
            alignment,
            .{
                .flags = macho.S_SYMBOL_STUBS | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
                .reserved2 = stub_size,
            },
        );
    }

    if (self.stub_helper_section_index == null) {
        const alignment: u2 = switch (cpu_arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const preamble_size: u6 = switch (cpu_arch) {
            .x86_64 => 15,
            .aarch64 => 6 * @sizeOf(u32),
            else => unreachable,
        };
        const stub_size: u4 = switch (cpu_arch) {
            .x86_64 => 10,
            .aarch64 => 3 * @sizeOf(u32),
            else => unreachable,
        };
        const needed_size = if (self.mode == .incremental)
            stub_size * self.base.options.symbol_count_hint + preamble_size
        else
            0;
        self.stub_helper_section_index = try self.initSection(
            "__TEXT",
            "__stub_helper",
            needed_size,
            alignment,
            .{
                .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            },
        );
    }

    if (self.data_const_segment_cmd_index == null) {
        self.data_const_segment_cmd_index = @intCast(u8, self.segments.items.len);
        var vmaddr: u64 = 0;
        var fileoff: u64 = 0;
        var needed_size: u64 = 0;
        if (self.mode == .incremental) {
            const base = self.getSegmentAllocBase(&.{self.text_segment_cmd_index.?});
            vmaddr = base.vmaddr;
            fileoff = base.fileoff;
            const ideal_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
            needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);
            log.debug("found __DATA_CONST segment free space 0x{x} to 0x{x}", .{
                fileoff,
                fileoff + needed_size,
            });
        }
        try self.segments.append(gpa, .{
            .segname = makeStaticString("__DATA_CONST"),
            .vmaddr = vmaddr,
            .vmsize = needed_size,
            .fileoff = fileoff,
            .filesize = needed_size,
            .maxprot = macho.PROT.READ | macho.PROT.WRITE,
            .initprot = macho.PROT.READ | macho.PROT.WRITE,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (self.got_section_index == null) {
        const needed_size = if (self.mode == .incremental)
            @sizeOf(u64) * self.base.options.symbol_count_hint
        else
            0;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.got_section_index = try self.initSection(
            "__DATA_CONST",
            "__got",
            needed_size,
            alignment,
            .{
                .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
            },
        );
    }

    if (self.data_segment_cmd_index == null) {
        self.data_segment_cmd_index = @intCast(u8, self.segments.items.len);
        var vmaddr: u64 = 0;
        var fileoff: u64 = 0;
        var needed_size: u64 = 0;
        if (self.mode == .incremental) {
            const base = self.getSegmentAllocBase(&.{self.data_const_segment_cmd_index.?});
            vmaddr = base.vmaddr;
            fileoff = base.fileoff;
            const ideal_size = 2 * @sizeOf(u64) * self.base.options.symbol_count_hint;
            needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);
            log.debug("found __DATA segment free space 0x{x} to 0x{x}", .{
                fileoff,
                fileoff + needed_size,
            });
        }
        try self.segments.append(gpa, .{
            .segname = makeStaticString("__DATA"),
            .vmaddr = vmaddr,
            .vmsize = needed_size,
            .fileoff = fileoff,
            .filesize = needed_size,
            .maxprot = macho.PROT.READ | macho.PROT.WRITE,
            .initprot = macho.PROT.READ | macho.PROT.WRITE,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (self.la_symbol_ptr_section_index == null) {
        const needed_size = if (self.mode == .incremental)
            @sizeOf(u64) * self.base.options.symbol_count_hint
        else
            0;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.la_symbol_ptr_section_index = try self.initSection(
            "__DATA",
            "__la_symbol_ptr",
            needed_size,
            alignment,
            .{
                .flags = macho.S_LAZY_SYMBOL_POINTERS,
            },
        );
    }

    if (self.data_section_index == null) {
        const needed_size = if (self.mode == .incremental)
            @sizeOf(u64) * self.base.options.symbol_count_hint
        else
            0;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.data_section_index = try self.initSection(
            "__DATA",
            "__data",
            needed_size,
            alignment,
            .{},
        );
    }

    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @intCast(u8, self.segments.items.len);
        var vmaddr: u64 = 0;
        var fileoff: u64 = 0;
        if (self.mode == .incremental) {
            const base = self.getSegmentAllocBase(&.{self.data_segment_cmd_index.?});
            vmaddr = base.vmaddr;
            fileoff = base.fileoff;
            log.debug("found __LINKEDIT segment free space at 0x{x}", .{fileoff});
        }
        try self.segments.append(gpa, .{
            .segname = makeStaticString("__LINKEDIT"),
            .vmaddr = vmaddr,
            .fileoff = fileoff,
            .maxprot = macho.PROT.READ,
            .initprot = macho.PROT.READ,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }
}

inline fn calcInstallNameLen(cmd_size: u64, name: []const u8, assume_max_path_len: bool) u64 {
    const name_len = if (assume_max_path_len) std.os.PATH_MAX else std.mem.len(name) + 1;
    return mem.alignForwardGeneric(u64, cmd_size + name_len, @alignOf(u64));
}

fn calcLCsSize(self: *MachO, assume_max_path_len: bool) !u32 {
    const gpa = self.base.allocator;
    var sizeofcmds: u64 = 0;
    for (self.segments.items) |seg| {
        sizeofcmds += seg.nsects * @sizeOf(macho.section_64) + @sizeOf(macho.segment_command_64);
    }

    // LC_DYLD_INFO_ONLY
    sizeofcmds += @sizeOf(macho.dyld_info_command);
    // LC_FUNCTION_STARTS
    if (self.text_section_index != null) {
        sizeofcmds += @sizeOf(macho.linkedit_data_command);
    }
    // LC_DATA_IN_CODE
    sizeofcmds += @sizeOf(macho.linkedit_data_command);
    // LC_SYMTAB
    sizeofcmds += @sizeOf(macho.symtab_command);
    // LC_DYSYMTAB
    sizeofcmds += @sizeOf(macho.dysymtab_command);
    // LC_LOAD_DYLINKER
    sizeofcmds += calcInstallNameLen(
        @sizeOf(macho.dylinker_command),
        mem.sliceTo(default_dyld_path, 0),
        false,
    );
    // LC_MAIN
    if (self.base.options.output_mode == .Exe) {
        sizeofcmds += @sizeOf(macho.entry_point_command);
    }
    // LC_ID_DYLIB
    if (self.base.options.output_mode == .Lib) {
        sizeofcmds += blk: {
            const install_name = self.base.options.install_name orelse self.base.options.emit.?.sub_path;
            break :blk calcInstallNameLen(
                @sizeOf(macho.dylib_command),
                install_name,
                assume_max_path_len,
            );
        };
    }
    // LC_RPATH
    {
        var it = RpathIterator.init(gpa, self.base.options.rpath_list);
        defer it.deinit();
        while (try it.next()) |rpath| {
            sizeofcmds += calcInstallNameLen(
                @sizeOf(macho.rpath_command),
                rpath,
                assume_max_path_len,
            );
        }
    }
    // LC_SOURCE_VERSION
    sizeofcmds += @sizeOf(macho.source_version_command);
    // LC_BUILD_VERSION
    sizeofcmds += @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    // LC_UUID
    sizeofcmds += @sizeOf(macho.uuid_command);
    // LC_LOAD_DYLIB
    for (self.referenced_dylibs.keys()) |id| {
        const dylib = self.dylibs.items[id];
        const dylib_id = dylib.id orelse unreachable;
        sizeofcmds += calcInstallNameLen(
            @sizeOf(macho.dylib_command),
            dylib_id.name,
            assume_max_path_len,
        );
    }
    // LC_CODE_SIGNATURE
    {
        const target = self.base.options.target;
        const requires_codesig = blk: {
            if (self.base.options.entitlements) |_| break :blk true;
            if (target.cpu.arch == .aarch64 and (target.os.tag == .macos or target.abi == .simulator))
                break :blk true;
            break :blk false;
        };
        if (requires_codesig) {
            sizeofcmds += @sizeOf(macho.linkedit_data_command);
        }
    }

    return @intCast(u32, sizeofcmds);
}

pub fn calcMinHeaderPad(self: *MachO) !u64 {
    var padding: u32 = (try self.calcLCsSize(false)) + (self.base.options.headerpad_size orelse 0);
    log.debug("minimum requested headerpad size 0x{x}", .{padding + @sizeOf(macho.mach_header_64)});

    if (self.base.options.headerpad_max_install_names) {
        var min_headerpad_size: u32 = try self.calcLCsSize(true);
        log.debug("headerpad_max_install_names minimum headerpad size 0x{x}", .{
            min_headerpad_size + @sizeOf(macho.mach_header_64),
        });
        padding = @maximum(padding, min_headerpad_size);
    }
    const offset = @sizeOf(macho.mach_header_64) + padding;
    log.debug("actual headerpad size 0x{x}", .{offset});

    return offset;
}

const InitSectionOpts = struct {
    flags: u32 = macho.S_REGULAR,
    reserved1: u32 = 0,
    reserved2: u32 = 0,
};

fn initSection(
    self: *MachO,
    segname: []const u8,
    sectname: []const u8,
    size: u64,
    alignment: u32,
    opts: InitSectionOpts,
) !u8 {
    const segment_id = self.getSegmentByName(segname).?;
    const seg = &self.segments.items[segment_id];
    const index = try self.insertSection(segment_id, .{
        .sectname = makeStaticString(sectname),
        .segname = seg.segname,
        .flags = opts.flags,
        .reserved1 = opts.reserved1,
        .reserved2 = opts.reserved2,
    });
    seg.cmdsize += @sizeOf(macho.section_64);
    seg.nsects += 1;

    if (self.mode == .incremental) {
        const header = &self.sections.items(.header)[index];
        header.size = size;
        header.@"align" = alignment;

        const prev_end_off = if (index > 0) blk: {
            const prev_section = self.sections.get(index - 1);
            if (prev_section.segment_index == segment_id) {
                const prev_header = prev_section.header;
                break :blk prev_header.offset + padToIdeal(prev_header.size);
            } else break :blk seg.fileoff;
        } else 0;
        const alignment_pow_2 = try math.powi(u32, 2, alignment);
        // TODO better prealloc for __text section
        // const padding: u64 = if (index == 0) try self.calcMinHeaderPad() else 0;
        const padding: u64 = if (index == 0) 0x1000 else 0;
        const off = mem.alignForwardGeneric(u64, padding + prev_end_off, alignment_pow_2);

        if (!header.isZerofill()) {
            header.offset = @intCast(u32, off);
        }
        header.addr = seg.vmaddr + off - seg.fileoff;

        // TODO Will this break if we are inserting section that is not the last section
        // in a segment?
        const max_size = self.allocatedSize(segment_id, off);

        if (size > max_size) {
            try self.growSection(index, @intCast(u32, size));
        }

        log.debug("allocating {s},{s} section at 0x{x}", .{ header.segName(), header.sectName(), off });

        self.updateSectionOrdinals(index + 1);
    }

    return index;
}

fn getSectionPrecedence(header: macho.section_64) u4 {
    if (header.isCode()) {
        if (mem.eql(u8, "__text", header.sectName())) return 0x0;
        if (header.@"type"() == macho.S_SYMBOL_STUBS) return 0x1;
        return 0x2;
    }
    switch (header.@"type"()) {
        macho.S_NON_LAZY_SYMBOL_POINTERS,
        macho.S_LAZY_SYMBOL_POINTERS,
        => return 0x0,
        macho.S_MOD_INIT_FUNC_POINTERS => return 0x1,
        macho.S_MOD_TERM_FUNC_POINTERS => return 0x2,
        macho.S_ZEROFILL => return 0xf,
        macho.S_THREAD_LOCAL_REGULAR => return 0xd,
        macho.S_THREAD_LOCAL_ZEROFILL => return 0xe,
        else => if (mem.eql(u8, "__eh_frame", header.sectName()))
            return 0xf
        else
            return 0x3,
    }
}

fn insertSection(self: *MachO, segment_index: u8, header: macho.section_64) !u8 {
    const precedence = getSectionPrecedence(header);
    const indexes = self.getSectionIndexes(segment_index);
    const insertion_index = for (self.sections.items(.header)[indexes.start..indexes.end]) |hdr, i| {
        if (getSectionPrecedence(hdr) > precedence) break @intCast(u8, i + indexes.start);
    } else indexes.end;
    log.debug("inserting section '{s},{s}' at index {d}", .{
        header.segName(),
        header.sectName(),
        insertion_index,
    });
    for (&[_]*?u8{
        &self.text_section_index,
        &self.stubs_section_index,
        &self.stub_helper_section_index,
        &self.got_section_index,
        &self.la_symbol_ptr_section_index,
        &self.data_section_index,
    }) |maybe_index| {
        const index = maybe_index.* orelse continue;
        if (insertion_index <= index) maybe_index.* = index + 1;
    }
    try self.sections.insert(self.base.allocator, insertion_index, .{
        .segment_index = segment_index,
        .header = header,
    });
    return insertion_index;
}

fn updateSectionOrdinals(self: *MachO, start: u8) void {
    const tracy = trace(@src());
    defer tracy.end();

    const slice = self.sections.slice();
    for (slice.items(.last_atom)[start..]) |last_atom| {
        var atom = last_atom orelse continue;

        while (true) {
            const sym = atom.getSymbolPtr(self);
            sym.n_sect = start + 1;

            for (atom.contained.items) |sym_at_off| {
                const contained_sym = self.getSymbolPtr(.{
                    .sym_index = sym_at_off.sym_index,
                    .file = atom.file,
                });
                contained_sym.n_sect = start + 1;
            }

            if (atom.prev) |prev| {
                atom = prev;
            } else break;
        }
    }
}

fn shiftLocalsByOffset(self: *MachO, sect_id: u8, offset: i64) !void {
    var atom = self.sections.items(.last_atom)[sect_id] orelse return;

    while (true) {
        const atom_sym = atom.getSymbolPtr(self);
        atom_sym.n_value = @intCast(u64, @intCast(i64, atom_sym.n_value) + offset);

        for (atom.contained.items) |sym_at_off| {
            const contained_sym = self.getSymbolPtr(.{
                .sym_index = sym_at_off.sym_index,
                .file = atom.file,
            });
            contained_sym.n_value = @intCast(u64, @intCast(i64, contained_sym.n_value) + offset);
        }

        if (atom.prev) |prev| {
            atom = prev;
        } else break;
    }
}

fn growSegment(self: *MachO, segment_index: u8, new_size: u64) !void {
    const segment = &self.segments.items[segment_index];
    const new_segment_size = mem.alignForwardGeneric(u64, new_size, self.page_size);
    assert(new_segment_size > segment.filesize);
    const offset_amt = new_segment_size - segment.filesize;
    log.debug("growing segment {s} from 0x{x} to 0x{x}", .{
        segment.segname,
        segment.filesize,
        new_segment_size,
    });
    segment.filesize = new_segment_size;
    segment.vmsize = new_segment_size;

    log.debug("  (new segment file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
        segment.fileoff,
        segment.fileoff + segment.filesize,
        segment.vmaddr,
        segment.vmaddr + segment.vmsize,
    });

    var next: u8 = segment_index + 1;
    while (next < self.linkedit_segment_cmd_index.? + 1) : (next += 1) {
        const next_segment = &self.segments.items[next];

        try MachO.copyRangeAllOverlappingAlloc(
            self.base.allocator,
            self.base.file.?,
            next_segment.fileoff,
            next_segment.fileoff + offset_amt,
            math.cast(usize, next_segment.filesize) orelse return error.Overflow,
        );

        next_segment.fileoff += offset_amt;
        next_segment.vmaddr += offset_amt;

        log.debug("  (new {s} segment file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
            next_segment.segname,
            next_segment.fileoff,
            next_segment.fileoff + next_segment.filesize,
            next_segment.vmaddr,
            next_segment.vmaddr + next_segment.vmsize,
        });

        const indexes = self.getSectionIndexes(next);
        for (self.sections.items(.header)[indexes.start..indexes.end]) |*header, i| {
            header.offset += @intCast(u32, offset_amt);
            header.addr += offset_amt;

            log.debug("  (new {s},{s} file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
                header.segName(),
                header.sectName(),
                header.offset,
                header.offset + header.size,
                header.addr,
                header.addr + header.size,
            });

            try self.shiftLocalsByOffset(@intCast(u8, i + indexes.start), @intCast(i64, offset_amt));
        }
    }
}

fn growSection(self: *MachO, sect_id: u8, new_size: u32) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const section = self.sections.get(sect_id);
    const segment_index = section.segment_index;
    const header = section.header;
    const segment = self.segments.items[segment_index];

    const alignment = try math.powi(u32, 2, header.@"align");
    const max_size = self.allocatedSize(segment_index, header.offset);
    const ideal_size = padToIdeal(new_size);
    const needed_size = mem.alignForwardGeneric(u32, ideal_size, alignment);

    if (needed_size > max_size) blk: {
        log.debug("  (need to grow! needed 0x{x}, max 0x{x})", .{ needed_size, max_size });

        const indexes = self.getSectionIndexes(segment_index);
        if (sect_id == indexes.end - 1) {
            // Last section, just grow segments
            try self.growSegment(segment_index, segment.filesize + needed_size - max_size);
            break :blk;
        }

        // Need to move all sections below in file and address spaces.
        const offset_amt = offset: {
            const max_alignment = try self.getSectionMaxAlignment(sect_id + 1, indexes.end);
            break :offset mem.alignForwardGeneric(u64, needed_size - max_size, max_alignment);
        };

        // Before we commit to this, check if the segment needs to grow too.
        // We assume that each section header is growing linearly with the increasing
        // file offset / virtual memory address space.
        const last_sect_header = self.sections.items(.header)[indexes.end - 1];
        const last_sect_off = last_sect_header.offset + last_sect_header.size;
        const seg_off = segment.fileoff + segment.filesize;

        if (last_sect_off + offset_amt > seg_off) {
            // Need to grow segment first.
            const spill_size = (last_sect_off + offset_amt) - seg_off;
            try self.growSegment(segment_index, segment.filesize + spill_size);
        }

        // We have enough space to expand within the segment, so move all sections by
        // the required amount and update their header offsets.
        const next_sect = self.sections.items(.header)[sect_id + 1];
        const total_size = last_sect_off - next_sect.offset;

        try MachO.copyRangeAllOverlappingAlloc(
            self.base.allocator,
            self.base.file.?,
            next_sect.offset,
            next_sect.offset + offset_amt,
            math.cast(usize, total_size) orelse return error.Overflow,
        );

        for (self.sections.items(.header)[sect_id + 1 .. indexes.end]) |*moved_sect, i| {
            moved_sect.offset += @intCast(u32, offset_amt);
            moved_sect.addr += offset_amt;

            log.debug("  (new {s},{s} file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
                moved_sect.segName(),
                moved_sect.sectName(),
                moved_sect.offset,
                moved_sect.offset + moved_sect.size,
                moved_sect.addr,
                moved_sect.addr + moved_sect.size,
            });

            try self.shiftLocalsByOffset(@intCast(u8, sect_id + 1 + i), @intCast(i64, offset_amt));
        }
    }
}

fn allocatedSize(self: MachO, segment_id: u8, start: u64) u64 {
    const segment = self.segments.items[segment_id];
    const indexes = self.getSectionIndexes(segment_id);
    assert(start >= segment.fileoff);
    var min_pos: u64 = segment.fileoff + segment.filesize;
    if (start > min_pos) return 0;
    for (self.sections.items(.header)[indexes.start..indexes.end]) |header| {
        if (header.offset <= start) continue;
        if (header.offset < min_pos) min_pos = header.offset;
    }
    return min_pos - start;
}

fn getSectionMaxAlignment(self: *MachO, start: u8, end: u8) !u32 {
    var max_alignment: u32 = 1;
    const slice = self.sections.slice();
    for (slice.items(.header)[start..end]) |header| {
        const alignment = try math.powi(u32, 2, header.@"align");
        max_alignment = math.max(max_alignment, alignment);
    }
    return max_alignment;
}

fn allocateAtomCommon(self: *MachO, atom: *Atom) !void {
    if (self.mode == .incremental) {
        const sym_name = atom.getName(self);
        const size = atom.size;
        const alignment = try math.powi(u32, 2, atom.alignment);
        const vaddr = try self.allocateAtom(atom, size, alignment);
        log.debug("allocated {s} atom at 0x{x}", .{ sym_name, vaddr });
        atom.getSymbolPtr(self).n_value = vaddr;
    } else try self.addAtomToSection(atom);
}

fn allocateAtom(self: *MachO, atom: *Atom, new_atom_size: u64, alignment: u64) !u64 {
    const tracy = trace(@src());
    defer tracy.end();

    const sect_id = atom.getSymbol(self).n_sect - 1;
    const header = &self.sections.items(.header)[sect_id];
    const free_list = &self.sections.items(.free_list)[sect_id];
    const maybe_last_atom = &self.sections.items(.last_atom)[sect_id];
    const new_atom_ideal_capacity = if (header.isCode()) padToIdeal(new_atom_size) else new_atom_size;

    // We use these to indicate our intention to update metadata, placing the new atom,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var atom_placement: ?*Atom = null;
    var free_list_removal: ?usize = null;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    var vaddr = blk: {
        var i: usize = 0;
        while (i < free_list.items.len) {
            const big_atom = free_list.items[i];
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const sym = big_atom.getSymbol(self);
            const capacity = big_atom.capacity(self);
            const ideal_capacity = if (header.isCode()) padToIdeal(capacity) else capacity;
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
            atom_placement = big_atom;
            if (!keep_free_list_node) {
                free_list_removal = i;
            }
            break :blk new_start_vaddr;
        } else if (maybe_last_atom.*) |last| {
            const last_symbol = last.getSymbol(self);
            const ideal_capacity = if (header.isCode()) padToIdeal(last.size) else last.size;
            const ideal_capacity_end_vaddr = last_symbol.n_value + ideal_capacity;
            const new_start_vaddr = mem.alignForwardGeneric(u64, ideal_capacity_end_vaddr, alignment);
            atom_placement = last;
            break :blk new_start_vaddr;
        } else {
            break :blk mem.alignForwardGeneric(u64, header.addr, alignment);
        }
    };

    const expand_section = atom_placement == null or atom_placement.?.next == null;
    if (expand_section) {
        const needed_size = @intCast(u32, (vaddr + new_atom_size) - header.addr);
        try self.growSection(sect_id, needed_size);
        maybe_last_atom.* = atom;
        header.size = needed_size;
    }
    const align_pow = @intCast(u32, math.log2(alignment));
    if (header.@"align" < align_pow) {
        header.@"align" = align_pow;
    }
    atom.size = new_atom_size;
    atom.alignment = align_pow;

    if (atom.prev) |prev| {
        prev.next = atom.next;
    }
    if (atom.next) |next| {
        next.prev = atom.prev;
    }

    if (atom_placement) |big_atom| {
        atom.prev = big_atom;
        atom.next = big_atom.next;
        big_atom.next = atom;
    } else {
        atom.prev = null;
        atom.next = null;
    }
    if (free_list_removal) |i| {
        _ = free_list.swapRemove(i);
    }

    return vaddr;
}

pub fn addAtomToSection(self: *MachO, atom: *Atom) !void {
    const sect_id = atom.getSymbol(self).n_sect - 1;
    var section = self.sections.get(sect_id);
    if (section.header.size > 0) {
        section.last_atom.?.next = atom;
        atom.prev = section.last_atom.?;
    }
    section.last_atom = atom;
    const atom_alignment = try math.powi(u32, 2, atom.alignment);
    const aligned_end_addr = mem.alignForwardGeneric(u64, section.header.size, atom_alignment);
    const padding = aligned_end_addr - section.header.size;
    section.header.size += padding + atom.size;
    section.header.@"align" = @maximum(section.header.@"align", atom.alignment);
    self.sections.set(sect_id, section);
}

pub fn getGlobalSymbol(self: *MachO, name: []const u8) !u32 {
    const gpa = self.base.allocator;

    const sym_name = try std.fmt.allocPrint(gpa, "_{s}", .{name});
    defer gpa.free(sym_name);
    const gop = try self.getOrPutGlobalPtr(sym_name);
    const global_index = self.getGlobalIndex(sym_name).?;

    if (gop.found_existing) {
        return global_index;
    }

    const sym_index = try self.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    gop.value_ptr.* = sym_loc;

    const sym = self.getSymbolPtr(sym_loc);
    sym.n_strx = try self.strtab.insert(gpa, sym_name);

    try self.unresolved.putNoClobber(gpa, global_index, true);

    return global_index;
}

pub fn getSegmentAllocBase(self: MachO, indices: []const ?u8) struct { vmaddr: u64, fileoff: u64 } {
    for (indices) |maybe_prev_id| {
        const prev_id = maybe_prev_id orelse continue;
        const prev = self.segments.items[prev_id];
        return .{
            .vmaddr = prev.vmaddr + prev.vmsize,
            .fileoff = prev.fileoff + prev.filesize,
        };
    }
    return .{ .vmaddr = 0, .fileoff = 0 };
}

pub fn writeSegmentHeaders(self: *MachO, ncmds: *u32, writer: anytype) !void {
    for (self.segments.items) |seg, i| {
        const indexes = self.getSectionIndexes(@intCast(u8, i));
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

        ncmds.* += 1;
    }
}

pub fn writeLinkeditSegmentData(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    seg.filesize = 0;
    seg.vmsize = 0;

    try self.writeDyldInfoData(ncmds, lc_writer);
    try self.writeFunctionStarts(ncmds, lc_writer);
    try self.writeDataInCode(ncmds, lc_writer);
    try self.writeSymtabs(ncmds, lc_writer);

    seg.vmsize = mem.alignForwardGeneric(u64, seg.filesize, self.page_size);
}

pub fn writeDyldInfoData(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.allocator;

    var rebase_pointers = std.ArrayList(bind.Pointer).init(gpa);
    defer rebase_pointers.deinit();
    var bind_pointers = std.ArrayList(bind.Pointer).init(gpa);
    defer bind_pointers.deinit();
    var lazy_bind_pointers = std.ArrayList(bind.Pointer).init(gpa);
    defer lazy_bind_pointers.deinit();

    const slice = self.sections.slice();
    for (slice.items(.last_atom)) |last_atom, sect_id| {
        var atom = last_atom orelse continue;
        const segment_index = slice.items(.segment_index)[sect_id];
        const header = slice.items(.header)[sect_id];

        if (mem.eql(u8, header.segName(), "__TEXT")) continue; // __TEXT is non-writable

        log.debug("dyld info for {s},{s}", .{ header.segName(), header.sectName() });

        const seg = self.segments.items[segment_index];

        while (true) {
            log.debug("  ATOM(%{d}, '{s}')", .{ atom.sym_index, atom.getName(self) });
            const sym = atom.getSymbol(self);
            const base_offset = sym.n_value - seg.vmaddr;

            for (atom.rebases.items) |offset| {
                log.debug("    | rebase at {x}", .{base_offset + offset});
                try rebase_pointers.append(.{
                    .offset = base_offset + offset,
                    .segment_id = segment_index,
                });
            }

            for (atom.bindings.items) |binding| {
                const bind_sym = self.getSymbol(binding.target);
                const bind_sym_name = self.getSymbolName(binding.target);
                const dylib_ordinal = @divTrunc(
                    @bitCast(i16, bind_sym.n_desc),
                    macho.N_SYMBOL_RESOLVER,
                );
                var flags: u4 = 0;
                log.debug("    | bind at {x}, import('{s}') in dylib({d})", .{
                    binding.offset + base_offset,
                    bind_sym_name,
                    dylib_ordinal,
                });
                if (bind_sym.weakRef()) {
                    log.debug("    | marking as weak ref ", .{});
                    flags |= @truncate(u4, macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT);
                }
                try bind_pointers.append(.{
                    .offset = binding.offset + base_offset,
                    .segment_id = segment_index,
                    .dylib_ordinal = dylib_ordinal,
                    .name = bind_sym_name,
                    .bind_flags = flags,
                });
            }

            for (atom.lazy_bindings.items) |binding| {
                const bind_sym = self.getSymbol(binding.target);
                const bind_sym_name = self.getSymbolName(binding.target);
                const dylib_ordinal = @divTrunc(
                    @bitCast(i16, bind_sym.n_desc),
                    macho.N_SYMBOL_RESOLVER,
                );
                var flags: u4 = 0;
                log.debug("    | lazy bind at {x} import('{s}') ord({d})", .{
                    binding.offset + base_offset,
                    bind_sym_name,
                    dylib_ordinal,
                });
                if (bind_sym.weakRef()) {
                    log.debug("    | marking as weak ref ", .{});
                    flags |= @truncate(u4, macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT);
                }
                try lazy_bind_pointers.append(.{
                    .offset = binding.offset + base_offset,
                    .segment_id = segment_index,
                    .dylib_ordinal = dylib_ordinal,
                    .name = bind_sym_name,
                    .bind_flags = flags,
                });
            }

            if (atom.prev) |prev| {
                atom = prev;
            } else break;
        }
    }

    var trie: Trie = .{};
    defer trie.deinit(gpa);

    {
        // TODO handle macho.EXPORT_SYMBOL_FLAGS_REEXPORT and macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER.
        log.debug("generating export trie", .{});

        const text_segment = self.segments.items[self.text_segment_cmd_index.?];
        const base_address = text_segment.vmaddr;

        if (self.base.options.output_mode == .Exe) {
            for (&[_]SymbolWithLoc{
                try self.getEntryPoint(),
                self.getGlobal("__mh_execute_header").?,
            }) |global| {
                const sym = self.getSymbol(global);
                const sym_name = self.getSymbolName(global);
                log.debug("  (putting '{s}' defined at 0x{x})", .{ sym_name, sym.n_value });
                try trie.put(gpa, .{
                    .name = sym_name,
                    .vmaddr_offset = sym.n_value - base_address,
                    .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
                });
            }
        } else {
            assert(self.base.options.output_mode == .Lib);
            for (self.globals.items) |global| {
                const sym = self.getSymbol(global);

                if (sym.undf()) continue;
                if (!sym.ext()) continue;
                if (sym.n_desc == N_DESC_GCED) continue;

                const sym_name = self.getSymbolName(global);
                log.debug("  (putting '{s}' defined at 0x{x})", .{ sym_name, sym.n_value });
                try trie.put(gpa, .{
                    .name = sym_name,
                    .vmaddr_offset = sym.n_value - base_address,
                    .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
                });
            }
        }

        try trie.finalize(gpa);
    }

    const link_seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const rebase_off = mem.alignForwardGeneric(u64, link_seg.fileoff, @alignOf(u64));
    assert(rebase_off == link_seg.fileoff);
    const rebase_size = try bind.rebaseInfoSize(rebase_pointers.items);
    log.debug("writing rebase info from 0x{x} to 0x{x}", .{ rebase_off, rebase_off + rebase_size });

    const bind_off = mem.alignForwardGeneric(u64, rebase_off + rebase_size, @alignOf(u64));
    const bind_size = try bind.bindInfoSize(bind_pointers.items);
    log.debug("writing bind info from 0x{x} to 0x{x}", .{ bind_off, bind_off + bind_size });

    const lazy_bind_off = mem.alignForwardGeneric(u64, bind_off + bind_size, @alignOf(u64));
    const lazy_bind_size = try bind.lazyBindInfoSize(lazy_bind_pointers.items);
    log.debug("writing lazy bind info from 0x{x} to 0x{x}", .{ lazy_bind_off, lazy_bind_off + lazy_bind_size });

    const export_off = mem.alignForwardGeneric(u64, lazy_bind_off + lazy_bind_size, @alignOf(u64));
    const export_size = trie.size;
    log.debug("writing export trie from 0x{x} to 0x{x}", .{ export_off, export_off + export_size });

    const needed_size = export_off + export_size - rebase_off;
    link_seg.filesize = needed_size;

    var buffer = try gpa.alloc(u8, math.cast(usize, needed_size) orelse return error.Overflow);
    defer gpa.free(buffer);
    mem.set(u8, buffer, 0);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try bind.writeRebaseInfo(rebase_pointers.items, writer);
    try stream.seekTo(bind_off - rebase_off);

    try bind.writeBindInfo(bind_pointers.items, writer);
    try stream.seekTo(lazy_bind_off - rebase_off);

    try bind.writeLazyBindInfo(lazy_bind_pointers.items, writer);
    try stream.seekTo(export_off - rebase_off);

    _ = try trie.write(writer);

    log.debug("writing dyld info from 0x{x} to 0x{x}", .{
        rebase_off,
        rebase_off + needed_size,
    });

    try self.base.file.?.pwriteAll(buffer, rebase_off);
    const start = math.cast(usize, lazy_bind_off - rebase_off) orelse return error.Overflow;
    const end = start + (math.cast(usize, lazy_bind_size) orelse return error.Overflow);
    try self.populateLazyBindOffsetsInStubHelper(buffer[start..end]);

    try lc_writer.writeStruct(macho.dyld_info_command{
        .cmd = .DYLD_INFO_ONLY,
        .cmdsize = @sizeOf(macho.dyld_info_command),
        .rebase_off = @intCast(u32, rebase_off),
        .rebase_size = @intCast(u32, rebase_size),
        .bind_off = @intCast(u32, bind_off),
        .bind_size = @intCast(u32, bind_size),
        .weak_bind_off = 0,
        .weak_bind_size = 0,
        .lazy_bind_off = @intCast(u32, lazy_bind_off),
        .lazy_bind_size = @intCast(u32, lazy_bind_size),
        .export_off = @intCast(u32, export_off),
        .export_size = @intCast(u32, export_size),
    });
    ncmds.* += 1;
}

fn populateLazyBindOffsetsInStubHelper(self: *MachO, buffer: []const u8) !void {
    const gpa = self.base.allocator;

    const stub_helper_section_index = self.stub_helper_section_index orelse return;
    if (self.stub_helper_preamble_atom == null) return;

    const section = self.sections.get(stub_helper_section_index);
    const last_atom = section.last_atom orelse return;
    if (last_atom == self.stub_helper_preamble_atom.?) return; // TODO is this a redundant check?

    var table = std.AutoHashMap(i64, *Atom).init(gpa);
    defer table.deinit();

    {
        var stub_atom = last_atom;
        var laptr_atom = self.sections.items(.last_atom)[self.la_symbol_ptr_section_index.?].?;
        const base_addr = blk: {
            const seg = self.segments.items[self.data_segment_cmd_index.?];
            break :blk seg.vmaddr;
        };

        while (true) {
            const laptr_off = blk: {
                const sym = laptr_atom.getSymbol(self);
                break :blk @intCast(i64, sym.n_value - base_addr);
            };
            try table.putNoClobber(laptr_off, stub_atom);
            if (laptr_atom.prev) |prev| {
                laptr_atom = prev;
                stub_atom = stub_atom.prev.?;
            } else break;
        }
    }

    var stream = std.io.fixedBufferStream(buffer);
    var reader = stream.reader();
    var offsets = std.ArrayList(struct { sym_offset: i64, offset: u32 }).init(gpa);
    try offsets.append(.{ .sym_offset = undefined, .offset = 0 });
    defer offsets.deinit();
    var valid_block = false;

    while (true) {
        const inst = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
        };
        const opcode: u8 = inst & macho.BIND_OPCODE_MASK;

        switch (opcode) {
            macho.BIND_OPCODE_DO_BIND => {
                valid_block = true;
            },
            macho.BIND_OPCODE_DONE => {
                if (valid_block) {
                    const offset = try stream.getPos();
                    try offsets.append(.{ .sym_offset = undefined, .offset = @intCast(u32, offset) });
                }
                valid_block = false;
            },
            macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                var next = try reader.readByte();
                while (next != @as(u8, 0)) {
                    next = try reader.readByte();
                }
            },
            macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                var inserted = offsets.pop();
                inserted.sym_offset = try std.leb.readILEB128(i64, reader);
                try offsets.append(inserted);
            },
            macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => {
                _ = try std.leb.readULEB128(u64, reader);
            },
            macho.BIND_OPCODE_SET_ADDEND_SLEB => {
                _ = try std.leb.readILEB128(i64, reader);
            },
            else => {},
        }
    }

    const header = self.sections.items(.header)[stub_helper_section_index];
    const stub_offset: u4 = switch (self.base.options.target.cpu.arch) {
        .x86_64 => 1,
        .aarch64 => 2 * @sizeOf(u32),
        else => unreachable,
    };
    var buf: [@sizeOf(u32)]u8 = undefined;
    _ = offsets.pop();

    while (offsets.popOrNull()) |bind_offset| {
        const atom = table.get(bind_offset.sym_offset).?;
        const sym = atom.getSymbol(self);
        const file_offset = header.offset + sym.n_value - header.addr + stub_offset;
        mem.writeIntLittle(u32, &buf, bind_offset.offset);
        log.debug("writing lazy bind offset in stub helper of 0x{x} for symbol {s} at offset 0x{x}", .{
            bind_offset.offset,
            atom.getName(self),
            file_offset,
        });
        try self.base.file.?.pwriteAll(&buf, file_offset);
    }
}

const asc_u64 = std.sort.asc(u64);

fn writeFunctionStarts(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const text_seg_index = self.text_segment_cmd_index orelse return;
    const text_sect_index = self.text_section_index orelse return;
    const text_seg = self.segments.items[text_seg_index];

    const gpa = self.base.allocator;

    // We need to sort by address first
    var addresses = std.ArrayList(u64).init(gpa);
    defer addresses.deinit();
    try addresses.ensureTotalCapacityPrecise(self.globals.items.len);

    for (self.globals.items) |global| {
        const sym = self.getSymbol(global);
        if (sym.undf()) continue;
        if (sym.n_desc == N_DESC_GCED) continue;
        const sect_id = sym.n_sect - 1;
        if (sect_id != text_sect_index) continue;

        addresses.appendAssumeCapacity(sym.n_value);
    }

    std.sort.sort(u64, addresses.items, {}, asc_u64);

    var offsets = std.ArrayList(u32).init(gpa);
    defer offsets.deinit();
    try offsets.ensureTotalCapacityPrecise(addresses.items.len);

    var last_off: u32 = 0;
    for (addresses.items) |addr| {
        const offset = @intCast(u32, addr - text_seg.vmaddr);
        const diff = offset - last_off;

        if (diff == 0) continue;

        offsets.appendAssumeCapacity(diff);
        last_off = offset;
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const max_size = @intCast(usize, offsets.items.len * @sizeOf(u64));
    try buffer.ensureTotalCapacity(max_size);

    for (offsets.items) |offset| {
        try std.leb.writeULEB128(buffer.writer(), offset);
    }

    const link_seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, link_seg.fileoff + link_seg.filesize, @alignOf(u64));
    const needed_size = buffer.items.len;
    link_seg.filesize = offset + needed_size - link_seg.fileoff;

    log.debug("writing function starts info from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    try self.base.file.?.pwriteAll(buffer.items, offset);

    try lc_writer.writeStruct(macho.linkedit_data_command{
        .cmd = .FUNCTION_STARTS,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(u32, offset),
        .datasize = @intCast(u32, needed_size),
    });
    ncmds.* += 1;
}

fn filterDataInCode(
    dices: []align(1) const macho.data_in_code_entry,
    start_addr: u64,
    end_addr: u64,
) []align(1) const macho.data_in_code_entry {
    const Predicate = struct {
        addr: u64,

        pub fn predicate(self: @This(), dice: macho.data_in_code_entry) bool {
            return dice.offset >= self.addr;
        }
    };

    const start = MachO.findFirst(macho.data_in_code_entry, dices, 0, Predicate{ .addr = start_addr });
    const end = MachO.findFirst(macho.data_in_code_entry, dices, start, Predicate{ .addr = end_addr });

    return dices[start..end];
}

fn writeDataInCode(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var out_dice = std.ArrayList(macho.data_in_code_entry).init(self.base.allocator);
    defer out_dice.deinit();

    const text_sect_id = self.text_section_index orelse return;
    const text_sect_header = self.sections.items(.header)[text_sect_id];

    for (self.objects.items) |object| {
        const dice = object.parseDataInCode() orelse continue;
        try out_dice.ensureUnusedCapacity(dice.len);

        for (object.managed_atoms.items) |atom| {
            const sym = atom.getSymbol(self);
            if (sym.n_desc == N_DESC_GCED) continue;

            const sect_id = sym.n_sect - 1;
            if (sect_id != self.text_section_index.?) {
                continue;
            }

            const source_sym = object.getSourceSymbol(atom.sym_index) orelse continue;
            const source_addr = math.cast(u32, source_sym.n_value) orelse return error.Overflow;
            const filtered_dice = filterDataInCode(dice, source_addr, source_addr + atom.size);
            const base = math.cast(u32, sym.n_value - text_sect_header.addr + text_sect_header.offset) orelse
                return error.Overflow;

            for (filtered_dice) |single| {
                const offset = single.offset - source_addr + base;
                out_dice.appendAssumeCapacity(.{
                    .offset = offset,
                    .length = single.length,
                    .kind = single.kind,
                });
            }
        }
    }

    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64));
    const needed_size = out_dice.items.len * @sizeOf(macho.data_in_code_entry);
    seg.filesize = offset + needed_size - seg.fileoff;

    log.debug("writing data-in-code from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    try self.base.file.?.pwriteAll(mem.sliceAsBytes(out_dice.items), offset);
    try lc_writer.writeStruct(macho.linkedit_data_command{
        .cmd = .DATA_IN_CODE,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(u32, offset),
        .datasize = @intCast(u32, needed_size),
    });
    ncmds.* += 1;
}

fn writeSymtabs(self: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    var symtab_cmd = macho.symtab_command{
        .cmdsize = @sizeOf(macho.symtab_command),
        .symoff = 0,
        .nsyms = 0,
        .stroff = 0,
        .strsize = 0,
    };
    var dysymtab_cmd = macho.dysymtab_command{
        .cmdsize = @sizeOf(macho.dysymtab_command),
        .ilocalsym = 0,
        .nlocalsym = 0,
        .iextdefsym = 0,
        .nextdefsym = 0,
        .iundefsym = 0,
        .nundefsym = 0,
        .tocoff = 0,
        .ntoc = 0,
        .modtaboff = 0,
        .nmodtab = 0,
        .extrefsymoff = 0,
        .nextrefsyms = 0,
        .indirectsymoff = 0,
        .nindirectsyms = 0,
        .extreloff = 0,
        .nextrel = 0,
        .locreloff = 0,
        .nlocrel = 0,
    };
    var ctx = try self.writeSymtab(&symtab_cmd);
    defer ctx.imports_table.deinit();
    try self.writeDysymtab(ctx, &dysymtab_cmd);
    try self.writeStrtab(&symtab_cmd);
    try lc_writer.writeStruct(symtab_cmd);
    try lc_writer.writeStruct(dysymtab_cmd);
    ncmds.* += 2;
}

fn writeSymtab(self: *MachO, lc: *macho.symtab_command) !SymtabCtx {
    const gpa = self.base.allocator;

    var locals = std.ArrayList(macho.nlist_64).init(gpa);
    defer locals.deinit();

    for (self.locals.items) |sym, sym_id| {
        if (sym.n_strx == 0) continue; // no name, skip
        if (sym.n_desc == N_DESC_GCED) continue; // GCed, skip
        const sym_loc = SymbolWithLoc{ .sym_index = @intCast(u32, sym_id), .file = null };
        if (self.symbolIsTemp(sym_loc)) continue; // local temp symbol, skip
        if (self.getGlobal(self.getSymbolName(sym_loc)) != null) continue; // global symbol is either an export or import, skip
        try locals.append(sym);
    }

    for (self.objects.items) |object, object_id| {
        for (object.symtab.items) |sym, sym_id| {
            if (sym.n_strx == 0) continue; // no name, skip
            if (sym.n_desc == N_DESC_GCED) continue; // GCed, skip
            const sym_loc = SymbolWithLoc{ .sym_index = @intCast(u32, sym_id), .file = @intCast(u32, object_id) };
            if (self.symbolIsTemp(sym_loc)) continue; // local temp symbol, skip
            if (self.getGlobal(self.getSymbolName(sym_loc)) != null) continue; // global symbol is either an export or import, skip
            var out_sym = sym;
            out_sym.n_strx = try self.strtab.insert(gpa, self.getSymbolName(sym_loc));
            try locals.append(out_sym);
        }

        if (!self.base.options.strip) {
            try self.generateSymbolStabs(object, &locals);
        }
    }

    var exports = std.ArrayList(macho.nlist_64).init(gpa);
    defer exports.deinit();

    for (self.globals.items) |global| {
        const sym = self.getSymbol(global);
        if (sym.undf()) continue; // import, skip
        if (sym.n_desc == N_DESC_GCED) continue; // GCed, skip
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

    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(
        u64,
        seg.fileoff + seg.filesize,
        @alignOf(macho.nlist_64),
    );
    const needed_size = nsyms * @sizeOf(macho.nlist_64);
    seg.filesize = offset + needed_size - seg.fileoff;

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(needed_size);
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(locals.items));
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(exports.items));
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(imports.items));

    log.debug("writing symtab from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    try self.base.file.?.pwriteAll(buffer.items, offset);

    lc.symoff = @intCast(u32, offset);
    lc.nsyms = nsyms;

    return SymtabCtx{
        .nlocalsym = nlocals,
        .nextdefsym = nexports,
        .nundefsym = nimports,
        .imports_table = imports_table,
    };
}

fn writeStrtab(self: *MachO, lc: *macho.symtab_command) !void {
    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64));
    const needed_size = self.strtab.buffer.items.len;
    seg.filesize = offset + needed_size - seg.fileoff;

    log.debug("writing string table from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    try self.base.file.?.pwriteAll(self.strtab.buffer.items, offset);

    lc.stroff = @intCast(u32, offset);
    lc.strsize = @intCast(u32, needed_size);
}

const SymtabCtx = struct {
    nlocalsym: u32,
    nextdefsym: u32,
    nundefsym: u32,
    imports_table: std.AutoHashMap(SymbolWithLoc, u32),
};

fn writeDysymtab(self: *MachO, ctx: SymtabCtx, lc: *macho.dysymtab_command) !void {
    const gpa = self.base.allocator;
    const nstubs = @intCast(u32, self.stubs_table.count());
    const ngot_entries = @intCast(u32, self.got_entries_table.count());
    const nindirectsyms = nstubs * 2 + ngot_entries;
    const iextdefsym = ctx.nlocalsym;
    const iundefsym = iextdefsym + ctx.nextdefsym;

    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64));
    const needed_size = nindirectsyms * @sizeOf(u32);
    seg.filesize = offset + needed_size - seg.fileoff;

    log.debug("writing indirect symbol table from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    var buf = std.ArrayList(u8).init(gpa);
    defer buf.deinit();
    try buf.ensureTotalCapacity(needed_size);
    const writer = buf.writer();

    if (self.stubs_section_index) |sect_id| {
        const stubs = &self.sections.items(.header)[sect_id];
        stubs.reserved1 = 0;
        for (self.stubs.items) |entry| {
            if (entry.sym_index == 0) continue;
            const atom_sym = entry.getSymbol(self);
            if (atom_sym.n_desc == N_DESC_GCED) continue;
            const target_sym = self.getSymbol(entry.target);
            assert(target_sym.undf());
            try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry.target).?);
        }
    }

    if (self.got_section_index) |sect_id| {
        const got = &self.sections.items(.header)[sect_id];
        got.reserved1 = nstubs;
        for (self.got_entries.items) |entry| {
            if (entry.sym_index == 0) continue;
            const atom_sym = entry.getSymbol(self);
            if (atom_sym.n_desc == N_DESC_GCED) continue;
            const target_sym = self.getSymbol(entry.target);
            if (target_sym.undf()) {
                try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry.target).?);
            } else {
                try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL);
            }
        }
    }

    if (self.la_symbol_ptr_section_index) |sect_id| {
        const la_symbol_ptr = &self.sections.items(.header)[sect_id];
        la_symbol_ptr.reserved1 = nstubs + ngot_entries;
        for (self.stubs.items) |entry| {
            if (entry.sym_index == 0) continue;
            const atom_sym = entry.getSymbol(self);
            if (atom_sym.n_desc == N_DESC_GCED) continue;
            const target_sym = self.getSymbol(entry.target);
            assert(target_sym.undf());
            try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry.target).?);
        }
    }

    assert(buf.items.len == needed_size);
    try self.base.file.?.pwriteAll(buf.items, offset);

    lc.nlocalsym = ctx.nlocalsym;
    lc.iextdefsym = iextdefsym;
    lc.nextdefsym = ctx.nextdefsym;
    lc.iundefsym = iundefsym;
    lc.nundefsym = ctx.nundefsym;
    lc.indirectsymoff = @intCast(u32, offset);
    lc.nindirectsyms = nindirectsyms;
}

pub fn writeCodeSignaturePadding(
    self: *MachO,
    code_sig: *CodeSignature,
    ncmds: *u32,
    lc_writer: anytype,
) !u32 {
    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
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

    try lc_writer.writeStruct(macho.linkedit_data_command{
        .cmd = .CODE_SIGNATURE,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(u32, offset),
        .datasize = @intCast(u32, needed_size),
    });
    ncmds.* += 1;

    return @intCast(u32, offset);
}

pub fn writeCodeSignature(self: *MachO, code_sig: *CodeSignature, offset: u32) !void {
    const seg = self.segments.items[self.text_segment_cmd_index.?];

    var buffer = std.ArrayList(u8).init(self.base.allocator);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(code_sig.size());
    try code_sig.writeAdhocSignature(self.base.allocator, .{
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

    if (self.getSectionByName("__DATA", "__thread_vars")) |sect_id| {
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
    // TODO https://github.com/ziglang/zig/issues/1284
    return std.math.add(@TypeOf(actual_size), actual_size, actual_size / ideal_factor) catch
        std.math.maxInt(@TypeOf(actual_size));
}

pub fn makeStaticString(bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    assert(bytes.len <= buf.len);
    mem.copy(u8, &buf, bytes);
    return buf;
}

fn getSegmentByName(self: MachO, segname: []const u8) ?u8 {
    for (self.segments.items) |seg, i| {
        if (mem.eql(u8, segname, seg.segName())) return @intCast(u8, i);
    } else return null;
}

pub fn getSectionByName(self: MachO, segname: []const u8, sectname: []const u8) ?u8 {
    // TODO investigate caching with a hashmap
    for (self.sections.items(.header)) |header, i| {
        if (mem.eql(u8, header.segName(), segname) and mem.eql(u8, header.sectName(), sectname))
            return @intCast(u8, i);
    } else return null;
}

pub fn getSectionIndexes(self: MachO, segment_index: u8) struct { start: u8, end: u8 } {
    var start: u8 = 0;
    const nsects = for (self.segments.items) |seg, i| {
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
    if (sym_with_loc.file) |file| {
        const object = &self.objects.items[file];
        return &object.symtab.items[sym_with_loc.sym_index];
    } else {
        return &self.locals.items[sym_with_loc.sym_index];
    }
}

/// Returns symbol described by `sym_with_loc` descriptor.
pub fn getSymbol(self: *MachO, sym_with_loc: SymbolWithLoc) macho.nlist_64 {
    return self.getSymbolPtr(sym_with_loc).*;
}

/// Returns name of the symbol described by `sym_with_loc` descriptor.
pub fn getSymbolName(self: *MachO, sym_with_loc: SymbolWithLoc) []const u8 {
    if (sym_with_loc.file) |file| {
        const object = self.objects.items[file];
        const sym = object.symtab.items[sym_with_loc.sym_index];
        return object.getString(sym.n_strx);
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

/// Returns atom if there is an atom referenced by the symbol described by `sym_with_loc` descriptor.
/// Returns null on failure.
pub fn getAtomForSymbol(self: *MachO, sym_with_loc: SymbolWithLoc) ?*Atom {
    if (sym_with_loc.file) |file| {
        const object = self.objects.items[file];
        return object.getAtomForSymbol(sym_with_loc.sym_index);
    } else {
        return self.atom_by_index_table.get(sym_with_loc.sym_index);
    }
}

/// Returns GOT atom that references `sym_with_loc` if one exists.
/// Returns null otherwise.
pub fn getGotAtomForSymbol(self: *MachO, sym_with_loc: SymbolWithLoc) ?*Atom {
    const got_index = self.got_entries_table.get(sym_with_loc) orelse return null;
    return self.got_entries.items[got_index].getAtom(self);
}

/// Returns stubs atom that references `sym_with_loc` if one exists.
/// Returns null otherwise.
pub fn getStubsAtomForSymbol(self: *MachO, sym_with_loc: SymbolWithLoc) ?*Atom {
    const stubs_index = self.stubs_table.get(sym_with_loc) orelse return null;
    return self.stubs.items[stubs_index].getAtom(self);
}

/// Returns TLV pointer atom that references `sym_with_loc` if one exists.
/// Returns null otherwise.
pub fn getTlvPtrAtomForSymbol(self: *MachO, sym_with_loc: SymbolWithLoc) ?*Atom {
    const tlv_ptr_index = self.tlv_ptr_entries_table.get(sym_with_loc) orelse return null;
    return self.tlv_ptr_entries.items[tlv_ptr_index].getAtom(self);
}

/// Returns symbol location corresponding to the set entrypoint.
/// Asserts output mode is executable.
pub fn getEntryPoint(self: MachO) error{MissingMainEntrypoint}!SymbolWithLoc {
    const entry_name = self.base.options.entry orelse "_main";
    const global = self.getGlobal(entry_name) orelse {
        log.err("entrypoint '{s}' not found", .{entry_name});
        return error.MissingMainEntrypoint;
    };
    return global;
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

pub fn generateSymbolStabs(
    self: *MachO,
    object: Object,
    locals: *std.ArrayList(macho.nlist_64),
) !void {
    assert(!self.base.options.strip);

    log.debug("parsing debug info in '{s}'", .{object.name});

    const gpa = self.base.allocator;
    var debug_info = try object.parseDwarfInfo();
    defer debug_info.deinit(gpa);
    try dwarf.openDwarfDebugInfo(&debug_info, gpa);

    // We assume there is only one CU.
    const compile_unit = debug_info.findCompileUnit(0x0) catch |err| switch (err) {
        error.MissingDebugInfo => {
            // TODO audit cases with missing debug info and audit our dwarf.zig module.
            log.debug("invalid or missing debug info in {s}; skipping", .{object.name});
            return;
        },
        else => |e| return e,
    };

    const tu_name = try compile_unit.die.getAttrString(&debug_info, dwarf.AT.name, debug_info.debug_str, compile_unit.*);
    const tu_comp_dir = try compile_unit.die.getAttrString(&debug_info, dwarf.AT.comp_dir, debug_info.debug_str, compile_unit.*);

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

    for (object.managed_atoms.items) |atom| {
        const stabs = try self.generateSymbolStabsForSymbol(
            atom.getSymbolWithLoc(),
            debug_info,
            &stabs_buf,
        );
        try locals.appendSlice(stabs);

        for (atom.contained.items) |sym_at_off| {
            const sym_loc = SymbolWithLoc{
                .sym_index = sym_at_off.sym_index,
                .file = atom.file,
            };
            const contained_stabs = try self.generateSymbolStabsForSymbol(
                sym_loc,
                debug_info,
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
    sym_loc: SymbolWithLoc,
    debug_info: dwarf.DwarfInfo,
    buf: *[4]macho.nlist_64,
) ![]const macho.nlist_64 {
    const gpa = self.base.allocator;
    const object = self.objects.items[sym_loc.file.?];
    const sym = self.getSymbol(sym_loc);
    const sym_name = self.getSymbolName(sym_loc);

    if (sym.n_strx == 0) return buf[0..0];
    if (sym.n_desc == N_DESC_GCED) return buf[0..0];
    if (self.symbolIsTemp(sym_loc)) return buf[0..0];

    const source_sym = object.getSourceSymbol(sym_loc.sym_index) orelse return buf[0..0];
    const size: ?u64 = size: {
        if (source_sym.tentative()) break :size null;
        for (debug_info.func_list.items) |func| {
            if (func.pc_range) |range| {
                if (source_sym.n_value >= range.start and source_sym.n_value < range.end) {
                    break :size range.end - range.start;
                }
            }
        }
        break :size null;
    };

    if (size) |ss| {
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
            .n_value = ss,
        };
        buf[3] = .{
            .n_strx = 0,
            .n_type = macho.N_ENSYM,
            .n_sect = sym.n_sect,
            .n_desc = 0,
            .n_value = ss,
        };
        return buf;
    } else {
        buf[0] = .{
            .n_strx = try self.strtab.insert(gpa, sym_name),
            .n_type = macho.N_STSYM,
            .n_sect = sym.n_sect,
            .n_desc = 0,
            .n_value = sym.n_value,
        };
        return buf[0..1];
    }
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
    for (self.sections.items(.header)) |header, i| {
        log.debug("  sect({d}): {s},{s} @{x}, sizeof({x})", .{
            i + 1,
            header.segName(),
            header.sectName(),
            header.offset,
            header.size,
        });
    }
}

fn logSymAttributes(sym: macho.nlist_64, buf: *[9]u8) []const u8 {
    mem.set(u8, buf[0..4], '_');
    mem.set(u8, buf[4..], ' ');
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
    if (sym.n_desc == N_DESC_GCED) {
        mem.copy(u8, buf[5..], "DEAD");
    }
    return buf[0..];
}

pub fn logSymtab(self: *MachO) void {
    var buf: [9]u8 = undefined;

    log.debug("symtab:", .{});
    for (self.objects.items) |object, id| {
        log.debug("  object({d}): {s}", .{ id, object.name });
        for (object.symtab.items) |sym, sym_id| {
            const where = if (sym.undf() and !sym.tentative()) "ord" else "sect";
            const def_index = if (sym.undf() and !sym.tentative())
                @divTrunc(sym.n_desc, macho.N_SYMBOL_RESOLVER)
            else
                sym.n_sect;
            log.debug("    %{d}: {s} @{x} in {s}({d}), {s}", .{
                sym_id,
                object.getString(sym.n_strx),
                sym.n_value,
                where,
                def_index,
                logSymAttributes(sym, &buf),
            });
        }
    }
    log.debug("  object(null)", .{});
    for (self.locals.items) |sym, sym_id| {
        const where = if (sym.undf() and !sym.tentative()) "ord" else "sect";
        const def_index = if (sym.undf() and !sym.tentative())
            @divTrunc(sym.n_desc, macho.N_SYMBOL_RESOLVER)
        else
            sym.n_sect;
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
    for (self.got_entries.items) |entry, i| {
        const atom_sym = entry.getSymbol(self);
        if (atom_sym.n_desc == N_DESC_GCED) continue;
        const target_sym = self.getSymbol(entry.target);
        if (target_sym.undf()) {
            log.debug("  {d}@{x} => import('{s}')", .{
                i,
                atom_sym.n_value,
                self.getSymbolName(entry.target),
            });
        } else {
            log.debug("  {d}@{x} => local(%{d}) in object({?d}) {s}", .{
                i,
                atom_sym.n_value,
                entry.target.sym_index,
                entry.target.file,
                logSymAttributes(target_sym, &buf),
            });
        }
    }

    log.debug("__thread_ptrs entries:", .{});
    for (self.tlv_ptr_entries.items) |entry, i| {
        const atom_sym = entry.getSymbol(self);
        if (atom_sym.n_desc == N_DESC_GCED) continue;
        const target_sym = self.getSymbol(entry.target);
        assert(target_sym.undf());
        log.debug("  {d}@{x} => import('{s}')", .{
            i,
            atom_sym.n_value,
            self.getSymbolName(entry.target),
        });
    }

    log.debug("stubs entries:", .{});
    for (self.stubs.items) |entry, i| {
        const target_sym = self.getSymbol(entry.target);
        const atom_sym = entry.getSymbol(self);
        assert(target_sym.undf());
        log.debug("  {d}@{x} => import('{s}')", .{
            i,
            atom_sym.n_value,
            self.getSymbolName(entry.target),
        });
    }
}

pub fn logAtoms(self: *MachO) void {
    log.debug("atoms:", .{});

    const slice = self.sections.slice();
    for (slice.items(.last_atom)) |last, i| {
        var atom = last orelse continue;
        const header = slice.items(.header)[i];

        while (atom.prev) |prev| {
            atom = prev;
        }

        log.debug("{s},{s}", .{ header.segName(), header.sectName() });

        while (true) {
            self.logAtom(atom);
            if (atom.next) |next| {
                atom = next;
            } else break;
        }
    }
}

pub fn logAtom(self: *MachO, atom: *const Atom) void {
    const sym = atom.getSymbol(self);
    const sym_name = atom.getName(self);
    log.debug("  ATOM(%{d}, '{s}') @ {x} (sizeof({x}), alignof({x})) in object({?d}) in sect({d})", .{
        atom.sym_index,
        sym_name,
        sym.n_value,
        atom.size,
        atom.alignment,
        atom.file,
        sym.n_sect,
    });

    for (atom.contained.items) |sym_off| {
        const inner_sym = self.getSymbol(.{
            .sym_index = sym_off.sym_index,
            .file = atom.file,
        });
        const inner_sym_name = self.getSymbolName(.{
            .sym_index = sym_off.sym_index,
            .file = atom.file,
        });
        log.debug("    (%{d}, '{s}') @ {x} ({x})", .{
            sym_off.sym_index,
            inner_sym_name,
            inner_sym.n_value,
            sym_off.offset,
        });
    }
}

/// Since `os.copy_file_range` cannot be used when copying overlapping ranges within the same file,
/// and since `File.copyRangeAll` uses `os.copy_file_range` under-the-hood, we use heap allocated
/// buffers on all hosts except Linux (if `copy_file_range` syscall is available).
pub fn copyRangeAllOverlappingAlloc(
    allocator: Allocator,
    file: std.fs.File,
    in_offset: u64,
    out_offset: u64,
    len: usize,
) !void {
    const buf = try allocator.alloc(u8, len);
    defer allocator.free(buf);
    _ = try file.preadAll(buf, in_offset);
    try file.pwriteAll(buf, out_offset);
}
