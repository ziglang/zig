const MachO = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
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
const commands = @import("MachO/commands.zig");
const link = @import("../link.zig");
const llvm_backend = @import("../codegen/llvm.zig");
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;

const Air = @import("../Air.zig");
const Allocator = mem.Allocator;
const Archive = @import("MachO/Archive.zig");
const Atom = @import("MachO/Atom.zig");
const Cache = @import("../Cache.zig");
const CodeSignature = @import("MachO/CodeSignature.zig");
const Compilation = @import("../Compilation.zig");
const DebugSymbols = @import("MachO/DebugSymbols.zig");
const Dylib = @import("MachO/Dylib.zig");
const File = link.File;
const Object = @import("MachO/Object.zig");
const LibStub = @import("tapi.zig").LibStub;
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const LoadCommand = commands.LoadCommand;
const Module = @import("../Module.zig");
const SegmentCommand = commands.SegmentCommand;
const StringIndexAdapter = std.hash_map.StringIndexAdapter;
const StringIndexContext = std.hash_map.StringIndexContext;
const Trie = @import("MachO/Trie.zig");

pub const TextBlock = Atom;

pub const base_tag: File.Tag = File.Tag.macho;

base: File,

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

/// Debug symbols bundle (or dSym).
d_sym: ?DebugSymbols = null,

/// Page size is dependent on the target cpu architecture.
/// For x86_64 that's 4KB, whereas for aarch64, that's 16KB.
page_size: u16,

/// TODO Should we figure out embedding code signatures for other Apple platforms as part of the linker?
/// Or should this be a separate tool?
/// https://github.com/ziglang/zig/issues/9567
requires_adhoc_codesig: bool,

/// We commit 0x1000 = 4096 bytes of space to the header and
/// the table of load commands. This should be plenty for any
/// potential future extensions.
header_pad: u16 = 0x1000,

/// The absolute address of the entry point.
entry_addr: ?u64 = null,

objects: std.ArrayListUnmanaged(Object) = .{},
archives: std.ArrayListUnmanaged(Archive) = .{},

dylibs: std.ArrayListUnmanaged(Dylib) = .{},
dylibs_map: std.StringHashMapUnmanaged(u16) = .{},
referenced_dylibs: std.AutoArrayHashMapUnmanaged(u16, void) = .{},

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

pagezero_segment_cmd_index: ?u16 = null,
text_segment_cmd_index: ?u16 = null,
data_const_segment_cmd_index: ?u16 = null,
data_segment_cmd_index: ?u16 = null,
linkedit_segment_cmd_index: ?u16 = null,
dyld_info_cmd_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
dylinker_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,
function_starts_cmd_index: ?u16 = null,
main_cmd_index: ?u16 = null,
dylib_id_cmd_index: ?u16 = null,
source_version_cmd_index: ?u16 = null,
build_version_cmd_index: ?u16 = null,
uuid_cmd_index: ?u16 = null,
code_signature_cmd_index: ?u16 = null,

// __TEXT segment sections
text_section_index: ?u16 = null,
stubs_section_index: ?u16 = null,
stub_helper_section_index: ?u16 = null,
text_const_section_index: ?u16 = null,
cstring_section_index: ?u16 = null,
ustring_section_index: ?u16 = null,
gcc_except_tab_section_index: ?u16 = null,
unwind_info_section_index: ?u16 = null,
eh_frame_section_index: ?u16 = null,

objc_methlist_section_index: ?u16 = null,
objc_methname_section_index: ?u16 = null,
objc_methtype_section_index: ?u16 = null,
objc_classname_section_index: ?u16 = null,

// __DATA_CONST segment sections
got_section_index: ?u16 = null,
mod_init_func_section_index: ?u16 = null,
mod_term_func_section_index: ?u16 = null,
data_const_section_index: ?u16 = null,

objc_cfstring_section_index: ?u16 = null,
objc_classlist_section_index: ?u16 = null,
objc_imageinfo_section_index: ?u16 = null,

// __DATA segment sections
tlv_section_index: ?u16 = null,
tlv_data_section_index: ?u16 = null,
tlv_bss_section_index: ?u16 = null,
la_symbol_ptr_section_index: ?u16 = null,
data_section_index: ?u16 = null,
bss_section_index: ?u16 = null,

objc_const_section_index: ?u16 = null,
objc_selrefs_section_index: ?u16 = null,
objc_classrefs_section_index: ?u16 = null,
objc_data_section_index: ?u16 = null,

bss_file_offset: u32 = 0,
tlv_bss_file_offset: u32 = 0,

locals: std.ArrayListUnmanaged(macho.nlist_64) = .{},
globals: std.ArrayListUnmanaged(macho.nlist_64) = .{},
undefs: std.ArrayListUnmanaged(macho.nlist_64) = .{},
symbol_resolver: std.AutoHashMapUnmanaged(u32, SymbolWithLoc) = .{},
unresolved: std.AutoArrayHashMapUnmanaged(u32, enum {
    none,
    stub,
    got,
}) = .{},
tentatives: std.AutoArrayHashMapUnmanaged(u32, void) = .{},

locals_free_list: std.ArrayListUnmanaged(u32) = .{},
globals_free_list: std.ArrayListUnmanaged(u32) = .{},

dyld_stub_binder_index: ?u32 = null,
dyld_private_atom: ?*Atom = null,
stub_helper_preamble_atom: ?*Atom = null,

strtab: std.ArrayListUnmanaged(u8) = .{},
strtab_dir: std.HashMapUnmanaged(u32, void, StringIndexContext, std.hash_map.default_max_load_percentage) = .{},

got_entries_map: std.AutoArrayHashMapUnmanaged(Atom.Relocation.Target, *Atom) = .{},
got_entries_map_free_list: std.ArrayListUnmanaged(u32) = .{},

stubs_map: std.AutoArrayHashMapUnmanaged(u32, *Atom) = .{},
stubs_map_free_list: std.ArrayListUnmanaged(u32) = .{},

error_flags: File.ErrorFlags = File.ErrorFlags{},

load_commands_dirty: bool = false,
sections_order_dirty: bool = false,
has_dices: bool = false,
has_stabs: bool = false,
/// A helper var to indicate if we are at the start of the incremental updates, or
/// already somewhere further along the update-and-run chain.
/// TODO once we add opening a prelinked output binary from file, this will become
/// obsolete as we will carry on where we left off.
cold_start: bool = false,
invalidate_relocs: bool = false,

section_ordinals: std.AutoArrayHashMapUnmanaged(MatchingSection, void) = .{},

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
atom_free_lists: std.AutoHashMapUnmanaged(MatchingSection, std.ArrayListUnmanaged(*Atom)) = .{},

/// Pointer to the last allocated atom
atoms: std.AutoHashMapUnmanaged(MatchingSection, *Atom) = .{},

/// List of atoms that are owned directly by the linker.
/// Currently these are only atoms that are the result of linking
/// object files. Atoms which take part in incremental linking are
/// at present owned by Module.Decl.
/// TODO consolidate this.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

/// Table of Decls that are currently alive.
/// We store them here so that we can properly dispose of any allocated
/// memory within the atom in the incremental linker.
/// TODO consolidate this.
decls: std.AutoArrayHashMapUnmanaged(*Module.Decl, void) = .{},

/// Currently active Module.Decl.
/// TODO this might not be necessary if we figure out how to pass Module.Decl instance
/// to codegen.genSetReg() or alternatively move PIE displacement for MCValue{ .memory = x }
/// somewhere else in the codegen.
active_decl: ?*Module.Decl = null,

const PendingUpdate = union(enum) {
    resolve_undef: u32,
    add_stub_entry: u32,
    add_got_entry: u32,
};

