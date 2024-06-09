base: link.File,
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
llvm_object: ?*LlvmObject = null,

/// A list of all input files.
/// Index of each input file also encodes the priority or precedence of one input file
/// over another.
files: std.MultiArrayList(File.Entry) = .{},
/// Long-lived list of all file descriptors.
/// We store them globally rather than per actual File so that we can re-use
/// one file handle per every object file within an archive.
file_handles: std.ArrayListUnmanaged(File.Handle) = .{},
zig_object_index: ?File.Index = null,
linker_defined_index: ?File.Index = null,
objects: std.ArrayListUnmanaged(File.Index) = .{},
shared_objects: std.ArrayListUnmanaged(File.Index) = .{},

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
shdrs: std.ArrayListUnmanaged(elf.Elf64_Shdr) = .{},
/// Given index to a section, pulls index of containing phdr if any.
phdr_to_shdr_table: std.AutoHashMapUnmanaged(u32, u32) = .{},
/// File offset into the shdr table.
shdr_table_offset: ?u64 = null,
/// Table of lists of atoms per output section.
/// This table is not used to track incrementally generated atoms.
output_sections: std.AutoArrayHashMapUnmanaged(u32, std.ArrayListUnmanaged(Atom.Index)) = .{},
output_rela_sections: std.AutoArrayHashMapUnmanaged(u32, RelaSection) = .{},

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
phdrs: std.ArrayListUnmanaged(elf.Elf64_Phdr) = .{},

/// Tracked loadable segments during incremental linking.
/// The index into the program headers of a PT_LOAD program header with Read and Execute flags
phdr_zig_load_re_index: ?u16 = null,
/// The index into the program headers of the global offset table.
/// It needs PT_LOAD and Read flags.
phdr_zig_got_index: ?u16 = null,
/// The index into the program headers of a PT_LOAD program header with Read flag
phdr_zig_load_ro_index: ?u16 = null,
/// The index into the program headers of a PT_LOAD program header with Write flag
phdr_zig_load_rw_index: ?u16 = null,
/// The index into the program headers of a PT_LOAD program header with zerofill data.
phdr_zig_load_zerofill_index: ?u16 = null,

/// Special program headers
/// PT_PHDR
phdr_table_index: ?u16 = null,
/// PT_LOAD for PHDR table
/// We add this special load segment to ensure the EHDR and PHDR table are always
/// loaded into memory.
phdr_table_load_index: ?u16 = null,
/// PT_INTERP
phdr_interp_index: ?u16 = null,
/// PT_DYNAMIC
phdr_dynamic_index: ?u16 = null,
/// PT_GNU_EH_FRAME
phdr_gnu_eh_frame_index: ?u16 = null,
/// PT_GNU_STACK
phdr_gnu_stack_index: ?u16 = null,
/// PT_TLS
/// TODO I think ELF permits multiple TLS segments but for now, assume one per file.
phdr_tls_index: ?u16 = null,

entry_index: ?Symbol.Index = null,
page_size: u32,
default_sym_version: elf.Elf64_Versym,

/// .shstrtab buffer
shstrtab: std.ArrayListUnmanaged(u8) = .{},
/// .symtab buffer
symtab: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
/// .strtab buffer
strtab: std.ArrayListUnmanaged(u8) = .{},
/// Dynamic symbol table. Only populated and emitted when linking dynamically.
dynsym: DynsymSection = .{},
/// .dynstrtab buffer
dynstrtab: std.ArrayListUnmanaged(u8) = .{},
/// Version symbol table. Only populated and emitted when linking dynamically.
versym: std.ArrayListUnmanaged(elf.Elf64_Versym) = .{},
/// .verneed section
verneed: VerneedSection = .{},
/// .got section
got: GotSection = .{},
/// .rela.dyn section
rela_dyn: std.ArrayListUnmanaged(elf.Elf64_Rela) = .{},
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
rela_plt: std.ArrayListUnmanaged(elf.Elf64_Rela) = .{},
/// .got.zig section
zig_got: ZigGotSection = .{},
/// SHT_GROUP sections
/// Applies only to a relocatable.
comdat_group_sections: std.ArrayListUnmanaged(ComdatGroupSection) = .{},

/// Tracked section headers with incremental updates to Zig object.
/// .rela.* sections are only used when emitting a relocatable object file.
zig_text_section_index: ?u32 = null,
zig_data_rel_ro_section_index: ?u32 = null,
zig_data_section_index: ?u32 = null,
zig_bss_section_index: ?u32 = null,
zig_got_section_index: ?u32 = null,

debug_info_section_index: ?u32 = null,
debug_abbrev_section_index: ?u32 = null,
debug_str_section_index: ?u32 = null,
debug_aranges_section_index: ?u32 = null,
debug_line_section_index: ?u32 = null,

copy_rel_section_index: ?u32 = null,
dynamic_section_index: ?u32 = null,
dynstrtab_section_index: ?u32 = null,
dynsymtab_section_index: ?u32 = null,
eh_frame_section_index: ?u32 = null,
eh_frame_rela_section_index: ?u32 = null,
eh_frame_hdr_section_index: ?u32 = null,
hash_section_index: ?u32 = null,
gnu_hash_section_index: ?u32 = null,
got_section_index: ?u32 = null,
got_plt_section_index: ?u32 = null,
interp_section_index: ?u32 = null,
plt_section_index: ?u32 = null,
plt_got_section_index: ?u32 = null,
rela_dyn_section_index: ?u32 = null,
rela_plt_section_index: ?u32 = null,
versym_section_index: ?u32 = null,
verneed_section_index: ?u32 = null,

shstrtab_section_index: ?u32 = null,
strtab_section_index: ?u32 = null,
symtab_section_index: ?u32 = null,

// Linker-defined symbols
dynamic_index: ?Symbol.Index = null,
ehdr_start_index: ?Symbol.Index = null,
init_array_start_index: ?Symbol.Index = null,
init_array_end_index: ?Symbol.Index = null,
fini_array_start_index: ?Symbol.Index = null,
fini_array_end_index: ?Symbol.Index = null,
preinit_array_start_index: ?Symbol.Index = null,
preinit_array_end_index: ?Symbol.Index = null,
got_index: ?Symbol.Index = null,
plt_index: ?Symbol.Index = null,
end_index: ?Symbol.Index = null,
gnu_eh_frame_hdr_index: ?Symbol.Index = null,
dso_handle_index: ?Symbol.Index = null,
rela_iplt_start_index: ?Symbol.Index = null,
rela_iplt_end_index: ?Symbol.Index = null,
global_pointer_index: ?Symbol.Index = null,
start_stop_indexes: std.ArrayListUnmanaged(u32) = .{},

/// An array of symbols parsed across all input files.
symbols: std.ArrayListUnmanaged(Symbol) = .{},
symbols_extra: std.ArrayListUnmanaged(u32) = .{},
symbols_free_list: std.ArrayListUnmanaged(Symbol.Index) = .{},

resolver: std.AutoArrayHashMapUnmanaged(u32, Symbol.Index) = .{},

has_text_reloc: bool = false,
num_ifunc_dynrelocs: usize = 0,

/// List of atoms that are owned directly by the linker.
atoms: std.ArrayListUnmanaged(Atom) = .{},
atoms_extra: std.ArrayListUnmanaged(u32) = .{},

/// List of range extension thunks.
thunks: std.ArrayListUnmanaged(Thunk) = .{},

/// List of output merge sections with deduped contents.
merge_sections: std.ArrayListUnmanaged(MergeSection) = .{},
/// List of output merge subsections.
/// Each subsection is akin to Atom but belongs to a MergeSection.
merge_subsections: std.ArrayListUnmanaged(MergeSubsection) = .{},
/// List of input merge sections as parsed from input relocatables.
merge_input_sections: std.ArrayListUnmanaged(InputMergeSection) = .{},

/// Table of last atom index in a section and matching atom free list if any.
last_atom_and_free_list_table: LastAtomAndFreeListTable = .{},

comdat_groups: std.ArrayListUnmanaged(ComdatGroup) = .{},
comdat_groups_owners: std.ArrayListUnmanaged(ComdatGroupOwner) = .{},
comdat_groups_table: std.AutoHashMapUnmanaged(u32, ComdatGroupOwner.Index) = .{},

/// Global string table used to provide quick access to global symbol resolvers
/// such as `resolver` and `comdat_groups_table`.
strings: StringTable = .{},

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
    emit: Compilation.Emit,
    options: link.File.OpenOptions,
) !*Elf {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .elf);

    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const use_llvm = comp.config.use_llvm;
    const opt_zcu = comp.module;
    const output_mode = comp.config.output_mode;
    const link_mode = comp.config.link_mode;
    const optimize_mode = comp.root_mod.optimize_mode;
    const is_native_os = comp.root_mod.resolved_target.is_native_os;
    const ptr_width: PtrWidth = switch (target.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedELFArchitecture,
    };

    const page_size: u32 = switch (target.cpu.arch) {
        .aarch64, .powerpc64le => 0x10000,
        .sparc64 => 0x2000,
        else => 0x1000,
    };
    const is_dyn_lib = output_mode == .Lib and link_mode == .dynamic;
    const default_sym_version: elf.Elf64_Versym = if (is_dyn_lib or comp.config.rdynamic)
        elf.VER_NDX_GLOBAL
    else
        elf.VER_NDX_LOCAL;

    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    // If using LLVM to generate the object file for the zig compilation unit,
    // we need a place to put the object file so that it can be subsequently
    // handled.
    const zcu_object_sub_path = if (!use_lld and !use_llvm)
        null
    else
        try std.fmt.allocPrint(arena, "{s}.o", .{emit.sub_path});

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
            .rpath_list = options.rpath_list,
        },
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
    self.base.file = try emit.directory.handle.createFile(sub_path, .{
        .truncate = true,
        .read = true,
        .mode = link.File.determineMode(use_lld, output_mode, link_mode),
    });

    const gpa = comp.gpa;

    // Index 0 is always a null symbol.
    try self.symbols.append(gpa, .{});
    // Index 0 is always a null symbol.
    try self.symbols_extra.append(gpa, 0);
    // Allocate atom index 0 to null atom
    try self.atoms.append(gpa, .{});
    try self.atoms_extra.append(gpa, 0);
    // Append null file at index 0
    try self.files.append(gpa, .null);
    // Append null byte to string tables
    try self.shstrtab.append(gpa, 0);
    try self.strtab.append(gpa, 0);
    // There must always be a null shdr in index 0
    _ = try self.addSection(.{ .name = "" });
    // Append null symbol in output symtab
    try self.symtab.append(gpa, null_sym);
    // Append null input merge section.
    try self.merge_input_sections.append(gpa, .{});

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
        self.phdr_table_index = try self.addPhdr(.{
            .type = elf.PT_PHDR,
            .flags = elf.PF_R,
            .@"align" = p_align,
            .addr = self.image_base + ehsize,
            .offset = ehsize,
            .filesz = reserved,
            .memsz = reserved,
        });
        self.phdr_table_load_index = try self.addPhdr(.{
            .type = elf.PT_LOAD,
            .flags = elf.PF_R,
            .@"align" = self.page_size,
            .addr = self.image_base,
            .offset = 0,
            .filesz = reserved + ehsize,
            .memsz = reserved + ehsize,
        });
    }

    if (opt_zcu) |zcu| {
        if (!use_llvm) {
            const index: File.Index = @intCast(try self.files.addOne(gpa));
            self.files.set(index, .{ .zig_object = .{
                .index = index,
                .path = try std.fmt.allocPrint(arena, "{s}.o", .{fs.path.stem(
                    zcu.main_mod.root_src_path,
                )}),
            } });
            self.zig_object_index = index;
            try self.zigObjectPtr().?.init(self);
            try self.initMetadata(.{
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

    self.shdrs.deinit(gpa);
    self.phdr_to_shdr_table.deinit(gpa);
    self.phdrs.deinit(gpa);
    for (self.output_sections.values()) |*list| {
        list.deinit(gpa);
    }
    self.output_sections.deinit(gpa);
    for (self.output_rela_sections.values()) |*sec| {
        sec.atom_list.deinit(gpa);
    }
    self.output_rela_sections.deinit(gpa);
    self.shstrtab.deinit(gpa);
    self.symtab.deinit(gpa);
    self.strtab.deinit(gpa);
    self.symbols.deinit(gpa);
    self.symbols_extra.deinit(gpa);
    self.symbols_free_list.deinit(gpa);
    self.resolver.deinit(gpa);
    self.start_stop_indexes.deinit(gpa);

    self.atoms.deinit(gpa);
    self.atoms_extra.deinit(gpa);
    for (self.thunks.items) |*th| {
        th.deinit(gpa);
    }
    self.thunks.deinit(gpa);
    for (self.merge_sections.items) |*sect| {
        sect.deinit(gpa);
    }
    self.merge_sections.deinit(gpa);
    self.merge_subsections.deinit(gpa);
    for (self.merge_input_sections.items) |*sect| {
        sect.deinit(gpa);
    }
    self.merge_input_sections.deinit(gpa);
    for (self.last_atom_and_free_list_table.values()) |*value| {
        value.free_list.deinit(gpa);
    }
    self.last_atom_and_free_list_table.deinit(gpa);

    self.comdat_groups.deinit(gpa);
    self.comdat_groups_owners.deinit(gpa);
    self.comdat_groups_table.deinit(gpa);
    self.strings.deinit(gpa);

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
    self.zig_got.deinit(gpa);
    self.comdat_group_sections.deinit(gpa);
}

pub fn getDeclVAddr(self: *Elf, decl_index: InternPool.DeclIndex, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    return self.zigObjectPtr().?.getDeclVAddr(self, decl_index, reloc_info);
}

pub fn lowerAnonDecl(
    self: *Elf,
    decl_val: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Module.SrcLoc,
) !codegen.Result {
    return self.zigObjectPtr().?.lowerAnonDecl(self, decl_val, explicit_alignment, src_loc);
}

pub fn getAnonDeclVAddr(self: *Elf, decl_val: InternPool.Index, reloc_info: link.File.RelocInfo) !u64 {
    assert(self.llvm_object == null);
    return self.zigObjectPtr().?.getAnonDeclVAddr(self, decl_val, reloc_info);
}

/// Returns end pos of collision, if any.
fn detectAllocCollision(self: *Elf, start: u64, size: u64) ?u64 {
    const small_ptr = self.ptr_width == .p32;
    const ehdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Ehdr) else @sizeOf(elf.Elf64_Ehdr);
    if (start < ehdr_size)
        return ehdr_size;

    const end = start + padToIdeal(size);

    if (self.shdr_table_offset) |off| {
        const shdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Shdr) else @sizeOf(elf.Elf64_Shdr);
        const tight_size = self.shdrs.items.len * shdr_size;
        const increased_size = padToIdeal(tight_size);
        const test_end = off +| increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    for (self.shdrs.items) |shdr| {
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        const increased_size = padToIdeal(shdr.sh_size);
        const test_end = shdr.sh_offset +| increased_size;
        if (end > shdr.sh_offset and start < test_end) {
            return test_end;
        }
    }

    for (self.phdrs.items) |phdr| {
        if (phdr.p_type != elf.PT_LOAD) continue;
        const increased_size = padToIdeal(phdr.p_filesz);
        const test_end = phdr.p_offset +| increased_size;
        if (end > phdr.p_offset and start < test_end) {
            return test_end;
        }
    }

    return null;
}

pub fn allocatedSize(self: *Elf, start: u64) u64 {
    if (start == 0) return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    if (self.shdr_table_offset) |off| {
        if (off > start and off < min_pos) min_pos = off;
    }
    for (self.shdrs.items) |section| {
        if (section.sh_offset <= start) continue;
        if (section.sh_offset < min_pos) min_pos = section.sh_offset;
    }
    for (self.phdrs.items) |phdr| {
        if (phdr.p_offset <= start) continue;
        if (phdr.p_offset < min_pos) min_pos = phdr.p_offset;
    }
    return min_pos - start;
}

fn allocatedVirtualSize(self: *Elf, start: u64) u64 {
    if (start == 0) return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    for (self.phdrs.items) |phdr| {
        if (phdr.p_vaddr <= start) continue;
        if (phdr.p_vaddr < min_pos) min_pos = phdr.p_vaddr;
    }
    return min_pos - start;
}

pub fn findFreeSpace(self: *Elf, object_size: u64, min_alignment: u64) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForward(u64, item_end, min_alignment);
    }
    return start;
}

pub const InitMetadataOptions = struct {
    symbol_count_hint: u64,
    program_code_size_hint: u64,
};

