pub const Atom = @import("Elf/Atom.zig");

base: link.File,
rpath_table: std.StringArrayHashMapUnmanaged(void),
image_base: u64,
emit_relocs: bool,
z_nodelete: bool,
z_notext: bool,
z_defs: bool,
z_origin: bool,
z_nocopyreloc: bool,
z_now: bool,
z_relro: bool,
/// TODO make this non optional and resolve the default in open()
z_common_page_size: ?u64,
/// TODO make this non optional and resolve the default in open()
z_max_page_size: ?u64,
lib_dirs: []const []const u8,
hash_style: HashStyle,
compress_debug_sections: CompressDebugSections,
symbol_wrap_set: std.StringArrayHashMapUnmanaged(void),
sort_section: ?SortSection,
soname: ?[]const u8,
bind_global_refs_locally: bool,
linker_script: ?[]const u8,
version_script: ?[]const u8,
allow_undefined_version: bool,
enable_new_dtags: ?bool,
print_icf_sections: bool,
print_map: bool,
entry_name: ?[]const u8,

ptr_width: PtrWidth,

/// If this is not null, an object file is created by LLVM and emitted to zcu_object_sub_path.
llvm_object: ?LlvmObject.Ptr = null,

/// A list of all input files.
/// Index of each input file also encodes the priority or precedence of one input file
/// over another.
files: std.MultiArrayList(File.Entry) = .{},
/// Long-lived list of all file descriptors.
/// We store them globally rather than per actual File so that we can re-use
/// one file handle per every object file within an archive.
file_handles: std.ArrayListUnmanaged(File.Handle) = .empty,
zig_object_index: ?File.Index = null,
linker_defined_index: ?File.Index = null,
objects: std.ArrayListUnmanaged(File.Index) = .empty,
shared_objects: std.StringArrayHashMapUnmanaged(File.Index) = .empty,

/// List of all output sections and their associated metadata.
sections: std.MultiArrayList(Section) = .{},
/// File offset into the shdr table.
shdr_table_offset: ?u64 = null,

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
phdrs: ProgramHeaderList = .empty,

/// Special program headers.
phdr_indexes: ProgramHeaderIndexes = .{},
section_indexes: SectionIndexes = .{},

page_size: u32,
default_sym_version: elf.Versym,

/// .shstrtab buffer
shstrtab: std.ArrayListUnmanaged(u8) = .empty,
/// .symtab buffer
symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .empty,
/// .strtab buffer
strtab: std.ArrayListUnmanaged(u8) = .empty,
/// Dynamic symbol table. Only populated and emitted when linking dynamically.
dynsym: DynsymSection = .{},
/// .dynstrtab buffer
dynstrtab: std.ArrayListUnmanaged(u8) = .empty,
/// Version symbol table. Only populated and emitted when linking dynamically.
versym: std.ArrayListUnmanaged(elf.Versym) = .empty,
/// .verneed section
verneed: VerneedSection = .{},
/// .got section
got: GotSection = .{},
/// .rela.dyn section
rela_dyn: std.ArrayListUnmanaged(elf.Elf64_Rela) = .empty,
/// .dynamic section
dynamic: DynamicSection = .{},
/// .hash section
hash: HashSection = .{},
/// .gnu.hash section
gnu_hash: GnuHashSection = .{},
/// .plt section
plt: PltSection = .{},
/// .got.plt section
got_plt: GotPltSection = .{},
/// .plt.got section
plt_got: PltGotSection = .{},
/// .copyrel section
copy_rel: CopyRelSection = .{},
/// .rela.plt section
rela_plt: std.ArrayListUnmanaged(elf.Elf64_Rela) = .empty,
/// SHT_GROUP sections
/// Applies only to a relocatable.
comdat_group_sections: std.ArrayListUnmanaged(ComdatGroupSection) = .empty,

resolver: SymbolResolver = .{},

has_text_reloc: bool = false,
num_ifunc_dynrelocs: usize = 0,

/// List of range extension thunks.
thunks: std.ArrayListUnmanaged(Thunk) = .empty,

/// List of output merge sections with deduped contents.
merge_sections: std.ArrayListUnmanaged(Merge.Section) = .empty,
comment_merge_section_index: ?Merge.Section.Index = null,

first_eflags: ?elf.Word = null,

const SectionIndexes = struct {
    copy_rel: ?u32 = null,
    dynamic: ?u32 = null,
    dynstrtab: ?u32 = null,
    dynsymtab: ?u32 = null,
    eh_frame: ?u32 = null,
    eh_frame_rela: ?u32 = null,
    eh_frame_hdr: ?u32 = null,
    hash: ?u32 = null,
    gnu_hash: ?u32 = null,
    got: ?u32 = null,
    got_plt: ?u32 = null,
    interp: ?u32 = null,
    plt: ?u32 = null,
    plt_got: ?u32 = null,
    rela_dyn: ?u32 = null,
    rela_plt: ?u32 = null,
    versym: ?u32 = null,
    verneed: ?u32 = null,

    shstrtab: ?u32 = null,
    strtab: ?u32 = null,
    symtab: ?u32 = null,
};

const ProgramHeaderList = std.ArrayListUnmanaged(elf.Elf64_Phdr);

const OptionalProgramHeaderIndex = enum(u16) {
    none = std.math.maxInt(u16),
    _,

    fn unwrap(i: OptionalProgramHeaderIndex) ?ProgramHeaderIndex {
        if (i == .none) return null;
        return @enumFromInt(@intFromEnum(i));
    }

    fn int(i: OptionalProgramHeaderIndex) ?u16 {
        if (i == .none) return null;
        return @intFromEnum(i);
    }
};

const ProgramHeaderIndex = enum(u16) {
    _,

    fn toOptional(i: ProgramHeaderIndex) OptionalProgramHeaderIndex {
        const result: OptionalProgramHeaderIndex = @enumFromInt(@intFromEnum(i));
        assert(result != .none);
        return result;
    }

    fn int(i: ProgramHeaderIndex) u16 {
        return @intFromEnum(i);
    }
};

const ProgramHeaderIndexes = struct {
    /// PT_PHDR
    table: OptionalProgramHeaderIndex = .none,
    /// PT_LOAD for PHDR table
    /// We add this special load segment to ensure the EHDR and PHDR table are always
    /// loaded into memory.
    table_load: OptionalProgramHeaderIndex = .none,
    /// PT_INTERP
    interp: OptionalProgramHeaderIndex = .none,
    /// PT_DYNAMIC
    dynamic: OptionalProgramHeaderIndex = .none,
    /// PT_GNU_EH_FRAME
    gnu_eh_frame: OptionalProgramHeaderIndex = .none,
    /// PT_GNU_STACK
    gnu_stack: OptionalProgramHeaderIndex = .none,
    /// PT_TLS
    /// TODO I think ELF permits multiple TLS segments but for now, assume one per file.
    tls: OptionalProgramHeaderIndex = .none,
};

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_atom_size = 64;
pub const min_text_capacity = padToIdeal(minimum_atom_size);

pub const PtrWidth = enum { p32, p64 };
pub const HashStyle = enum { sysv, gnu, both };
pub const CompressDebugSections = enum { none, zlib, zstd };
pub const SortSection = enum { name, alignment };

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Elf {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .elf);

    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;
    const opt_zcu = comp.zcu;
    const output_mode = comp.config.output_mode;
    const link_mode = comp.config.link_mode;
    const optimize_mode = comp.root_mod.optimize_mode;
    const is_native_os = comp.root_mod.resolved_target.is_native_os;
    const ptr_width: PtrWidth = switch (target.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedELFArchitecture,
    };

    // This is the max page size that the target system can run with, aka the ABI page size. Not to
    // be confused with the common page size, which is the page size that's used in practice on most
    // systems.
    const page_size: u32 = switch (target.cpu.arch) {
        .bpfel,
        .bpfeb,
        .sparc64,
        => 0x100000,
        .aarch64,
        .aarch64_be,
        .amdgcn,
        .hexagon,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        .sparc,
        => 0x10000,
        .loongarch32,
        .loongarch64,
        => 0x4000,
        .arc,
        .m68k,
        => 0x2000,
        .msp430,
        => 0x4,
        .avr,
        => 0x1,
        else => 0x1000,
    };

    const is_dyn_lib = output_mode == .Lib and link_mode == .dynamic;
    const default_sym_version: elf.Versym = if (is_dyn_lib or comp.config.rdynamic) .GLOBAL else .LOCAL;

    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    // If using LLVM to generate the object file for the zig compilation unit,
    // we need a place to put the object file so that it can be subsequently
    // handled.
    const zcu_object_sub_path = if (!use_lld and !use_llvm)
        null
    else
        try std.fmt.allocPrint(arena, "{s}.o", .{emit.sub_path});

    var rpath_table: std.StringArrayHashMapUnmanaged(void) = .empty;
    try rpath_table.entries.resize(arena, options.rpath_list.len);
    @memcpy(rpath_table.entries.items(.key), options.rpath_list);
    try rpath_table.reIndex(arena);

    const self = try arena.create(Elf);
    self.* = .{
        .base = .{
            .tag = .elf,
            .comp = comp,
            .emit = emit,
            .zcu_object_sub_path = zcu_object_sub_path,
            .gc_sections = options.gc_sections orelse (optimize_mode != .Debug and output_mode != .Obj),
            .print_gc_sections = options.print_gc_sections,
            .stack_size = options.stack_size orelse 16777216,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse !is_native_os,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
        },
        .rpath_table = rpath_table,
        .ptr_width = ptr_width,
        .page_size = page_size,
        .default_sym_version = default_sym_version,

        .entry_name = switch (options.entry) {
            .disabled => null,
            .default => if (output_mode != .Exe) null else defaultEntrySymbolName(target.cpu.arch),
            .enabled => defaultEntrySymbolName(target.cpu.arch),
            .named => |name| name,
        },

        .image_base = b: {
            if (is_dyn_lib) break :b 0;
            if (output_mode == .Exe and comp.config.pie) break :b 0;
            break :b options.image_base orelse switch (ptr_width) {
                .p32 => 0x10000,
                .p64 => 0x1000000,
            };
        },

        .emit_relocs = options.emit_relocs,
        .z_nodelete = options.z_nodelete,
        .z_notext = options.z_notext,
        .z_defs = options.z_defs,
        .z_origin = options.z_origin,
        .z_nocopyreloc = options.z_nocopyreloc,
        .z_now = options.z_now,
        .z_relro = options.z_relro,
        .z_common_page_size = options.z_common_page_size,
        .z_max_page_size = options.z_max_page_size,
        .lib_dirs = options.lib_dirs,
        .hash_style = options.hash_style,
        .compress_debug_sections = options.compress_debug_sections,
        .symbol_wrap_set = options.symbol_wrap_set,
        .sort_section = options.sort_section,
        .soname = options.soname,
        .bind_global_refs_locally = options.bind_global_refs_locally,
        .linker_script = options.linker_script,
        .version_script = options.version_script,
        .allow_undefined_version = options.allow_undefined_version,
        .enable_new_dtags = options.enable_new_dtags,
        .print_icf_sections = options.print_icf_sections,
        .print_map = options.print_map,
    };
    if (use_llvm and comp.config.have_zcu) {
        self.llvm_object = try LlvmObject.create(arena, comp);
    }
    errdefer self.base.destroy();

    if (use_lld and (use_llvm or !comp.config.have_zcu)) {
        // LLVM emits the object file (if any); LLD links it into the final product.
        return self;
    }

    const is_obj = output_mode == .Obj;
    const is_obj_or_ar = is_obj or (output_mode == .Lib and link_mode == .static);

    // What path should this ELF linker code output to?
    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    const sub_path = if (use_lld) zcu_object_sub_path.? else emit.sub_path;
    self.base.file = try emit.root_dir.handle.createFile(sub_path, .{
        .truncate = true,
        .read = true,
        .mode = link.File.determineMode(use_lld, output_mode, link_mode),
    });

    const gpa = comp.gpa;

    // Append null file at index 0
    try self.files.append(gpa, .null);
    // Append null byte to string tables
    try self.shstrtab.append(gpa, 0);
    try self.strtab.append(gpa, 0);
    // There must always be a null shdr in index 0
    _ = try self.addSection(.{});
    // Append null symbol in output symtab
    try self.symtab.append(gpa, null_sym);

    if (!is_obj_or_ar) {
        try self.dynstrtab.append(gpa, 0);

        // Initialize PT_PHDR program header
        const p_align: u16 = switch (self.ptr_width) {
            .p32 => @alignOf(elf.Elf32_Phdr),
            .p64 => @alignOf(elf.Elf64_Phdr),
        };
        const ehsize: u64 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Ehdr),
            .p64 => @sizeOf(elf.Elf64_Ehdr),
        };
        const phsize: u64 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Phdr),
            .p64 => @sizeOf(elf.Elf64_Phdr),
        };
        const max_nphdrs = comptime getMaxNumberOfPhdrs();
        const reserved: u64 = mem.alignForward(u64, padToIdeal(max_nphdrs * phsize), self.page_size);
        self.phdr_indexes.table = (try self.addPhdr(.{
            .type = elf.PT_PHDR,
            .flags = elf.PF_R,
            .@"align" = p_align,
            .addr = self.image_base + ehsize,
            .offset = ehsize,
            .filesz = reserved,
            .memsz = reserved,
        })).toOptional();
        self.phdr_indexes.table_load = (try self.addPhdr(.{
            .type = elf.PT_LOAD,
            .flags = elf.PF_R,
            .@"align" = self.page_size,
            .addr = self.image_base,
            .offset = 0,
            .filesz = reserved + ehsize,
            .memsz = reserved + ehsize,
        })).toOptional();
    }

    if (opt_zcu) |zcu| {
        if (!use_llvm) {
            const index: File.Index = @intCast(try self.files.addOne(gpa));
            self.files.set(index, .{ .zig_object = .{
                .index = index,
                .basename = try std.fmt.allocPrint(arena, "{s}.o", .{
                    fs.path.stem(zcu.main_mod.root_src_path),
                }),
            } });
            self.zig_object_index = index;
            try self.zigObjectPtr().?.init(self, .{
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
    emit: Path,
    options: link.File.OpenOptions,
) !*Elf {
    // TODO: restore saved linker state, don't truncate the file, and
    // participate in incremental compilation.
    return createEmpty(arena, comp, emit, options);
}

pub fn deinit(self: *Elf) void {
    const gpa = self.base.comp.gpa;

    if (self.llvm_object) |llvm_object| llvm_object.deinit();

    for (self.file_handles.items) |fh| {
        fh.close();
    }
    self.file_handles.deinit(gpa);

    for (self.files.items(.tags), self.files.items(.data)) |tag, *data| switch (tag) {
        .null => {},
        .zig_object => data.zig_object.deinit(gpa),
        .linker_defined => data.linker_defined.deinit(gpa),
        .object => data.object.deinit(gpa),
        .shared_object => data.shared_object.deinit(gpa),
    };
    self.files.deinit(gpa);
    self.objects.deinit(gpa);
    self.shared_objects.deinit(gpa);

    for (self.sections.items(.atom_list_2), self.sections.items(.atom_list), self.sections.items(.free_list)) |*atom_list, *atoms, *free_list| {
        atom_list.deinit(gpa);
        atoms.deinit(gpa);
        free_list.deinit(gpa);
    }
    self.sections.deinit(gpa);
    self.phdrs.deinit(gpa);
    self.shstrtab.deinit(gpa);
    self.symtab.deinit(gpa);
    self.strtab.deinit(gpa);
    self.resolver.deinit(gpa);

    for (self.thunks.items) |*th| {
        th.deinit(gpa);
    }
    self.thunks.deinit(gpa);
    for (self.merge_sections.items) |*sect| {
        sect.deinit(gpa);
    }
    self.merge_sections.deinit(gpa);

    self.got.deinit(gpa);
    self.plt.deinit(gpa);
    self.plt_got.deinit(gpa);
    self.dynsym.deinit(gpa);
    self.dynstrtab.deinit(gpa);
    self.dynamic.deinit(gpa);
    self.hash.deinit(gpa);
    self.versym.deinit(gpa);
    self.verneed.deinit(gpa);
    self.copy_rel.deinit(gpa);
    self.rela_dyn.deinit(gpa);
    self.rela_plt.deinit(gpa);
    self.comdat_group_sections.deinit(gpa);
}

pub fn getNavVAddr(self: *Elf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    return self.zigObjectPtr().?.getNavVAddr(self, pt, nav_index, reloc_info);
}

pub fn lowerUav(
    self: *Elf,
    pt: Zcu.PerThread,
    uav: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.GenResult {
    return self.zigObjectPtr().?.lowerUav(self, pt, uav, explicit_alignment, src_loc);
}

pub fn getUavVAddr(self: *Elf, uav: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    return self.zigObjectPtr().?.getUavVAddr(self, uav, reloc_info);
}

/// Returns end pos of collision, if any.
fn detectAllocCollision(self: *Elf, start: u64, size: u64) !?u64 {
    const small_ptr = self.ptr_width == .p32;
    const ehdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Ehdr) else @sizeOf(elf.Elf64_Ehdr);
    if (start < ehdr_size)
        return ehdr_size;

    var at_end = true;
    const end = start + padToIdeal(size);

    if (self.shdr_table_offset) |off| {
        const shdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Shdr) else @sizeOf(elf.Elf64_Shdr);
        const tight_size = self.sections.items(.shdr).len * shdr_size;
        const increased_size = padToIdeal(tight_size);
        const test_end = off +| increased_size;
        if (start < test_end) {
            if (end > off) return test_end;
            if (test_end < std.math.maxInt(u64)) at_end = false;
        }
    }

    for (self.sections.items(.shdr)) |shdr| {
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        const increased_size = padToIdeal(shdr.sh_size);
        const test_end = shdr.sh_offset +| increased_size;
        if (start < test_end) {
            if (end > shdr.sh_offset) return test_end;
            if (test_end < std.math.maxInt(u64)) at_end = false;
        }
    }

    for (self.phdrs.items) |phdr| {
        if (phdr.p_type != elf.PT_LOAD) continue;
        const increased_size = padToIdeal(phdr.p_filesz);
        const test_end = phdr.p_offset +| increased_size;
        if (start < test_end) {
            if (end > phdr.p_offset) return test_end;
            if (test_end < std.math.maxInt(u64)) at_end = false;
        }
    }

    if (at_end) try self.base.file.?.setEndPos(end);
    return null;
}

pub fn allocatedSize(self: *Elf, start: u64) u64 {
    if (start == 0) return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    if (self.shdr_table_offset) |off| {
        if (off > start and off < min_pos) min_pos = off;
    }
    for (self.sections.items(.shdr)) |section| {
        if (section.sh_offset <= start) continue;
        if (section.sh_offset < min_pos) min_pos = section.sh_offset;
    }
    for (self.phdrs.items) |phdr| {
        if (phdr.p_offset <= start) continue;
        if (phdr.p_offset < min_pos) min_pos = phdr.p_offset;
    }
    return min_pos - start;
}

pub fn findFreeSpace(self: *Elf, object_size: u64, min_alignment: u64) !u64 {
    var start: u64 = 0;
    while (try self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForward(u64, item_end, min_alignment);
    }
    return start;
}

pub fn growSection(self: *Elf, shdr_index: u32, needed_size: u64, min_alignment: u64) !void {
    const shdr = &self.sections.items(.shdr)[shdr_index];

    if (shdr.sh_type != elf.SHT_NOBITS) {
        const allocated_size = self.allocatedSize(shdr.sh_offset);
        log.debug("allocated size {x} of '{s}', needed size {x}", .{
            allocated_size,
            self.getShString(shdr.sh_name),
            needed_size,
        });

        if (needed_size > allocated_size) {
            const existing_size = shdr.sh_size;
            shdr.sh_size = 0;
            // Must move the entire section.
            const new_offset = try self.findFreeSpace(needed_size, min_alignment);

            log.debug("moving '{s}' from 0x{x} to 0x{x}", .{
                self.getShString(shdr.sh_name),
                shdr.sh_offset,
                new_offset,
            });

            const amt = try self.base.file.?.copyRangeAll(
                shdr.sh_offset,
                self.base.file.?,
                new_offset,
                existing_size,
            );
            // TODO figure out what to about this error condition - how to communicate it up.
            if (amt != existing_size) return error.InputOutput;

            shdr.sh_offset = new_offset;
        } else if (shdr.sh_offset + allocated_size == std.math.maxInt(u64)) {
            try self.base.file.?.setEndPos(shdr.sh_offset + needed_size);
        }
    }

    shdr.sh_size = needed_size;
    self.markDirty(shdr_index);
}

fn markDirty(self: *Elf, shdr_index: u32) void {
    if (self.zigObjectPtr()) |zo| {
        for ([_]?Symbol.Index{
            zo.debug_info_index,
            zo.debug_abbrev_index,
            zo.debug_aranges_index,
            zo.debug_str_index,
            zo.debug_line_index,
            zo.debug_line_str_index,
            zo.debug_loclists_index,
            zo.debug_rnglists_index,
        }, [_]*bool{
            &zo.debug_info_section_dirty,
            &zo.debug_abbrev_section_dirty,
            &zo.debug_aranges_section_dirty,
            &zo.debug_str_section_dirty,
            &zo.debug_line_section_dirty,
            &zo.debug_line_str_section_dirty,
            &zo.debug_loclists_section_dirty,
            &zo.debug_rnglists_section_dirty,
        }) |maybe_sym_index, dirty| {
            const sym_index = maybe_sym_index orelse continue;
            if (zo.symbol(sym_index).atom(self).?.output_section_index == shdr_index) {
                dirty.* = true;
                break;
            }
        }
    }
}

const AllocateChunkResult = struct {
    value: u64,
    placement: Ref,
};

pub fn allocateChunk(self: *Elf, args: struct {
    size: u64,
    shndx: u32,
    alignment: Atom.Alignment,
    requires_padding: bool = true,
}) !AllocateChunkResult {
    const slice = self.sections.slice();
    const shdr = &slice.items(.shdr)[args.shndx];
    const free_list = &slice.items(.free_list)[args.shndx];
    const last_atom_ref = &slice.items(.last_atom)[args.shndx];
    const new_atom_ideal_capacity = if (args.requires_padding) padToIdeal(args.size) else args.size;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    const res: AllocateChunkResult = blk: {
        var i: usize = if (self.base.child_pid == null) 0 else free_list.items.len;
        while (i < free_list.items.len) {
            const big_atom_ref = free_list.items[i];
            const big_atom = self.atom(big_atom_ref).?;
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const cap = big_atom.capacity(self);
            const ideal_capacity = if (args.requires_padding) padToIdeal(cap) else cap;
            const ideal_capacity_end_vaddr = std.math.add(u64, @intCast(big_atom.value), ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = @as(u64, @intCast(big_atom.value)) + cap;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = args.alignment.backward(new_start_vaddr_unaligned);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the block that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(self)) {
                    _ = free_list.swapRemove(i);
                } else {
                    i += 1;
                }
                continue;
            }
            // At this point we know that we will place the new block here. But the
            // remaining question is whether there is still yet enough capacity left
            // over for there to still be a free list node.
            const remaining_capacity = new_start_vaddr - ideal_capacity_end_vaddr;
            const keep_free_list_node = remaining_capacity >= min_text_capacity;

            if (!keep_free_list_node) {
                _ = free_list.swapRemove(i);
            }
            break :blk .{ .value = new_start_vaddr, .placement = big_atom_ref };
        } else if (self.atom(last_atom_ref.*)) |last_atom| {
            const ideal_capacity = if (args.requires_padding) padToIdeal(last_atom.size) else last_atom.size;
            const ideal_capacity_end_vaddr = @as(u64, @intCast(last_atom.value)) + ideal_capacity;
            const new_start_vaddr = args.alignment.forward(ideal_capacity_end_vaddr);
            break :blk .{ .value = new_start_vaddr, .placement = last_atom.ref() };
        } else {
            break :blk .{ .value = 0, .placement = .{} };
        }
    };

    const expand_section = if (self.atom(res.placement)) |placement_atom|
        placement_atom.nextAtom(self) == null
    else
        true;
    if (expand_section) {
        const needed_size = res.value + args.size;
        try self.growSection(args.shndx, needed_size, args.alignment.toByteUnits().?);
    }

    log.debug("allocated chunk (size({x}),align({x})) in {s} at 0x{x} (file(0x{x}))", .{
        args.size,
        args.alignment.toByteUnits().?,
        self.getShString(shdr.sh_name),
        shdr.sh_addr + res.value,
        shdr.sh_offset + res.value,
    });
    log.debug("  placement {}, {s}", .{
        res.placement,
        if (self.atom(res.placement)) |atom_ptr| atom_ptr.name(self) else "",
    });

    return res;
}

pub fn flush(self: *Elf, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    const use_lld = build_options.have_llvm and self.base.comp.config.use_lld;
    if (use_lld) {
        return self.linkWithLLD(arena, tid, prog_node);
    }
    try self.flushModule(arena, tid, prog_node);
}

pub fn flushModule(self: *Elf, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;

    if (self.llvm_object) |llvm_object| {
        try self.base.emitLlvmObject(arena, llvm_object, prog_node);
        const use_lld = build_options.have_llvm and comp.config.use_lld;
        if (use_lld) return;
    }

    const sub_prog_node = prog_node.start("ELF Flush", 0);
    defer sub_prog_node.end();

    const target = self.getTarget();
    const link_mode = comp.config.link_mode;
    const directory = self.base.emit.root_dir; // Just an alias to make it shorter to type.
    const module_obj_path: ?Path = if (self.base.zcu_object_sub_path) |path| .{
        .root_dir = directory,
        .sub_path = if (fs.path.dirname(self.base.emit.sub_path)) |dirname|
            try fs.path.join(arena, &.{ dirname, path })
        else
            path,
    } else null;

    // --verbose-link
    if (comp.verbose_link) try self.dumpArgv(comp);

    if (self.zigObjectPtr()) |zig_object| try zig_object.flush(self, tid);
    if (self.base.isStaticLib()) return relocatable.flushStaticLib(self, comp, module_obj_path);
    if (self.base.isObject()) return relocatable.flushObject(self, comp, module_obj_path);

    const csu = try comp.getCrtPaths(arena);

    // csu prelude
    if (csu.crt0) |path| parseObjectReportingFailure(self, path);
    if (csu.crti) |path| parseObjectReportingFailure(self, path);
    if (csu.crtbegin) |path| parseObjectReportingFailure(self, path);

    for (comp.objects) |obj| {
        parseInputReportingFailure(self, obj.path, obj.needed, obj.must_link);
    }

    // This is a set of object files emitted by clang in a single `build-exe` invocation.
    // For instance, the implicit `a.o` as compiled by `zig build-exe a.c` will end up
    // in this set.
    for (comp.c_object_table.keys()) |key| {
        parseObjectReportingFailure(self, key.status.success.object_path);
    }

    if (module_obj_path) |path| parseObjectReportingFailure(self, path);

    if (comp.config.any_sanitize_thread) parseCrtFileReportingFailure(self, comp.tsan_lib.?);
    if (comp.config.any_fuzz) parseCrtFileReportingFailure(self, comp.fuzzer_lib.?);

    // libc
    if (!comp.skip_linker_dependencies and !comp.config.link_libc) {
        if (comp.libc_static_lib) |lib| parseCrtFileReportingFailure(self, lib);
    }

    for (comp.system_libs.values()) |lib_info| {
        parseInputReportingFailure(self, lib_info.path.?, lib_info.needed, false);
    }

    // libc++ dep
    if (comp.config.link_libcpp) {
        parseInputReportingFailure(self, comp.libcxxabi_static_lib.?.full_object_path, false, false);
        parseInputReportingFailure(self, comp.libcxx_static_lib.?.full_object_path, false, false);
    }

    // libunwind dep
    if (comp.config.link_libunwind) {
        parseInputReportingFailure(self, comp.libunwind_static_lib.?.full_object_path, false, false);
    }

    // libc dep
    diags.flags.missing_libc = false;
    if (comp.config.link_libc) {
        if (comp.libc_installation) |lc| {
            const flags = target_util.libcFullLinkFlags(target);

            var test_path = std.ArrayList(u8).init(arena);
            var checked_paths = std.ArrayList([]const u8).init(arena);

            for (flags) |flag| {
                checked_paths.clearRetainingCapacity();
                const lib_name = flag["-l".len..];

                success: {
                    if (!self.base.isStatic()) {
                        if (try self.accessLibPath(arena, &test_path, &checked_paths, lc.crt_dir.?, lib_name, .dynamic))
                            break :success;
                    }
                    if (try self.accessLibPath(arena, &test_path, &checked_paths, lc.crt_dir.?, lib_name, .static))
                        break :success;

                    diags.addMissingLibraryError(
                        checked_paths.items,
                        "missing system library: '{s}' was not found",
                        .{lib_name},
                    );
                    continue;
                }

                const resolved_path = Path.initCwd(try arena.dupe(u8, test_path.items));
                parseInputReportingFailure(self, resolved_path, false, false);
            }
        } else if (target.isGnuLibC()) {
            for (glibc.libs) |lib| {
                if (lib.removed_in) |rem_in| {
                    if (target.os.version_range.linux.glibc.order(rem_in) != .lt) continue;
                }

                const lib_path = Path.initCwd(try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                    comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                }));
                parseInputReportingFailure(self, lib_path, false, false);
            }
            parseInputReportingFailure(self, try comp.get_libc_crt_file(arena, "libc_nonshared.a"), false, false);
        } else if (target.isMusl()) {
            const path = try comp.get_libc_crt_file(arena, switch (link_mode) {
                .static => "libc.a",
                .dynamic => "libc.so",
            });
            parseInputReportingFailure(self, path, false, false);
        } else {
            diags.flags.missing_libc = true;
        }
    }

    // Finally, as the last input objects we add compiler_rt and CSU postlude (if any).

    // compiler-rt. Since compiler_rt exports symbols like `memset`, it needs
    // to be after the shared libraries, so they are picked up from the shared
    // libraries, not libcompiler_rt.
    if (comp.compiler_rt_lib) |crt_file| {
        parseInputReportingFailure(self, crt_file.full_object_path, false, false);
    } else if (comp.compiler_rt_obj) |crt_file| {
        parseObjectReportingFailure(self, crt_file.full_object_path);
    }

    // csu postlude
    if (csu.crtend) |path| parseObjectReportingFailure(self, path);
    if (csu.crtn) |path| parseObjectReportingFailure(self, path);

    if (diags.hasErrors()) return error.FlushFailure;

    // If we haven't already, create a linker-generated input file comprising of
    // linker-defined synthetic symbols only such as `_DYNAMIC`, etc.
    if (self.linker_defined_index == null) {
        const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
        self.files.set(index, .{ .linker_defined = .{ .index = index } });
        self.linker_defined_index = index;
        const object = self.linkerDefinedPtr().?;
        try object.init(gpa);
        try object.initSymbols(self);
    }

    // Now, we are ready to resolve the symbols across all input files.
    // We will first resolve the files in the ZigObject, next in the parsed
    // input Object files.
    // Any qualifing unresolved symbol will be upgraded to an absolute, weak
    // symbol for potential resolution at load-time.
    try self.resolveSymbols();
    self.markEhFrameAtomsDead();
    try self.resolveMergeSections();

    for (self.objects.items) |index| {
        try self.file(index).?.object.convertCommonSymbols(self);
    }
    self.markImportsExports();

    if (self.base.gc_sections) {
        try gc.gcAtoms(self);

        if (self.base.print_gc_sections) {
            try gc.dumpPrunedAtoms(self);
        }
    }

    self.checkDuplicates() catch |err| switch (err) {
        error.HasDuplicates => return error.FlushFailure,
        else => |e| return e,
    };

    try self.addCommentString();
    try self.finalizeMergeSections();
    try self.initOutputSections();
    if (self.linkerDefinedPtr()) |obj| {
        try obj.initStartStopSymbols(self);
    }
    self.claimUnresolved();

    // Scan and create missing synthetic entries such as GOT indirection.
    try self.scanRelocs();

    // Generate and emit synthetic sections.
    try self.initSyntheticSections();
    try self.initSpecialPhdrs();
    try sortShdrs(
        gpa,
        &self.section_indexes,
        &self.sections,
        self.shstrtab.items,
        self.merge_sections.items,
        self.comdat_group_sections.items,
        self.zigObjectPtr(),
        self.files,
    );

    try self.setDynamicSection(self.rpath_table.keys());
    self.sortDynamicSymtab();
    try self.setHashSections();
    try self.setVersionSymtab();

    try self.sortInitFini();
    try self.updateMergeSectionSizes();
    try self.updateSectionSizes();

    try self.addLoadPhdrs();
    try self.allocatePhdrTable();
    try self.allocateAllocSections();
    try sortPhdrs(gpa, &self.phdrs, &self.phdr_indexes, self.sections.items(.phndx));
    try self.allocateNonAllocSections();
    self.allocateSpecialPhdrs();
    if (self.linkerDefinedPtr()) |obj| {
        obj.allocateSymbols(self);
    }

    // Dump the state for easy debugging.
    // State can be dumped via `--debug-log link_state`.
    if (build_options.enable_logging) {
        state_log.debug("{}", .{self.dumpState()});
    }

    // Beyond this point, everything has been allocated a virtual address and we can resolve
    // the relocations, and commit objects to file.
    for (self.objects.items) |index| {
        self.file(index).?.object.dirty = false;
    }
    // TODO: would state tracking be more appropriate here? perhaps even custom relocation type?
    self.rela_dyn.clearRetainingCapacity();
    self.rela_plt.clearRetainingCapacity();

    if (self.zigObjectPtr()) |zo| {
        var has_reloc_errors = false;
        for (zo.atoms_indexes.items) |atom_index| {
            const atom_ptr = zo.atom(atom_index) orelse continue;
            if (!atom_ptr.alive) continue;
            const out_shndx = atom_ptr.output_section_index;
            const shdr = &self.sections.items(.shdr)[out_shndx];
            if (shdr.sh_type == elf.SHT_NOBITS) continue;
            const code = try zo.codeAlloc(self, atom_index);
            defer gpa.free(code);
            const file_offset = atom_ptr.offset(self);
            atom_ptr.resolveRelocsAlloc(self, code) catch |err| switch (err) {
                error.RelocFailure, error.RelaxFailure => has_reloc_errors = true,
                error.UnsupportedCpuArch => {
                    try self.reportUnsupportedCpuArch();
                    return error.FlushFailure;
                },
                else => |e| return e,
            };
            try self.base.file.?.pwriteAll(code, file_offset);
        }

        if (has_reloc_errors) return error.FlushFailure;
    }

    try self.writePhdrTable();
    try self.writeShdrTable();
    try self.writeAtoms();
    try self.writeMergeSections();

    self.writeSyntheticSections() catch |err| switch (err) {
        error.RelocFailure => return error.FlushFailure,
        error.UnsupportedCpuArch => {
            try self.reportUnsupportedCpuArch();
            return error.FlushFailure;
        },
        else => |e| return e,
    };

    if (self.base.isExe() and self.linkerDefinedPtr().?.entry_index == null) {
        log.debug("flushing. no_entry_point_found = true", .{});
        diags.flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false", .{});
        diags.flags.no_entry_point_found = false;
        try self.writeElfHeader();
    }

    if (diags.hasErrors()) return error.FlushFailure;
}