const SymbolWithLoc = struct {
    // Table where the symbol can be found.
    where: enum {
        global,
        undef,
    },
    where_index: u32,
    local_sym_index: u32 = 0,
    file: ?u16 = null, // null means Zig module
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

/// Virtual memory offset corresponds to the size of __PAGEZERO segment and start of
/// __TEXT segment.
const pagezero_vmsize: u64 = 0x100000000;

pub const Export = struct {
    sym_index: ?u32 = null,
};

pub const SrcFn = struct {
    /// Offset from the beginning of the Debug Line Program header that contains this function.
    off: u32,
    /// Size of the line number program component belonging to this function, not
    /// including padding.
    len: u32,

    /// Points to the previous and next neighbors, based on the offset from .debug_line.
    /// This can be used to find, for example, the capacity of this `SrcFn`.
    prev: ?*SrcFn,
    next: ?*SrcFn,

    pub const empty: SrcFn = .{
        .off = 0,
        .len = 0,
        .prev = null,
        .next = null,
    };
};

pub fn openPath(allocator: *Allocator, options: link.Options) !*MachO {
    assert(options.object_format == .macho);

    const use_stage1 = build_options.is_stage1 and options.use_stage1;
    if (use_stage1 or options.emit == null) {
        return createEmpty(allocator, options);
    }
    const emit = options.emit.?;
    const file = try emit.directory.handle.createFile(emit.sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();

    const self = try createEmpty(allocator, options);
    errdefer {
        self.base.file = null;
        self.base.destroy();
    }

    self.base.file = file;

    if (build_options.have_llvm and options.use_llvm and options.module != null) {
        // TODO this intermediary_basename isn't enough; in the case of `zig build-exe`,
        // we also want to put the intermediary object file in the cache while the
        // main emit directory is the cwd.
        const sub_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{
            emit.sub_path, options.object_format.fileExt(options.target.cpu.arch),
        });
        self.llvm_object = try LlvmObject.create(allocator, sub_path, options);
        self.base.intermediary_basename = sub_path;
    }

    if (options.output_mode == .Lib and
        options.link_mode == .Static and self.base.intermediary_basename != null)
    {
        return self;
    }

    // TODO Migrate DebugSymbols to the merged linker codepaths
    // if (!options.strip and options.module != null) {
    //     // Create dSYM bundle.
    //     const dir = options.module.?.zig_cache_artifact_directory;
    //     log.debug("creating {s}.dSYM bundle in {s}", .{ sub_path, dir.path });

    //     const d_sym_path = try fmt.allocPrint(
    //         allocator,
    //         "{s}.dSYM" ++ fs.path.sep_str ++ "Contents" ++ fs.path.sep_str ++ "Resources" ++ fs.path.sep_str ++ "DWARF",
    //         .{sub_path},
    //     );
    //     defer allocator.free(d_sym_path);

    //     var d_sym_bundle = try dir.handle.makeOpenPath(d_sym_path, .{});
    //     defer d_sym_bundle.close();

    //     const d_sym_file = try d_sym_bundle.createFile(sub_path, .{
    //         .truncate = false,
    //         .read = true,
    //     });

    //     self.d_sym = .{
    //         .base = self,
    //         .file = d_sym_file,
    //     };
    // }

    // Index 0 is always a null symbol.
    try self.locals.append(allocator, .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    try self.strtab.append(allocator, 0);

    try self.populateMissingMetadata();

    if (self.d_sym) |*ds| {
        try ds.populateMissingMetadata(allocator);
    }

    return self;
}

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*MachO {
    const self = try gpa.create(MachO);
    const cpu_arch = options.target.cpu.arch;
    const os_tag = options.target.os.tag;
    const abi = options.target.abi;
    const page_size: u16 = if (cpu_arch == .aarch64) 0x4000 else 0x1000;
    // Adhoc code signature is required when targeting aarch64-macos either directly or indirectly via the simulator
    // ABI such as aarch64-ios-simulator, etc.
    const requires_adhoc_codesig = cpu_arch == .aarch64 and (os_tag == .macos or abi == .simulator);

    self.* = .{
        .base = .{
            .tag = .macho,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .page_size = page_size,
        .requires_adhoc_codesig = requires_adhoc_codesig,
    };

    return self;
}

pub fn flush(self: *MachO, comp: *Compilation) !void {
    if (self.base.options.output_mode == .Lib and self.base.options.link_mode == .Static) {
        if (build_options.have_llvm) {
            return self.base.linkAsArchive(comp);
        } else {
            log.err("TODO: non-LLVM archiver for MachO object files", .{});
            return error.TODOImplementWritingStaticLibFiles;
        }
    }
    try self.flushModule(comp);
}

pub fn flushModule(self: *MachO, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const use_stage1 = build_options.is_stage1 and self.base.options.use_stage1;
    if (!use_stage1 and self.base.options.output_mode == .Obj)
        return self.flushObject(comp);

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const directory = self.base.options.emit.?.directory; // Just an alias to make it shorter to type.

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (self.base.options.module) |module| blk: {
        if (use_stage1) {
            const obj_basename = try std.zig.binNameAlloc(arena, .{
                .root_name = self.base.options.root_name,
                .target = self.base.options.target,
                .output_mode = .Obj,
            });
            const o_directory = module.zig_cache_artifact_directory;
            const full_obj_path = try o_directory.join(arena, &[_][]const u8{obj_basename});
            break :blk full_obj_path;
        }

        const obj_basename = self.base.intermediary_basename orelse break :blk null;
        try self.flushObject(comp);
        const full_obj_path = try directory.join(arena, &[_][]const u8{obj_basename});
        break :blk full_obj_path;
    } else null;

    const is_lib = self.base.options.output_mode == .Lib;
    const is_dyn_lib = self.base.options.link_mode == .Dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or self.base.options.output_mode == .Exe;
    const stack_size = self.base.options.stack_size_override orelse 0;

    const id_symlink_basename = "zld.id";

    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;
    var needs_full_relink = true;

    cache: {
        if (use_stage1 and self.base.options.disable_lld_caching) break :cache;

        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        try man.addListOfFiles(self.base.options.objects);
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        // We can skip hashing libc and libc++ components that we are in charge of building from Zig
        // installation sources because they are always a product of the compiler version + target information.
        man.hash.add(stack_size);
        man.hash.addListOfBytes(self.base.options.lib_dirs);
        man.hash.addListOfBytes(self.base.options.framework_dirs);
        man.hash.addListOfBytes(self.base.options.frameworks);
        man.hash.addListOfBytes(self.base.options.rpath_list);
        if (is_dyn_lib) {
            man.hash.addOptional(self.base.options.version);
        }
        man.hash.addStringSet(self.base.options.system_libs);
        man.hash.addOptionalBytes(self.base.options.sysroot);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
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
        if (mem.eql(u8, prev_digest, &digest)) {
            // Hot diggity dog! The output binary is already there.

            if (use_stage1) {
                log.debug("MachO Zld digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
                self.base.lock = man.toOwnedLock();
                return;
            } else {
                log.debug("MachO Zld digest={s} match", .{std.fmt.fmtSliceHexLower(&digest)});
                if (!self.cold_start) {
                    log.debug("  no need to relink objects", .{});
                    needs_full_relink = false;
                } else {
                    log.debug("  TODO parse prelinked binary and continue linking where we left off", .{});
                    // TODO until such time however, perform a full relink of objects.
                    needs_full_relink = true;
                }
            }
        }
        log.debug("MachO Zld prev_digest={s} new_digest={s}", .{
            std.fmt.fmtSliceHexLower(prev_digest),
            std.fmt.fmtSliceHexLower(&digest),
        });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path});

    if (self.base.options.output_mode == .Obj) {
        // LLD's MachO driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (self.base.options.objects.len != 0)
                break :blk self.base.options.objects[0];

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (module_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        // This can happen when using --enable-cache and using the stage1 backend. In this case
        // we can skip the file copy.
        if (!mem.eql(u8, the_object_path, full_out_path)) {
            try fs.cwd().copyFile(the_object_path, fs.cwd(), full_out_path, .{});
        }
    } else {
        if (use_stage1) {
            const sub_path = self.base.options.emit.?.sub_path;
            self.base.file = try directory.handle.createFile(sub_path, .{
                .truncate = true,
                .read = true,
                .mode = link.determineMode(self.base.options),
            });
            // Index 0 is always a null symbol.
            try self.locals.append(self.base.allocator, .{
                .n_strx = 0,
                .n_type = 0,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            });
            try self.strtab.append(self.base.allocator, 0);
            try self.populateMissingMetadata();
        }

        if (needs_full_relink) {
            for (self.objects.items) |*object| {
                object.free(self.base.allocator, self);
                object.deinit(self.base.allocator);
            }
            self.objects.clearRetainingCapacity();

            for (self.archives.items) |*archive| {
                archive.deinit(self.base.allocator);
            }
            self.archives.clearRetainingCapacity();

            for (self.dylibs.items) |*dylib| {
                dylib.deinit(self.base.allocator);
            }
            self.dylibs.clearRetainingCapacity();
            self.dylibs_map.clearRetainingCapacity();
            self.referenced_dylibs.clearRetainingCapacity();

            {
                var to_remove = std.ArrayList(u32).init(self.base.allocator);
                defer to_remove.deinit();
                var it = self.symbol_resolver.iterator();
                while (it.next()) |entry| {
                    const key = entry.key_ptr.*;
                    const value = entry.value_ptr.*;
                    if (value.file != null) {
                        try to_remove.append(key);
                    }
                }

                for (to_remove.items) |key| {
                    if (self.symbol_resolver.fetchRemove(key)) |entry| {
                        const resolv = entry.value;
                        switch (resolv.where) {
                            .global => {
                                self.globals_free_list.append(self.base.allocator, resolv.where_index) catch {};
                                const sym = &self.globals.items[resolv.where_index];
                                sym.n_strx = 0;
                                sym.n_type = 0;
                                sym.n_value = 0;
                            },
                            .undef => {
                                const sym = &self.undefs.items[resolv.where_index];
                                sym.n_strx = 0;
                                sym.n_desc = 0;
                            },
                        }
                        if (self.got_entries_map.getIndex(.{ .global = entry.key })) |i| {
                            self.got_entries_map_free_list.append(
                                self.base.allocator,
                                @intCast(u32, i),
                            ) catch {};
                            self.got_entries_map.keys()[i] = .{ .local = 0 };
                        }
                        if (self.stubs_map.getIndex(entry.key)) |i| {
                            self.stubs_map_free_list.append(self.base.allocator, @intCast(u32, i)) catch {};
                            self.stubs_map.keys()[i] = 0;
                        }
                    }
                }
            }
            // Invalidate all relocs
            // TODO we only need to invalidate the backlinks to the relinked atoms from
            // the relocatable object files.
            self.invalidate_relocs = true;

            // Positional arguments to the linker such as object files and static archives.
            var positionals = std.ArrayList([]const u8).init(arena);

            try positionals.appendSlice(self.base.options.objects);

            for (comp.c_object_table.keys()) |key| {
                try positionals.append(key.status.success.object_path);
            }

            if (module_obj_path) |p| {
                try positionals.append(p);
            }

            if (comp.compiler_rt_static_lib) |lib| {
                try positionals.append(lib.full_object_path);
            }

            // libc++ dep
            if (self.base.options.link_libcpp) {
                try positionals.append(comp.libcxxabi_static_lib.?.full_object_path);
                try positionals.append(comp.libcxx_static_lib.?.full_object_path);
            }

            // Shared and static libraries passed via `-l` flag.
            var search_lib_names = std.ArrayList([]const u8).init(arena);

            const system_libs = self.base.options.system_libs.keys();
            for (system_libs) |link_lib| {
                // By this time, we depend on these libs being dynamically linked libraries and not static libraries
                // (the check for that needs to be earlier), but they could be full paths to .dylib files, in which
                // case we want to avoid prepending "-l".
                if (Compilation.classifyFileExt(link_lib) == .shared_library) {
                    try positionals.append(link_lib);
                    continue;
                }

                try search_lib_names.append(link_lib);
            }

            var lib_dirs = std.ArrayList([]const u8).init(arena);
            for (self.base.options.lib_dirs) |dir| {
                if (try resolveSearchDir(arena, dir, self.base.options.sysroot)) |search_dir| {
                    try lib_dirs.append(search_dir);
                } else {
                    log.warn("directory not found for '-L{s}'", .{dir});
                }
            }

            var libs = std.ArrayList([]const u8).init(arena);
            var lib_not_found = false;
            for (search_lib_names.items) |lib_name| {
                // Assume ld64 default: -search_paths_first
                // Look in each directory for a dylib (stub first), and then for archive
                // TODO implement alternative: -search_dylibs_first
                for (&[_][]const u8{ ".tbd", ".dylib", ".a" }) |ext| {
                    if (try resolveLib(arena, lib_dirs.items, lib_name, ext)) |full_path| {
                        try libs.append(full_path);
                        break;
                    }
                } else {
                    log.warn("library not found for '-l{s}'", .{lib_name});
                    lib_not_found = true;
                }
            }

            if (lib_not_found) {
                log.warn("Library search paths:", .{});
                for (lib_dirs.items) |dir| {
                    log.warn("  {s}", .{dir});
                }
            }

            // If we were given the sysroot, try to look there first for libSystem.B.{dylib, tbd}.
            var libsystem_available = false;
            if (self.base.options.sysroot != null) blk: {
                // Try stub file first. If we hit it, then we're done as the stub file
                // re-exports every single symbol definition.
                if (try resolveLib(arena, lib_dirs.items, "System", ".tbd")) |full_path| {
                    try libs.append(full_path);
                    libsystem_available = true;
                    break :blk;
                }
                // If we didn't hit the stub file, try .dylib next. However, libSystem.dylib
                // doesn't export libc.dylib which we'll need to resolve subsequently also.
                if (try resolveLib(arena, lib_dirs.items, "System", ".dylib")) |libsystem_path| {
                    if (try resolveLib(arena, lib_dirs.items, "c", ".dylib")) |libc_path| {
                        try libs.append(libsystem_path);
                        try libs.append(libc_path);
                        libsystem_available = true;
                        break :blk;
                    }
                }
            }
            if (!libsystem_available) {
                const full_path = try comp.zig_lib_directory.join(arena, &[_][]const u8{
                    "libc", "darwin", "libSystem.B.tbd",
                });
                try libs.append(full_path);
            }

            // frameworks
            var framework_dirs = std.ArrayList([]const u8).init(arena);
            for (self.base.options.framework_dirs) |dir| {
                if (try resolveSearchDir(arena, dir, self.base.options.sysroot)) |search_dir| {
                    try framework_dirs.append(search_dir);
                } else {
                    log.warn("directory not found for '-F{s}'", .{dir});
                }
            }

            var framework_not_found = false;
            for (self.base.options.frameworks) |framework| {
                for (&[_][]const u8{ ".tbd", ".dylib", "" }) |ext| {
                    if (try resolveFramework(arena, framework_dirs.items, framework, ext)) |full_path| {
                        try libs.append(full_path);
                        break;
                    }
                } else {
                    log.warn("framework not found for '-framework {s}'", .{framework});
                    framework_not_found = true;
                }
            }

            if (framework_not_found) {
                log.warn("Framework search paths:", .{});
                for (framework_dirs.items) |dir| {
                    log.warn("  {s}", .{dir});
                }
            }

            // rpaths
            var rpath_table = std.StringArrayHashMap(void).init(arena);
            for (self.base.options.rpath_list) |rpath| {
                if (rpath_table.contains(rpath)) continue;
                const cmdsize = @intCast(u32, mem.alignForwardGeneric(
                    u64,
                    @sizeOf(macho.rpath_command) + rpath.len + 1,
                    @sizeOf(u64),
                ));
                var rpath_cmd = commands.emptyGenericCommandWithData(macho.rpath_command{
                    .cmd = macho.LC_RPATH,
                    .cmdsize = cmdsize,
                    .path = @sizeOf(macho.rpath_command),
                });
                rpath_cmd.data = try self.base.allocator.alloc(u8, cmdsize - rpath_cmd.inner.path);
                mem.set(u8, rpath_cmd.data, 0);
                mem.copy(u8, rpath_cmd.data, rpath);
                try self.load_commands.append(self.base.allocator, .{ .Rpath = rpath_cmd });
                try rpath_table.putNoClobber(rpath, {});
                self.load_commands_dirty = true;
            }

            if (self.base.options.verbose_link) {
                var argv = std.ArrayList([]const u8).init(arena);

                try argv.append("zig");
                try argv.append("ld");

                if (is_exe_or_dyn_lib) {
                    try argv.append("-dynamic");
                }

                if (is_dyn_lib) {
                    try argv.append("-dylib");

                    const install_name = try std.fmt.allocPrint(arena, "@rpath/{s}", .{
                        self.base.options.emit.?.sub_path,
                    });
                    try argv.append("-install_name");
                    try argv.append(install_name);
                }

                if (self.base.options.sysroot) |syslibroot| {
                    try argv.append("-syslibroot");
                    try argv.append(syslibroot);
                }

                for (rpath_table.keys()) |rpath| {
                    try argv.append("-rpath");
                    try argv.append(rpath);
                }

                try argv.appendSlice(positionals.items);

                try argv.append("-o");
                try argv.append(full_out_path);

                try argv.append("-lSystem");
                try argv.append("-lc");

                for (search_lib_names.items) |l_name| {
                    try argv.append(try std.fmt.allocPrint(arena, "-l{s}", .{l_name}));
                }

                for (self.base.options.lib_dirs) |lib_dir| {
                    try argv.append(try std.fmt.allocPrint(arena, "-L{s}", .{lib_dir}));
                }

                for (self.base.options.frameworks) |framework| {
                    try argv.append(try std.fmt.allocPrint(arena, "-framework {s}", .{framework}));
                }

                for (self.base.options.framework_dirs) |framework_dir| {
                    try argv.append(try std.fmt.allocPrint(arena, "-F{s}", .{framework_dir}));
                }

                Compilation.dump_argv(argv.items);
            }

            try self.parseInputFiles(positionals.items, self.base.options.sysroot);
            try self.parseLibs(libs.items, self.base.options.sysroot);
        }

        if (self.bss_section_index) |idx| {
            const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
            const sect = &seg.sections.items[idx];
            sect.offset = self.bss_file_offset;
        }
        if (self.tlv_bss_section_index) |idx| {
            const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
            const sect = &seg.sections.items[idx];
            sect.offset = self.tlv_bss_file_offset;
        }

        for (self.objects.items) |*object, object_id| {
            if (object.analyzed) continue;
            try self.resolveSymbolsInObject(@intCast(u16, object_id));
        }

        try self.resolveSymbolsInArchives();
        try self.resolveDyldStubBinder();
        try self.createDyldPrivateAtom();
        try self.createStubHelperPreambleAtom();
        try self.resolveSymbolsInDylibs();
        try self.createDsoHandleAtom();
        try self.addCodeSignatureLC();

        for (self.unresolved.keys()) |index| {
            const sym = self.undefs.items[index];
            const sym_name = self.getString(sym.n_strx);
            const resolv = self.symbol_resolver.get(sym.n_strx) orelse unreachable;

            log.err("undefined reference to symbol '{s}'", .{sym_name});
            if (resolv.file) |file| {
                log.err("  first referenced in '{s}'", .{self.objects.items[file].name});
            }
        }
        if (self.unresolved.count() > 0) {
            return error.UndefinedSymbolReference;
        }

        try self.createTentativeDefAtoms();
        try self.parseObjectsIntoAtoms();
        try self.allocateGlobalSymbols();

        log.debug("locals:", .{});
        for (self.locals.items) |sym, id| {
            log.debug("  {d}: {s}: {}", .{ id, self.getString(sym.n_strx), sym });
        }
        log.debug("globals:", .{});
        for (self.globals.items) |sym, id| {
            log.debug("  {d}: {s}: {}", .{ id, self.getString(sym.n_strx), sym });
        }
        log.debug("undefs:", .{});
        for (self.undefs.items) |sym, id| {
            log.debug("  {d}: {s}: {}", .{ id, self.getString(sym.n_strx), sym });
        }
        {
            log.debug("resolver:", .{});
            var it = self.symbol_resolver.iterator();
            while (it.next()) |entry| {
                log.debug("  {s} => {}", .{ self.getString(entry.key_ptr.*), entry.value_ptr.* });
            }
        }

        log.debug("GOT entries:", .{});
        for (self.got_entries_map.keys()) |key| {
            switch (key) {
                .local => |sym_index| log.debug("  {} => {d}", .{ key, sym_index }),
                .global => |n_strx| log.debug("  {} => {s}", .{ key, self.getString(n_strx) }),
            }
        }

        log.debug("stubs:", .{});
        for (self.stubs_map.keys()) |key| {
            log.debug("  {} => {s}", .{ key, self.getString(key) });
        }

        try self.writeAtoms();

        if (self.bss_section_index) |idx| {
            const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
            const sect = &seg.sections.items[idx];
            self.bss_file_offset = sect.offset;
            sect.offset = 0;
        }
        if (self.tlv_bss_section_index) |idx| {
            const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
            const sect = &seg.sections.items[idx];
            self.tlv_bss_file_offset = sect.offset;
            sect.offset = 0;
        }

        try self.setEntryPoint();
        try self.updateSectionOrdinals();
        try self.writeLinkeditSegment();

        if (self.d_sym) |*ds| {
            // Flush debug symbols bundle.
            try ds.flushModule(self.base.allocator, self.base.options);
        }

        if (self.requires_adhoc_codesig) {
            // Preallocate space for the code signature.
            // We need to do this at this stage so that we have the load commands with proper values
            // written out to the file.
            // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
            // where the code signature goes into.
            try self.writeCodeSignaturePadding();
        }

        try self.writeLoadCommands();
        try self.writeHeader();

        if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
            log.debug("flushing. no_entry_point_found = true", .{});
            self.error_flags.no_entry_point_found = true;
        } else {
            log.debug("flushing. no_entry_point_found = false", .{});
            self.error_flags.no_entry_point_found = false;
        }

        assert(!self.load_commands_dirty);

        if (self.requires_adhoc_codesig) {
            try self.writeCodeSignature(); // code signing always comes last
        }

        if (build_options.enable_link_snapshots) {
            if (self.base.options.enable_link_snapshots)
                try self.snapshotState();
        }
    }

    cache: {
        if (use_stage1 and self.base.options.disable_lld_caching) break :cache;
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
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

pub fn flushObject(self: *MachO, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (build_options.have_llvm)
        if (self.llvm_object) |llvm_object| return llvm_object.flushModule(comp);

    return error.TODOImplementWritingObjFiles;
}

fn resolveSearchDir(
    arena: *Allocator,
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

fn resolveLib(
    arena: *Allocator,
    search_dirs: []const []const u8,
    name: []const u8,
    ext: []const u8,
) !?[]const u8 {
    const search_name = try std.fmt.allocPrint(arena, "lib{s}{s}", .{ name, ext });

    for (search_dirs) |dir| {
        const full_path = try fs.path.join(arena, &[_][]const u8{ dir, search_name });

        // Check if the file exists.
        const tmp = fs.cwd().openFile(full_path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        defer tmp.close();

        return full_path;
    }

    return null;
}

fn resolveFramework(
    arena: *Allocator,
    search_dirs: []const []const u8,
    name: []const u8,
    ext: []const u8,
) !?[]const u8 {
    const search_name = try std.fmt.allocPrint(arena, "{s}{s}", .{ name, ext });
    const prefix_path = try std.fmt.allocPrint(arena, "{s}.framework", .{name});

    for (search_dirs) |dir| {
        const full_path = try fs.path.join(arena, &[_][]const u8{ dir, prefix_path, search_name });

        // Check if the file exists.
        const tmp = fs.cwd().openFile(full_path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        defer tmp.close();

        return full_path;
    }

    return null;
}

fn parseObject(self: *MachO, path: []const u8) !bool {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    errdefer file.close();

    const name = try self.base.allocator.dupe(u8, path);
    errdefer self.base.allocator.free(name);

    var object = Object{
        .name = name,
        .file = file,
    };

    object.parse(self.base.allocator, self.base.options.target) catch |err| switch (err) {
        error.EndOfStream, error.NotObject => {
            object.deinit(self.base.allocator);
            return false;
        },
        else => |e| return e,
    };

    try self.objects.append(self.base.allocator, object);

    return true;
}

fn parseArchive(self: *MachO, path: []const u8) !bool {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    errdefer file.close();

    const name = try self.base.allocator.dupe(u8, path);
    errdefer self.base.allocator.free(name);

    var archive = Archive{
        .name = name,
        .file = file,
    };

    archive.parse(self.base.allocator, self.base.options.target) catch |err| switch (err) {
        error.EndOfStream, error.NotArchive => {
            archive.deinit(self.base.allocator);
            return false;
        },
        else => |e| return e,
    };

    try self.archives.append(self.base.allocator, archive);

    return true;
}

const ParseDylibError = error{
    OutOfMemory,
    EmptyStubFile,
    MismatchedCpuArchitecture,
    UnsupportedCpuArchitecture,
} || fs.File.OpenError || std.os.PReadError || Dylib.Id.ParseError;

const DylibCreateOpts = struct {
    syslibroot: ?[]const u8 = null,
    id: ?Dylib.Id = null,
    is_dependent: bool = false,
};

pub fn parseDylib(self: *MachO, path: []const u8, opts: DylibCreateOpts) ParseDylibError!bool {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    errdefer file.close();

    const name = try self.base.allocator.dupe(u8, path);
    errdefer self.base.allocator.free(name);

    var dylib = Dylib{
        .name = name,
        .file = file,
    };

    dylib.parse(self.base.allocator, self.base.options.target) catch |err| switch (err) {
        error.EndOfStream, error.NotDylib => {
            try file.seekTo(0);

            var lib_stub = LibStub.loadFromFile(self.base.allocator, file) catch {
                dylib.deinit(self.base.allocator);
                return false;
            };
            defer lib_stub.deinit();

            try dylib.parseFromStub(self.base.allocator, self.base.options.target, lib_stub);
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
            dylib.deinit(self.base.allocator);
            return false;
        }
    }

    const dylib_id = @intCast(u16, self.dylibs.items.len);
    try self.dylibs.append(self.base.allocator, dylib);
    try self.dylibs_map.putNoClobber(self.base.allocator, dylib.id.?.name, dylib_id);

    if (!(opts.is_dependent or self.referenced_dylibs.contains(dylib_id))) {
        try self.addLoadDylibLC(dylib_id);
        try self.referenced_dylibs.putNoClobber(self.base.allocator, dylib_id, {});
    }

    // TODO this should not be performed if the user specifies `-flat_namespace` flag.
    // See ld64 manpages.
    try dylib.parseDependentLibs(self, opts.syslibroot);

    return true;
}

fn parseInputFiles(self: *MachO, files: []const []const u8, syslibroot: ?[]const u8) !void {
    for (files) |file_name| {
        const full_path = full_path: {
            var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
            const path = try std.fs.realpath(file_name, &buffer);
            break :full_path try self.base.allocator.dupe(u8, path);
        };
        defer self.base.allocator.free(full_path);
        log.debug("parsing input file path '{s}'", .{full_path});

        if (try self.parseObject(full_path)) continue;
        if (try self.parseArchive(full_path)) continue;
        if (try self.parseDylib(full_path, .{
            .syslibroot = syslibroot,
        })) continue;

        log.warn("unknown filetype for positional input file: '{s}'", .{file_name});
    }
}

fn parseLibs(self: *MachO, libs: []const []const u8, syslibroot: ?[]const u8) !void {
    for (libs) |lib| {
        log.debug("parsing lib path '{s}'", .{lib});
        if (try self.parseDylib(lib, .{
            .syslibroot = syslibroot,
        })) continue;
        if (try self.parseArchive(lib)) continue;

        log.warn("unknown filetype for a library: '{s}'", .{lib});
    }
}

pub const MatchingSection = struct {
    seg: u16,
    sect: u16,
};

pub fn getMatchingSection(self: *MachO, sect: macho.section_64) !?MatchingSection {
    const segname = commands.segmentName(sect);
    const sectname = commands.sectionName(sect);
    const res: ?MatchingSection = blk: {
        switch (commands.sectionType(sect)) {
            macho.S_4BYTE_LITERALS, macho.S_8BYTE_LITERALS, macho.S_16BYTE_LITERALS => {
                if (self.text_const_section_index == null) {
                    self.text_const_section_index = try self.allocateSection(
                        self.text_segment_cmd_index.?,
                        "__const",
                        sect.size,
                        sect.@"align",
                        .{},
                    );
                }

                break :blk .{
                    .seg = self.text_segment_cmd_index.?,
                    .sect = self.text_const_section_index.?,
                };
            },
            macho.S_CSTRING_LITERALS => {
                if (mem.eql(u8, sectname, "__objc_methname")) {
                    // TODO it seems the common values within the sections in objects are deduplicated/merged
                    // on merging the sections' contents.
                    if (self.objc_methname_section_index == null) {
                        self.objc_methname_section_index = try self.allocateSection(
                            self.text_segment_cmd_index.?,
                            "__objc_methname",
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    }

                    break :blk .{
                        .seg = self.text_segment_cmd_index.?,
                        .sect = self.objc_methname_section_index.?,
                    };
                } else if (mem.eql(u8, sectname, "__objc_methtype")) {
                    if (self.objc_methtype_section_index == null) {
                        self.objc_methtype_section_index = try self.allocateSection(
                            self.text_segment_cmd_index.?,
                            "__objc_methtype",
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    }

                    break :blk .{
                        .seg = self.text_segment_cmd_index.?,
                        .sect = self.objc_methtype_section_index.?,
                    };
                } else if (mem.eql(u8, sectname, "__objc_classname")) {
                    if (self.objc_classname_section_index == null) {
                        self.objc_classname_section_index = try self.allocateSection(
                            self.text_segment_cmd_index.?,
                            "__objc_classname",
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    }

                    break :blk .{
                        .seg = self.text_segment_cmd_index.?,
                        .sect = self.objc_classname_section_index.?,
                    };
                }

                if (self.cstring_section_index == null) {
                    self.cstring_section_index = try self.allocateSection(
                        self.text_segment_cmd_index.?,
                        "__cstring",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_CSTRING_LITERALS,
                        },
                    );
                }

                break :blk .{
                    .seg = self.text_segment_cmd_index.?,
                    .sect = self.cstring_section_index.?,
                };
            },
            macho.S_LITERAL_POINTERS => {
                if (mem.eql(u8, segname, "__DATA") and mem.eql(u8, sectname, "__objc_selrefs")) {
                    if (self.objc_selrefs_section_index == null) {
                        self.objc_selrefs_section_index = try self.allocateSection(
                            self.data_segment_cmd_index.?,
                            "__objc_selrefs",
                            sect.size,
                            sect.@"align",
                            .{
                                .flags = macho.S_LITERAL_POINTERS,
                            },
                        );
                    }

                    break :blk .{
                        .seg = self.data_segment_cmd_index.?,
                        .sect = self.objc_selrefs_section_index.?,
                    };
                } else {
                    // TODO investigate
                    break :blk null;
                }
            },
            macho.S_MOD_INIT_FUNC_POINTERS => {
                if (self.mod_init_func_section_index == null) {
                    self.mod_init_func_section_index = try self.allocateSection(
                        self.data_const_segment_cmd_index.?,
                        "__mod_init_func",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_MOD_INIT_FUNC_POINTERS,
                        },
                    );
                }

                break :blk .{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.mod_init_func_section_index.?,
                };
            },
            macho.S_MOD_TERM_FUNC_POINTERS => {
                if (self.mod_term_func_section_index == null) {
                    self.mod_term_func_section_index = try self.allocateSection(
                        self.data_const_segment_cmd_index.?,
                        "__mod_term_func",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_MOD_TERM_FUNC_POINTERS,
                        },
                    );
                }

                break :blk .{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.mod_term_func_section_index.?,
                };
            },
            macho.S_ZEROFILL => {
                if (self.bss_section_index == null) {
                    self.bss_section_index = try self.allocateSection(
                        self.data_segment_cmd_index.?,
                        "__bss",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_ZEROFILL,
                        },
                    );
                }

                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.bss_section_index.?,
                };
            },
            macho.S_THREAD_LOCAL_VARIABLES => {
                if (self.tlv_section_index == null) {
                    self.tlv_section_index = try self.allocateSection(
                        self.data_segment_cmd_index.?,
                        "__thread_vars",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_THREAD_LOCAL_VARIABLES,
                        },
                    );
                }

                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.tlv_section_index.?,
                };
            },
            macho.S_THREAD_LOCAL_REGULAR => {
                if (self.tlv_data_section_index == null) {
                    self.tlv_data_section_index = try self.allocateSection(
                        self.data_segment_cmd_index.?,
                        "__thread_data",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_THREAD_LOCAL_REGULAR,
                        },
                    );
                }

                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.tlv_data_section_index.?,
                };
            },
            macho.S_THREAD_LOCAL_ZEROFILL => {
                if (self.tlv_bss_section_index == null) {
                    self.tlv_bss_section_index = try self.allocateSection(
                        self.data_segment_cmd_index.?,
                        "__thread_bss",
                        sect.size,
                        sect.@"align",
                        .{
                            .flags = macho.S_THREAD_LOCAL_ZEROFILL,
                        },
                    );
                }

                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.tlv_bss_section_index.?,
                };
            },
            macho.S_COALESCED => {
                if (mem.eql(u8, "__TEXT", segname) and mem.eql(u8, "__eh_frame", sectname)) {
                    // TODO I believe __eh_frame is currently part of __unwind_info section
                    // in the latest ld64 output.
                    if (self.eh_frame_section_index == null) {
                        self.eh_frame_section_index = try self.allocateSection(
                            self.text_segment_cmd_index.?,
                            "__eh_frame",
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    }

                    break :blk .{
                        .seg = self.text_segment_cmd_index.?,
                        .sect = self.eh_frame_section_index.?,
                    };
                }

                // TODO audit this: is this the right mapping?
                if (self.data_const_section_index == null) {
                    self.data_const_section_index = try self.allocateSection(
                        self.data_const_segment_cmd_index.?,
                        "__const",
                        sect.size,
                        sect.@"align",
                        .{},
                    );
                }

                break :blk .{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.data_const_section_index.?,
                };
            },
            macho.S_REGULAR => {
                if (commands.sectionIsCode(sect)) {
                    if (self.text_section_index == null) {
                        self.text_section_index = try self.allocateSection(
                            self.text_segment_cmd_index.?,
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

                    break :blk .{
                        .seg = self.text_segment_cmd_index.?,
                        .sect = self.text_section_index.?,
                    };
                }
                if (commands.sectionIsDebug(sect)) {
                    // TODO debug attributes
                    if (mem.eql(u8, "__LD", segname) and mem.eql(u8, "__compact_unwind", sectname)) {
                        log.debug("TODO compact unwind section: type 0x{x}, name '{s},{s}'", .{
                            sect.flags, segname, sectname,
                        });
                    }
                    break :blk null;
                }

                if (mem.eql(u8, segname, "__TEXT")) {
                    if (mem.eql(u8, sectname, "__ustring")) {
                        if (self.ustring_section_index == null) {
                            self.ustring_section_index = try self.allocateSection(
                                self.text_segment_cmd_index.?,
                                "__ustring",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.text_segment_cmd_index.?,
                            .sect = self.ustring_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__gcc_except_tab")) {
                        if (self.gcc_except_tab_section_index == null) {
                            self.gcc_except_tab_section_index = try self.allocateSection(
                                self.text_segment_cmd_index.?,
                                "__gcc_except_tab",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.text_segment_cmd_index.?,
                            .sect = self.gcc_except_tab_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__objc_methlist")) {
                        if (self.objc_methlist_section_index == null) {
                            self.objc_methlist_section_index = try self.allocateSection(
                                self.text_segment_cmd_index.?,
                                "__objc_methlist",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.text_segment_cmd_index.?,
                            .sect = self.objc_methlist_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__rodata") or
                        mem.eql(u8, sectname, "__typelink") or
                        mem.eql(u8, sectname, "__itablink") or
                        mem.eql(u8, sectname, "__gosymtab") or
                        mem.eql(u8, sectname, "__gopclntab"))
                    {
                        if (self.data_const_section_index == null) {
                            self.data_const_section_index = try self.allocateSection(
                                self.data_const_segment_cmd_index.?,
                                "__const",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_const_segment_cmd_index.?,
                            .sect = self.data_const_section_index.?,
                        };
                    } else {
                        if (self.text_const_section_index == null) {
                            self.text_const_section_index = try self.allocateSection(
                                self.text_segment_cmd_index.?,
                                "__const",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.text_segment_cmd_index.?,
                            .sect = self.text_const_section_index.?,
                        };
                    }
                }

                if (mem.eql(u8, segname, "__DATA_CONST")) {
                    if (self.data_const_section_index == null) {
                        self.data_const_section_index = try self.allocateSection(
                            self.data_const_segment_cmd_index.?,
                            "__const",
                            sect.size,
                            sect.@"align",
                            .{},
                        );
                    }

                    break :blk .{
                        .seg = self.data_const_segment_cmd_index.?,
                        .sect = self.data_const_section_index.?,
                    };
                }

                if (mem.eql(u8, segname, "__DATA")) {
                    if (mem.eql(u8, sectname, "__const")) {
                        if (self.data_const_section_index == null) {
                            self.data_const_section_index = try self.allocateSection(
                                self.data_const_segment_cmd_index.?,
                                "__const",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_const_segment_cmd_index.?,
                            .sect = self.data_const_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__cfstring")) {
                        if (self.objc_cfstring_section_index == null) {
                            self.objc_cfstring_section_index = try self.allocateSection(
                                self.data_const_segment_cmd_index.?,
                                "__cfstring",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_const_segment_cmd_index.?,
                            .sect = self.objc_cfstring_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__objc_classlist")) {
                        if (self.objc_classlist_section_index == null) {
                            self.objc_classlist_section_index = try self.allocateSection(
                                self.data_const_segment_cmd_index.?,
                                "__objc_classlist",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_const_segment_cmd_index.?,
                            .sect = self.objc_classlist_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__objc_imageinfo")) {
                        if (self.objc_imageinfo_section_index == null) {
                            self.objc_imageinfo_section_index = try self.allocateSection(
                                self.data_const_segment_cmd_index.?,
                                "__objc_imageinfo",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_const_segment_cmd_index.?,
                            .sect = self.objc_imageinfo_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__objc_const")) {
                        if (self.objc_const_section_index == null) {
                            self.objc_const_section_index = try self.allocateSection(
                                self.data_segment_cmd_index.?,
                                "__objc_const",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_segment_cmd_index.?,
                            .sect = self.objc_const_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__objc_classrefs")) {
                        if (self.objc_classrefs_section_index == null) {
                            self.objc_classrefs_section_index = try self.allocateSection(
                                self.data_segment_cmd_index.?,
                                "__objc_classrefs",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_segment_cmd_index.?,
                            .sect = self.objc_classrefs_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__objc_data")) {
                        if (self.objc_data_section_index == null) {
                            self.objc_data_section_index = try self.allocateSection(
                                self.data_segment_cmd_index.?,
                                "__objc_data",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_segment_cmd_index.?,
                            .sect = self.objc_data_section_index.?,
                        };
                    } else {
                        if (self.data_section_index == null) {
                            self.data_section_index = try self.allocateSection(
                                self.data_segment_cmd_index.?,
                                "__data",
                                sect.size,
                                sect.@"align",
                                .{},
                            );
                        }

                        break :blk .{
                            .seg = self.data_segment_cmd_index.?,
                            .sect = self.data_section_index.?,
                        };
                    }
                }

                if (mem.eql(u8, "__LLVM", segname) and mem.eql(u8, "__asm", sectname)) {
                    log.debug("TODO LLVM asm section: type 0x{x}, name '{s},{s}'", .{
                        sect.flags, segname, sectname,
                    });
                }

                break :blk null;
            },
            else => break :blk null,
        }
    };
    return res;
}

pub fn createEmptyAtom(self: *MachO, local_sym_index: u32, size: u64, alignment: u32) !*Atom {
    const code = try self.base.allocator.alloc(u8, size);
    defer self.base.allocator.free(code);
    mem.set(u8, code, 0);

    const atom = try self.base.allocator.create(Atom);
    errdefer self.base.allocator.destroy(atom);
    atom.* = Atom.empty;
    atom.local_sym_index = local_sym_index;
    atom.size = size;
    atom.alignment = alignment;
    try atom.code.appendSlice(self.base.allocator, code);
    try self.managed_atoms.append(self.base.allocator, atom);

    return atom;
}

pub fn writeAtom(self: *MachO, atom: *Atom, match: MatchingSection) !void {
    const seg = self.load_commands.items[match.seg].Segment;
    const sect = seg.sections.items[match.sect];
    const sym = self.locals.items[atom.local_sym_index];
    const file_offset = sect.offset + sym.n_value - sect.addr;
    try atom.resolveRelocs(self);
    log.debug("writing atom for symbol {s} at file offset 0x{x}", .{ self.getString(sym.n_strx), file_offset });
    try self.base.file.?.pwriteAll(atom.code.items, file_offset);
}

fn allocateLocalSymbols(self: *MachO, match: MatchingSection, offset: i64) !void {
    var atom = self.atoms.get(match) orelse return;

    while (true) {
        const atom_sym = &self.locals.items[atom.local_sym_index];
        atom_sym.n_value = @intCast(u64, @intCast(i64, atom_sym.n_value) + offset);

        for (atom.aliases.items) |index| {
            const alias_sym = &self.locals.items[index];
            alias_sym.n_value = @intCast(u64, @intCast(i64, alias_sym.n_value) + offset);
        }

        for (atom.contained.items) |sym_at_off| {
            const contained_sym = &self.locals.items[sym_at_off.local_sym_index];
            contained_sym.n_value = @intCast(u64, @intCast(i64, contained_sym.n_value) + offset);
        }

        if (atom.prev) |prev| {
            atom = prev;
        } else break;
    }
}

fn allocateGlobalSymbols(self: *MachO) !void {
    var sym_it = self.symbol_resolver.valueIterator();
    while (sym_it.next()) |resolv| {
        if (resolv.where != .global) continue;

        assert(resolv.local_sym_index != 0);
        const local_sym = self.locals.items[resolv.local_sym_index];
        const sym = &self.globals.items[resolv.where_index];
        sym.n_value = local_sym.n_value;
        sym.n_sect = local_sym.n_sect;
        log.debug("allocating global symbol {s} at 0x{x}", .{ self.getString(sym.n_strx), local_sym.n_value });
    }
}

fn writeAtoms(self: *MachO) !void {
    var buffer = std.ArrayList(u8).init(self.base.allocator);
    defer buffer.deinit();
    var file_offset: ?u64 = null;

    var it = self.atoms.iterator();
    while (it.next()) |entry| {
        const match = entry.key_ptr.*;
        const seg = self.load_commands.items[match.seg].Segment;
        const sect = seg.sections.items[match.sect];
        var atom: *Atom = entry.value_ptr.*;

        log.debug("writing atoms in {s},{s}", .{ commands.segmentName(sect), commands.sectionName(sect) });

        while (atom.prev) |prev| {
            atom = prev;
        }

        while (true) {
            if (atom.dirty or self.invalidate_relocs) {
                const atom_sym = self.locals.items[atom.local_sym_index];
                const padding_size: u64 = if (atom.next) |next| blk: {
                    const next_sym = self.locals.items[next.local_sym_index];
                    break :blk next_sym.n_value - (atom_sym.n_value + atom.size);
                } else 0;

                log.debug("  (adding atom {s} to buffer: {})", .{ self.getString(atom_sym.n_strx), atom_sym });

                try atom.resolveRelocs(self);
                try buffer.appendSlice(atom.code.items);
                try buffer.ensureUnusedCapacity(padding_size);

                var i: usize = 0;
                while (i < padding_size) : (i += 1) {
                    buffer.appendAssumeCapacity(0);
                }

                if (file_offset == null) {
                    file_offset = sect.offset + atom_sym.n_value - sect.addr;
                }
                atom.dirty = false;
            } else {
                if (file_offset) |off| {
                    try self.base.file.?.pwriteAll(buffer.items, off);
                }
                file_offset = null;
                buffer.clearRetainingCapacity();
            }

            if (atom.next) |next| {
                atom = next;
            } else {
                if (file_offset) |off| {
                    try self.base.file.?.pwriteAll(buffer.items, off);
                }
                file_offset = null;
                buffer.clearRetainingCapacity();
                break;
            }
        }
    }
}

pub fn createGotAtom(self: *MachO, target: Atom.Relocation.Target) !*Atom {
    const local_sym_index = @intCast(u32, self.locals.items.len);
    try self.locals.append(self.base.allocator, .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    const atom = try self.createEmptyAtom(local_sym_index, @sizeOf(u64), 3);
    try atom.relocs.append(self.base.allocator, .{
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
    switch (target) {
        .local => {
            try atom.rebases.append(self.base.allocator, 0);
        },
        .global => |n_strx| {
            try atom.bindings.append(self.base.allocator, .{
                .n_strx = n_strx,
                .offset = 0,
            });
        },
    }
    return atom;
}

fn createDyldPrivateAtom(self: *MachO) !void {
    if (self.dyld_private_atom != null) return;
    const local_sym_index = @intCast(u32, self.locals.items.len);
    const sym = try self.locals.addOne(self.base.allocator);
    sym.* = .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    const atom = try self.createEmptyAtom(local_sym_index, @sizeOf(u64), 3);
    self.dyld_private_atom = atom;
    const match = MatchingSection{
        .seg = self.data_segment_cmd_index.?,
        .sect = self.data_section_index.?,
    };
    const vaddr = try self.allocateAtom(atom, @sizeOf(u64), 8, match);
    sym.n_value = vaddr;
    sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
    log.debug("allocated {s} atom at 0x{x}", .{ self.getString(sym.n_strx), vaddr });
}

fn createStubHelperPreambleAtom(self: *MachO) !void {
    if (self.stub_helper_preamble_atom != null) return;
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
    const local_sym_index = @intCast(u32, self.locals.items.len);
    const sym = try self.locals.addOne(self.base.allocator);
    sym.* = .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    const atom = try self.createEmptyAtom(local_sym_index, size, alignment);
    const dyld_private_sym_index = self.dyld_private_atom.?.local_sym_index;
    switch (arch) {
        .x86_64 => {
            try atom.relocs.ensureUnusedCapacity(self.base.allocator, 2);
            // lea %r11, [rip + disp]
            atom.code.items[0] = 0x4c;
            atom.code.items[1] = 0x8d;
            atom.code.items[2] = 0x1d;
            atom.relocs.appendAssumeCapacity(.{
                .offset = 3,
                .target = .{ .local = dyld_private_sym_index },
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
                .target = .{ .global = self.undefs.items[self.dyld_stub_binder_index.?].n_strx },
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
                .target = .{ .local = dyld_private_sym_index },
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
                .target = .{ .local = dyld_private_sym_index },
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
                .target = .{ .global = self.undefs.items[self.dyld_stub_binder_index.?].n_strx },
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
                .target = .{ .global = self.undefs.items[self.dyld_stub_binder_index.?].n_strx },
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
    const match = MatchingSection{
        .seg = self.text_segment_cmd_index.?,
        .sect = self.stub_helper_section_index.?,
    };
    const alignment_pow_2 = try math.powi(u32, 2, atom.alignment);
    const vaddr = try self.allocateAtom(atom, atom.size, alignment_pow_2, match);
    sym.n_value = vaddr;
    sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
    log.debug("allocated {s} atom at 0x{x}", .{ self.getString(sym.n_strx), vaddr });
}

pub fn createStubHelperAtom(self: *MachO) !*Atom {
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
    const local_sym_index = @intCast(u32, self.locals.items.len);
    try self.locals.append(self.base.allocator, .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    const atom = try self.createEmptyAtom(local_sym_index, stub_size, alignment);
    try atom.relocs.ensureTotalCapacity(self.base.allocator, 1);

    switch (arch) {
        .x86_64 => {
            // pushq
            atom.code.items[0] = 0x68;
            // Next 4 bytes 1..4 are just a placeholder populated in `populateLazyBindOffsetsInStubHelper`.
            // jmpq
            atom.code.items[5] = 0xe9;
            atom.relocs.appendAssumeCapacity(.{
                .offset = 6,
                .target = .{ .local = self.stub_helper_preamble_atom.?.local_sym_index },
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
                break :blk try math.cast(u18, div_res);
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
                .target = .{ .local = self.stub_helper_preamble_atom.?.local_sym_index },
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

    return atom;
}

pub fn createLazyPointerAtom(self: *MachO, stub_sym_index: u32, n_strx: u32) !*Atom {
    const local_sym_index = @intCast(u32, self.locals.items.len);
    try self.locals.append(self.base.allocator, .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    const atom = try self.createEmptyAtom(local_sym_index, @sizeOf(u64), 3);
    try atom.relocs.append(self.base.allocator, .{
        .offset = 0,
        .target = .{ .local = stub_sym_index },
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
    try atom.rebases.append(self.base.allocator, 0);
    try atom.lazy_bindings.append(self.base.allocator, .{
        .n_strx = n_strx,
        .offset = 0,
    });
    return atom;
}

pub fn createStubAtom(self: *MachO, laptr_sym_index: u32) !*Atom {
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
    const local_sym_index = @intCast(u32, self.locals.items.len);
    try self.locals.append(self.base.allocator, .{
        .n_strx = 0,
        .n_type = macho.N_SECT,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    const atom = try self.createEmptyAtom(local_sym_index, stub_size, alignment);
    switch (arch) {
        .x86_64 => {
            // jmp
            atom.code.items[0] = 0xff;
            atom.code.items[1] = 0x25;
            try atom.relocs.append(self.base.allocator, .{
                .offset = 2,
                .target = .{ .local = laptr_sym_index },
                .addend = 0,
                .subtractor = null,
                .pcrel = true,
                .length = 2,
                .@"type" = @enumToInt(macho.reloc_type_x86_64.X86_64_RELOC_BRANCH),
            });
        },
        .aarch64 => {
            try atom.relocs.ensureTotalCapacity(self.base.allocator, 2);
            // adrp x16, pages
            mem.writeIntLittle(u32, atom.code.items[0..4], aarch64.Instruction.adrp(.x16, 0).toU32());
            atom.relocs.appendAssumeCapacity(.{
                .offset = 0,
                .target = .{ .local = laptr_sym_index },
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
                .target = .{ .local = laptr_sym_index },
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
    return atom;
}

fn createTentativeDefAtoms(self: *MachO) !void {
    if (self.tentatives.count() == 0) return;
    // Convert any tentative definition into a regular symbol and allocate
    // text blocks for each tentative definition.
    while (self.tentatives.popOrNull()) |entry| {
        const match = MatchingSection{
            .seg = self.data_segment_cmd_index.?,
            .sect = self.bss_section_index.?,
        };
        _ = try self.section_ordinals.getOrPut(self.base.allocator, match);

        const global_sym = &self.globals.items[entry.key];
        const size = global_sym.n_value;
        const alignment = (global_sym.n_desc >> 8) & 0x0f;

        global_sym.n_value = 0;
        global_sym.n_desc = 0;
        global_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);

        const local_sym_index = @intCast(u32, self.locals.items.len);
        const local_sym = try self.locals.addOne(self.base.allocator);
        local_sym.* = .{
            .n_strx = global_sym.n_strx,
            .n_type = macho.N_SECT,
            .n_sect = global_sym.n_sect,
            .n_desc = 0,
            .n_value = 0,
        };

        const resolv = self.symbol_resolver.getPtr(local_sym.n_strx) orelse unreachable;
        resolv.local_sym_index = local_sym_index;

        const atom = try self.createEmptyAtom(local_sym_index, size, alignment);
        const alignment_pow_2 = try math.powi(u32, 2, alignment);
        const vaddr = try self.allocateAtom(atom, size, alignment_pow_2, match);
        local_sym.n_value = vaddr;
        global_sym.n_value = vaddr;
    }
}

fn createDsoHandleAtom(self: *MachO) !void {
    if (self.strtab_dir.getKeyAdapted(@as([]const u8, "___dso_handle"), StringIndexAdapter{
        .bytes = &self.strtab,
    })) |n_strx| blk: {
        const resolv = self.symbol_resolver.getPtr(n_strx) orelse break :blk;
        if (resolv.where != .undef) break :blk;

        const undef = &self.undefs.items[resolv.where_index];
        const match: MatchingSection = .{
            .seg = self.text_segment_cmd_index.?,
            .sect = self.text_section_index.?,
        };
        const local_sym_index = @intCast(u32, self.locals.items.len);
        var nlist = macho.nlist_64{
            .n_strx = undef.n_strx,
            .n_type = macho.N_SECT,
            .n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1),
            .n_desc = 0,
            .n_value = 0,
        };
        try self.locals.append(self.base.allocator, nlist);
        const global_sym_index = @intCast(u32, self.globals.items.len);
        nlist.n_type |= macho.N_EXT;
        nlist.n_desc = macho.N_WEAK_DEF;
        try self.globals.append(self.base.allocator, nlist);

        assert(self.unresolved.swapRemove(resolv.where_index));

        undef.* = .{
            .n_strx = 0,
            .n_type = macho.N_UNDF,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        };
        resolv.* = .{
            .where = .global,
            .where_index = global_sym_index,
            .local_sym_index = local_sym_index,
        };

        // We create an empty atom for this symbol.
        // TODO perhaps we should special-case special symbols? Create a separate
        // linked list of atoms?
        const atom = try self.createEmptyAtom(local_sym_index, 0, 0);
        const sym = &self.locals.items[local_sym_index];
        const vaddr = try self.allocateAtom(atom, 0, 1, match);
        sym.n_value = vaddr;
        atom.dirty = false; // We don't really want to write it to file.
    }
}

fn resolveSymbolsInObject(self: *MachO, object_id: u16) !void {
    const object = &self.objects.items[object_id];

    log.debug("resolving symbols in '{s}'", .{object.name});

    for (object.symtab.items) |sym, id| {
        const sym_id = @intCast(u32, id);
        const sym_name = object.getString(sym.n_strx);

        if (symbolIsStab(sym)) {
            log.err("unhandled symbol type: stab", .{});
            log.err("  symbol '{s}'", .{sym_name});
            log.err("  first definition in '{s}'", .{object.name});
            return error.UnhandledSymbolType;
        }

        if (symbolIsIndr(sym)) {
            log.err("unhandled symbol type: indirect", .{});
            log.err("  symbol '{s}'", .{sym_name});
            log.err("  first definition in '{s}'", .{object.name});
            return error.UnhandledSymbolType;
        }

        if (symbolIsAbs(sym)) {
            log.err("unhandled symbol type: absolute", .{});
            log.err("  symbol '{s}'", .{sym_name});
            log.err("  first definition in '{s}'", .{object.name});
            return error.UnhandledSymbolType;
        }

        const n_strx = try self.makeString(sym_name);
        if (symbolIsSect(sym)) {
            // Defined symbol regardless of scope lands in the locals symbol table.
            const local_sym_index = @intCast(u32, self.locals.items.len);
            try self.locals.append(self.base.allocator, .{
                .n_strx = n_strx,
                .n_type = macho.N_SECT,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = sym.n_value,
            });
            try object.symbol_mapping.putNoClobber(self.base.allocator, sym_id, local_sym_index);
            try object.reverse_symbol_mapping.putNoClobber(self.base.allocator, local_sym_index, sym_id);

            // If the symbol's scope is not local aka translation unit, then we need work out
            // if we should save the symbol as a global, or potentially flag the error.
            if (!symbolIsExt(sym)) continue;

            const local = self.locals.items[local_sym_index];
            const resolv = self.symbol_resolver.getPtr(n_strx) orelse {
                const global_sym_index = @intCast(u32, self.globals.items.len);
                try self.globals.append(self.base.allocator, .{
                    .n_strx = n_strx,
                    .n_type = sym.n_type,
                    .n_sect = 0,
                    .n_desc = sym.n_desc,
                    .n_value = sym.n_value,
                });
                try self.symbol_resolver.putNoClobber(self.base.allocator, n_strx, .{
                    .where = .global,
                    .where_index = global_sym_index,
                    .local_sym_index = local_sym_index,
                    .file = object_id,
                });
                continue;
            };

            switch (resolv.where) {
                .global => {
                    const global = &self.globals.items[resolv.where_index];

                    if (symbolIsTentative(global.*)) {
                        assert(self.tentatives.swapRemove(resolv.where_index));
                    } else if (!(symbolIsWeakDef(sym) or symbolIsPext(sym)) and
                        !(symbolIsWeakDef(global.*) or symbolIsPext(global.*)))
                    {
                        log.err("symbol '{s}' defined multiple times", .{sym_name});
                        if (resolv.file) |file| {
                            log.err("  first definition in '{s}'", .{self.objects.items[file].name});
                        }
                        log.err("  next definition in '{s}'", .{object.name});
                        return error.MultipleSymbolDefinitions;
                    } else if (symbolIsWeakDef(sym) or symbolIsPext(sym)) continue; // Current symbol is weak, so skip it.

                    // Otherwise, update the resolver and the global symbol.
                    global.n_type = sym.n_type;
                    resolv.local_sym_index = local_sym_index;
                    resolv.file = object_id;

                    continue;
                },
                .undef => {
                    const undef = &self.undefs.items[resolv.where_index];
                    undef.* = .{
                        .n_strx = 0,
                        .n_type = macho.N_UNDF,
                        .n_sect = 0,
                        .n_desc = 0,
                        .n_value = 0,
                    };
                    assert(self.unresolved.swapRemove(resolv.where_index));
                },
            }

            const global_sym_index = @intCast(u32, self.globals.items.len);
            try self.globals.append(self.base.allocator, .{
                .n_strx = local.n_strx,
                .n_type = sym.n_type,
                .n_sect = 0,
                .n_desc = sym.n_desc,
                .n_value = sym.n_value,
            });
            resolv.* = .{
                .where = .global,
                .where_index = global_sym_index,
                .local_sym_index = local_sym_index,
                .file = object_id,
            };
        } else if (symbolIsTentative(sym)) {
            // Symbol is a tentative definition.
            const resolv = self.symbol_resolver.getPtr(n_strx) orelse {
                const global_sym_index = @intCast(u32, self.globals.items.len);
                try self.globals.append(self.base.allocator, .{
                    .n_strx = try self.makeString(sym_name),
                    .n_type = sym.n_type,
                    .n_sect = 0,
                    .n_desc = sym.n_desc,
                    .n_value = sym.n_value,
                });
                try self.symbol_resolver.putNoClobber(self.base.allocator, n_strx, .{
                    .where = .global,
                    .where_index = global_sym_index,
                    .file = object_id,
                });
                _ = try self.tentatives.getOrPut(self.base.allocator, global_sym_index);
                continue;
            };

            switch (resolv.where) {
                .global => {
                    const global = &self.globals.items[resolv.where_index];
                    if (!symbolIsTentative(global.*)) continue;
                    if (global.n_value >= sym.n_value) continue;

                    global.n_desc = sym.n_desc;
                    global.n_value = sym.n_value;
                    resolv.file = object_id;
                },
                .undef => {
                    const undef = &self.undefs.items[resolv.where_index];
                    const global_sym_index = @intCast(u32, self.globals.items.len);
                    try self.globals.append(self.base.allocator, .{
                        .n_strx = undef.n_strx,
                        .n_type = sym.n_type,
                        .n_sect = 0,
                        .n_desc = sym.n_desc,
                        .n_value = sym.n_value,
                    });
                    _ = try self.tentatives.getOrPut(self.base.allocator, global_sym_index);
                    assert(self.unresolved.swapRemove(resolv.where_index));

                    resolv.* = .{
                        .where = .global,
                        .where_index = global_sym_index,
                        .file = object_id,
                    };
                    undef.* = .{
                        .n_strx = 0,
                        .n_type = macho.N_UNDF,
                        .n_sect = 0,
                        .n_desc = 0,
                        .n_value = 0,
                    };
                },
            }
        } else {
            // Symbol is undefined.
            if (self.symbol_resolver.contains(n_strx)) continue;

            const undef_sym_index = @intCast(u32, self.undefs.items.len);
            try self.undefs.append(self.base.allocator, .{
                .n_strx = try self.makeString(sym_name),
                .n_type = macho.N_UNDF,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            });
            try self.symbol_resolver.putNoClobber(self.base.allocator, n_strx, .{
                .where = .undef,
                .where_index = undef_sym_index,
                .file = object_id,
            });
            try self.unresolved.putNoClobber(self.base.allocator, undef_sym_index, .none);
        }
    }
}

fn resolveSymbolsInArchives(self: *MachO) !void {
    if (self.archives.items.len == 0) return;

    var next_sym: usize = 0;
    loop: while (next_sym < self.unresolved.count()) {
        const sym = self.undefs.items[self.unresolved.keys()[next_sym]];
        const sym_name = self.getString(sym.n_strx);

        for (self.archives.items) |archive| {
            // Check if the entry exists in a static archive.
            const offsets = archive.toc.get(sym_name) orelse {
                // No hit.
                continue;
            };
            assert(offsets.items.len > 0);

            const object_id = @intCast(u16, self.objects.items.len);
            const object = try self.objects.addOne(self.base.allocator);
            object.* = try archive.parseObject(self.base.allocator, self.base.options.target, offsets.items[0]);
            try self.resolveSymbolsInObject(object_id);

            continue :loop;
        }

        next_sym += 1;
    }
}

fn resolveSymbolsInDylibs(self: *MachO) !void {
    if (self.dylibs.items.len == 0) return;

    var next_sym: usize = 0;
    loop: while (next_sym < self.unresolved.count()) {
        const sym = self.undefs.items[self.unresolved.keys()[next_sym]];
        const sym_name = self.getString(sym.n_strx);

        for (self.dylibs.items) |dylib, id| {
            if (!dylib.symbols.contains(sym_name)) continue;

            const dylib_id = @intCast(u16, id);
            if (!self.referenced_dylibs.contains(dylib_id)) {
                try self.addLoadDylibLC(dylib_id);
                try self.referenced_dylibs.putNoClobber(self.base.allocator, dylib_id, {});
            }

            const ordinal = self.referenced_dylibs.getIndex(dylib_id) orelse unreachable;
            const resolv = self.symbol_resolver.getPtr(sym.n_strx) orelse unreachable;
            const undef = &self.undefs.items[resolv.where_index];
            undef.n_type |= macho.N_EXT;
            undef.n_desc = @intCast(u16, ordinal + 1) * macho.N_SYMBOL_RESOLVER;

            if (self.unresolved.fetchSwapRemove(resolv.where_index)) |entry| outer_blk: {
                switch (entry.value) {
                    .none => {},
                    .got => return error.TODOGotHint,
                    .stub => {
                        if (self.stubs_map.contains(sym.n_strx)) break :outer_blk;
                        const stub_helper_atom = blk: {
                            const match = MatchingSection{
                                .seg = self.text_segment_cmd_index.?,
                                .sect = self.stub_helper_section_index.?,
                            };
                            const atom = try self.createStubHelperAtom();
                            const atom_sym = &self.locals.items[atom.local_sym_index];
                            const alignment = try math.powi(u32, 2, atom.alignment);
                            const vaddr = try self.allocateAtom(atom, atom.size, alignment, match);
                            atom_sym.n_value = vaddr;
                            atom_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
                            break :blk atom;
                        };
                        const laptr_atom = blk: {
                            const match = MatchingSection{
                                .seg = self.data_segment_cmd_index.?,
                                .sect = self.la_symbol_ptr_section_index.?,
                            };
                            const atom = try self.createLazyPointerAtom(
                                stub_helper_atom.local_sym_index,
                                sym.n_strx,
                            );
                            const atom_sym = &self.locals.items[atom.local_sym_index];
                            const alignment = try math.powi(u32, 2, atom.alignment);
                            const vaddr = try self.allocateAtom(atom, atom.size, alignment, match);
                            atom_sym.n_value = vaddr;
                            atom_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
                            break :blk atom;
                        };
                        const stub_atom = blk: {
                            const match = MatchingSection{
                                .seg = self.text_segment_cmd_index.?,
                                .sect = self.stubs_section_index.?,
                            };
                            const atom = try self.createStubAtom(laptr_atom.local_sym_index);
                            const atom_sym = &self.locals.items[atom.local_sym_index];
                            const alignment = try math.powi(u32, 2, atom.alignment);
                            const vaddr = try self.allocateAtom(atom, atom.size, alignment, match);
                            atom_sym.n_value = vaddr;
                            atom_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
                            break :blk atom;
                        };
                        try self.stubs_map.putNoClobber(self.base.allocator, sym.n_strx, stub_atom);
                    },
                }
            }

            continue :loop;
        }

        next_sym += 1;
    }
}

fn resolveDyldStubBinder(self: *MachO) !void {
    if (self.dyld_stub_binder_index != null) return;

    const n_strx = try self.makeString("dyld_stub_binder");
    const sym_index = @intCast(u32, self.undefs.items.len);
    try self.undefs.append(self.base.allocator, .{
        .n_strx = n_strx,
        .n_type = macho.N_UNDF,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    try self.symbol_resolver.putNoClobber(self.base.allocator, n_strx, .{
        .where = .undef,
        .where_index = sym_index,
    });
    const sym = &self.undefs.items[sym_index];
    const sym_name = self.getString(n_strx);

    for (self.dylibs.items) |dylib, id| {
        if (!dylib.symbols.contains(sym_name)) continue;

        const dylib_id = @intCast(u16, id);
        if (!self.referenced_dylibs.contains(dylib_id)) {
            try self.addLoadDylibLC(dylib_id);
            try self.referenced_dylibs.putNoClobber(self.base.allocator, dylib_id, {});
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
    const target = Atom.Relocation.Target{ .global = n_strx };
    const atom = try self.createGotAtom(target);
    try self.got_entries_map.putNoClobber(self.base.allocator, target, atom);
    const match = MatchingSection{
        .seg = self.data_const_segment_cmd_index.?,
        .sect = self.got_section_index.?,
    };
    const atom_sym = &self.locals.items[atom.local_sym_index];
    const vaddr = try self.allocateAtom(atom, @sizeOf(u64), 8, match);
    atom_sym.n_value = vaddr;
    atom_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
    log.debug("allocated {s} atom at 0x{x}", .{ self.getString(sym.n_strx), vaddr });
}

fn parseObjectsIntoAtoms(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var parsed_atoms = std.AutoArrayHashMap(MatchingSection, *Atom).init(self.base.allocator);
    defer parsed_atoms.deinit();

    var first_atoms = std.AutoArrayHashMap(MatchingSection, *Atom).init(self.base.allocator);
    defer first_atoms.deinit();

    var section_metadata = std.AutoHashMap(MatchingSection, struct {
        size: u64,
        alignment: u32,
    }).init(self.base.allocator);
    defer section_metadata.deinit();

    for (self.objects.items) |*object| {
        if (object.analyzed) continue;

        try object.parseIntoAtoms(self.base.allocator, self);

        var it = object.end_atoms.iterator();
        while (it.next()) |entry| {
            const match = entry.key_ptr.*;
            const last_atom = entry.value_ptr.*;
            var atom = last_atom;

            const metadata = try section_metadata.getOrPut(match);
            if (!metadata.found_existing) {
                metadata.value_ptr.* = .{
                    .size = 0,
                    .alignment = 0,
                };
            }

            while (true) {
                const alignment = try math.powi(u32, 2, atom.alignment);
                metadata.value_ptr.size += mem.alignForwardGeneric(u64, atom.size, alignment);
                metadata.value_ptr.alignment = math.max(metadata.value_ptr.alignment, atom.alignment);

                const sym = self.locals.items[atom.local_sym_index];
                log.debug("  {s}: n_value=0x{x}, size=0x{x}, alignment=0x{x}", .{
                    self.getString(sym.n_strx),
                    sym.n_value,
                    atom.size,
                    atom.alignment,
                });

                if (atom.prev) |prev| {
                    atom = prev;
                } else break;
            }

            if (parsed_atoms.getPtr(match)) |last| {
                last.*.next = atom;
                atom.prev = last.*;
                last.* = atom;
            }
            _ = try parsed_atoms.put(match, last_atom);

            if (!first_atoms.contains(match)) {
                try first_atoms.putNoClobber(match, atom);
            }
        }

        object.analyzed = true;
    }

    var it = section_metadata.iterator();
    while (it.next()) |entry| {
        const match = entry.key_ptr.*;
        const metadata = entry.value_ptr.*;
        const seg = &self.load_commands.items[match.seg].Segment;
        const sect = &seg.sections.items[match.sect];
        log.debug("{s},{s} => size: 0x{x}, alignment: 0x{x}", .{
            commands.segmentName(sect.*),
            commands.sectionName(sect.*),
            metadata.size,
            metadata.alignment,
        });

        const sect_size = if (self.atoms.get(match)) |last| blk: {
            const last_atom_sym = self.locals.items[last.local_sym_index];
            break :blk last_atom_sym.n_value + last.size - sect.addr;
        } else 0;

        sect.@"align" = math.max(sect.@"align", metadata.alignment);
        const needed_size = @intCast(u32, metadata.size + sect_size);
        try self.growSection(match, needed_size);
        sect.size = needed_size;

        var base_vaddr = if (self.atoms.get(match)) |last| blk: {
            const last_atom_sym = self.locals.items[last.local_sym_index];
            break :blk last_atom_sym.n_value + last.size;
        } else sect.addr;
        const n_sect = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);

        var atom = first_atoms.get(match).?;
        while (true) {
            const alignment = try math.powi(u32, 2, atom.alignment);
            base_vaddr = mem.alignForwardGeneric(u64, base_vaddr, alignment);

            const sym = &self.locals.items[atom.local_sym_index];
            sym.n_value = base_vaddr;
            sym.n_sect = n_sect;

            log.debug("  {s}: start=0x{x}, end=0x{x}, size=0x{x}, alignment=0x{x}", .{
                self.getString(sym.n_strx),
                base_vaddr,
                base_vaddr + atom.size,
                atom.size,
                atom.alignment,
            });

            // Update each alias (if any)
            for (atom.aliases.items) |index| {
                const alias_sym = &self.locals.items[index];
                alias_sym.n_value = base_vaddr;
                alias_sym.n_sect = n_sect;
            }

            // Update each symbol contained within the atom
            for (atom.contained.items) |sym_at_off| {
                const contained_sym = &self.locals.items[sym_at_off.local_sym_index];
                contained_sym.n_value = base_vaddr + sym_at_off.offset;
                contained_sym.n_sect = n_sect;
            }

            base_vaddr += atom.size;

            if (atom.next) |next| {
                atom = next;
            } else break;
        }

        if (self.atoms.getPtr(match)) |last| {
            const first_atom = first_atoms.get(match).?;
            last.*.next = first_atom;
            first_atom.prev = last.*;
            last.* = first_atom;
        }
        _ = try self.atoms.put(self.base.allocator, match, parsed_atoms.get(match).?);
    }
}

fn addLoadDylibLC(self: *MachO, id: u16) !void {
    const dylib = self.dylibs.items[id];
    const dylib_id = dylib.id orelse unreachable;
    var dylib_cmd = try commands.createLoadDylibCommand(
        self.base.allocator,
        dylib_id.name,
        dylib_id.timestamp,
        dylib_id.current_version,
        dylib_id.compatibility_version,
    );
    errdefer dylib_cmd.deinit(self.base.allocator);
    try self.load_commands.append(self.base.allocator, .{ .Dylib = dylib_cmd });
    self.load_commands_dirty = true;
}

fn addCodeSignatureLC(self: *MachO) !void {
    if (self.code_signature_cmd_index != null or !self.requires_adhoc_codesig) return;
    self.code_signature_cmd_index = @intCast(u16, self.load_commands.items.len);
    try self.load_commands.append(self.base.allocator, .{
        .LinkeditData = .{
            .cmd = macho.LC_CODE_SIGNATURE,
            .cmdsize = @sizeOf(macho.linkedit_data_command),
            .dataoff = 0,
            .datasize = 0,
        },
    });
    self.load_commands_dirty = true;
}

fn setEntryPoint(self: *MachO) !void {
    if (self.base.options.output_mode != .Exe) return;

    // TODO we should respect the -entry flag passed in by the user to set a custom
    // entrypoint. For now, assume default of `_main`.
    const seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const n_strx = self.strtab_dir.getKeyAdapted(@as([]const u8, "_main"), StringIndexAdapter{
        .bytes = &self.strtab,
    }) orelse {
        log.err("'_main' export not found", .{});
        return error.MissingMainEntrypoint;
    };
    const resolv = self.symbol_resolver.get(n_strx) orelse unreachable;
    assert(resolv.where == .global);
    const sym = self.globals.items[resolv.where_index];
    const ec = &self.load_commands.items[self.main_cmd_index.?].Main;
    ec.entryoff = @intCast(u32, sym.n_value - seg.inner.vmaddr);
    ec.stacksize = self.base.options.stack_size_override orelse 0;
    self.entry_addr = sym.n_value;
    self.load_commands_dirty = true;
}

pub fn deinit(self: *MachO) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(self.base.allocator);
    }

    if (self.d_sym) |*ds| {
        ds.deinit(self.base.allocator);
    }

    self.section_ordinals.deinit(self.base.allocator);
    self.got_entries_map.deinit(self.base.allocator);
    self.got_entries_map_free_list.deinit(self.base.allocator);
    self.stubs_map.deinit(self.base.allocator);
    self.stubs_map_free_list.deinit(self.base.allocator);
    self.strtab_dir.deinit(self.base.allocator);
    self.strtab.deinit(self.base.allocator);
    self.undefs.deinit(self.base.allocator);
    self.globals.deinit(self.base.allocator);
    self.globals_free_list.deinit(self.base.allocator);
    self.locals.deinit(self.base.allocator);
    self.locals_free_list.deinit(self.base.allocator);
    self.symbol_resolver.deinit(self.base.allocator);
    self.unresolved.deinit(self.base.allocator);
    self.tentatives.deinit(self.base.allocator);

    for (self.objects.items) |*object| {
        object.deinit(self.base.allocator);
    }
    self.objects.deinit(self.base.allocator);

    for (self.archives.items) |*archive| {
        archive.deinit(self.base.allocator);
    }
    self.archives.deinit(self.base.allocator);

    for (self.dylibs.items) |*dylib| {
        dylib.deinit(self.base.allocator);
    }
    self.dylibs.deinit(self.base.allocator);
    self.dylibs_map.deinit(self.base.allocator);
    self.referenced_dylibs.deinit(self.base.allocator);

    for (self.load_commands.items) |*lc| {
        lc.deinit(self.base.allocator);
    }
    self.load_commands.deinit(self.base.allocator);

    for (self.managed_atoms.items) |atom| {
        atom.deinit(self.base.allocator);
        self.base.allocator.destroy(atom);
    }
    self.managed_atoms.deinit(self.base.allocator);
    self.atoms.deinit(self.base.allocator);
    {
        var it = self.atom_free_lists.valueIterator();
        while (it.next()) |free_list| {
            free_list.deinit(self.base.allocator);
        }
        self.atom_free_lists.deinit(self.base.allocator);
    }
    for (self.decls.keys()) |decl| {
        decl.link.macho.deinit(self.base.allocator);
    }
    self.decls.deinit(self.base.allocator);
}

pub fn closeFiles(self: MachO) void {
    for (self.objects.items) |object| {
        object.file.close();
    }
    for (self.archives.items) |archive| {
        archive.file.close();
    }
    for (self.dylibs.items) |dylib| {
        dylib.file.close();
    }
}

fn freeAtom(self: *MachO, atom: *Atom, match: MatchingSection) void {
    log.debug("freeAtom {*}", .{atom});
    atom.deinit(self.base.allocator);

    const free_list = self.atom_free_lists.getPtr(match).?;
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
    // TODO process free list for dbg info just like we do above for vaddrs

    if (self.atoms.getPtr(match)) |last_atom| {
        if (last_atom.* == atom) {
            if (atom.prev) |prev| {
                // TODO shrink the section size here
                last_atom.* = prev;
            } else {
                _ = self.atoms.fetchRemove(match);
            }
        }
    }

    if (self.d_sym) |*ds| {
        if (ds.dbg_info_decl_first == atom) {
            ds.dbg_info_decl_first = atom.dbg_info_next;
        }
        if (ds.dbg_info_decl_last == atom) {
            // TODO shrink the .debug_info section size here
            ds.dbg_info_decl_last = atom.dbg_info_prev;
        }
    }

    if (atom.prev) |prev| {
        prev.next = atom.next;

        if (!already_have_free_list_node and prev.freeListEligible(self.*)) {
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

    if (atom.dbg_info_prev) |prev| {
        prev.dbg_info_next = atom.dbg_info_next;

        // TODO the free list logic like we do for atoms above
    } else {
        atom.dbg_info_prev = null;
    }

    if (atom.dbg_info_next) |next| {
        next.dbg_info_prev = atom.dbg_info_prev;
    } else {
        atom.dbg_info_next = null;
    }
}

fn shrinkAtom(self: *MachO, atom: *Atom, new_block_size: u64, match: MatchingSection) void {
    _ = self;
    _ = atom;
    _ = new_block_size;
    _ = match;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn growAtom(self: *MachO, atom: *Atom, new_atom_size: u64, alignment: u64, match: MatchingSection) !u64 {
    const sym = self.locals.items[atom.local_sym_index];
    const align_ok = mem.alignBackwardGeneric(u64, sym.n_value, alignment) == sym.n_value;
    const need_realloc = !align_ok or new_atom_size > atom.capacity(self.*);
    if (!need_realloc) return sym.n_value;
    return self.allocateAtom(atom, new_atom_size, alignment, match);
}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {
    if (self.llvm_object) |_| return;
    if (decl.link.macho.local_sym_index != 0) return;

    try self.locals.ensureUnusedCapacity(self.base.allocator, 1);
    try self.decls.putNoClobber(self.base.allocator, decl, {});

    if (self.locals_free_list.popOrNull()) |i| {
        log.debug("reusing symbol index {d} for {s}", .{ i, decl.name });
        decl.link.macho.local_sym_index = i;
    } else {
        log.debug("allocating symbol index {d} for {s}", .{ self.locals.items.len, decl.name });
        decl.link.macho.local_sym_index = @intCast(u32, self.locals.items.len);
        _ = self.locals.addOneAssumeCapacity();
    }

    self.locals.items[decl.link.macho.local_sym_index] = .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };

    // TODO try popping from free list first before allocating a new GOT atom.
    const target = Atom.Relocation.Target{ .local = decl.link.macho.local_sym_index };
    const value_ptr = blk: {
        if (self.got_entries_map_free_list.popOrNull()) |i| {
            log.debug("reusing GOT entry index {d} for {s}", .{ i, decl.name });
            self.got_entries_map.keys()[i] = target;
            const value_ptr = self.got_entries_map.getPtr(target).?;
            break :blk value_ptr;
        } else {
            const res = try self.got_entries_map.getOrPut(self.base.allocator, target);
            log.debug("creating new GOT entry at index {d} for {s}", .{
                self.got_entries_map.getIndex(target).?,
                decl.name,
            });
            break :blk res.value_ptr;
        }
    };
    value_ptr.* = try self.createGotAtom(target);
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

    const decl = func.owner_decl;
    // TODO clearing the code and relocs buffer should probably be orchestrated
    // in a different, smarter, more automatic way somewhere else, in a more centralised
    // way than this.
    // If we don't clear the buffers here, we are up for some nasty surprises when
    // this atom is reused later on and was not freed by freeAtom().
    decl.link.macho.clearRetainingCapacity();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var debug_buffers_buf: DebugSymbols.DeclDebugBuffers = undefined;
    const debug_buffers = if (self.d_sym) |*ds| blk: {
        debug_buffers_buf = try ds.initDeclDebugBuffers(self.base.allocator, module, decl);
        break :blk &debug_buffers_buf;
    } else null;
    defer {
        if (debug_buffers) |dbg| {
            dbg.dbg_line_buffer.deinit();
            dbg.dbg_info_buffer.deinit();
            var it = dbg.dbg_info_type_relocs.valueIterator();
            while (it.next()) |value| {
                value.relocs.deinit(self.base.allocator);
            }
            dbg.dbg_info_type_relocs.deinit(self.base.allocator);
        }
    }

    self.active_decl = decl;

    const res = if (debug_buffers) |dbg|
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .{
            .dwarf = .{
                .dbg_line = &dbg.dbg_line_buffer,
                .dbg_info = &dbg.dbg_info_buffer,
                .dbg_info_type_relocs = &dbg.dbg_info_type_relocs,
            },
        })
    else
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .none);
    switch (res) {
        .appended => {
            try decl.link.macho.code.appendSlice(self.base.allocator, code_buffer.items);
        },
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, em);
            return;
        },
    }

    _ = try self.placeDecl(decl, decl.link.macho.code.items.len);

    if (debug_buffers) |db| {
        try self.d_sym.?.commitDeclDebugInfo(
            self.base.allocator,
            module,
            decl,
            db,
            self.base.options.target,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
    try self.updateDeclExports(module, decl, decl_exports);
}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(module, decl);
    }
    const tracy = trace(@src());
    defer tracy.end();

    if (decl.val.tag() == .extern_fn) {
        return; // TODO Should we do more when front-end analyzed extern decl?
    }

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var debug_buffers_buf: DebugSymbols.DeclDebugBuffers = undefined;
    const debug_buffers = if (self.d_sym) |*ds| blk: {
        debug_buffers_buf = try ds.initDeclDebugBuffers(self.base.allocator, module, decl);
        break :blk &debug_buffers_buf;
    } else null;
    defer {
        if (debug_buffers) |dbg| {
            dbg.dbg_line_buffer.deinit();
            dbg.dbg_info_buffer.deinit();
            var it = dbg.dbg_info_type_relocs.valueIterator();
            while (it.next()) |value| {
                value.relocs.deinit(self.base.allocator);
            }
            dbg.dbg_info_type_relocs.deinit(self.base.allocator);
        }
    }

    self.active_decl = decl;

    const res = if (debug_buffers) |dbg|
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl.val,
        }, &code_buffer, .{
            .dwarf = .{
                .dbg_line = &dbg.dbg_line_buffer,
                .dbg_info = &dbg.dbg_info_buffer,
                .dbg_info_type_relocs = &dbg.dbg_info_type_relocs,
            },
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl.val,
        }, &code_buffer, .none);

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
                try module.failed_decls.put(module.gpa, decl, em);
                return;
            },
        }
    };
    _ = try self.placeDecl(decl, code.len);

    // Since we updated the vaddr and the size, each corresponding export symbol also
    // needs to be updated.
    const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
    try self.updateDeclExports(module, decl, decl_exports);
}

fn placeDecl(self: *MachO, decl: *Module.Decl, code_len: usize) !*macho.nlist_64 {
    const required_alignment = decl.ty.abiAlignment(self.base.options.target);
    assert(decl.link.macho.local_sym_index != 0); // Caller forgot to call allocateDeclIndexes()
    const symbol = &self.locals.items[decl.link.macho.local_sym_index];

    if (decl.link.macho.size != 0) {
        const capacity = decl.link.macho.capacity(self.*);
        const need_realloc = code_len > capacity or !mem.isAlignedGeneric(u64, symbol.n_value, required_alignment);
        if (need_realloc) {
            const vaddr = try self.growAtom(&decl.link.macho, code_len, required_alignment, .{
                .seg = self.text_segment_cmd_index.?,
                .sect = self.text_section_index.?,
            });

            log.debug("growing {s} and moving from 0x{x} to 0x{x}", .{ decl.name, symbol.n_value, vaddr });

            if (vaddr != symbol.n_value) {
                log.debug(" (writing new GOT entry)", .{});
                const got_atom = self.got_entries_map.get(.{ .local = decl.link.macho.local_sym_index }).?;
                const got_sym = &self.locals.items[got_atom.local_sym_index];
                const got_vaddr = try self.allocateAtom(got_atom, @sizeOf(u64), 8, .{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.got_section_index.?,
                });
                got_sym.n_value = got_vaddr;
                got_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(.{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.got_section_index.?,
                }).? + 1);
                got_atom.dirty = true;
            }

            symbol.n_value = vaddr;
        } else if (code_len < decl.link.macho.size) {
            self.shrinkAtom(&decl.link.macho, code_len, .{
                .seg = self.text_segment_cmd_index.?,
                .sect = self.text_section_index.?,
            });
        }
        decl.link.macho.size = code_len;
        decl.link.macho.dirty = true;

        const new_name = try std.fmt.allocPrint(self.base.allocator, "_{s}", .{mem.spanZ(decl.name)});
        defer self.base.allocator.free(new_name);

        symbol.n_strx = try self.makeString(new_name);
        symbol.n_type = macho.N_SECT;
        symbol.n_sect = @intCast(u8, self.text_section_index.?) + 1;
        symbol.n_desc = 0;
    } else {
        const decl_name = try std.fmt.allocPrint(self.base.allocator, "_{s}", .{mem.spanZ(decl.name)});
        defer self.base.allocator.free(decl_name);

        const name_str_index = try self.makeString(decl_name);
        const addr = try self.allocateAtom(&decl.link.macho, code_len, required_alignment, .{
            .seg = self.text_segment_cmd_index.?,
            .sect = self.text_section_index.?,
        });

        log.debug("allocated atom for {s} at 0x{x}", .{ decl_name, addr });

        errdefer self.freeAtom(&decl.link.macho, .{
            .seg = self.text_segment_cmd_index.?,
            .sect = self.text_section_index.?,
        });

        symbol.* = .{
            .n_strx = name_str_index,
            .n_type = macho.N_SECT,
            .n_sect = @intCast(u8, self.text_section_index.?) + 1,
            .n_desc = 0,
            .n_value = addr,
        };
        const got_atom = self.got_entries_map.get(.{ .local = decl.link.macho.local_sym_index }).?;
        const got_sym = &self.locals.items[got_atom.local_sym_index];
        const vaddr = try self.allocateAtom(got_atom, @sizeOf(u64), 8, .{
            .seg = self.data_const_segment_cmd_index.?,
            .sect = self.got_section_index.?,
        });
        got_sym.n_value = vaddr;
        got_sym.n_sect = @intCast(u8, self.section_ordinals.getIndex(.{
            .seg = self.data_const_segment_cmd_index.?,
            .sect = self.got_section_index.?,
        }).? + 1);
    }

    return symbol;
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {
    if (self.d_sym) |*ds| {
        try ds.updateDeclLineNumber(module, decl);
    }
}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl: *Module.Decl,
    exports: []const *Module.Export,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .macho) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDeclExports(module, decl, exports);
    }
    const tracy = trace(@src());
    defer tracy.end();

    try self.globals.ensureUnusedCapacity(self.base.allocator, exports.len);
    if (decl.link.macho.local_sym_index == 0) return;
    const decl_sym = &self.locals.items[decl.link.macho.local_sym_index];

    for (exports) |exp| {
        const exp_name = try std.fmt.allocPrint(self.base.allocator, "_{s}", .{exp.options.name});
        defer self.base.allocator.free(exp_name);

        if (exp.options.section) |section_name| {
            if (!mem.eql(u8, section_name, "__text")) {
                try module.failed_exports.putNoClobber(
                    module.gpa,
                    exp,
                    try Module.ErrorMsg.create(
                        self.base.allocator,
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
                    self.base.allocator,
                    decl.srcLoc(),
                    "Unimplemented: GlobalLinkage.LinkOnce",
                    .{},
                ),
            );
            continue;
        }

        const is_weak = exp.options.linkage == .Internal or exp.options.linkage == .Weak;
        const n_strx = try self.makeString(exp_name);
        if (self.symbol_resolver.getPtr(n_strx)) |resolv| {
            switch (resolv.where) {
                .global => {
                    if (resolv.local_sym_index == decl.link.macho.local_sym_index) continue;

                    const sym = &self.globals.items[resolv.where_index];

                    if (symbolIsTentative(sym.*)) {
                        assert(self.tentatives.swapRemove(resolv.where_index));
                    } else if (!is_weak and !(symbolIsWeakDef(sym.*) or symbolIsPext(sym.*))) {
                        _ = try module.failed_exports.put(
                            module.gpa,
                            exp,
                            try Module.ErrorMsg.create(
                                self.base.allocator,
                                decl.srcLoc(),
                                \\LinkError: symbol '{s}' defined multiple times
                                \\  first definition in '{s}'
                            ,
                                .{ exp_name, self.objects.items[resolv.file.?].name },
                            ),
                        );
                        continue;
                    } else if (is_weak) continue; // Current symbol is weak, so skip it.

                    // Otherwise, update the resolver and the global symbol.
                    sym.n_type = macho.N_SECT | macho.N_EXT;
                    resolv.local_sym_index = decl.link.macho.local_sym_index;
                    resolv.file = null;
                    exp.link.macho.sym_index = resolv.where_index;

                    continue;
                },
                .undef => {
                    assert(self.unresolved.swapRemove(resolv.where_index));
                    _ = self.symbol_resolver.remove(n_strx);
                },
            }
        }

        var n_type: u8 = macho.N_SECT | macho.N_EXT;
        var n_desc: u16 = 0;

        switch (exp.options.linkage) {
            .Internal => {
                // Symbol should be hidden, or in MachO lingo, private extern.
                // We should also mark the symbol as Weak: n_desc == N_WEAK_DEF.
                // TODO work out when to add N_WEAK_REF.
                n_type |= macho.N_PEXT;
                n_desc |= macho.N_WEAK_DEF;
            },
            .Strong => {},
            .Weak => {
                // Weak linkage is specified as part of n_desc field.
                // Symbol's n_type is like for a symbol with strong linkage.
                n_desc |= macho.N_WEAK_DEF;
            },
            else => unreachable,
        }

        const global_sym_index = if (exp.link.macho.sym_index) |i| i else blk: {
            const i = if (self.globals_free_list.popOrNull()) |i| i else inner: {
                _ = self.globals.addOneAssumeCapacity();
                break :inner @intCast(u32, self.globals.items.len - 1);
            };
            break :blk i;
        };
        const sym = &self.globals.items[global_sym_index];
        sym.* = .{
            .n_strx = try self.makeString(exp_name),
            .n_type = n_type,
            .n_sect = @intCast(u8, self.text_section_index.?) + 1,
            .n_desc = n_desc,
            .n_value = decl_sym.n_value,
        };
        exp.link.macho.sym_index = global_sym_index;

        try self.symbol_resolver.putNoClobber(self.base.allocator, n_strx, .{
            .where = .global,
            .where_index = global_sym_index,
            .local_sym_index = decl.link.macho.local_sym_index,
        });
    }
}

pub fn deleteExport(self: *MachO, exp: Export) void {
    if (self.llvm_object) |_| return;
    const sym_index = exp.sym_index orelse return;
    self.globals_free_list.append(self.base.allocator, sym_index) catch {};
    const global = &self.globals.items[sym_index];
    log.debug("deleting export '{s}': {}", .{ self.getString(global.n_strx), global });
    assert(self.symbol_resolver.remove(global.n_strx));
    global.n_type = 0;
    global.n_strx = 0;
    global.n_value = 0;
}

pub fn freeDecl(self: *MachO, decl: *Module.Decl) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl);
    }
    log.debug("freeDecl {*}", .{decl});
    _ = self.decls.swapRemove(decl);
    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    self.freeAtom(&decl.link.macho, .{
        .seg = self.text_segment_cmd_index.?,
        .sect = self.text_section_index.?,
    });
    if (decl.link.macho.local_sym_index != 0) {
        self.locals_free_list.append(self.base.allocator, decl.link.macho.local_sym_index) catch {};

        // Try freeing GOT atom
        const got_index = self.got_entries_map.getIndex(.{ .local = decl.link.macho.local_sym_index }).?;
        self.got_entries_map_free_list.append(self.base.allocator, @intCast(u32, got_index)) catch {};

        self.locals.items[decl.link.macho.local_sym_index].n_type = 0;
        decl.link.macho.local_sym_index = 0;
    }
    if (self.d_sym) |*ds| {
        // TODO make this logic match freeAtom. Maybe abstract the logic
        // out since the same thing is desired for both.
        _ = ds.dbg_line_fn_free_list.remove(&decl.fn_link.macho);
        if (decl.fn_link.macho.prev) |prev| {
            ds.dbg_line_fn_free_list.put(self.base.allocator, prev, {}) catch {};
            prev.next = decl.fn_link.macho.next;
            if (decl.fn_link.macho.next) |next| {
                next.prev = prev;
            } else {
                ds.dbg_line_fn_last = prev;
            }
        } else if (decl.fn_link.macho.next) |next| {
            ds.dbg_line_fn_first = next;
            next.prev = null;
        }
        if (ds.dbg_line_fn_first == &decl.fn_link.macho) {
            ds.dbg_line_fn_first = decl.fn_link.macho.next;
        }
        if (ds.dbg_line_fn_last == &decl.fn_link.macho) {
            ds.dbg_line_fn_last = decl.fn_link.macho.prev;
        }
    }
}

pub fn getDeclVAddr(self: *MachO, decl: *const Module.Decl) u64 {
    assert(decl.link.macho.local_sym_index != 0);
    return self.locals.items[decl.link.macho.local_sym_index].n_value;
}

pub fn populateMissingMetadata(self: *MachO) !void {
    if (self.pagezero_segment_cmd_index == null) {
        self.pagezero_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .inner = .{
                    .segname = makeStaticString("__PAGEZERO"),
                    .vmsize = pagezero_vmsize,
                },
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.text_segment_cmd_index == null) {
        self.text_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const program_code_size_hint = self.base.options.program_code_size_hint;
        const got_size_hint = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const ideal_size = self.header_pad + program_code_size_hint + got_size_hint;
        const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);

        log.debug("found __TEXT segment free space 0x{x} to 0x{x}", .{ 0, needed_size });

        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .inner = .{
                    .segname = makeStaticString("__TEXT"),
                    .vmaddr = pagezero_vmsize,
                    .vmsize = needed_size,
                    .filesize = needed_size,
                    .maxprot = macho.VM_PROT_READ | macho.VM_PROT_EXECUTE,
                    .initprot = macho.VM_PROT_READ | macho.VM_PROT_EXECUTE,
                },
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.text_section_index == null) {
        const alignment: u2 = switch (self.base.options.target.cpu.arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const needed_size = self.base.options.program_code_size_hint;
        self.text_section_index = try self.allocateSection(
            self.text_segment_cmd_index.?,
            "__text",
            needed_size,
            alignment,
            .{
                .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            },
        );
    }

    if (self.stubs_section_index == null) {
        const alignment: u2 = switch (self.base.options.target.cpu.arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const stub_size: u4 = switch (self.base.options.target.cpu.arch) {
            .x86_64 => 6,
            .aarch64 => 3 * @sizeOf(u32),
            else => unreachable, // unhandled architecture type
        };
        const needed_size = stub_size * self.base.options.symbol_count_hint;
        self.stubs_section_index = try self.allocateSection(
            self.text_segment_cmd_index.?,
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
        const alignment: u2 = switch (self.base.options.target.cpu.arch) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const preamble_size: u6 = switch (self.base.options.target.cpu.arch) {
            .x86_64 => 15,
            .aarch64 => 6 * @sizeOf(u32),
            else => unreachable,
        };
        const stub_size: u4 = switch (self.base.options.target.cpu.arch) {
            .x86_64 => 10,
            .aarch64 => 3 * @sizeOf(u32),
            else => unreachable,
        };
        const needed_size = stub_size * self.base.options.symbol_count_hint + preamble_size;
        self.stub_helper_section_index = try self.allocateSection(
            self.text_segment_cmd_index.?,
            "__stub_helper",
            needed_size,
            alignment,
            .{
                .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            },
        );
    }

    if (self.data_const_segment_cmd_index == null) {
        self.data_const_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const address_and_offset = self.nextSegmentAddressAndOffset();
        const ideal_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);

        log.debug("found __DATA_CONST segment free space 0x{x} to 0x{x}", .{
            address_and_offset.offset,
            address_and_offset.offset + needed_size,
        });

        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .inner = .{
                    .segname = makeStaticString("__DATA_CONST"),
                    .vmaddr = address_and_offset.address,
                    .vmsize = needed_size,
                    .fileoff = address_and_offset.offset,
                    .filesize = needed_size,
                    .maxprot = macho.VM_PROT_READ | macho.VM_PROT_WRITE,
                    .initprot = macho.VM_PROT_READ | macho.VM_PROT_WRITE,
                },
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.got_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.got_section_index = try self.allocateSection(
            self.data_const_segment_cmd_index.?,
            "__got",
            needed_size,
            alignment,
            .{
                .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
            },
        );
    }

    if (self.data_segment_cmd_index == null) {
        self.data_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const address_and_offset = self.nextSegmentAddressAndOffset();
        const ideal_size = 2 * @sizeOf(u64) * self.base.options.symbol_count_hint;
        const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.page_size);

        log.debug("found __DATA segment free space 0x{x} to 0x{x}", .{ address_and_offset.offset, address_and_offset.offset + needed_size });

        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .inner = .{
                    .segname = makeStaticString("__DATA"),
                    .vmaddr = address_and_offset.address,
                    .vmsize = needed_size,
                    .fileoff = address_and_offset.offset,
                    .filesize = needed_size,
                    .maxprot = macho.VM_PROT_READ | macho.VM_PROT_WRITE,
                    .initprot = macho.VM_PROT_READ | macho.VM_PROT_WRITE,
                },
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.la_symbol_ptr_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.la_symbol_ptr_section_index = try self.allocateSection(
            self.data_segment_cmd_index.?,
            "__la_symbol_ptr",
            needed_size,
            alignment,
            .{
                .flags = macho.S_LAZY_SYMBOL_POINTERS,
            },
        );
    }

    if (self.data_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.data_section_index = try self.allocateSection(
            self.data_segment_cmd_index.?,
            "__data",
            needed_size,
            alignment,
            .{},
        );
    }

    if (self.tlv_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.tlv_section_index = try self.allocateSection(
            self.data_segment_cmd_index.?,
            "__thread_vars",
            needed_size,
            alignment,
            .{
                .flags = macho.S_THREAD_LOCAL_VARIABLES,
            },
        );
    }

    if (self.tlv_data_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.tlv_data_section_index = try self.allocateSection(
            self.data_segment_cmd_index.?,
            "__thread_data",
            needed_size,
            alignment,
            .{
                .flags = macho.S_THREAD_LOCAL_REGULAR,
            },
        );
    }

    if (self.tlv_bss_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.tlv_bss_section_index = try self.allocateSection(
            self.data_segment_cmd_index.?,
            "__thread_bss",
            needed_size,
            alignment,
            .{
                .flags = macho.S_THREAD_LOCAL_ZEROFILL,
            },
        );
        const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[self.tlv_bss_section_index.?];
        self.tlv_bss_file_offset = sect.offset;
    }

    if (self.bss_section_index == null) {
        const needed_size = @sizeOf(u64) * self.base.options.symbol_count_hint;
        const alignment: u16 = 3; // 2^3 = @sizeOf(u64)
        self.bss_section_index = try self.allocateSection(
            self.data_segment_cmd_index.?,
            "__bss",
            needed_size,
            alignment,
            .{
                .flags = macho.S_ZEROFILL,
            },
        );
        const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[self.bss_section_index.?];
        self.bss_file_offset = sect.offset;
    }

    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const address_and_offset = self.nextSegmentAddressAndOffset();

        log.debug("found __LINKEDIT segment free space at 0x{x}", .{address_and_offset.offset});

        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .inner = .{
                    .segname = makeStaticString("__LINKEDIT"),
                    .vmaddr = address_and_offset.address,
                    .fileoff = address_and_offset.offset,
                    .maxprot = macho.VM_PROT_READ,
                    .initprot = macho.VM_PROT_READ,
                },
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.dyld_info_cmd_index == null) {
        self.dyld_info_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .DyldInfoOnly = .{
                .cmd = macho.LC_DYLD_INFO_ONLY,
                .cmdsize = @sizeOf(macho.dyld_info_command),
                .rebase_off = 0,
                .rebase_size = 0,
                .bind_off = 0,
                .bind_size = 0,
                .weak_bind_off = 0,
                .weak_bind_size = 0,
                .lazy_bind_off = 0,
                .lazy_bind_size = 0,
                .export_off = 0,
                .export_size = 0,
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.symtab_cmd_index == null) {
        self.symtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Symtab = .{
                .cmd = macho.LC_SYMTAB,
                .cmdsize = @sizeOf(macho.symtab_command),
                .symoff = 0,
                .nsyms = 0,
                .stroff = 0,
                .strsize = 0,
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.dysymtab_cmd_index == null) {
        self.dysymtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Dysymtab = .{
                .cmd = macho.LC_DYSYMTAB,
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
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.dylinker_cmd_index == null) {
        self.dylinker_cmd_index = @intCast(u16, self.load_commands.items.len);
        const cmdsize = @intCast(u32, mem.alignForwardGeneric(
            u64,
            @sizeOf(macho.dylinker_command) + mem.lenZ(default_dyld_path),
            @sizeOf(u64),
        ));
        var dylinker_cmd = commands.emptyGenericCommandWithData(macho.dylinker_command{
            .cmd = macho.LC_LOAD_DYLINKER,
            .cmdsize = cmdsize,
            .name = @sizeOf(macho.dylinker_command),
        });
        dylinker_cmd.data = try self.base.allocator.alloc(u8, cmdsize - dylinker_cmd.inner.name);
        mem.set(u8, dylinker_cmd.data, 0);
        mem.copy(u8, dylinker_cmd.data, mem.spanZ(default_dyld_path));
        try self.load_commands.append(self.base.allocator, .{ .Dylinker = dylinker_cmd });
        self.load_commands_dirty = true;
    }

    if (self.main_cmd_index == null and self.base.options.output_mode == .Exe) {
        self.main_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Main = .{
                .cmd = macho.LC_MAIN,
                .cmdsize = @sizeOf(macho.entry_point_command),
                .entryoff = 0x0,
                .stacksize = 0,
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.dylib_id_cmd_index == null and self.base.options.output_mode == .Lib) {
        self.dylib_id_cmd_index = @intCast(u16, self.load_commands.items.len);
        const install_name = try std.fmt.allocPrint(self.base.allocator, "@rpath/{s}", .{
            self.base.options.emit.?.sub_path,
        });
        defer self.base.allocator.free(install_name);
        var dylib_cmd = try commands.createLoadDylibCommand(
            self.base.allocator,
            install_name,
            2,
            0x10000, // TODO forward user-provided versions
            0x10000,
        );
        errdefer dylib_cmd.deinit(self.base.allocator);
        dylib_cmd.inner.cmd = macho.LC_ID_DYLIB;
        try self.load_commands.append(self.base.allocator, .{ .Dylib = dylib_cmd });
        self.load_commands_dirty = true;
    }

    if (self.source_version_cmd_index == null) {
        self.source_version_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .SourceVersion = .{
                .cmd = macho.LC_SOURCE_VERSION,
                .cmdsize = @sizeOf(macho.source_version_command),
                .version = 0x0,
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.build_version_cmd_index == null) {
        self.build_version_cmd_index = @intCast(u16, self.load_commands.items.len);
        const cmdsize = @intCast(u32, mem.alignForwardGeneric(
            u64,
            @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version),
            @sizeOf(u64),
        ));
        const ver = self.base.options.target.os.version_range.semver.min;
        const version = ver.major << 16 | ver.minor << 8 | ver.patch;
        const is_simulator_abi = self.base.options.target.abi == .simulator;
        var cmd = commands.emptyGenericCommandWithData(macho.build_version_command{
            .cmd = macho.LC_BUILD_VERSION,
            .cmdsize = cmdsize,
            .platform = switch (self.base.options.target.os.tag) {
                .macos => macho.PLATFORM_MACOS,
                .ios => if (is_simulator_abi) macho.PLATFORM_IOSSIMULATOR else macho.PLATFORM_IOS,
                .watchos => if (is_simulator_abi) macho.PLATFORM_WATCHOSSIMULATOR else macho.PLATFORM_WATCHOS,
                .tvos => if (is_simulator_abi) macho.PLATFORM_TVOSSIMULATOR else macho.PLATFORM_TVOS,
                else => unreachable,
            },
            .minos = version,
            .sdk = version,
            .ntools = 1,
        });
        const ld_ver = macho.build_tool_version{
            .tool = macho.TOOL_LD,
            .version = 0x0,
        };
        cmd.data = try self.base.allocator.alloc(u8, cmdsize - @sizeOf(macho.build_version_command));
        mem.set(u8, cmd.data, 0);
        mem.copy(u8, cmd.data, mem.asBytes(&ld_ver));
        try self.load_commands.append(self.base.allocator, .{ .BuildVersion = cmd });
        self.load_commands_dirty = true;
    }

    if (self.uuid_cmd_index == null) {
        self.uuid_cmd_index = @intCast(u16, self.load_commands.items.len);
        var uuid_cmd: macho.uuid_command = .{
            .cmd = macho.LC_UUID,
            .cmdsize = @sizeOf(macho.uuid_command),
            .uuid = undefined,
        };
        std.crypto.random.bytes(&uuid_cmd.uuid);
        try self.load_commands.append(self.base.allocator, .{ .Uuid = uuid_cmd });
        self.load_commands_dirty = true;
    }

    if (self.data_in_code_cmd_index == null) {
        self.data_in_code_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .LinkeditData = .{
                .cmd = macho.LC_DATA_IN_CODE,
                .cmdsize = @sizeOf(macho.linkedit_data_command),
                .dataoff = 0,
                .datasize = 0,
            },
        });
        self.load_commands_dirty = true;
    }

    self.cold_start = true;
}

const AllocateSectionOpts = struct {
    flags: u32 = macho.S_REGULAR,
    reserved1: u32 = 0,
    reserved2: u32 = 0,
};

fn allocateSection(
    self: *MachO,
    segment_id: u16,
    sectname: []const u8,
    size: u64,
    alignment: u32,
    opts: AllocateSectionOpts,
) !u16 {
    const seg = &self.load_commands.items[segment_id].Segment;
    var sect = macho.section_64{
        .sectname = makeStaticString(sectname),
        .segname = seg.inner.segname,
        .size = @intCast(u32, size),
        .@"align" = alignment,
        .flags = opts.flags,
        .reserved1 = opts.reserved1,
        .reserved2 = opts.reserved2,
    };

    const alignment_pow_2 = try math.powi(u32, 2, alignment);
    const padding: ?u64 = if (segment_id == self.text_segment_cmd_index.?) self.header_pad else null;
    const off = self.findFreeSpace(segment_id, alignment_pow_2, padding);

    log.debug("allocating {s},{s} section from 0x{x} to 0x{x}", .{
        commands.segmentName(sect),
        commands.sectionName(sect),
        off,
        off + size,
    });

    sect.addr = seg.inner.vmaddr + off - seg.inner.fileoff;
    sect.offset = @intCast(u32, off);

    const index = @intCast(u16, seg.sections.items.len);
    try seg.sections.append(self.base.allocator, sect);
    seg.inner.cmdsize += @sizeOf(macho.section_64);
    seg.inner.nsects += 1;

    const match = MatchingSection{
        .seg = segment_id,
        .sect = index,
    };
    _ = try self.section_ordinals.getOrPut(self.base.allocator, match);
    try self.atom_free_lists.putNoClobber(self.base.allocator, match, .{});

    self.load_commands_dirty = true;
    self.sections_order_dirty = true;

    return index;
}

fn findFreeSpace(self: MachO, segment_id: u16, alignment: u64, start: ?u64) u64 {
    const seg = self.load_commands.items[segment_id].Segment;
    if (seg.sections.items.len == 0) {
        return if (start) |v| v else seg.inner.fileoff;
    }
    const last_sect = seg.sections.items[seg.sections.items.len - 1];
    const final_off = last_sect.offset + padToIdeal(last_sect.size);
    return mem.alignForwardGeneric(u64, final_off, alignment);
}

fn growSegment(self: *MachO, seg_id: u16, new_size: u64) !void {
    const seg = &self.load_commands.items[seg_id].Segment;
    const new_seg_size = mem.alignForwardGeneric(u64, new_size, self.page_size);
    assert(new_seg_size > seg.inner.filesize);
    const offset_amt = new_seg_size - seg.inner.filesize;
    log.debug("growing segment {s} from 0x{x} to 0x{x}", .{ seg.inner.segname, seg.inner.filesize, new_seg_size });
    seg.inner.filesize = new_seg_size;
    seg.inner.vmsize = new_seg_size;

    log.debug("  (new segment file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
        seg.inner.fileoff,
        seg.inner.fileoff + seg.inner.filesize,
        seg.inner.vmaddr,
        seg.inner.vmaddr + seg.inner.vmsize,
    });

    // TODO We should probably nop the expanded by distance, or put 0s.

    // TODO copyRangeAll doesn't automatically extend the file on macOS.
    const ledit_seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const new_filesize = offset_amt + ledit_seg.inner.fileoff + ledit_seg.inner.filesize;
    try self.base.file.?.pwriteAll(&[_]u8{0}, new_filesize - 1);

    var next: usize = seg_id + 1;
    while (next < self.linkedit_segment_cmd_index.? + 1) : (next += 1) {
        const next_seg = &self.load_commands.items[next].Segment;
        _ = try self.base.file.?.copyRangeAll(
            next_seg.inner.fileoff,
            self.base.file.?,
            next_seg.inner.fileoff + offset_amt,
            next_seg.inner.filesize,
        );
        next_seg.inner.fileoff += offset_amt;
        next_seg.inner.vmaddr += offset_amt;

        log.debug("  (new {s} segment file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
            next_seg.inner.segname,
            next_seg.inner.fileoff,
            next_seg.inner.fileoff + next_seg.inner.filesize,
            next_seg.inner.vmaddr,
            next_seg.inner.vmaddr + next_seg.inner.vmsize,
        });

        for (next_seg.sections.items) |*moved_sect, moved_sect_id| {
            moved_sect.offset += @intCast(u32, offset_amt);
            moved_sect.addr += offset_amt;

            log.debug("  (new {s},{s} file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
                commands.segmentName(moved_sect.*),
                commands.sectionName(moved_sect.*),
                moved_sect.offset,
                moved_sect.offset + moved_sect.size,
                moved_sect.addr,
                moved_sect.addr + moved_sect.size,
            });

            try self.allocateLocalSymbols(.{
                .seg = @intCast(u16, next),
                .sect = @intCast(u16, moved_sect_id),
            }, @intCast(i64, offset_amt));
        }
    }
}

fn growSection(self: *MachO, match: MatchingSection, new_size: u32) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[match.seg].Segment;
    const sect = &seg.sections.items[match.sect];

    const alignment = try math.powi(u32, 2, sect.@"align");
    const max_size = self.allocatedSize(match.seg, sect.offset);
    const ideal_size = padToIdeal(new_size);
    const needed_size = mem.alignForwardGeneric(u32, ideal_size, alignment);

    if (needed_size > max_size) blk: {
        log.debug("  (need to grow! needed 0x{x}, max 0x{x})", .{ needed_size, max_size });

        if (match.sect == seg.sections.items.len - 1) {
            // Last section, just grow segments
            try self.growSegment(match.seg, seg.inner.filesize + needed_size - max_size);
            break :blk;
        }

        // Need to move all sections below in file and address spaces.
        const offset_amt = offset: {
            const max_alignment = try self.getSectionMaxAlignment(match.seg, match.sect + 1);
            break :offset mem.alignForwardGeneric(u64, needed_size - max_size, max_alignment);
        };

        // Before we commit to this, check if the segment needs to grow too.
        // We assume that each section header is growing linearly with the increasing
        // file offset / virtual memory address space.
        const last_sect = seg.sections.items[seg.sections.items.len - 1];
        const last_sect_off = last_sect.offset + last_sect.size;
        const seg_off = seg.inner.fileoff + seg.inner.filesize;

        if (last_sect_off + offset_amt > seg_off) {
            // Need to grow segment first.
            const spill_size = (last_sect_off + offset_amt) - seg_off;
            try self.growSegment(match.seg, seg.inner.filesize + spill_size);
        }

        // We have enough space to expand within the segment, so move all sections by
        // the required amount and update their header offsets.
        const next_sect = seg.sections.items[match.sect + 1];
        const total_size = last_sect_off - next_sect.offset;
        _ = try self.base.file.?.copyRangeAll(
            next_sect.offset,
            self.base.file.?,
            next_sect.offset + offset_amt,
            total_size,
        );

        var next = match.sect + 1;
        while (next < seg.sections.items.len) : (next += 1) {
            const moved_sect = &seg.sections.items[next];
            moved_sect.offset += @intCast(u32, offset_amt);
            moved_sect.addr += offset_amt;

            log.debug("  (new {s},{s} file offsets from 0x{x} to 0x{x} (in memory 0x{x} to 0x{x}))", .{
                commands.segmentName(moved_sect.*),
                commands.sectionName(moved_sect.*),
                moved_sect.offset,
                moved_sect.offset + moved_sect.size,
                moved_sect.addr,
                moved_sect.addr + moved_sect.size,
            });

            try self.allocateLocalSymbols(.{
                .seg = match.seg,
                .sect = next,
            }, @intCast(i64, offset_amt));
        }
    }
}

fn allocatedSize(self: MachO, segment_id: u16, start: u64) u64 {
    const seg = self.load_commands.items[segment_id].Segment;
    assert(start >= seg.inner.fileoff);
    var min_pos: u64 = seg.inner.fileoff + seg.inner.filesize;
    if (start > min_pos) return 0;
    for (seg.sections.items) |section| {
        if (section.offset <= start) continue;
        if (section.offset < min_pos) min_pos = section.offset;
    }
    return min_pos - start;
}

fn getSectionMaxAlignment(self: *MachO, segment_id: u16, start_sect_id: u16) !u32 {
    const seg = self.load_commands.items[segment_id].Segment;
    var max_alignment: u32 = 1;
    var next = start_sect_id;
    while (next < seg.sections.items.len) : (next += 1) {
        const sect = seg.sections.items[next];
        const alignment = try math.powi(u32, 2, sect.@"align");
        max_alignment = math.max(max_alignment, alignment);
    }
    return max_alignment;
}

fn allocateAtom(self: *MachO, atom: *Atom, new_atom_size: u64, alignment: u64, match: MatchingSection) !u64 {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[match.seg].Segment;
    const sect = &seg.sections.items[match.sect];
    var free_list = self.atom_free_lists.get(match).?;
    const needs_padding = match.seg == self.text_segment_cmd_index.? and match.sect == self.text_section_index.?;
    const new_atom_ideal_capacity = if (needs_padding) padToIdeal(new_atom_size) else new_atom_size;

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
            const sym = self.locals.items[big_atom.local_sym_index];
            const capacity = big_atom.capacity(self.*);
            const ideal_capacity = if (needs_padding) padToIdeal(capacity) else capacity;
            const ideal_capacity_end_vaddr = sym.n_value + ideal_capacity;
            const capacity_end_vaddr = sym.n_value + capacity;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = mem.alignBackwardGeneric(u64, new_start_vaddr_unaligned, alignment);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the atom that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(self.*)) {
                    const bl = free_list.swapRemove(i);
                    bl.deinit(self.base.allocator);
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
        } else if (self.atoms.get(match)) |last| {
            const last_symbol = self.locals.items[last.local_sym_index];
            const ideal_capacity = if (needs_padding) padToIdeal(last.size) else last.size;
            const ideal_capacity_end_vaddr = last_symbol.n_value + ideal_capacity;
            const new_start_vaddr = mem.alignForwardGeneric(u64, ideal_capacity_end_vaddr, alignment);
            atom_placement = last;
            break :blk new_start_vaddr;
        } else {
            break :blk mem.alignForwardGeneric(u64, sect.addr, alignment);
        }
    };

    const expand_section = atom_placement == null or atom_placement.?.next == null;
    if (expand_section) {
        const needed_size = @intCast(u32, (vaddr + new_atom_size) - sect.addr);
        try self.growSection(match, needed_size);
        _ = try self.atoms.put(self.base.allocator, match, atom);
        sect.size = needed_size;
        self.load_commands_dirty = true;
    }
    const align_pow = @intCast(u32, math.log2(alignment));
    if (sect.@"align" < align_pow) {
        sect.@"align" = align_pow;
        self.load_commands_dirty = true;
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

pub fn addExternFn(self: *MachO, name: []const u8) !u32 {
    const sym_name = try std.fmt.allocPrint(self.base.allocator, "_{s}", .{name});
    defer self.base.allocator.free(sym_name);
    const n_strx = try self.makeString(sym_name);

    if (!self.symbol_resolver.contains(n_strx)) {
        log.debug("adding new extern function '{s}'", .{sym_name});
        const sym_index = @intCast(u32, self.undefs.items.len);
        try self.undefs.append(self.base.allocator, .{
            .n_strx = n_strx,
            .n_type = macho.N_UNDF,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        });
        try self.symbol_resolver.putNoClobber(self.base.allocator, n_strx, .{
            .where = .undef,
            .where_index = sym_index,
        });
        try self.unresolved.putNoClobber(self.base.allocator, sym_index, .stub);
    }

    return n_strx;
}

const NextSegmentAddressAndOffset = struct {
    address: u64,
    offset: u64,
};

fn nextSegmentAddressAndOffset(self: *MachO) NextSegmentAddressAndOffset {
    var prev_segment_idx: ?usize = null; // We use optional here for safety.
    for (self.load_commands.items) |cmd, i| {
        if (cmd == .Segment) {
            prev_segment_idx = i;
        }
    }
    const prev_segment = self.load_commands.items[prev_segment_idx.?].Segment;
    const address = prev_segment.inner.vmaddr + prev_segment.inner.vmsize;
    const offset = prev_segment.inner.fileoff + prev_segment.inner.filesize;
    return .{
        .address = address,
        .offset = offset,
    };
}

fn updateSectionOrdinals(self: *MachO) !void {
    if (!self.sections_order_dirty) return;

    const tracy = trace(@src());
    defer tracy.end();

    var ordinal_remap = std.AutoHashMap(u8, u8).init(self.base.allocator);
    defer ordinal_remap.deinit();
    var ordinals: std.AutoArrayHashMapUnmanaged(MatchingSection, void) = .{};

    var new_ordinal: u8 = 0;
    for (self.load_commands.items) |lc, lc_id| {
        if (lc != .Segment) break;

        for (lc.Segment.sections.items) |_, sect_id| {
            const match = MatchingSection{
                .seg = @intCast(u16, lc_id),
                .sect = @intCast(u16, sect_id),
            };
            const old_ordinal = @intCast(u8, self.section_ordinals.getIndex(match).? + 1);
            new_ordinal += 1;
            try ordinal_remap.putNoClobber(old_ordinal, new_ordinal);
            try ordinals.putNoClobber(self.base.allocator, match, {});
        }
    }

    for (self.locals.items) |*sym| {
        if (sym.n_sect == 0) continue;
        sym.n_sect = ordinal_remap.get(sym.n_sect).?;
    }
    for (self.globals.items) |*sym| {
        sym.n_sect = ordinal_remap.get(sym.n_sect).?;
    }

    self.section_ordinals.deinit(self.base.allocator);
    self.section_ordinals = ordinals;
}

fn writeDyldInfoData(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var rebase_pointers = std.ArrayList(bind.Pointer).init(self.base.allocator);
    defer rebase_pointers.deinit();
    var bind_pointers = std.ArrayList(bind.Pointer).init(self.base.allocator);
    defer bind_pointers.deinit();
    var lazy_bind_pointers = std.ArrayList(bind.Pointer).init(self.base.allocator);
    defer lazy_bind_pointers.deinit();

    {
        var it = self.atoms.iterator();
        while (it.next()) |entry| {
            const match = entry.key_ptr.*;
            var atom: *Atom = entry.value_ptr.*;

            if (match.seg == self.text_segment_cmd_index.?) continue; // __TEXT is non-writable

            const seg = self.load_commands.items[match.seg].Segment;

            while (true) {
                const sym = self.locals.items[atom.local_sym_index];
                const base_offset = sym.n_value - seg.inner.vmaddr;

                for (atom.rebases.items) |offset| {
                    try rebase_pointers.append(.{
                        .offset = base_offset + offset,
                        .segment_id = match.seg,
                    });
                }

                for (atom.bindings.items) |binding| {
                    const resolv = self.symbol_resolver.get(binding.n_strx).?;
                    switch (resolv.where) {
                        .global => {
                            // Turn into a rebase.
                            try rebase_pointers.append(.{
                                .offset = base_offset + binding.offset,
                                .segment_id = match.seg,
                            });
                        },
                        .undef => {
                            const bind_sym = self.undefs.items[resolv.where_index];
                            try bind_pointers.append(.{
                                .offset = binding.offset + base_offset,
                                .segment_id = match.seg,
                                .dylib_ordinal = @divExact(bind_sym.n_desc, macho.N_SYMBOL_RESOLVER),
                                .name = self.getString(bind_sym.n_strx),
                            });
                        },
                    }
                }

                for (atom.lazy_bindings.items) |binding| {
                    const resolv = self.symbol_resolver.get(binding.n_strx).?;
                    switch (resolv.where) {
                        .global => {
                            // Turn into a rebase.
                            try rebase_pointers.append(.{
                                .offset = base_offset + binding.offset,
                                .segment_id = match.seg,
                            });
                        },
                        .undef => {
                            const bind_sym = self.undefs.items[resolv.where_index];
                            try lazy_bind_pointers.append(.{
                                .offset = binding.offset + base_offset,
                                .segment_id = match.seg,
                                .dylib_ordinal = @divExact(bind_sym.n_desc, macho.N_SYMBOL_RESOLVER),
                                .name = self.getString(bind_sym.n_strx),
                            });
                        },
                    }
                }

                if (atom.prev) |prev| {
                    atom = prev;
                } else break;
            }
        }
    }

    var trie: Trie = .{};
    defer trie.deinit(self.base.allocator);

    {
        // TODO handle macho.EXPORT_SYMBOL_FLAGS_REEXPORT and macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER.
        log.debug("generating export trie", .{});
        const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        const base_address = text_segment.inner.vmaddr;

        for (self.globals.items) |sym| {
            if (sym.n_type == 0) continue;
            const sym_name = self.getString(sym.n_strx);
            log.debug("  (putting '{s}' defined at 0x{x})", .{ sym_name, sym.n_value });

            try trie.put(self.base.allocator, .{
                .name = sym_name,
                .vmaddr_offset = sym.n_value - base_address,
                .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
            });
        }

        try trie.finalize(self.base.allocator);
    }

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dyld_info = &self.load_commands.items[self.dyld_info_cmd_index.?].DyldInfoOnly;
    const rebase_size = try bind.rebaseInfoSize(rebase_pointers.items);
    const bind_size = try bind.bindInfoSize(bind_pointers.items);
    const lazy_bind_size = try bind.lazyBindInfoSize(lazy_bind_pointers.items);
    const export_size = trie.size;

    dyld_info.rebase_off = @intCast(u32, seg.inner.fileoff);
    dyld_info.rebase_size = @intCast(u32, mem.alignForwardGeneric(u64, rebase_size, @alignOf(u64)));
    seg.inner.filesize += dyld_info.rebase_size;

    dyld_info.bind_off = dyld_info.rebase_off + dyld_info.rebase_size;
    dyld_info.bind_size = @intCast(u32, mem.alignForwardGeneric(u64, bind_size, @alignOf(u64)));
    seg.inner.filesize += dyld_info.bind_size;

    dyld_info.lazy_bind_off = dyld_info.bind_off + dyld_info.bind_size;
    dyld_info.lazy_bind_size = @intCast(u32, mem.alignForwardGeneric(u64, lazy_bind_size, @alignOf(u64)));
    seg.inner.filesize += dyld_info.lazy_bind_size;

    dyld_info.export_off = dyld_info.lazy_bind_off + dyld_info.lazy_bind_size;
    dyld_info.export_size = @intCast(u32, mem.alignForwardGeneric(u64, export_size, @alignOf(u64)));
    seg.inner.filesize += dyld_info.export_size;

    const needed_size = dyld_info.rebase_size + dyld_info.bind_size + dyld_info.lazy_bind_size + dyld_info.export_size;
    var buffer = try self.base.allocator.alloc(u8, needed_size);
    defer self.base.allocator.free(buffer);
    mem.set(u8, buffer, 0);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try bind.writeRebaseInfo(rebase_pointers.items, writer);
    try stream.seekBy(@intCast(i64, dyld_info.rebase_size) - @intCast(i64, rebase_size));

    try bind.writeBindInfo(bind_pointers.items, writer);
    try stream.seekBy(@intCast(i64, dyld_info.bind_size) - @intCast(i64, bind_size));

    try bind.writeLazyBindInfo(lazy_bind_pointers.items, writer);
    try stream.seekBy(@intCast(i64, dyld_info.lazy_bind_size) - @intCast(i64, lazy_bind_size));

    _ = try trie.write(writer);

    log.debug("writing dyld info from 0x{x} to 0x{x}", .{
        dyld_info.rebase_off,
        dyld_info.rebase_off + needed_size,
    });

    try self.base.file.?.pwriteAll(buffer, dyld_info.rebase_off);
    try self.populateLazyBindOffsetsInStubHelper(
        buffer[dyld_info.rebase_size + dyld_info.bind_size ..][0..dyld_info.lazy_bind_size],
    );
    self.load_commands_dirty = true;
}

fn populateLazyBindOffsetsInStubHelper(self: *MachO, buffer: []const u8) !void {
    const last_atom = self.atoms.get(.{
        .seg = self.text_segment_cmd_index.?,
        .sect = self.stub_helper_section_index.?,
    }) orelse return;
    if (last_atom == self.stub_helper_preamble_atom.?) return;

    var table = std.AutoHashMap(i64, *Atom).init(self.base.allocator);
    defer table.deinit();

    {
        var stub_atom = last_atom;
        var laptr_atom = self.atoms.get(.{
            .seg = self.data_segment_cmd_index.?,
            .sect = self.la_symbol_ptr_section_index.?,
        }).?;
        const base_addr = blk: {
            const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
            break :blk seg.inner.vmaddr;
        };

        while (true) {
            const laptr_off = blk: {
                const sym = self.locals.items[laptr_atom.local_sym_index];
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
    var offsets = std.ArrayList(struct { sym_offset: i64, offset: u32 }).init(self.base.allocator);
    try offsets.append(.{ .sym_offset = undefined, .offset = 0 });
    defer offsets.deinit();
    var valid_block = false;

    while (true) {
        const inst = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
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

    const sect = blk: {
        const seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        break :blk seg.sections.items[self.stub_helper_section_index.?];
    };
    const stub_offset: u4 = switch (self.base.options.target.cpu.arch) {
        .x86_64 => 1,
        .aarch64 => 2 * @sizeOf(u32),
        else => unreachable,
    };
    var buf: [@sizeOf(u32)]u8 = undefined;
    _ = offsets.pop();

    while (offsets.popOrNull()) |bind_offset| {
        const atom = table.get(bind_offset.sym_offset).?;
        const sym = self.locals.items[atom.local_sym_index];
        const file_offset = sect.offset + sym.n_value - sect.addr + stub_offset;
        mem.writeIntLittle(u32, &buf, bind_offset.offset);
        log.debug("writing lazy bind offset in stub helper of 0x{x} for symbol {s} at offset 0x{x}", .{
            bind_offset.offset,
            self.getString(sym.n_strx),
            file_offset,
        });
        try self.base.file.?.pwriteAll(&buf, file_offset);
    }
}

fn writeDices(self: *MachO) !void {
    if (!self.has_dices) return;

    const tracy = trace(@src());
    defer tracy.end();

    var buf = std.ArrayList(u8).init(self.base.allocator);
    defer buf.deinit();

    var atom: *Atom = self.atoms.get(.{
        .seg = self.text_segment_cmd_index orelse return,
        .sect = self.text_section_index orelse return,
    }) orelse return;

    while (atom.prev) |prev| {
        atom = prev;
    }

    const text_seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const text_sect = text_seg.sections.items[self.text_section_index.?];

    while (true) {
        if (atom.dices.items.len > 0) {
            const sym = self.locals.items[atom.local_sym_index];
            const base_off = try math.cast(u32, sym.n_value - text_sect.addr + text_sect.offset);

            try buf.ensureUnusedCapacity(atom.dices.items.len * @sizeOf(macho.data_in_code_entry));
            for (atom.dices.items) |dice| {
                const rebased_dice = macho.data_in_code_entry{
                    .offset = base_off + dice.offset,
                    .length = dice.length,
                    .kind = dice.kind,
                };
                buf.appendSliceAssumeCapacity(mem.asBytes(&rebased_dice));
            }
        }

        if (atom.next) |next| {
            atom = next;
        } else break;
    }

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dice_cmd = &self.load_commands.items[self.data_in_code_cmd_index.?].LinkeditData;
    const needed_size = @intCast(u32, buf.items.len);

    dice_cmd.dataoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dice_cmd.datasize = needed_size;
    seg.inner.filesize += needed_size;

    log.debug("writing data-in-code from 0x{x} to 0x{x}", .{
        dice_cmd.dataoff,
        dice_cmd.dataoff + dice_cmd.datasize,
    });

    try self.base.file.?.pwriteAll(buf.items, dice_cmd.dataoff);
    self.load_commands_dirty = true;
}

fn writeSymbolTable(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    symtab.symoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);

    var locals = std.ArrayList(macho.nlist_64).init(self.base.allocator);
    defer locals.deinit();

    for (self.locals.items) |sym| {
        if (sym.n_strx == 0) continue;
        if (symbolIsTemp(sym, self.getString(sym.n_strx))) continue;
        try locals.append(sym);
    }

    if (self.has_stabs) {
        for (self.objects.items) |object| {
            if (object.debug_info == null) continue;

            // Open scope
            try locals.ensureUnusedCapacity(3);
            locals.appendAssumeCapacity(.{
                .n_strx = try self.makeString(object.tu_comp_dir.?),
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            });
            locals.appendAssumeCapacity(.{
                .n_strx = try self.makeString(object.tu_name.?),
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            });
            locals.appendAssumeCapacity(.{
                .n_strx = try self.makeString(object.name),
                .n_type = macho.N_OSO,
                .n_sect = 0,
                .n_desc = 1,
                .n_value = object.mtime orelse 0,
            });

            for (object.contained_atoms.items) |atom| {
                if (atom.stab) |stab| {
                    const nlists = try stab.asNlists(atom.local_sym_index, self);
                    defer self.base.allocator.free(nlists);
                    try locals.appendSlice(nlists);
                } else {
                    for (atom.contained.items) |sym_at_off| {
                        const stab = sym_at_off.stab orelse continue;
                        const nlists = try stab.asNlists(sym_at_off.local_sym_index, self);
                        defer self.base.allocator.free(nlists);
                        try locals.appendSlice(nlists);
                    }
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
    }

    var undefs = std.ArrayList(macho.nlist_64).init(self.base.allocator);
    defer undefs.deinit();

    for (self.undefs.items) |sym| {
        if (sym.n_strx == 0) continue;
        try undefs.append(sym);
    }

    const nlocals = locals.items.len;
    const nexports = self.globals.items.len;
    const nundefs = undefs.items.len;

    const locals_off = symtab.symoff;
    const locals_size = nlocals * @sizeOf(macho.nlist_64);
    log.debug("writing local symbols from 0x{x} to 0x{x}", .{ locals_off, locals_size + locals_off });
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(locals.items), locals_off);

    const exports_off = locals_off + locals_size;
    const exports_size = nexports * @sizeOf(macho.nlist_64);
    log.debug("writing exported symbols from 0x{x} to 0x{x}", .{ exports_off, exports_size + exports_off });
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.globals.items), exports_off);

    const undefs_off = exports_off + exports_size;
    const undefs_size = nundefs * @sizeOf(macho.nlist_64);
    log.debug("writing undefined symbols from 0x{x} to 0x{x}", .{ undefs_off, undefs_size + undefs_off });
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(undefs.items), undefs_off);

    symtab.nsyms = @intCast(u32, nlocals + nexports + nundefs);
    seg.inner.filesize += locals_size + exports_size + undefs_size;

    // Update dynamic symbol table.
    const dysymtab = &self.load_commands.items[self.dysymtab_cmd_index.?].Dysymtab;
    dysymtab.nlocalsym = @intCast(u32, nlocals);
    dysymtab.iextdefsym = dysymtab.nlocalsym;
    dysymtab.nextdefsym = @intCast(u32, nexports);
    dysymtab.iundefsym = dysymtab.nlocalsym + dysymtab.nextdefsym;
    dysymtab.nundefsym = @intCast(u32, nundefs);

    const text_segment = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stubs = &text_segment.sections.items[self.stubs_section_index.?];
    const data_const_segment = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
    const got = &data_const_segment.sections.items[self.got_section_index.?];
    const data_segment = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const la_symbol_ptr = &data_segment.sections.items[self.la_symbol_ptr_section_index.?];

    const nstubs = @intCast(u32, self.stubs_map.keys().len);
    const ngot_entries = @intCast(u32, self.got_entries_map.keys().len);

    dysymtab.indirectsymoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dysymtab.nindirectsyms = nstubs * 2 + ngot_entries;

    const needed_size = dysymtab.nindirectsyms * @sizeOf(u32);
    seg.inner.filesize += needed_size;

    log.debug("writing indirect symbol table from 0x{x} to 0x{x}", .{
        dysymtab.indirectsymoff,
        dysymtab.indirectsymoff + needed_size,
    });

    var buf = try self.base.allocator.alloc(u8, needed_size);
    defer self.base.allocator.free(buf);

    var stream = std.io.fixedBufferStream(buf);
    var writer = stream.writer();

    stubs.reserved1 = 0;
    for (self.stubs_map.keys()) |key| {
        const resolv = self.symbol_resolver.get(key) orelse continue;
        switch (resolv.where) {
            .global => try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL),
            .undef => try writer.writeIntLittle(u32, dysymtab.iundefsym + resolv.where_index),
        }
    }

    got.reserved1 = nstubs;
    for (self.got_entries_map.keys()) |key| {
        switch (key) {
            .local => try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL),
            .global => |n_strx| {
                const resolv = self.symbol_resolver.get(n_strx) orelse continue;
                switch (resolv.where) {
                    .global => try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL),
                    .undef => try writer.writeIntLittle(u32, dysymtab.iundefsym + resolv.where_index),
                }
            },
        }
    }

    la_symbol_ptr.reserved1 = got.reserved1 + ngot_entries;
    for (self.stubs_map.keys()) |key| {
        const resolv = self.symbol_resolver.get(key) orelse continue;
        switch (resolv.where) {
            .global => try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL),
            .undef => try writer.writeIntLittle(u32, dysymtab.iundefsym + resolv.where_index),
        }
    }

    try self.base.file.?.pwriteAll(buf, dysymtab.indirectsymoff);
    self.load_commands_dirty = true;
}

fn writeStringTable(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    symtab.stroff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    symtab.strsize = @intCast(u32, mem.alignForwardGeneric(u64, self.strtab.items.len, @alignOf(u64)));
    seg.inner.filesize += symtab.strsize;

    log.debug("writing string table from 0x{x} to 0x{x}", .{ symtab.stroff, symtab.stroff + symtab.strsize });

    try self.base.file.?.pwriteAll(self.strtab.items, symtab.stroff);

    if (symtab.strsize > self.strtab.items.len) {
        // This is potentially the last section, so we need to pad it out.
        try self.base.file.?.pwriteAll(&[_]u8{0}, seg.inner.fileoff + seg.inner.filesize - 1);
    }
    self.load_commands_dirty = true;
}

fn writeLinkeditSegment(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    seg.inner.filesize = 0;

    try self.writeDyldInfoData();
    try self.writeDices();
    try self.writeSymbolTable();
    try self.writeStringTable();

    seg.inner.vmsize = mem.alignForwardGeneric(u64, seg.inner.filesize, self.page_size);
}

fn writeCodeSignaturePadding(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const linkedit_segment = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const code_sig_cmd = &self.load_commands.items[self.code_signature_cmd_index.?].LinkeditData;
    const fileoff = linkedit_segment.inner.fileoff + linkedit_segment.inner.filesize;
    const needed_size = CodeSignature.calcCodeSignaturePaddingSize(
        self.base.options.emit.?.sub_path,
        fileoff,
        self.page_size,
    );
    code_sig_cmd.dataoff = @intCast(u32, fileoff);
    code_sig_cmd.datasize = needed_size;

    // Advance size of __LINKEDIT segment
    linkedit_segment.inner.filesize += needed_size;
    if (linkedit_segment.inner.vmsize < linkedit_segment.inner.filesize) {
        linkedit_segment.inner.vmsize = mem.alignForwardGeneric(u64, linkedit_segment.inner.filesize, self.page_size);
    }
    log.debug("writing code signature padding from 0x{x} to 0x{x}", .{ fileoff, fileoff + needed_size });
    // Pad out the space. We need to do this to calculate valid hashes for everything in the file
    // except for code signature data.
    try self.base.file.?.pwriteAll(&[_]u8{0}, fileoff + needed_size - 1);
    self.load_commands_dirty = true;
}

fn writeCodeSignature(self: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const code_sig_cmd = self.load_commands.items[self.code_signature_cmd_index.?].LinkeditData;

    var code_sig: CodeSignature = .{};
    defer code_sig.deinit(self.base.allocator);

    try code_sig.calcAdhocSignature(
        self.base.allocator,
        self.base.file.?,
        self.base.options.emit.?.sub_path,
        text_segment.inner,
        code_sig_cmd,
        self.base.options.output_mode,
        self.page_size,
    );

    var buffer = try self.base.allocator.alloc(u8, code_sig.size());
    defer self.base.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    try code_sig.write(stream.writer());

    log.debug("writing code signature from 0x{x} to 0x{x}", .{ code_sig_cmd.dataoff, code_sig_cmd.dataoff + buffer.len });

    try self.base.file.?.pwriteAll(buffer, code_sig_cmd.dataoff);
}

/// Writes all load commands and section headers.
fn writeLoadCommands(self: *MachO) !void {
    if (!self.load_commands_dirty) return;

    var sizeofcmds: u32 = 0;
    for (self.load_commands.items) |lc| {
        sizeofcmds += lc.cmdsize();
    }

    var buffer = try self.base.allocator.alloc(u8, sizeofcmds);
    defer self.base.allocator.free(buffer);
    var writer = std.io.fixedBufferStream(buffer).writer();
    for (self.load_commands.items) |lc| {
        try lc.write(writer);
    }

    const off = @sizeOf(macho.mach_header_64);

    log.debug("writing {} load commands from 0x{x} to 0x{x}", .{ self.load_commands.items.len, off, off + sizeofcmds });

    try self.base.file.?.pwriteAll(buffer, off);
    self.load_commands_dirty = false;
}

/// Writes Mach-O file header.
fn writeHeader(self: *MachO) !void {
    var header = commands.emptyHeader(.{
        .flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK | macho.MH_PIE | macho.MH_TWOLEVEL,
    });

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

    if (self.tlv_section_index) |_| {
        header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;
    }

    header.ncmds = @intCast(u32, self.load_commands.items.len);
    header.sizeofcmds = 0;

    for (self.load_commands.items) |cmd| {
        header.sizeofcmds += cmd.cmdsize();
    }

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

pub fn makeString(self: *MachO, string: []const u8) !u32 {
    const gop = try self.strtab_dir.getOrPutContextAdapted(self.base.allocator, @as([]const u8, string), StringIndexAdapter{
        .bytes = &self.strtab,
    }, StringIndexContext{
        .bytes = &self.strtab,
    });
    if (gop.found_existing) {
        const off = gop.key_ptr.*;
        log.debug("reusing string '{s}' at offset 0x{x}", .{ string, off });
        return off;
    }

    try self.strtab.ensureUnusedCapacity(self.base.allocator, string.len + 1);
    const new_off = @intCast(u32, self.strtab.items.len);

    log.debug("writing new string '{s}' at offset 0x{x}", .{ string, new_off });

    self.strtab.appendSliceAssumeCapacity(string);
    self.strtab.appendAssumeCapacity(0);

    gop.key_ptr.* = new_off;

    return new_off;
}

pub fn getString(self: *MachO, off: u32) []const u8 {
    assert(off < self.strtab.items.len);
    return mem.spanZ(@ptrCast([*:0]const u8, self.strtab.items.ptr + off));
}

pub fn symbolIsStab(sym: macho.nlist_64) bool {
    return (macho.N_STAB & sym.n_type) != 0;
}

pub fn symbolIsPext(sym: macho.nlist_64) bool {
    return (macho.N_PEXT & sym.n_type) != 0;
}

pub fn symbolIsExt(sym: macho.nlist_64) bool {
    return (macho.N_EXT & sym.n_type) != 0;
}

pub fn symbolIsSect(sym: macho.nlist_64) bool {
    const type_ = macho.N_TYPE & sym.n_type;
    return type_ == macho.N_SECT;
}

pub fn symbolIsUndf(sym: macho.nlist_64) bool {
    const type_ = macho.N_TYPE & sym.n_type;
    return type_ == macho.N_UNDF;
}

pub fn symbolIsIndr(sym: macho.nlist_64) bool {
    const type_ = macho.N_TYPE & sym.n_type;
    return type_ == macho.N_INDR;
}

pub fn symbolIsAbs(sym: macho.nlist_64) bool {
    const type_ = macho.N_TYPE & sym.n_type;
    return type_ == macho.N_ABS;
}

pub fn symbolIsWeakDef(sym: macho.nlist_64) bool {
    return (sym.n_desc & macho.N_WEAK_DEF) != 0;
}

pub fn symbolIsWeakRef(sym: macho.nlist_64) bool {
    return (sym.n_desc & macho.N_WEAK_REF) != 0;
}

pub fn symbolIsTentative(sym: macho.nlist_64) bool {
    if (!symbolIsUndf(sym)) return false;
    return sym.n_value != 0;
}

pub fn symbolIsTemp(sym: macho.nlist_64, sym_name: []const u8) bool {
    if (!symbolIsSect(sym)) return false;
    if (symbolIsExt(sym)) return false;
    return mem.startsWith(u8, sym_name, "l") or mem.startsWith(u8, sym_name, "L");
}

pub fn findFirst(comptime T: type, haystack: []T, start: usize, predicate: anytype) usize {
    if (!@hasDecl(@TypeOf(predicate), "predicate"))
        @compileError("Predicate is required to define fn predicate(@This(), T) bool");

    if (start == haystack.len) return start;

    var i = start;
    while (i < haystack.len) : (i += 1) {
        if (predicate.predicate(haystack[i])) break;
    }
    return i;
}

fn snapshotState(self: *MachO) !void {
    const emit = self.base.options.emit orelse {
        log.debug("no emit directory found; skipping snapshot...", .{});
        return;
    };

    const Snapshot = struct {
        const Node = struct {
            const Tag = enum {
                section_start,
                section_end,
                atom_start,
                atom_end,
                relocation,

                pub fn jsonStringify(
                    tag: Tag,
                    options: std.json.StringifyOptions,
                    out_stream: anytype,
                ) !void {
                    _ = options;
                    switch (tag) {
                        .section_start => try out_stream.writeAll("\"section_start\""),
                        .section_end => try out_stream.writeAll("\"section_end\""),
                        .atom_start => try out_stream.writeAll("\"atom_start\""),
                        .atom_end => try out_stream.writeAll("\"atom_end\""),
                        .relocation => try out_stream.writeAll("\"relocation\""),
                    }
                }
            };
            const Payload = struct {
                name: []const u8 = "",
                aliases: [][]const u8 = &[0][]const u8{},
                is_global: bool = false,
                target: u64 = 0,
            };
            address: u64,
            tag: Tag,
            payload: Payload,
        };
        timestamp: i128,
        nodes: []Node,
    };

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const out_file = try emit.directory.handle.createFile("snapshots.json", .{
        .truncate = self.cold_start,
        .read = true,
    });
    defer out_file.close();

    if (out_file.seekFromEnd(-1)) {
        try out_file.writer().writeByte(',');
    } else |err| switch (err) {
        error.Unseekable => try out_file.writer().writeByte('['),
        else => |e| return e,
    }
    var writer = out_file.writer();

    var snapshot = Snapshot{
        .timestamp = std.time.nanoTimestamp(),
        .nodes = undefined,
    };
    var nodes = std.ArrayList(Snapshot.Node).init(arena);

    for (self.section_ordinals.keys()) |key| {
        const seg = self.load_commands.items[key.seg].Segment;
        const sect = seg.sections.items[key.sect];
        const sect_name = try std.fmt.allocPrint(arena, "{s},{s}", .{
            commands.segmentName(sect),
            commands.sectionName(sect),
        });
        try nodes.append(.{
            .address = sect.addr,
            .tag = .section_start,
            .payload = .{ .name = sect_name },
        });

        var atom: *Atom = self.atoms.get(key) orelse {
            try nodes.append(.{
                .address = sect.addr + sect.size,
                .tag = .section_end,
                .payload = .{},
            });
            continue;
        };

        while (atom.prev) |prev| {
            atom = prev;
        }

        while (true) {
            const atom_sym = self.locals.items[atom.local_sym_index];
            var node = Snapshot.Node{
                .address = atom_sym.n_value,
                .tag = .atom_start,
                .payload = .{
                    .name = self.getString(atom_sym.n_strx),
                    .is_global = self.symbol_resolver.contains(atom_sym.n_strx),
                },
            };

            var aliases = std.ArrayList([]const u8).init(arena);
            for (atom.aliases.items) |loc| {
                try aliases.append(self.getString(self.locals.items[loc].n_strx));
            }
            node.payload.aliases = aliases.toOwnedSlice();
            try nodes.append(node);

            var relocs = try std.ArrayList(Snapshot.Node).initCapacity(arena, atom.relocs.items.len);
            for (atom.relocs.items) |rel| {
                const arch = self.base.options.target.cpu.arch;
                const source_addr = blk: {
                    const sym = self.locals.items[atom.local_sym_index];
                    break :blk sym.n_value + rel.offset;
                };
                const target_addr = blk: {
                    const is_via_got = got: {
                        switch (arch) {
                            .aarch64 => break :got switch (@intToEnum(macho.reloc_type_arm64, rel.@"type")) {
                                .ARM64_RELOC_GOT_LOAD_PAGE21, .ARM64_RELOC_GOT_LOAD_PAGEOFF12 => true,
                                else => false,
                            },
                            .x86_64 => break :got switch (@intToEnum(macho.reloc_type_x86_64, rel.@"type")) {
                                .X86_64_RELOC_GOT, .X86_64_RELOC_GOT_LOAD => true,
                                else => false,
                            },
                            else => unreachable,
                        }
                    };

                    if (is_via_got) {
                        const got_atom = self.got_entries_map.get(rel.target) orelse break :blk 0;
                        break :blk self.locals.items[got_atom.local_sym_index].n_value;
                    }

                    switch (rel.target) {
                        .local => |sym_index| {
                            const sym = self.locals.items[sym_index];
                            const is_tlv = is_tlv: {
                                const source_sym = self.locals.items[atom.local_sym_index];
                                const match = self.section_ordinals.keys()[source_sym.n_sect - 1];
                                const match_seg = self.load_commands.items[match.seg].Segment;
                                const match_sect = match_seg.sections.items[match.sect];
                                break :is_tlv commands.sectionType(match_sect) == macho.S_THREAD_LOCAL_VARIABLES;
                            };
                            if (is_tlv) {
                                const match_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
                                const base_address = inner: {
                                    if (self.tlv_data_section_index) |i| {
                                        break :inner match_seg.sections.items[i].addr;
                                    } else if (self.tlv_bss_section_index) |i| {
                                        break :inner match_seg.sections.items[i].addr;
                                    } else unreachable;
                                };
                                break :blk sym.n_value - base_address;
                            }
                            break :blk sym.n_value;
                        },
                        .global => |n_strx| {
                            const resolv = self.symbol_resolver.get(n_strx).?;
                            switch (resolv.where) {
                                .global => break :blk self.globals.items[resolv.where_index].n_value,
                                .undef => {
                                    break :blk if (self.stubs_map.get(n_strx)) |stub_atom|
                                        self.locals.items[stub_atom.local_sym_index].n_value
                                    else
                                        0;
                                },
                            }
                        },
                    }
                };

                relocs.appendAssumeCapacity(.{
                    .address = source_addr,
                    .tag = .relocation,
                    .payload = .{ .target = target_addr },
                });
            }

            if (atom.contained.items.len == 0) {
                try nodes.appendSlice(relocs.items);
            } else {
                // Need to reverse iteration order of relocs since by default for relocatable sources
                // they come in reverse. For linking, this doesn't matter in any way, however, for
                // arranging the memoryline for displaying it does.
                std.mem.reverse(Snapshot.Node, relocs.items);

                var next_i: usize = 0;
                var last_rel: usize = 0;
                while (next_i < atom.contained.items.len) : (next_i += 1) {
                    const loc = atom.contained.items[next_i];
                    const cont_sym = self.locals.items[loc.local_sym_index];
                    const cont_sym_name = self.getString(cont_sym.n_strx);
                    var contained_node = Snapshot.Node{
                        .address = cont_sym.n_value,
                        .tag = .atom_start,
                        .payload = .{
                            .name = cont_sym_name,
                            .is_global = self.symbol_resolver.contains(cont_sym.n_strx),
                        },
                    };

                    // Accumulate aliases
                    var inner_aliases = std.ArrayList([]const u8).init(arena);
                    while (true) {
                        if (next_i + 1 >= atom.contained.items.len) break;
                        const next_sym = self.locals.items[atom.contained.items[next_i + 1].local_sym_index];
                        if (next_sym.n_value != cont_sym.n_value) break;
                        const next_sym_name = self.getString(next_sym.n_strx);
                        if (self.symbol_resolver.contains(next_sym.n_strx)) {
                            try inner_aliases.append(contained_node.payload.name);
                            contained_node.payload.name = next_sym_name;
                            contained_node.payload.is_global = true;
                        } else try inner_aliases.append(next_sym_name);
                        next_i += 1;
                    }

                    const cont_size = if (next_i + 1 < atom.contained.items.len)
                        self.locals.items[atom.contained.items[next_i + 1].local_sym_index].n_value - cont_sym.n_value
                    else
                        atom_sym.n_value + atom.size - cont_sym.n_value;

                    contained_node.payload.aliases = inner_aliases.toOwnedSlice();
                    try nodes.append(contained_node);

                    for (relocs.items[last_rel..]) |rel| {
                        if (rel.address >= cont_sym.n_value + cont_size) {
                            break;
                        }
                        try nodes.append(rel);
                        last_rel += 1;
                    }

                    try nodes.append(.{
                        .address = cont_sym.n_value + cont_size,
                        .tag = .atom_end,
                        .payload = .{},
                    });
                }
            }

            try nodes.append(.{
                .address = atom_sym.n_value + atom.size,
                .tag = .atom_end,
                .payload = .{},
            });

            if (atom.next) |next| {
                atom = next;
            } else break;
        }

        try nodes.append(.{
            .address = sect.addr + sect.size,
            .tag = .section_end,
            .payload = .{},
        });
    }

    snapshot.nodes = nodes.toOwnedSlice();

    try std.json.stringify(snapshot, .{}, writer);
    try writer.writeByte(']');
}