/// TODO move to ZigObject
pub fn initMetadata(self: *Elf, options: InitMetadataOptions) !void {
    const gpa = self.base.comp.gpa;
    const ptr_size = self.ptrWidthBytes();
    const target = self.base.comp.root_mod.resolved_target.result;
    const ptr_bit_width = target.ptrBitWidth();
    const zig_object = self.zigObjectPtr().?;

    const fillSection = struct {
        fn fillSection(elf_file: *Elf, shdr: *elf.Elf64_Shdr, size: u64, phndx: ?u16) void {
            if (elf_file.base.isRelocatable()) {
                const off = elf_file.findFreeSpace(size, shdr.sh_addralign);
                shdr.sh_offset = off;
                shdr.sh_size = size;
            } else {
                const phdr = elf_file.phdrs.items[phndx.?];
                shdr.sh_addr = phdr.p_vaddr;
                shdr.sh_offset = phdr.p_offset;
                shdr.sh_size = phdr.p_memsz;
            }
        }
    }.fillSection;

    comptime assert(number_of_zig_segments == 5);

    if (!self.base.isRelocatable()) {
        if (self.phdr_zig_load_re_index == null) {
            const filesz = options.program_code_size_hint;
            const off = self.findFreeSpace(filesz, self.page_size);
            self.phdr_zig_load_re_index = try self.addPhdr(.{
                .type = elf.PT_LOAD,
                .offset = off,
                .filesz = filesz,
                .addr = if (ptr_bit_width >= 32) 0x8000000 else 0x8000,
                .memsz = filesz,
                .@"align" = self.page_size,
                .flags = elf.PF_X | elf.PF_R | elf.PF_W,
            });
        }

        if (self.phdr_zig_got_index == null) {
            const alignment = self.page_size;
            const filesz = @as(u64, ptr_size) * options.symbol_count_hint;
            const off = self.findFreeSpace(filesz, alignment);
            self.phdr_zig_got_index = try self.addPhdr(.{
                .type = elf.PT_LOAD,
                .offset = off,
                .filesz = filesz,
                .addr = if (ptr_bit_width >= 32) 0x4000000 else 0x4000,
                .memsz = filesz,
                .@"align" = alignment,
                .flags = elf.PF_R | elf.PF_W,
            });
        }

        if (self.phdr_zig_load_ro_index == null) {
            const alignment = self.page_size;
            const filesz: u64 = 1024;
            const off = self.findFreeSpace(filesz, alignment);
            self.phdr_zig_load_ro_index = try self.addPhdr(.{
                .type = elf.PT_LOAD,
                .offset = off,
                .filesz = filesz,
                .addr = if (ptr_bit_width >= 32) 0xc000000 else 0xa000,
                .memsz = filesz,
                .@"align" = alignment,
                .flags = elf.PF_R | elf.PF_W,
            });
        }

        if (self.phdr_zig_load_rw_index == null) {
            const alignment = self.page_size;
            const filesz: u64 = 1024;
            const off = self.findFreeSpace(filesz, alignment);
            self.phdr_zig_load_rw_index = try self.addPhdr(.{
                .type = elf.PT_LOAD,
                .offset = off,
                .filesz = filesz,
                .addr = if (ptr_bit_width >= 32) 0x10000000 else 0xc000,
                .memsz = filesz,
                .@"align" = alignment,
                .flags = elf.PF_R | elf.PF_W,
            });
        }

        if (self.phdr_zig_load_zerofill_index == null) {
            const alignment = self.page_size;
            self.phdr_zig_load_zerofill_index = try self.addPhdr(.{
                .type = elf.PT_LOAD,
                .addr = if (ptr_bit_width >= 32) 0x14000000 else 0xf000,
                .memsz = 1024,
                .@"align" = alignment,
                .flags = elf.PF_R | elf.PF_W,
            });
        }
    }

    if (self.zig_text_section_index == null) {
        self.zig_text_section_index = try self.addSection(.{
            .name = ".text.zig",
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            .addralign = 1,
            .offset = std.math.maxInt(u64),
        });
        const shdr = &self.shdrs.items[self.zig_text_section_index.?];
        fillSection(self, shdr, options.program_code_size_hint, self.phdr_zig_load_re_index);
        if (self.base.isRelocatable()) {
            const rela_shndx = try self.addRelaShdr(".rela.text.zig", self.zig_text_section_index.?);
            try self.output_rela_sections.putNoClobber(gpa, self.zig_text_section_index.?, .{
                .shndx = rela_shndx,
            });
        } else {
            try self.phdr_to_shdr_table.putNoClobber(
                gpa,
                self.zig_text_section_index.?,
                self.phdr_zig_load_re_index.?,
            );
        }
        try self.output_sections.putNoClobber(gpa, self.zig_text_section_index.?, .{});
        try self.last_atom_and_free_list_table.putNoClobber(gpa, self.zig_text_section_index.?, .{});
    }

    if (self.zig_got_section_index == null and !self.base.isRelocatable()) {
        self.zig_got_section_index = try self.addSection(.{
            .name = ".got.zig",
            .type = elf.SHT_PROGBITS,
            .addralign = ptr_size,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .offset = std.math.maxInt(u64),
        });
        const shdr = &self.shdrs.items[self.zig_got_section_index.?];
        const phndx = self.phdr_zig_got_index.?;
        const phdr = self.phdrs.items[phndx];
        shdr.sh_addr = phdr.p_vaddr;
        shdr.sh_offset = phdr.p_offset;
        shdr.sh_size = phdr.p_memsz;
        try self.phdr_to_shdr_table.putNoClobber(
            gpa,
            self.zig_got_section_index.?,
            self.phdr_zig_got_index.?,
        );
    }

    if (self.zig_data_rel_ro_section_index == null) {
        self.zig_data_rel_ro_section_index = try self.addSection(.{
            .name = ".data.rel.ro.zig",
            .type = elf.SHT_PROGBITS,
            .addralign = 1,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .offset = std.math.maxInt(u64),
        });
        const shdr = &self.shdrs.items[self.zig_data_rel_ro_section_index.?];
        fillSection(self, shdr, 1024, self.phdr_zig_load_ro_index);
        if (self.base.isRelocatable()) {
            const rela_shndx = try self.addRelaShdr(
                ".rela.data.rel.ro.zig",
                self.zig_data_rel_ro_section_index.?,
            );
            try self.output_rela_sections.putNoClobber(gpa, self.zig_data_rel_ro_section_index.?, .{
                .shndx = rela_shndx,
            });
        } else {
            try self.phdr_to_shdr_table.putNoClobber(
                gpa,
                self.zig_data_rel_ro_section_index.?,
                self.phdr_zig_load_ro_index.?,
            );
        }
        try self.output_sections.putNoClobber(gpa, self.zig_data_rel_ro_section_index.?, .{});
        try self.last_atom_and_free_list_table.putNoClobber(gpa, self.zig_data_rel_ro_section_index.?, .{});
    }

    if (self.zig_data_section_index == null) {
        self.zig_data_section_index = try self.addSection(.{
            .name = ".data.zig",
            .type = elf.SHT_PROGBITS,
            .addralign = ptr_size,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .offset = std.math.maxInt(u64),
        });
        const shdr = &self.shdrs.items[self.zig_data_section_index.?];
        fillSection(self, shdr, 1024, self.phdr_zig_load_rw_index);
        if (self.base.isRelocatable()) {
            const rela_shndx = try self.addRelaShdr(
                ".rela.data.zig",
                self.zig_data_section_index.?,
            );
            try self.output_rela_sections.putNoClobber(gpa, self.zig_data_section_index.?, .{
                .shndx = rela_shndx,
            });
        } else {
            try self.phdr_to_shdr_table.putNoClobber(
                gpa,
                self.zig_data_section_index.?,
                self.phdr_zig_load_rw_index.?,
            );
        }
        try self.output_sections.putNoClobber(gpa, self.zig_data_section_index.?, .{});
        try self.last_atom_and_free_list_table.putNoClobber(gpa, self.zig_data_section_index.?, .{});
    }

    if (self.zig_bss_section_index == null) {
        self.zig_bss_section_index = try self.addSection(.{
            .name = ".bss.zig",
            .type = elf.SHT_NOBITS,
            .addralign = ptr_size,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .offset = 0,
        });
        const shdr = &self.shdrs.items[self.zig_bss_section_index.?];
        if (self.phdr_zig_load_zerofill_index) |phndx| {
            const phdr = self.phdrs.items[phndx];
            shdr.sh_addr = phdr.p_vaddr;
            shdr.sh_size = phdr.p_memsz;
            try self.phdr_to_shdr_table.putNoClobber(gpa, self.zig_bss_section_index.?, phndx);
        } else {
            shdr.sh_size = 1024;
        }
        try self.output_sections.putNoClobber(gpa, self.zig_bss_section_index.?, .{});
        try self.last_atom_and_free_list_table.putNoClobber(gpa, self.zig_bss_section_index.?, .{});
    }

    if (zig_object.dwarf) |*dw| {
        if (self.debug_str_section_index == null) {
            assert(dw.strtab.buffer.items.len == 0);
            try dw.strtab.buffer.append(gpa, 0);
            self.debug_str_section_index = try self.addSection(.{
                .name = ".debug_str",
                .flags = elf.SHF_MERGE | elf.SHF_STRINGS,
                .entsize = 1,
                .type = elf.SHT_PROGBITS,
                .addralign = 1,
                .offset = std.math.maxInt(u64),
            });
            const shdr = &self.shdrs.items[self.debug_str_section_index.?];
            const size = @as(u64, @intCast(dw.strtab.buffer.items.len));
            const off = self.findFreeSpace(size, 1);
            shdr.sh_offset = off;
            shdr.sh_size = size;
            zig_object.debug_strtab_dirty = true;
            try self.output_sections.putNoClobber(gpa, self.debug_str_section_index.?, .{});
        }

        if (self.debug_info_section_index == null) {
            self.debug_info_section_index = try self.addSection(.{
                .name = ".debug_info",
                .type = elf.SHT_PROGBITS,
                .addralign = 1,
                .offset = std.math.maxInt(u64),
            });
            const shdr = &self.shdrs.items[self.debug_info_section_index.?];
            const size: u64 = 200;
            const off = self.findFreeSpace(size, 1);
            shdr.sh_offset = off;
            shdr.sh_size = size;
            zig_object.debug_info_header_dirty = true;
            try self.output_sections.putNoClobber(gpa, self.debug_info_section_index.?, .{});
        }

        if (self.debug_abbrev_section_index == null) {
            self.debug_abbrev_section_index = try self.addSection(.{
                .name = ".debug_abbrev",
                .type = elf.SHT_PROGBITS,
                .addralign = 1,
                .offset = std.math.maxInt(u64),
            });
            const shdr = &self.shdrs.items[self.debug_abbrev_section_index.?];
            const size: u64 = 128;
            const off = self.findFreeSpace(size, 1);
            shdr.sh_offset = off;
            shdr.sh_size = size;
            zig_object.debug_abbrev_section_dirty = true;
            try self.output_sections.putNoClobber(gpa, self.debug_abbrev_section_index.?, .{});
        }

        if (self.debug_aranges_section_index == null) {
            self.debug_aranges_section_index = try self.addSection(.{
                .name = ".debug_aranges",
                .type = elf.SHT_PROGBITS,
                .addralign = 16,
                .offset = std.math.maxInt(u64),
            });
            const shdr = &self.shdrs.items[self.debug_aranges_section_index.?];
            const size: u64 = 160;
            const off = self.findFreeSpace(size, 16);
            shdr.sh_offset = off;
            shdr.sh_size = size;
            zig_object.debug_aranges_section_dirty = true;
            try self.output_sections.putNoClobber(gpa, self.debug_aranges_section_index.?, .{});
        }

        if (self.debug_line_section_index == null) {
            self.debug_line_section_index = try self.addSection(.{
                .name = ".debug_line",
                .type = elf.SHT_PROGBITS,
                .addralign = 1,
                .offset = std.math.maxInt(u64),
            });
            const shdr = &self.shdrs.items[self.debug_line_section_index.?];
            const size: u64 = 250;
            const off = self.findFreeSpace(size, 1);
            shdr.sh_offset = off;
            shdr.sh_size = size;
            zig_object.debug_line_header_dirty = true;
            try self.output_sections.putNoClobber(gpa, self.debug_line_section_index.?, .{});
        }
    }

    // We need to find current max assumed file offset, and actually write to file to make it a reality.
    var end_pos: u64 = 0;
    for (self.shdrs.items) |shdr| {
        if (shdr.sh_offset == std.math.maxInt(u64)) continue;
        end_pos = @max(end_pos, shdr.sh_offset + shdr.sh_size);
    }
    try self.base.file.?.pwriteAll(&[1]u8{0}, end_pos);
}

pub fn growAllocSection(self: *Elf, shdr_index: u32, needed_size: u64) !void {
    const shdr = &self.shdrs.items[shdr_index];
    const maybe_phdr = if (self.phdr_to_shdr_table.get(shdr_index)) |phndx| &self.phdrs.items[phndx] else null;
    const is_zerofill = shdr.sh_type == elf.SHT_NOBITS;

    if (needed_size > self.allocatedSize(shdr.sh_offset) and !is_zerofill) {
        const existing_size = shdr.sh_size;
        shdr.sh_size = 0;
        // Must move the entire section.
        const alignment = if (maybe_phdr) |phdr| phdr.p_align else shdr.sh_addralign;
        const new_offset = self.findFreeSpace(needed_size, alignment);

        log.debug("new '{s}' file offset 0x{x} to 0x{x}", .{
            self.getShString(shdr.sh_name),
            new_offset,
            new_offset + existing_size,
        });

        const amt = try self.base.file.?.copyRangeAll(shdr.sh_offset, self.base.file.?, new_offset, existing_size);
        // TODO figure out what to about this error condition - how to communicate it up.
        if (amt != existing_size) return error.InputOutput;

        shdr.sh_offset = new_offset;
        if (maybe_phdr) |phdr| phdr.p_offset = new_offset;
    }

    shdr.sh_size = needed_size;
    if (!is_zerofill) {
        if (maybe_phdr) |phdr| phdr.p_filesz = needed_size;
    }

    if (maybe_phdr) |phdr| {
        const mem_capacity = self.allocatedVirtualSize(phdr.p_vaddr);
        if (needed_size > mem_capacity) {
            var err = try self.addErrorWithNotes(2);
            try err.addMsg(self, "fatal linker error: cannot expand load segment phdr({d}) in virtual memory", .{
                self.phdr_to_shdr_table.get(shdr_index).?,
            });
            try err.addNote(self, "TODO: emit relocations to memory locations in self-hosted backends", .{});
            try err.addNote(self, "as a workaround, try increasing pre-allocated virtual memory of each segment", .{});
        }

        phdr.p_memsz = needed_size;
    }

    self.markDirty(shdr_index);
}

pub fn growNonAllocSection(
    self: *Elf,
    shdr_index: u32,
    needed_size: u64,
    min_alignment: u32,
    requires_file_copy: bool,
) !void {
    const shdr = &self.shdrs.items[shdr_index];

    if (needed_size > self.allocatedSize(shdr.sh_offset)) {
        const existing_size = shdr.sh_size;
        shdr.sh_size = 0;
        // Move all the symbols to a new file location.
        const new_offset = self.findFreeSpace(needed_size, min_alignment);

        log.debug("new '{s}' file offset 0x{x} to 0x{x}", .{
            self.getShString(shdr.sh_name),
            new_offset,
            new_offset + existing_size,
        });

        if (requires_file_copy) {
            const amt = try self.base.file.?.copyRangeAll(
                shdr.sh_offset,
                self.base.file.?,
                new_offset,
                existing_size,
            );
            if (amt != existing_size) return error.InputOutput;
        }

        shdr.sh_offset = new_offset;
    }

    shdr.sh_size = needed_size;

    self.markDirty(shdr_index);
}

pub fn markDirty(self: *Elf, shdr_index: u32) void {
    const zig_object = self.zigObjectPtr().?;
    if (zig_object.dwarf) |_| {
        if (self.debug_info_section_index.? == shdr_index) {
            zig_object.debug_info_header_dirty = true;
        } else if (self.debug_line_section_index.? == shdr_index) {
            zig_object.debug_line_header_dirty = true;
        } else if (self.debug_abbrev_section_index.? == shdr_index) {
            zig_object.debug_abbrev_section_dirty = true;
        } else if (self.debug_str_section_index.? == shdr_index) {
            zig_object.debug_strtab_dirty = true;
        } else if (self.debug_aranges_section_index.? == shdr_index) {
            zig_object.debug_aranges_section_dirty = true;
        }
    }
}

pub fn flush(self: *Elf, arena: Allocator, prog_node: std.Progress.Node) link.File.FlushError!void {
    const use_lld = build_options.have_llvm and self.base.comp.config.use_lld;
    if (use_lld) {
        return self.linkWithLLD(arena, prog_node);
    }
    try self.flushModule(arena, prog_node);
}

pub fn flushModule(self: *Elf, arena: Allocator, prog_node: std.Progress.Node) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;

    if (self.llvm_object) |llvm_object| {
        try self.base.emitLlvmObject(arena, llvm_object, prog_node);
        const use_lld = build_options.have_llvm and comp.config.use_lld;
        if (use_lld) return;
    }

    const sub_prog_node = prog_node.start("ELF Flush", 0);
    defer sub_prog_node.end();

    const target = comp.root_mod.resolved_target.result;
    const link_mode = comp.config.link_mode;
    const directory = self.base.emit.directory; // Just an alias to make it shorter to type.
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

    if (self.zigObjectPtr()) |zig_object| try zig_object.flushModule(self);
    if (self.base.isStaticLib()) return relocatable.flushStaticLib(self, comp, module_obj_path);
    if (self.base.isObject()) return relocatable.flushObject(self, comp, module_obj_path);

    const csu = try CsuObjects.init(arena, comp);
    const compiler_rt_path: ?[]const u8 = blk: {
        if (comp.compiler_rt_lib) |x| break :blk x.full_object_path;
        if (comp.compiler_rt_obj) |x| break :blk x.full_object_path;
        break :blk null;
    };

    // Here we will parse input positional and library files (if referenced).
    // This will roughly match in any linker backend we support.
    var positionals = std.ArrayList(Compilation.LinkObject).init(arena);

    // csu prelude
    if (csu.crt0) |v| try positionals.append(.{ .path = v });
    if (csu.crti) |v| try positionals.append(.{ .path = v });
    if (csu.crtbegin) |v| try positionals.append(.{ .path = v });

    try positionals.ensureUnusedCapacity(comp.objects.len);
    positionals.appendSliceAssumeCapacity(comp.objects);

    // This is a set of object files emitted by clang in a single `build-exe` invocation.
    // For instance, the implicit `a.o` as compiled by `zig build-exe a.c` will end up
    // in this set.
    for (comp.c_object_table.keys()) |key| {
        try positionals.append(.{ .path = key.status.success.object_path });
    }

    if (module_obj_path) |path| try positionals.append(.{ .path = path });

    // rpaths
    var rpath_table = std.StringArrayHashMap(void).init(gpa);
    defer rpath_table.deinit();

    for (self.base.rpath_list) |rpath| {
        _ = try rpath_table.put(rpath, {});
    }

    // TSAN
    if (comp.config.any_sanitize_thread) {
        try positionals.append(.{ .path = comp.tsan_static_lib.?.full_object_path });
    }

    // libc
    if (!comp.skip_linker_dependencies and !comp.config.link_libc) {
        if (comp.libc_static_lib) |lib| {
            try positionals.append(.{ .path = lib.full_object_path });
        }
    }

    for (positionals.items) |obj| {
        self.parsePositional(obj.path, obj.must_link) catch |err| switch (err) {
            error.MalformedObject, error.MalformedArchive, error.InvalidCpuArch => continue, // already reported
            else => |e| try self.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    var system_libs = std.ArrayList(SystemLib).init(arena);

    try system_libs.ensureUnusedCapacity(comp.system_libs.values().len);
    for (comp.system_libs.values()) |lib_info| {
        system_libs.appendAssumeCapacity(.{ .needed = lib_info.needed, .path = lib_info.path.? });
    }

    // libc++ dep
    if (comp.config.link_libcpp) {
        try system_libs.ensureUnusedCapacity(2);
        system_libs.appendAssumeCapacity(.{ .path = comp.libcxxabi_static_lib.?.full_object_path });
        system_libs.appendAssumeCapacity(.{ .path = comp.libcxx_static_lib.?.full_object_path });
    }

    // libunwind dep
    if (comp.config.link_libunwind) {
        try system_libs.append(.{ .path = comp.libunwind_static_lib.?.full_object_path });
    }

    // libc dep
    comp.link_error_flags.missing_libc = false;
    if (comp.config.link_libc) {
        if (comp.libc_installation) |lc| {
            const flags = target_util.libcFullLinkFlags(target);
            try system_libs.ensureUnusedCapacity(flags.len);

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

                    try self.reportMissingLibraryError(
                        checked_paths.items,
                        "missing system library: '{s}' was not found",
                        .{lib_name},
                    );

                    continue;
                }

                const resolved_path = try arena.dupe(u8, test_path.items);
                system_libs.appendAssumeCapacity(.{ .path = resolved_path });
            }
        } else if (target.isGnuLibC()) {
            try system_libs.ensureUnusedCapacity(glibc.libs.len + 1);
            for (glibc.libs) |lib| {
                const lib_path = try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                    comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                });
                system_libs.appendAssumeCapacity(.{ .path = lib_path });
            }
            system_libs.appendAssumeCapacity(.{
                .path = try comp.get_libc_crt_file(arena, "libc_nonshared.a"),
            });
        } else if (target.isMusl()) {
            const path = try comp.get_libc_crt_file(arena, switch (link_mode) {
                .static => "libc.a",
                .dynamic => "libc.so",
            });
            try system_libs.append(.{ .path = path });
        } else {
            comp.link_error_flags.missing_libc = true;
        }
    }

    for (system_libs.items) |lib| {
        self.parseLibrary(lib, false) catch |err| switch (err) {
            error.MalformedObject, error.MalformedArchive, error.InvalidCpuArch => continue, // already reported
            else => |e| try self.reportParseError(
                lib.path,
                "unexpected error: parsing library failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    // Finally, as the last input objects we add compiler_rt and CSU postlude (if any).
    positionals.clearRetainingCapacity();

    // compiler-rt. Since compiler_rt exports symbols like `memset`, it needs
    // to be after the shared libraries, so they are picked up from the shared
    // libraries, not libcompiler_rt.
    if (compiler_rt_path) |path| try positionals.append(.{ .path = path });

    // csu postlude
    if (csu.crtend) |v| try positionals.append(.{ .path = v });
    if (csu.crtn) |v| try positionals.append(.{ .path = v });

    for (positionals.items) |obj| {
        self.parsePositional(obj.path, obj.must_link) catch |err| switch (err) {
            error.MalformedObject, error.MalformedArchive, error.InvalidCpuArch => continue, // already reported
            else => |e| try self.reportParseError(
                obj.path,
                "unexpected error: parsing input file failed with error {s}",
                .{@errorName(e)},
            ),
        };
    }

    if (comp.link_errors.items.len > 0) return error.FlushFailure;

    // Dedup shared objects
    {
        var seen_dsos = std.StringHashMap(void).init(gpa);
        defer seen_dsos.deinit();
        try seen_dsos.ensureTotalCapacity(@as(u32, @intCast(self.shared_objects.items.len)));

        var i: usize = 0;
        while (i < self.shared_objects.items.len) {
            const index = self.shared_objects.items[i];
            const shared_object = self.file(index).?.shared_object;
            const soname = shared_object.soname();
            const gop = seen_dsos.getOrPutAssumeCapacity(soname);
            if (gop.found_existing) {
                _ = self.shared_objects.orderedRemove(i);
            } else i += 1;
        }
    }

    // If we haven't already, create a linker-generated input file comprising of
    // linker-defined synthetic symbols only such as `_DYNAMIC`, etc.
    if (self.linker_defined_index == null) {
        const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
        self.files.set(index, .{ .linker_defined = .{ .index = index } });
        self.linker_defined_index = index;
    }

    // Now, we are ready to resolve the symbols across all input files.
    // We will first resolve the files in the ZigObject, next in the parsed
    // input Object files.
    // Any qualifing unresolved symbol will be upgraded to an absolute, weak
    // symbol for potential resolution at load-time.
    self.resolveSymbols();
    self.markEhFrameAtomsDead();
    try self.resolveMergeSections();

    try self.convertCommonSymbols();
    self.markImportsExports();

    // Look for entry address in objects if not set by the incremental compiler.
    if (self.entry_index == null) {
        if (self.entry_name) |name| {
            self.entry_index = self.globalByName(name);
        }
    }

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
    try self.initMergeSections();
    try self.addLinkerDefinedSymbols();
    self.claimUnresolved();

    // Scan and create missing synthetic entries such as GOT indirection.
    try self.scanRelocs();

    // Generate and emit synthetic sections.
    try self.initSyntheticSections();
    try self.initSpecialPhdrs();
    try self.sortShdrs();
    for (self.objects.items) |index| {
        try self.file(index).?.object.addAtomsToOutputSections(self);
    }
    try self.sortInitFini();
    try self.setDynamicSection(rpath_table.keys());
    self.sortDynamicSymtab();
    try self.setHashSections();
    try self.setVersionSymtab();
    try self.updateMergeSectionSizes();
    try self.updateSectionSizes();

    try self.allocatePhdrTable();
    try self.allocateAllocSections();
    try self.sortPhdrs();
    try self.allocateNonAllocSections();
    self.allocateSpecialPhdrs();
    self.allocateLinkerDefinedSymbols();

    // Dump the state for easy debugging.
    // State can be dumped via `--debug-log link_state`.
    if (build_options.enable_logging) {
        state_log.debug("{}", .{self.dumpState()});
    }

    // Beyond this point, everything has been allocated a virtual address and we can resolve
    // the relocations, and commit objects to file.
    if (self.zigObjectPtr()) |zig_object| {
        var has_reloc_errors = false;
        for (zig_object.atoms.items) |atom_index| {
            const atom_ptr = self.atom(atom_index) orelse continue;
            if (!atom_ptr.flags.alive) continue;
            const out_shndx = atom_ptr.outputShndx() orelse continue;
            const shdr = &self.shdrs.items[out_shndx];
            if (shdr.sh_type == elf.SHT_NOBITS) continue;
            const code = try zig_object.codeAlloc(self, atom_index);
            defer gpa.free(code);
            const file_offset = shdr.sh_offset + @as(u64, @intCast(atom_ptr.value));
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

    if (self.entry_index == null and self.base.isExe()) {
        log.debug("flushing. no_entry_point_found = true", .{});
        comp.link_error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false", .{});
        comp.link_error_flags.no_entry_point_found = false;
        try self.writeElfHeader();
    }

    if (comp.link_errors.items.len > 0) return error.FlushFailure;
}

/// --verbose-link output
fn dumpArgv(self: *Elf, comp: *Compilation) !void {
    const gpa = self.base.comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = self.base.comp.root_mod.resolved_target.result;
    const link_mode = self.base.comp.config.link_mode;
    const directory = self.base.emit.directory; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.emit.sub_path});
    const module_obj_path: ?[]const u8 = if (self.base.zcu_object_sub_path) |path| blk: {
        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, path });
        } else {
            break :blk path;
        }
    } else null;

    const csu = try CsuObjects.init(arena, comp);
    const compiler_rt_path: ?[]const u8 = blk: {
        if (comp.compiler_rt_lib) |x| break :blk x.full_object_path;
        if (comp.compiler_rt_obj) |x| break :blk x.full_object_path;
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

        for (self.base.rpath_list) |rpath| {
            try argv.append("-rpath");
            try argv.append(rpath);
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
        if (csu.crt0) |v| try argv.append(v);
        if (csu.crti) |v| try argv.append(v);
        if (csu.crtbegin) |v| try argv.append(v);

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
                assert(obj.path[0] == ':');
                try argv.append("-l");
            }
            try argv.append(obj.path);
        }
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (comp.config.any_sanitize_thread) {
            try argv.append(comp.tsan_static_lib.?.full_object_path);
        }

        // libc
        if (!comp.skip_linker_dependencies and !comp.config.link_libc) {
            if (comp.libc_static_lib) |lib| {
                try argv.append(lib.full_object_path);
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
            argv.appendAssumeCapacity(lib_info.path.?);
        }

        if (!as_needed) {
            argv.appendAssumeCapacity("--as-needed");
            as_needed = true;
        }

        // libc++ dep
        if (comp.config.link_libcpp) {
            try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
            try argv.append(comp.libcxx_static_lib.?.full_object_path);
        }

        // libunwind dep
        if (comp.config.link_libunwind) {
            try argv.append(comp.libunwind_static_lib.?.full_object_path);
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
                    const lib_path = try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                        comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                    });
                    try argv.append(lib_path);
                }
                try argv.append(try comp.get_libc_crt_file(arena, "libc_nonshared.a"));
            } else if (target.isMusl()) {
                try argv.append(try comp.get_libc_crt_file(arena, switch (link_mode) {
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
        if (csu.crtend) |v| try argv.append(v);
        if (csu.crtn) |v| try argv.append(v);
    }

    Compilation.dump_argv(argv.items);
}

pub const ParseError = error{
    MalformedObject,
    MalformedArchive,
    InvalidCpuArch,
    OutOfMemory,
    Overflow,
    InputOutput,
    EndOfStream,
    FileSystem,
    NotSupported,
    InvalidCharacter,
    UnknownFileType,
} || LdScript.Error || fs.Dir.AccessError || fs.File.SeekError || fs.File.OpenError || fs.File.ReadError;

pub fn parsePositional(self: *Elf, path: []const u8, must_link: bool) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();
    if (try Object.isObject(path)) {
        try self.parseObject(path);
    } else {
        try self.parseLibrary(.{ .path = path }, must_link);
    }
}

fn parseLibrary(self: *Elf, lib: SystemLib, must_link: bool) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    if (try Archive.isArchive(lib.path)) {
        try self.parseArchive(lib.path, must_link);
    } else if (try SharedObject.isSharedObject(lib.path)) {
        try self.parseSharedObject(lib);
    } else {
        try self.parseLdScript(lib);
    }
}