/// --verbose-link output
fn dumpArgv(self: *Elf, comp: *Compilation) !void {
    const gpa = self.base.comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = self.getTarget();
    const link_mode = self.base.comp.config.link_mode;
    const directory = self.base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.emit.sub_path});
    const module_obj_path: ?[]const u8 = if (self.base.zcu_object_sub_path) |path| blk: {
        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, path });
        } else {
            break :blk path;
        }
    } else null;

    const csu = try comp.getCrtPaths(arena);
    const compiler_rt_path: ?[]const u8 = blk: {
        if (comp.compiler_rt_lib) |x| break :blk try x.full_object_path.toString(arena);
        if (comp.compiler_rt_obj) |x| break :blk try x.full_object_path.toString(arena);
        break :blk null;
    };

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
            try argv.append(try obj.path.toString(arena));
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }
    } else {
        if (!self.base.isStatic()) {
            if (target.dynamic_linker.get()) |path| {
                try argv.append("-dynamic-linker");
                try argv.append(path);
            }
        }

        if (self.base.isDynLib()) {
            if (self.soname) |name| {
                try argv.append("-soname");
                try argv.append(name);
            }
        }

        if (self.entry_name) |name| {
            try argv.appendSlice(&.{ "--entry", name });
        }

        for (self.rpath_table.keys()) |rpath| {
            try argv.appendSlice(&.{ "-rpath", rpath });
        }

        try argv.appendSlice(&.{
            "-z",
            try std.fmt.allocPrint(arena, "stack-size={d}", .{self.base.stack_size}),
        });

        try argv.append(try std.fmt.allocPrint(arena, "--image-base={d}", .{self.image_base}));

        if (self.base.gc_sections) {
            try argv.append("--gc-sections");
        }

        if (self.base.print_gc_sections) {
            try argv.append("--print-gc-sections");
        }

        if (comp.link_eh_frame_hdr) {
            try argv.append("--eh-frame-hdr");
        }

        if (comp.config.rdynamic) {
            try argv.append("--export-dynamic");
        }

        if (self.z_notext) {
            try argv.append("-z");
            try argv.append("notext");
        }

        if (self.z_nocopyreloc) {
            try argv.append("-z");
            try argv.append("nocopyreloc");
        }

        if (self.z_now) {
            try argv.append("-z");
            try argv.append("now");
        }

        if (self.base.isStatic()) {
            try argv.append("-static");
        } else if (self.isEffectivelyDynLib()) {
            try argv.append("-shared");
        }

        if (comp.config.pie and self.base.isExe()) {
            try argv.append("-pie");
        }

        if (comp.config.debug_format == .strip) {
            try argv.append("-s");
        }

        // csu prelude
        if (csu.crt0) |path| try argv.append(try path.toString(arena));
        if (csu.crti) |path| try argv.append(try path.toString(arena));
        if (csu.crtbegin) |path| try argv.append(try path.toString(arena));

        for (self.lib_dirs) |lib_dir| {
            try argv.append("-L");
            try argv.append(lib_dir);
        }

        if (comp.config.link_libc) {
            if (self.base.comp.libc_installation) |libc_installation| {
                try argv.append("-L");
                try argv.append(libc_installation.crt_dir.?);
            }
        }

        var whole_archive = false;
        for (comp.objects) |obj| {
            if (obj.must_link and !whole_archive) {
                try argv.append("-whole-archive");
                whole_archive = true;
            } else if (!obj.must_link and whole_archive) {
                try argv.append("-no-whole-archive");
                whole_archive = false;
            }

            if (obj.loption) {
                try argv.append("-l");
            }
            try argv.append(try obj.path.toString(arena));
        }
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (comp.config.any_sanitize_thread) {
            try argv.append(try comp.tsan_lib.?.full_object_path.toString(arena));
        }

        if (comp.config.any_fuzz) {
            try argv.append(try comp.fuzzer_lib.?.full_object_path.toString(arena));
        }

        // libc
        if (!comp.skip_linker_dependencies and !comp.config.link_libc) {
            if (comp.libc_static_lib) |lib| {
                try argv.append(try lib.full_object_path.toString(arena));
            }
        }

        // Shared libraries.
        // Worst-case, we need an --as-needed argument for every lib, as well
        // as one before and one after.
        try argv.ensureUnusedCapacity(self.base.comp.system_libs.keys().len * 2 + 2);
        argv.appendAssumeCapacity("--as-needed");
        var as_needed = true;

        for (self.base.comp.system_libs.values()) |lib_info| {
            const lib_as_needed = !lib_info.needed;
            switch ((@as(u2, @intFromBool(lib_as_needed)) << 1) | @intFromBool(as_needed)) {
                0b00, 0b11 => {},
                0b01 => {
                    argv.appendAssumeCapacity("--no-as-needed");
                    as_needed = false;
                },
                0b10 => {
                    argv.appendAssumeCapacity("--as-needed");
                    as_needed = true;
                },
            }
            argv.appendAssumeCapacity(try lib_info.path.?.toString(arena));
        }

        if (!as_needed) {
            argv.appendAssumeCapacity("--as-needed");
            as_needed = true;
        }

        // libc++ dep
        if (comp.config.link_libcpp) {
            try argv.append(try comp.libcxxabi_static_lib.?.full_object_path.toString(arena));
            try argv.append(try comp.libcxx_static_lib.?.full_object_path.toString(arena));
        }

        // libunwind dep
        if (comp.config.link_libunwind) {
            try argv.append(try comp.libunwind_static_lib.?.full_object_path.toString(arena));
        }

        // libc dep
        if (comp.config.link_libc) {
            if (self.base.comp.libc_installation != null) {
                const needs_grouping = link_mode == .static;
                if (needs_grouping) try argv.append("--start-group");
                try argv.appendSlice(target_util.libcFullLinkFlags(target));
                if (needs_grouping) try argv.append("--end-group");
            } else if (target.isGnuLibC()) {
                for (glibc.libs) |lib| {
                    if (lib.removed_in) |rem_in| {
                        if (target.os.version_range.linux.glibc.order(rem_in) != .lt) continue;
                    }

                    const lib_path = try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                        comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                    });
                    try argv.append(lib_path);
                }
                try argv.append(try comp.crtFileAsString(arena, "libc_nonshared.a"));
            } else if (target.isMusl()) {
                try argv.append(try comp.crtFileAsString(arena, switch (link_mode) {
                    .static => "libc.a",
                    .dynamic => "libc.so",
                }));
            }
        }

        // compiler-rt
        if (compiler_rt_path) |p| {
            try argv.append(p);
        }

        // crt postlude
        if (csu.crtend) |path| try argv.append(try path.toString(arena));
        if (csu.crtn) |path| try argv.append(try path.toString(arena));
    }

    Compilation.dump_argv(argv.items);
}

pub const ParseError = error{
    /// Indicates the error is already reported on `Compilation.link_diags`.
    LinkFailure,

    OutOfMemory,
    Overflow,
    InputOutput,
    EndOfStream,
    FileSystem,
    NotSupported,
    InvalidCharacter,
    UnknownFileType,
} || LdScript.Error || fs.Dir.AccessError || fs.File.SeekError || fs.File.OpenError || fs.File.ReadError;

fn parseCrtFileReportingFailure(self: *Elf, crt_file: Compilation.CrtFile) void {
    parseInputReportingFailure(self, crt_file.full_object_path, false, false);
}

pub fn parseInputReportingFailure(self: *Elf, path: Path, needed: bool, must_link: bool) void {
    const gpa = self.base.comp.gpa;
    const diags = &self.base.comp.link_diags;
    const target = self.getTarget();

    switch (Compilation.classifyFileExt(path.sub_path)) {
        .object => parseObjectReportingFailure(self, path),
        .shared_library => parseSharedObject(gpa, diags, .{
            .path = path,
            .needed = needed,
        }, &self.shared_objects, &self.files, target) catch |err| switch (err) {
            error.LinkFailure => return, // already reported
            error.BadMagic, error.UnexpectedEndOfFile => {
                // It could be a linker script.
                self.parseLdScript(.{ .path = path, .needed = needed }) catch |err2| switch (err2) {
                    error.LinkFailure => return, // already reported
                    else => |e| diags.addParseError(path, "failed to parse linker script: {s}", .{@errorName(e)}),
                };
            },
            else => |e| diags.addParseError(path, "failed to parse shared object: {s}", .{@errorName(e)}),
        },
        .static_library => parseArchive(self, path, must_link) catch |err| switch (err) {
            error.LinkFailure => return, // already reported
            else => |e| diags.addParseError(path, "failed to parse archive: {s}", .{@errorName(e)}),
        },
        .unknown => self.parseLdScript(.{ .path = path, .needed = needed }) catch |err| switch (err) {
            error.LinkFailure => return, // already reported
            else => |e| diags.addParseError(path, "failed to parse linker script: {s}", .{@errorName(e)}),
        },
        else => diags.addParseError(path, "unrecognized file type", .{}),
    }
}

pub fn parseObjectReportingFailure(self: *Elf, path: Path) void {
    const diags = &self.base.comp.link_diags;
    self.parseObject(path) catch |err| switch (err) {
        error.LinkFailure => return, // already reported
        else => |e| diags.addParseError(path, "unable to parse object: {s}", .{@errorName(e)}),
    };
}

fn parseObject(self: *Elf, path: Path) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const handle = try path.root_dir.handle.openFile(path.sub_path, .{});
    const fh = try self.addFileHandle(handle);

    const index: File.Index = @intCast(try self.files.addOne(gpa));
    self.files.set(index, .{ .object = .{
        .path = .{
            .root_dir = path.root_dir,
            .sub_path = try gpa.dupe(u8, path.sub_path),
        },
        .file_handle = fh,
        .index = index,
    } });
    try self.objects.append(gpa, index);

    const object = self.file(index).?.object;
    try object.parse(self);
}

fn parseArchive(self: *Elf, path: Path, must_link: bool) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const handle = try path.root_dir.handle.openFile(path.sub_path, .{});
    const fh = try self.addFileHandle(handle);

    var archive: Archive = .{};
    defer archive.deinit(gpa);
    try archive.parse(self, path, fh);

    const objects = try archive.objects.toOwnedSlice(gpa);
    defer gpa.free(objects);

    for (objects) |extracted| {
        const index: File.Index = @intCast(try self.files.addOne(gpa));
        self.files.set(index, .{ .object = extracted });
        const object = &self.files.items(.data)[index].object;
        object.index = index;
        object.alive = must_link;
        try object.parse(self);
        try self.objects.append(gpa, index);
    }
}