fn parseObject(self: *Elf, path: []const u8) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const handle = try fs.cwd().openFile(path, .{});
    const fh = try self.addFileHandle(handle);

    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .object = .{
        .path = try gpa.dupe(u8, path),
        .file_handle = fh,
        .index = index,
    } });
    try self.objects.append(gpa, index);

    const object = self.file(index).?.object;
    try object.parse(self);
}

fn parseArchive(self: *Elf, path: []const u8, must_link: bool) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const handle = try fs.cwd().openFile(path, .{});
    const fh = try self.addFileHandle(handle);

    var archive = Archive{};
    defer archive.deinit(gpa);
    try archive.parse(self, path, fh);

    const objects = try archive.objects.toOwnedSlice(gpa);
    defer gpa.free(objects);

    for (objects) |extracted| {
        const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
        self.files.set(index, .{ .object = extracted });
        const object = &self.files.items(.data)[index].object;
        object.index = index;
        object.alive = must_link;
        try object.parse(self);
        try self.objects.append(gpa, index);
    }
}

fn parseSharedObject(self: *Elf, lib: SystemLib) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const handle = try fs.cwd().openFile(lib.path, .{});
    defer handle.close();

    const index = @as(File.Index, @intCast(try self.files.addOne(gpa)));
    self.files.set(index, .{ .shared_object = .{
        .path = try gpa.dupe(u8, lib.path),
        .index = index,
        .needed = lib.needed,
        .alive = lib.needed,
    } });
    try self.shared_objects.append(gpa, index);

    const shared_object = self.file(index).?.shared_object;
    try shared_object.parse(self, handle);
}

fn parseLdScript(self: *Elf, lib: SystemLib) ParseError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.comp.gpa;
    const in_file = try fs.cwd().openFile(lib.path, .{});
    defer in_file.close();
    const data = try in_file.readToEndAlloc(gpa, std.math.maxInt(u32));
    defer gpa.free(data);

    var script = LdScript{ .path = lib.path };
    defer script.deinit(gpa);
    try script.parse(data, self);

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var test_path = std.ArrayList(u8).init(arena);
    var checked_paths = std.ArrayList([]const u8).init(arena);

    for (script.args.items) |scr_obj| {
        checked_paths.clearRetainingCapacity();

        success: {
            if (mem.startsWith(u8, scr_obj.path, "-l")) {
                const lib_name = scr_obj.path["-l".len..];

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
                var buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
                if (fs.realpath(scr_obj.path, &buffer)) |path| {
                    test_path.clearRetainingCapacity();
                    try test_path.writer().writeAll(path);
                    break :success;
                } else |_| {}

                try checked_paths.append(try arena.dupe(u8, scr_obj.path));
                for (self.lib_dirs) |lib_dir| {
                    if (try self.accessLibPath(arena, &test_path, &checked_paths, lib_dir, scr_obj.path, null))
                        break :success;
                }
            }

            try self.reportMissingLibraryError(
                checked_paths.items,
                "missing library dependency: GNU ld script '{s}' requires '{s}', but file not found",
                .{
                    lib.path,
                    scr_obj.path,
                },
            );
            continue;
        }

        const full_path = test_path.items;
        self.parseLibrary(.{
            .needed = scr_obj.needed,
            .path = full_path,
        }, false) catch |err| switch (err) {
            error.MalformedObject, error.MalformedArchive, error.InvalidCpuArch => continue, // already reported
            else => |e| try self.reportParseError(
                full_path,
                "unexpected error: parsing library failed with error {s}",
                .{@errorName(e)},
            ),
        };
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
    const target = self.base.comp.root_mod.resolved_target.result;
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
pub fn resolveSymbols(self: *Elf) void {
    // Resolve symbols in the ZigObject. For now, we assume that it's always live.
    if (self.zigObjectPtr()) |zig_object| zig_object.asFile().resolveSymbols(self);
    // Resolve symbols on the set of all objects and shared objects (even if some are unneeded).
    for (self.objects.items) |index| self.file(index).?.resolveSymbols(self);
    for (self.shared_objects.items) |index| self.file(index).?.resolveSymbols(self);

    // Mark live objects.
    self.markLive();

    // Reset state of all globals after marking live objects.
    if (self.zigObjectPtr()) |zig_object| zig_object.asFile().resetGlobals(self);
    for (self.objects.items) |index| self.file(index).?.resetGlobals(self);
    for (self.shared_objects.items) |index| self.file(index).?.resetGlobals(self);

    // Prune dead objects and shared objects.
    var i: usize = 0;
    while (i < self.objects.items.len) {
        const index = self.objects.items[i];
        if (!self.file(index).?.isAlive()) {
            _ = self.objects.orderedRemove(i);
        } else i += 1;
    }
    i = 0;
    while (i < self.shared_objects.items.len) {
        const index = self.shared_objects.items[i];
        if (!self.file(index).?.isAlive()) {
            _ = self.shared_objects.orderedRemove(i);
        } else i += 1;
    }

    // Dedup comdat groups.
    for (self.objects.items) |index| {
        const object = self.file(index).?.object;
        for (object.comdat_groups.items) |cg_index| {
            const cg = self.comdatGroup(cg_index);
            const cg_owner = self.comdatGroupOwner(cg.owner);
            const owner_file_index = if (self.file(cg_owner.file)) |file_ptr|
                file_ptr.object.index
            else
                std.math.maxInt(File.Index);
            cg_owner.file = @min(owner_file_index, index);
        }
    }

    for (self.objects.items) |index| {
        const object = self.file(index).?.object;
        for (object.comdat_groups.items) |cg_index| {
            const cg = self.comdatGroup(cg_index);
            const cg_owner = self.comdatGroupOwner(cg.owner);
            if (cg_owner.file != index) {
                for (cg.comdatGroupMembers(self)) |shndx| {
                    const atom_index = object.atoms.items[shndx];
                    if (self.atom(atom_index)) |atom_ptr| {
                        atom_ptr.flags.alive = false;
                        atom_ptr.markFdesDead(self);
                    }
                }
            }
        }
    }

    // Re-resolve the symbols.
    if (self.zigObjectPtr()) |zig_object| zig_object.resolveSymbols(self);
    for (self.objects.items) |index| self.file(index).?.resolveSymbols(self);
    for (self.shared_objects.items) |index| self.file(index).?.resolveSymbols(self);
}

/// Traverses all objects and shared objects marking any object referenced by
/// a live object/shared object as alive itself.
/// This routine will prune unneeded objects extracted from archives and
/// unneeded shared objects.
fn markLive(self: *Elf) void {
    if (self.zigObjectPtr()) |zig_object| zig_object.asFile().markLive(self);
    for (self.objects.items) |index| {
        const file_ptr = self.file(index).?;
        if (file_ptr.isAlive()) file_ptr.markLive(self);
    }
    for (self.shared_objects.items) |index| {
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

fn convertCommonSymbols(self: *Elf) !void {
    for (self.objects.items) |index| {
        try self.file(index).?.object.convertCommonSymbols(self);
    }
}

fn markImportsExports(self: *Elf) void {
    const mark = struct {
        fn mark(elf_file: *Elf, file_index: File.Index) void {
            for (elf_file.file(file_index).?.globals()) |global_index| {
                const global = elf_file.symbol(global_index);
                if (global.version_index == elf.VER_NDX_LOCAL) continue;
                const file_ptr = global.file(elf_file) orelse continue;
                const vis = @as(elf.STV, @enumFromInt(global.elfSym(elf_file).st_other));
                if (vis == .HIDDEN) continue;
                if (file_ptr == .shared_object and !global.isAbs(elf_file)) {
                    global.flags.import = true;
                    continue;
                }
                if (file_ptr.index() == file_index) {
                    global.flags.@"export" = true;
                    if (elf_file.isEffectivelyDynLib() and vis != .PROTECTED) {
                        global.flags.import = true;
                    }
                }
            }
        }
    }.mark;

    if (!self.isEffectivelyDynLib()) {
        for (self.shared_objects.items) |index| {
            for (self.file(index).?.globals()) |global_index| {
                const global = self.symbol(global_index);
                const file_ptr = global.file(self) orelse continue;
                const vis = @as(elf.STV, @enumFromInt(global.elfSym(self).st_other));
                if (file_ptr != .shared_object and vis != .HIDDEN) global.flags.@"export" = true;
            }
        }
    }

    if (self.zig_object_index) |index| {
        mark(self, index);
    }

    for (self.objects.items) |index| {
        mark(self, index);
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

    var undefs = std.AutoHashMap(Symbol.Index, std.ArrayList(Atom.Index)).init(gpa);
    defer {
        var it = undefs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        undefs.deinit();
    }

    var objects = try std.ArrayList(File.Index).initCapacity(gpa, self.objects.items.len + 1);
    defer objects.deinit();
    if (self.zigObjectPtr()) |zo| objects.appendAssumeCapacity(zo.index);
    objects.appendSliceAssumeCapacity(self.objects.items);

    var has_reloc_errors = false;
    for (objects.items) |index| {
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

    for (self.symbols.items, 0..) |*sym, i| {
        const index = @as(u32, @intCast(i));
        if (!sym.isLocal(self) and !sym.flags.has_dynamic) {
            log.debug("'{s}' is non-local", .{sym.name(self)});
            try self.dynsym.addSymbol(index, self);
        }
        if (sym.flags.needs_got) {
            log.debug("'{s}' needs GOT", .{sym.name(self)});
            _ = try self.got.addGotSymbol(index, self);
        }
        if (sym.flags.needs_plt) {
            if (sym.flags.is_canonical) {
                log.debug("'{s}' needs CPLT", .{sym.name(self)});
                sym.flags.@"export" = true;
                try self.plt.addSymbol(index, self);
            } else if (sym.flags.needs_got) {
                log.debug("'{s}' needs PLTGOT", .{sym.name(self)});
                try self.plt_got.addSymbol(index, self);
            } else {
                log.debug("'{s}' needs PLT", .{sym.name(self)});
                try self.plt.addSymbol(index, self);
            }
        }
        if (sym.flags.needs_copy_rel and !sym.flags.has_copy_rel) {
            log.debug("'{s}' needs COPYREL", .{sym.name(self)});
            try self.copy_rel.addSymbol(index, self);
        }
        if (sym.flags.needs_tlsgd) {
            log.debug("'{s}' needs TLSGD", .{sym.name(self)});
            try self.got.addTlsGdSymbol(index, self);
        }
        if (sym.flags.needs_gottp) {
            log.debug("'{s}' needs GOTTP", .{sym.name(self)});
            try self.got.addGotTpSymbol(index, self);
        }
        if (sym.flags.needs_tlsdesc) {
            log.debug("'{s}' needs TLSDESC", .{sym.name(self)});
            try self.got.addTlsDescSymbol(index, self);
        }
    }

    if (self.got.flags.needs_tlsld) {
        log.debug("program needs TLSLD", .{});
        try self.got.addTlsLdSymbol(self);
    }
}

fn linkWithLLD(self: *Elf, arena: Allocator, prog_node: std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = self.base.comp;
    const gpa = comp.gpa;

    const directory = self.base.emit.directory; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.emit.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (comp.module != null) blk: {
        try self.flushModule(arena, prog_node);

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
    const target = comp.root_mod.resolved_target.result;
    const compiler_rt_path: ?[]const u8 = blk: {
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

    var man: Cache.Manifest = undefined;
    defer if (!self.base.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!self.base.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 13);

        try man.addOptionalFile(self.linker_script);
        try man.addOptionalFile(self.version_script);
        man.hash.add(self.allow_undefined_version);
        man.hash.addOptional(self.enable_new_dtags);
        for (comp.objects) |obj| {
            _ = try man.addFile(obj.path, null);
            man.hash.add(obj.must_link);
            man.hash.add(obj.loption);
        }
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        try man.addOptionalFile(compiler_rt_path);

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
        man.hash.addListOfBytes(self.base.rpath_list);
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
        man.hash.addOptionalBytes(comp.sysroot);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
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
            // Any target ELF will use the freebsd osabi if suffixed with "_fbsd".
            const arg = if (target.os.tag == .freebsd)
                try std.fmt.allocPrint(arena, "{s}_fbsd", .{ldm})
            else
                ldm;
            try argv.append("-m");
            try argv.append(arg);
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
        const csu = try CsuObjects.init(arena, comp);
        if (csu.crt0) |v| try argv.append(v);
        if (csu.crti) |v| try argv.append(v);
        if (csu.crtbegin) |v| try argv.append(v);

        // rpaths
        var rpath_table = std.StringHashMap(void).init(gpa);
        defer rpath_table.deinit();
        for (self.base.rpath_list) |rpath| {
            if ((try rpath_table.fetchPut(rpath, {})) == null) {
                try argv.append("-rpath");
                try argv.append(rpath);
            }
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
                assert(obj.path[0] == ':');
                try argv.append("-l");
            }
            try argv.append(obj.path);
        }
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (comp.config.any_sanitize_thread) {
            try argv.append(comp.tsan_static_lib.?.full_object_path);
        }

        // libc
        if (is_exe_or_dyn_lib and
            !comp.skip_linker_dependencies and
            !comp.config.link_libc)
        {
            if (comp.libc_static_lib) |lib| {
                try argv.append(lib.full_object_path);
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
                argv.appendAssumeCapacity(lib_info.path.?);
            }

            if (!as_needed) {
                argv.appendAssumeCapacity("--as-needed");
                as_needed = true;
            }

            // libc++ dep
            if (comp.config.link_libcpp) {
                try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
                try argv.append(comp.libcxx_static_lib.?.full_object_path);
            }

            // libunwind dep
            if (comp.config.link_libunwind) {
                try argv.append(comp.libunwind_static_lib.?.full_object_path);
            }

            // libc dep
            comp.link_error_flags.missing_libc = false;
            if (comp.config.link_libc) {
                if (comp.libc_installation != null) {
                    const needs_grouping = link_mode == .static;
                    if (needs_grouping) try argv.append("--start-group");
                    try argv.appendSlice(target_util.libcFullLinkFlags(target));
                    if (needs_grouping) try argv.append("--end-group");
                } else if (target.isGnuLibC()) {
                    for (glibc.libs) |lib| {
                        const lib_path = try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                            comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                        });
                        try argv.append(lib_path);
                    }
                    try argv.append(try comp.get_libc_crt_file(arena, "libc_nonshared.a"));
                } else if (target.isMusl()) {
                    try argv.append(try comp.get_libc_crt_file(arena, switch (link_mode) {
                        .static => "libc.a",
                        .dynamic => "libc.so",
                    }));
                } else {
                    comp.link_error_flags.missing_libc = true;
                }
            }
        }

        // compiler-rt. Since compiler_rt exports symbols like `memset`, it needs
        // to be after the shared libraries, so they are picked up from the shared
        // libraries, not libcompiler_rt.
        if (compiler_rt_path) |p| {
            try argv.append(p);
        }

        // crt postlude
        if (csu.crtend) |v| try argv.append(v);
        if (csu.crtn) |v| try argv.append(v);

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
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
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

fn writeDwarfAddrAssumeCapacity(self: *Elf, buf: *std.ArrayList(u8), addr: u64) void {
    const target = self.base.comp.root_mod.resolved_target.result;
    const target_endian = target.cpu.arch.endian();
    switch (self.ptr_width) {
        .p32 => mem.writeInt(u32, buf.addManyAsArrayAssumeCapacity(4), @as(u32, @intCast(addr)), target_endian),
        .p64 => mem.writeInt(u64, buf.addManyAsArrayAssumeCapacity(8), addr, target_endian),
    }
}

pub fn writeShdrTable(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    const target = self.base.comp.root_mod.resolved_target.result;
    const target_endian = target.cpu.arch.endian();
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
    const needed_size = self.shdrs.items.len * shsize;

    if (needed_size > self.allocatedSize(shoff)) {
        self.shdr_table_offset = null;
        self.shdr_table_offset = self.findFreeSpace(needed_size, shalign);
    }

    log.debug("writing section headers from 0x{x} to 0x{x}", .{
        self.shdr_table_offset.?,
        self.shdr_table_offset.? + needed_size,
    });

    switch (self.ptr_width) {
        .p32 => {
            const buf = try gpa.alloc(elf.Elf32_Shdr, self.shdrs.items.len);
            defer gpa.free(buf);

            for (buf, 0..) |*shdr, i| {
                assert(self.shdrs.items[i].sh_offset != math.maxInt(u64));
                shdr.* = shdrTo32(self.shdrs.items[i]);
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf32_Shdr, shdr);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
        },
        .p64 => {
            const buf = try gpa.alloc(elf.Elf64_Shdr, self.shdrs.items.len);
            defer gpa.free(buf);

            for (buf, 0..) |*shdr, i| {
                assert(self.shdrs.items[i].sh_offset != math.maxInt(u64));
                shdr.* = self.shdrs.items[i];
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
    const target = self.base.comp.root_mod.resolved_target.result;
    const target_endian = target.cpu.arch.endian();
    const foreign_endian = target_endian != builtin.cpu.arch.endian();
    const phdr_table = &self.phdrs.items[self.phdr_table_index.?];

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
    const comp = self.base.comp;
    if (comp.link_errors.items.len > 0) return; // We had errors, so skip flushing to render the output unusable

    var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

    var index: usize = 0;
    hdr_buf[0..4].* = elf.MAGIC.*;
    index += 4;

    hdr_buf[index] = switch (self.ptr_width) {
        .p32 => elf.ELFCLASS32,
        .p64 => elf.ELFCLASS64,
    };
    index += 1;

    const target = comp.root_mod.resolved_target.result;
    const endian = target.cpu.arch.endian();
    hdr_buf[index] = switch (endian) {
        .little => elf.ELFDATA2LSB,
        .big => elf.ELFDATA2MSB,
    };
    index += 1;

    hdr_buf[index] = 1; // ELF version
    index += 1;

    // OS ABI, often set to 0 regardless of target platform
    // ABI Version, possibly used by glibc but not by static executables
    // padding
    @memset(hdr_buf[index..][0..9], 0);
    index += 9;

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

    const machine = target.cpu.arch.toElfMachine();
    mem.writeInt(u16, hdr_buf[index..][0..2], @intFromEnum(machine), endian);
    index += 2;

    // ELF Version, again
    mem.writeInt(u32, hdr_buf[index..][0..4], 1, endian);
    index += 4;

    const e_entry = if (self.entry_index) |entry_index|
        @as(u64, @intCast(self.symbol(entry_index).address(.{}, self)))
    else
        0;
    const phdr_table_offset = if (self.phdr_table_index) |phndx| self.phdrs.items[phndx].p_offset else 0;
    switch (self.ptr_width) {
        .p32 => {
            mem.writeInt(u32, hdr_buf[index..][0..4], @as(u32, @intCast(e_entry)), endian);
            index += 4;

            // e_phoff
            mem.writeInt(u32, hdr_buf[index..][0..4], @as(u32, @intCast(phdr_table_offset)), endian);
            index += 4;

            // e_shoff
            mem.writeInt(u32, hdr_buf[index..][0..4], @as(u32, @intCast(self.shdr_table_offset.?)), endian);
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

    const e_shnum = @as(u16, @intCast(self.shdrs.items.len));
    mem.writeInt(u16, hdr_buf[index..][0..2], e_shnum, endian);
    index += 2;

    mem.writeInt(u16, hdr_buf[index..][0..2], @intCast(self.shstrtab_section_index.?), endian);
    index += 2;

    assert(index == e_ehsize);

    try self.base.file.?.pwriteAll(hdr_buf[0..index], 0);
}

pub fn freeDecl(self: *Elf, decl_index: InternPool.DeclIndex) void {
    if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    return self.zigObjectPtr().?.freeDecl(self, decl_index);
}

pub fn updateFunc(self: *Elf, mod: *Module, func_index: InternPool.Index, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(mod, func_index, air, liveness);
    return self.zigObjectPtr().?.updateFunc(self, mod, func_index, air, liveness);
}

pub fn updateDecl(
    self: *Elf,
    mod: *Module,
    decl_index: InternPool.DeclIndex,
) link.File.UpdateDeclError!void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(mod, decl_index);
    return self.zigObjectPtr().?.updateDecl(self, mod, decl_index);
}

pub fn lowerUnnamedConst(self: *Elf, val: Value, decl_index: InternPool.DeclIndex) !u32 {
    return self.zigObjectPtr().?.lowerUnnamedConst(self, val, decl_index);
}

pub fn updateExports(
    self: *Elf,
    mod: *Module,
    exported: Module.Exported,
    exports: []const *Module.Export,
) link.File.UpdateExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (self.llvm_object) |llvm_object| return llvm_object.updateExports(mod, exported, exports);
    return self.zigObjectPtr().?.updateExports(self, mod, exported, exports);
}

pub fn updateDeclLineNumber(self: *Elf, mod: *Module, decl_index: InternPool.DeclIndex) !void {
    if (self.llvm_object) |_| return;
    return self.zigObjectPtr().?.updateDeclLineNumber(mod, decl_index);
}

pub fn deleteDeclExport(
    self: *Elf,
    decl_index: InternPool.DeclIndex,
    name: InternPool.NullTerminatedString,
) void {
    if (self.llvm_object) |_| return;
    return self.zigObjectPtr().?.deleteDeclExport(self, decl_index, name);
}

fn addLinkerDefinedSymbols(self: *Elf) !void {
    const comp = self.base.comp;
    const gpa = comp.gpa;

    const linker_defined_index = self.linker_defined_index orelse return;
    const linker_defined = self.file(linker_defined_index).?.linker_defined;
    self.dynamic_index = try linker_defined.addGlobal("_DYNAMIC", self);
    self.ehdr_start_index = try linker_defined.addGlobal("__ehdr_start", self);
    self.init_array_start_index = try linker_defined.addGlobal("__init_array_start", self);
    self.init_array_end_index = try linker_defined.addGlobal("__init_array_end", self);
    self.fini_array_start_index = try linker_defined.addGlobal("__fini_array_start", self);
    self.fini_array_end_index = try linker_defined.addGlobal("__fini_array_end", self);
    self.preinit_array_start_index = try linker_defined.addGlobal("__preinit_array_start", self);
    self.preinit_array_end_index = try linker_defined.addGlobal("__preinit_array_end", self);
    self.got_index = try linker_defined.addGlobal("_GLOBAL_OFFSET_TABLE_", self);
    self.plt_index = try linker_defined.addGlobal("_PROCEDURE_LINKAGE_TABLE_", self);
    self.end_index = try linker_defined.addGlobal("_end", self);

    if (comp.link_eh_frame_hdr) {
        self.gnu_eh_frame_hdr_index = try linker_defined.addGlobal("__GNU_EH_FRAME_HDR", self);
    }

    if (self.globalByName("__dso_handle")) |index| {
        if (self.symbol(index).file(self) == null)
            self.dso_handle_index = try linker_defined.addGlobal("__dso_handle", self);
    }

    self.rela_iplt_start_index = try linker_defined.addGlobal("__rela_iplt_start", self);
    self.rela_iplt_end_index = try linker_defined.addGlobal("__rela_iplt_end", self);

    for (self.shdrs.items) |shdr| {
        if (self.getStartStopBasename(shdr)) |name| {
            try self.start_stop_indexes.ensureUnusedCapacity(gpa, 2);

            const start = try std.fmt.allocPrintZ(gpa, "__start_{s}", .{name});
            defer gpa.free(start);
            const stop = try std.fmt.allocPrintZ(gpa, "__stop_{s}", .{name});
            defer gpa.free(stop);

            self.start_stop_indexes.appendAssumeCapacity(try linker_defined.addGlobal(start, self));
            self.start_stop_indexes.appendAssumeCapacity(try linker_defined.addGlobal(stop, self));
        }
    }

    if (self.getTarget().cpu.arch == .riscv64 and self.isEffectivelyDynLib()) {
        self.global_pointer_index = try linker_defined.addGlobal("__global_pointer$", self);
    }

    linker_defined.resolveSymbols(self);
}

fn allocateLinkerDefinedSymbols(self: *Elf) void {
    const comp = self.base.comp;
    const link_mode = comp.config.link_mode;

    // _DYNAMIC
    if (self.dynamic_section_index) |shndx| {
        const shdr = &self.shdrs.items[shndx];
        const symbol_ptr = self.symbol(self.dynamic_index.?);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = shndx;
    }

    // __ehdr_start
    {
        const symbol_ptr = self.symbol(self.ehdr_start_index.?);
        symbol_ptr.value = @intCast(self.image_base);
        symbol_ptr.output_section_index = 1;
    }

    // __init_array_start, __init_array_end
    if (self.sectionByName(".init_array")) |shndx| {
        const start_sym = self.symbol(self.init_array_start_index.?);
        const end_sym = self.symbol(self.init_array_end_index.?);
        const shdr = &self.shdrs.items[shndx];
        start_sym.output_section_index = shndx;
        start_sym.value = @intCast(shdr.sh_addr);
        end_sym.output_section_index = shndx;
        end_sym.value = @intCast(shdr.sh_addr + shdr.sh_size);
    }

    // __fini_array_start, __fini_array_end
    if (self.sectionByName(".fini_array")) |shndx| {
        const start_sym = self.symbol(self.fini_array_start_index.?);
        const end_sym = self.symbol(self.fini_array_end_index.?);
        const shdr = &self.shdrs.items[shndx];
        start_sym.output_section_index = shndx;
        start_sym.value = @intCast(shdr.sh_addr);
        end_sym.output_section_index = shndx;
        end_sym.value = @intCast(shdr.sh_addr + shdr.sh_size);
    }

    // __preinit_array_start, __preinit_array_end
    if (self.sectionByName(".preinit_array")) |shndx| {
        const start_sym = self.symbol(self.preinit_array_start_index.?);
        const end_sym = self.symbol(self.preinit_array_end_index.?);
        const shdr = &self.shdrs.items[shndx];
        start_sym.output_section_index = shndx;
        start_sym.value = @intCast(shdr.sh_addr);
        end_sym.output_section_index = shndx;
        end_sym.value = @intCast(shdr.sh_addr + shdr.sh_size);
    }

    // _GLOBAL_OFFSET_TABLE_
    if (self.getTarget().cpu.arch == .x86_64) {
        if (self.got_plt_section_index) |shndx| {
            const shdr = self.shdrs.items[shndx];
            const sym = self.symbol(self.got_index.?);
            sym.value = @intCast(shdr.sh_addr);
            sym.output_section_index = shndx;
        }
    } else {
        if (self.got_section_index) |shndx| {
            const shdr = self.shdrs.items[shndx];
            const sym = self.symbol(self.got_index.?);
            sym.value = @intCast(shdr.sh_addr);
            sym.output_section_index = shndx;
        }
    }

    // _PROCEDURE_LINKAGE_TABLE_
    if (self.plt_section_index) |shndx| {
        const shdr = &self.shdrs.items[shndx];
        const symbol_ptr = self.symbol(self.plt_index.?);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = shndx;
    }

    // __dso_handle
    if (self.dso_handle_index) |index| {
        const shdr = &self.shdrs.items[1];
        const symbol_ptr = self.symbol(index);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = 0;
    }

    // __GNU_EH_FRAME_HDR
    if (self.eh_frame_hdr_section_index) |shndx| {
        const shdr = &self.shdrs.items[shndx];
        const symbol_ptr = self.symbol(self.gnu_eh_frame_hdr_index.?);
        symbol_ptr.value = @intCast(shdr.sh_addr);
        symbol_ptr.output_section_index = shndx;
    }

    // __rela_iplt_start, __rela_iplt_end
    if (self.rela_dyn_section_index) |shndx| blk: {
        if (link_mode != .static or comp.config.pie) break :blk;
        const shdr = &self.shdrs.items[shndx];
        const end_addr = shdr.sh_addr + shdr.sh_size;
        const start_addr = end_addr - self.calcNumIRelativeRelocs() * @sizeOf(elf.Elf64_Rela);
        const start_sym = self.symbol(self.rela_iplt_start_index.?);
        const end_sym = self.symbol(self.rela_iplt_end_index.?);
        start_sym.value = @intCast(start_addr);
        start_sym.output_section_index = shndx;
        end_sym.value = @intCast(end_addr);
        end_sym.output_section_index = shndx;
    }

    // _end
    {
        const end_symbol = self.symbol(self.end_index.?);
        for (self.shdrs.items, 0..) |shdr, shndx| {
            if (shdr.sh_flags & elf.SHF_ALLOC != 0) {
                end_symbol.value = @intCast(shdr.sh_addr + shdr.sh_size);
                end_symbol.output_section_index = @intCast(shndx);
            }
        }
    }

    // __start_*, __stop_*
    {
        var index: usize = 0;
        while (index < self.start_stop_indexes.items.len) : (index += 2) {
            const start = self.symbol(self.start_stop_indexes.items[index]);
            const name = start.name(self);
            const stop = self.symbol(self.start_stop_indexes.items[index + 1]);
            const shndx = self.sectionByName(name["__start_".len..]).?;
            const shdr = &self.shdrs.items[shndx];
            start.value = @intCast(shdr.sh_addr);
            start.output_section_index = shndx;
            stop.value = @intCast(shdr.sh_addr + shdr.sh_size);
            stop.output_section_index = shndx;
        }
    }

    // __global_pointer$
    if (self.global_pointer_index) |index| {
        const sym = self.symbol(index);
        if (self.sectionByName(".sdata")) |shndx| {
            const shdr = self.shdrs.items[shndx];
            sym.value = @intCast(shdr.sh_addr + 0x800);
            sym.output_section_index = shndx;
        } else {
            sym.value = 0;
            sym.output_section_index = 0;
        }
    }
}

fn checkDuplicates(self: *Elf) !void {
    const gpa = self.base.comp.gpa;

    var dupes = std.AutoArrayHashMap(Symbol.Index, std.ArrayListUnmanaged(File.Index)).init(gpa);
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
    const msec_index = try self.getOrCreateMergeSection(".comment", elf.SHF_MERGE | elf.SHF_STRINGS, elf.SHT_PROGBITS);
    const msec = self.mergeSection(msec_index);
    const res = try msec.insertZ(self.base.comp.gpa, "zig " ++ builtin.zig_version_string);
    if (res.found_existing) return;
    const msub_index = try self.addMergeSubsection();
    const msub = self.mergeSubsection(msub_index);
    msub.merge_section_index = msec_index;
    msub.string_index = res.key.pos;
    msub.alignment = .@"1";
    msub.size = res.key.len;
    msub.entsize = 1;
    msub.alive = true;
    res.sub.* = msub_index;
}

pub fn resolveMergeSections(self: *Elf) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var has_errors = false;
    for (self.objects.items) |index| {
        const file_ptr = self.file(index).?;
        if (!file_ptr.isAlive()) continue;
        file_ptr.object.initMergeSections(self) catch |err| switch (err) {
            error.MalformedObject => has_errors = true,
            else => |e| return e,
        };
    }

    if (has_errors) return error.FlushFailure;

    for (self.objects.items) |index| {
        const file_ptr = self.file(index).?;
        if (!file_ptr.isAlive()) continue;
        file_ptr.object.resolveMergeSubsections(self) catch |err| switch (err) {
            error.MalformedObject => has_errors = true,
            else => |e| return e,
        };
    }

    if (has_errors) return error.FlushFailure;
}

pub fn finalizeMergeSections(self: *Elf) !void {
    for (self.merge_sections.items) |*msec| {
        try msec.finalize(self);
    }
}

pub fn updateMergeSectionSizes(self: *Elf) !void {
    for (self.merge_sections.items) |*msec| {
        const shdr = &self.shdrs.items[msec.output_section_index];
        for (msec.subsections.items) |msub_index| {
            const msub = self.mergeSubsection(msub_index);
            assert(msub.alive);
            const offset = msub.alignment.forward(shdr.sh_size);
            const padding = offset - shdr.sh_size;
            msub.value = @intCast(offset);
            shdr.sh_size += padding + msub.size;
            shdr.sh_addralign = @max(shdr.sh_addralign, msub.alignment.toByteUnits() orelse 1);
        }
    }
}

pub fn writeMergeSections(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    for (self.merge_sections.items) |msec| {
        const shdr = self.shdrs.items[msec.output_section_index];
        const size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        try buffer.ensureTotalCapacity(size);
        buffer.appendNTimesAssumeCapacity(0, size);

        for (msec.subsections.items) |msub_index| {
            const msub = self.mergeSubsection(msub_index);
            assert(msub.alive);
            const string = msub.getString(self);
            const off = math.cast(usize, msub.value) orelse return error.Overflow;
            @memcpy(buffer.items[off..][0..string.len], string);
        }

        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
        buffer.clearRetainingCapacity();
    }
}

fn initOutputSections(self: *Elf) !void {
    for (self.objects.items) |index| {
        try self.file(index).?.object.initOutputSections(self);
    }
}

pub fn initMergeSections(self: *Elf) !void {
    for (self.merge_sections.items) |*msec| {
        if (msec.subsections.items.len == 0) continue;
        const name = msec.name(self);
        const shndx = self.sectionByName(name) orelse try self.addSection(.{
            .name = name,
            .type = msec.type,
            .flags = msec.flags,
        });
        msec.output_section_index = shndx;

        var entsize = self.mergeSubsection(msec.subsections.items[0]).entsize;
        for (msec.subsections.items) |index| {
            const msub = self.mergeSubsection(index);
            entsize = @min(entsize, msub.entsize);
        }
        const shdr = &self.shdrs.items[shndx];
        shdr.sh_entsize = entsize;
    }
}

fn initSyntheticSections(self: *Elf) !void {
    const comp = self.base.comp;
    const target = comp.root_mod.resolved_target.result;
    const ptr_size = self.ptrWidthBytes();

    const needs_eh_frame = for (self.objects.items) |index| {
        if (self.file(index).?.object.cies.items.len > 0) break true;
    } else false;
    if (needs_eh_frame) {
        self.eh_frame_section_index = try self.addSection(.{
            .name = ".eh_frame",
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC,
            .addralign = ptr_size,
            .offset = std.math.maxInt(u64),
        });

        if (comp.link_eh_frame_hdr) {
            self.eh_frame_hdr_section_index = try self.addSection(.{
                .name = ".eh_frame_hdr",
                .type = elf.SHT_PROGBITS,
                .flags = elf.SHF_ALLOC,
                .addralign = 4,
                .offset = std.math.maxInt(u64),
            });
        }
    }

    if (self.got.entries.items.len > 0) {
        self.got_section_index = try self.addSection(.{
            .name = ".got",
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .addralign = ptr_size,
            .offset = std.math.maxInt(u64),
        });
    }

    self.got_plt_section_index = try self.addSection(.{
        .name = ".got.plt",
        .type = elf.SHT_PROGBITS,
        .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
        .addralign = @alignOf(u64),
        .offset = std.math.maxInt(u64),
    });

    const needs_rela_dyn = blk: {
        if (self.got.flags.needs_rela or self.got.flags.needs_tlsld or
            self.zig_got.flags.needs_rela or self.copy_rel.symbols.items.len > 0) break :blk true;
        if (self.zigObjectPtr()) |zig_object| {
            if (zig_object.num_dynrelocs > 0) break :blk true;
        }
        for (self.objects.items) |index| {
            if (self.file(index).?.object.num_dynrelocs > 0) break :blk true;
        }
        break :blk false;
    };
    if (needs_rela_dyn) {
        self.rela_dyn_section_index = try self.addSection(.{
            .name = ".rela.dyn",
            .type = elf.SHT_RELA,
            .flags = elf.SHF_ALLOC,
            .addralign = @alignOf(elf.Elf64_Rela),
            .entsize = @sizeOf(elf.Elf64_Rela),
            .offset = std.math.maxInt(u64),
        });
    }

    if (self.plt.symbols.items.len > 0) {
        self.plt_section_index = try self.addSection(.{
            .name = ".plt",
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            .addralign = 16,
            .offset = std.math.maxInt(u64),
        });
        self.rela_plt_section_index = try self.addSection(.{
            .name = ".rela.plt",
            .type = elf.SHT_RELA,
            .flags = elf.SHF_ALLOC,
            .addralign = @alignOf(elf.Elf64_Rela),
            .entsize = @sizeOf(elf.Elf64_Rela),
            .offset = std.math.maxInt(u64),
        });
    }

    if (self.plt_got.symbols.items.len > 0) {
        self.plt_got_section_index = try self.addSection(.{
            .name = ".plt.got",
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            .addralign = 16,
            .offset = std.math.maxInt(u64),
        });
    }

    if (self.copy_rel.symbols.items.len > 0) {
        self.copy_rel_section_index = try self.addSection(.{
            .name = ".copyrel",
            .type = elf.SHT_NOBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .offset = std.math.maxInt(u64),
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
    if (needs_interp) {
        self.interp_section_index = try self.addSection(.{
            .name = ".interp",
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC,
            .addralign = 1,
            .offset = std.math.maxInt(u64),
        });
    }

    if (self.isEffectivelyDynLib() or self.shared_objects.items.len > 0 or comp.config.pie) {
        self.dynstrtab_section_index = try self.addSection(.{
            .name = ".dynstr",
            .flags = elf.SHF_ALLOC,
            .type = elf.SHT_STRTAB,
            .entsize = 1,
            .addralign = 1,
            .offset = std.math.maxInt(u64),
        });
        self.dynamic_section_index = try self.addSection(.{
            .name = ".dynamic",
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .type = elf.SHT_DYNAMIC,
            .entsize = @sizeOf(elf.Elf64_Dyn),
            .addralign = @alignOf(elf.Elf64_Dyn),
            .offset = std.math.maxInt(u64),
        });
        self.dynsymtab_section_index = try self.addSection(.{
            .name = ".dynsym",
            .flags = elf.SHF_ALLOC,
            .type = elf.SHT_DYNSYM,
            .addralign = @alignOf(elf.Elf64_Sym),
            .entsize = @sizeOf(elf.Elf64_Sym),
            .info = 1,
            .offset = std.math.maxInt(u64),
        });
        self.hash_section_index = try self.addSection(.{
            .name = ".hash",
            .flags = elf.SHF_ALLOC,
            .type = elf.SHT_HASH,
            .addralign = 4,
            .entsize = 4,
            .offset = std.math.maxInt(u64),
        });
        self.gnu_hash_section_index = try self.addSection(.{
            .name = ".gnu.hash",
            .flags = elf.SHF_ALLOC,
            .type = elf.SHT_GNU_HASH,
            .addralign = 8,
            .offset = std.math.maxInt(u64),
        });

        const needs_versions = for (self.dynsym.entries.items) |entry| {
            const sym = self.symbol(entry.symbol_index);
            if (sym.flags.import and sym.version_index & elf.VERSYM_VERSION > elf.VER_NDX_GLOBAL) break true;
        } else false;
        if (needs_versions) {
            self.versym_section_index = try self.addSection(.{
                .name = ".gnu.version",
                .flags = elf.SHF_ALLOC,
                .type = elf.SHT_GNU_VERSYM,
                .addralign = @alignOf(elf.Elf64_Versym),
                .entsize = @sizeOf(elf.Elf64_Versym),
                .offset = std.math.maxInt(u64),
            });
            self.verneed_section_index = try self.addSection(.{
                .name = ".gnu.version_r",
                .flags = elf.SHF_ALLOC,
                .type = elf.SHT_GNU_VERNEED,
                .addralign = @alignOf(elf.Elf64_Verneed),
                .offset = std.math.maxInt(u64),
            });
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
    if (self.symtab_section_index == null) {
        self.symtab_section_index = try self.addSection(.{
            .name = ".symtab",
            .type = elf.SHT_SYMTAB,
            .addralign = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym),
            .entsize = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym),
            .offset = std.math.maxInt(u64),
        });
    }
    if (self.strtab_section_index == null) {
        self.strtab_section_index = try self.addSection(.{
            .name = ".strtab",
            .type = elf.SHT_STRTAB,
            .entsize = 1,
            .addralign = 1,
            .offset = std.math.maxInt(u64),
        });
    }
}

pub fn initShStrtab(self: *Elf) !void {
    if (self.shstrtab_section_index == null) {
        self.shstrtab_section_index = try self.addSection(.{
            .name = ".shstrtab",
            .type = elf.SHT_STRTAB,
            .entsize = 1,
            .addralign = 1,
            .offset = std.math.maxInt(u64),
        });
    }
}

fn initSpecialPhdrs(self: *Elf) !void {
    comptime assert(max_number_of_special_phdrs == 5);

    if (self.interp_section_index != null) {
        self.phdr_interp_index = try self.addPhdr(.{
            .type = elf.PT_INTERP,
            .flags = elf.PF_R,
            .@"align" = 1,
        });
    }
    if (self.dynamic_section_index != null) {
        self.phdr_dynamic_index = try self.addPhdr(.{
            .type = elf.PT_DYNAMIC,
            .flags = elf.PF_R | elf.PF_W,
        });
    }
    if (self.eh_frame_hdr_section_index != null) {
        self.phdr_gnu_eh_frame_index = try self.addPhdr(.{
            .type = elf.PT_GNU_EH_FRAME,
            .flags = elf.PF_R,
        });
    }
    self.phdr_gnu_stack_index = try self.addPhdr(.{
        .type = elf.PT_GNU_STACK,
        .flags = elf.PF_W | elf.PF_R,
        .memsz = self.base.stack_size,
        .@"align" = 1,
    });

    const has_tls = for (self.shdrs.items) |shdr| {
        if (shdr.sh_flags & elf.SHF_TLS != 0) break true;
    } else false;
    if (has_tls) {
        self.phdr_tls_index = try self.addPhdr(.{
            .type = elf.PT_TLS,
            .flags = elf.PF_R,
            .@"align" = 1,
        });
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

    const Entry = struct {
        priority: i32,
        atom_index: Atom.Index,

        pub fn lessThan(ctx: *Elf, lhs: @This(), rhs: @This()) bool {
            if (lhs.priority == rhs.priority) {
                return ctx.atom(lhs.atom_index).?.priority(ctx) < ctx.atom(rhs.atom_index).?.priority(ctx);
            }
            return lhs.priority < rhs.priority;
        }
    };

    for (self.shdrs.items, 0..) |shdr, shndx| {
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;

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

        const atom_list = self.output_sections.getPtr(@intCast(shndx)).?;
        if (atom_list.items.len == 0) continue;

        var entries = std.ArrayList(Entry).init(gpa);
        try entries.ensureTotalCapacityPrecise(atom_list.items.len);
        defer entries.deinit();

        for (atom_list.items) |atom_index| {
            const atom_ptr = self.atom(atom_index).?;
            const object = atom_ptr.file(self).?.object;
            const priority = blk: {
                if (is_ctor_dtor) {
                    if (mem.indexOf(u8, object.path, "crtbegin") != null) break :blk std.math.minInt(i32);
                    if (mem.indexOf(u8, object.path, "crtend") != null) break :blk std.math.maxInt(i32);
                }
                const default: i32 = if (is_ctor_dtor) -1 else std.math.maxInt(i32);
                const name = atom_ptr.name(self);
                var it = mem.splitBackwards(u8, name, ".");
                const priority = std.fmt.parseUnsigned(u16, it.first(), 10) catch default;
                break :blk priority;
            };
            entries.appendAssumeCapacity(.{ .priority = priority, .atom_index = atom_index });
        }

        mem.sort(Entry, entries.items, self, Entry.lessThan);

        atom_list.clearRetainingCapacity();
        for (entries.items) |entry| {
            atom_list.appendAssumeCapacity(entry.atom_index);
        }
    }
}

fn setDynamicSection(self: *Elf, rpaths: []const []const u8) !void {
    if (self.dynamic_section_index == null) return;

    for (self.shared_objects.items) |index| {
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
    if (self.gnu_hash_section_index == null) return;
    self.dynsym.sort(self);
}

fn setVersionSymtab(self: *Elf) !void {
    const gpa = self.base.comp.gpa;
    if (self.versym_section_index == null) return;
    try self.versym.resize(gpa, self.dynsym.count());
    self.versym.items[0] = elf.VER_NDX_LOCAL;
    for (self.dynsym.entries.items, 1..) |entry, i| {
        const sym = self.symbol(entry.symbol_index);
        self.versym.items[i] = sym.version_index;
    }

    if (self.verneed_section_index) |shndx| {
        try self.verneed.generate(self);
        const shdr = &self.shdrs.items[shndx];
        shdr.sh_info = @as(u32, @intCast(self.verneed.verneed.items.len));
    }
}

fn setHashSections(self: *Elf) !void {
    if (self.hash_section_index != null) {
        try self.hash.generate(self);
    }
    if (self.gnu_hash_section_index != null) {
        try self.gnu_hash.calcSize(self);
    }
}

fn phdrRank(phdr: elf.Elf64_Phdr) u8 {
    switch (phdr.p_type) {
        elf.PT_NULL => return 0,
        elf.PT_PHDR => return 1,
        elf.PT_INTERP => return 2,
        elf.PT_LOAD => return 3,
        elf.PT_DYNAMIC, elf.PT_TLS => return 4,
        elf.PT_GNU_EH_FRAME => return 5,
        elf.PT_GNU_STACK => return 6,
        else => return 7,
    }
}

fn sortPhdrs(self: *Elf) error{OutOfMemory}!void {
    const Entry = struct {
        phndx: u16,

        pub fn lessThan(elf_file: *Elf, lhs: @This(), rhs: @This()) bool {
            const lhs_phdr = elf_file.phdrs.items[lhs.phndx];
            const rhs_phdr = elf_file.phdrs.items[rhs.phndx];
            const lhs_rank = phdrRank(lhs_phdr);
            const rhs_rank = phdrRank(rhs_phdr);
            if (lhs_rank == rhs_rank) return lhs_phdr.p_vaddr < rhs_phdr.p_vaddr;
            return lhs_rank < rhs_rank;
        }
    };

    const gpa = self.base.comp.gpa;
    var entries = try std.ArrayList(Entry).initCapacity(gpa, self.phdrs.items.len);
    defer entries.deinit();
    for (0..self.phdrs.items.len) |phndx| {
        entries.appendAssumeCapacity(.{ .phndx = @as(u16, @intCast(phndx)) });
    }

    mem.sort(Entry, entries.items, self, Entry.lessThan);

    const backlinks = try gpa.alloc(u16, entries.items.len);
    defer gpa.free(backlinks);
    for (entries.items, 0..) |entry, i| {
        backlinks[entry.phndx] = @as(u16, @intCast(i));
    }

    const slice = try self.phdrs.toOwnedSlice(gpa);
    defer gpa.free(slice);

    try self.phdrs.ensureTotalCapacityPrecise(gpa, slice.len);
    for (entries.items) |sorted| {
        self.phdrs.appendAssumeCapacity(slice[sorted.phndx]);
    }

    for (&[_]*?u16{
        &self.phdr_zig_load_re_index,
        &self.phdr_zig_got_index,
        &self.phdr_zig_load_ro_index,
        &self.phdr_zig_load_zerofill_index,
        &self.phdr_table_index,
        &self.phdr_table_load_index,
        &self.phdr_interp_index,
        &self.phdr_dynamic_index,
        &self.phdr_gnu_eh_frame_index,
        &self.phdr_tls_index,
    }) |maybe_index| {
        if (maybe_index.*) |*index| {
            index.* = backlinks[index.*];
        }
    }

    {
        var it = self.phdr_to_shdr_table.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.* = backlinks[entry.value_ptr.*];
        }
    }
}

fn shdrRank(self: *Elf, shndx: u32) u8 {
    const shdr = self.shdrs.items[shndx];
    const name = self.getShString(shdr.sh_name);
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
        => return 0xf2,

        elf.SHT_DYNAMIC => return 0xf3,

        elf.SHT_RELA, elf.SHT_GROUP => return 0xf,

        elf.SHT_PROGBITS => if (flags & elf.SHF_ALLOC != 0) {
            if (flags & elf.SHF_EXECINSTR != 0) {
                return 0xf1;
            } else if (flags & elf.SHF_WRITE != 0) {
                return if (flags & elf.SHF_TLS != 0) 0xf4 else 0xf6;
            } else if (mem.eql(u8, name, ".interp")) {
                return 1;
            } else {
                return 0xf0;
            }
        } else {
            if (mem.startsWith(u8, name, ".debug")) {
                return 0xf8;
            } else {
                return 0xf9;
            }
        },

        elf.SHT_NOBITS => return if (flags & elf.SHF_TLS != 0) 0xf5 else 0xf7,
        elf.SHT_SYMTAB => return 0xfa,
        elf.SHT_STRTAB => return if (mem.eql(u8, name, ".dynstr")) 0x4 else 0xfb,
        else => return 0xff,
    }
}

pub fn sortShdrs(self: *Elf) !void {
    const Entry = struct {
        shndx: u32,

        pub fn lessThan(elf_file: *Elf, lhs: @This(), rhs: @This()) bool {
            return elf_file.shdrRank(lhs.shndx) < elf_file.shdrRank(rhs.shndx);
        }
    };

    const gpa = self.base.comp.gpa;
    var entries = try std.ArrayList(Entry).initCapacity(gpa, self.shdrs.items.len);
    defer entries.deinit();
    for (0..self.shdrs.items.len) |shndx| {
        entries.appendAssumeCapacity(.{ .shndx = @intCast(shndx) });
    }

    mem.sort(Entry, entries.items, self, Entry.lessThan);

    const backlinks = try gpa.alloc(u32, entries.items.len);
    defer gpa.free(backlinks);
    for (entries.items, 0..) |entry, i| {
        backlinks[entry.shndx] = @intCast(i);
    }

    const slice = try self.shdrs.toOwnedSlice(gpa);
    defer gpa.free(slice);

    try self.shdrs.ensureTotalCapacityPrecise(gpa, slice.len);
    for (entries.items) |sorted| {
        self.shdrs.appendAssumeCapacity(slice[sorted.shndx]);
    }

    try self.resetShdrIndexes(backlinks);
}

fn resetShdrIndexes(self: *Elf, backlinks: []const u32) !void {
    const gpa = self.base.comp.gpa;

    for (&[_]*?u32{
        &self.eh_frame_section_index,
        &self.eh_frame_rela_section_index,
        &self.eh_frame_hdr_section_index,
        &self.got_section_index,
        &self.symtab_section_index,
        &self.strtab_section_index,
        &self.shstrtab_section_index,
        &self.interp_section_index,
        &self.dynamic_section_index,
        &self.dynsymtab_section_index,
        &self.dynstrtab_section_index,
        &self.hash_section_index,
        &self.gnu_hash_section_index,
        &self.plt_section_index,
        &self.got_plt_section_index,
        &self.plt_got_section_index,
        &self.rela_dyn_section_index,
        &self.rela_plt_section_index,
        &self.copy_rel_section_index,
        &self.versym_section_index,
        &self.verneed_section_index,
        &self.zig_text_section_index,
        &self.zig_got_section_index,
        &self.zig_data_rel_ro_section_index,
        &self.zig_data_section_index,
        &self.zig_bss_section_index,
        &self.debug_str_section_index,
        &self.debug_info_section_index,
        &self.debug_abbrev_section_index,
        &self.debug_aranges_section_index,
        &self.debug_line_section_index,
    }) |maybe_index| {
        if (maybe_index.*) |*index| {
            index.* = backlinks[index.*];
        }
    }

    if (self.symtab_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.strtab_section_index.?;
    }

    if (self.dynamic_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynstrtab_section_index.?;
    }

    if (self.dynsymtab_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynstrtab_section_index.?;
    }

    if (self.hash_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynsymtab_section_index.?;
    }

    if (self.gnu_hash_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynsymtab_section_index.?;
    }

    if (self.versym_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynsymtab_section_index.?;
    }

    if (self.verneed_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynstrtab_section_index.?;
    }

    if (self.rela_dyn_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynsymtab_section_index orelse 0;
    }

    if (self.rela_plt_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.dynsymtab_section_index.?;
        shdr.sh_info = self.plt_section_index.?;
    }

    if (self.eh_frame_rela_section_index) |index| {
        const shdr = &self.shdrs.items[index];
        shdr.sh_link = self.symtab_section_index.?;
        shdr.sh_info = self.eh_frame_section_index.?;
    }

    {
        var output_sections = try self.output_sections.clone(gpa);
        defer output_sections.deinit(gpa);

        self.output_sections.clearRetainingCapacity();

        var it = output_sections.iterator();
        while (it.next()) |entry| {
            const shndx = entry.key_ptr.*;
            const meta = entry.value_ptr.*;
            self.output_sections.putAssumeCapacityNoClobber(backlinks[shndx], meta);
        }
    }

    for (self.merge_sections.items) |*msec| {
        msec.output_section_index = backlinks[msec.output_section_index];
    }

    {
        var output_rela_sections = try self.output_rela_sections.clone(gpa);
        defer output_rela_sections.deinit(gpa);

        self.output_rela_sections.clearRetainingCapacity();

        var it = output_rela_sections.iterator();
        while (it.next()) |entry| {
            const shndx = entry.key_ptr.*;
            var meta = entry.value_ptr.*;
            meta.shndx = backlinks[meta.shndx];
            self.output_rela_sections.putAssumeCapacityNoClobber(backlinks[shndx], meta);
        }
    }

    {
        var last_atom_and_free_list_table = try self.last_atom_and_free_list_table.clone(gpa);
        defer last_atom_and_free_list_table.deinit(gpa);

        self.last_atom_and_free_list_table.clearRetainingCapacity();

        var it = last_atom_and_free_list_table.iterator();
        while (it.next()) |entry| {
            const shndx = entry.key_ptr.*;
            const meta = entry.value_ptr.*;
            self.last_atom_and_free_list_table.putAssumeCapacityNoClobber(backlinks[shndx], meta);
        }
    }

    {
        var phdr_to_shdr_table = try self.phdr_to_shdr_table.clone(gpa);
        defer phdr_to_shdr_table.deinit(gpa);

        self.phdr_to_shdr_table.clearRetainingCapacity();

        var it = phdr_to_shdr_table.iterator();
        while (it.next()) |entry| {
            const shndx = entry.key_ptr.*;
            const phndx = entry.value_ptr.*;
            self.phdr_to_shdr_table.putAssumeCapacityNoClobber(backlinks[shndx], phndx);
        }
    }

    if (self.zigObjectPtr()) |zig_object| {
        for (zig_object.atoms.items) |atom_index| {
            const atom_ptr = self.atom(atom_index) orelse continue;
            atom_ptr.output_section_index = backlinks[atom_ptr.output_section_index];
        }

        for (zig_object.locals()) |local_index| {
            const local = self.symbol(local_index);
            local.output_section_index = backlinks[local.output_section_index];
        }

        for (zig_object.globals()) |global_index| {
            const global = self.symbol(global_index);
            const atom_ptr = global.atom(self) orelse continue;
            if (!atom_ptr.flags.alive) continue;
            // TODO claim unresolved for objects
            if (global.file(self).?.index() != zig_object.index) continue;
            const out_shndx = global.outputShndx() orelse continue;
            global.output_section_index = backlinks[out_shndx];
        }
    }

    for (self.output_rela_sections.keys(), self.output_rela_sections.values()) |shndx, sec| {
        const shdr = &self.shdrs.items[sec.shndx];
        shdr.sh_link = self.symtab_section_index.?;
        shdr.sh_info = shndx;
    }

    for (self.comdat_group_sections.items) |*cg| {
        cg.shndx = backlinks[cg.shndx];
    }
}

fn updateSectionSizes(self: *Elf) !void {
    const target = self.base.comp.root_mod.resolved_target.result;
    for (self.output_sections.keys(), self.output_sections.values()) |shndx, atom_list| {
        const shdr = &self.shdrs.items[shndx];
        if (atom_list.items.len == 0) continue;
        if (self.requiresThunks() and shdr.sh_flags & elf.SHF_EXECINSTR != 0) continue;
        for (atom_list.items) |atom_index| {
            const atom_ptr = self.atom(atom_index) orelse continue;
            if (!atom_ptr.flags.alive) continue;
            const offset = atom_ptr.alignment.forward(shdr.sh_size);
            const padding = offset - shdr.sh_size;
            atom_ptr.value = @intCast(offset);
            shdr.sh_size += padding + atom_ptr.size;
            shdr.sh_addralign = @max(shdr.sh_addralign, atom_ptr.alignment.toByteUnits() orelse 1);
        }
    }

    if (self.requiresThunks()) {
        for (self.output_sections.keys(), self.output_sections.values()) |shndx, atom_list| {
            const shdr = self.shdrs.items[shndx];
            if (shdr.sh_flags & elf.SHF_EXECINSTR == 0) continue;
            if (atom_list.items.len == 0) continue;

            // Create jump/branch range extenders if needed.
            try thunks.createThunks(shndx, self);
        }
    }

    if (self.eh_frame_section_index) |index| {
        self.shdrs.items[index].sh_size = try eh_frame.calcEhFrameSize(self);
    }

    if (self.eh_frame_hdr_section_index) |index| {
        self.shdrs.items[index].sh_size = eh_frame.calcEhFrameHdrSize(self);
    }

    if (self.got_section_index) |index| {
        self.shdrs.items[index].sh_size = self.got.size(self);
    }

    if (self.plt_section_index) |index| {
        self.shdrs.items[index].sh_size = self.plt.size(self);
    }

    if (self.got_plt_section_index) |index| {
        self.shdrs.items[index].sh_size = self.got_plt.size(self);
    }

    if (self.plt_got_section_index) |index| {
        self.shdrs.items[index].sh_size = self.plt_got.size(self);
    }

    if (self.rela_dyn_section_index) |shndx| {
        var num = self.got.numRela(self) + self.copy_rel.numRela() + self.zig_got.numRela();
        if (self.zigObjectPtr()) |zig_object| {
            num += zig_object.num_dynrelocs;
        }
        for (self.objects.items) |index| {
            num += self.file(index).?.object.num_dynrelocs;
        }
        self.shdrs.items[shndx].sh_size = num * @sizeOf(elf.Elf64_Rela);
    }

    if (self.rela_plt_section_index) |index| {
        self.shdrs.items[index].sh_size = self.plt.numRela() * @sizeOf(elf.Elf64_Rela);
    }

    if (self.copy_rel_section_index) |index| {
        try self.copy_rel.updateSectionSize(index, self);
    }

    if (self.interp_section_index) |index| {
        self.shdrs.items[index].sh_size = target.dynamic_linker.get().?.len + 1;
    }

    if (self.hash_section_index) |index| {
        self.shdrs.items[index].sh_size = self.hash.size();
    }

    if (self.gnu_hash_section_index) |index| {
        self.shdrs.items[index].sh_size = self.gnu_hash.size();
    }

    if (self.dynamic_section_index) |index| {
        self.shdrs.items[index].sh_size = self.dynamic.size(self);
    }

    if (self.dynsymtab_section_index) |index| {
        self.shdrs.items[index].sh_size = self.dynsym.size();
    }

    if (self.dynstrtab_section_index) |index| {
        self.shdrs.items[index].sh_size = self.dynstrtab.items.len;
    }

    if (self.versym_section_index) |index| {
        self.shdrs.items[index].sh_size = self.versym.items.len * @sizeOf(elf.Elf64_Versym);
    }

    if (self.verneed_section_index) |index| {
        self.shdrs.items[index].sh_size = self.verneed.size();
    }

    try self.updateSymtabSize();
    self.updateShStrtabSize();
}

pub fn updateShStrtabSize(self: *Elf) void {
    if (self.shstrtab_section_index) |index| {
        self.shdrs.items[index].sh_size = self.shstrtab.items.len;
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
    // First, assume we compile Zig's source incrementally, this gives us:
    var num: u64 = number_of_zig_segments;
    // Next, the estimated maximum number of segments the linker can emit for input sections are:
    num += max_number_of_object_segments;
    // Next, any other non-loadable program headers, including TLS, DYNAMIC, GNU_STACK, GNU_EH_FRAME, INTERP:
    num += max_number_of_special_phdrs;
    // Finally, PHDR program header and corresponding read-only load segment:
    num += 2;
    return num;
}

/// Calculates how many segments (PT_LOAD progam headers) are required
/// to cover the set of sections.
/// We permit a maximum of 3**2 number of segments.
fn calcNumberOfSegments(self: *Elf) usize {
    var covers: [9]bool = [_]bool{false} ** 9;
    for (self.shdrs.items, 0..) |shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        if (self.isZigSection(@intCast(shndx))) continue;
        const flags = shdrToPhdrFlags(shdr.sh_flags);
        covers[flags - 1] = true;
    }
    var count: usize = 0;
    for (covers) |cover| {
        if (cover) count += 1;
    }
    return count;
}

/// Allocates PHDR table in virtual memory and in file.
fn allocatePhdrTable(self: *Elf) error{OutOfMemory}!void {
    const new_load_segments = self.calcNumberOfSegments();
    const phdr_table = &self.phdrs.items[self.phdr_table_index.?];
    const phdr_table_load = &self.phdrs.items[self.phdr_table_load_index.?];

    const ehsize: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Ehdr),
        .p64 => @sizeOf(elf.Elf64_Ehdr),
    };
    const phsize: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Phdr),
        .p64 => @sizeOf(elf.Elf64_Phdr),
    };
    const needed_size = (self.phdrs.items.len + new_load_segments) * phsize;
    const available_space = self.allocatedSize(phdr_table.p_offset);

    if (needed_size > available_space) {
        // In this case, we have two options:
        // 1. increase the available padding for EHDR + PHDR table so that we don't overflow it
        //    (revisit getMaxNumberOfPhdrs())
        // 2. shift everything in file to free more space for EHDR + PHDR table
        // TODO verify `getMaxNumberOfPhdrs()` is accurate and convert this into no-op
        var err = try self.addErrorWithNotes(1);
        try err.addMsg(self, "fatal linker error: not enough space reserved for EHDR and PHDR table", .{});
        try err.addNote(self, "required 0x{x}, available 0x{x}", .{ needed_size, available_space });
    }

    phdr_table_load.p_filesz = needed_size + ehsize;
    phdr_table_load.p_memsz = needed_size + ehsize;
    phdr_table.p_filesz = needed_size;
    phdr_table.p_memsz = needed_size;
}

/// Allocates alloc sections and creates load segments for sections
/// extracted from input object files.
pub fn allocateAllocSections(self: *Elf) error{OutOfMemory}!void {
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

    var alignment = Align{};
    for (self.shdrs.items, 0..) |shdr, i| {
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

    for (self.shdrs.items, 0..) |shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC == 0) continue;
        if (self.isZigSection(@intCast(shndx))) continue;
        const flags = shdrToPhdrFlags(shdr.sh_flags);
        try covers[flags - 1].append(@intCast(shndx));
    }

    // Now we can proceed with allocating the sections in virtual memory.
    // As the base address we take the end address of the PHDR table.
    // When allocating we first find the largest required alignment
    // of any section that is contained in a cover and use it to align
    // the start address of the segement (and first section).
    const phdr_table = &self.phdrs.items[self.phdr_table_load_index.?];
    var addr = phdr_table.p_vaddr + phdr_table.p_memsz;

    for (covers) |cover| {
        if (cover.items.len == 0) continue;

        var @"align": u64 = self.page_size;
        for (cover.items) |shndx| {
            const shdr = self.shdrs.items[shndx];
            if (shdr.sh_type == elf.SHT_NOBITS and shdr.sh_flags & elf.SHF_TLS != 0) continue;
            @"align" = @max(@"align", shdr.sh_addralign);
        }

        addr = mem.alignForward(u64, addr, @"align");

        var memsz: u64 = 0;
        var filesz: u64 = 0;
        var i: usize = 0;
        while (i < cover.items.len) : (i += 1) {
            const shndx = cover.items[i];
            const shdr = &self.shdrs.items[shndx];
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
                    self.shdrs.items[cover.items[i]].sh_type == elf.SHT_NOBITS and
                    self.shdrs.items[cover.items[i]].sh_flags & elf.SHF_TLS != 0) : (i += 1)
                {
                    const tbss_shndx = cover.items[i];
                    const tbss_shdr = &self.shdrs.items[tbss_shndx];
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

        const first = self.shdrs.items[cover.items[0]];
        var off = self.findFreeSpace(filesz, @"align");
        const phndx = try self.addPhdr(.{
            .type = elf.PT_LOAD,
            .offset = off,
            .addr = first.sh_addr,
            .memsz = memsz,
            .filesz = filesz,
            .@"align" = @"align",
            .flags = shdrToPhdrFlags(first.sh_flags),
        });

        for (cover.items) |shndx| {
            const shdr = &self.shdrs.items[shndx];
            if (shdr.sh_type == elf.SHT_NOBITS) {
                shdr.sh_offset = 0;
                continue;
            }
            off = alignment.@"align"(shndx, shdr.sh_addralign, off);
            shdr.sh_offset = off;
            off += shdr.sh_size;
            try self.phdr_to_shdr_table.putNoClobber(gpa, shndx, phndx);
        }

        addr = mem.alignForward(u64, addr, self.page_size);
    }
}

/// Allocates non-alloc sections (debug info, symtabs, etc.).
pub fn allocateNonAllocSections(self: *Elf) !void {
    for (self.shdrs.items, 0..) |*shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_flags & elf.SHF_ALLOC != 0) continue;
        const needed_size = shdr.sh_size;
        if (needed_size > self.allocatedSize(shdr.sh_offset)) {
            shdr.sh_size = 0;
            const new_offset = self.findFreeSpace(needed_size, shdr.sh_addralign);

            if (self.isDebugSection(@intCast(shndx))) {
                log.debug("moving {s} from 0x{x} to 0x{x}", .{
                    self.getShString(shdr.sh_name),
                    shdr.sh_offset,
                    new_offset,
                });
                const zig_object = self.zigObjectPtr().?;
                const existing_size = blk: {
                    if (shndx == self.debug_info_section_index.?)
                        break :blk zig_object.debug_info_section_zig_size;
                    if (shndx == self.debug_abbrev_section_index.?)
                        break :blk zig_object.debug_abbrev_section_zig_size;
                    if (shndx == self.debug_str_section_index.?)
                        break :blk zig_object.debug_str_section_zig_size;
                    if (shndx == self.debug_aranges_section_index.?)
                        break :blk zig_object.debug_aranges_section_zig_size;
                    if (shndx == self.debug_line_section_index.?)
                        break :blk zig_object.debug_line_section_zig_size;
                    unreachable;
                };
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
    for (&[_]struct { ?u16, ?u32 }{
        .{ self.phdr_interp_index, self.interp_section_index },
        .{ self.phdr_dynamic_index, self.dynamic_section_index },
        .{ self.phdr_gnu_eh_frame_index, self.eh_frame_hdr_section_index },
    }) |pair| {
        if (pair[0]) |index| {
            const shdr = self.shdrs.items[pair[1].?];
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
    if (self.phdr_tls_index) |index| {
        const slice = self.shdrs.items;
        const phdr = &self.phdrs.items[index];
        var shndx: u32 = 0;
        while (shndx < slice.len) {
            const shdr = slice[shndx];
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

            while (shndx < slice.len) : (shndx += 1) {
                const next = slice[shndx];
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

    var undefs = std.AutoHashMap(Symbol.Index, std.ArrayList(Atom.Index)).init(gpa);
    defer {
        var it = undefs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        undefs.deinit();
    }

    var has_reloc_errors = false;

    // TODO iterate over `output_sections` directly
    for (self.shdrs.items, 0..) |shdr, shndx| {
        if (shdr.sh_type == elf.SHT_NULL) continue;
        if (shdr.sh_type == elf.SHT_NOBITS) continue;

        const atom_list = self.output_sections.get(@intCast(shndx)) orelse continue;
        if (atom_list.items.len == 0) continue;

        log.debug("writing atoms in '{s}' section", .{self.getShString(shdr.sh_name)});

        // TODO really, really handle debug section separately
        const base_offset = if (self.isDebugSection(@intCast(shndx))) blk: {
            const zig_object = self.zigObjectPtr().?;
            if (shndx == self.debug_info_section_index.?)
                break :blk zig_object.debug_info_section_zig_size;
            if (shndx == self.debug_abbrev_section_index.?)
                break :blk zig_object.debug_abbrev_section_zig_size;
            if (shndx == self.debug_str_section_index.?)
                break :blk zig_object.debug_str_section_zig_size;
            if (shndx == self.debug_aranges_section_index.?)
                break :blk zig_object.debug_aranges_section_zig_size;
            if (shndx == self.debug_line_section_index.?)
                break :blk zig_object.debug_line_section_zig_size;
            unreachable;
        } else 0;
        const sh_offset = shdr.sh_offset + base_offset;
        const sh_size = math.cast(usize, shdr.sh_size - base_offset) orelse return error.Overflow;

        const buffer = try gpa.alloc(u8, sh_size);
        defer gpa.free(buffer);
        const padding_byte: u8 = if (shdr.sh_type == elf.SHT_PROGBITS and
            shdr.sh_flags & elf.SHF_EXECINSTR != 0 and self.getTarget().cpu.arch == .x86_64)
            0xcc // int3
        else
            0;
        @memset(buffer, padding_byte);

        for (atom_list.items) |atom_index| {
            const atom_ptr = self.atom(atom_index).?;
            assert(atom_ptr.flags.alive);

            const offset = math.cast(usize, atom_ptr.value - @as(i64, @intCast(base_offset))) orelse
                return error.Overflow;
            const size = math.cast(usize, atom_ptr.size) orelse return error.Overflow;

            log.debug("writing atom({d}) at 0x{x}", .{ atom_index, sh_offset + offset });

            // TODO decompress directly into provided buffer
            const out_code = buffer[offset..][0..size];
            const in_code = switch (atom_ptr.file(self).?) {
                .object => |x| try x.codeDecompressAlloc(self, atom_index),
                .zig_object => |x| try x.codeAlloc(self, atom_index),
                else => unreachable,
            };
            defer gpa.free(in_code);
            @memcpy(out_code, in_code);

            const res = if (shdr.sh_flags & elf.SHF_ALLOC == 0)
                atom_ptr.resolveRelocsNonAlloc(self, out_code, &undefs)
            else
                atom_ptr.resolveRelocsAlloc(self, out_code);
            _ = res catch |err| switch (err) {
                error.UnsupportedCpuArch => {
                    try self.reportUnsupportedCpuArch();
                    return error.FlushFailure;
                },
                error.RelocFailure, error.RelaxFailure => has_reloc_errors = true,
                else => |e| return e,
            };
        }

        try self.base.file.?.pwriteAll(buffer, sh_offset);
    }

    if (self.requiresThunks()) {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();

        for (self.thunks.items) |th| {
            const thunk_size = th.size(self);
            try buffer.ensureUnusedCapacity(thunk_size);
            const shdr = self.shdrs.items[th.output_section_index];
            const offset = @as(u64, @intCast(th.value)) + shdr.sh_offset;
            try th.write(self, buffer.writer());
            assert(buffer.items.len == thunk_size);
            try self.base.file.?.pwriteAll(buffer.items, offset);
            buffer.clearRetainingCapacity();
        }
    }

    try self.reportUndefinedSymbols(&undefs);

    if (has_reloc_errors) return error.FlushFailure;
}

pub fn updateSymtabSize(self: *Elf) !void {
    var nlocals: u32 = 0;
    var nglobals: u32 = 0;
    var strsize: u32 = 0;

    const gpa = self.base.comp.gpa;
    var files = std.ArrayList(File.Index).init(gpa);
    defer files.deinit();
    try files.ensureTotalCapacityPrecise(self.objects.items.len + self.shared_objects.items.len + 2);

    if (self.zig_object_index) |index| files.appendAssumeCapacity(index);
    for (self.objects.items) |index| files.appendAssumeCapacity(index);
    for (self.shared_objects.items) |index| files.appendAssumeCapacity(index);
    if (self.linker_defined_index) |index| files.appendAssumeCapacity(index);

    // Section symbols
    for (self.output_sections.keys()) |_| {
        nlocals += 1;
    }
    if (self.eh_frame_section_index) |_| {
        nlocals += 1;
    }
    nlocals += @intCast(self.merge_sections.items.len);

    if (self.requiresThunks()) for (self.thunks.items) |*th| {
        th.output_symtab_ctx.ilocal = nlocals + 1;
        th.calcSymtabSize(self);
        nlocals += th.output_symtab_ctx.nlocals;
        strsize += th.output_symtab_ctx.strsize;
    };

    for (files.items) |index| {
        const file_ptr = self.file(index).?;
        const ctx = switch (file_ptr) {
            inline else => |x| &x.output_symtab_ctx,
        };
        ctx.ilocal = nlocals + 1;
        ctx.iglobal = nglobals + 1;
        try file_ptr.updateSymtabSize(self);
        nlocals += ctx.nlocals;
        nglobals += ctx.nglobals;
        strsize += ctx.strsize;
    }

    if (self.zig_got_section_index) |_| {
        self.zig_got.output_symtab_ctx.ilocal = nlocals + 1;
        self.zig_got.updateSymtabSize(self);
        nlocals += self.zig_got.output_symtab_ctx.nlocals;
        strsize += self.zig_got.output_symtab_ctx.strsize;
    }

    if (self.got_section_index) |_| {
        self.got.output_symtab_ctx.ilocal = nlocals + 1;
        self.got.updateSymtabSize(self);
        nlocals += self.got.output_symtab_ctx.nlocals;
        strsize += self.got.output_symtab_ctx.strsize;
    }

    if (self.plt_section_index) |_| {
        self.plt.output_symtab_ctx.ilocal = nlocals + 1;
        self.plt.updateSymtabSize(self);
        nlocals += self.plt.output_symtab_ctx.nlocals;
        strsize += self.plt.output_symtab_ctx.strsize;
    }

    if (self.plt_got_section_index) |_| {
        self.plt_got.output_symtab_ctx.ilocal = nlocals + 1;
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

    const symtab_shdr = &self.shdrs.items[self.symtab_section_index.?];
    symtab_shdr.sh_info = nlocals + 1;
    symtab_shdr.sh_link = self.strtab_section_index.?;

    const sym_size: u64 = switch (self.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Sym),
        .p64 => @sizeOf(elf.Elf64_Sym),
    };
    const needed_size = (nlocals + nglobals + 1) * sym_size;
    symtab_shdr.sh_size = needed_size;

    const strtab = &self.shdrs.items[self.strtab_section_index.?];
    strtab.sh_size = strsize + 1;
}

fn writeSyntheticSections(self: *Elf) !void {
    const target = self.base.comp.root_mod.resolved_target.result;
    const gpa = self.base.comp.gpa;

    if (self.interp_section_index) |shndx| {
        var buffer: [256]u8 = undefined;
        const interp = target.dynamic_linker.get().?;
        @memcpy(buffer[0..interp.len], interp);
        buffer[interp.len] = 0;
        const contents = buffer[0 .. interp.len + 1];
        const shdr = self.shdrs.items[shndx];
        assert(shdr.sh_size == contents.len);
        try self.base.file.?.pwriteAll(contents, shdr.sh_offset);
    }

    if (self.hash_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        try self.base.file.?.pwriteAll(self.hash.buffer.items, shdr.sh_offset);
    }

    if (self.gnu_hash_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.gnu_hash.size());
        defer buffer.deinit();
        try self.gnu_hash.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.versym_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.versym.items), shdr.sh_offset);
    }

    if (self.verneed_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.verneed.size());
        defer buffer.deinit();
        try self.verneed.write(buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.dynamic_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.dynamic.size(self));
        defer buffer.deinit();
        try self.dynamic.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.dynsymtab_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.dynsym.size());
        defer buffer.deinit();
        try self.dynsym.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.dynstrtab_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        try self.base.file.?.pwriteAll(self.dynstrtab.items, shdr.sh_offset);
    }

    if (self.eh_frame_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, sh_size);
        defer buffer.deinit();
        try eh_frame.writeEhFrame(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.eh_frame_hdr_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        const sh_size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, sh_size);
        defer buffer.deinit();
        try eh_frame.writeEhFrameHdr(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.got_section_index) |index| {
        const shdr = self.shdrs.items[index];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.got.size(self));
        defer buffer.deinit();
        try self.got.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.rela_dyn_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        try self.got.addRela(self);
        try self.copy_rel.addRela(self);
        try self.zig_got.addRela(self);
        self.sortRelaDyn();
        try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.rela_dyn.items), shdr.sh_offset);
    }

    if (self.plt_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.plt.size(self));
        defer buffer.deinit();
        try self.plt.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.got_plt_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.got_plt.size(self));
        defer buffer.deinit();
        try self.got_plt.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.plt_got_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        var buffer = try std.ArrayList(u8).initCapacity(gpa, self.plt_got.size(self));
        defer buffer.deinit();
        try self.plt_got.write(self, buffer.writer());
        try self.base.file.?.pwriteAll(buffer.items, shdr.sh_offset);
    }

    if (self.rela_plt_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        try self.plt.addRela(self);
        try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.rela_plt.items), shdr.sh_offset);
    }

    try self.writeSymtab();
    try self.writeShStrtab();
}