fn parseSharedObject(
    gpa: Allocator,
    diags: *Diags,
    lib: SystemLib,
    shared_objects: *std.StringArrayHashMapUnmanaged(File.Index),
    files: *std.MultiArrayList(File.Entry),
    target: std.Target,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const handle = try lib.path.root_dir.handle.openFile(lib.path.sub_path, .{});
    defer handle.close();

    const stat = Stat.fromFs(try handle.stat());
    var header = try SharedObject.parseHeader(gpa, diags, lib.path, handle, stat, target);
    defer header.deinit(gpa);

    const soname = header.soname() orelse lib.path.basename();

    const gop = try shared_objects.getOrPut(gpa, soname);
    if (gop.found_existing) {
        header.deinit(gpa);
        return;
    }
    errdefer _ = shared_objects.pop();

    const index: File.Index = @intCast(try files.addOne(gpa));
    errdefer _ = files.pop();

    gop.value_ptr.* = index;

    var parsed = try SharedObject.parse(gpa, &header, handle);
    errdefer parsed.deinit(gpa);

    const duped_path: Path = .{
        .root_dir = lib.path.root_dir,
        .sub_path = try gpa.dupe(u8, lib.path.sub_path),
    };
    errdefer gpa.free(duped_path.sub_path);

    files.set(index, .{
        .shared_object = .{
            .parsed = parsed,
            .path = duped_path,
            .index = index,
            .needed = lib.needed,
            .alive = lib.needed,
            .aliases = null,
            .symbols = .empty,
            .symbols_extra = .empty,
            .symbols_resolver = .empty,
            .output_symtab_ctx = .{},
        },
    });
    const so = fileLookup(files.*, index).?.shared_object;

    // TODO: save this work for later
    const nsyms = parsed.symbols.len;
    try so.symbols.ensureTotalCapacityPrecise(gpa, nsyms);
    try so.symbols_extra.ensureTotalCapacityPrecise(gpa, nsyms * @typeInfo(Symbol.Extra).@"struct".fields.len);
    try so.symbols_resolver.ensureTotalCapacityPrecise(gpa, nsyms);
    so.symbols_resolver.appendNTimesAssumeCapacity(0, nsyms);

    for (parsed.symtab, parsed.symbols, parsed.versyms, 0..) |esym, sym, versym, i| {
        const out_sym_index = so.addSymbolAssumeCapacity();
        const out_sym = &so.symbols.items[out_sym_index];
        out_sym.value = @intCast(esym.st_value);
        out_sym.name_offset = sym.mangled_name;
        out_sym.ref = .{ .index = 0, .file = 0 };
        out_sym.esym_index = @intCast(i);
        out_sym.version_index = versym;
        out_sym.extra_index = so.addSymbolExtraAssumeCapacity(.{});
    }
}

fn parseLdScript(self: *Elf, lib: SystemLib) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;

    const in_file = try lib.path.root_dir.handle.openFile(lib.path.sub_path, .{});
    defer in_file.close();
    const data = try in_file.readToEndAlloc(gpa, std.math.maxInt(u32));
    defer gpa.free(data);

    var script: LdScript = .{ .path = lib.path };
    defer script.deinit(gpa);
    try script.parse(data, self);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var test_path = std.ArrayList(u8).init(arena);
    var checked_paths = std.ArrayList([]const u8).init(arena);

    for (script.args.items) |script_arg| {
        checked_paths.clearRetainingCapacity();

        success: {
            if (mem.startsWith(u8, script_arg.path, "-l")) {
                const lib_name = script_arg.path["-l".len..];

                // TODO I think technically we should re-use the mechanism used by the frontend here.
                // Maybe we should hoist search-strategy all the way here?
                for (self.lib_dirs) |lib_dir| {
                    if (!self.base.isStatic()) {
                        if (try self.accessLibPath(arena, &test_path, &checked_paths, lib_dir, lib_name, .dynamic))
                            break :success;
                    }
                    if (try self.accessLibPath(arena, &test_path, &checked_paths, lib_dir, lib_name, .static))
                        break :success;
                }
            } else {
                var buffer: [fs.max_path_bytes]u8 = undefined;
                if (fs.realpath(script_arg.path, &buffer)) |path| {
                    test_path.clearRetainingCapacity();
                    try test_path.writer().writeAll(path);
                    break :success;
                } else |_| {}

                try checked_paths.append(try arena.dupe(u8, script_arg.path));
                for (self.lib_dirs) |lib_dir| {
                    if (try self.accessLibPath(arena, &test_path, &checked_paths, lib_dir, script_arg.path, null))
                        break :success;
                }
            }

            diags.addMissingLibraryError(
                checked_paths.items,
                "missing library dependency: GNU ld script '{}' requires '{s}', but file not found",
                .{ @as(Path, lib.path), script_arg.path },
            );
            continue;
        }

        const full_path = Path.initCwd(test_path.items);
        parseInputReportingFailure(self, full_path, script_arg.needed, false);
    }
}

pub fn validateEFlags(self: *Elf, file_index: File.Index, e_flags: elf.Word) !void {
    if (self.first_eflags == null) {
        self.first_eflags = e_flags;
        return; // there isn't anything to conflict with yet
    }
    const self_eflags: *elf.Word = &self.first_eflags.?;

    switch (self.getTarget().cpu.arch) {
        .riscv64 => {
            if (e_flags != self_eflags.*) {
                const riscv_eflags: riscv.RiscvEflags = @bitCast(e_flags);
                const self_riscv_eflags: *riscv.RiscvEflags = @ptrCast(self_eflags);

                self_riscv_eflags.rvc = self_riscv_eflags.rvc or riscv_eflags.rvc;
                self_riscv_eflags.tso = self_riscv_eflags.tso or riscv_eflags.tso;

                var any_errors: bool = false;
                if (self_riscv_eflags.fabi != riscv_eflags.fabi) {
                    any_errors = true;
                    try self.addFileError(
                        file_index,
                        "cannot link object files with different float-point ABIs",
                        .{},
                    );
                }
                if (self_riscv_eflags.rve != riscv_eflags.rve) {
                    any_errors = true;
                    try self.addFileError(
                        file_index,
                        "cannot link object files with different RVEs",
                        .{},
                    );
                }
                if (any_errors) return error.LinkFailure;
            }
        },
        else => {},
    }
}

fn accessLibPath(
    self: *Elf,
    arena: Allocator,
    test_path: *std.ArrayList(u8),
    checked_paths: ?*std.ArrayList([]const u8),
    lib_dir_path: []const u8,
    lib_name: []const u8,
    link_mode: ?std.builtin.LinkMode,
) !bool {
    const sep = fs.path.sep_str;
    const target = self.getTarget();
    test_path.clearRetainingCapacity();
    const prefix = if (link_mode != null) "lib" else "";
    const suffix = if (link_mode) |mode| switch (mode) {
        .static => target.staticLibSuffix(),
        .dynamic => target.dynamicLibSuffix(),
    } else "";
    try test_path.writer().print("{s}" ++ sep ++ "{s}{s}{s}", .{
        lib_dir_path,
        prefix,
        lib_name,
        suffix,
    });
    if (checked_paths) |cpaths| {
        try cpaths.append(try arena.dupe(u8, test_path.items));
    }
    fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |e| return e,
    };
    return true;
}

/// When resolving symbols, we approach the problem similarly to `mold`.
/// 1. Resolve symbols across all objects (including those preemptively extracted archives).
/// 2. Resolve symbols across all shared objects.
/// 3. Mark live objects (see `Elf.markLive`)
/// 4. Reset state of all resolved globals since we will redo this bit on the pruned set.
/// 5. Remove references to dead objects/shared objects
/// 6. Re-run symbol resolution on pruned objects and shared objects sets.
pub fn resolveSymbols(self: *Elf) !void {
    // This function mutates `shared_objects`.
    const shared_objects = &self.shared_objects;

    // Resolve symbols in the ZigObject. For now, we assume that it's always live.
    if (self.zigObjectPtr()) |zo| try zo.asFile().resolveSymbols(self);
    // Resolve symbols on the set of all objects and shared objects (even if some are unneeded).
    for (self.objects.items) |index| try self.file(index).?.resolveSymbols(self);
    for (shared_objects.values()) |index| try self.file(index).?.resolveSymbols(self);
    if (self.linkerDefinedPtr()) |obj| try obj.asFile().resolveSymbols(self);

    // Mark live objects.
    self.markLive();

    // Reset state of all globals after marking live objects.
    self.resolver.reset();

    // Prune dead objects and shared objects.
    var i: usize = 0;
    while (i < self.objects.items.len) {
        const index = self.objects.items[i];
        if (!self.file(index).?.isAlive()) {
            _ = self.objects.orderedRemove(i);
        } else i += 1;
    }
    // TODO This loop has 2 major flaws:
    // 1. It is O(N^2) which is never allowed in the codebase.
    // 2. It mutates shared_objects, which is a non-starter for incremental compilation.
    i = 0;
    while (i < shared_objects.values().len) {
        const index = shared_objects.values()[i];
        if (!self.file(index).?.isAlive()) {
            _ = shared_objects.orderedRemoveAt(i);
        } else i += 1;
    }

    {
        // Dedup comdat groups.
        var table = std.StringHashMap(Ref).init(self.base.comp.gpa);
        defer table.deinit();

        for (self.objects.items) |index| {
            try self.file(index).?.object.resolveComdatGroups(self, &table);
        }

        for (self.objects.items) |index| {
            self.file(index).?.object.markComdatGroupsDead(self);
        }
    }

    // Re-resolve the symbols.
    if (self.zigObjectPtr()) |zo| try zo.asFile().resolveSymbols(self);
    for (self.objects.items) |index| try self.file(index).?.resolveSymbols(self);
    for (shared_objects.values()) |index| try self.file(index).?.resolveSymbols(self);
    if (self.linkerDefinedPtr()) |obj| try obj.asFile().resolveSymbols(self);
}

/// Traverses all objects and shared objects marking any object referenced by
/// a live object/shared object as alive itself.
/// This routine will prune unneeded objects extracted from archives and
/// unneeded shared objects.
fn markLive(self: *Elf) void {
    const shared_objects = self.shared_objects.values();
    if (self.zigObjectPtr()) |zig_object| zig_object.asFile().markLive(self);
    for (self.objects.items) |index| {
        const file_ptr = self.file(index).?;
        if (file_ptr.isAlive()) file_ptr.markLive(self);
    }
    for (shared_objects) |index| {
        const file_ptr = self.file(index).?;
        if (file_ptr.isAlive()) file_ptr.markLive(self);
    }
}

pub fn markEhFrameAtomsDead(self: *Elf) void {
    for (self.objects.items) |index| {
        const file_ptr = self.file(index).?;
        if (!file_ptr.isAlive()) continue;
        file_ptr.object.markEhFrameAtomsDead(self);
    }
}

fn markImportsExports(self: *Elf) void {
    const shared_objects = self.shared_objects.values();
    if (self.zigObjectPtr()) |zo| {
        zo.markImportsExports(self);
    }
    for (self.objects.items) |index| {
        self.file(index).?.object.markImportsExports(self);
    }
    if (!self.isEffectivelyDynLib()) {
        for (shared_objects) |index| {
            self.file(index).?.shared_object.markImportExports(self);
        }
    }
}

fn claimUnresolved(self: *Elf) void {
    if (self.zigObjectPtr()) |zig_object| {
        zig_object.claimUnresolved(self);
    }
    for (self.objects.items) |index| {
        self.file(index).?.object.claimUnresolved(self);
    }
}

/// In scanRelocs we will go over all live atoms and scan their relocs.
/// This will help us work out what synthetics to emit, GOT indirection, etc.
/// This is also the point where we will report undefined symbols for any
/// alloc sections.
fn scanRelocs(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const shared_objects = self.shared_objects.values();

    var undefs = std.AutoArrayHashMap(SymbolResolver.Index, std.ArrayList(Ref)).init(gpa);
    defer {
        for (undefs.values()) |*refs| {
            refs.deinit();
        }
        undefs.deinit();
    }

    var has_reloc_errors = false;
    if (self.zigObjectPtr()) |zo| {
        zo.asFile().scanRelocs(self, &undefs) catch |err| switch (err) {
            error.RelaxFailure => unreachable,
            error.UnsupportedCpuArch => {
                try self.reportUnsupportedCpuArch();
                return error.FlushFailure;
            },
            error.RelocFailure => has_reloc_errors = true,
            else => |e| return e,
        };
    }
    for (self.objects.items) |index| {
        self.file(index).?.scanRelocs(self, &undefs) catch |err| switch (err) {
            error.RelaxFailure => unreachable,
            error.UnsupportedCpuArch => {
                try self.reportUnsupportedCpuArch();
                return error.FlushFailure;
            },
            error.RelocFailure => has_reloc_errors = true,
            else => |e| return e,
        };
    }

    try self.reportUndefinedSymbols(&undefs);

    if (has_reloc_errors) return error.FlushFailure;

    if (self.zigObjectPtr()) |zo| {
        try zo.asFile().createSymbolIndirection(self);
    }
    for (self.objects.items) |index| {
        try self.file(index).?.createSymbolIndirection(self);
    }
    for (shared_objects) |index| {
        try self.file(index).?.createSymbolIndirection(self);
    }
    if (self.linkerDefinedPtr()) |obj| {
        try obj.asFile().createSymbolIndirection(self);
    }
    if (self.got.flags.needs_tlsld) {
        log.debug("program needs TLSLD", .{});
        try self.got.addTlsLdSymbol(self);
    }
}

pub fn initOutputSection(self: *Elf, args: struct {
    name: [:0]const u8,
    flags: u64,
    type: u32,
}) error{OutOfMemory}!u32 {
    const name = blk: {
        if (self.base.isRelocatable()) break :blk args.name;
        if (args.flags & elf.SHF_MERGE != 0) break :blk args.name;
        const name_prefixes: []const [:0]const u8 = &.{
            ".text",       ".data.rel.ro", ".data", ".rodata", ".bss.rel.ro",       ".bss",
            ".init_array", ".fini_array",  ".tbss", ".tdata",  ".gcc_except_table", ".ctors",
            ".dtors",      ".gnu.warning",
        };
        inline for (name_prefixes) |prefix| {
            if (std.mem.eql(u8, args.name, prefix) or std.mem.startsWith(u8, args.name, prefix ++ ".")) {
                break :blk prefix;
            }
        }
        break :blk args.name;
    };
    const @"type" = tt: {
        if (self.getTarget().cpu.arch == .x86_64 and args.type == elf.SHT_X86_64_UNWIND)
            break :tt elf.SHT_PROGBITS;
        switch (args.type) {
            elf.SHT_NULL => unreachable,
            elf.SHT_PROGBITS => {
                if (std.mem.eql(u8, args.name, ".init_array") or std.mem.startsWith(u8, args.name, ".init_array."))
                    break :tt elf.SHT_INIT_ARRAY;
                if (std.mem.eql(u8, args.name, ".fini_array") or std.mem.startsWith(u8, args.name, ".fini_array."))
                    break :tt elf.SHT_FINI_ARRAY;
                break :tt args.type;
            },
            else => break :tt args.type,
        }
    };
    const flags = blk: {
        var flags = args.flags;
        if (!self.base.isRelocatable()) {
            flags &= ~@as(u64, elf.SHF_COMPRESSED | elf.SHF_GROUP | elf.SHF_GNU_RETAIN);
        }
        break :blk switch (@"type") {
            elf.SHT_INIT_ARRAY, elf.SHT_FINI_ARRAY => flags | elf.SHF_WRITE,
            else => flags,
        };
    };
    const out_shndx = self.sectionByName(name) orelse try self.addSection(.{
        .type = @"type",
        .flags = flags,
        .name = try self.insertShString(name),
    });
    return out_shndx;
}

fn linkWithLLD(self: *Elf, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) !void {
    dev.check(.lld_linker);

    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;

    const directory = self.base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.emit.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (comp.zcu != null) blk: {
        try self.flushModule(arena, tid, prog_node);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, self.base.zcu_object_sub_path.? });
        } else {
            break :blk self.base.zcu_object_sub_path.?;
        }
    } else null;

    const sub_prog_node = prog_node.start("LLD Link", 0);
    defer sub_prog_node.end();

    const output_mode = comp.config.output_mode;
    const is_obj = output_mode == .Obj;
    const is_lib = output_mode == .Lib;
    const link_mode = comp.config.link_mode;
    const is_dyn_lib = link_mode == .dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or output_mode == .Exe;
    const have_dynamic_linker = comp.config.link_libc and
        link_mode == .dynamic and is_exe_or_dyn_lib;
    const target = self.getTarget();
    const compiler_rt_path: ?Path = blk: {
        if (comp.compiler_rt_lib) |x| break :blk x.full_object_path;
        if (comp.compiler_rt_obj) |x| break :blk x.full_object_path;
        break :blk null;
    };

    // Here we want to determine whether we can save time by not invoking LLD when the
    // output is unchanged. None of the linker options or the object files that are being
    // linked are in the hash that namespaces the directory we are outputting to. Therefore,
    // we must hash those now, and the resulting digest will form the "id" of the linking
    // job we are about to perform.
    // After a successful link, we store the id in the metadata of a symlink named "lld.id" in
    // the artifact directory. So, now, we check if this symlink exists, and if it matches
    // our digest. If so, we can skip linking. Otherwise, we proceed with invoking LLD.
    const id_symlink_basename = "lld.id";

    var man: std.Build.Cache.Manifest = undefined;
    defer if (!self.base.disable_lld_caching) man.deinit();

    var digest: [std.Build.Cache.hex_digest_len]u8 = undefined;

    if (!self.base.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 14);

        try man.addOptionalFile(self.linker_script);
        try man.addOptionalFile(self.version_script);
        man.hash.add(self.allow_undefined_version);
        man.hash.addOptional(self.enable_new_dtags);
        for (comp.objects) |obj| {
            _ = try man.addFilePath(obj.path, null);
            man.hash.add(obj.must_link);
            man.hash.add(obj.loption);
        }
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFilePath(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        try man.addOptionalFilePath(compiler_rt_path);
        try man.addOptionalFilePath(if (comp.tsan_lib) |l| l.full_object_path else null);
        try man.addOptionalFilePath(if (comp.fuzzer_lib) |l| l.full_object_path else null);

        // We can skip hashing libc and libc++ components that we are in charge of building from Zig
        // installation sources because they are always a product of the compiler version + target information.
        man.hash.addOptionalBytes(self.entry_name);
        man.hash.add(self.image_base);
        man.hash.add(self.base.gc_sections);
        man.hash.addOptional(self.sort_section);
        man.hash.add(comp.link_eh_frame_hdr);
        man.hash.add(self.emit_relocs);
        man.hash.add(comp.config.rdynamic);
        man.hash.addListOfBytes(self.lib_dirs);
        man.hash.addListOfBytes(self.rpath_table.keys());
        if (output_mode == .Exe) {
            man.hash.add(self.base.stack_size);
            man.hash.add(self.base.build_id);
        }
        man.hash.addListOfBytes(self.symbol_wrap_set.keys());
        man.hash.add(comp.skip_linker_dependencies);
        man.hash.add(self.z_nodelete);
        man.hash.add(self.z_notext);
        man.hash.add(self.z_defs);
        man.hash.add(self.z_origin);
        man.hash.add(self.z_nocopyreloc);
        man.hash.add(self.z_now);
        man.hash.add(self.z_relro);
        man.hash.add(self.z_common_page_size orelse 0);
        man.hash.add(self.z_max_page_size orelse 0);
        man.hash.add(self.hash_style);
        // strip does not need to go into the linker hash because it is part of the hash namespace
        if (comp.config.link_libc) {
            man.hash.add(comp.libc_installation != null);
            if (comp.libc_installation) |libc_installation| {
                man.hash.addBytes(libc_installation.crt_dir.?);
            }
            if (have_dynamic_linker) {
                man.hash.addOptionalBytes(target.dynamic_linker.get());
            }
        }
        man.hash.addOptionalBytes(self.soname);
        man.hash.addOptional(comp.version);
        try link.hashAddSystemLibs(&man, comp.system_libs);
        man.hash.addListOfBytes(comp.force_undefined_symbols.keys());
        man.hash.add(self.base.allow_shlib_undefined);
        man.hash.add(self.bind_global_refs_locally);
        man.hash.add(self.compress_debug_sections);
        man.hash.add(comp.config.any_sanitize_thread);
        man.hash.add(comp.config.any_fuzz);
        man.hash.addOptionalBytes(comp.sysroot);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = std.Build.Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("ELF LLD new_digest={s} error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("ELF LLD digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
            // Hot diggity dog! The output binary is already there.
            self.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("ELF LLD prev_digest={s} new_digest={s}", .{ std.fmt.fmtSliceHexLower(prev_digest), std.fmt.fmtSliceHexLower(&digest) });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    // Due to a deficiency in LLD, we need to special-case BPF to a simple file
    // copy when generating relocatables. Normally, we would expect `lld -r` to work.
    // However, because LLD wants to resolve BPF relocations which it shouldn't, it fails
    // before even generating the relocatable.
    if (output_mode == .Obj and
        (comp.config.lto or target.isBpfFreestanding()))
    {
        // In this case we must do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (comp.objects.len != 0)
                break :blk comp.objects[0].path;

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (module_obj_path) |p|
                break :blk Path.initCwd(p);

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        try std.fs.Dir.copyFile(
            the_object_path.root_dir.handle,
            the_object_path.sub_path,
            directory.handle,
            self.base.emit.sub_path,
            .{},
        );
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "ld.lld";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });
        if (is_obj) {
            try argv.append("-r");
        }

        try argv.append("--error-limit=0");

        if (comp.sysroot) |sysroot| {
            try argv.append(try std.fmt.allocPrint(arena, "--sysroot={s}", .{sysroot}));
        }

        if (comp.config.lto) {
            switch (comp.root_mod.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("--lto-O2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("--lto-O3"),
            }
        }
        switch (comp.root_mod.optimize_mode) {
            .Debug => {},
            .ReleaseSmall => try argv.append("-O2"),
            .ReleaseFast, .ReleaseSafe => try argv.append("-O3"),
        }

        if (self.entry_name) |name| {
            try argv.appendSlice(&.{ "--entry", name });
        }

        for (comp.force_undefined_symbols.keys()) |sym| {
            try argv.append("-u");
            try argv.append(sym);
        }

        switch (self.hash_style) {
            .gnu => try argv.append("--hash-style=gnu"),
            .sysv => try argv.append("--hash-style=sysv"),
            .both => {}, // this is the default
        }

        if (output_mode == .Exe) {
            try argv.appendSlice(&.{
                "-z",
                try std.fmt.allocPrint(arena, "stack-size={d}", .{self.base.stack_size}),
            });

            switch (self.base.build_id) {
                .none => {},
                .fast, .uuid, .sha1, .md5 => {
                    try argv.append(try std.fmt.allocPrint(arena, "--build-id={s}", .{
                        @tagName(self.base.build_id),
                    }));
                },
                .hexstring => |hs| {
                    try argv.append(try std.fmt.allocPrint(arena, "--build-id=0x{s}", .{
                        std.fmt.fmtSliceHexLower(hs.toSlice()),
                    }));
                },
            }
        }

        try argv.append(try std.fmt.allocPrint(arena, "--image-base={d}", .{self.image_base}));

        if (self.linker_script) |linker_script| {
            try argv.append("-T");
            try argv.append(linker_script);
        }

        if (self.sort_section) |how| {
            const arg = try std.fmt.allocPrint(arena, "--sort-section={s}", .{@tagName(how)});
            try argv.append(arg);
        }

        if (self.base.gc_sections) {
            try argv.append("--gc-sections");
        }

        if (self.base.print_gc_sections) {
            try argv.append("--print-gc-sections");
        }

        if (self.print_icf_sections) {
            try argv.append("--print-icf-sections");
        }

        if (self.print_map) {
            try argv.append("--print-map");
        }

        if (comp.link_eh_frame_hdr) {
            try argv.append("--eh-frame-hdr");
        }

        if (self.emit_relocs) {
            try argv.append("--emit-relocs");
        }

        if (comp.config.rdynamic) {
            try argv.append("--export-dynamic");
        }

        if (comp.config.debug_format == .strip) {
            try argv.append("-s");
        }

        if (self.z_nodelete) {
            try argv.append("-z");
            try argv.append("nodelete");
        }
        if (self.z_notext) {
            try argv.append("-z");
            try argv.append("notext");
        }
        if (self.z_defs) {
            try argv.append("-z");
            try argv.append("defs");
        }
        if (self.z_origin) {
            try argv.append("-z");
            try argv.append("origin");
        }
        if (self.z_nocopyreloc) {
            try argv.append("-z");
            try argv.append("nocopyreloc");
        }
        if (self.z_now) {
            // LLD defaults to -zlazy
            try argv.append("-znow");
        }
        if (!self.z_relro) {
            // LLD defaults to -zrelro
            try argv.append("-znorelro");
        }
        if (self.z_common_page_size) |size| {
            try argv.append("-z");
            try argv.append(try std.fmt.allocPrint(arena, "common-page-size={d}", .{size}));
        }
        if (self.z_max_page_size) |size| {
            try argv.append("-z");
            try argv.append(try std.fmt.allocPrint(arena, "max-page-size={d}", .{size}));
        }

        if (getLDMOption(target)) |ldm| {
            try argv.append("-m");
            try argv.append(ldm);
        }

        if (link_mode == .static) {
            if (target.cpu.arch.isArmOrThumb()) {
                try argv.append("-Bstatic");
            } else {
                try argv.append("-static");
            }
        } else if (switch (target.os.tag) {
            else => is_dyn_lib,
            .haiku => is_exe_or_dyn_lib,
        }) {
            try argv.append("-shared");
        }

        if (comp.config.pie and output_mode == .Exe) {
            try argv.append("-pie");
        }

        if (is_exe_or_dyn_lib and target.os.tag == .netbsd) {
            // Add options to produce shared objects with only 2 PT_LOAD segments.
            // NetBSD expects 2 PT_LOAD segments in a shared object, otherwise
            // ld.elf_so fails loading dynamic libraries with "not found" error.
            // See https://github.com/ziglang/zig/issues/9109 .
            try argv.append("--no-rosegment");
            try argv.append("-znorelro");
        }

        try argv.append("-o");
        try argv.append(full_out_path);

        // csu prelude
        const csu = try comp.getCrtPaths(arena);
        if (csu.crt0) |p| try argv.append(try p.toString(arena));
        if (csu.crti) |p| try argv.append(try p.toString(arena));
        if (csu.crtbegin) |p| try argv.append(try p.toString(arena));

        for (self.rpath_table.keys()) |rpath| {
            try argv.appendSlice(&.{ "-rpath", rpath });
        }

        for (self.symbol_wrap_set.keys()) |symbol_name| {
            try argv.appendSlice(&.{ "-wrap", symbol_name });
        }

        for (self.lib_dirs) |lib_dir| {
            try argv.append("-L");
            try argv.append(lib_dir);
        }

        if (comp.config.link_libc) {
            if (comp.libc_installation) |libc_installation| {
                try argv.append("-L");
                try argv.append(libc_installation.crt_dir.?);
            }

            if (have_dynamic_linker) {
                if (target.dynamic_linker.get()) |dynamic_linker| {
                    try argv.append("-dynamic-linker");
                    try argv.append(dynamic_linker);
                }
            }
        }

        if (is_dyn_lib) {
            if (self.soname) |soname| {
                try argv.append("-soname");
                try argv.append(soname);
            }
            if (self.version_script) |version_script| {
                try argv.append("-version-script");
                try argv.append(version_script);
            }
            if (self.allow_undefined_version) {
                try argv.append("--undefined-version");
            } else {
                try argv.append("--no-undefined-version");
            }
            if (self.enable_new_dtags) |enable_new_dtags| {
                if (enable_new_dtags) {
                    try argv.append("--enable-new-dtags");
                } else {
                    try argv.append("--disable-new-dtags");
                }
            }
        }

        // Positional arguments to the linker such as object files.
        var whole_archive = false;
        for (comp.objects) |obj| {
            if (obj.must_link and !whole_archive) {
                try argv.append("-whole-archive");
                whole_archive = true;
            } else if (!obj.must_link and whole_archive) {
                try argv.append("-no-whole-archive");
                whole_archive = false;
            }

            if (obj.loption) {
                assert(obj.path.sub_path[0] == ':');
                try argv.append("-l");
            }
            try argv.append(try obj.path.toString(arena));
        }
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (comp.tsan_lib) |lib| {
            assert(comp.config.any_sanitize_thread);
            try argv.append(try lib.full_object_path.toString(arena));
        }

        if (comp.fuzzer_lib) |lib| {
            assert(comp.config.any_fuzz);
            try argv.append(try lib.full_object_path.toString(arena));
        }

        // libc
        if (is_exe_or_dyn_lib and
            !comp.skip_linker_dependencies and
            !comp.config.link_libc)
        {
            if (comp.libc_static_lib) |lib| {
                try argv.append(try lib.full_object_path.toString(arena));
            }
        }

        // Shared libraries.
        if (is_exe_or_dyn_lib) {
            const system_libs = comp.system_libs.keys();
            const system_libs_values = comp.system_libs.values();

            // Worst-case, we need an --as-needed argument for every lib, as well
            // as one before and one after.
            try argv.ensureUnusedCapacity(system_libs.len * 2 + 2);
            argv.appendAssumeCapacity("--as-needed");
            var as_needed = true;

            for (system_libs_values) |lib_info| {
                const lib_as_needed = !lib_info.needed;
                switch ((@as(u2, @intFromBool(lib_as_needed)) << 1) | @intFromBool(as_needed)) {
                    0b00, 0b11 => {},
                    0b01 => {
                        argv.appendAssumeCapacity("--no-as-needed");
                        as_needed = false;
                    },
                    0b10 => {
                        argv.appendAssumeCapacity("--as-needed");
                        as_needed = true;
                    },
                }

                // By this time, we depend on these libs being dynamically linked
                // libraries and not static libraries (the check for that needs to be earlier),
                // but they could be full paths to .so files, in which case we
                // want to avoid prepending "-l".
                argv.appendAssumeCapacity(try lib_info.path.?.toString(arena));
            }

            if (!as_needed) {
                argv.appendAssumeCapacity("--as-needed");
                as_needed = true;
            }

            // libc++ dep
            if (comp.config.link_libcpp) {
                try argv.append(try comp.libcxxabi_static_lib.?.full_object_path.toString(arena));
                try argv.append(try comp.libcxx_static_lib.?.full_object_path.toString(arena));
            }

            // libunwind dep
            if (comp.config.link_libunwind) {
                try argv.append(try comp.libunwind_static_lib.?.full_object_path.toString(arena));
            }

            // libc dep
            diags.flags.missing_libc = false;
            if (comp.config.link_libc) {
                if (comp.libc_installation != null) {
                    const needs_grouping = link_mode == .static;
                    if (needs_grouping) try argv.append("--start-group");
                    try argv.appendSlice(target_util.libcFullLinkFlags(target));
                    if (needs_grouping) try argv.append("--end-group");
                } else if (target.isGnuLibC()) {
                    for (glibc.libs) |lib| {
                        if (lib.removed_in) |rem_in| {
                            if (target.os.version_range.linux.glibc.order(rem_in) != .lt) continue;
                        }

                        const lib_path = try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                            comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                        });
                        try argv.append(lib_path);
                    }
                    try argv.append(try comp.crtFileAsString(arena, "libc_nonshared.a"));
                } else if (target.isMusl()) {
                    try argv.append(try comp.crtFileAsString(arena, switch (link_mode) {
                        .static => "libc.a",
                        .dynamic => "libc.so",
                    }));
                } else {
                    diags.flags.missing_libc = true;
                }
            }
        }

        // compiler-rt. Since compiler_rt exports symbols like `memset`, it needs
        // to be after the shared libraries, so they are picked up from the shared
        // libraries, not libcompiler_rt.
        if (compiler_rt_path) |p| {
            try argv.append(try p.toString(arena));
        }

        // crt postlude
        if (csu.crtend) |p| try argv.append(try p.toString(arena));
        if (csu.crtn) |p| try argv.append(try p.toString(arena));

        if (self.base.allow_shlib_undefined) {
            try argv.append("--allow-shlib-undefined");
        }

        switch (self.compress_debug_sections) {
            .none => {},
            .zlib => try argv.append("--compress-debug-sections=zlib"),
            .zstd => try argv.append("--compress-debug-sections=zstd"),
        }

        if (self.bind_global_refs_locally) {
            try argv.append("-Bsymbolic");
        }

        try link.spawnLld(comp, arena, argv.items);
    }

    if (!self.base.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        std.Build.Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.warn("failed to save linking hash digest file: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        self.base.lock = man.toOwnedLock();
    }
}