pub fn writeShStrtab(self: *Elf) !void {
    if (self.shstrtab_section_index) |index| {
        const shdr = self.shdrs.items[index];
        log.debug("writing .shstrtab from 0x{x} to 0x{x}", .{ shdr.sh_offset, shdr.sh_offset + shdr.sh_size });
        try self.base.file.?.pwriteAll(self.shstrtab.items, shdr.sh_offset);
    }
}

pub fn writeSymtab(self: *Elf) !void {
    const target = self.base.comp.root_mod.resolved_target.result;
    const gpa = self.base.comp.gpa;
    const symtab_shdr = self.shdrs.items[self.symtab_section_index.?];
    const strtab_shdr = self.shdrs.items[self.strtab_section_index.?];
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
    try self.strtab.ensureUnusedCapacity(gpa, needed_strtab_size);

    self.writeSectionSymbols();

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

    for (self.shared_objects.items) |index| {
        const file_ptr = self.file(index).?;
        file_ptr.writeSymtab(self);
    }

    if (self.linker_defined_index) |index| {
        const file_ptr = self.file(index).?;
        file_ptr.writeSymtab(self);
    }

    if (self.zig_got_section_index) |_| {
        self.zig_got.writeSymtab(self);
    }

    if (self.got_section_index) |_| {
        self.got.writeSymtab(self);
    }

    if (self.plt_section_index) |_| {
        self.plt.writeSymtab(self);
    }

    if (self.plt_got_section_index) |_| {
        self.plt_got.writeSymtab(self);
    }

    const foreign_endian = target.cpu.arch.endian() != builtin.cpu.arch.endian();
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
                    .st_value = @as(u32, @intCast(sym.st_value)),
                    .st_size = @as(u32, @intCast(sym.st_size)),
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

fn writeSectionSymbols(self: *Elf) void {
    var ilocal: u32 = 1;
    for (self.output_sections.keys()) |shndx| {
        const shdr = self.shdrs.items[shndx];
        const out_sym = &self.symtab.items[ilocal];
        out_sym.* = .{
            .st_name = 0,
            .st_value = shdr.sh_addr,
            .st_info = elf.STT_SECTION,
            .st_shndx = @intCast(shndx),
            .st_size = 0,
            .st_other = 0,
        };
        ilocal += 1;
    }

    if (self.eh_frame_section_index) |shndx| {
        const shdr = self.shdrs.items[shndx];
        const out_sym = &self.symtab.items[ilocal];
        out_sym.* = .{
            .st_name = 0,
            .st_value = shdr.sh_addr,
            .st_info = elf.STT_SECTION,
            .st_shndx = @intCast(shndx),
            .st_size = 0,
            .st_other = 0,
        };
        ilocal += 1;
    }

    for (self.merge_sections.items) |msec| {
        const shdr = self.shdrs.items[msec.output_section_index];
        const out_sym = &self.symtab.items[ilocal];
        out_sym.* = .{
            .st_name = 0,
            .st_value = shdr.sh_addr,
            .st_info = elf.STT_SECTION,
            .st_shndx = @intCast(msec.output_section_index),
            .st_size = 0,
            .st_other = 0,
        };
        ilocal += 1;
    }
}

pub fn sectionSymbolOutputSymtabIndex(self: Elf, shndx: u32) u32 {
    if (self.eh_frame_section_index) |index| {
        if (index == shndx) return @intCast(self.output_sections.keys().len + 1);
    }
    const base: usize = if (self.eh_frame_section_index == null) 0 else 1;
    for (self.merge_sections.items, 0..) |msec, index| {
        if (msec.output_section_index == shndx) return @intCast(self.output_sections.keys().len + 1 + index + base);
    }
    return @intCast(self.output_sections.getIndex(shndx).? + 1);
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
    const target = self.base.comp.root_mod.resolved_target.result;
    return @intCast(@divExact(target.ptrBitWidth(), 8));
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
    switch (target.cpu.arch) {
        .x86 => return "elf_i386",
        .aarch64 => return "aarch64linux",
        .aarch64_be => return "aarch64linuxb",
        .arm, .thumb => return "armelf_linux_eabi",
        .armeb, .thumbeb => return "armelfb_linux_eabi",
        .powerpc => return "elf32ppclinux",
        .powerpc64 => return "elf64ppc",
        .powerpc64le => return "elf64lppc",
        .sparc, .sparcel => return "elf32_sparc",
        .sparc64 => return "elf64_sparc",
        .mips => return "elf32btsmip",
        .mipsel => return "elf32ltsmip",
        .mips64 => {
            if (target.abi == .gnuabin32) {
                return "elf32btsmipn32";
            } else {
                return "elf64btsmip";
            }
        },
        .mips64el => {
            if (target.abi == .gnuabin32) {
                return "elf32ltsmipn32";
            } else {
                return "elf64ltsmip";
            }
        },
        .s390x => return "elf64_s390",
        .x86_64 => {
            if (target.abi == .gnux32) {
                return "elf32_x86_64";
            } else {
                return "elf_x86_64";
            }
        },
        .riscv32 => return "elf32lriscv",
        .riscv64 => return "elf64lriscv",
        else => return null,
    }
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

// Provide a blueprint of csu (c-runtime startup) objects for supported
// link modes.
//
// This is for cross-mode targets only. For host-mode targets the system
// compiler can be probed to produce a robust blueprint.
//
// Targets requiring a libc for which zig does not bundle a libc are
// host-mode targets. Unfortunately, host-mode probes are not yet
// implemented. For now the data is hard-coded here. Such targets are
// { freebsd, netbsd, openbsd, dragonfly }.
const CsuObjects = struct {
    crt0: ?[]const u8 = null,
    crti: ?[]const u8 = null,
    crtbegin: ?[]const u8 = null,
    crtend: ?[]const u8 = null,
    crtn: ?[]const u8 = null,

    const InitArgs = struct {};

    fn init(arena: Allocator, comp: *const Compilation) !CsuObjects {
        // crt objects are only required for libc.
        if (!comp.config.link_libc) return .{};

        var result: CsuObjects = .{};

        // Flatten crt cases.
        const mode: enum {
            dynamic_lib,
            dynamic_exe,
            dynamic_pie,
            static_exe,
            static_pie,
        } = switch (comp.config.output_mode) {
            .Obj => return CsuObjects{},
            .Lib => switch (comp.config.link_mode) {
                .dynamic => .dynamic_lib,
                .static => return CsuObjects{},
            },
            .Exe => switch (comp.config.link_mode) {
                .dynamic => if (comp.config.pie) .dynamic_pie else .dynamic_exe,
                .static => if (comp.config.pie) .static_pie else .static_exe,
            },
        };

        const target = comp.root_mod.resolved_target.result;

        if (target.isAndroid()) {
            switch (mode) {
                // zig fmt: off
                .dynamic_lib => result.set( null, null, "crtbegin_so.o",      "crtend_so.o",      null ),
                .dynamic_exe,
                .dynamic_pie => result.set( null, null, "crtbegin_dynamic.o", "crtend_android.o", null ),
                .static_exe,
                .static_pie  => result.set( null, null, "crtbegin_static.o",  "crtend_android.o", null ),
                // zig fmt: on
            }
        } else {
            switch (target.os.tag) {
                .linux => {
                    switch (mode) {
                        // zig fmt: off
                        .dynamic_lib => result.set( null,      "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                        .dynamic_exe => result.set( "crt1.o",  "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                        .dynamic_pie => result.set( "Scrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                        .static_exe  => result.set( "crt1.o",  "crti.o", "crtbeginT.o", "crtend.o",  "crtn.o" ),
                        .static_pie  => result.set( "rcrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                        // zig fmt: on
                    }
                    if (comp.libc_installation) |_| {
                        // hosted-glibc provides crtbegin/end objects in platform/compiler-specific dirs
                        // and they are not known at comptime. For now null-out crtbegin/end objects;
                        // there is no feature loss, zig has never linked those objects in before.
                        result.crtbegin = null;
                        result.crtend = null;
                    } else {
                        // Bundled glibc only has Scrt1.o .
                        if (result.crt0 != null and target.isGnuLibC()) result.crt0 = "Scrt1.o";
                    }
                },
                .dragonfly => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,      "crti.o", "crtbeginS.o",  "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "crt1.o",  "crti.o", "crtbegin.o",   "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "Scrt1.o", "crti.o", "crtbeginS.o",  "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "crt1.o",  "crti.o", "crtbegin.o",   "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "Scrt1.o", "crti.o", "crtbeginS.o",  "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .freebsd => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,      "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "crt1.o",  "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "Scrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "crt1.o",  "crti.o", "crtbeginT.o", "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "Scrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .netbsd => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,     "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "crt0.o", "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "crt0.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "crt0.o", "crti.o", "crtbeginT.o", "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "crt0.o", "crti.o", "crtbeginT.o", "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .openbsd => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,      null, "crtbeginS.o", "crtendS.o", null ),
                    .dynamic_exe,
                    .dynamic_pie => result.set( "crt0.o",  null, "crtbegin.o",  "crtend.o",  null ),
                    .static_exe,
                    .static_pie  => result.set( "rcrt0.o", null, "crtbegin.o",  "crtend.o",  null ),
                    // zig fmt: on
                },
                .haiku => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,          "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "start_dyn.o", "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "start_dyn.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "start_dyn.o", "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "start_dyn.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .solaris, .illumos => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,     "crti.o", null, null, "crtn.o" ),
                    .dynamic_exe,
                    .dynamic_pie => result.set( "crt1.o", "crti.o", null, null, "crtn.o" ),
                    .static_exe,
                    .static_pie  => result.set( null,     null,     null, null, null     ),
                    // zig fmt: on
                },
                else => {},
            }
        }

        // Convert each object to a full pathname.
        if (comp.libc_installation) |lci| {
            const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCRTDir;
            switch (target.os.tag) {
                .dragonfly => {
                    if (result.crt0) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crti) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crtn) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });

                    var gccv: []const u8 = undefined;
                    if (target.os.version_range.semver.isAtLeast(.{ .major = 5, .minor = 4, .patch = 0 }) orelse true) {
                        gccv = "gcc80";
                    } else {
                        gccv = "gcc54";
                    }

                    if (result.crtbegin) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, gccv, obj.* });
                    if (result.crtend) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, gccv, obj.* });
                },
                .haiku => {
                    const gcc_dir_path = lci.gcc_dir orelse return error.LibCInstallationMissingCRTDir;
                    if (result.crt0) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crti) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crtn) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });

                    if (result.crtbegin) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ gcc_dir_path, obj.* });
                    if (result.crtend) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ gcc_dir_path, obj.* });
                },
                else => {
                    inline for (std.meta.fields(@TypeOf(result))) |f| {
                        if (@field(result, f.name)) |*obj| {
                            obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                        }
                    }
                },
            }
        } else {
            inline for (std.meta.fields(@TypeOf(result))) |f| {
                if (@field(result, f.name)) |*obj| {
                    if (comp.crt_files.get(obj.*)) |crtf| {
                        obj.* = crtf.full_object_path;
                    } else {
                        @field(result, f.name) = null;
                    }
                }
            }
        }

        return result;
    }

    fn set(
        self: *CsuObjects,
        crt0: ?[]const u8,
        crti: ?[]const u8,
        crtbegin: ?[]const u8,
        crtend: ?[]const u8,
        crtn: ?[]const u8,
    ) void {
        self.crt0 = crt0;
        self.crti = crti;
        self.crtbegin = crtbegin;
        self.crtend = crtend;
        self.crtn = crtn;
    }
};

/// If a target compiles other output modes as dynamic libraries,
/// this function returns true for those too.
pub fn isEffectivelyDynLib(self: Elf) bool {
    if (self.base.isDynLib()) return true;
    return switch (self.getTarget().os.tag) {
        .haiku => self.base.isExe(),
        else => false,
    };
}

pub fn isZigSection(self: Elf, shndx: u32) bool {
    inline for (&[_]?u32{
        self.zig_text_section_index,
        self.zig_data_rel_ro_section_index,
        self.zig_data_section_index,
        self.zig_bss_section_index,
        self.zig_got_section_index,
    }) |maybe_index| {
        if (maybe_index) |index| {
            if (index == shndx) return true;
        }
    }
    return false;
}

pub fn isDebugSection(self: Elf, shndx: u32) bool {
    inline for (&[_]?u32{
        self.debug_info_section_index,
        self.debug_abbrev_section_index,
        self.debug_str_section_index,
        self.debug_aranges_section_index,
        self.debug_line_section_index,
    }) |maybe_index| {
        if (maybe_index) |index| {
            if (index == shndx) return true;
        }
    }
    return false;
}

fn addPhdr(self: *Elf, opts: struct {
    type: u32 = 0,
    flags: u32 = 0,
    @"align": u64 = 0,
    offset: u64 = 0,
    addr: u64 = 0,
    filesz: u64 = 0,
    memsz: u64 = 0,
}) error{OutOfMemory}!u16 {
    const gpa = self.base.comp.gpa;
    const index = @as(u16, @intCast(self.phdrs.items.len));
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

pub fn addRelaShdr(self: *Elf, name: [:0]const u8, shndx: u32) !u32 {
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
        .offset = std.math.maxInt(u64),
    });
}