pub fn writeShdrTable(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const target_endian = self.getTarget().cpu.arch.endian();
    const foreign_endian = target_endian != builtin.cpu.arch.endian();
    const shsize: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Shdr),
        .p64 => @sizeOf(elf.Elf64_Shdr),
    };
    const shalign: u16 = switch (self.ptr_width) {
        .p32 => @alignOf(elf.Elf32_Shdr),
        .p64 => @alignOf(elf.Elf64_Shdr),
    };

    const shoff = self.shdr_table_offset orelse 0;
    const needed_size = self.sections.items(.shdr).len * shsize;

    if (needed_size > self.allocatedSize(shoff)) {
        self.shdr_table_offset = null;
        self.shdr_table_offset = try self.findFreeSpace(needed_size, shalign);
    }

    log.debug("writing section headers from 0x{x} to 0x{x}", .{
        self.shdr_table_offset.?,
        self.shdr_table_offset.? + needed_size,
    });

    switch (self.ptr_width) {
        .p32 => {
            const buf = try gpa.alloc(elf.Elf32_Shdr, self.sections.items(.shdr).len);
            defer gpa.free(buf);

            for (buf, 0..) |*shdr, i| {
                assert(self.sections.items(.shdr)[i].sh_offset != math.maxInt(u64));
                shdr.* = shdrTo32(self.sections.items(.shdr)[i]);
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf32_Shdr, shdr);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
        },
        .p64 => {
            const buf = try gpa.alloc(elf.Elf64_Shdr, self.sections.items(.shdr).len);
            defer gpa.free(buf);

            for (buf, 0..) |*shdr, i| {
                assert(self.sections.items(.shdr)[i].sh_offset != math.maxInt(u64));
                shdr.* = self.sections.items(.shdr)[i];
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf64_Shdr, shdr);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
        },
    }
}

fn writePhdrTable(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const target_endian = self.getTarget().cpu.arch.endian();
    const foreign_endian = target_endian != builtin.cpu.arch.endian();
    const phdr_table = &self.phdrs.items[self.phdr_indexes.table.int().?];

    log.debug("writing program headers from 0x{x} to 0x{x}", .{
        phdr_table.p_offset,
        phdr_table.p_offset + phdr_table.p_filesz,
    });

    switch (self.ptr_width) {
        .p32 => {
            const buf = try gpa.alloc(elf.Elf32_Phdr, self.phdrs.items.len);
            defer gpa.free(buf);

            for (buf, 0..) |*phdr, i| {
                phdr.* = phdrTo32(self.phdrs.items[i]);
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf32_Phdr, phdr);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), phdr_table.p_offset);
        },
        .p64 => {
            const buf = try gpa.alloc(elf.Elf64_Phdr, self.phdrs.items.len);
            defer gpa.free(buf);

            for (buf, 0..) |*phdr, i| {
                phdr.* = self.phdrs.items[i];
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf64_Phdr, phdr);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), phdr_table.p_offset);
        },
    }
}

pub fn writeElfHeader(self: *Elf) !void {
    const diags = &self.base.comp.link_diags;
    if (diags.hasErrors()) return; // We had errors, so skip flushing to render the output unusable

    const comp = self.base.comp;
    var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

    var index: usize = 0;
    hdr_buf[0..4].* = elf.MAGIC.*;
    index += 4;

    hdr_buf[index] = switch (self.ptr_width) {
        .p32 => elf.ELFCLASS32,
        .p64 => elf.ELFCLASS64,
    };
    index += 1;

    const target = self.getTarget();
    const endian = target.cpu.arch.endian();
    hdr_buf[index] = switch (endian) {
        .little => elf.ELFDATA2LSB,
        .big => elf.ELFDATA2MSB,
    };
    index += 1;

    hdr_buf[index] = 1; // ELF version
    index += 1;

    hdr_buf[index] = @intFromEnum(@as(elf.OSABI, switch (target.cpu.arch) {
        .amdgcn => switch (target.os.tag) {
            .amdhsa => .AMDGPU_HSA,
            .amdpal => .AMDGPU_PAL,
            .mesa3d => .AMDGPU_MESA3D,
            else => .NONE,
        },
        .msp430 => .STANDALONE,
        else => switch (target.os.tag) {
            .freebsd, .ps4 => .FREEBSD,
            .hermit => .STANDALONE,
            .illumos, .solaris => .SOLARIS,
            .openbsd => .OPENBSD,
            else => .NONE,
        },
    }));
    index += 1;

    // ABI Version, possibly used by glibc but not by static executables
    // padding
    @memset(hdr_buf[index..][0..8], 0);
    index += 8;

    assert(index == 16);

    const output_mode = comp.config.output_mode;
    const link_mode = comp.config.link_mode;
    const elf_type: elf.ET = switch (output_mode) {
        .Exe => if (comp.config.pie or target.os.tag == .haiku) .DYN else .EXEC,
        .Obj => .REL,
        .Lib => switch (link_mode) {
            .static => @as(elf.ET, .REL),
            .dynamic => .DYN,
        },
    };
    mem.writeInt(u16, hdr_buf[index..][0..2], @intFromEnum(elf_type), endian);
    index += 2;

    const machine = target.toElfMachine();
    mem.writeInt(u16, hdr_buf[index..][0..2], @intFromEnum(machine), endian);
    index += 2;

    // ELF Version, again
    mem.writeInt(u32, hdr_buf[index..][0..4], 1, endian);
    index += 4;

    const e_entry: u64 = if (self.linkerDefinedPtr()) |obj| blk: {
        const entry_sym = obj.entrySymbol(self) orelse break :blk 0;
        break :blk @intCast(entry_sym.address(.{}, self));
    } else 0;
    const phdr_table_offset = if (self.phdr_indexes.table.int()) |phndx| self.phdrs.items[phndx].p_offset else 0;
    switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, hdr_buf[index..][0..4], @intCast(e_entry), endian);
            index += 4;

            // e_phoff
            mem.writeInt(u32, hdr_buf[index..][0..4], @intCast(phdr_table_offset), endian);
            index += 4;

            // e_shoff
            mem.writeInt(u32, hdr_buf[index..][0..4], @intCast(self.shdr_table_offset.?), endian);
            index += 4;
        },
        .p64 => {
            // e_entry
            mem.writeInt(u64, hdr_buf[index..][0..8], e_entry, endian);
            index += 8;

            // e_phoff
            mem.writeInt(u64, hdr_buf[index..][0..8], phdr_table_offset, endian);
            index += 8;

            // e_shoff
            mem.writeInt(u64, hdr_buf[index..][0..8], self.shdr_table_offset.?, endian);
            index += 8;
        },
    }

    const e_flags = 0;
    mem.writeInt(u32, hdr_buf[index..][0..4], e_flags, endian);
    index += 4;

    const e_ehsize: u16 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Ehdr),
        .p64 => @sizeOf(elf.Elf64_Ehdr),
    };
    mem.writeInt(u16, hdr_buf[index..][0..2], e_ehsize, endian);
    index += 2;

    const e_phentsize: u16 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Phdr),
        .p64 => @sizeOf(elf.Elf64_Phdr),
    };
    mem.writeInt(u16, hdr_buf[index..][0..2], e_phentsize, endian);
    index += 2;

    const e_phnum = @as(u16, @intCast(self.phdrs.items.len));
    mem.writeInt(u16, hdr_buf[index..][0..2], e_phnum, endian);
    index += 2;

    const e_shentsize: u16 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Shdr),
        .p64 => @sizeOf(elf.Elf64_Shdr),
    };
    mem.writeInt(u16, hdr_buf[index..][0..2], e_shentsize, endian);
    index += 2;

    const e_shnum: u16 = @intCast(self.sections.items(.shdr).len);
    mem.writeInt(u16, hdr_buf[index..][0..2], e_shnum, endian);
    index += 2;

    mem.writeInt(u16, hdr_buf[index..][0..2], @intCast(self.section_indexes.shstrtab.?), endian);
    index += 2;

    assert(index == e_ehsize);

    try self.base.file.?.pwriteAll(hdr_buf[0..index], 0);
}

pub fn freeNav(self: *Elf, nav: InternPool.Nav.Index) void {
    if (self.llvm_object) |llvm_object| return llvm_object.freeNav(nav);
    return self.zigObjectPtr().?.freeNav(self, nav);
}

pub fn updateFunc(self: *Elf, pt: Zcu.PerThread, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(pt, func_index, air, liveness);
    return self.zigObjectPtr().?.updateFunc(self, pt, func_index, air, liveness);
}

pub fn updateNav(
    self: *Elf,
    pt: Zcu.PerThread,
    nav: InternPool.Nav.Index,
) link.File.UpdateNavError!void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateNav(pt, nav);
    return self.zigObjectPtr().?.updateNav(self, pt, nav);
}

pub fn updateContainerType(
    self: *Elf,
    pt: Zcu.PerThread,
    ty: InternPool.Index,
) link.File.UpdateNavError!void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |_| return;
    return self.zigObjectPtr().?.updateContainerType(pt, ty);
}

pub fn updateExports(
    self: *Elf,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const u32,
) link.File.UpdateExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateExports(pt, exported, export_indices);
    return self.zigObjectPtr().?.updateExports(self, pt, exported, export_indices);
}

pub fn updateNavLineNumber(self: *Elf, pt: Zcu.PerThread, nav: InternPool.Nav.Index) !void {
    if (self.llvm_object) |_| return;
    return self.zigObjectPtr().?.updateNavLineNumber(pt, nav);
}

pub fn deleteExport(
    self: *Elf,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    if (self.llvm_object) |_| return;
    return self.zigObjectPtr().?.deleteExport(self, exported, name);
}

fn checkDuplicates(self: *Elf) !void {
    const gpa = self.base.comp.gpa;

    var dupes = std.AutoArrayHashMap(SymbolResolver.Index, std.ArrayListUnmanaged(File.Index)).init(gpa);
    defer {
        for (dupes.values()) |*list| {
            list.deinit(gpa);
        }
        dupes.deinit();
    }

    if (self.zigObjectPtr()) |zig_object| {
        try zig_object.checkDuplicates(&dupes, self);
    }
    for (self.objects.items) |index| {
        try self.file(index).?.object.checkDuplicates(&dupes, self);
    }

    try self.reportDuplicates(dupes);
}

pub fn addCommentString(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    if (self.comment_merge_section_index != null) return;
    const msec_index = try self.getOrCreateMergeSection(".comment", elf.SHF_MERGE | elf.SHF_STRINGS, elf.SHT_PROGBITS);
    const msec = self.mergeSection(msec_index);
    const res = try msec.insertZ(gpa, "zig " ++ builtin.zig_version_string);
    if (res.found_existing) return;
    const msub_index = try msec.addMergeSubsection(gpa);
    const msub = msec.mergeSubsection(msub_index);
    msub.merge_section_index = msec_index;
    msub.string_index = res.key.pos;
    msub.alignment = .@"1";
    msub.size = res.key.len;
    msub.entsize = 1;
    msub.alive = true;
    res.sub.* = msub_index;
    self.comment_merge_section_index = msec_index;
}

pub fn resolveMergeSections(self: *Elf) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var has_errors = false;
    for (self.objects.items) |index| {
        const object = self.file(index).?.object;
        if (!object.alive) continue;
        if (!object.dirty) continue;
        object.initInputMergeSections(self) catch |err| switch (err) {
            error.LinkFailure => has_errors = true,
            else => |e| return e,
        };
    }

    if (has_errors) return error.FlushFailure;

    for (self.objects.items) |index| {
        const object = self.file(index).?.object;
        if (!object.alive) continue;
        if (!object.dirty) continue;
        try object.initOutputMergeSections(self);
    }

    for (self.objects.items) |index| {
        const object = self.file(index).?.object;
        if (!object.alive) continue;
        if (!object.dirty) continue;
        object.resolveMergeSubsections(self) catch |err| switch (err) {
            error.LinkFailure => has_errors = true,
            else => |e| return e,
        };
    }

    if (has_errors) return error.LinkFailure;
}

pub fn finalizeMergeSections(self: *Elf) !void {
    for (self.merge_sections.items) |*msec| {
        try msec.finalize(self.base.comp.gpa);
    }
}

pub fn updateMergeSectionSizes(self: *Elf) !void {
    for (self.merge_sections.items) |*msec| {
        msec.updateSize();
    }
    for (self.merge_sections.items) |*msec| {
        const shdr = &self.sections.items(.shdr)[msec.output_section_index];
        const offset = msec.alignment.forward(shdr.sh_size);
        const padding = offset - shdr.sh_size;
        msec.value = @intCast(offset);
        shdr.sh_size += padding + msec.size;
        shdr.sh_addralign = @max(shdr.sh_addralign, msec.alignment.toByteUnits() orelse 1);
        shdr.sh_entsize = if (shdr.sh_entsize == 0) msec.entsize else @min(shdr.sh_entsize, msec.entsize);
    }
}

pub fn writeMergeSections(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    for (self.merge_sections.items) |*msec| {
        const shdr = self.sections.items(.shdr)[msec.output_section_index];
        const fileoff = math.cast(usize, msec.value + shdr.sh_offset) orelse return error.Overflow;
        const size = math.cast(usize, msec.size) orelse return error.Overflow;
        try buffer.ensureTotalCapacity(size);
        buffer.appendNTimesAssumeCapacity(0, size);

        for (msec.finalized_subsections.items) |msub_index| {
            const msub = msec.mergeSubsection(msub_index);
            assert(msub.alive);
            const string = msub.getString(self);
            const off = math.cast(usize, msub.value) orelse return error.Overflow;
            @memcpy(buffer.items[off..][0..string.len], string);
        }

        try self.base.file.?.pwriteAll(buffer.items, fileoff);
        buffer.clearRetainingCapacity();
    }
}

fn initOutputSections(self: *Elf) !void {
    for (self.objects.items) |index| {
        try self.file(index).?.object.initOutputSections(self);
    }
    for (self.merge_sections.items) |*msec| {
        if (msec.finalized_subsections.items.len == 0) continue;
        try msec.initOutputSection(self);
    }
}