pub const AddSectionOpts = struct {
    name: [:0]const u8,
    type: u32 = elf.SHT_NULL,
    flags: u64 = 0,
    link: u32 = 0,
    info: u32 = 0,
    addralign: u64 = 0,
    entsize: u64 = 0,
    offset: u64 = 0,
};

pub fn addSection(self: *Elf, opts: AddSectionOpts) !u32 {
    const gpa = self.base.comp.gpa;
    const index = @as(u32, @intCast(self.shdrs.items.len));
    const shdr = try self.shdrs.addOne(gpa);
    shdr.* = .{
        .sh_name = try self.insertShString(opts.name),
        .sh_type = opts.type,
        .sh_flags = opts.flags,
        .sh_addr = 0,
        .sh_offset = opts.offset,
        .sh_size = 0,
        .sh_link = opts.link,
        .sh_info = opts.info,
        .sh_addralign = opts.addralign,
        .sh_entsize = opts.entsize,
    };
    return index;
}

pub fn sectionByName(self: *Elf, name: [:0]const u8) ?u32 {
    for (self.shdrs.items, 0..) |*shdr, i| {
        const this_name = self.getShString(shdr.sh_name);
        if (mem.eql(u8, this_name, name)) return @intCast(i);
    } else return null;
}

const RelaDyn = struct {
    offset: u64,
    sym: u64 = 0,
    type: u32,
    addend: i64 = 0,
};

pub fn addRelaDyn(self: *Elf, opts: RelaDyn) !void {
    try self.rela_dyn.ensureUnusedCapacity(self.base.alloctor, 1);
    self.addRelaDynAssumeCapacity(opts);
}