fn initSyntheticSections(self: *Elf) !void {
    const comp = self.base.comp;
    const target = self.getTarget();
    const ptr_size = self.ptrWidthBytes();
    const shared_objects = self.shared_objects.values();

    const needs_eh_frame = blk: {
        if (self.zigObjectPtr()) |zo|
            if (zo.eh_frame_index != null) break :blk true;
        break :blk for (self.objects.items) |index| {
            if (self.file(index).?.object.cies.items.len > 0) break true;
        } else false;
    };
    if (needs_eh_frame) {
        if (self.section_indexes.eh_frame == null) {
            self.section_indexes.eh_frame = self.sectionByName(".eh_frame") orelse try self.addSection(.{
                .name = try self.insertShString(".eh_frame"),
                .type = if (target.cpu.arch == .x86_64)
                    elf.SHT_X86_64_UNWIND
                else
                    elf.SHT_PROGBITS,
                .flags = elf.SHF_ALLOC,
                .addralign = ptr_size,
            });
        }
        if (comp.link_eh_frame_hdr and self.section_indexes.eh_frame_hdr == null) {
            self.section_indexes.eh_frame_hdr = try self.addSection(.{
                .name = try self.insertShString(".eh_frame_hdr"),
                .type = elf.SHT_PROGBITS,
                .flags = elf.SHF_ALLOC,
                .addralign = 4,
            });
        }
    }

    if (self.got.entries.items.len > 0 and self.section_indexes.got == null) {
        self.section_indexes.got = try self.addSection(.{
            .name = try self.insertShString(".got"),
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .addralign = ptr_size,
        });
    }

    if (self.section_indexes.got_plt == null) {
        self.section_indexes.got_plt = try self.addSection(.{
            .name = try self.insertShString(".got.plt"),
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .addralign = @alignOf(u64),
        });
    }

    const needs_rela_dyn = blk: {
        if (self.got.flags.needs_rela or self.got.flags.needs_tlsld or self.copy_rel.symbols.items.len > 0)
            break :blk true;
        if (self.zigObjectPtr()) |zig_object| {
            if (zig_object.num_dynrelocs > 0) break :blk true;
        }
        for (self.objects.items) |index| {
            if (self.file(index).?.object.num_dynrelocs > 0) break :blk true;
        }
        break :blk false;
    };
    if (needs_rela_dyn and self.section_indexes.rela_dyn == null) {
        self.section_indexes.rela_dyn = try self.addSection(.{
            .name = try self.insertShString(".rela.dyn"),
            .type = elf.SHT_RELA,
            .flags = elf.SHF_ALLOC,
            .addralign = @alignOf(elf.Elf64_Rela),
            .entsize = @sizeOf(elf.Elf64_Rela),
        });
    }

    if (self.plt.symbols.items.len > 0) {
        if (self.section_indexes.plt == null) {
            self.section_indexes.plt = try self.addSection(.{
                .name = try self.insertShString(".plt"),
                .type = elf.SHT_PROGBITS,
                .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
                .addralign = 16,
            });
        }
        if (self.section_indexes.rela_plt == null) {
            self.section_indexes.rela_plt = try self.addSection(.{
                .name = try self.insertShString(".rela.plt"),
                .type = elf.SHT_RELA,
                .flags = elf.SHF_ALLOC,
                .addralign = @alignOf(elf.Elf64_Rela),
                .entsize = @sizeOf(elf.Elf64_Rela),
            });
        }
    }

    if (self.plt_got.symbols.items.len > 0 and self.section_indexes.plt_got == null) {
        self.section_indexes.plt_got = try self.addSection(.{
            .name = try self.insertShString(".plt.got"),
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            .addralign = 16,
        });
    }

    if (self.copy_rel.symbols.items.len > 0 and self.section_indexes.copy_rel == null) {
        self.section_indexes.copy_rel = try self.addSection(.{
            .name = try self.insertShString(".copyrel"),
            .type = elf.SHT_NOBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
        });
    }

    const needs_interp = blk: {
        // On Ubuntu with musl-gcc, we get a weird combo of options looking like this:
        // -dynamic-linker=<path> -static
        // In this case, if we do generate .interp section and segment, we will get
        // a segfault in the dynamic linker trying to load a binary that is static
        // and doesn't contain .dynamic section.
        if (self.base.isStatic() and !comp.config.pie) break :blk false;
        break :blk target.dynamic_linker.get() != null;
    };
    if (needs_interp and self.section_indexes.interp == null) {
        self.section_indexes.interp = try self.addSection(.{
            .name = try self.insertShString(".interp"),
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC,
            .addralign = 1,
        });
    }

    if (self.isEffectivelyDynLib() or shared_objects.len > 0 or comp.config.pie) {
        if (self.section_indexes.dynstrtab == null) {
            self.section_indexes.dynstrtab = try self.addSection(.{
                .name = try self.insertShString(".dynstr"),
                .flags = elf.SHF_ALLOC,
                .type = elf.SHT_STRTAB,
                .entsize = 1,
                .addralign = 1,
            });
        }
        if (self.section_indexes.dynamic == null) {
            self.section_indexes.dynamic = try self.addSection(.{
                .name = try self.insertShString(".dynamic"),
                .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
                .type = elf.SHT_DYNAMIC,
                .entsize = @sizeOf(elf.Elf64_Dyn),
                .addralign = @alignOf(elf.Elf64_Dyn),
            });
        }
        if (self.section_indexes.dynsymtab == null) {
            self.section_indexes.dynsymtab = try self.addSection(.{
                .name = try self.insertShString(".dynsym"),
                .flags = elf.SHF_ALLOC,
                .type = elf.SHT_DYNSYM,
                .addralign = @alignOf(elf.Elf64_Sym),
                .entsize = @sizeOf(elf.Elf64_Sym),
                .info = 1,
            });
        }
        if (self.section_indexes.hash == null) {
            self.section_indexes.hash = try self.addSection(.{
                .name = try self.insertShString(".hash"),
                .flags = elf.SHF_ALLOC,
                .type = elf.SHT_HASH,
                .addralign = 4,
                .entsize = 4,
            });
        }
        if (self.section_indexes.gnu_hash == null) {
            self.section_indexes.gnu_hash = try self.addSection(.{
                .name = try self.insertShString(".gnu.hash"),
                .flags = elf.SHF_ALLOC,
                .type = elf.SHT_GNU_HASH,
                .addralign = 8,
            });
        }

        const needs_versions = for (self.dynsym.entries.items) |entry| {
            const sym = self.symbol(entry.ref).?;
            if (sym.flags.import and sym.version_index.VERSION > elf.Versym.GLOBAL.VERSION) break true;
        } else false;
        if (needs_versions) {
            if (self.section_indexes.versym == null) {
                self.section_indexes.versym = try self.addSection(.{
                    .name = try self.insertShString(".gnu.version"),
                    .flags = elf.SHF_ALLOC,
                    .type = elf.SHT_GNU_VERSYM,
                    .addralign = @alignOf(elf.Versym),
                    .entsize = @sizeOf(elf.Versym),
                });
            }
            if (self.section_indexes.verneed == null) {
                self.section_indexes.verneed = try self.addSection(.{
                    .name = try self.insertShString(".gnu.version_r"),
                    .flags = elf.SHF_ALLOC,
                    .type = elf.SHT_GNU_VERNEED,
                    .addralign = @alignOf(elf.Elf64_Verneed),
                });
            }
        }
    }

    try self.initSymtab();
    try self.initShStrtab();
}

pub fn initSymtab(self: *Elf) !void {
    const small_ptr = switch (self.ptr_width) {
        .p32 => true,
        .p64 => false,
    };
    if (self.section_indexes.symtab == null) {
        self.section_indexes.symtab = try self.addSection(.{
            .name = try self.insertShString(".symtab"),
            .type = elf.SHT_SYMTAB,
            .addralign = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym),
            .entsize = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym),
        });
    }
    if (self.section_indexes.strtab == null) {
        self.section_indexes.strtab = try self.addSection(.{
            .name = try self.insertShString(".strtab"),
            .type = elf.SHT_STRTAB,
            .entsize = 1,
            .addralign = 1,
        });
    }
}

pub fn initShStrtab(self: *Elf) !void {
    if (self.section_indexes.shstrtab == null) {
        self.section_indexes.shstrtab = try self.addSection(.{
            .name = try self.insertShString(".shstrtab"),
            .type = elf.SHT_STRTAB,
            .entsize = 1,
            .addralign = 1,
        });
    }
}

fn initSpecialPhdrs(self: *Elf) !void {
    comptime assert(max_number_of_special_phdrs == 5);

    if (self.section_indexes.interp != null and self.phdr_indexes.interp == .none) {
        self.phdr_indexes.interp = (try self.addPhdr(.{
            .type = elf.PT_INTERP,
            .flags = elf.PF_R,
            .@"align" = 1,
        })).toOptional();
    }
    if (self.section_indexes.dynamic != null and self.phdr_indexes.dynamic == .none) {
        self.phdr_indexes.dynamic = (try self.addPhdr(.{
            .type = elf.PT_DYNAMIC,
            .flags = elf.PF_R | elf.PF_W,
        })).toOptional();
    }
    if (self.section_indexes.eh_frame_hdr != null and self.phdr_indexes.gnu_eh_frame == .none) {
        self.phdr_indexes.gnu_eh_frame = (try self.addPhdr(.{
            .type = elf.PT_GNU_EH_FRAME,
            .flags = elf.PF_R,
        })).toOptional();
    }
    if (self.phdr_indexes.gnu_stack == .none) {
        self.phdr_indexes.gnu_stack = (try self.addPhdr(.{
            .type = elf.PT_GNU_STACK,
            .flags = elf.PF_W | elf.PF_R,
            .memsz = self.base.stack_size,
            .@"align" = 1,
        })).toOptional();
    }

    const has_tls = for (self.sections.items(.shdr)) |shdr| {
        if (shdr.sh_flags & elf.SHF_TLS != 0) break true;
    } else false;
    if (has_tls and self.phdr_indexes.tls == .none) {
        self.phdr_indexes.tls = (try self.addPhdr(.{
            .type = elf.PT_TLS,
            .flags = elf.PF_R,
            .@"align" = 1,
        })).toOptional();
    }
}

/// We need to sort constructors/destuctors in the following sections:
/// * .init_array
/// * .fini_array
/// * .preinit_array
/// * .ctors
/// * .dtors
/// The prority of inclusion is defined as part of the input section's name. For example, .init_array.10000.
/// If no priority value has been specified,
/// * for .init_array, .fini_array and .preinit_array, we automatically assign that section max value of maxInt(i32)
///   and push it to the back of the queue,
/// * for .ctors and .dtors, we automatically assign that section min value of -1
///   and push it to the front of the queue,
/// crtbegin and ctrend are assigned minInt(i32) and maxInt(i32) respectively.
/// Ties are broken by the file prority which corresponds to the inclusion of input sections in this output section
/// we are about to sort.
fn sortInitFini(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const slice = self.sections.slice();

    const Entry = struct {
        priority: i32,
        atom_ref: Ref,

        pub fn lessThan(ctx: *Elf, lhs: @This(), rhs: @This()) bool {
            if (lhs.priority == rhs.priority) {
                return ctx.atom(lhs.atom_ref).?.priority(ctx) < ctx.atom(rhs.atom_ref).?.priority(ctx);
            }
            return lhs.priority < rhs.priority;
        }
    };

    for (slice.items(.shdr), slice.items(.atom_list_2)) |shdr, *atom_list| {
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        if (atom_list.atoms.keys().len == 0) continue;

        var is_init_fini = false;
        var is_ctor_dtor = false;
        switch (shdr.sh_type) {
            elf.SHT_PREINIT_ARRAY,
            elf.SHT_INIT_ARRAY,
            elf.SHT_FINI_ARRAY,
            => is_init_fini = true,
            else => {
                const name = self.getShString(shdr.sh_name);
                is_ctor_dtor = mem.indexOf(u8, name, ".ctors") != null or mem.indexOf(u8, name, ".dtors") != null;
            },
        }
        if (!is_init_fini and !is_ctor_dtor) continue;

        var entries = std.ArrayList(Entry).init(gpa);
        try entries.ensureTotalCapacityPrecise(atom_list.atoms.keys().len);
        defer entries.deinit();

        for (atom_list.atoms.keys()) |ref| {
            const atom_ptr = self.atom(ref).?;
            const object = atom_ptr.file(self).?.object;
            const priority = blk: {
                if (is_ctor_dtor) {
                    const basename = object.path.basename();
                    if (mem.eql(u8, basename, "crtbegin.o")) break :blk std.math.minInt(i32);
                    if (mem.eql(u8, basename, "crtend.o")) break :blk std.math.maxInt(i32);
                }
                const default: i32 = if (is_ctor_dtor) -1 else std.math.maxInt(i32);
                const name = atom_ptr.name(self);
                var it = mem.splitBackwardsScalar(u8, name, '.');
                const priority = std.fmt.parseUnsigned(u16, it.first(), 10) catch default;
                break :blk priority;
            };
            entries.appendAssumeCapacity(.{ .priority = priority, .atom_ref = ref });
        }

        mem.sort(Entry, entries.items, self, Entry.lessThan);

        atom_list.atoms.clearRetainingCapacity();
        for (entries.items) |entry| {
            _ = atom_list.atoms.getOrPutAssumeCapacity(entry.atom_ref);
        }
    }
}

fn setDynamicSection(self: *Elf, rpaths: []const []const u8) !void {
    if (self.section_indexes.dynamic == null) return;

    const shared_objects = self.shared_objects.values();

    for (shared_objects) |index| {
        const shared_object = self.file(index).?.shared_object;
        if (!shared_object.alive) continue;
        try self.dynamic.addNeeded(shared_object, self);
    }

    if (self.isEffectivelyDynLib()) {
        if (self.soname) |soname| {
            try self.dynamic.setSoname(soname, self);
        }
    }

    try self.dynamic.setRpath(rpaths, self);
}

fn sortDynamicSymtab(self: *Elf) void {
    if (self.section_indexes.gnu_hash == null) return;
    self.dynsym.sort(self);
}

fn setVersionSymtab(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    if (self.section_indexes.versym == null) return;
    try self.versym.resize(gpa, self.dynsym.count());
    self.versym.items[0] = .LOCAL;
    for (self.dynsym.entries.items, 1..) |entry, i| {
        const sym = self.symbol(entry.ref).?;
        self.versym.items[i] = sym.version_index;
    }

    if (self.section_indexes.verneed) |shndx| {
        try self.verneed.generate(self);
        const shdr = &self.sections.items(.shdr)[shndx];
        shdr.sh_info = @as(u32, @intCast(self.verneed.verneed.items.len));
    }
}

fn setHashSections(self: *Elf) !void {
    if (self.section_indexes.hash != null) {
        try self.hash.generate(self);
    }
    if (self.section_indexes.gnu_hash != null) {
        try self.gnu_hash.calcSize(self);
    }
}

fn phdrRank(phdr: elf.Elf64_Phdr) u8 {
    return switch (phdr.p_type) {
        elf.PT_NULL => 0,
        elf.PT_PHDR => 1,
        elf.PT_INTERP => 2,
        elf.PT_LOAD => 3,
        elf.PT_DYNAMIC, elf.PT_TLS => 4,
        elf.PT_GNU_EH_FRAME => 5,
        elf.PT_GNU_STACK => 6,
        else => 7,
    };
}

fn sortPhdrs(
    gpa: Allocator,
    phdrs: *ProgramHeaderList,
    special_indexes: *ProgramHeaderIndexes,
    section_indexes: []OptionalProgramHeaderIndex,
) error{OutOfMemory}!void {
    const Entry = struct {
        phndx: u16,

        pub fn lessThan(program_headers: []const elf.Elf64_Phdr, lhs: @This(), rhs: @This()) bool {
            const lhs_phdr = program_headers[lhs.phndx];
            const rhs_phdr = program_headers[rhs.phndx];
            const lhs_rank = phdrRank(lhs_phdr);
            const rhs_rank = phdrRank(rhs_phdr);
            if (lhs_rank == rhs_rank) return lhs_phdr.p_vaddr < rhs_phdr.p_vaddr;
            return lhs_rank < rhs_rank;
        }
    };

    const entries = try gpa.alloc(Entry, phdrs.items.len);
    defer gpa.free(entries);
    for (entries, 0..) |*entry, phndx| {
        entry.* = .{ .phndx = @intCast(phndx) };
    }

    // The `@as` here works around a bug in the C backend.
    mem.sort(Entry, entries, @as([]const elf.Elf64_Phdr, phdrs.items), Entry.lessThan);

    const backlinks = try gpa.alloc(u16, entries.len);
    defer gpa.free(backlinks);
    const slice = try phdrs.toOwnedSlice(gpa);
    defer gpa.free(slice);
    try phdrs.resize(gpa, slice.len);

    for (entries, phdrs.items, 0..) |entry, *phdr, i| {
        backlinks[entry.phndx] = @intCast(i);
        phdr.* = slice[entry.phndx];
    }

    inline for (@typeInfo(ProgramHeaderIndexes).@"struct".fields) |field| {
        if (@field(special_indexes, field.name).int()) |special_index| {
            @field(special_indexes, field.name) = @enumFromInt(backlinks[special_index]);
        }
    }

    for (section_indexes) |*opt_phndx| {
        if (opt_phndx.int()) |index| {
            opt_phndx.* = @enumFromInt(backlinks[index]);
        }
    }
}

fn shdrRank(shdr: elf.Elf64_Shdr, shstrtab: []const u8) u8 {
    const name = shString(shstrtab, shdr.sh_name);
    const flags = shdr.sh_flags;

    switch (shdr.sh_type) {
        elf.SHT_NULL => return 0,
        elf.SHT_DYNSYM => return 2,
        elf.SHT_HASH => return 3,
        elf.SHT_GNU_HASH => return 3,
        elf.SHT_GNU_VERSYM => return 4,
        elf.SHT_GNU_VERDEF => return 4,
        elf.SHT_GNU_VERNEED => return 4,

        elf.SHT_PREINIT_ARRAY,
        elf.SHT_INIT_ARRAY,
        elf.SHT_FINI_ARRAY,
        => return 0xf1,

        elf.SHT_DYNAMIC => return 0xf2,

        elf.SHT_RELA, elf.SHT_GROUP => return 0xf,

        elf.SHT_PROGBITS => if (flags & elf.SHF_ALLOC != 0) {
            if (flags & elf.SHF_EXECINSTR != 0) {
                return 0xf0;
            } else if (flags & elf.SHF_WRITE != 0) {
                return if (flags & elf.SHF_TLS != 0) 0xf3 else 0xf5;
            } else if (mem.eql(u8, name, ".interp")) {
                return 1;
            } else if (mem.startsWith(u8, name, ".eh_frame")) {
                return 0xe1;
            } else {
                return 0xe0;
            }
        } else {
            if (mem.startsWith(u8, name, ".debug")) {
                return 0xf7;
            } else {
                return 0xf8;
            }
        },
        elf.SHT_X86_64_UNWIND => return 0xe1,

        elf.SHT_NOBITS => return if (flags & elf.SHF_TLS != 0) 0xf4 else 0xf6,
        elf.SHT_SYMTAB => return 0xf9,
        elf.SHT_STRTAB => return if (mem.eql(u8, name, ".dynstr")) 0x4 else 0xfa,
        else => return 0xff,
    }
}

pub fn sortShdrs(
    gpa: Allocator,
    section_indexes: *SectionIndexes,
    sections: *std.MultiArrayList(Section),
    shstrtab: []const u8,
    merge_sections: []Merge.Section,
    comdat_group_sections: []ComdatGroupSection,
    zig_object_ptr: ?*ZigObject,
    files: std.MultiArrayList(File.Entry),
) !void {
    const Entry = struct {
        shndx: u32,

        const Context = struct {
            shdrs: []const elf.Elf64_Shdr,
            shstrtab: []const u8,
        };

        pub fn lessThan(ctx: Context, lhs: @This(), rhs: @This()) bool {
            return shdrRank(ctx.shdrs[lhs.shndx], ctx.shstrtab) <
                shdrRank(ctx.shdrs[rhs.shndx], ctx.shstrtab);
        }
    };

    const shdrs = sections.items(.shdr);

    const entries = try gpa.alloc(Entry, shdrs.len);
    defer gpa.free(entries);
    for (entries, 0..shdrs.len) |*entry, shndx| {
        entry.* = .{ .shndx = @intCast(shndx) };
    }

    const sort_context: Entry.Context = .{
        .shdrs = shdrs,
        .shstrtab = shstrtab,
    };
    mem.sort(Entry, entries, sort_context, Entry.lessThan);

    const backlinks = try gpa.alloc(u32, entries.len);
    defer gpa.free(backlinks);
    {
        var slice = sections.toOwnedSlice();
        defer slice.deinit(gpa);
        try sections.resize(gpa, slice.len);

        for (entries, 0..) |entry, i| {
            backlinks[entry.shndx] = @intCast(i);
            sections.set(i, slice.get(entry.shndx));
        }
    }

    inline for (@typeInfo(SectionIndexes).@"struct".fields) |field| {
        if (@field(section_indexes, field.name)) |special_index| {
            @field(section_indexes, field.name) = backlinks[special_index];
        }
    }

    for (merge_sections) |*msec| {
        msec.output_section_index = backlinks[msec.output_section_index];
    }

    const slice = sections.slice();
    for (slice.items(.shdr), slice.items(.atom_list_2)) |*shdr, *atom_list| {
        atom_list.output_section_index = backlinks[atom_list.output_section_index];
        for (atom_list.atoms.keys()) |ref| {
            fileLookup(files, ref.file).?.atom(ref.index).?.output_section_index = atom_list.output_section_index;
        }
        if (shdr.sh_type == elf.SHT_RELA) {
            // FIXME:JK we should spin up .symtab potentially earlier, or set all non-dynamic RELA sections
            // to point at symtab
            // shdr.sh_link = backlinks[shdr.sh_link];
            shdr.sh_link = section_indexes.symtab.?;
            shdr.sh_info = backlinks[shdr.sh_info];
        }
    }

    if (zig_object_ptr) |zo| zo.resetShdrIndexes(backlinks);

    for (comdat_group_sections) |*cg| {
        cg.shndx = backlinks[cg.shndx];
    }

    if (section_indexes.symtab) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.strtab.?;
    }

    if (section_indexes.dynamic) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynstrtab.?;
    }

    if (section_indexes.dynsymtab) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynstrtab.?;
    }

    if (section_indexes.hash) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynsymtab.?;
    }

    if (section_indexes.gnu_hash) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynsymtab.?;
    }

    if (section_indexes.versym) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynsymtab.?;
    }

    if (section_indexes.verneed) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynstrtab.?;
    }

    if (section_indexes.rela_dyn) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynsymtab orelse 0;
    }

    if (section_indexes.rela_plt) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.dynsymtab.?;
        shdr.sh_info = section_indexes.plt.?;
    }

    if (section_indexes.eh_frame_rela) |index| {
        const shdr = &slice.items(.shdr)[index];
        shdr.sh_link = section_indexes.symtab.?;
        shdr.sh_info = section_indexes.eh_frame.?;
    }
}

fn updateSectionSizes(self: *Elf) !void {
    const slice = self.sections.slice();
    for (slice.items(.shdr), slice.items(.atom_list_2)) |shdr, *atom_list| {
        if (atom_list.atoms.keys().len == 0) continue;
        if (!atom_list.dirty) continue;
        if (self.requiresThunks() and shdr.sh_flags & elf.SHF_EXECINSTR != 0) continue;
        atom_list.updateSize(self);
        try atom_list.allocate(self);
        atom_list.dirty = false;
    }

    if (self.requiresThunks()) {
        for (slice.items(.shdr), slice.items(.atom_list_2)) |shdr, *atom_list| {
            if (shdr.sh_flags & elf.SHF_EXECINSTR == 0) continue;
            if (atom_list.atoms.keys().len == 0) continue;
            if (!atom_list.dirty) continue;

            // Create jump/branch range extenders if needed.
            try self.createThunks(atom_list);
            try atom_list.allocate(self);
            atom_list.dirty = false;
        }

        // FIXME:JK this will hopefully not be needed once we create a link from Atom/Thunk to AtomList.
        for (self.thunks.items) |*th| {
            th.value += slice.items(.atom_list_2)[th.output_section_index].value;
        }
    }

    const shdrs = slice.items(.shdr);
    if (self.section_indexes.eh_frame) |index| {
        shdrs[index].sh_size = try eh_frame.calcEhFrameSize(self);
    }

    if (self.section_indexes.eh_frame_hdr) |index| {
        shdrs[index].sh_size = eh_frame.calcEhFrameHdrSize(self);
    }

    if (self.section_indexes.got) |index| {
        shdrs[index].sh_size = self.got.size(self);
    }

    if (self.section_indexes.plt) |index| {
        shdrs[index].sh_size = self.plt.size(self);
    }

    if (self.section_indexes.got_plt) |index| {
        shdrs[index].sh_size = self.got_plt.size(self);
    }

    if (self.section_indexes.plt_got) |index| {
        shdrs[index].sh_size = self.plt_got.size(self);
    }

    if (self.section_indexes.rela_dyn) |shndx| {
        var num = self.got.numRela(self) + self.copy_rel.numRela();
        if (self.zigObjectPtr()) |zig_object| {
            num += zig_object.num_dynrelocs;
        }
        for (self.objects.items) |index| {
            num += self.file(index).?.object.num_dynrelocs;
        }
        shdrs[shndx].sh_size = num * @sizeOf(elf.Elf64_Rela);
    }

    if (self.section_indexes.rela_plt) |index| {
        shdrs[index].sh_size = self.plt.numRela() * @sizeOf(elf.Elf64_Rela);
    }

    if (self.section_indexes.copy_rel) |index| {
        try self.copy_rel.updateSectionSize(index, self);
    }

    if (self.section_indexes.interp) |index| {
        shdrs[index].sh_size = self.getTarget().dynamic_linker.get().?.len + 1;
    }

    if (self.section_indexes.hash) |index| {
        shdrs[index].sh_size = self.hash.size();
    }

    if (self.section_indexes.gnu_hash) |index| {
        shdrs[index].sh_size = self.gnu_hash.size();
    }

    if (self.section_indexes.dynamic) |index| {
        shdrs[index].sh_size = self.dynamic.size(self);
    }

    if (self.section_indexes.dynsymtab) |index| {
        shdrs[index].sh_size = self.dynsym.size();
    }

    if (self.section_indexes.dynstrtab) |index| {
        shdrs[index].sh_size = self.dynstrtab.items.len;
    }

    if (self.section_indexes.versym) |index| {
        shdrs[index].sh_size = self.versym.items.len * @sizeOf(elf.Versym);
    }

    if (self.section_indexes.verneed) |index| {
        shdrs[index].sh_size = self.verneed.size();
    }

    try self.updateSymtabSize();
    self.updateShStrtabSize();
}

// FIXME:JK this is very much obsolete, remove!
pub fn updateShStrtabSize(self: *Elf) void {
    if (self.section_indexes.shstrtab) |index| {
        self.sections.items(.shdr)[index].sh_size = self.shstrtab.items.len;
    }
}

fn shdrToPhdrFlags(sh_flags: u64) u32 {
    const write = sh_flags & elf.SHF_WRITE != 0;
    const exec = sh_flags & elf.SHF_EXECINSTR != 0;
    var out_flags: u32 = elf.PF_R;
    if (write) out_flags |= elf.PF_W;
    if (exec) out_flags |= elf.PF_X;
    return out_flags;
}

/// Returns maximum number of program headers that may be emitted by the linker.
/// (This is an upper bound so that we can reserve enough space for the header and progam header
/// table without running out of space and being forced to move things around.)
fn getMaxNumberOfPhdrs() u64 {
    // The estimated maximum number of segments the linker can emit for input sections are:
    var num: u64 = max_number_of_object_segments;
    // Any other non-loadable program headers, including TLS, DYNAMIC, GNU_STACK, GNU_EH_FRAME, INTERP:
    num += max_number_of_special_phdrs;
    // PHDR program header and corresponding read-only load segment:
    num += 2;
    return num;
}

fn addLoadPhdrs(self: *Elf) error{OutOfMemory}!void {
    for (self.sections.items(.shdr)) |shdr| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        const flags = shdrToPhdrFlags(shdr.sh_flags);
        if (self.getPhdr(.{ .flags = flags, .type = elf.PT_LOAD }) == .none) {
            _ = try self.addPhdr(.{ .flags = flags, .type = elf.PT_LOAD });
        }
    }
}

/// Allocates PHDR table in virtual memory and in file.
fn allocatePhdrTable(self: *Elf) error{OutOfMemory}!void {
    const diags = &self.base.comp.link_diags;
    const phdr_table = &self.phdrs.items[self.phdr_indexes.table.int().?];
    const phdr_table_load = &self.phdrs.items[self.phdr_indexes.table_load.int().?];

    const ehsize: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Ehdr),
        .p64 => @sizeOf(elf.Elf64_Ehdr),
    };
    const phsize: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Phdr),
        .p64 => @sizeOf(elf.Elf64_Phdr),
    };
    const needed_size = self.phdrs.items.len * phsize;
    const available_space = self.allocatedSize(phdr_table.p_offset);

    if (needed_size > available_space) {
        // In this case, we have two options:
        // 1. increase the available padding for EHDR + PHDR table so that we don't overflow it
        //    (revisit getMaxNumberOfPhdrs())
        // 2. shift everything in file to free more space for EHDR + PHDR table
        // TODO verify `getMaxNumberOfPhdrs()` is accurate and convert this into no-op
        var err = try diags.addErrorWithNotes(1);
        try err.addMsg("fatal linker error: not enough space reserved for EHDR and PHDR table", .{});
        try err.addNote("required 0x{x}, available 0x{x}", .{ needed_size, available_space });
    }

    phdr_table_load.p_filesz = needed_size + ehsize;
    phdr_table_load.p_memsz = needed_size + ehsize;
    phdr_table.p_filesz = needed_size;
    phdr_table.p_memsz = needed_size;
}

/// Allocates alloc sections and creates load segments for sections
/// extracted from input object files.
pub fn allocateAllocSections(self: *Elf) !void {
    // We use this struct to track maximum alignment of all TLS sections.
    // According to https://github.com/rui314/mold/commit/bd46edf3f0fe9e1a787ea453c4657d535622e61f in mold,
    // in-file offsets have to be aligned against the start of TLS program header.
    // If that's not ensured, then in a multi-threaded context, TLS variables across a shared object
    // boundary may not get correctly loaded at an aligned address.
    const Align = struct {
        tls_start_align: u64 = 1,
        first_tls_index: ?usize = null,

        fn isFirstTlsShdr(this: @This(), other: usize) bool {
            if (this.first_tls_index) |index| return index == other;
            return false;
        }

        fn @"align"(this: @This(), index: usize, sh_addralign: u64, addr: u64) u64 {
            const alignment = if (this.isFirstTlsShdr(index)) this.tls_start_align else sh_addralign;
            return mem.alignForward(u64, addr, alignment);
        }
    };

    const slice = self.sections.slice();
    var alignment = Align{};
    for (slice.items(.shdr), 0..) |shdr, i| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_TLS == 0) continue;
        if (alignment.first_tls_index == null) alignment.first_tls_index = i;
        alignment.tls_start_align = @max(alignment.tls_start_align, shdr.sh_addralign);
    }

    // Next, calculate segment covers by scanning all alloc sections.
    // If a section matches segment flags with the preceeding section,
    // we put it in the same segment. Otherwise, we create a new cover.
    // This algorithm is simple but suboptimal in terms of space re-use:
    // normally we would also take into account any gaps in allocated
    // virtual and file offsets. However, the simple one will do for one
    // as we are more interested in quick turnaround and compatibility
    // with `findFreeSpace` mechanics than anything else.
    const Cover = std.ArrayList(u32);
    const gpa = self.base.comp.gpa;
    var covers: [max_number_of_object_segments]Cover = undefined;
    for (&covers) |*cover| {
        cover.* = Cover.init(gpa);
    }
    defer for (&covers) |*cover| {
        cover.deinit();
    };

    for (slice.items(.shdr), 0..) |shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        const flags = shdrToPhdrFlags(shdr.sh_flags);
        try covers[flags - 1].append(@intCast(shndx));
    }

    // Now we can proceed with allocating the sections in virtual memory.
    // As the base address we take the end address of the PHDR table.
    // When allocating we first find the largest required alignment
    // of any section that is contained in a cover and use it to align
    // the start address of the segement (and first section).
    const phdr_table = &self.phdrs.items[self.phdr_indexes.table_load.int().?];
    var addr = phdr_table.p_vaddr + phdr_table.p_memsz;

    for (covers) |cover| {
        if (cover.items.len == 0) continue;

        var @"align": u64 = self.page_size;
        for (cover.items) |shndx| {
            const shdr = slice.items(.shdr)[shndx];
            if (shdr.sh_type == elf.SHT_NOBITS and shdr.sh_flags & elf.SHF_TLS != 0) continue;
            @"align" = @max(@"align", shdr.sh_addralign);
        }

        addr = mem.alignForward(u64, addr, @"align");

        var memsz: u64 = 0;
        var filesz: u64 = 0;
        var i: usize = 0;
        while (i < cover.items.len) : (i += 1) {
            const shndx = cover.items[i];
            const shdr = &slice.items(.shdr)[shndx];
            if (shdr.sh_type == elf.SHT_NOBITS and shdr.sh_flags & elf.SHF_TLS != 0) {
                // .tbss is a little special as it's used only by the loader meaning it doesn't
                // need to be actually mmap'ed at runtime. We still need to correctly increment
                // the addresses of every TLS zerofill section tho. Thus, we hack it so that
                // we increment the start address like normal, however, after we are done,
                // the next ALLOC section will get its start address allocated within the same
                // range as the .tbss sections. We will get something like this:
                //
                // ...
                // .tbss 0x10
                // .tcommon 0x20
                // .data 0x10
                // ...
                var tbss_addr = addr;
                while (i < cover.items.len and
                    slice.items(.shdr)[cover.items[i]].sh_type == elf.SHT_NOBITS and
                    slice.items(.shdr)[cover.items[i]].sh_flags & elf.SHF_TLS != 0) : (i += 1)
                {
                    const tbss_shndx = cover.items[i];
                    const tbss_shdr = &slice.items(.shdr)[tbss_shndx];
                    tbss_addr = alignment.@"align"(tbss_shndx, tbss_shdr.sh_addralign, tbss_addr);
                    tbss_shdr.sh_addr = tbss_addr;
                    tbss_addr += tbss_shdr.sh_size;
                }
                i -= 1;
                continue;
            }
            const next = alignment.@"align"(shndx, shdr.sh_addralign, addr);
            const padding = next - addr;
            addr = next;
            shdr.sh_addr = addr;
            if (shdr.sh_type != elf.SHT_NOBITS) {
                filesz += padding + shdr.sh_size;
            }
            memsz += padding + shdr.sh_size;
            addr += shdr.sh_size;
        }

        const first = slice.items(.shdr)[cover.items[0]];
        const phndx = self.getPhdr(.{ .type = elf.PT_LOAD, .flags = shdrToPhdrFlags(first.sh_flags) }).unwrap().?;
        const phdr = &self.phdrs.items[phndx.int()];
        const allocated_size = self.allocatedSize(phdr.p_offset);
        if (filesz > allocated_size) {
            const old_offset = phdr.p_offset;
            phdr.p_offset = 0;
            var new_offset = try self.findFreeSpace(filesz, @"align");
            phdr.p_offset = new_offset;

            log.debug("moving phdr({d}) from 0x{x} to 0x{x}", .{ phndx, old_offset, new_offset });

            for (cover.items) |shndx| {
                const shdr = &slice.items(.shdr)[shndx];
                slice.items(.phndx)[shndx] = phndx.toOptional();
                if (shdr.sh_type == elf.SHT_NOBITS) {
                    shdr.sh_offset = 0;
                    continue;
                }
                new_offset = alignment.@"align"(shndx, shdr.sh_addralign, new_offset);

                log.debug("moving {s} from 0x{x} to 0x{x}", .{
                    self.getShString(shdr.sh_name),
                    shdr.sh_offset,
                    new_offset,
                });

                if (shdr.sh_offset > 0) {
                    // Get size actually commited to the output file.
                    const existing_size = self.sectionSize(shndx);
                    const amt = try self.base.file.?.copyRangeAll(
                        shdr.sh_offset,
                        self.base.file.?,
                        new_offset,
                        existing_size,
                    );
                    if (amt != existing_size) return error.InputOutput;
                }

                shdr.sh_offset = new_offset;
                new_offset += shdr.sh_size;
            }
        }

        phdr.p_vaddr = first.sh_addr;
        phdr.p_paddr = first.sh_addr;
        phdr.p_memsz = memsz;
        phdr.p_filesz = filesz;
        phdr.p_align = @"align";

        addr = mem.alignForward(u64, addr, self.page_size);
    }
}

/// Allocates non-alloc sections (debug info, symtabs, etc.).
pub fn allocateNonAllocSections(self: *Elf) !void {
    for (self.sections.items(.shdr), 0..) |*shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC != 0) continue;
        const needed_size = shdr.sh_size;
        if (needed_size > self.allocatedSize(shdr.sh_offset)) {
            shdr.sh_size = 0;
            const new_offset = try self.findFreeSpace(needed_size, shdr.sh_addralign);

            log.debug("moving {s} from 0x{x} to 0x{x}", .{
                self.getShString(shdr.sh_name),
                shdr.sh_offset,
                new_offset,
            });

            if (shdr.sh_offset > 0) {
                const existing_size = self.sectionSize(@intCast(shndx));
                const amt = try self.base.file.?.copyRangeAll(
                    shdr.sh_offset,
                    self.base.file.?,
                    new_offset,
                    existing_size,
                );
                if (amt != existing_size) return error.InputOutput;
            }

            shdr.sh_offset = new_offset;
            shdr.sh_size = needed_size;
        }
    }
}

fn allocateSpecialPhdrs(self: *Elf) void {
    const slice = self.sections.slice();

    for (&[_]struct { OptionalProgramHeaderIndex, ?u32 }{
        .{ self.phdr_indexes.interp, self.section_indexes.interp },
        .{ self.phdr_indexes.dynamic, self.section_indexes.dynamic },
        .{ self.phdr_indexes.gnu_eh_frame, self.section_indexes.eh_frame_hdr },
    }) |pair| {
        if (pair[0].int()) |index| {
            const shdr = slice.items(.shdr)[pair[1].?];
            const phdr = &self.phdrs.items[index];
            phdr.p_align = shdr.sh_addralign;
            phdr.p_offset = shdr.sh_offset;
            phdr.p_vaddr = shdr.sh_addr;
            phdr.p_paddr = shdr.sh_addr;
            phdr.p_filesz = shdr.sh_size;
            phdr.p_memsz = shdr.sh_size;
        }
    }

    // Set the TLS segment boundaries.
    // We assume TLS sections are laid out contiguously and that there is
    // a single TLS segment.
    if (self.phdr_indexes.tls.int()) |index| {
        const shdrs = slice.items(.shdr);
        const phdr = &self.phdrs.items[index];
        var shndx: u32 = 0;
        while (shndx < shdrs.len) {
            const shdr = shdrs[shndx];
            if (shdr.sh_flags & elf.SHF_TLS == 0) {
                shndx += 1;
                continue;
            }
            phdr.p_offset = shdr.sh_offset;
            phdr.p_vaddr = shdr.sh_addr;
            phdr.p_paddr = shdr.sh_addr;
            phdr.p_align = shdr.sh_addralign;
            shndx += 1;
            phdr.p_align = @max(phdr.p_align, shdr.sh_addralign);
            if (shdr.sh_type != elf.SHT_NOBITS) {
                phdr.p_filesz = shdr.sh_offset + shdr.sh_size - phdr.p_offset;
            }
            phdr.p_memsz = shdr.sh_addr + shdr.sh_size - phdr.p_vaddr;

            while (shndx < shdrs.len) : (shndx += 1) {
                const next = shdrs[shndx];
                if (next.sh_flags & elf.SHF_TLS == 0) break;
                phdr.p_align = @max(phdr.p_align, next.sh_addralign);
                if (next.sh_type != elf.SHT_NOBITS) {
                    phdr.p_filesz = next.sh_offset + next.sh_size - phdr.p_offset;
                }
                phdr.p_memsz = next.sh_addr + next.sh_size - phdr.p_vaddr;
            }
        }
    }
}

fn writeAtoms(self: *Elf) !void {
    const gpa = self.base.comp.gpa;

    var undefs = std.AutoArrayHashMap(SymbolResolver.Index, std.ArrayList(Ref)).init(gpa);
    defer {
        for (undefs.values()) |*refs| {
            refs.deinit();
        }
        undefs.deinit();
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const slice = self.sections.slice();
    var has_reloc_errors = false;
    for (slice.items(.shdr), slice.items(.atom_list_2)) |shdr, atom_list| {
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        if (atom_list.atoms.keys().len == 0) continue;
        atom_list.write(&buffer, &undefs, self) catch |err| switch (err) {
            error.UnsupportedCpuArch => {
                try self.reportUnsupportedCpuArch();
                return error.FlushFailure;
            },
            error.RelocFailure, error.RelaxFailure => has_reloc_errors = true,
            else => |e| return e,
        };
    }

    try self.reportUndefinedSymbols(&undefs);
    if (has_reloc_errors) return error.FlushFailure;

    if (self.requiresThunks()) {
        for (self.thunks.items) |th| {
            const thunk_size = th.size(self);
            try buffer.ensureUnusedCapacity(thunk_size);
            const shdr = slice.items(.shdr)[th.output_section_index];
            const offset = @as(u64, @intCast(th.value)) + shdr.sh_offset;
            try th.write(self, buffer.writer());
            assert(buffer.items.len == thunk_size);
            try self.base.file.?.pwriteAll(buffer.items, offset);
            buffer.clearRetainingCapacity();
        }
    }
}

pub fn updateSymtabSize(self: *Elf) !void {
    var nlocals: u32 = 0;
    var nglobals: u32 = 0;
    var strsize: u32 = 0;

    const gpa = self.base.comp.gpa;
    const shared_objects = self.shared_objects.values();

    var files = std.ArrayList(File.Index).init(gpa);
    defer files.deinit();
    try files.ensureTotalCapacityPrecise(self.objects.items.len + shared_objects.len + 2);

    if (self.zig_object_index) |index| files.appendAssumeCapacity(index);
    for (self.objects.items) |index| files.appendAssumeCapacity(index);
    for (shared_objects) |index| files.appendAssumeCapacity(index);
    if (self.linker_defined_index) |index| files.appendAssumeCapacity(index);

    // Section symbols
    nlocals += @intCast(self.sections.slice().len);

    if (self.requiresThunks()) for (self.thunks.items) |*th| {
        th.output_symtab_ctx.reset();
        th.output_symtab_ctx.ilocal = nlocals;
        th.calcSymtabSize(self);
        nlocals += th.output_symtab_ctx.nlocals;
        strsize += th.output_symtab_ctx.strsize;
    };

    for (files.items) |index| {
        const file_ptr = self.file(index).?;
        const ctx = switch (file_ptr) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.reset();
        ctx.ilocal = nlocals;
        ctx.iglobal = nglobals;
        try file_ptr.updateSymtabSize(self);
        nlocals += ctx.nlocals;
        nglobals += ctx.nglobals;
        strsize += ctx.strsize;
    }

    if (self.section_indexes.got) |_| {
        self.got.output_symtab_ctx.reset();
        self.got.output_symtab_ctx.ilocal = nlocals;
        self.got.updateSymtabSize(self);
        nlocals += self.got.output_symtab_ctx.nlocals;
        strsize += self.got.output_symtab_ctx.strsize;
    }

    if (self.section_indexes.plt) |_| {
        self.plt.output_symtab_ctx.reset();
        self.plt.output_symtab_ctx.ilocal = nlocals;
        self.plt.updateSymtabSize(self);
        nlocals += self.plt.output_symtab_ctx.nlocals;
        strsize += self.plt.output_symtab_ctx.strsize;
    }

    if (self.section_indexes.plt_got) |_| {
        self.plt_got.output_symtab_ctx.reset();
        self.plt_got.output_symtab_ctx.ilocal = nlocals;
        self.plt_got.updateSymtabSize(self);
        nlocals += self.plt_got.output_symtab_ctx.nlocals;
        strsize += self.plt_got.output_symtab_ctx.strsize;
    }

    for (files.items) |index| {
        const file_ptr = self.file(index).?;
        const ctx = switch (file_ptr) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.iglobal += nlocals;
    }

    const slice = self.sections.slice();
    const symtab_shdr = &slice.items(.shdr)[self.section_indexes.symtab.?];
    symtab_shdr.sh_info = nlocals;
    symtab_shdr.sh_link = self.section_indexes.strtab.?;

    const sym_size: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Sym),
        .p64 => @sizeOf(elf.Elf64_Sym),
    };
    const needed_size = (nlocals + nglobals) * sym_size;
    symtab_shdr.sh_size = needed_size;

    const strtab = &slice.items(.shdr)[self.section_indexes.strtab.?];
    strtab.sh_size = strsize + 1;
}

fn writeSyntheticSections(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const slice = self.sections.slice();

    if (self.section_indexes.interp) |shndx| {
        var buffer: [256]u8 = undefined;
        const interp = self.getTarget().dynamic_linker.get().?;
        @memcpy(buffer[0..interp.len], interp);
        buffer[interp.len] = 0;
        const contents = buffer[0 .. interp.len + 1];
        const shdr = slice.items(.shdr)[shndx];
        assert(shdr.sh_size == contents.len);
        try self.base.file.?.pwriteAll(contents, shdr.sh_offset);
    }

    if (self.section_indexes.hash) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        try self.base.file.?.pwriteAll(self.hash.buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.gnu_hash) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.gnu_hash.size());
        defer buffer.deinit();
        try self.gnu_hash.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.versym) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.versym.items), shdr.sh_offset);
    }

    if (self.section_indexes.verneed) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.verneed.size());
        defer buffer.deinit();
        try self.verneed.write(buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.dynamic) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.dynamic.size(self));
        defer buffer.deinit();
        try self.dynamic.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.dynsymtab) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.dynsym.size());
        defer buffer.deinit();
        try self.dynsym.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.dynstrtab) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        try self.base.file.?.pwriteAll(self.dynstrtab.items, shdr.sh_offset);
    }

    if (self.section_indexes.eh_frame) |shndx| {
        const existing_size = existing_size: {
            const zo = self.zigObjectPtr() orelse break :existing_size 0;
            const sym = zo.symbol(zo.eh_frame_index orelse break :existing_size 0);
            break :existing_size sym.atom(self).?.size;
        };
        const shdr = slice.items(.shdr)[shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, @intCast(sh_size - existing_size));
        defer buffer.deinit();
        try eh_frame.writeEhFrame(self, buffer.writer());
        assert(buffer.items.len == sh_size - existing_size);
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset + existing_size);
    }

    if (self.section_indexes.eh_frame_hdr) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, sh_size);
        defer buffer.deinit();
        try eh_frame.writeEhFrameHdr(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.got) |index| {
        const shdr = slice.items(.shdr)[index];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.got.size(self));
        defer buffer.deinit();
        try self.got.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.rela_dyn) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        try self.got.addRela(self);
        try self.copy_rel.addRela(self);
        self.sortRelaDyn();
        try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.rela_dyn.items), shdr.sh_offset);
    }

    if (self.section_indexes.plt) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.plt.size(self));
        defer buffer.deinit();
        try self.plt.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.got_plt) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.got_plt.size(self));
        defer buffer.deinit();
        try self.got_plt.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.plt_got) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.plt_got.size(self));
        defer buffer.deinit();
        try self.plt_got.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.section_indexes.rela_plt) |shndx| {
        const shdr = slice.items(.shdr)[shndx];
        try self.plt.addRela(self);
        try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.rela_plt.items), shdr.sh_offset);
    }

    try self.writeSymtab();
    try self.writeShStrtab();
}