pub fn addRelaDynAssumeCapacity(self: *Elf, opts: RelaDyn) void {
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

fn calcNumIRelativeRelocs(self: *Elf) usize {
    var count: usize = self.num_ifunc_dynrelocs;

    for (self.got.entries.items) |entry| {
        if (entry.tag != .got) continue;
        const sym = self.symbol(entry.symbol_index);
        if (sym.isIFunc(self)) count += 1;
    }

    return count;
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

fn getStartStopBasename(self: *Elf, shdr: elf.Elf64_Shdr) ?[]const u8 {
    const name = self.getShString(shdr.sh_name);
    if (shdr.sh_flags & elf.SHF_ALLOC != 0 and name.len > 0) {
        if (isCIdentifier(name)) return name;
    }
    return null;
}

pub fn atom(self: *Elf, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

pub fn addAtom(self: *Elf) !Atom.Index {
    const gpa = self.base.comp.gpa;
    const index = @as(Atom.Index, @intCast(self.atoms.items.len));
    const atom_ptr = try self.atoms.addOne(gpa);
    atom_ptr.* = .{ .atom_index = index };
    return index;
}

pub fn addAtomExtra(self: *Elf, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    try self.atoms_extra.ensureUnusedCapacity(self.base.comp.gpa, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

pub fn addAtomExtraAssumeCapacity(self: *Elf, extra: Atom.Extra) u32 {
    const index = @as(u32, @intCast(self.atoms_extra.items.len));
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    inline for (fields) |field| {
        self.atoms_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn atomExtra(self: *Elf, index: u32) ?Atom.Extra {
    if (index == 0) return null;
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    var i: usize = index;
    var result: Atom.Extra = undefined;
    inline for (fields) |field| {
        @field(result, field.name) = switch (field.type) {
            u32 => self.atoms_extra.items[i],
            else => @compileError("bad field type"),
        };
        i += 1;
    }
    return result;
}

pub fn setAtomExtra(self: *Elf, index: u32, extra: Atom.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Atom.Extra).Struct.fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
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
    const tag = self.files.items(.tags)[index];
    return switch (tag) {
        .null => null,
        .linker_defined => .{ .linker_defined = &self.files.items(.data)[index].linker_defined },
        .zig_object => .{ .zig_object = &self.files.items(.data)[index].zig_object },
        .object => .{ .object = &self.files.items(.data)[index].object },
        .shared_object => .{ .shared_object = &self.files.items(.data)[index].shared_object },
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

/// Returns pointer-to-symbol described at sym_index.
pub fn symbol(self: *Elf, sym_index: Symbol.Index) *Symbol {
    return &self.symbols.items[sym_index];
}

pub fn addSymbol(self: *Elf) !Symbol.Index {
    const gpa = self.base.comp.gpa;
    try self.symbols.ensureUnusedCapacity(gpa, 1);
    const index = blk: {
        if (self.symbols_free_list.popOrNull()) |index| {
            log.debug("  (reusing symbol index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{self.symbols.items.len});
            const index: Symbol.Index = @intCast(self.symbols.items.len);
            _ = self.symbols.addOneAssumeCapacity();
            break :blk index;
        }
    };
    self.symbols.items[index] = .{};
    return index;
}

pub fn addSymbolExtra(self: *Elf, extra: Symbol.Extra) !u32 {
    const gpa = self.base.comp.gpa;
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    try self.symbols_extra.ensureUnusedCapacity(gpa, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

pub fn addSymbolExtraAssumeCapacity(self: *Elf, extra: Symbol.Extra) u32 {
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

pub fn symbolExtra(self: *Elf, index: u32) ?Symbol.Extra {
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

pub fn setSymbolExtra(self: *Elf, index: u32, extra: Symbol.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Symbol.Extra).Struct.fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

const GetOrPutGlobalResult = struct {
    found_existing: bool,
    index: Symbol.Index,
};

pub fn getOrPutGlobal(self: *Elf, name: []const u8) !GetOrPutGlobalResult {
    const gpa = self.base.comp.gpa;
    const name_off = try self.strings.insert(gpa, name);
    const gop = try self.resolver.getOrPut(gpa, name_off);
    if (!gop.found_existing) {
        const index = try self.addSymbol();
        log.debug("added symbol '{s}' at index {d}", .{ name, index });
        const global = self.symbol(index);
        global.name_offset = name_off;
        global.flags.global = true;
        gop.value_ptr.* = index;
    }
    return .{
        .found_existing = gop.found_existing,
        .index = gop.value_ptr.*,
    };
}

pub fn globalByName(self: *Elf, name: []const u8) ?Symbol.Index {
    const name_off = self.strings.getOffset(name) orelse return null;
    return self.resolver.get(name_off);
}

pub fn getGlobalSymbol(self: *Elf, name: []const u8, lib_name: ?[]const u8) !u32 {
    return self.zigObjectPtr().?.getGlobalSymbol(self, name, lib_name);
}

pub fn zigObjectPtr(self: *Elf) ?*ZigObject {
    const index = self.zig_object_index orelse return null;
    return self.file(index).?.zig_object;
}

const GetOrCreateComdatGroupOwnerResult = struct {
    found_existing: bool,
    index: ComdatGroupOwner.Index,
};

pub fn getOrCreateComdatGroupOwner(self: *Elf, name: [:0]const u8) !GetOrCreateComdatGroupOwnerResult {
    const gpa = self.base.comp.gpa;
    const off = try self.strings.insert(gpa, name);
    const gop = try self.comdat_groups_table.getOrPut(gpa, off);
    if (!gop.found_existing) {
        const index: ComdatGroupOwner.Index = @intCast(self.comdat_groups_owners.items.len);
        const owner = try self.comdat_groups_owners.addOne(gpa);
        owner.* = .{};
        gop.value_ptr.* = index;
    }
    return .{
        .found_existing = gop.found_existing,
        .index = gop.value_ptr.*,
    };
}

pub fn addComdatGroup(self: *Elf) !ComdatGroup.Index {
    const gpa = self.base.comp.gpa;
    const index = @as(ComdatGroup.Index, @intCast(self.comdat_groups.items.len));
    _ = try self.comdat_groups.addOne(gpa);
    return index;
}

pub fn comdatGroup(self: *Elf, index: ComdatGroup.Index) *ComdatGroup {
    assert(index < self.comdat_groups.items.len);
    return &self.comdat_groups.items[index];
}

pub fn comdatGroupOwner(self: *Elf, index: ComdatGroupOwner.Index) *ComdatGroupOwner {
    assert(index < self.comdat_groups_owners.items.len);
    return &self.comdat_groups_owners.items[index];
}

pub fn addInputMergeSection(self: *Elf) !InputMergeSection.Index {
    const index: InputMergeSection.Index = @intCast(self.merge_input_sections.items.len);
    const msec = try self.merge_input_sections.addOne(self.base.comp.gpa);
    msec.* = .{};
    return index;
}

pub fn inputMergeSection(self: *Elf, index: InputMergeSection.Index) ?*InputMergeSection {
    if (index == 0) return null;
    return &self.merge_input_sections.items[index];
}

pub fn addMergeSubsection(self: *Elf) !MergeSubsection.Index {
    const index: MergeSubsection.Index = @intCast(self.merge_subsections.items.len);
    const msec = try self.merge_subsections.addOne(self.base.comp.gpa);
    msec.* = .{};
    return index;
}

pub fn mergeSubsection(self: *Elf, index: MergeSubsection.Index) *MergeSubsection {
    assert(index < self.merge_subsections.items.len);
    return &self.merge_subsections.items[index];
}

pub fn getOrCreateMergeSection(self: *Elf, name: []const u8, flags: u64, @"type": u32) !MergeSection.Index {
    const gpa = self.base.comp.gpa;
    const out_name = name: {
        if (self.base.isRelocatable()) break :name name;
        if (mem.eql(u8, name, ".rodata") or mem.startsWith(u8, name, ".rodata"))
            break :name if (flags & elf.SHF_STRINGS != 0) ".rodata.str" else ".rodata.cst";
        break :name name;
    };
    const out_off = try self.strings.insert(gpa, out_name);
    const out_flags = flags & ~@as(u64, elf.SHF_COMPRESSED | elf.SHF_GROUP);
    for (self.merge_sections.items, 0..) |msec, index| {
        if (msec.name_offset == out_off) return @intCast(index);
    }
    const index = @as(MergeSection.Index, @intCast(self.merge_sections.items.len));
    const msec = try self.merge_sections.addOne(gpa);
    msec.* = .{
        .name_offset = out_off,
        .flags = out_flags,
        .type = @"type",
    };
    return index;
}

pub fn mergeSection(self: *Elf, index: MergeSection.Index) *MergeSection {
    assert(index < self.merge_sections.items.len);
    return &self.merge_sections.items[index];
}

pub fn gotAddress(self: *Elf) i64 {
    const shndx = blk: {
        if (self.getTarget().cpu.arch == .x86_64 and self.got_plt_section_index != null)
            break :blk self.got_plt_section_index.?;
        break :blk if (self.got_section_index) |shndx| shndx else null;
    };
    return if (shndx) |index| @intCast(self.shdrs.items[index].sh_addr) else 0;
}

pub fn tpAddress(self: *Elf) i64 {
    const index = self.phdr_tls_index orelse return 0;
    const phdr = self.phdrs.items[index];
    const addr = switch (self.getTarget().cpu.arch) {
        .x86_64 => mem.alignForward(u64, phdr.p_vaddr + phdr.p_memsz, phdr.p_align),
        .aarch64 => mem.alignBackward(u64, phdr.p_vaddr - 16, phdr.p_align),
        else => @panic("TODO implement getTpAddress for this arch"),
    };
    return @intCast(addr);
}

pub fn dtpAddress(self: *Elf) i64 {
    const index = self.phdr_tls_index orelse return 0;
    const phdr = self.phdrs.items[index];
    return @intCast(phdr.p_vaddr);
}

pub fn tlsAddress(self: *Elf) i64 {
    const index = self.phdr_tls_index orelse return 0;
    const phdr = self.phdrs.items[index];
    return @intCast(phdr.p_vaddr);
}

const ErrorWithNotes = struct {
    /// Allocated index in comp.link_errors array.
    index: usize,

    /// Next available note slot.
    note_slot: usize = 0,

    pub fn addMsg(
        err: ErrorWithNotes,
        elf_file: *Elf,
        comptime format: []const u8,
        args: anytype,
    ) error{OutOfMemory}!void {
        const comp = elf_file.base.comp;
        const gpa = comp.gpa;
        const err_msg = &comp.link_errors.items[err.index];
        err_msg.msg = try std.fmt.allocPrint(gpa, format, args);
    }

    pub fn addNote(
        err: *ErrorWithNotes,
        elf_file: *Elf,
        comptime format: []const u8,
        args: anytype,
    ) error{OutOfMemory}!void {
        const comp = elf_file.base.comp;
        const gpa = comp.gpa;
        const err_msg = &comp.link_errors.items[err.index];
        assert(err.note_slot < err_msg.notes.len);
        err_msg.notes[err.note_slot] = .{ .msg = try std.fmt.allocPrint(gpa, format, args) };
        err.note_slot += 1;
    }
};

pub fn addErrorWithNotes(self: *Elf, note_count: usize) error{OutOfMemory}!ErrorWithNotes {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    try comp.link_errors.ensureUnusedCapacity(gpa, 1);
    return self.addErrorWithNotesAssumeCapacity(note_count);
}

fn addErrorWithNotesAssumeCapacity(self: *Elf, note_count: usize) error{OutOfMemory}!ErrorWithNotes {
    const comp = self.base.comp;
    const gpa = comp.gpa;
    const index = comp.link_errors.items.len;
    const err = comp.link_errors.addOneAssumeCapacity();
    err.* = .{ .msg = undefined, .notes = try gpa.alloc(link.File.ErrorMsg, note_count) };
    return .{ .index = index };
}

pub fn getShString(self: Elf, off: u32) [:0]const u8 {
    assert(off < self.shstrtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.shstrtab.items.ptr + off)), 0);
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
    const comp = self.base.comp;
    const gpa = comp.gpa;
    const max_notes = 4;

    try comp.link_errors.ensureUnusedCapacity(gpa, undefs.count());

    var it = undefs.iterator();
    while (it.next()) |entry| {
        const undef_index = entry.key_ptr.*;
        const atoms = entry.value_ptr.*.items;
        const natoms = @min(atoms.len, max_notes);
        const nnotes = natoms + @intFromBool(atoms.len > max_notes);

        var err = try self.addErrorWithNotesAssumeCapacity(nnotes);
        try err.addMsg(self, "undefined symbol: {s}", .{self.symbol(undef_index).name(self)});

        for (atoms[0..natoms]) |atom_index| {
            const atom_ptr = self.atom(atom_index).?;
            const file_ptr = self.file(atom_ptr.file_index).?;
            try err.addNote(self, "referenced by {s}:{s}", .{ file_ptr.fmtPath(), atom_ptr.name(self) });
        }

        if (atoms.len > max_notes) {
            const remaining = atoms.len - max_notes;
            try err.addNote(self, "referenced {d} more times", .{remaining});
        }
    }
}

fn reportDuplicates(self: *Elf, dupes: anytype) error{ HasDuplicates, OutOfMemory }!void {
    const max_notes = 3;
    var has_dupes = false;
    var it = dupes.iterator();
    while (it.next()) |entry| {
        const sym = self.symbol(entry.key_ptr.*);
        const notes = entry.value_ptr.*;
        const nnotes = @min(notes.items.len, max_notes) + @intFromBool(notes.items.len > max_notes);

        var err = try self.addErrorWithNotes(nnotes + 1);
        try err.addMsg(self, "duplicate symbol definition: {s}", .{sym.name(self)});
        try err.addNote(self, "defined by {}", .{sym.file(self).?.fmtPath()});

        var inote: usize = 0;
        while (inote < @min(notes.items.len, max_notes)) : (inote += 1) {
            const file_ptr = self.file(notes.items[inote]).?;
            try err.addNote(self, "defined by {}", .{file_ptr.fmtPath()});
        }

        if (notes.items.len > max_notes) {
            const remaining = notes.items.len - max_notes;
            try err.addNote(self, "defined {d} more times", .{remaining});
        }

        has_dupes = true;
    }

    if (has_dupes) return error.HasDuplicates;
}

fn reportMissingLibraryError(
    self: *Elf,
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

pub fn reportUnsupportedCpuArch(self: *Elf) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(0);
    try err.addMsg(self, "fatal linker error: unsupported CPU architecture {s}", .{
        @tagName(self.getTarget().cpu.arch),
    });
}

pub fn reportParseError(
    self: *Elf,
    path: []const u8,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(1);
    try err.addMsg(self, format, args);
    try err.addNote(self, "while parsing {s}", .{path});
}

pub fn reportParseError2(
    self: *Elf,
    file_index: File.Index,
    comptime format: []const u8,
    args: anytype,
) error{OutOfMemory}!void {
    var err = try self.addErrorWithNotes(1);
    try err.addMsg(self, format, args);
    try err.addNote(self, "while parsing {}", .{self.file(file_index).?.fmtPath()});
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
    try writer.print("{s} : @{x} ({x}) : align({x}) : size({x}) : flags({})", .{
        ctx.elf_file.getShString(shdr.sh_name), shdr.sh_offset,
        shdr.sh_addr,                           shdr.sh_addralign,
        shdr.sh_size,                           fmtShdrFlags(shdr.sh_flags),
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

    if (self.zigObjectPtr()) |zig_object| {
        try writer.print("zig_object({d}) : {s}\n", .{ zig_object.index, zig_object.path });
        try writer.print("{}{}\n", .{
            zig_object.fmtAtoms(self),
            zig_object.fmtSymtab(self),
        });
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

    for (self.shared_objects.items) |index| {
        const shared_object = self.file(index).?.shared_object;
        try writer.print("shared_object({d}) : ", .{index});
        try writer.print("{s}", .{shared_object.path});
        try writer.print(" : needed({})", .{shared_object.needed});
        if (!shared_object.alive) try writer.writeAll(" : [*]");
        try writer.writeByte('\n');
        try writer.print("{}\n", .{shared_object.fmtSymtab(self)});
    }

    if (self.linker_defined_index) |index| {
        const linker_defined = self.file(index).?.linker_defined;
        try writer.print("linker_defined({d}) : (linker defined)\n", .{index});
        try writer.print("{}\n", .{linker_defined.fmtSymtab(self)});
    }

    if (self.requiresThunks()) {
        try writer.writeAll("thunks\n");
        for (self.thunks.items, 0..) |th, index| {
            try writer.print("thunk({d}) : {}\n", .{ index, th.fmt(self) });
        }
    }

    try writer.print("{}\n", .{self.zig_got.fmt(self)});
    try writer.print("{}\n", .{self.got.fmt(self)});
    try writer.print("{}\n", .{self.plt.fmt(self)});

    try writer.writeAll("Output COMDAT groups\n");
    for (self.comdat_group_sections.items) |cg| {
        try writer.print("  shdr({d}) : COMDAT({d})\n", .{ cg.shndx, cg.cg_index });
    }

    try writer.writeAll("\nOutput merge sections\n");
    for (self.merge_sections.items) |msec| {
        try writer.print("  shdr({d}) : {}\n", .{ msec.output_section_index, msec.fmt(self) });
    }

    try writer.writeAll("\nOutput shdrs\n");
    for (self.shdrs.items, 0..) |shdr, shndx| {
        try writer.print("  shdr({d}) : phdr({?d}) : {}\n", .{
            shndx,
            self.phdr_to_shdr_table.get(@intCast(shndx)),
            self.fmtShdr(shdr),
        });
    }
    try writer.writeAll("\nOutput phdrs\n");
    for (self.phdrs.items, 0..) |phdr, phndx| {
        try writer.print("  phdr{d} : {}\n", .{ phndx, self.fmtPhdr(phdr) });
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
const number_of_zig_segments = 5;
const max_number_of_object_segments = 9;
const max_number_of_special_phdrs = 5;

const default_entry_addr = 0x8000000;

pub const base_tag: link.File.Tag = .elf;

const ComdatGroupOwner = struct {
    file: File.Index = 0,

    const Index = u32;
};

pub const ComdatGroup = struct {
    owner: ComdatGroupOwner.Index,
    file: File.Index,
    shndx: u32,
    members_start: u32,
    members_len: u32,

    pub fn comdatGroupMembers(cg: ComdatGroup, elf_file: *Elf) []const u32 {
        const object = elf_file.file(cg.file).?.object;
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
    path: []const u8,
};

const LastAtomAndFreeList = struct {
    /// Index of the last allocated atom in this section.
    last_atom_index: Atom.Index = 0,

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
    free_list: std.ArrayListUnmanaged(Atom.Index) = .{},
};
const LastAtomAndFreeListTable = std.AutoArrayHashMapUnmanaged(u32, LastAtomAndFreeList);

const RelaSection = struct {
    shndx: u32,
    atom_list: std.ArrayListUnmanaged(Atom.Index) = .{},
};
const RelaSectionTable = std.AutoArrayHashMapUnmanaged(u32, RelaSection);

// TODO: add comptime check we don't clobber any reloc for any ISA
pub const R_ZIG_GOT32: u32 = 0xff00;
pub const R_ZIG_GOTPCREL: u32 = 0xff01;
pub const R_ZIG_GOT_HI20: u32 = 0xff02;
pub const R_ZIG_GOT_LO12: u32 = 0xff03;

fn defaultEntrySymbolName(cpu_arch: std.Target.Cpu.Arch) []const u8 {
    return switch (cpu_arch) {
        .mips, .mipsel, .mips64, .mips64el => "__start",
        else => "_start",
    };
}

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const elf = std.elf;
const fs = std.fs;
const log = std.log.scoped(.link);
const state_log = std.log.scoped(.link_state);
const math = std.math;
const mem = std.mem;

const codegen = @import("../codegen.zig");
const eh_frame = @import("Elf/eh_frame.zig");
const gc = @import("Elf/gc.zig");
const glibc = @import("../glibc.zig");
const link = @import("../link.zig");
const merge_section = @import("Elf/merge_section.zig");
const musl = @import("../musl.zig");
const relocatable = @import("Elf/relocatable.zig");
const relocation = @import("Elf/relocation.zig");
const target_util = @import("../target.zig");
const thunks = @import("Elf/thunks.zig");
const trace = @import("../tracy.zig").trace;
const synthetic_sections = @import("Elf/synthetic_sections.zig");

const Air = @import("../Air.zig");
const Allocator = std.mem.Allocator;
const Archive = @import("Elf/Archive.zig");
pub const Atom = @import("Elf/Atom.zig");
const Cache = std.Build.Cache;
const Compilation = @import("../Compilation.zig");
const ComdatGroupSection = synthetic_sections.ComdatGroupSection;
const CopyRelSection = synthetic_sections.CopyRelSection;
const DynamicSection = synthetic_sections.DynamicSection;
const DynsymSection = synthetic_sections.DynsymSection;
const Dwarf = @import("Dwarf.zig");
const Elf = @This();
const File = @import("Elf/file.zig").File;
const GnuHashSection = synthetic_sections.GnuHashSection;
const GotSection = synthetic_sections.GotSection;
const GotPltSection = synthetic_sections.GotPltSection;
const HashSection = synthetic_sections.HashSection;
const InputMergeSection = merge_section.InputMergeSection;
const LdScript = @import("Elf/LdScript.zig");
const LinkerDefined = @import("Elf/LinkerDefined.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const MergeSection = merge_section.MergeSection;
const MergeSubsection = merge_section.MergeSubsection;
const Module = @import("../Module.zig");
const Object = @import("Elf/Object.zig");
const InternPool = @import("../InternPool.zig");
const PltSection = synthetic_sections.PltSection;
const PltGotSection = synthetic_sections.PltGotSection;
const SharedObject = @import("Elf/SharedObject.zig");
const Symbol = @import("Elf/Symbol.zig");
const StringTable = @import("StringTable.zig");
const Thunk = thunks.Thunk;
const Value = @import("../Value.zig");
const VerneedSection = synthetic_sections.VerneedSection;
const ZigGotSection = synthetic_sections.ZigGotSection;
const ZigObject = @import("Elf/ZigObject.zig");