// FIXME:JK again, why is this needed?
pub fn writeShStrtab(self: *Elf) !void {
    if (self.section_indexes.shstrtab) |index| {
        const shdr = self.sections.items(.shdr)[index];
        log.debug("writing .shstrtab from 0x{x} to 0x{x}", .{ shdr.sh_offset, shdr.sh_offset + shdr.sh_size });
        try self.base.file.?.pwriteAll(self.shstrtab.items, shdr.sh_offset);
    }
}

pub fn writeSymtab(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const shared_objects = self.shared_objects.values();

    const slice = self.sections.slice();
    const symtab_shdr = slice.items(.shdr)[self.section_indexes.symtab.?];
    const strtab_shdr = slice.items(.shdr)[self.section_indexes.strtab.?];
    const sym_size: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Sym),
        .p64 => @sizeOf(elf.Elf64_Sym),
    };
    const nsyms = math.cast(usize, @divExact(symtab_shdr.sh_size, sym_size)) orelse return error.Overflow;

    log.debug("writing {d} symbols in .symtab from 0x{x} to 0x{x}", .{
        nsyms,
        symtab_shdr.sh_offset,
        symtab_shdr.sh_offset + symtab_shdr.sh_size,
    });
    log.debug("writing .strtab from 0x{x} to 0x{x}", .{
        strtab_shdr.sh_offset,
        strtab_shdr.sh_offset + strtab_shdr.sh_size,
    });

    try self.symtab.resize(gpa, nsyms);
    const needed_strtab_size = math.cast(usize, strtab_shdr.sh_size - 1) orelse return error.Overflow;
    // TODO we could resize instead and in ZigObject/Object always access as slice
    self.strtab.clearRetainingCapacity();
    self.strtab.appendAssumeCapacity(0);
    try self.strtab.ensureUnusedCapacity(gpa, needed_strtab_size);

    for (slice.items(.shdr), 0..) |shdr, shndx| {
        const out_sym = &self.symtab.items[shndx];
        out_sym.* = .{
            .st_name = 0,
            .st_value = shdr.sh_addr,
            .st_info = if (shdr.sh_type == elf.SHT_NULL) elf.STT_NOTYPE else elf.STT_SECTION,
            .st_shndx = @intCast(shndx),
            .st_size = 0,
            .st_other = 0,
        };
    }

    if (self.requiresThunks()) for (self.thunks.items) |th| {
        th.writeSymtab(self);
    };

    if (self.zigObjectPtr()) |zig_object| {
        zig_object.asFile().writeSymtab(self);
    }

    for (self.objects.items) |index| {
        const file_ptr = self.file(index).?;
        file_ptr.writeSymtab(self);
    }

    for (shared_objects) |index| {
        const file_ptr = self.file(index).?;
        file_ptr.writeSymtab(self);
    }

    if (self.linkerDefinedPtr()) |obj| {
        obj.asFile().writeSymtab(self);
    }

    if (self.section_indexes.got) |_| {
        self.got.writeSymtab(self);
    }

    if (self.section_indexes.plt) |_| {
        self.plt.writeSymtab(self);
    }

    if (self.section_indexes.plt_got) |_| {
        self.plt_got.writeSymtab(self);
    }

    const foreign_endian = self.getTarget().cpu.arch.endian() != builtin.cpu.arch.endian();
    switch (self.ptr_width) {
        .p32 => {
            const buf = try gpa.alloc(elf.Elf32_Sym, self.symtab.items.len);
            defer gpa.free(buf);

            for (buf, self.symtab.items) |*out, sym| {
                out.* = .{
                    .st_name = sym.st_name,
                    .st_info = sym.st_info,
                    .st_other = sym.st_other,
                    .st_shndx = sym.st_shndx,
                    .st_value = @intCast(sym.st_value),
                    .st_size = @intCast(sym.st_size),
                };
                if (foreign_endian) mem.byteSwapAllFields(elf.Elf32_Sym, out);
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), symtab_shdr.sh_offset);
        },
        .p64 => {
            if (foreign_endian) {
                for (self.symtab.items) |*sym| mem.byteSwapAllFields(elf.Elf64_Sym, sym);
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.symtab.items), symtab_shdr.sh_offset);
        },
    }

    try self.base.file.?.pwriteAll(self.strtab.items, strtab_shdr.sh_offset);
}

/// Always 4 or 8 depending on whether this is 32-bit ELF or 64-bit ELF.
pub fn ptrWidthBytes(self: Elf) u8 {
    return switch (self.ptr_width) {
        .p32 => 4,
        .p64 => 8,
    };
}

/// Does not necessarily match `ptrWidthBytes` for example can be 2 bytes
/// in a 32-bit ELF file.
pub fn archPtrWidthBytes(self: Elf) u8 {
    return @intCast(@divExact(self.getTarget().ptrBitWidth(), 8));
}

fn phdrTo32(phdr: elf.Elf64_Phdr) elf.Elf32_Phdr {
    return .{
        .p_type = phdr.p_type,
        .p_flags = phdr.p_flags,
        .p_offset = @as(u32, @intCast(phdr.p_offset)),
        .p_vaddr = @as(u32, @intCast(phdr.p_vaddr)),
        .p_paddr = @as(u32, @intCast(phdr.p_paddr)),
        .p_filesz = @as(u32, @intCast(phdr.p_filesz)),
        .p_memsz = @as(u32, @intCast(phdr.p_memsz)),
        .p_align = @as(u32, @intCast(phdr.p_align)),
    };
}

fn shdrTo32(shdr: elf.Elf64_Shdr) elf.Elf32_Shdr {
    return .{
        .sh_name = shdr.sh_name,
        .sh_type = shdr.sh_type,
        .sh_flags = @as(u32, @intCast(shdr.sh_flags)),
        .sh_addr = @as(u32, @intCast(shdr.sh_addr)),
        .sh_offset = @as(u32, @intCast(shdr.sh_offset)),
        .sh_size = @as(u32, @intCast(shdr.sh_size)),
        .sh_link = shdr.sh_link,
        .sh_info = shdr.sh_info,
        .sh_addralign = @as(u32, @intCast(shdr.sh_addralign)),
        .sh_entsize = @as(u32, @intCast(shdr.sh_entsize)),
    };
}

fn getLDMOption(target: std.Target) ?[]const u8 {
    // This should only return emulations understood by LLD's parseEmulation().
    return switch (target.cpu.arch) {
        .aarch64 => switch (target.os.tag) {
            .linux => "aarch64linux",
            else => "aarch64elf",
        },
        .aarch64_be => switch (target.os.tag) {
            .linux => "aarch64linuxb",
            else => "aarch64elfb",
        },
        .amdgcn => "elf64_amdgpu",
        .arm, .thumb => switch (target.os.tag) {
            .linux => "armelf_linux_eabi",
            else => "armelf",
        },
        .armeb, .thumbeb => switch (target.os.tag) {
            .linux => "armelfb_linux_eabi",
            else => "armelfb",
        },
        .hexagon => "hexagonelf",
        .loongarch32 => "elf32loongarch",
        .loongarch64 => "elf64loongarch",
        .mips => switch (target.os.tag) {
            .freebsd => "elf32btsmip_fbsd",
            else => "elf32btsmip",
        },
        .mipsel => switch (target.os.tag) {
            .freebsd => "elf32ltsmip_fbsd",
            else => "elf32ltsmip",
        },
        .mips64 => switch (target.os.tag) {
            .freebsd => switch (target.abi) {
                .gnuabin32 => "elf32btsmipn32_fbsd",
                else => "elf64btsmip_fbsd",
            },
            else => switch (target.abi) {
                .gnuabin32 => "elf32btsmipn32",
                else => "elf64btsmip",
            },
        },
        .mips64el => switch (target.os.tag) {
            .freebsd => switch (target.abi) {
                .gnuabin32 => "elf32ltsmipn32_fbsd",
                else => "elf64ltsmip_fbsd",
            },
            else => switch (target.abi) {
                .gnuabin32 => "elf32ltsmipn32",
                else => "elf64ltsmip",
            },
        },
        .msp430 => "msp430elf",
        .powerpc => switch (target.os.tag) {
            .freebsd => "elf32ppc_fbsd",
            .linux => "elf32ppclinux",
            else => "elf32ppc",
        },
        .powerpcle => switch (target.os.tag) {
            .linux => "elf32lppclinux",
            else => "elf32lppc",
        },
        .powerpc64 => "elf64ppc",
        .powerpc64le => "elf64lppc",
        .riscv32 => "elf32lriscv",
        .riscv64 => "elf64lriscv",
        .s390x => "elf64_s390",
        .sparc64 => "elf64_sparc",
        .x86 => switch (target.os.tag) {
            .elfiamcu => "elf_iamcu",
            .freebsd => "elf_i386_fbsd",
            else => "elf_i386",
        },
        .x86_64 => switch (target.abi) {
            .gnux32, .muslx32 => "elf32_x86_64",
            else => "elf_x86_64",
        },
        else => null,
    };
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

/// If a target compiles other output modes as dynamic libraries,
/// this function returns true for those too.
pub fn isEffectivelyDynLib(self: Elf) bool {
    if (self.base.isDynLib()) return true;
    return switch (self.getTarget().os.tag) {
        .haiku => self.base.isExe(),
        else => false,
    };
}

fn getPhdr(self: *Elf, opts: struct {
    type: u32 = 0,
    flags: u32 = 0,
}) OptionalProgramHeaderIndex {
    for (self.phdrs.items, 0..) |phdr, phndx| {
        if (self.phdr_indexes.table_load.int()) |index| {
            if (phndx == index) continue;
        }
        if (phdr.p_type == opts.type and phdr.p_flags == opts.flags)
            return @enumFromInt(phndx);
    }
    return .none;
}

fn addPhdr(self: *Elf, opts: struct {
    type: u32 = 0,
    flags: u32 = 0,
    @"align": u64 = 0,
    offset: u64 = 0,
    addr: u64 = 0,
    filesz: u64 = 0,
    memsz: u64 = 0,
}) error{OutOfMemory}!ProgramHeaderIndex {
    const gpa = self.base.comp.gpa;
    const index: ProgramHeaderIndex = @enumFromInt(self.phdrs.items.len);
    try self.phdrs.append(gpa, .{
        .p_type = opts.type,
        .p_flags = opts.flags,
        .p_offset = opts.offset,
        .p_vaddr = opts.addr,
        .p_paddr = opts.addr,
        .p_filesz = opts.filesz,
        .p_memsz = opts.memsz,
        .p_align = opts.@"align",
    });
    return index;
}

pub fn addRelaShdr(self: *Elf, name: u32, shndx: u32) !u32 {
    const entsize: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Rela),
        .p64 => @sizeOf(elf.Elf64_Rela),
    };
    const addralign: u64 = switch (self.ptr_width) {
        .p32 => @alignOf(elf.Elf32_Rela),
        .p64 => @alignOf(elf.Elf64_Rela),
    };
    return self.addSection(.{
        .name = name,
        .type = elf.SHT_RELA,
        .flags = elf.SHF_INFO_LINK,
        .entsize = entsize,
        .info = shndx,
        .addralign = addralign,
    });
}

pub const AddSectionOpts = struct {
    name: u32 = 0,
    type: u32 = elf.SHT_NULL,
    flags: u64 = 0,
    link: u32 = 0,
    info: u32 = 0,
    addralign: u64 = 0,
    entsize: u64 = 0,
};

pub fn addSection(self: *Elf, opts: AddSectionOpts) !u32 {
    const gpa = self.base.comp.gpa;
    const index: u32 = @intCast(try self.sections.addOne(gpa));
    self.sections.set(index, .{
        .shdr = .{
            .sh_name = opts.name,
            .sh_type = opts.type,
            .sh_flags = opts.flags,
            .sh_addr = 0,
            .sh_offset = 0,
            .sh_size = 0,
            .sh_link = opts.link,
            .sh_info = opts.info,
            .sh_addralign = opts.addralign,
            .sh_entsize = opts.entsize,
        },
    });
    return index;
}

pub fn sectionByName(self: *Elf, name: [:0]const u8) ?u32 {
    for (self.sections.items(.shdr), 0..) |*shdr, i| {
        const this_name = self.getShString(shdr.sh_name);
        if (mem.eql(u8, this_name, name)) return @intCast(i);
    } else return null;
}

const RelaDyn = struct {
    offset: u64,
    sym: u64 = 0,
    type: u32,
    addend: i64 = 0,
    target: ?*const Symbol = null,
};

pub fn addRelaDyn(self: *Elf, opts: RelaDyn) !void {
    try self.rela_dyn.ensureUnusedCapacity(self.base.alloctor, 1);
    self.addRelaDynAssumeCapacity(opts);
}

pub fn addRelaDynAssumeCapacity(self: *Elf, opts: RelaDyn) void {
    relocs_log.debug("  {s}: [{x} => {d}({s})] + {x}", .{
        relocation.fmtRelocType(opts.type, self.getTarget().cpu.arch),
        opts.offset,
        opts.sym,
        if (opts.target) |sym| sym.name(self) else "",
        opts.addend,
    });
    self.rela_dyn.appendAssumeCapacity(.{
        .r_offset = opts.offset,
        .r_info = (opts.sym << 32) | opts.type,
        .r_addend = opts.addend,
    });
}

fn sortRelaDyn(self: *Elf) void {
    const Sort = struct {
        fn rank(rel: elf.Elf64_Rela, ctx: *Elf) u2 {
            const cpu_arch = ctx.getTarget().cpu.arch;
            const r_type = rel.r_type();
            const r_kind = relocation.decode(r_type, cpu_arch).?;
            return switch (r_kind) {
                .rel => 0,
                .irel => 2,
                else => 1,
            };
        }

        pub fn lessThan(ctx: *Elf, lhs: elf.Elf64_Rela, rhs: elf.Elf64_Rela) bool {
            if (rank(lhs, ctx) == rank(rhs, ctx)) {
                if (lhs.r_sym() == rhs.r_sym()) return lhs.r_offset < rhs.r_offset;
                return lhs.r_sym() < rhs.r_sym();
            }
            return rank(lhs, ctx) < rank(rhs, ctx);
        }
    };
    mem.sort(elf.Elf64_Rela, self.rela_dyn.items, self, Sort.lessThan);
}

pub fn calcNumIRelativeRelocs(self: *Elf) usize {
    var count: usize = self.num_ifunc_dynrelocs;

    for (self.got.entries.items) |entry| {
        if (entry.tag != .got) continue;
        const sym = self.symbol(entry.ref).?;
        if (sym.isIFunc(self)) count += 1;
    }

    return count;
}

pub fn getStartStopBasename(self: Elf, shdr: elf.Elf64_Shdr) ?[]const u8 {
    const name = self.getShString(shdr.sh_name);
    if (shdr.sh_flags & elf.SHF_ALLOC != 0 and name.len > 0) {
        if (Elf.isCIdentifier(name)) return name;
    }
    return null;
}

pub fn isCIdentifier(name: []const u8) bool {
    if (name.len == 0) return false;
    const first_c = name[0];
    if (!std.ascii.isAlphabetic(first_c) and first_c != '_') return false;
    for (name[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') return false;
    }
    return true;
}

pub fn addThunk(self: *Elf) !Thunk.Index {
    const index = @as(Thunk.Index, @intCast(self.thunks.items.len));
    const th = try self.thunks.addOne(self.base.comp.gpa);
    th.* = .{};
    return index;
}

pub fn thunk(self: *Elf, index: Thunk.Index) *Thunk {
    assert(index < self.thunks.items.len);
    return &self.thunks.items[index];
}

pub fn file(self: *Elf, index: File.Index) ?File {
    return fileLookup(self.files, index);
}

fn fileLookup(files: std.MultiArrayList(File.Entry), index: File.Index) ?File {
    const tag = files.items(.tags)[index];
    return switch (tag) {
        .null => null,
        .linker_defined => .{ .linker_defined = &files.items(.data)[index].linker_defined },
        .zig_object => .{ .zig_object = &files.items(.data)[index].zig_object },
        .object => .{ .object = &files.items(.data)[index].object },
        .shared_object => .{ .shared_object = &files.items(.data)[index].shared_object },
    };
}

pub fn addFileHandle(self: *Elf, handle: fs.File) !File.HandleIndex {
    const gpa = self.base.comp.gpa;
    const index: File.HandleIndex = @intCast(self.file_handles.items.len);
    const fh = try self.file_handles.addOne(gpa);
    fh.* = handle;
    return index;
}

pub fn fileHandle(self: Elf, index: File.HandleIndex) File.Handle {
    assert(index < self.file_handles.items.len);
    return self.file_handles.items[index];
}

pub fn atom(self: *Elf, ref: Ref) ?*Atom {
    const file_ptr = self.file(ref.file) orelse return null;
    return file_ptr.atom(ref.index);
}

pub fn comdatGroup(self: *Elf, ref: Ref) *ComdatGroup {
    return self.file(ref.file).?.comdatGroup(ref.index);
}

pub fn symbol(self: *Elf, ref: Ref) ?*Symbol {
    const file_ptr = self.file(ref.file) orelse return null;
    return file_ptr.symbol(ref.index);
}

pub fn getGlobalSymbol(self: *Elf, name: []const u8, lib_name: ?[]const u8) !u32 {
    return self.zigObjectPtr().?.getGlobalSymbol(self, name, lib_name);
}

pub fn zigObjectPtr(self: *Elf) ?*ZigObject {
    const index = self.zig_object_index orelse return null;
    return self.file(index).?.zig_object;
}

pub fn linkerDefinedPtr(self: *Elf) ?*LinkerDefined {
    const index = self.linker_defined_index orelse return null;
    return self.file(index).?.linker_defined;
}

pub fn getOrCreateMergeSection(self: *Elf, name: [:0]const u8, flags: u64, @"type": u32) !Merge.Section.Index {
    const gpa = self.base.comp.gpa;
    const out_name = name: {
        if (self.base.isRelocatable()) break :name name;
        if (mem.eql(u8, name, ".rodata") or mem.startsWith(u8, name, ".rodata"))
            break :name if (flags & elf.SHF_STRINGS != 0) ".rodata.str" else ".rodata.cst";
        break :name name;
    };
    for (self.merge_sections.items, 0..) |msec, index| {
        if (mem.eql(u8, msec.name(self), out_name)) return @intCast(index);
    }
    const out_off = try self.insertShString(out_name);
    const out_flags = flags & ~@as(u64, elf.SHF_COMPRESSED | elf.SHF_GROUP);
    const index: Merge.Section.Index = @intCast(self.merge_sections.items.len);
    const msec = try self.merge_sections.addOne(gpa);
    msec.* = .{
        .name_offset = out_off,
        .flags = out_flags,
        .type = @"type",
    };
    return index;
}

pub fn mergeSection(self: *Elf, index: Merge.Section.Index) *Merge.Section {
    assert(index < self.merge_sections.items.len);
    return &self.merge_sections.items[index];
}

pub fn gotAddress(self: *Elf) i64 {
    const shndx = blk: {
        if (self.getTarget().cpu.arch == .x86_64 and self.section_indexes.got_plt != null)
            break :blk self.section_indexes.got_plt.?;
        break :blk if (self.section_indexes.got) |shndx| shndx else null;
    };
    return if (shndx) |index| @intCast(self.sections.items(.shdr)[index].sh_addr) else 0;
}

pub fn tpAddress(self: *Elf) i64 {
    const index = self.phdr_indexes.tls.int() orelse return 0;
    const phdr = self.phdrs.items[index];
    const addr = switch (self.getTarget().cpu.arch) {
        .x86_64 => mem.alignForward(u64, phdr.p_vaddr + phdr.p_memsz, phdr.p_align),
        .aarch64 => mem.alignBackward(u64, phdr.p_vaddr - 16, phdr.p_align),
        .riscv64 => phdr.p_vaddr,
        else => |arch| std.debug.panic("TODO implement getTpAddress for {s}", .{@tagName(arch)}),
    };
    return @intCast(addr);
}

pub fn dtpAddress(self: *Elf) i64 {
    const index = self.phdr_indexes.tls.int() orelse return 0;
    const phdr = self.phdrs.items[index];
    return @intCast(phdr.p_vaddr);
}

pub fn tlsAddress(self: *Elf) i64 {
    const index = self.phdr_indexes.tls.int() orelse return 0;
    const phdr = self.phdrs.items[index];
    return @intCast(phdr.p_vaddr);
}

pub fn getShString(self: Elf, off: u32) [:0]const u8 {
    return shString(self.shstrtab.items, off);
}

fn shString(
    shstrtab: []const u8,
    off: u32,
) [:0]const u8 {
    const slice = shstrtab[off..];
    return slice[0..std.mem.indexOfScalar(u8, slice, 0).? :0];
}

pub fn insertShString(self: *Elf, name: [:0]const u8) error{OutOfMemory}!u32 {
    const gpa = self.base.comp.gpa;
    const off = @as(u32, @intCast(self.shstrtab.items.len));
    try self.shstrtab.ensureUnusedCapacity(gpa, name.len + 1);
    self.shstrtab.writer(gpa).print("{s}\x00", .{name}) catch unreachable;
    return off;
}

pub fn getDynString(self: Elf, off: u32) [:0]const u8 {
    assert(off < self.dynstrtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.dynstrtab.items.ptr + off)), 0);
}

pub fn insertDynString(self: *Elf, name: []const u8) error{OutOfMemory}!u32 {
    const gpa = self.base.comp.gpa;
    const off = @as(u32, @intCast(self.dynstrtab.items.len));
    try self.dynstrtab.ensureUnusedCapacity(gpa, name.len + 1);
    self.dynstrtab.writer(gpa).print("{s}\x00", .{name}) catch unreachable;
    return off;
}

fn reportUndefinedSymbols(self: *Elf, undefs: anytype) !void {
    const gpa = self.base.comp.gpa;
    const diags = &self.base.comp.link_diags;
    const max_notes = 4;

    try diags.msgs.ensureUnusedCapacity(gpa, undefs.count());

    for (undefs.keys(), undefs.values()) |key, refs| {
        const undef_sym = self.resolver.keys.items[key - 1];
        const nrefs = @min(refs.items.len, max_notes);
        const nnotes = nrefs + @intFromBool(refs.items.len > max_notes);

        var err = try diags.addErrorWithNotesAssumeCapacity(nnotes);
        try err.addMsg("undefined symbol: {s}", .{undef_sym.name(self)});

        for (refs.items[0..nrefs]) |ref| {
            const atom_ptr = self.atom(ref).?;
            const file_ptr = atom_ptr.file(self).?;
            try err.addNote("referenced by {s}:{s}", .{ file_ptr.fmtPath(), atom_ptr.name(self) });
        }

        if (refs.items.len > max_notes) {
            const remaining = refs.items.len - max_notes;
            try err.addNote("referenced {d} more times", .{remaining});
        }
    }
}

fn reportDuplicates(self: *Elf, dupes: anytype) error{ HasDuplicates, OutOfMemory }!void {
    if (dupes.keys().len == 0) return; // Nothing to do
    const diags = &self.base.comp.link_diags;

    const max_notes = 3;

    for (dupes.keys(), dupes.values()) |key, notes| {
        const sym = self.resolver.keys.items[key - 1];
        const nnotes = @min(notes.items.len, max_notes) + @intFromBool(notes.items.len > max_notes);

        var err = try diags.addErrorWithNotes(nnotes + 1);
        try err.addMsg("duplicate symbol definition: {s}", .{sym.name(self)});
        try err.addNote("defined by {}", .{sym.file(self).?.fmtPath()});

        var inote: usize = 0;
        while (inote < @min(notes.items.len, max_notes)) : (inote += 1) {
            const file_ptr = self.file(notes.items[inote]).?;
            try err.addNote("defined by {}", .{file_ptr.fmtPath()});
        }

        if (notes.items.len > max_notes) {
            const remaining = notes.items.len - max_notes;
            try err.addNote("defined {d} more times", .{remaining});
        }
    }

    return error.HasDuplicates;
}

fn reportUnsupportedCpuArch(self: *Elf) error{OutOfMemory}!void {
    const diags = &self.base.comp.link_diags;
    var err = try diags.addErrorWithNotes(0);
    try err.addMsg("fatal linker error: unsupported CPU architecture {s}", .{
        @tagName(self.getTarget().cpu.arch),
    });
}

pub fn addFileError(
    self: *Elf,
    file_index: File.Index,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    const diags = &self.base.comp.link_diags;
    var err = try diags.addErrorWithNotes(1);
    try err.addMsg(format, args);
    try err.addNote("while parsing {}", .{self.file(file_index).?.fmtPath()});
}

pub fn failFile(
    self: *Elf,
    file_index: File.Index,
    comptime format: []const u8,
    args: anytype,
) error{ OutOfMemory, LinkFailure } {
    try addFileError(self, file_index, format, args);
    return error.LinkFailure;
}

const FormatShdrCtx = struct {
    elf_file: *Elf,
    shdr: elf.Elf64_Shdr,
};

fn fmtShdr(self: *Elf, shdr: elf.Elf64_Shdr) std.fmt.Formatter(formatShdr) {
    return .{ .data = .{
        .shdr = shdr,
        .elf_file = self,
    } };
}

fn formatShdr(
    ctx: FormatShdrCtx,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const shdr = ctx.shdr;
    try writer.print("{s} : @{x} ({x}) : align({x}) : size({x}) : entsize({x}) : flags({})", .{
        ctx.elf_file.getShString(shdr.sh_name), shdr.sh_offset,
        shdr.sh_addr,                           shdr.sh_addralign,
        shdr.sh_size,                           shdr.sh_entsize,
        fmtShdrFlags(shdr.sh_flags),
    });
}

pub fn fmtShdrFlags(sh_flags: u64) std.fmt.Formatter(formatShdrFlags) {
    return .{ .data = sh_flags };
}

fn formatShdrFlags(
    sh_flags: u64,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    if (elf.SHF_WRITE & sh_flags != 0) {
        try writer.writeAll("W");
    }
    if (elf.SHF_ALLOC & sh_flags != 0) {
        try writer.writeAll("A");
    }
    if (elf.SHF_EXECINSTR & sh_flags != 0) {
        try writer.writeAll("X");
    }
    if (elf.SHF_MERGE & sh_flags != 0) {
        try writer.writeAll("M");
    }
    if (elf.SHF_STRINGS & sh_flags != 0) {
        try writer.writeAll("S");
    }
    if (elf.SHF_INFO_LINK & sh_flags != 0) {
        try writer.writeAll("I");
    }
    if (elf.SHF_LINK_ORDER & sh_flags != 0) {
        try writer.writeAll("L");
    }
    if (elf.SHF_EXCLUDE & sh_flags != 0) {
        try writer.writeAll("E");
    }
    if (elf.SHF_COMPRESSED & sh_flags != 0) {
        try writer.writeAll("C");
    }
    if (elf.SHF_GROUP & sh_flags != 0) {
        try writer.writeAll("G");
    }
    if (elf.SHF_OS_NONCONFORMING & sh_flags != 0) {
        try writer.writeAll("O");
    }
    if (elf.SHF_TLS & sh_flags != 0) {
        try writer.writeAll("T");
    }
    if (elf.SHF_X86_64_LARGE & sh_flags != 0) {
        try writer.writeAll("l");
    }
    if (elf.SHF_MIPS_ADDR & sh_flags != 0 or elf.SHF_ARM_PURECODE & sh_flags != 0) {
        try writer.writeAll("p");
    }
}

const FormatPhdrCtx = struct {
    elf_file: *Elf,
    phdr: elf.Elf64_Phdr,
};

fn fmtPhdr(self: *Elf, phdr: elf.Elf64_Phdr) std.fmt.Formatter(formatPhdr) {
    return .{ .data = .{
        .phdr = phdr,
        .elf_file = self,
    } };
}

fn formatPhdr(
    ctx: FormatPhdrCtx,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = unused_fmt_string;
    const phdr = ctx.phdr;
    const write = phdr.p_flags & elf.PF_W != 0;
    const read = phdr.p_flags & elf.PF_R != 0;
    const exec = phdr.p_flags & elf.PF_X != 0;
    var flags: [3]u8 = [_]u8{'_'} ** 3;
    if (exec) flags[0] = 'X';
    if (write) flags[1] = 'W';
    if (read) flags[2] = 'R';
    const p_type = switch (phdr.p_type) {
        elf.PT_LOAD => "LOAD",
        elf.PT_TLS => "TLS",
        elf.PT_GNU_EH_FRAME => "GNU_EH_FRAME",
        elf.PT_GNU_STACK => "GNU_STACK",
        elf.PT_DYNAMIC => "DYNAMIC",
        elf.PT_INTERP => "INTERP",
        elf.PT_NULL => "NULL",
        elf.PT_PHDR => "PHDR",
        elf.PT_NOTE => "NOTE",
        else => "UNKNOWN",
    };
    try writer.print("{s} : {s} : @{x} ({x}) : align({x}) : filesz({x}) : memsz({x})", .{
        p_type,       flags,         phdr.p_offset, phdr.p_vaddr,
        phdr.p_align, phdr.p_filesz, phdr.p_memsz,
    });
}

pub fn dumpState(self: *Elf) std.fmt.Formatter(fmtDumpState) {
    return .{ .data = self };
}

fn fmtDumpState(
    self: *Elf,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;

    const shared_objects = self.shared_objects.values();

    if (self.zigObjectPtr()) |zig_object| {
        try writer.print("zig_object({d}) : {s}\n", .{ zig_object.index, zig_object.basename });
        try writer.print("{}{}", .{
            zig_object.fmtAtoms(self),
            zig_object.fmtSymtab(self),
        });
        try writer.writeByte('\n');
    }

    for (self.objects.items) |index| {
        const object = self.file(index).?.object;
        try writer.print("object({d}) : {}", .{ index, object.fmtPath() });
        if (!object.alive) try writer.writeAll(" : [*]");
        try writer.writeByte('\n');
        try writer.print("{}{}{}{}{}\n", .{
            object.fmtAtoms(self),
            object.fmtCies(self),
            object.fmtFdes(self),
            object.fmtSymtab(self),
            object.fmtComdatGroups(self),
        });
    }

    for (shared_objects) |index| {
        const shared_object = self.file(index).?.shared_object;
        try writer.print("shared_object({d}) : {} : needed({})", .{
            index, shared_object.path, shared_object.needed,
        });
        if (!shared_object.alive) try writer.writeAll(" : [*]");
        try writer.writeByte('\n');
        try writer.print("{}\n", .{shared_object.fmtSymtab(self)});
    }

    if (self.linker_defined_index) |index| {
        const linker_defined = self.file(index).?.linker_defined;
        try writer.print("linker_defined({d}) : (linker defined)\n", .{index});
        try writer.print("{}\n", .{linker_defined.fmtSymtab(self)});
    }

    const slice = self.sections.slice();
    {
        try writer.writeAll("atom lists\n");
        for (slice.items(.shdr), slice.items(.atom_list_2), 0..) |shdr, atom_list, shndx| {
            try writer.print("shdr({d}) : {s} : {}\n", .{ shndx, self.getShString(shdr.sh_name), atom_list.fmt(self) });
        }
    }

    if (self.requiresThunks()) {
        try writer.writeAll("thunks\n");
        for (self.thunks.items, 0..) |th, index| {
            try writer.print("thunk({d}) : {}\n", .{ index, th.fmt(self) });
        }
    }

    try writer.print("{}\n", .{self.got.fmt(self)});
    try writer.print("{}\n", .{self.plt.fmt(self)});

    try writer.writeAll("Output COMDAT groups\n");
    for (self.comdat_group_sections.items) |cg| {
        try writer.print("  shdr({d}) : COMDAT({})\n", .{ cg.shndx, cg.cg_ref });
    }

    try writer.writeAll("\nOutput merge sections\n");
    for (self.merge_sections.items) |msec| {
        try writer.print("  shdr({d}) : {}\n", .{ msec.output_section_index, msec.fmt(self) });
    }

    try writer.writeAll("\nOutput shdrs\n");
    for (slice.items(.shdr), slice.items(.phndx), 0..) |shdr, phndx, shndx| {
        try writer.print("  shdr({d}) : phdr({?d}) : {}\n", .{
            shndx,
            phndx,
            self.fmtShdr(shdr),
        });
    }
    try writer.writeAll("\nOutput phdrs\n");
    for (self.phdrs.items, 0..) |phdr, phndx| {
        try writer.print("  phdr({d}) : {}\n", .{ phndx, self.fmtPhdr(phdr) });
    }
}

/// Caller owns the memory.
pub fn preadAllAlloc(allocator: Allocator, handle: fs.File, offset: u64, size: u64) ![]u8 {
    const buffer = try allocator.alloc(u8, math.cast(usize, size) orelse return error.Overflow);
    errdefer allocator.free(buffer);
    const amt = try handle.preadAll(buffer, offset);
    if (amt != size) return error.InputOutput;
    return buffer;
}

/// Binary search
pub fn bsearch(comptime T: type, haystack: []const T, predicate: anytype) usize {
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
pub fn lsearch(comptime T: type, haystack: []const T, predicate: anytype) usize {
    var i: usize = 0;
    while (i < haystack.len) : (i += 1) {
        if (predicate.predicate(haystack[i])) break;
    }
    return i;
}

pub fn getTarget(self: Elf) std.Target {
    return self.base.comp.root_mod.resolved_target.result;
}

fn requiresThunks(self: Elf) bool {
    return switch (self.getTarget().cpu.arch) {
        .aarch64 => true,
        .x86_64, .riscv64 => false,
        else => @panic("TODO unimplemented architecture"),
    };
}

/// The following three values are only observed at compile-time and used to emit a compile error
/// to remind the programmer to update expected maximum numbers of different program header types
/// so that we reserve enough space for the program header table up-front.
/// Bump these numbers when adding or deleting a Zig specific pre-allocated segment, or adding
/// more special-purpose program headers.
const max_number_of_object_segments = 9;
const max_number_of_special_phdrs = 5;

const default_entry_addr = 0x8000000;

pub const base_tag: link.File.Tag = .elf;

pub const ComdatGroup = struct {
    signature_off: u32,
    file_index: File.Index,
    shndx: u32,
    members_start: u32,
    members_len: u32,
    alive: bool = true,

    pub fn file(cg: ComdatGroup, elf_file: *Elf) File {
        return elf_file.file(cg.file_index).?;
    }

    pub fn signature(cg: ComdatGroup, elf_file: *Elf) [:0]const u8 {
        return cg.file(elf_file).object.getString(cg.signature_off);
    }

    pub fn comdatGroupMembers(cg: ComdatGroup, elf_file: *Elf) []const u32 {
        const object = cg.file(elf_file).object;
        return object.comdat_group_data.items[cg.members_start..][0..cg.members_len];
    }

    pub const Index = u32;
};

pub const SymtabCtx = struct {
    ilocal: u32 = 0,
    iglobal: u32 = 0,
    nlocals: u32 = 0,
    nglobals: u32 = 0,
    strsize: u32 = 0,

    pub fn reset(ctx: *SymtabCtx) void {
        ctx.ilocal = 0;
        ctx.iglobal = 0;
        ctx.nlocals = 0;
        ctx.nglobals = 0;
        ctx.strsize = 0;
    }
};

pub const null_sym = elf.Elf64_Sym{
    .st_name = 0,
    .st_info = 0,
    .st_other = 0,
    .st_shndx = 0,
    .st_value = 0,
    .st_size = 0,
};

pub const null_shdr = elf.Elf64_Shdr{
    .sh_name = 0,
    .sh_type = 0,
    .sh_flags = 0,
    .sh_addr = 0,
    .sh_offset = 0,
    .sh_size = 0,
    .sh_link = 0,
    .sh_info = 0,
    .sh_addralign = 0,
    .sh_entsize = 0,
};

pub const SystemLib = struct {
    needed: bool = false,
    path: Path,
};

pub const Ref = struct {
    index: u32 = 0,
    file: u32 = 0,

    pub fn eql(ref: Ref, other: Ref) bool {
        return ref.index == other.index and ref.file == other.file;
    }

    pub fn format(
        ref: Ref,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("ref({},{})", .{ ref.index, ref.file });
    }
};

pub const SymbolResolver = struct {
    keys: std.ArrayListUnmanaged(Key) = .empty,
    values: std.ArrayListUnmanaged(Ref) = .empty,
    table: std.AutoArrayHashMapUnmanaged(void, void) = .empty,

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
        elf_file: *Elf,
    ) !Result {
        const adapter = Adapter{ .keys = resolver.keys.items, .elf_file = elf_file };
        const key = Key{ .index = ref.index, .file_index = ref.file };
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
        file_index: File.Index,

        fn name(key: Key, elf_file: *Elf) [:0]const u8 {
            const ref = Ref{ .index = key.index, .file = key.file_index };
            return elf_file.symbol(ref).?.name(elf_file);
        }

        fn file(key: Key, elf_file: *Elf) ?File {
            return elf_file.file(key.file_index);
        }

        fn eql(key: Key, other: Key, elf_file: *Elf) bool {
            const key_name = key.name(elf_file);
            const other_name = other.name(elf_file);
            return mem.eql(u8, key_name, other_name);
        }

        fn hash(key: Key, elf_file: *Elf) u32 {
            return @truncate(Hash.hash(0, key.name(elf_file)));
        }
    };

    const Adapter = struct {
        keys: []const Key,
        elf_file: *Elf,

        pub fn eql(ctx: @This(), key: Key, b_void: void, b_map_index: usize) bool {
            _ = b_void;
            const other = ctx.keys[b_map_index];
            return key.eql(other, ctx.elf_file);
        }

        pub fn hash(ctx: @This(), key: Key) u32 {
            return key.hash(ctx.elf_file);
        }
    };

    pub const Index = u32;
};

const Section = struct {
    /// Section header.
    shdr: elf.Elf64_Shdr,

    /// Assigned program header index if any.
    phndx: OptionalProgramHeaderIndex = .none,

    /// List of atoms contributing to this section.
    /// TODO currently this is only used for relocations tracking in relocatable mode
    /// but will be merged with atom_list_2.
    atom_list: std.ArrayListUnmanaged(Ref) = .empty,

    /// List of atoms contributing to this section.
    /// This can be used by sections that require special handling such as init/fini array, etc.
    atom_list_2: AtomList = .{},

    /// Index of the last allocated atom in this section.
    last_atom: Ref = .{ .index = 0, .file = 0 },

    /// A list of atoms that have surplus capacity. This list can have false
    /// positives, as functions grow and shrink over time, only sometimes being added
    /// or removed from the freelist.
    ///
    /// An atom has surplus capacity when its overcapacity value is greater than
    /// padToIdeal(minimum_atom_size). That is, when it has so
    /// much extra capacity, that we could fit a small new symbol in it, itself with
    /// ideal_capacity or more.
    ///
    /// Ideal capacity is defined by size + (size / ideal_factor)
    ///
    /// Overcapacity is measured by actual_capacity - ideal_capacity. Note that
    /// overcapacity can be negative. A simple way to have negative overcapacity is to
    /// allocate a fresh text block, which will have ideal capacity, and then grow it
    /// by 1 byte. It will then have -1 overcapacity.
    free_list: std.ArrayListUnmanaged(Ref) = .empty,
};

pub fn sectionSize(self: *Elf, shndx: u32) u64 {
    const last_atom_ref = self.sections.items(.last_atom)[shndx];
    const atom_ptr = self.atom(last_atom_ref) orelse return 0;
    return @as(u64, @intCast(atom_ptr.value)) + atom_ptr.size;
}

fn defaultEntrySymbolName(cpu_arch: std.Target.Cpu.Arch) []const u8 {
    return switch (cpu_arch) {
        .mips, .mipsel, .mips64, .mips64el => "__start",
        else => "_start",
    };
}

fn createThunks(elf_file: *Elf, atom_list: *AtomList) !void {
    const gpa = elf_file.base.comp.gpa;
    const cpu_arch = elf_file.getTarget().cpu.arch;

    // A branch will need an extender if its target is larger than
    // `2^(jump_bits - 1) - margin` where margin is some arbitrary number.
    const max_distance = switch (cpu_arch) {
        .aarch64 => 0x500_000,
        .x86_64, .riscv64 => unreachable,
        else => @panic("unhandled arch"),
    };

    const advance = struct {
        fn advance(list: *AtomList, size: u64, alignment: Atom.Alignment) !i64 {
            const offset = alignment.forward(list.size);
            const padding = offset - list.size;
            list.size += padding + size;
            list.alignment = list.alignment.max(alignment);
            return @intCast(offset);
        }
    }.advance;

    for (atom_list.atoms.keys()) |ref| {
        elf_file.atom(ref).?.value = -1;
    }

    var i: usize = 0;
    while (i < atom_list.atoms.keys().len) {
        const start = i;
        const start_atom = elf_file.atom(atom_list.atoms.keys()[start]).?;
        assert(start_atom.alive);
        start_atom.value = try advance(atom_list, start_atom.size, start_atom.alignment);
        i += 1;

        while (i < atom_list.atoms.keys().len) : (i += 1) {
            const atom_ptr = elf_file.atom(atom_list.atoms.keys()[i]).?;
            assert(atom_ptr.alive);
            if (@as(i64, @intCast(atom_ptr.alignment.forward(atom_list.size))) - start_atom.value >= max_distance)
                break;
            atom_ptr.value = try advance(atom_list, atom_ptr.size, atom_ptr.alignment);
        }

        // Insert a thunk at the group end
        const thunk_index = try elf_file.addThunk();
        const thunk_ptr = elf_file.thunk(thunk_index);
        thunk_ptr.output_section_index = atom_list.output_section_index;

        // Scan relocs in the group and create trampolines for any unreachable callsite
        for (atom_list.atoms.keys()[start..i]) |ref| {
            const atom_ptr = elf_file.atom(ref).?;
            const file_ptr = atom_ptr.file(elf_file).?;
            log.debug("atom({}) {s}", .{ ref, atom_ptr.name(elf_file) });
            for (atom_ptr.relocs(elf_file)) |rel| {
                const is_reachable = switch (cpu_arch) {
                    .aarch64 => r: {
                        const r_type: elf.R_AARCH64 = @enumFromInt(rel.r_type());
                        if (r_type != .CALL26 and r_type != .JUMP26) break :r true;
                        const target_ref = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
                        const target = elf_file.symbol(target_ref).?;
                        if (target.flags.has_plt) break :r false;
                        if (atom_ptr.output_section_index != target.output_section_index) break :r false;
                        const target_atom = target.atom(elf_file).?;
                        if (target_atom.value == -1) break :r false;
                        const saddr = atom_ptr.address(elf_file) + @as(i64, @intCast(rel.r_offset));
                        const taddr = target.address(.{}, elf_file);
                        _ = math.cast(i28, taddr + rel.r_addend - saddr) orelse break :r false;
                        break :r true;
                    },
                    .x86_64, .riscv64 => unreachable,
                    else => @panic("unsupported arch"),
                };
                if (is_reachable) continue;
                const target = file_ptr.resolveSymbol(rel.r_sym(), elf_file);
                try thunk_ptr.symbols.put(gpa, target, {});
            }
            atom_ptr.addExtra(.{ .thunk = thunk_index }, elf_file);
        }

        thunk_ptr.value = try advance(atom_list, thunk_ptr.size(elf_file), Atom.Alignment.fromNonzeroByteUnits(2));

        log.debug("thunk({d}) : {}", .{ thunk_index, thunk_ptr.fmt(elf_file) });
    }
}

pub fn stringTableLookup(strtab: []const u8, off: u32) [:0]const u8 {
    const slice = strtab[off..];
    return slice[0..mem.indexOfScalar(u8, slice, 0).? :0];
}

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const elf = std.elf;
const fs = std.fs;
const log = std.log.scoped(.link);
const relocs_log = std.log.scoped(.link_relocs);
const state_log = std.log.scoped(.link_state);
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Hash = std.hash.Wyhash;
const Path = std.Build.Cache.Path;
const Stat = std.Build.Cache.File.Stat;

const codegen = @import("../codegen.zig");
const dev = @import("../dev.zig");
const eh_frame = @import("Elf/eh_frame.zig");
const gc = @import("Elf/gc.zig");
const glibc = @import("../glibc.zig");
const link = @import("../link.zig");
const musl = @import("../musl.zig");
const relocatable = @import("Elf/relocatable.zig");
const relocation = @import("Elf/relocation.zig");
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;
const synthetic_sections = @import("Elf/synthetic_sections.zig");

const Merge = @import("Elf/Merge.zig");
const Air = @import("../Air.zig");
const Archive = @import("Elf/Archive.zig");
const AtomList = @import("Elf/AtomList.zig");
const Compilation = @import("../Compilation.zig");
const ComdatGroupSection = synthetic_sections.ComdatGroupSection;
const CopyRelSection = synthetic_sections.CopyRelSection;
const Diags = @import("../link.zig").Diags;
const DynamicSection = synthetic_sections.DynamicSection;
const DynsymSection = synthetic_sections.DynsymSection;
const Dwarf = @import("Dwarf.zig");
const Elf = @This();
const File = @import("Elf/file.zig").File;
const GnuHashSection = synthetic_sections.GnuHashSection;
const GotSection = synthetic_sections.GotSection;
const GotPltSection = synthetic_sections.GotPltSection;
const HashSection = synthetic_sections.HashSection;
const LdScript = @import("Elf/LdScript.zig");
const LinkerDefined = @import("Elf/LinkerDefined.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Zcu = @import("../Zcu.zig");
const Object = @import("Elf/Object.zig");
const InternPool = @import("../InternPool.zig");
const PltSection = synthetic_sections.PltSection;
const PltGotSection = synthetic_sections.PltGotSection;
const SharedObject = @import("Elf/SharedObject.zig");
const Symbol = @import("Elf/Symbol.zig");
const StringTable = @import("StringTable.zig");
const Thunk = @import("Elf/Thunk.zig");
const Value = @import("../Value.zig");
const VerneedSection = synthetic_sections.VerneedSection;
const ZigObject = @import("Elf/ZigObject.zig");
const riscv = @import("riscv.zig");
