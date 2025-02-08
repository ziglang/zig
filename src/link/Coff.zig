//! The main driver of the COFF linker.
//! Currently uses our own implementation for the incremental linker, and falls back to
//! LLD for traditional linking (linking relocatable object files).
//! LLD is also the default linker for LLVM.

/// If this is not null, an object file is created by LLVM and emitted to zcu_object_sub_path.
llvm_object: ?LlvmObject.Ptr = null,

base: link.File,
image_base: u64,
subsystem: ?std.Target.SubSystem,
tsaware: bool,
nxcompat: bool,
dynamicbase: bool,
/// TODO this and minor_subsystem_version should be combined into one property and left as
/// default or populated together. They should not be separate fields.
major_subsystem_version: u16,
minor_subsystem_version: u16,
lib_directories: []const Directory,
entry: link.File.OpenOptions.Entry,
entry_addr: ?u32,
module_definition_file: ?[]const u8,
pdb_out_path: ?[]const u8,
repro: bool,

ptr_width: PtrWidth,
page_size: u32,

sections: std.MultiArrayList(Section) = .{},
data_directories: [coff_util.IMAGE_NUMBEROF_DIRECTORY_ENTRIES]coff_util.ImageDataDirectory,

text_section_index: ?u16 = null,
got_section_index: ?u16 = null,
rdata_section_index: ?u16 = null,
data_section_index: ?u16 = null,
reloc_section_index: ?u16 = null,
idata_section_index: ?u16 = null,

locals: std.ArrayListUnmanaged(coff_util.Symbol) = .empty,
globals: std.ArrayListUnmanaged(SymbolWithLoc) = .empty,
resolver: std.StringHashMapUnmanaged(u32) = .empty,
unresolved: std.AutoArrayHashMapUnmanaged(u32, bool) = .empty,
need_got_table: std.AutoHashMapUnmanaged(u32, void) = .empty,

locals_free_list: std.ArrayListUnmanaged(u32) = .empty,
globals_free_list: std.ArrayListUnmanaged(u32) = .empty,

strtab: StringTable = .{},
strtab_offset: ?u32 = null,

temp_strtab: StringTable = .{},

got_table: TableSection(SymbolWithLoc) = .{},

/// A table of ImportTables partitioned by the library name.
/// Key is an offset into the interning string table `temp_strtab`.
import_tables: std.AutoArrayHashMapUnmanaged(u32, ImportTable) = .empty,

got_table_count_dirty: bool = true,
got_table_contents_dirty: bool = true,
imports_count_dirty: bool = true,

/// Table of tracked LazySymbols.
lazy_syms: LazySymbolTable = .{},

/// Table of tracked `Nav`s.
navs: NavTable = .{},

/// List of atoms that are either synthetic or map directly to the Zig source program.
atoms: std.ArrayListUnmanaged(Atom) = .empty,

/// Table of atoms indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, Atom.Index) = .empty,

uavs: UavTable = .{},

/// A table of relocations indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
relocs: RelocTable = .{},

/// A table of base relocations indexed by the owning them `Atom`.
/// Note that once we refactor `Atom`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
base_relocs: BaseRelocationTable = .{},

/// Hot-code swapping state.
hot_state: if (is_hot_update_compatible) HotUpdateState else struct {} = .{},

const is_hot_update_compatible = switch (builtin.target.os.tag) {
    .windows => true,
    else => false,
};

const HotUpdateState = struct {
    /// Base address at which the process (image) got loaded.
    /// We need this info to correctly slide pointers when relocating.
    loaded_base_address: ?std.os.windows.HMODULE = null,
};

const NavTable = std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, AvMetadata);
const UavTable = std.AutoHashMapUnmanaged(InternPool.Index, AvMetadata);
const RelocTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(Relocation));
const BaseRelocationTable = std.AutoArrayHashMapUnmanaged(Atom.Index, std.ArrayListUnmanaged(u32));

const default_file_alignment: u16 = 0x200;
const default_size_of_stack_reserve: u32 = 0x1000000;
const default_size_of_stack_commit: u32 = 0x1000;
const default_size_of_heap_reserve: u32 = 0x100000;
const default_size_of_heap_commit: u32 = 0x1000;

const Section = struct {
    header: coff_util.SectionHeader,

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
    free_list: std.ArrayListUnmanaged(Atom.Index) = .empty,
};

const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.Index, LazySymbolMetadata);

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_atom: Atom.Index = undefined,
    rdata_atom: Atom.Index = undefined,
    text_state: State = .unused,
    rdata_state: State = .unused,
};

const AvMetadata = struct {
    atom: Atom.Index,
    section: u16,
    /// A list of all exports aliases of this Decl.
    exports: std.ArrayListUnmanaged(u32) = .empty,

    fn deinit(m: *AvMetadata, allocator: Allocator) void {
        m.exports.deinit(allocator);
    }

    fn getExport(m: AvMetadata, coff: *const Coff, name: []const u8) ?u32 {
        for (m.exports.items) |exp| {
            if (mem.eql(u8, name, coff.getSymbolName(.{
                .sym_index = exp,
                .file = null,
            }))) return exp;
        }
        return null;
    }

    fn getExportPtr(m: *AvMetadata, coff: *Coff, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            if (mem.eql(u8, name, coff.getSymbolName(.{
                .sym_index = exp.*,
                .file = null,
            }))) return exp;
        }
        return null;
    }
};

pub const PtrWidth = enum {
    p32,
    p64,

    /// Size in bytes.
    pub fn size(pw: PtrWidth) u4 {
        return switch (pw) {
            .p32 => 4,
            .p64 => 8,
        };
    }
};

pub const SymbolWithLoc = struct {
    // Index into the respective symbol table.
    sym_index: u32,

    // null means it's a synthetic global or Zig source.
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

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_text_block_size = 64;
pub const min_text_capacity = padToIdeal(minimum_text_block_size);

pub fn createEmpty(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Coff {
    const target = comp.root_mod.resolved_target.result;
    assert(target.ofmt == .coff);
    const optimize_mode = comp.root_mod.optimize_mode;
    const output_mode = comp.config.output_mode;
    const link_mode = comp.config.link_mode;
    const use_llvm = comp.config.use_llvm;
    const use_lld = build_options.have_llvm and comp.config.use_lld;

    const ptr_width: PtrWidth = switch (target.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedCOFFArchitecture,
    };
    const page_size: u32 = switch (target.cpu.arch) {
        else => 0x1000,
    };

    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    // If using LLVM to generate the object file for the zig compilation unit,
    // we need a place to put the object file so that it can be subsequently
    // handled.
    const zcu_object_sub_path = if (!use_lld and !use_llvm)
        null
    else
        try allocPrint(arena, "{s}.obj", .{emit.sub_path});

    const coff = try arena.create(Coff);
    coff.* = .{
        .base = .{
            .tag = .coff,
            .comp = comp,
            .emit = emit,
            .zcu_object_sub_path = zcu_object_sub_path,
            .stack_size = options.stack_size orelse 16777216,
            .gc_sections = options.gc_sections orelse (optimize_mode != .Debug),
            .print_gc_sections = options.print_gc_sections,
            .allow_shlib_undefined = options.allow_shlib_undefined orelse false,
            .file = null,
            .disable_lld_caching = options.disable_lld_caching,
            .build_id = options.build_id,
        },
        .ptr_width = ptr_width,
        .page_size = page_size,

        .data_directories = [1]coff_util.ImageDataDirectory{.{
            .virtual_address = 0,
            .size = 0,
        }} ** coff_util.IMAGE_NUMBEROF_DIRECTORY_ENTRIES,

        .image_base = options.image_base orelse switch (output_mode) {
            .Exe => switch (target.cpu.arch) {
                .aarch64, .x86_64 => 0x140000000,
                .thumb, .x86 => 0x400000,
                else => unreachable,
            },
            .Lib => switch (target.cpu.arch) {
                .aarch64, .x86_64 => 0x180000000,
                .thumb, .x86 => 0x10000000,
                else => unreachable,
            },
            .Obj => 0,
        },

        // Subsystem depends on the set of public symbol names from linked objects.
        // See LinkerDriver::inferSubsystem from the LLD project for the flow chart.
        .subsystem = options.subsystem,

        .entry = options.entry,

        .tsaware = options.tsaware,
        .nxcompat = options.nxcompat,
        .dynamicbase = options.dynamicbase,
        .major_subsystem_version = options.major_subsystem_version orelse 6,
        .minor_subsystem_version = options.minor_subsystem_version orelse 0,
        .lib_directories = options.lib_directories,
        .entry_addr = math.cast(u32, options.entry_addr orelse 0) orelse
            return error.EntryAddressTooBig,
        .module_definition_file = options.module_definition_file,
        .pdb_out_path = options.pdb_out_path,
        .repro = options.repro,
    };
    if (use_llvm and comp.config.have_zcu) {
        coff.llvm_object = try LlvmObject.create(arena, comp);
    }
    errdefer coff.base.destroy();

    if (use_lld and (use_llvm or !comp.config.have_zcu)) {
        // LLVM emits the object file (if any); LLD links it into the final product.
        return coff;
    }

    // What path should this COFF linker code output to?
    // If using LLD to link, this code should produce an object file so that it
    // can be passed to LLD.
    const sub_path = if (use_lld) zcu_object_sub_path.? else emit.sub_path;
    coff.base.file = try emit.root_dir.handle.createFile(sub_path, .{
        .truncate = true,
        .read = true,
        .mode = link.File.determineMode(use_lld, output_mode, link_mode),
    });

    assert(coff.llvm_object == null);
    const gpa = comp.gpa;

    try coff.strtab.buffer.ensureUnusedCapacity(gpa, @sizeOf(u32));
    coff.strtab.buffer.appendNTimesAssumeCapacity(0, @sizeOf(u32));

    try coff.temp_strtab.buffer.append(gpa, 0);

    // Index 0 is always a null symbol.
    try coff.locals.append(gpa, .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    });

    if (coff.text_section_index == null) {
        const file_size: u32 = @intCast(options.program_code_size_hint);
        coff.text_section_index = try coff.allocateSection(".text", file_size, .{
            .CNT_CODE = 1,
            .MEM_EXECUTE = 1,
            .MEM_READ = 1,
        });
    }

    if (coff.got_section_index == null) {
        const file_size = @as(u32, @intCast(options.symbol_count_hint)) * coff.ptr_width.size();
        coff.got_section_index = try coff.allocateSection(".got", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
        });
    }

    if (coff.rdata_section_index == null) {
        const file_size: u32 = coff.page_size;
        coff.rdata_section_index = try coff.allocateSection(".rdata", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
        });
    }

    if (coff.data_section_index == null) {
        const file_size: u32 = coff.page_size;
        coff.data_section_index = try coff.allocateSection(".data", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
            .MEM_WRITE = 1,
        });
    }

    if (coff.idata_section_index == null) {
        const file_size = @as(u32, @intCast(options.symbol_count_hint)) * coff.ptr_width.size();
        coff.idata_section_index = try coff.allocateSection(".idata", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_READ = 1,
        });
    }

    if (coff.reloc_section_index == null) {
        const file_size = @as(u32, @intCast(options.symbol_count_hint)) * @sizeOf(coff_util.BaseRelocation);
        coff.reloc_section_index = try coff.allocateSection(".reloc", file_size, .{
            .CNT_INITIALIZED_DATA = 1,
            .MEM_DISCARDABLE = 1,
            .MEM_READ = 1,
        });
    }

    if (coff.strtab_offset == null) {
        const file_size = @as(u32, @intCast(coff.strtab.buffer.items.len));
        coff.strtab_offset = coff.findFreeSpace(file_size, @alignOf(u32)); // 4bytes aligned seems like a good idea here
        log.debug("found strtab free space 0x{x} to 0x{x}", .{ coff.strtab_offset.?, coff.strtab_offset.? + file_size });
    }

    {
        // We need to find out what the max file offset is according to section headers.
        // Otherwise, we may end up with an COFF binary with file size not matching the final section's
        // offset + it's filesize.
        // TODO I don't like this here one bit
        var max_file_offset: u64 = 0;
        for (coff.sections.items(.header)) |header| {
            if (header.pointer_to_raw_data + header.size_of_raw_data > max_file_offset) {
                max_file_offset = header.pointer_to_raw_data + header.size_of_raw_data;
            }
        }
        try coff.pwriteAll(&[_]u8{0}, max_file_offset);
    }

    return coff;
}

pub fn open(
    arena: Allocator,
    comp: *Compilation,
    emit: Path,
    options: link.File.OpenOptions,
) !*Coff {
    // TODO: restore saved linker state, don't truncate the file, and
    // participate in incremental compilation.
    return createEmpty(arena, comp, emit, options);
}

pub fn deinit(coff: *Coff) void {
    const gpa = coff.base.comp.gpa;

    if (coff.llvm_object) |llvm_object| llvm_object.deinit();

    for (coff.sections.items(.free_list)) |*free_list| {
        free_list.deinit(gpa);
    }
    coff.sections.deinit(gpa);

    coff.atoms.deinit(gpa);
    coff.locals.deinit(gpa);
    coff.globals.deinit(gpa);

    {
        var it = coff.resolver.keyIterator();
        while (it.next()) |key_ptr| {
            gpa.free(key_ptr.*);
        }
        coff.resolver.deinit(gpa);
    }

    coff.unresolved.deinit(gpa);
    coff.need_got_table.deinit(gpa);
    coff.locals_free_list.deinit(gpa);
    coff.globals_free_list.deinit(gpa);
    coff.strtab.deinit(gpa);
    coff.temp_strtab.deinit(gpa);
    coff.got_table.deinit(gpa);

    for (coff.import_tables.values()) |*itab| {
        itab.deinit(gpa);
    }
    coff.import_tables.deinit(gpa);

    coff.lazy_syms.deinit(gpa);

    for (coff.navs.values()) |*metadata| {
        metadata.deinit(gpa);
    }
    coff.navs.deinit(gpa);

    coff.atom_by_index_table.deinit(gpa);

    {
        var it = coff.uavs.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.exports.deinit(gpa);
        }
        coff.uavs.deinit(gpa);
    }

    for (coff.relocs.values()) |*relocs| {
        relocs.deinit(gpa);
    }
    coff.relocs.deinit(gpa);

    for (coff.base_relocs.values()) |*relocs| {
        relocs.deinit(gpa);
    }
    coff.base_relocs.deinit(gpa);
}

fn allocateSection(coff: *Coff, name: []const u8, size: u32, flags: coff_util.SectionHeaderFlags) !u16 {
    const index = @as(u16, @intCast(coff.sections.slice().len));
    const off = coff.findFreeSpace(size, default_file_alignment);
    // Memory is always allocated in sequence
    // TODO: investigate if we can allocate .text last; this way it would never need to grow in memory!
    const vaddr = blk: {
        if (index == 0) break :blk coff.page_size;
        const prev_header = coff.sections.items(.header)[index - 1];
        break :blk mem.alignForward(u32, prev_header.virtual_address + prev_header.virtual_size, coff.page_size);
    };
    // We commit more memory than needed upfront so that we don't have to reallocate too soon.
    const memsz = mem.alignForward(u32, size, coff.page_size) * 100;
    log.debug("found {s} free space 0x{x} to 0x{x} (0x{x} - 0x{x})", .{
        name,
        off,
        off + size,
        vaddr,
        vaddr + size,
    });
    var header = coff_util.SectionHeader{
        .name = undefined,
        .virtual_size = memsz,
        .virtual_address = vaddr,
        .size_of_raw_data = size,
        .pointer_to_raw_data = off,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = flags,
    };
    const gpa = coff.base.comp.gpa;
    try coff.setSectionName(&header, name);
    try coff.sections.append(gpa, .{ .header = header });
    return index;
}

fn growSection(coff: *Coff, sect_id: u32, needed_size: u32) !void {
    const header = &coff.sections.items(.header)[sect_id];
    const maybe_last_atom_index = coff.sections.items(.last_atom_index)[sect_id];
    const sect_capacity = coff.allocatedSize(header.pointer_to_raw_data);

    if (needed_size > sect_capacity) {
        const new_offset = coff.findFreeSpace(needed_size, default_file_alignment);
        const current_size = if (maybe_last_atom_index) |last_atom_index| blk: {
            const last_atom = coff.getAtom(last_atom_index);
            const sym = last_atom.getSymbol(coff);
            break :blk (sym.value + last_atom.size) - header.virtual_address;
        } else 0;
        log.debug("moving {s} from 0x{x} to 0x{x}", .{
            coff.getSectionName(header),
            header.pointer_to_raw_data,
            new_offset,
        });
        const amt = try coff.base.file.?.copyRangeAll(
            header.pointer_to_raw_data,
            coff.base.file.?,
            new_offset,
            current_size,
        );
        if (amt != current_size) return error.InputOutput;
        header.pointer_to_raw_data = new_offset;
    }

    const sect_vm_capacity = coff.allocatedVirtualSize(header.virtual_address);
    if (needed_size > sect_vm_capacity) {
        coff.markRelocsDirtyByAddress(header.virtual_address + header.virtual_size);
        try coff.growSectionVirtualMemory(sect_id, needed_size);
    }

    header.virtual_size = @max(header.virtual_size, needed_size);
    header.size_of_raw_data = needed_size;
}

fn growSectionVirtualMemory(coff: *Coff, sect_id: u32, needed_size: u32) !void {
    const header = &coff.sections.items(.header)[sect_id];
    const increased_size = padToIdeal(needed_size);
    const old_aligned_end = header.virtual_address + mem.alignForward(u32, header.virtual_size, coff.page_size);
    const new_aligned_end = header.virtual_address + mem.alignForward(u32, increased_size, coff.page_size);
    const diff = new_aligned_end - old_aligned_end;
    log.debug("growing {s} in virtual memory by {x}", .{ coff.getSectionName(header), diff });

    // TODO: enforce order by increasing VM addresses in coff.sections container.
    // This is required by the loader anyhow as far as I can tell.
    for (coff.sections.items(.header)[sect_id + 1 ..], 0..) |*next_header, next_sect_id| {
        const maybe_last_atom_index = coff.sections.items(.last_atom_index)[sect_id + 1 + next_sect_id];
        next_header.virtual_address += diff;

        if (maybe_last_atom_index) |last_atom_index| {
            var atom_index = last_atom_index;
            while (true) {
                const atom = coff.getAtom(atom_index);
                const sym = atom.getSymbolPtr(coff);
                sym.value += diff;

                if (atom.prev_index) |prev_index| {
                    atom_index = prev_index;
                } else break;
            }
        }
    }

    header.virtual_size = increased_size;
}

fn allocateAtom(coff: *Coff, atom_index: Atom.Index, new_atom_size: u32, alignment: u32) !u32 {
    const tracy = trace(@src());
    defer tracy.end();

    const atom = coff.getAtom(atom_index);
    const sect_id = @intFromEnum(atom.getSymbol(coff).section_number) - 1;
    const header = &coff.sections.items(.header)[sect_id];
    const free_list = &coff.sections.items(.free_list)[sect_id];
    const maybe_last_atom_index = &coff.sections.items(.last_atom_index)[sect_id];
    const new_atom_ideal_capacity = if (header.isCode()) padToIdeal(new_atom_size) else new_atom_size;

    // We use these to indicate our intention to update metadata, placing the new atom,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var atom_placement: ?Atom.Index = null;
    var free_list_removal: ?usize = null;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    const vaddr = blk: {
        var i: usize = 0;
        while (i < free_list.items.len) {
            const big_atom_index = free_list.items[i];
            const big_atom = coff.getAtom(big_atom_index);
            // We now have a pointer to a live atom that has too much capacity.
            // Is it enough that we could fit this new atom?
            const sym = big_atom.getSymbol(coff);
            const capacity = big_atom.capacity(coff);
            const ideal_capacity = if (header.isCode()) padToIdeal(capacity) else capacity;
            const ideal_capacity_end_vaddr = math.add(u32, sym.value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = sym.value + capacity;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_atom_ideal_capacity;
            const new_start_vaddr = mem.alignBackward(u32, new_start_vaddr_unaligned, alignment);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the atom that it points to has grown to take up
                // more of the extra capacity.
                if (!big_atom.freeListEligible(coff)) {
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
            const last = coff.getAtom(last_index);
            const last_symbol = last.getSymbol(coff);
            const ideal_capacity = if (header.isCode()) padToIdeal(last.size) else last.size;
            const ideal_capacity_end_vaddr = last_symbol.value + ideal_capacity;
            const new_start_vaddr = mem.alignForward(u32, ideal_capacity_end_vaddr, alignment);
            atom_placement = last_index;
            break :blk new_start_vaddr;
        } else {
            break :blk mem.alignForward(u32, header.virtual_address, alignment);
        }
    };

    const expand_section = if (atom_placement) |placement_index|
        coff.getAtom(placement_index).next_index == null
    else
        true;
    if (expand_section) {
        const needed_size: u32 = (vaddr + new_atom_size) - header.virtual_address;
        try coff.growSection(sect_id, needed_size);
        maybe_last_atom_index.* = atom_index;
    }
    coff.getAtomPtr(atom_index).size = new_atom_size;

    if (atom.prev_index) |prev_index| {
        const prev = coff.getAtomPtr(prev_index);
        prev.next_index = atom.next_index;
    }
    if (atom.next_index) |next_index| {
        const next = coff.getAtomPtr(next_index);
        next.prev_index = atom.prev_index;
    }

    if (atom_placement) |big_atom_index| {
        const big_atom = coff.getAtomPtr(big_atom_index);
        const atom_ptr = coff.getAtomPtr(atom_index);
        atom_ptr.prev_index = big_atom_index;
        atom_ptr.next_index = big_atom.next_index;
        big_atom.next_index = atom_index;
    } else {
        const atom_ptr = coff.getAtomPtr(atom_index);
        atom_ptr.prev_index = null;
        atom_ptr.next_index = null;
    }
    if (free_list_removal) |i| {
        _ = free_list.swapRemove(i);
    }

    return vaddr;
}

pub fn allocateSymbol(coff: *Coff) !u32 {
    const gpa = coff.base.comp.gpa;
    try coff.locals.ensureUnusedCapacity(gpa, 1);

    const index = blk: {
        if (coff.locals_free_list.pop()) |index| {
            log.debug("  (reusing symbol index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{coff.locals.items.len});
            const index = @as(u32, @intCast(coff.locals.items.len));
            _ = coff.locals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    coff.locals.items[index] = .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    };

    return index;
}

fn allocateGlobal(coff: *Coff) !u32 {
    const gpa = coff.base.comp.gpa;
    try coff.globals.ensureUnusedCapacity(gpa, 1);

    const index = blk: {
        if (coff.globals_free_list.pop()) |index| {
            log.debug("  (reusing global index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating global index {d})", .{coff.globals.items.len});
            const index = @as(u32, @intCast(coff.globals.items.len));
            _ = coff.globals.addOneAssumeCapacity();
            break :blk index;
        }
    };

    coff.globals.items[index] = .{
        .sym_index = 0,
        .file = null,
    };

    return index;
}

fn addGotEntry(coff: *Coff, target: SymbolWithLoc) !void {
    const gpa = coff.base.comp.gpa;
    if (coff.got_table.lookup.contains(target)) return;
    const got_index = try coff.got_table.allocateEntry(gpa, target);
    try coff.writeOffsetTableEntry(got_index);
    coff.got_table_count_dirty = true;
    coff.markRelocsDirtyByTarget(target);
}

pub fn createAtom(coff: *Coff) !Atom.Index {
    const gpa = coff.base.comp.gpa;
    const atom_index = @as(Atom.Index, @intCast(coff.atoms.items.len));
    const atom = try coff.atoms.addOne(gpa);
    const sym_index = try coff.allocateSymbol();
    try coff.atom_by_index_table.putNoClobber(gpa, sym_index, atom_index);
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

fn growAtom(coff: *Coff, atom_index: Atom.Index, new_atom_size: u32, alignment: u32) !u32 {
    const atom = coff.getAtom(atom_index);
    const sym = atom.getSymbol(coff);
    const align_ok = mem.alignBackward(u32, sym.value, alignment) == sym.value;
    const need_realloc = !align_ok or new_atom_size > atom.capacity(coff);
    if (!need_realloc) return sym.value;
    return coff.allocateAtom(atom_index, new_atom_size, alignment);
}

fn shrinkAtom(coff: *Coff, atom_index: Atom.Index, new_block_size: u32) void {
    _ = coff;
    _ = atom_index;
    _ = new_block_size;
    // TODO check the new capacity, and if it crosses the size threshold into a big enough
    // capacity, insert a free list node for it.
}

fn writeAtom(coff: *Coff, atom_index: Atom.Index, code: []u8) !void {
    const atom = coff.getAtom(atom_index);
    const sym = atom.getSymbol(coff);
    const section = coff.sections.get(@intFromEnum(sym.section_number) - 1);
    const file_offset = section.header.pointer_to_raw_data + sym.value - section.header.virtual_address;

    log.debug("writing atom for symbol {s} at file offset 0x{x} to 0x{x}", .{
        atom.getName(coff),
        file_offset,
        file_offset + code.len,
    });

    const gpa = coff.base.comp.gpa;

    // Gather relocs which can be resolved.
    // We need to do this as we will be applying different slide values depending
    // if we are running in hot-code swapping mode or not.
    // TODO: how crazy would it be to try and apply the actual image base of the loaded
    // process for the in-file values rather than the Windows defaults?
    var relocs = std.ArrayList(*Relocation).init(gpa);
    defer relocs.deinit();

    if (coff.relocs.getPtr(atom_index)) |rels| {
        try relocs.ensureTotalCapacityPrecise(rels.items.len);
        for (rels.items) |*reloc| {
            if (reloc.isResolvable(coff) and reloc.dirty) {
                relocs.appendAssumeCapacity(reloc);
            }
        }
    }

    if (is_hot_update_compatible) {
        if (coff.base.child_pid) |handle| {
            const slide = @intFromPtr(coff.hot_state.loaded_base_address.?);

            const mem_code = try gpa.dupe(u8, code);
            defer gpa.free(mem_code);
            coff.resolveRelocs(atom_index, relocs.items, mem_code, slide);

            const vaddr = sym.value + slide;
            const pvaddr = @as(*anyopaque, @ptrFromInt(vaddr));

            log.debug("writing to memory at address {x}", .{vaddr});

            if (build_options.enable_logging) {
                try debugMem(gpa, handle, pvaddr, mem_code);
            }

            if (section.header.flags.MEM_WRITE == 0) {
                writeMemProtected(handle, pvaddr, mem_code) catch |err| {
                    log.warn("writing to protected memory failed with error: {s}", .{@errorName(err)});
                };
            } else {
                writeMem(handle, pvaddr, mem_code) catch |err| {
                    log.warn("writing to protected memory failed with error: {s}", .{@errorName(err)});
                };
            }
        }
    }

    coff.resolveRelocs(atom_index, relocs.items, code, coff.image_base);
    try coff.pwriteAll(code, file_offset);

    // Now we can mark the relocs as resolved.
    while (relocs.pop()) |reloc| {
        reloc.dirty = false;
    }
}

fn debugMem(allocator: Allocator, handle: std.process.Child.Id, pvaddr: std.os.windows.LPVOID, code: []const u8) !void {
    const buffer = try allocator.alloc(u8, code.len);
    defer allocator.free(buffer);
    const memread = try std.os.windows.ReadProcessMemory(handle, pvaddr, buffer);
    log.debug("to write: {x}", .{std.fmt.fmtSliceHexLower(code)});
    log.debug("in memory: {x}", .{std.fmt.fmtSliceHexLower(memread)});
}

fn writeMemProtected(handle: std.process.Child.Id, pvaddr: std.os.windows.LPVOID, code: []const u8) !void {
    const old_prot = try std.os.windows.VirtualProtectEx(handle, pvaddr, code.len, std.os.windows.PAGE_EXECUTE_WRITECOPY);
    try writeMem(handle, pvaddr, code);
    // TODO: We can probably just set the pages writeable and leave it at that without having to restore the attributes.
    // For that though, we want to track which page has already been modified.
    _ = try std.os.windows.VirtualProtectEx(handle, pvaddr, code.len, old_prot);
}

fn writeMem(handle: std.process.Child.Id, pvaddr: std.os.windows.LPVOID, code: []const u8) !void {
    const amt = try std.os.windows.WriteProcessMemory(handle, pvaddr, code);
    if (amt != code.len) return error.InputOutput;
}

fn writeOffsetTableEntry(coff: *Coff, index: usize) !void {
    const sect_id = coff.got_section_index.?;

    if (coff.got_table_count_dirty) {
        const needed_size: u32 = @intCast(coff.got_table.entries.items.len * coff.ptr_width.size());
        try coff.growSection(sect_id, needed_size);
        coff.got_table_count_dirty = false;
    }

    const header = &coff.sections.items(.header)[sect_id];
    const entry = coff.got_table.entries.items[index];
    const entry_value = coff.getSymbol(entry).value;
    const entry_offset = index * coff.ptr_width.size();
    const file_offset = header.pointer_to_raw_data + entry_offset;
    const vmaddr = header.virtual_address + entry_offset;

    log.debug("writing GOT entry {d}: @{x} => {x}", .{ index, vmaddr, entry_value + coff.image_base });

    switch (coff.ptr_width) {
        .p32 => {
            var buf: [4]u8 = undefined;
            mem.writeInt(u32, &buf, @intCast(entry_value + coff.image_base), .little);
            try coff.base.file.?.pwriteAll(&buf, file_offset);
        },
        .p64 => {
            var buf: [8]u8 = undefined;
            mem.writeInt(u64, &buf, entry_value + coff.image_base, .little);
            try coff.base.file.?.pwriteAll(&buf, file_offset);
        },
    }

    if (is_hot_update_compatible) {
        if (coff.base.child_pid) |handle| {
            const gpa = coff.base.comp.gpa;
            const slide = @intFromPtr(coff.hot_state.loaded_base_address.?);
            const actual_vmaddr = vmaddr + slide;
            const pvaddr = @as(*anyopaque, @ptrFromInt(actual_vmaddr));
            log.debug("writing GOT entry to memory at address {x}", .{actual_vmaddr});
            if (build_options.enable_logging) {
                switch (coff.ptr_width) {
                    .p32 => {
                        var buf: [4]u8 = undefined;
                        try debugMem(gpa, handle, pvaddr, &buf);
                    },
                    .p64 => {
                        var buf: [8]u8 = undefined;
                        try debugMem(gpa, handle, pvaddr, &buf);
                    },
                }
            }

            switch (coff.ptr_width) {
                .p32 => {
                    var buf: [4]u8 = undefined;
                    mem.writeInt(u32, &buf, @as(u32, @intCast(entry_value + slide)), .little);
                    writeMem(handle, pvaddr, &buf) catch |err| {
                        log.warn("writing to protected memory failed with error: {s}", .{@errorName(err)});
                    };
                },
                .p64 => {
                    var buf: [8]u8 = undefined;
                    mem.writeInt(u64, &buf, entry_value + slide, .little);
                    writeMem(handle, pvaddr, &buf) catch |err| {
                        log.warn("writing to protected memory failed with error: {s}", .{@errorName(err)});
                    };
                },
            }
        }
    }
}

fn markRelocsDirtyByTarget(coff: *Coff, target: SymbolWithLoc) void {
    // TODO: reverse-lookup might come in handy here
    for (coff.relocs.values()) |*relocs| {
        for (relocs.items) |*reloc| {
            if (!reloc.target.eql(target)) continue;
            reloc.dirty = true;
        }
    }
}

fn markRelocsDirtyByAddress(coff: *Coff, addr: u32) void {
    const got_moved = blk: {
        const sect_id = coff.got_section_index orelse break :blk false;
        break :blk coff.sections.items(.header)[sect_id].virtual_address >= addr;
    };

    // TODO: dirty relocations targeting import table if that got moved in memory

    for (coff.relocs.values()) |*relocs| {
        for (relocs.items) |*reloc| {
            if (reloc.isGotIndirection()) {
                reloc.dirty = reloc.dirty or got_moved;
            } else {
                const target_vaddr = reloc.getTargetAddress(coff) orelse continue;
                if (target_vaddr >= addr) reloc.dirty = true;
            }
        }
    }

    // TODO: dirty only really affected GOT cells
    for (coff.got_table.entries.items) |entry| {
        const target_addr = coff.getSymbol(entry).value;
        if (target_addr >= addr) {
            coff.got_table_contents_dirty = true;
            break;
        }
    }
}

fn resolveRelocs(coff: *Coff, atom_index: Atom.Index, relocs: []const *const Relocation, code: []u8, image_base: u64) void {
    log.debug("relocating '{s}'", .{coff.getAtom(atom_index).getName(coff)});
    for (relocs) |reloc| {
        reloc.resolve(atom_index, code, image_base, coff);
    }
}

pub fn ptraceAttach(coff: *Coff, handle: std.process.Child.Id) !void {
    if (!is_hot_update_compatible) return;

    log.debug("attaching to process with handle {*}", .{handle});
    coff.hot_state.loaded_base_address = std.os.windows.ProcessBaseAddress(handle) catch |err| {
        log.warn("failed to get base address for the process with error: {s}", .{@errorName(err)});
        return;
    };
}

pub fn ptraceDetach(coff: *Coff, handle: std.process.Child.Id) void {
    if (!is_hot_update_compatible) return;

    log.debug("detaching from process with handle {*}", .{handle});
    coff.hot_state.loaded_base_address = null;
}

fn freeAtom(coff: *Coff, atom_index: Atom.Index) void {
    log.debug("freeAtom {d}", .{atom_index});

    const gpa = coff.base.comp.gpa;

    // Remove any relocs and base relocs associated with this Atom
    coff.freeRelocations(atom_index);

    const atom = coff.getAtom(atom_index);
    const sym = atom.getSymbol(coff);
    const sect_id = @intFromEnum(sym.section_number) - 1;
    const free_list = &coff.sections.items(.free_list)[sect_id];
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

    const maybe_last_atom_index = &coff.sections.items(.last_atom_index)[sect_id];
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
        const prev = coff.getAtomPtr(prev_index);
        prev.next_index = atom.next_index;

        if (!already_have_free_list_node and prev.*.freeListEligible(coff)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            free_list.append(gpa, prev_index) catch {};
        }
    } else {
        coff.getAtomPtr(atom_index).prev_index = null;
    }

    if (atom.next_index) |next_index| {
        coff.getAtomPtr(next_index).prev_index = atom.prev_index;
    } else {
        coff.getAtomPtr(atom_index).next_index = null;
    }

    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    const sym_index = atom.getSymbolIndex().?;
    coff.locals_free_list.append(gpa, sym_index) catch {};

    // Try freeing GOT atom if this decl had one
    coff.got_table.freeEntry(gpa, .{ .sym_index = sym_index });

    coff.locals.items[sym_index].section_number = .UNDEFINED;
    _ = coff.atom_by_index_table.remove(sym_index);
    log.debug("  adding local symbol index {d} to free list", .{sym_index});
    coff.getAtomPtr(atom_index).sym_index = 0;
}

pub fn updateFunc(
    coff: *Coff,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) link.File.UpdateNavError!void {
    if (build_options.skip_non_native and builtin.object_format != .coff) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (coff.llvm_object) |llvm_object| {
        return llvm_object.updateFunc(pt, func_index, air, liveness);
    }
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const func = zcu.funcInfo(func_index);
    const nav_index = func.owner_nav;

    const atom_index = try coff.getOrCreateAtomForNav(nav_index);
    coff.freeRelocations(atom_index);

    coff.navs.getPtr(func.owner_nav).?.section = coff.text_section_index.?;

    var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer code_buffer.deinit(gpa);

    codegen.generateFunction(
        &coff.base,
        pt,
        zcu.navSrcLoc(nav_index),
        func_index,
        air,
        liveness,
        &code_buffer,
        .none,
    ) catch |err| switch (err) {
        error.CodegenFail => return error.CodegenFail,
        error.OutOfMemory => return error.OutOfMemory,
        error.Overflow => |e| {
            try zcu.failed_codegen.putNoClobber(gpa, nav_index, try Zcu.ErrorMsg.create(
                gpa,
                zcu.navSrcLoc(nav_index),
                "unable to codegen: {s}",
                .{@errorName(e)},
            ));
            try zcu.retryable_failures.append(zcu.gpa, AnalUnit.wrap(.{ .func = func_index }));
            return error.CodegenFail;
        },
    };

    try coff.updateNavCode(pt, nav_index, code_buffer.items, .FUNCTION);

    // Exports will be updated by `Zcu.processExports` after the update.
}

const LowerConstResult = union(enum) {
    ok: Atom.Index,
    fail: *Zcu.ErrorMsg,
};

fn lowerConst(
    coff: *Coff,
    pt: Zcu.PerThread,
    name: []const u8,
    val: Value,
    required_alignment: InternPool.Alignment,
    sect_id: u16,
    src_loc: Zcu.LazySrcLoc,
) !LowerConstResult {
    const gpa = coff.base.comp.gpa;

    var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer code_buffer.deinit(gpa);

    const atom_index = try coff.createAtom();
    const sym = coff.getAtom(atom_index).getSymbolPtr(coff);
    try coff.setSymbolName(sym, name);
    sym.section_number = @as(coff_util.SectionNumber, @enumFromInt(sect_id + 1));

    try codegen.generateSymbol(&coff.base, pt, src_loc, val, &code_buffer, .{
        .atom_index = coff.getAtom(atom_index).getSymbolIndex().?,
    });
    const code = code_buffer.items;

    const atom = coff.getAtomPtr(atom_index);
    atom.size = @intCast(code.len);
    atom.getSymbolPtr(coff).value = try coff.allocateAtom(
        atom_index,
        atom.size,
        @intCast(required_alignment.toByteUnits().?),
    );
    errdefer coff.freeAtom(atom_index);

    log.debug("allocated atom for {s} at 0x{x}", .{ name, atom.getSymbol(coff).value });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    try coff.writeAtom(atom_index, code);

    return .{ .ok = atom_index };
}

pub fn updateNav(
    coff: *Coff,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
) link.File.UpdateNavError!void {
    if (build_options.skip_non_native and builtin.object_format != .coff) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (coff.llvm_object) |llvm_object| return llvm_object.updateNav(pt, nav_index);
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    const nav_val = zcu.navValue(nav_index);
    const nav_init = switch (ip.indexToKey(nav_val.toIntern())) {
        .func => return,
        .variable => |variable| Value.fromInterned(variable.init),
        .@"extern" => |@"extern"| {
            if (ip.isFunctionType(@"extern".ty)) return;
            // TODO make this part of getGlobalSymbol
            const name = nav.name.toSlice(ip);
            const lib_name = @"extern".lib_name.toSlice(ip);
            const global_index = try coff.getGlobalSymbol(name, lib_name);
            try coff.need_got_table.put(gpa, global_index, {});
            return;
        },
        else => nav_val,
    };

    if (nav_init.typeOf(zcu).hasRuntimeBits(zcu)) {
        const atom_index = try coff.getOrCreateAtomForNav(nav_index);
        coff.freeRelocations(atom_index);
        const atom = coff.getAtom(atom_index);

        coff.navs.getPtr(nav_index).?.section = coff.getNavOutputSection(nav_index);

        var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
        defer code_buffer.deinit(gpa);

        try codegen.generateSymbol(
            &coff.base,
            pt,
            zcu.navSrcLoc(nav_index),
            nav_init,
            &code_buffer,
            .{ .atom_index = atom.getSymbolIndex().? },
        );

        try coff.updateNavCode(pt, nav_index, code_buffer.items, .NULL);
    }

    // Exports will be updated by `Zcu.processExports` after the update.
}

fn updateLazySymbolAtom(
    coff: *Coff,
    pt: Zcu.PerThread,
    sym: link.File.LazySymbol,
    atom_index: Atom.Index,
    section_index: u16,
) !void {
    const zcu = pt.zcu;
    const comp = coff.base.comp;
    const gpa = comp.gpa;

    var required_alignment: InternPool.Alignment = .none;
    var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer code_buffer.deinit(gpa);

    const name = try allocPrint(gpa, "__lazy_{s}_{}", .{
        @tagName(sym.kind),
        Type.fromInterned(sym.ty).fmt(pt),
    });
    defer gpa.free(name);

    const atom = coff.getAtomPtr(atom_index);
    const local_sym_index = atom.getSymbolIndex().?;

    const src = Type.fromInterned(sym.ty).srcLocOrNull(zcu) orelse Zcu.LazySrcLoc.unneeded;
    try codegen.generateLazySymbol(
        &coff.base,
        pt,
        src,
        sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .atom_index = local_sym_index },
    );
    const code = code_buffer.items;

    const code_len: u32 = @intCast(code.len);
    const symbol = atom.getSymbolPtr(coff);
    try coff.setSymbolName(symbol, name);
    symbol.section_number = @enumFromInt(section_index + 1);
    symbol.type = .{ .complex_type = .NULL, .base_type = .NULL };

    const vaddr = try coff.allocateAtom(atom_index, code_len, @intCast(required_alignment.toByteUnits() orelse 0));
    errdefer coff.freeAtom(atom_index);

    log.debug("allocated atom for {s} at 0x{x}", .{ name, vaddr });
    log.debug("  (required alignment 0x{x})", .{required_alignment});

    atom.size = code_len;
    symbol.value = vaddr;

    try coff.addGotEntry(.{ .sym_index = local_sym_index });
    try coff.writeAtom(atom_index, code);
}

pub fn getOrCreateAtomForLazySymbol(
    coff: *Coff,
    pt: Zcu.PerThread,
    lazy_sym: link.File.LazySymbol,
) !Atom.Index {
    const gop = try coff.lazy_syms.getOrPut(pt.zcu.gpa, lazy_sym.ty);
    errdefer _ = if (!gop.found_existing) coff.lazy_syms.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const atom_ptr, const state_ptr = switch (lazy_sym.kind) {
        .code => .{ &gop.value_ptr.text_atom, &gop.value_ptr.text_state },
        .const_data => .{ &gop.value_ptr.rdata_atom, &gop.value_ptr.rdata_state },
    };
    switch (state_ptr.*) {
        .unused => atom_ptr.* = try coff.createAtom(),
        .pending_flush => return atom_ptr.*,
        .flushed => {},
    }
    state_ptr.* = .pending_flush;
    const atom = atom_ptr.*;
    // anyerror needs to be deferred until flushModule
    if (lazy_sym.ty != .anyerror_type) try coff.updateLazySymbolAtom(pt, lazy_sym, atom, switch (lazy_sym.kind) {
        .code => coff.text_section_index.?,
        .const_data => coff.rdata_section_index.?,
    });
    return atom;
}

pub fn getOrCreateAtomForNav(coff: *Coff, nav_index: InternPool.Nav.Index) !Atom.Index {
    const gpa = coff.base.comp.gpa;
    const gop = try coff.navs.getOrPut(gpa, nav_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{
            .atom = try coff.createAtom(),
            // If necessary, this will be modified by `updateNav` or `updateFunc`.
            .section = coff.rdata_section_index.?,
            .exports = .{},
        };
    }
    return gop.value_ptr.atom;
}

fn getNavOutputSection(coff: *Coff, nav_index: InternPool.Nav.Index) u16 {
    const zcu = coff.base.comp.zcu.?;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    const ty = Type.fromInterned(nav.typeOf(ip));
    const zig_ty = ty.zigTypeTag(zcu);
    const val = Value.fromInterned(nav.status.fully_resolved.val);
    const index: u16 = blk: {
        if (val.isUndefDeep(zcu)) {
            // TODO in release-fast and release-small, we should put undef in .bss
            break :blk coff.data_section_index.?;
        }

        switch (zig_ty) {
            // TODO: what if this is a function pointer?
            .@"fn" => break :blk coff.text_section_index.?,
            else => {
                if (val.getVariable(zcu)) |_| {
                    break :blk coff.data_section_index.?;
                }
                break :blk coff.rdata_section_index.?;
            },
        }
    };
    return index;
}

fn updateNavCode(
    coff: *Coff,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    code: []u8,
    complex_type: coff_util.ComplexType,
) link.File.UpdateNavError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    log.debug("updateNavCode {} 0x{x}", .{ nav.fqn.fmt(ip), nav_index });

    const target = zcu.navFileScope(nav_index).mod.resolved_target.result;
    const required_alignment = switch (pt.navAlignment(nav_index)) {
        .none => target_util.defaultFunctionAlignment(target),
        else => |a| a.maxStrict(target_util.minFunctionAlignment(target)),
    };

    const nav_metadata = coff.navs.get(nav_index).?;
    const atom_index = nav_metadata.atom;
    const atom = coff.getAtom(atom_index);
    const sym_index = atom.getSymbolIndex().?;
    const sect_index = nav_metadata.section;
    const code_len: u32 = @intCast(code.len);

    if (atom.size != 0) {
        const sym = atom.getSymbolPtr(coff);
        try coff.setSymbolName(sym, nav.fqn.toSlice(ip));
        sym.section_number = @enumFromInt(sect_index + 1);
        sym.type = .{ .complex_type = complex_type, .base_type = .NULL };

        const capacity = atom.capacity(coff);
        const need_realloc = code.len > capacity or !required_alignment.check(sym.value);
        if (need_realloc) {
            const vaddr = coff.growAtom(atom_index, code_len, @intCast(required_alignment.toByteUnits() orelse 0)) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return coff.base.cgFail(nav_index, "failed to grow atom: {s}", .{@errorName(e)}),
            };
            log.debug("growing {} from 0x{x} to 0x{x}", .{ nav.fqn.fmt(ip), sym.value, vaddr });
            log.debug("  (required alignment 0x{x}", .{required_alignment});

            if (vaddr != sym.value) {
                sym.value = vaddr;
                log.debug("  (updating GOT entry)", .{});
                const got_entry_index = coff.got_table.lookup.get(.{ .sym_index = sym_index }).?;
                coff.writeOffsetTableEntry(got_entry_index) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    else => |e| return coff.base.cgFail(nav_index, "failed to write offset table entry: {s}", .{@errorName(e)}),
                };
                coff.markRelocsDirtyByTarget(.{ .sym_index = sym_index });
            }
        } else if (code_len < atom.size) {
            coff.shrinkAtom(atom_index, code_len);
        }
        coff.getAtomPtr(atom_index).size = code_len;
    } else {
        const sym = atom.getSymbolPtr(coff);
        try coff.setSymbolName(sym, nav.fqn.toSlice(ip));
        sym.section_number = @enumFromInt(sect_index + 1);
        sym.type = .{ .complex_type = complex_type, .base_type = .NULL };

        const vaddr = coff.allocateAtom(atom_index, code_len, @intCast(required_alignment.toByteUnits() orelse 0)) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| return coff.base.cgFail(nav_index, "failed to allocate atom: {s}", .{@errorName(e)}),
        };
        errdefer coff.freeAtom(atom_index);
        log.debug("allocated atom for {} at 0x{x}", .{ nav.fqn.fmt(ip), vaddr });
        coff.getAtomPtr(atom_index).size = code_len;
        sym.value = vaddr;

        coff.addGotEntry(.{ .sym_index = sym_index }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| return coff.base.cgFail(nav_index, "failed to add GOT entry: {s}", .{@errorName(e)}),
        };
    }

    coff.writeAtom(atom_index, code) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return coff.base.cgFail(nav_index, "failed to write atom: {s}", .{@errorName(e)}),
    };
}

pub fn freeNav(coff: *Coff, nav_index: InternPool.NavIndex) void {
    if (coff.llvm_object) |llvm_object| return llvm_object.freeNav(nav_index);

    const gpa = coff.base.comp.gpa;

    if (coff.decls.fetchOrderedRemove(nav_index)) |const_kv| {
        var kv = const_kv;
        coff.freeAtom(kv.value.atom);
        kv.value.exports.deinit(gpa);
    }
}

pub fn updateExports(
    coff: *Coff,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) link.File.UpdateExportsError!void {
    if (build_options.skip_non_native and builtin.object_format != .coff) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const comp = coff.base.comp;
    const target = comp.root_mod.resolved_target.result;

    if (comp.config.use_llvm) {
        // Even in the case of LLVM, we need to notice certain exported symbols in order to
        // detect the default subsystem.
        for (export_indices) |export_idx| {
            const exp = export_idx.ptr(zcu);
            const exported_nav_index = switch (exp.exported) {
                .nav => |nav| nav,
                .uav => continue,
            };
            const exported_nav = ip.getNav(exported_nav_index);
            const exported_ty = exported_nav.typeOf(ip);
            if (!ip.isFunctionType(exported_ty)) continue;
            const c_cc = target.cCallingConvention().?;
            const winapi_cc: std.builtin.CallingConvention = switch (target.cpu.arch) {
                .x86 => .{ .x86_stdcall = .{} },
                else => c_cc,
            };
            const exported_cc = Type.fromInterned(exported_ty).fnCallingConvention(zcu);
            const CcTag = std.builtin.CallingConvention.Tag;
            if (@as(CcTag, exported_cc) == @as(CcTag, c_cc) and exp.opts.name.eqlSlice("main", ip) and comp.config.link_libc) {
                zcu.stage1_flags.have_c_main = true;
            } else if (@as(CcTag, exported_cc) == @as(CcTag, winapi_cc) and target.os.tag == .windows) {
                if (exp.opts.name.eqlSlice("WinMain", ip)) {
                    zcu.stage1_flags.have_winmain = true;
                } else if (exp.opts.name.eqlSlice("wWinMain", ip)) {
                    zcu.stage1_flags.have_wwinmain = true;
                } else if (exp.opts.name.eqlSlice("WinMainCRTStartup", ip)) {
                    zcu.stage1_flags.have_winmain_crt_startup = true;
                } else if (exp.opts.name.eqlSlice("wWinMainCRTStartup", ip)) {
                    zcu.stage1_flags.have_wwinmain_crt_startup = true;
                } else if (exp.opts.name.eqlSlice("DllMainCRTStartup", ip)) {
                    zcu.stage1_flags.have_dllmain_crt_startup = true;
                }
            }
        }
    }

    if (coff.llvm_object) |llvm_object| return llvm_object.updateExports(pt, exported, export_indices);

    const gpa = comp.gpa;

    const metadata = switch (exported) {
        .nav => |nav| blk: {
            _ = try coff.getOrCreateAtomForNav(nav);
            break :blk coff.navs.getPtr(nav).?;
        },
        .uav => |uav| coff.uavs.getPtr(uav) orelse blk: {
            const first_exp = export_indices[0].ptr(zcu);
            const res = try coff.lowerUav(pt, uav, .none, first_exp.src);
            switch (res) {
                .mcv => {},
                .fail => |em| {
                    // TODO maybe it's enough to return an error here and let Module.processExportsInner
                    // handle the error?
                    try zcu.failed_exports.ensureUnusedCapacity(zcu.gpa, 1);
                    zcu.failed_exports.putAssumeCapacityNoClobber(export_indices[0], em);
                    return;
                },
            }
            break :blk coff.uavs.getPtr(uav).?;
        },
    };
    const atom_index = metadata.atom;
    const atom = coff.getAtom(atom_index);

    for (export_indices) |export_idx| {
        const exp = export_idx.ptr(zcu);
        log.debug("adding new export '{}'", .{exp.opts.name.fmt(&zcu.intern_pool)});

        if (exp.opts.section.toSlice(&zcu.intern_pool)) |section_name| {
            if (!mem.eql(u8, section_name, ".text")) {
                try zcu.failed_exports.putNoClobber(gpa, export_idx, try Zcu.ErrorMsg.create(
                    gpa,
                    exp.src,
                    "Unimplemented: ExportOptions.section",
                    .{},
                ));
                continue;
            }
        }

        if (exp.opts.linkage == .link_once) {
            try zcu.failed_exports.putNoClobber(gpa, export_idx, try Zcu.ErrorMsg.create(
                gpa,
                exp.src,
                "Unimplemented: GlobalLinkage.link_once",
                .{},
            ));
            continue;
        }

        const exp_name = exp.opts.name.toSlice(&zcu.intern_pool);
        const sym_index = metadata.getExport(coff, exp_name) orelse blk: {
            const sym_index = if (coff.getGlobalIndex(exp_name)) |global_index| ind: {
                const global = coff.globals.items[global_index];
                // TODO this is just plain wrong as it all should happen in a single `resolveSymbols`
                // pass. This will go away once we abstact away Zig's incremental compilation into
                // its own module.
                if (global.file == null and coff.getSymbol(global).section_number == .UNDEFINED) {
                    _ = coff.unresolved.swapRemove(global_index);
                    break :ind global.sym_index;
                }
                break :ind try coff.allocateSymbol();
            } else try coff.allocateSymbol();
            try metadata.exports.append(gpa, sym_index);
            break :blk sym_index;
        };
        const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
        const sym = coff.getSymbolPtr(sym_loc);
        try coff.setSymbolName(sym, exp_name);
        sym.value = atom.getSymbol(coff).value;
        sym.section_number = @as(coff_util.SectionNumber, @enumFromInt(metadata.section + 1));
        sym.type = atom.getSymbol(coff).type;

        switch (exp.opts.linkage) {
            .strong => {
                sym.storage_class = .EXTERNAL;
            },
            .internal => @panic("TODO Internal"),
            .weak => @panic("TODO WeakExternal"),
            else => unreachable,
        }

        try coff.resolveGlobalSymbol(sym_loc);
    }
}

pub fn deleteExport(
    coff: *Coff,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    if (coff.llvm_object) |_| return;
    const metadata = switch (exported) {
        .nav => |nav| coff.navs.getPtr(nav),
        .uav => |uav| coff.uavs.getPtr(uav),
    } orelse return;
    const zcu = coff.base.comp.zcu.?;
    const name_slice = name.toSlice(&zcu.intern_pool);
    const sym_index = metadata.getExportPtr(coff, name_slice) orelse return;

    const gpa = coff.base.comp.gpa;
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index.*, .file = null };
    const sym = coff.getSymbolPtr(sym_loc);
    log.debug("deleting export '{}'", .{name.fmt(&zcu.intern_pool)});
    assert(sym.storage_class == .EXTERNAL and sym.section_number != .UNDEFINED);
    sym.* = .{
        .name = [_]u8{0} ** 8,
        .value = 0,
        .section_number = .UNDEFINED,
        .type = .{ .base_type = .NULL, .complex_type = .NULL },
        .storage_class = .NULL,
        .number_of_aux_symbols = 0,
    };
    coff.locals_free_list.append(gpa, sym_index.*) catch {};

    if (coff.resolver.fetchRemove(name_slice)) |entry| {
        defer gpa.free(entry.key);
        coff.globals_free_list.append(gpa, entry.value) catch {};
        coff.globals.items[entry.value] = .{
            .sym_index = 0,
            .file = null,
        };
    }

    sym_index.* = 0;
}

fn resolveGlobalSymbol(coff: *Coff, current: SymbolWithLoc) !void {
    const gpa = coff.base.comp.gpa;
    const sym = coff.getSymbol(current);
    const sym_name = coff.getSymbolName(current);

    const gop = try coff.getOrPutGlobalPtr(sym_name);
    if (!gop.found_existing) {
        gop.value_ptr.* = current;
        if (sym.section_number == .UNDEFINED) {
            try coff.unresolved.putNoClobber(gpa, coff.getGlobalIndex(sym_name).?, false);
        }
        return;
    }

    log.debug("TODO finish resolveGlobalSymbols implementation", .{});

    if (sym.section_number == .UNDEFINED) return;

    _ = coff.unresolved.swapRemove(coff.getGlobalIndex(sym_name).?);

    gop.value_ptr.* = current;
}

pub fn flush(coff: *Coff, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) link.File.FlushError!void {
    const comp = coff.base.comp;
    const use_lld = build_options.have_llvm and comp.config.use_lld;
    const diags = &comp.link_diags;
    if (use_lld) {
        return coff.linkWithLLD(arena, tid, prog_node) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.LinkFailure => return error.LinkFailure,
            else => |e| return diags.fail("failed to link with LLD: {s}", .{@errorName(e)}),
        };
    }
    switch (comp.config.output_mode) {
        .Exe, .Obj => return coff.flushModule(arena, tid, prog_node),
        .Lib => return diags.fail("writing lib files not yet implemented for COFF", .{}),
    }
}

fn linkWithLLD(coff: *Coff, arena: Allocator, tid: Zcu.PerThread.Id, prog_node: std.Progress.Node) !void {
    dev.check(.lld_linker);

    const tracy = trace(@src());
    defer tracy.end();

    const comp = coff.base.comp;
    const gpa = comp.gpa;

    const directory = coff.base.emit.root_dir; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{coff.base.emit.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (comp.zcu != null) blk: {
        try coff.flushModule(arena, tid, prog_node);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, coff.base.zcu_object_sub_path.? });
        } else {
            break :blk coff.base.zcu_object_sub_path.?;
        }
    } else null;

    const sub_prog_node = prog_node.start("LLD Link", 0);
    defer sub_prog_node.end();

    const is_lib = comp.config.output_mode == .Lib;
    const is_dyn_lib = comp.config.link_mode == .dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or comp.config.output_mode == .Exe;
    const link_in_crt = comp.config.link_libc and is_exe_or_dyn_lib;
    const target = comp.root_mod.resolved_target.result;
    const optimize_mode = comp.root_mod.optimize_mode;
    const entry_name: ?[]const u8 = switch (coff.entry) {
        // This logic isn't quite right for disabled or enabled. No point in fixing it
        // when the goal is to eliminate dependency on LLD anyway.
        // https://github.com/ziglang/zig/issues/17751
        .disabled, .default, .enabled => null,
        .named => |name| name,
    };

    // See link/Elf.zig for comments on how this mechanism works.
    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!coff.base.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!coff.base.disable_lld_caching) {
        man = comp.cache_parent.obtain();
        coff.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 14);

        try link.hashInputs(&man, comp.link_inputs);
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFilePath(key.status.success.object_path, null);
        }
        for (comp.win32_resource_table.keys()) |key| {
            _ = try man.addFile(key.status.success.res_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        man.hash.addOptionalBytes(entry_name);
        man.hash.add(coff.base.stack_size);
        man.hash.add(coff.image_base);
        {
            // TODO remove this, libraries must instead be resolved by the frontend.
            for (coff.lib_directories) |lib_directory| man.hash.addOptionalBytes(lib_directory.path);
        }
        man.hash.add(comp.skip_linker_dependencies);
        if (comp.config.link_libc) {
            man.hash.add(comp.libc_installation != null);
            if (comp.libc_installation) |libc_installation| {
                man.hash.addBytes(libc_installation.crt_dir.?);
                if (target.abi == .msvc or target.abi == .itanium) {
                    man.hash.addBytes(libc_installation.msvc_lib_dir.?);
                    man.hash.addBytes(libc_installation.kernel32_lib_dir.?);
                }
            }
        }
        man.hash.addListOfBytes(comp.windows_libs.keys());
        man.hash.addListOfBytes(comp.force_undefined_symbols.keys());
        man.hash.addOptional(coff.subsystem);
        man.hash.add(comp.config.is_test);
        man.hash.add(coff.tsaware);
        man.hash.add(coff.nxcompat);
        man.hash.add(coff.dynamicbase);
        man.hash.add(coff.base.allow_shlib_undefined);
        // strip does not need to go into the linker hash because it is part of the hash namespace
        man.hash.add(coff.major_subsystem_version);
        man.hash.add(coff.minor_subsystem_version);
        man.hash.add(coff.repro);
        man.hash.addOptional(comp.version);
        try man.addOptionalFile(coff.module_definition_file);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();
        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("COFF LLD new_digest={s} error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("COFF LLD digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
            // Hot diggity dog! The output binary is already there.
            coff.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("COFF LLD prev_digest={s} new_digest={s}", .{ std.fmt.fmtSliceHexLower(prev_digest), std.fmt.fmtSliceHexLower(&digest) });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    if (comp.config.output_mode == .Obj) {
        // LLD's COFF driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (link.firstObjectInput(comp.link_inputs)) |obj| break :blk obj.path;

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
            coff.base.emit.sub_path,
            .{},
        );
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(gpa);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "lld-link";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });

        if (target.isMinGW()) {
            try argv.append("-lldmingw");
        }

        try argv.append("-ERRORLIMIT:0");
        try argv.append("-NOLOGO");
        if (comp.config.debug_format != .strip) {
            try argv.append("-DEBUG");

            const out_ext = std.fs.path.extension(full_out_path);
            const out_pdb = coff.pdb_out_path orelse try allocPrint(arena, "{s}.pdb", .{
                full_out_path[0 .. full_out_path.len - out_ext.len],
            });
            const out_pdb_basename = std.fs.path.basename(out_pdb);

            try argv.append(try allocPrint(arena, "-PDB:{s}", .{out_pdb}));
            try argv.append(try allocPrint(arena, "-PDBALTPATH:{s}", .{out_pdb_basename}));
        }
        if (comp.version) |version| {
            try argv.append(try allocPrint(arena, "-VERSION:{}.{}", .{ version.major, version.minor }));
        }

        if (target_util.llvmMachineAbi(target)) |mabi| {
            try argv.append(try allocPrint(arena, "-MLLVM:-target-abi={s}", .{mabi}));
        }

        try argv.append(try allocPrint(arena, "-MLLVM:-float-abi={s}", .{if (target.abi.floatAbi() == .hard) "hard" else "soft"}));

        if (comp.config.lto != .none) {
            switch (optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("-OPT:lldlto=2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("-OPT:lldlto=3"),
            }
        }
        if (comp.config.output_mode == .Exe) {
            try argv.append(try allocPrint(arena, "-STACK:{d}", .{coff.base.stack_size}));
        }
        try argv.append(try allocPrint(arena, "-BASE:{d}", .{coff.image_base}));

        if (target.cpu.arch == .x86) {
            try argv.append("-MACHINE:X86");
        } else if (target.cpu.arch == .x86_64) {
            try argv.append("-MACHINE:X64");
        } else if (target.cpu.arch == .thumb) {
            try argv.append("-MACHINE:ARM");
        } else if (target.cpu.arch == .aarch64) {
            try argv.append("-MACHINE:ARM64");
        }

        for (comp.force_undefined_symbols.keys()) |symbol| {
            try argv.append(try allocPrint(arena, "-INCLUDE:{s}", .{symbol}));
        }

        if (is_dyn_lib) {
            try argv.append("-DLL");
        }

        if (entry_name) |name| {
            try argv.append(try allocPrint(arena, "-ENTRY:{s}", .{name}));
        }

        if (coff.repro) {
            try argv.append("-BREPRO");
        }

        if (coff.tsaware) {
            try argv.append("-tsaware");
        }
        if (coff.nxcompat) {
            try argv.append("-nxcompat");
        }
        if (!coff.dynamicbase) {
            try argv.append("-dynamicbase:NO");
        }
        if (coff.base.allow_shlib_undefined) {
            try argv.append("-FORCE:UNRESOLVED");
        }

        try argv.append(try allocPrint(arena, "-OUT:{s}", .{full_out_path}));

        if (comp.implib_emit) |emit| {
            const implib_out_path = try emit.root_dir.join(arena, &[_][]const u8{emit.sub_path});
            try argv.append(try allocPrint(arena, "-IMPLIB:{s}", .{implib_out_path}));
        }

        if (comp.config.link_libc) {
            if (comp.libc_installation) |libc_installation| {
                try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.crt_dir.?}));

                if (target.abi == .msvc or target.abi == .itanium) {
                    try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.msvc_lib_dir.?}));
                    try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.kernel32_lib_dir.?}));
                }
            }
        }

        for (coff.lib_directories) |lib_directory| {
            try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{lib_directory.path orelse "."}));
        }

        try argv.ensureUnusedCapacity(comp.link_inputs.len);
        for (comp.link_inputs) |link_input| switch (link_input) {
            .dso_exact => unreachable, // not applicable to PE/COFF
            inline .dso, .res => |x| {
                argv.appendAssumeCapacity(try x.path.toString(arena));
            },
            .object, .archive => |obj| {
                if (obj.must_link) {
                    argv.appendAssumeCapacity(try allocPrint(arena, "-WHOLEARCHIVE:{}", .{@as(Path, obj.path)}));
                } else {
                    argv.appendAssumeCapacity(try obj.path.toString(arena));
                }
            },
        };

        for (comp.c_object_table.keys()) |key| {
            try argv.append(try key.status.success.object_path.toString(arena));
        }

        for (comp.win32_resource_table.keys()) |key| {
            try argv.append(key.status.success.res_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (coff.module_definition_file) |def| {
            try argv.append(try allocPrint(arena, "-DEF:{s}", .{def}));
        }

        const resolved_subsystem: ?std.Target.SubSystem = blk: {
            if (coff.subsystem) |explicit| break :blk explicit;
            switch (target.os.tag) {
                .windows => {
                    if (comp.zcu) |module| {
                        if (module.stage1_flags.have_dllmain_crt_startup or is_dyn_lib)
                            break :blk null;
                        if (module.stage1_flags.have_c_main or comp.config.is_test or
                            module.stage1_flags.have_winmain_crt_startup or
                            module.stage1_flags.have_wwinmain_crt_startup)
                        {
                            break :blk .Console;
                        }
                        if (module.stage1_flags.have_winmain or module.stage1_flags.have_wwinmain)
                            break :blk .Windows;
                    }
                },
                .uefi => break :blk .EfiApplication,
                else => {},
            }
            break :blk null;
        };

        const Mode = enum { uefi, win32 };
        const mode: Mode = mode: {
            if (resolved_subsystem) |subsystem| {
                const subsystem_suffix = try allocPrint(arena, ",{d}.{d}", .{
                    coff.major_subsystem_version, coff.minor_subsystem_version,
                });

                switch (subsystem) {
                    .Console => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:console{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .EfiApplication => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_application{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiBootServiceDriver => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_boot_service_driver{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiRom => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_rom{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiRuntimeDriver => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_runtime_driver{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .Native => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:native{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .Posix => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:posix{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .Windows => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:windows{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                }
            } else if (target.os.tag == .uefi) {
                break :mode .uefi;
            } else {
                break :mode .win32;
            }
        };

        switch (mode) {
            .uefi => try argv.appendSlice(&[_][]const u8{
                "-BASE:0",
                "-ENTRY:EfiMain",
                "-OPT:REF",
                "-SAFESEH:NO",
                "-MERGE:.rdata=.data",
                "-NODEFAULTLIB",
                "-SECTION:.xdata,D",
            }),
            .win32 => {
                if (link_in_crt) {
                    if (target.abi.isGnu()) {
                        if (target.cpu.arch == .x86) {
                            try argv.append("-ALTERNATENAME:__image_base__=___ImageBase");
                        } else {
                            try argv.append("-ALTERNATENAME:__image_base__=__ImageBase");
                        }

                        if (is_dyn_lib) {
                            try argv.append(try comp.crtFileAsString(arena, "dllcrt2.obj"));
                            if (target.cpu.arch == .x86) {
                                try argv.append("-ALTERNATENAME:__DllMainCRTStartup@12=_DllMainCRTStartup@12");
                            } else {
                                try argv.append("-ALTERNATENAME:_DllMainCRTStartup=DllMainCRTStartup");
                            }
                        } else {
                            try argv.append(try comp.crtFileAsString(arena, "crt2.obj"));
                        }

                        try argv.append(try comp.crtFileAsString(arena, "mingw32.lib"));
                    } else {
                        const lib_str = switch (comp.config.link_mode) {
                            .dynamic => "",
                            .static => "lib",
                        };
                        const d_str = switch (optimize_mode) {
                            .Debug => "d",
                            else => "",
                        };
                        switch (comp.config.link_mode) {
                            .static => try argv.append(try allocPrint(arena, "libcmt{s}.lib", .{d_str})),
                            .dynamic => try argv.append(try allocPrint(arena, "msvcrt{s}.lib", .{d_str})),
                        }

                        try argv.append(try allocPrint(arena, "{s}vcruntime{s}.lib", .{ lib_str, d_str }));
                        try argv.append(try allocPrint(arena, "{s}ucrt{s}.lib", .{ lib_str, d_str }));

                        //Visual C++ 2015 Conformance Changes
                        //https://msdn.microsoft.com/en-us/library/bb531344.aspx
                        try argv.append("legacy_stdio_definitions.lib");

                        // msvcrt depends on kernel32 and ntdll
                        try argv.append("kernel32.lib");
                        try argv.append("ntdll.lib");
                    }
                } else {
                    try argv.append("-NODEFAULTLIB");
                    if (!is_lib and entry_name == null) {
                        if (comp.zcu) |module| {
                            if (module.stage1_flags.have_winmain_crt_startup) {
                                try argv.append("-ENTRY:WinMainCRTStartup");
                            } else {
                                try argv.append("-ENTRY:wWinMainCRTStartup");
                            }
                        } else {
                            try argv.append("-ENTRY:wWinMainCRTStartup");
                        }
                    }
                }
            },
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

        if (comp.config.any_fuzz) {
            try argv.append(try comp.fuzzer_lib.?.full_object_path.toString(arena));
        }

        if (is_exe_or_dyn_lib and !comp.skip_linker_dependencies) {
            if (!comp.config.link_libc) {
                if (comp.libc_static_lib) |lib| {
                    try argv.append(try lib.full_object_path.toString(arena));
                }
            }
            // MSVC compiler_rt is missing some stuff, so we build it unconditionally but
            // and rely on weak linkage to allow MSVC compiler_rt functions to override ours.
            if (comp.compiler_rt_obj) |obj| try argv.append(try obj.full_object_path.toString(arena));
            if (comp.compiler_rt_lib) |lib| try argv.append(try lib.full_object_path.toString(arena));
        }

        try argv.ensureUnusedCapacity(comp.windows_libs.count());
        for (comp.windows_libs.keys()) |key| {
            const lib_basename = try allocPrint(arena, "{s}.lib", .{key});
            if (comp.crt_files.get(lib_basename)) |crt_file| {
                argv.appendAssumeCapacity(try crt_file.full_object_path.toString(arena));
                continue;
            }
            if (try findLib(arena, lib_basename, coff.lib_directories)) |full_path| {
                argv.appendAssumeCapacity(full_path);
                continue;
            }
            if (target.abi.isGnu()) {
                const fallback_name = try allocPrint(arena, "lib{s}.dll.a", .{key});
                if (try findLib(arena, fallback_name, coff.lib_directories)) |full_path| {
                    argv.appendAssumeCapacity(full_path);
                    continue;
                }
            }
            if (target.abi == .msvc or target.abi == .itanium) {
                argv.appendAssumeCapacity(lib_basename);
                continue;
            }

            log.err("DLL import library for -l{s} not found", .{key});
            return error.DllImportLibraryNotFound;
        }

        try link.spawnLld(comp, arena, argv.items);
    }

    if (!coff.base.disable_lld_caching) {
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
        coff.base.lock = man.toOwnedLock();
    }
}

fn findLib(arena: Allocator, name: []const u8, lib_directories: []const Directory) !?[]const u8 {
    for (lib_directories) |lib_directory| {
        lib_directory.handle.access(name, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        return try lib_directory.join(arena, &.{name});
    }
    return null;
}

pub fn flushModule(
    coff: *Coff,
    arena: Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const comp = coff.base.comp;
    const diags = &comp.link_diags;

    if (coff.llvm_object) |llvm_object| {
        try coff.base.emitLlvmObject(arena, llvm_object, prog_node);
        return;
    }

    const sub_prog_node = prog_node.start("COFF Flush", 0);
    defer sub_prog_node.end();

    return flushModuleInner(coff, arena, tid) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.LinkFailure => return error.LinkFailure,
        else => |e| return diags.fail("COFF flush failed: {s}", .{@errorName(e)}),
    };
}

fn flushModuleInner(coff: *Coff, arena: Allocator, tid: Zcu.PerThread.Id) !void {
    _ = arena;

    const comp = coff.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;

    const pt: Zcu.PerThread = .activate(
        comp.zcu orelse return diags.fail("linking without zig source is not yet implemented", .{}),
        tid,
    );
    defer pt.deactivate();

    if (coff.lazy_syms.getPtr(.anyerror_type)) |metadata| {
        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) try coff.updateLazySymbolAtom(
            pt,
            .{ .kind = .code, .ty = .anyerror_type },
            metadata.text_atom,
            coff.text_section_index.?,
        );
        if (metadata.rdata_state != .unused) try coff.updateLazySymbolAtom(
            pt,
            .{ .kind = .const_data, .ty = .anyerror_type },
            metadata.rdata_atom,
            coff.rdata_section_index.?,
        );
    }
    for (coff.lazy_syms.values()) |*metadata| {
        if (metadata.text_state != .unused) metadata.text_state = .flushed;
        if (metadata.rdata_state != .unused) metadata.rdata_state = .flushed;
    }

    {
        var it = coff.need_got_table.iterator();
        while (it.next()) |entry| {
            const global = coff.globals.items[entry.key_ptr.*];
            try coff.addGotEntry(global);
        }
    }

    while (coff.unresolved.pop()) |entry| {
        assert(entry.value);
        const global = coff.globals.items[entry.key];
        const sym = coff.getSymbol(global);
        const res = try coff.import_tables.getOrPut(gpa, sym.value);
        const itable = res.value_ptr;
        if (!res.found_existing) {
            itable.* = .{};
        }
        if (itable.lookup.contains(global)) continue;
        // TODO: we could technically write the pointer placeholder for to-be-bound import here,
        // but since this happens in flush, there is currently no point.
        _ = try itable.addImport(gpa, global);
        coff.imports_count_dirty = true;
    }

    try coff.writeImportTables();

    for (coff.relocs.keys(), coff.relocs.values()) |atom_index, relocs| {
        const needs_update = for (relocs.items) |reloc| {
            if (reloc.dirty) break true;
        } else false;

        if (!needs_update) continue;

        const atom = coff.getAtom(atom_index);
        const sym = atom.getSymbol(coff);
        const section = coff.sections.get(@intFromEnum(sym.section_number) - 1).header;
        const file_offset = section.pointer_to_raw_data + sym.value - section.virtual_address;

        var code = std.ArrayList(u8).init(gpa);
        defer code.deinit();
        try code.resize(math.cast(usize, atom.size) orelse return error.Overflow);
        assert(atom.size > 0);

        const amt = try coff.base.file.?.preadAll(code.items, file_offset);
        if (amt != code.items.len) return error.InputOutput;

        try coff.writeAtom(atom_index, code.items);
    }

    // Update GOT if it got moved in memory.
    if (coff.got_table_contents_dirty) {
        for (coff.got_table.entries.items, 0..) |entry, i| {
            if (!coff.got_table.lookup.contains(entry)) continue;
            // TODO: write all in one go rather than incrementally.
            try coff.writeOffsetTableEntry(i);
        }
        coff.got_table_contents_dirty = false;
    }

    try coff.writeBaseRelocations();

    if (coff.getEntryPoint()) |entry_sym_loc| {
        coff.entry_addr = coff.getSymbol(entry_sym_loc).value;
    }

    if (build_options.enable_logging) {
        coff.logSymtab();
        coff.logImportTables();
    }

    try coff.writeStrtab();
    try coff.writeDataDirectoriesHeaders();
    try coff.writeSectionHeaders();

    if (coff.entry_addr == null and comp.config.output_mode == .Exe) {
        log.debug("flushing. no_entry_point_found = true\n", .{});
        diags.flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false\n", .{});
        diags.flags.no_entry_point_found = false;
        try coff.writeHeader();
    }

    assert(!coff.imports_count_dirty);
}

pub fn getNavVAddr(
    coff: *Coff,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    assert(coff.llvm_object == null);
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    log.debug("getNavVAddr {}({d})", .{ nav.fqn.fmt(ip), nav_index });
    const sym_index = if (nav.getExtern(ip)) |e|
        try coff.getGlobalSymbol(nav.name.toSlice(ip), e.lib_name.toSlice(ip))
    else
        coff.getAtom(try coff.getOrCreateAtomForNav(nav_index)).getSymbolIndex().?;
    const atom_index = coff.getAtomIndexForSymbol(.{
        .sym_index = reloc_info.parent.atom_index,
        .file = null,
    }).?;
    const target = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    try coff.addRelocation(atom_index, .{
        .type = .direct,
        .target = target,
        .offset = @as(u32, @intCast(reloc_info.offset)),
        .addend = reloc_info.addend,
        .pcrel = false,
        .length = 3,
    });
    try coff.addBaseRelocation(atom_index, @as(u32, @intCast(reloc_info.offset)));

    return 0;
}

pub fn lowerUav(
    coff: *Coff,
    pt: Zcu.PerThread,
    uav: InternPool.Index,
    explicit_alignment: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.GenResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const val = Value.fromInterned(uav);
    const uav_alignment = switch (explicit_alignment) {
        .none => val.typeOf(zcu).abiAlignment(zcu),
        else => explicit_alignment,
    };
    if (coff.uavs.get(uav)) |metadata| {
        const atom = coff.getAtom(metadata.atom);
        const existing_addr = atom.getSymbol(coff).value;
        if (uav_alignment.check(existing_addr))
            return .{ .mcv = .{ .load_direct = atom.getSymbolIndex().? } };
    }

    var name_buf: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "__anon_{d}", .{
        @intFromEnum(uav),
    }) catch unreachable;
    const res = coff.lowerConst(
        pt,
        name,
        val,
        uav_alignment,
        coff.rdata_section_index.?,
        src_loc,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Zcu.ErrorMsg.create(
            gpa,
            src_loc,
            "lowerAnonDecl failed with error: {s}",
            .{@errorName(e)},
        ) },
    };
    const atom_index = switch (res) {
        .ok => |atom_index| atom_index,
        .fail => |em| return .{ .fail = em },
    };
    try coff.uavs.put(gpa, uav, .{
        .atom = atom_index,
        .section = coff.rdata_section_index.?,
    });
    return .{ .mcv = .{
        .load_direct = coff.getAtom(atom_index).getSymbolIndex().?,
    } };
}

pub fn getUavVAddr(
    coff: *Coff,
    uav: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    assert(coff.llvm_object == null);

    const this_atom_index = coff.uavs.get(uav).?.atom;
    const sym_index = coff.getAtom(this_atom_index).getSymbolIndex().?;
    const atom_index = coff.getAtomIndexForSymbol(.{
        .sym_index = reloc_info.parent.atom_index,
        .file = null,
    }).?;
    const target = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    try coff.addRelocation(atom_index, .{
        .type = .direct,
        .target = target,
        .offset = @as(u32, @intCast(reloc_info.offset)),
        .addend = reloc_info.addend,
        .pcrel = false,
        .length = 3,
    });
    try coff.addBaseRelocation(atom_index, @as(u32, @intCast(reloc_info.offset)));

    return 0;
}

pub fn getGlobalSymbol(coff: *Coff, name: []const u8, lib_name_name: ?[]const u8) !u32 {
    const gop = try coff.getOrPutGlobalPtr(name);
    const global_index = coff.getGlobalIndex(name).?;

    if (gop.found_existing) {
        return global_index;
    }

    const sym_index = try coff.allocateSymbol();
    const sym_loc = SymbolWithLoc{ .sym_index = sym_index, .file = null };
    gop.value_ptr.* = sym_loc;

    const gpa = coff.base.comp.gpa;
    const sym = coff.getSymbolPtr(sym_loc);
    try coff.setSymbolName(sym, name);
    sym.storage_class = .EXTERNAL;

    if (lib_name_name) |lib_name| {
        // We repurpose the 'value' of the Symbol struct to store an offset into
        // temporary string table where we will store the library name hint.
        sym.value = try coff.temp_strtab.insert(gpa, lib_name);
    }

    try coff.unresolved.putNoClobber(gpa, global_index, true);

    return global_index;
}

pub fn updateLineNumber(coff: *Coff, pt: Zcu.PerThread, ti_id: InternPool.TrackedInst.Index) !void {
    _ = coff;
    _ = pt;
    _ = ti_id;
    log.debug("TODO implement updateLineNumber", .{});
}

/// TODO: note if we need to rewrite base relocations by dirtying any of the entries in the global table
/// TODO: note that .ABSOLUTE is used as padding within each block; we could use this fact to do
///       incremental updates and writes into the table instead of doing it all at once
fn writeBaseRelocations(coff: *Coff) !void {
    const gpa = coff.base.comp.gpa;

    var page_table = std.AutoHashMap(u32, std.ArrayList(coff_util.BaseRelocation)).init(gpa);
    defer {
        var it = page_table.valueIterator();
        while (it.next()) |inner| {
            inner.deinit();
        }
        page_table.deinit();
    }

    {
        var it = coff.base_relocs.iterator();
        while (it.next()) |entry| {
            const atom_index = entry.key_ptr.*;
            const atom = coff.getAtom(atom_index);
            const sym = atom.getSymbol(coff);
            const offsets = entry.value_ptr.*;

            for (offsets.items) |offset| {
                const rva = sym.value + offset;
                const page = mem.alignBackward(u32, rva, coff.page_size);
                const gop = try page_table.getOrPut(page);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList(coff_util.BaseRelocation).init(gpa);
                }
                try gop.value_ptr.append(.{
                    .offset = @as(u12, @intCast(rva - page)),
                    .type = .DIR64,
                });
            }
        }

        {
            const header = &coff.sections.items(.header)[coff.got_section_index.?];
            for (coff.got_table.entries.items, 0..) |entry, index| {
                if (!coff.got_table.lookup.contains(entry)) continue;

                const sym = coff.getSymbol(entry);
                if (sym.section_number == .UNDEFINED) continue;

                const rva = @as(u32, @intCast(header.virtual_address + index * coff.ptr_width.size()));
                const page = mem.alignBackward(u32, rva, coff.page_size);
                const gop = try page_table.getOrPut(page);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList(coff_util.BaseRelocation).init(gpa);
                }
                try gop.value_ptr.append(.{
                    .offset = @as(u12, @intCast(rva - page)),
                    .type = .DIR64,
                });
            }
        }
    }

    // Sort pages by address.
    var pages = try std.ArrayList(u32).initCapacity(gpa, page_table.count());
    defer pages.deinit();
    {
        var it = page_table.keyIterator();
        while (it.next()) |page| {
            pages.appendAssumeCapacity(page.*);
        }
    }
    mem.sort(u32, pages.items, {}, std.sort.asc(u32));

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    for (pages.items) |page| {
        const entries = page_table.getPtr(page).?;
        // Pad to required 4byte alignment
        if (!mem.isAlignedGeneric(
            usize,
            entries.items.len * @sizeOf(coff_util.BaseRelocation),
            @sizeOf(u32),
        )) {
            try entries.append(.{
                .offset = 0,
                .type = .ABSOLUTE,
            });
        }

        const block_size = @as(
            u32,
            @intCast(entries.items.len * @sizeOf(coff_util.BaseRelocation) + @sizeOf(coff_util.BaseRelocationDirectoryEntry)),
        );
        try buffer.ensureUnusedCapacity(block_size);
        buffer.appendSliceAssumeCapacity(mem.asBytes(&coff_util.BaseRelocationDirectoryEntry{
            .page_rva = page,
            .block_size = block_size,
        }));
        buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(entries.items));
    }

    const header = &coff.sections.items(.header)[coff.reloc_section_index.?];
    const needed_size = @as(u32, @intCast(buffer.items.len));
    try coff.growSection(coff.reloc_section_index.?, needed_size);

    try coff.pwriteAll(buffer.items, header.pointer_to_raw_data);

    coff.data_directories[@intFromEnum(coff_util.DirectoryEntry.BASERELOC)] = .{
        .virtual_address = header.virtual_address,
        .size = needed_size,
    };
}

fn writeImportTables(coff: *Coff) !void {
    if (coff.idata_section_index == null) return;
    if (!coff.imports_count_dirty) return;

    const gpa = coff.base.comp.gpa;

    const ext = ".dll";
    const header = &coff.sections.items(.header)[coff.idata_section_index.?];

    // Calculate needed size
    var iat_size: u32 = 0;
    var dir_table_size: u32 = @sizeOf(coff_util.ImportDirectoryEntry); // sentinel
    var lookup_table_size: u32 = 0;
    var names_table_size: u32 = 0;
    var dll_names_size: u32 = 0;
    for (coff.import_tables.keys(), 0..) |off, i| {
        const lib_name = coff.temp_strtab.getAssumeExists(off);
        const itable = coff.import_tables.values()[i];
        iat_size += itable.size() + 8;
        dir_table_size += @sizeOf(coff_util.ImportDirectoryEntry);
        lookup_table_size += @as(u32, @intCast(itable.entries.items.len + 1)) * @sizeOf(coff_util.ImportLookupEntry64.ByName);
        for (itable.entries.items) |entry| {
            const sym_name = coff.getSymbolName(entry);
            names_table_size += 2 + mem.alignForward(u32, @as(u32, @intCast(sym_name.len + 1)), 2);
        }
        dll_names_size += @as(u32, @intCast(lib_name.len + ext.len + 1));
    }

    const needed_size = iat_size + dir_table_size + lookup_table_size + names_table_size + dll_names_size;
    try coff.growSection(coff.idata_section_index.?, needed_size);

    // Do the actual writes
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(needed_size);
    buffer.resize(needed_size) catch unreachable;

    const dir_header_size = @sizeOf(coff_util.ImportDirectoryEntry);
    const lookup_entry_size = @sizeOf(coff_util.ImportLookupEntry64.ByName);

    var iat_offset: u32 = 0;
    var dir_table_offset = iat_size;
    var lookup_table_offset = dir_table_offset + dir_table_size;
    var names_table_offset = lookup_table_offset + lookup_table_size;
    var dll_names_offset = names_table_offset + names_table_size;
    for (coff.import_tables.keys(), 0..) |off, i| {
        const lib_name = coff.temp_strtab.getAssumeExists(off);
        const itable = coff.import_tables.values()[i];

        // Lookup table header
        const lookup_header = coff_util.ImportDirectoryEntry{
            .import_lookup_table_rva = header.virtual_address + lookup_table_offset,
            .time_date_stamp = 0,
            .forwarder_chain = 0,
            .name_rva = header.virtual_address + dll_names_offset,
            .import_address_table_rva = header.virtual_address + iat_offset,
        };
        @memcpy(buffer.items[dir_table_offset..][0..@sizeOf(coff_util.ImportDirectoryEntry)], mem.asBytes(&lookup_header));
        dir_table_offset += dir_header_size;

        for (itable.entries.items) |entry| {
            const import_name = coff.getSymbolName(entry);

            // IAT and lookup table entry
            const lookup = coff_util.ImportLookupEntry64.ByName{ .name_table_rva = @as(u31, @intCast(header.virtual_address + names_table_offset)) };
            @memcpy(
                buffer.items[iat_offset..][0..@sizeOf(coff_util.ImportLookupEntry64.ByName)],
                mem.asBytes(&lookup),
            );
            iat_offset += lookup_entry_size;
            @memcpy(
                buffer.items[lookup_table_offset..][0..@sizeOf(coff_util.ImportLookupEntry64.ByName)],
                mem.asBytes(&lookup),
            );
            lookup_table_offset += lookup_entry_size;

            // Names table entry
            mem.writeInt(u16, buffer.items[names_table_offset..][0..2], 0, .little); // Hint set to 0 until we learn how to parse DLLs
            names_table_offset += 2;
            @memcpy(buffer.items[names_table_offset..][0..import_name.len], import_name);
            names_table_offset += @as(u32, @intCast(import_name.len));
            buffer.items[names_table_offset] = 0;
            names_table_offset += 1;
            if (!mem.isAlignedGeneric(usize, names_table_offset, @sizeOf(u16))) {
                buffer.items[names_table_offset] = 0;
                names_table_offset += 1;
            }
        }

        // IAT sentinel
        mem.writeInt(u64, buffer.items[iat_offset..][0..lookup_entry_size], 0, .little);
        iat_offset += 8;

        // Lookup table sentinel
        @memcpy(
            buffer.items[lookup_table_offset..][0..@sizeOf(coff_util.ImportLookupEntry64.ByName)],
            mem.asBytes(&coff_util.ImportLookupEntry64.ByName{ .name_table_rva = 0 }),
        );
        lookup_table_offset += lookup_entry_size;

        // DLL name
        @memcpy(buffer.items[dll_names_offset..][0..lib_name.len], lib_name);
        dll_names_offset += @as(u32, @intCast(lib_name.len));
        @memcpy(buffer.items[dll_names_offset..][0..ext.len], ext);
        dll_names_offset += @as(u32, @intCast(ext.len));
        buffer.items[dll_names_offset] = 0;
        dll_names_offset += 1;
    }

    // Sentinel
    const lookup_header = coff_util.ImportDirectoryEntry{
        .import_lookup_table_rva = 0,
        .time_date_stamp = 0,
        .forwarder_chain = 0,
        .name_rva = 0,
        .import_address_table_rva = 0,
    };
    @memcpy(
        buffer.items[dir_table_offset..][0..@sizeOf(coff_util.ImportDirectoryEntry)],
        mem.asBytes(&lookup_header),
    );
    dir_table_offset += dir_header_size;

    assert(dll_names_offset == needed_size);

    try coff.pwriteAll(buffer.items, header.pointer_to_raw_data);

    coff.data_directories[@intFromEnum(coff_util.DirectoryEntry.IMPORT)] = .{
        .virtual_address = header.virtual_address + iat_size,
        .size = dir_table_size,
    };
    coff.data_directories[@intFromEnum(coff_util.DirectoryEntry.IAT)] = .{
        .virtual_address = header.virtual_address,
        .size = iat_size,
    };

    coff.imports_count_dirty = false;
}

fn writeStrtab(coff: *Coff) !void {
    if (coff.strtab_offset == null) return;

    const comp = coff.base.comp;
    const gpa = comp.gpa;
    const diags = &comp.link_diags;
    const allocated_size = coff.allocatedSize(coff.strtab_offset.?);
    const needed_size: u32 = @intCast(coff.strtab.buffer.items.len);

    if (needed_size > allocated_size) {
        coff.strtab_offset = null;
        coff.strtab_offset = @intCast(coff.findFreeSpace(needed_size, @alignOf(u32)));
    }

    log.debug("writing strtab from 0x{x} to 0x{x}", .{ coff.strtab_offset.?, coff.strtab_offset.? + needed_size });

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(needed_size);
    buffer.appendSliceAssumeCapacity(coff.strtab.buffer.items);
    // Here, we do a trick in that we do not commit the size of the strtab to strtab buffer, instead
    // we write the length of the strtab to a temporary buffer that goes to file.
    mem.writeInt(u32, buffer.items[0..4], @as(u32, @intCast(coff.strtab.buffer.items.len)), .little);

    coff.pwriteAll(buffer.items, coff.strtab_offset.?) catch |err| {
        return diags.fail("failed to write: {s}", .{@errorName(err)});
    };
}

fn writeSectionHeaders(coff: *Coff) !void {
    const offset = coff.getSectionHeadersOffset();
    try coff.pwriteAll(mem.sliceAsBytes(coff.sections.items(.header)), offset);
}

fn writeDataDirectoriesHeaders(coff: *Coff) !void {
    const offset = coff.getDataDirectoryHeadersOffset();
    try coff.pwriteAll(mem.sliceAsBytes(&coff.data_directories), offset);
}

fn writeHeader(coff: *Coff) !void {
    const target = coff.base.comp.root_mod.resolved_target.result;
    const gpa = coff.base.comp.gpa;
    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    const writer = buffer.writer();

    try buffer.ensureTotalCapacity(coff.getSizeOfHeaders());
    writer.writeAll(&msdos_stub) catch unreachable;
    mem.writeInt(u32, buffer.items[0x3c..][0..4], msdos_stub.len, .little);

    writer.writeAll("PE\x00\x00") catch unreachable;
    var flags = coff_util.CoffHeaderFlags{
        .EXECUTABLE_IMAGE = 1,
        .DEBUG_STRIPPED = 1, // TODO
    };
    switch (coff.ptr_width) {
        .p32 => flags.@"32BIT_MACHINE" = 1,
        .p64 => flags.LARGE_ADDRESS_AWARE = 1,
    }
    if (coff.base.comp.config.output_mode == .Lib and coff.base.comp.config.link_mode == .dynamic) {
        flags.DLL = 1;
    }

    const timestamp = if (coff.repro) 0 else std.time.timestamp();
    const size_of_optional_header = @as(u16, @intCast(coff.getOptionalHeaderSize() + coff.getDataDirectoryHeadersSize()));
    var coff_header = coff_util.CoffHeader{
        .machine = target.toCoffMachine(),
        .number_of_sections = @as(u16, @intCast(coff.sections.slice().len)), // TODO what if we prune a section
        .time_date_stamp = @as(u32, @truncate(@as(u64, @bitCast(timestamp)))),
        .pointer_to_symbol_table = coff.strtab_offset orelse 0,
        .number_of_symbols = 0,
        .size_of_optional_header = size_of_optional_header,
        .flags = flags,
    };

    writer.writeAll(mem.asBytes(&coff_header)) catch unreachable;

    const dll_flags: coff_util.DllFlags = .{
        .HIGH_ENTROPY_VA = 1, // TODO do we want to permit non-PIE builds at all?
        .DYNAMIC_BASE = 1,
        .TERMINAL_SERVER_AWARE = 1, // We are not a legacy app
        .NX_COMPAT = 1, // We are compatible with Data Execution Prevention
    };
    const subsystem: coff_util.Subsystem = .WINDOWS_CUI;
    const size_of_image: u32 = coff.getSizeOfImage();
    const size_of_headers: u32 = mem.alignForward(u32, coff.getSizeOfHeaders(), default_file_alignment);
    const base_of_code = coff.sections.get(coff.text_section_index.?).header.virtual_address;
    const base_of_data = coff.sections.get(coff.data_section_index.?).header.virtual_address;

    var size_of_code: u32 = 0;
    var size_of_initialized_data: u32 = 0;
    var size_of_uninitialized_data: u32 = 0;
    for (coff.sections.items(.header)) |header| {
        if (header.flags.CNT_CODE == 1) {
            size_of_code += header.size_of_raw_data;
        }
        if (header.flags.CNT_INITIALIZED_DATA == 1) {
            size_of_initialized_data += header.size_of_raw_data;
        }
        if (header.flags.CNT_UNINITIALIZED_DATA == 1) {
            size_of_uninitialized_data += header.size_of_raw_data;
        }
    }

    switch (coff.ptr_width) {
        .p32 => {
            var opt_header = coff_util.OptionalHeaderPE32{
                .magic = coff_util.IMAGE_NT_OPTIONAL_HDR32_MAGIC,
                .major_linker_version = 0,
                .minor_linker_version = 0,
                .size_of_code = size_of_code,
                .size_of_initialized_data = size_of_initialized_data,
                .size_of_uninitialized_data = size_of_uninitialized_data,
                .address_of_entry_point = coff.entry_addr orelse 0,
                .base_of_code = base_of_code,
                .base_of_data = base_of_data,
                .image_base = @intCast(coff.image_base),
                .section_alignment = coff.page_size,
                .file_alignment = default_file_alignment,
                .major_operating_system_version = 6,
                .minor_operating_system_version = 0,
                .major_image_version = 0,
                .minor_image_version = 0,
                .major_subsystem_version = @intCast(coff.major_subsystem_version),
                .minor_subsystem_version = @intCast(coff.minor_subsystem_version),
                .win32_version_value = 0,
                .size_of_image = size_of_image,
                .size_of_headers = size_of_headers,
                .checksum = 0,
                .subsystem = subsystem,
                .dll_flags = dll_flags,
                .size_of_stack_reserve = default_size_of_stack_reserve,
                .size_of_stack_commit = default_size_of_stack_commit,
                .size_of_heap_reserve = default_size_of_heap_reserve,
                .size_of_heap_commit = default_size_of_heap_commit,
                .loader_flags = 0,
                .number_of_rva_and_sizes = @intCast(coff.data_directories.len),
            };
            writer.writeAll(mem.asBytes(&opt_header)) catch unreachable;
        },
        .p64 => {
            var opt_header = coff_util.OptionalHeaderPE64{
                .magic = coff_util.IMAGE_NT_OPTIONAL_HDR64_MAGIC,
                .major_linker_version = 0,
                .minor_linker_version = 0,
                .size_of_code = size_of_code,
                .size_of_initialized_data = size_of_initialized_data,
                .size_of_uninitialized_data = size_of_uninitialized_data,
                .address_of_entry_point = coff.entry_addr orelse 0,
                .base_of_code = base_of_code,
                .image_base = coff.image_base,
                .section_alignment = coff.page_size,
                .file_alignment = default_file_alignment,
                .major_operating_system_version = 6,
                .minor_operating_system_version = 0,
                .major_image_version = 0,
                .minor_image_version = 0,
                .major_subsystem_version = coff.major_subsystem_version,
                .minor_subsystem_version = coff.minor_subsystem_version,
                .win32_version_value = 0,
                .size_of_image = size_of_image,
                .size_of_headers = size_of_headers,
                .checksum = 0,
                .subsystem = subsystem,
                .dll_flags = dll_flags,
                .size_of_stack_reserve = default_size_of_stack_reserve,
                .size_of_stack_commit = default_size_of_stack_commit,
                .size_of_heap_reserve = default_size_of_heap_reserve,
                .size_of_heap_commit = default_size_of_heap_commit,
                .loader_flags = 0,
                .number_of_rva_and_sizes = @intCast(coff.data_directories.len),
            };
            writer.writeAll(mem.asBytes(&opt_header)) catch unreachable;
        },
    }

    try coff.pwriteAll(buffer.items, 0);
}

pub fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    return actual_size +| (actual_size / ideal_factor);
}

fn detectAllocCollision(coff: *Coff, start: u32, size: u32) ?u32 {
    const headers_size = @max(coff.getSizeOfHeaders(), coff.page_size);
    if (start < headers_size)
        return headers_size;

    const end = start + padToIdeal(size);

    if (coff.strtab_offset) |off| {
        const tight_size = @as(u32, @intCast(coff.strtab.buffer.items.len));
        const increased_size = padToIdeal(tight_size);
        const test_end = off + increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    for (coff.sections.items(.header)) |header| {
        const tight_size = header.size_of_raw_data;
        const increased_size = padToIdeal(tight_size);
        const test_end = header.pointer_to_raw_data + increased_size;
        if (end > header.pointer_to_raw_data and start < test_end) {
            return test_end;
        }
    }

    return null;
}

fn allocatedSize(coff: *Coff, start: u32) u32 {
    if (start == 0)
        return 0;
    var min_pos: u32 = std.math.maxInt(u32);
    if (coff.strtab_offset) |off| {
        if (off > start and off < min_pos) min_pos = off;
    }
    for (coff.sections.items(.header)) |header| {
        if (header.pointer_to_raw_data <= start) continue;
        if (header.pointer_to_raw_data < min_pos) min_pos = header.pointer_to_raw_data;
    }
    return min_pos - start;
}

fn findFreeSpace(coff: *Coff, object_size: u32, min_alignment: u32) u32 {
    var start: u32 = 0;
    while (coff.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForward(u32, item_end, min_alignment);
    }
    return start;
}

fn allocatedVirtualSize(coff: *Coff, start: u32) u32 {
    if (start == 0)
        return 0;
    var min_pos: u32 = std.math.maxInt(u32);
    for (coff.sections.items(.header)) |header| {
        if (header.virtual_address <= start) continue;
        if (header.virtual_address < min_pos) min_pos = header.virtual_address;
    }
    return min_pos - start;
}

fn getSizeOfHeaders(coff: Coff) u32 {
    const msdos_hdr_size = msdos_stub.len + 4;
    return @as(u32, @intCast(msdos_hdr_size + @sizeOf(coff_util.CoffHeader) + coff.getOptionalHeaderSize() +
        coff.getDataDirectoryHeadersSize() + coff.getSectionHeadersSize()));
}

fn getOptionalHeaderSize(coff: Coff) u32 {
    return switch (coff.ptr_width) {
        .p32 => @as(u32, @intCast(@sizeOf(coff_util.OptionalHeaderPE32))),
        .p64 => @as(u32, @intCast(@sizeOf(coff_util.OptionalHeaderPE64))),
    };
}

fn getDataDirectoryHeadersSize(coff: Coff) u32 {
    return @as(u32, @intCast(coff.data_directories.len * @sizeOf(coff_util.ImageDataDirectory)));
}

fn getSectionHeadersSize(coff: Coff) u32 {
    return @as(u32, @intCast(coff.sections.slice().len * @sizeOf(coff_util.SectionHeader)));
}

fn getDataDirectoryHeadersOffset(coff: Coff) u32 {
    const msdos_hdr_size = msdos_stub.len + 4;
    return @as(u32, @intCast(msdos_hdr_size + @sizeOf(coff_util.CoffHeader) + coff.getOptionalHeaderSize()));
}

fn getSectionHeadersOffset(coff: Coff) u32 {
    return coff.getDataDirectoryHeadersOffset() + coff.getDataDirectoryHeadersSize();
}

fn getSizeOfImage(coff: Coff) u32 {
    var image_size: u32 = mem.alignForward(u32, coff.getSizeOfHeaders(), coff.page_size);
    for (coff.sections.items(.header)) |header| {
        image_size += mem.alignForward(u32, header.virtual_size, coff.page_size);
    }
    return image_size;
}

/// Returns symbol location corresponding to the set entrypoint (if any).
pub fn getEntryPoint(coff: Coff) ?SymbolWithLoc {
    const comp = coff.base.comp;

    // TODO This is incomplete.
    // The entry symbol name depends on the subsystem as well as the set of
    // public symbol names from linked objects.
    // See LinkerDriver::findDefaultEntry from the LLD project for the flow chart.
    const entry_name = switch (coff.entry) {
        .disabled => return null,
        .default => switch (comp.config.output_mode) {
            .Exe => "wWinMainCRTStartup",
            .Obj, .Lib => return null,
        },
        .enabled => "wWinMainCRTStartup",
        .named => |name| name,
    };
    const global_index = coff.resolver.get(entry_name) orelse return null;
    return coff.globals.items[global_index];
}

/// Returns pointer-to-symbol described by `sym_loc` descriptor.
pub fn getSymbolPtr(coff: *Coff, sym_loc: SymbolWithLoc) *coff_util.Symbol {
    assert(sym_loc.file == null); // TODO linking object files
    return &coff.locals.items[sym_loc.sym_index];
}

/// Returns symbol described by `sym_loc` descriptor.
pub fn getSymbol(coff: *const Coff, sym_loc: SymbolWithLoc) *const coff_util.Symbol {
    assert(sym_loc.file == null); // TODO linking object files
    return &coff.locals.items[sym_loc.sym_index];
}

/// Returns name of the symbol described by `sym_loc` descriptor.
pub fn getSymbolName(coff: *const Coff, sym_loc: SymbolWithLoc) []const u8 {
    assert(sym_loc.file == null); // TODO linking object files
    const sym = coff.getSymbol(sym_loc);
    const offset = sym.getNameOffset() orelse return sym.getName().?;
    return coff.strtab.get(offset).?;
}

/// Returns pointer to the global entry for `name` if one exists.
pub fn getGlobalPtr(coff: *Coff, name: []const u8) ?*SymbolWithLoc {
    const global_index = coff.resolver.get(name) orelse return null;
    return &coff.globals.items[global_index];
}

/// Returns the global entry for `name` if one exists.
pub fn getGlobal(coff: *const Coff, name: []const u8) ?SymbolWithLoc {
    const global_index = coff.resolver.get(name) orelse return null;
    return coff.globals.items[global_index];
}

/// Returns the index of the global entry for `name` if one exists.
pub fn getGlobalIndex(coff: *const Coff, name: []const u8) ?u32 {
    return coff.resolver.get(name);
}

/// Returns global entry at `index`.
pub fn getGlobalByIndex(coff: *const Coff, index: u32) SymbolWithLoc {
    assert(index < coff.globals.items.len);
    return coff.globals.items[index];
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
pub fn getOrPutGlobalPtr(coff: *Coff, name: []const u8) !GetOrPutGlobalPtrResult {
    if (coff.getGlobalPtr(name)) |ptr| {
        return GetOrPutGlobalPtrResult{ .found_existing = true, .value_ptr = ptr };
    }
    const gpa = coff.base.comp.gpa;
    const global_index = try coff.allocateGlobal();
    const global_name = try gpa.dupe(u8, name);
    _ = try coff.resolver.put(gpa, global_name, global_index);
    const ptr = &coff.globals.items[global_index];
    return GetOrPutGlobalPtrResult{ .found_existing = false, .value_ptr = ptr };
}

pub fn getAtom(coff: *const Coff, atom_index: Atom.Index) Atom {
    assert(atom_index < coff.atoms.items.len);
    return coff.atoms.items[atom_index];
}

pub fn getAtomPtr(coff: *Coff, atom_index: Atom.Index) *Atom {
    assert(atom_index < coff.atoms.items.len);
    return &coff.atoms.items[atom_index];
}

/// Returns atom if there is an atom referenced by the symbol described by `sym_loc` descriptor.
/// Returns null on failure.
pub fn getAtomIndexForSymbol(coff: *const Coff, sym_loc: SymbolWithLoc) ?Atom.Index {
    assert(sym_loc.file == null); // TODO linking with object files
    return coff.atom_by_index_table.get(sym_loc.sym_index);
}

fn setSectionName(coff: *Coff, header: *coff_util.SectionHeader, name: []const u8) !void {
    if (name.len <= 8) {
        @memcpy(header.name[0..name.len], name);
        @memset(header.name[name.len..], 0);
        return;
    }
    const gpa = coff.base.comp.gpa;
    const offset = try coff.strtab.insert(gpa, name);
    const name_offset = fmt.bufPrint(&header.name, "/{d}", .{offset}) catch unreachable;
    @memset(header.name[name_offset.len..], 0);
}

fn getSectionName(coff: *const Coff, header: *const coff_util.SectionHeader) []const u8 {
    if (header.getName()) |name| {
        return name;
    }
    const offset = header.getNameOffset().?;
    return coff.strtab.get(offset).?;
}

fn setSymbolName(coff: *Coff, symbol: *coff_util.Symbol, name: []const u8) !void {
    if (name.len <= 8) {
        @memcpy(symbol.name[0..name.len], name);
        @memset(symbol.name[name.len..], 0);
        return;
    }
    const gpa = coff.base.comp.gpa;
    const offset = try coff.strtab.insert(gpa, name);
    @memset(symbol.name[0..4], 0);
    mem.writeInt(u32, symbol.name[4..8], offset, .little);
}

fn logSymAttributes(sym: *const coff_util.Symbol, buf: *[4]u8) []const u8 {
    @memset(buf[0..4], '_');
    switch (sym.section_number) {
        .UNDEFINED => {
            buf[3] = 'u';
            switch (sym.storage_class) {
                .EXTERNAL => buf[1] = 'e',
                .WEAK_EXTERNAL => buf[1] = 'w',
                .NULL => {},
                else => unreachable,
            }
        },
        .ABSOLUTE => unreachable, // handle ABSOLUTE
        .DEBUG => unreachable,
        else => {
            buf[0] = 's';
            switch (sym.storage_class) {
                .EXTERNAL => buf[1] = 'e',
                .WEAK_EXTERNAL => buf[1] = 'w',
                .NULL => {},
                else => unreachable,
            }
        },
    }
    return buf[0..];
}

fn logSymtab(coff: *Coff) void {
    var buf: [4]u8 = undefined;

    log.debug("symtab:", .{});
    log.debug("  object(null)", .{});
    for (coff.locals.items, 0..) |*sym, sym_id| {
        const where = if (sym.section_number == .UNDEFINED) "ord" else "sect";
        const def_index: u16 = switch (sym.section_number) {
            .UNDEFINED => 0, // TODO
            .ABSOLUTE => unreachable, // TODO
            .DEBUG => unreachable, // TODO
            else => @intFromEnum(sym.section_number),
        };
        log.debug("    %{d}: {?s} @{x} in {s}({d}), {s}", .{
            sym_id,
            coff.getSymbolName(.{ .sym_index = @as(u32, @intCast(sym_id)), .file = null }),
            sym.value,
            where,
            def_index,
            logSymAttributes(sym, &buf),
        });
    }

    log.debug("globals table:", .{});
    for (coff.globals.items) |sym_loc| {
        const sym_name = coff.getSymbolName(sym_loc);
        log.debug("  {s} => %{d} in object({?d})", .{ sym_name, sym_loc.sym_index, sym_loc.file });
    }

    log.debug("GOT entries:", .{});
    log.debug("{}", .{coff.got_table});
}

fn logSections(coff: *Coff) void {
    log.debug("sections:", .{});
    for (coff.sections.items(.header)) |*header| {
        log.debug("  {s}: VM({x}, {x}) FILE({x}, {x})", .{
            coff.getSectionName(header),
            header.virtual_address,
            header.virtual_address + header.virtual_size,
            header.pointer_to_raw_data,
            header.pointer_to_raw_data + header.size_of_raw_data,
        });
    }
}

fn logImportTables(coff: *const Coff) void {
    log.debug("import tables:", .{});
    for (coff.import_tables.keys(), 0..) |off, i| {
        const itable = coff.import_tables.values()[i];
        log.debug("{}", .{itable.fmtDebug(.{
            .coff = coff,
            .index = i,
            .name_off = off,
        })});
    }
}

pub const Atom = struct {
    /// Each decl always gets a local symbol with the fully qualified name.
    /// The vaddr and size are found here directly.
    /// The file offset is found by computing the vaddr offset from the section vaddr
    /// the symbol references, and adding that to the file offset of the section.
    /// If this field is 0, it means the codegen size = 0 and there is no symbol or
    /// offset table entry.
    sym_index: u32,

    /// null means symbol defined by Zig source.
    file: ?u32,

    /// Size of the atom
    size: u32,

    /// Points to the previous and next neighbors, based on the `text_offset`.
    /// This can be used to find, for example, the capacity of this `Atom`.
    prev_index: ?Index,
    next_index: ?Index,

    const Index = u32;

    pub fn getSymbolIndex(atom: Atom) ?u32 {
        if (atom.sym_index == 0) return null;
        return atom.sym_index;
    }

    /// Returns symbol referencing this atom.
    fn getSymbol(atom: Atom, coff: *const Coff) *const coff_util.Symbol {
        const sym_index = atom.getSymbolIndex().?;
        return coff.getSymbol(.{
            .sym_index = sym_index,
            .file = atom.file,
        });
    }

    /// Returns pointer-to-symbol referencing this atom.
    fn getSymbolPtr(atom: Atom, coff: *Coff) *coff_util.Symbol {
        const sym_index = atom.getSymbolIndex().?;
        return coff.getSymbolPtr(.{
            .sym_index = sym_index,
            .file = atom.file,
        });
    }

    fn getSymbolWithLoc(atom: Atom) SymbolWithLoc {
        const sym_index = atom.getSymbolIndex().?;
        return .{ .sym_index = sym_index, .file = atom.file };
    }

    /// Returns the name of this atom.
    fn getName(atom: Atom, coff: *const Coff) []const u8 {
        const sym_index = atom.getSymbolIndex().?;
        return coff.getSymbolName(.{
            .sym_index = sym_index,
            .file = atom.file,
        });
    }

    /// Returns how much room there is to grow in virtual address space.
    fn capacity(atom: Atom, coff: *const Coff) u32 {
        const atom_sym = atom.getSymbol(coff);
        if (atom.next_index) |next_index| {
            const next = coff.getAtom(next_index);
            const next_sym = next.getSymbol(coff);
            return next_sym.value - atom_sym.value;
        } else {
            // We are the last atom.
            // The capacity is limited only by virtual address space.
            return std.math.maxInt(u32) - atom_sym.value;
        }
    }

    fn freeListEligible(atom: Atom, coff: *const Coff) bool {
        // No need to keep a free list node for the last atom.
        const next_index = atom.next_index orelse return false;
        const next = coff.getAtom(next_index);
        const atom_sym = atom.getSymbol(coff);
        const next_sym = next.getSymbol(coff);
        const cap = next_sym.value - atom_sym.value;
        const ideal_cap = padToIdeal(atom.size);
        if (cap <= ideal_cap) return false;
        const surplus = cap - ideal_cap;
        return surplus >= min_text_capacity;
    }
};

pub const Relocation = struct {
    type: enum {
        // x86, x86_64
        /// RIP-relative displacement to a GOT pointer
        got,
        /// RIP-relative displacement to an import pointer
        import,

        // aarch64
        /// PC-relative distance to target page in GOT section
        got_page,
        /// Offset to a GOT pointer relative to the start of a page in GOT section
        got_pageoff,
        /// PC-relative distance to target page in a section (e.g., .rdata)
        page,
        /// Offset to a pointer relative to the start of a page in a section (e.g., .rdata)
        pageoff,
        /// PC-relative distance to target page in a import section
        import_page,
        /// Offset to a pointer relative to the start of a page in an import section (e.g., .rdata)
        import_pageoff,

        // common
        /// Absolute pointer value
        direct,
    },
    target: SymbolWithLoc,
    offset: u32,
    addend: u32,
    pcrel: bool,
    length: u2,
    dirty: bool = true,

    /// Returns true if and only if the reloc can be resolved.
    fn isResolvable(reloc: Relocation, coff: *Coff) bool {
        _ = reloc.getTargetAddress(coff) orelse return false;
        return true;
    }

    fn isGotIndirection(reloc: Relocation) bool {
        return switch (reloc.type) {
            .got, .got_page, .got_pageoff => true,
            else => false,
        };
    }

    /// Returns address of the target if any.
    fn getTargetAddress(reloc: Relocation, coff: *const Coff) ?u32 {
        switch (reloc.type) {
            .got, .got_page, .got_pageoff => {
                const got_index = coff.got_table.lookup.get(reloc.target) orelse return null;
                const header = coff.sections.items(.header)[coff.got_section_index.?];
                return header.virtual_address + got_index * coff.ptr_width.size();
            },
            .import, .import_page, .import_pageoff => {
                const sym = coff.getSymbol(reloc.target);
                const index = coff.import_tables.getIndex(sym.value) orelse return null;
                const itab = coff.import_tables.values()[index];
                return itab.getImportAddress(reloc.target, .{
                    .coff = coff,
                    .index = index,
                    .name_off = sym.value,
                });
            },
            else => {
                const target_atom_index = coff.getAtomIndexForSymbol(reloc.target) orelse return null;
                const target_atom = coff.getAtom(target_atom_index);
                return target_atom.getSymbol(coff).value;
            },
        }
    }

    fn resolve(reloc: Relocation, atom_index: Atom.Index, code: []u8, image_base: u64, coff: *Coff) void {
        const atom = coff.getAtom(atom_index);
        const source_sym = atom.getSymbol(coff);
        const source_vaddr = source_sym.value + reloc.offset;

        const target_vaddr = reloc.getTargetAddress(coff).?; // Oops, you didn't check if the relocation can be resolved with isResolvable().
        const target_vaddr_with_addend = target_vaddr + reloc.addend;

        log.debug("  ({x}: [() => 0x{x} ({s})) ({s}) ", .{
            source_vaddr,
            target_vaddr_with_addend,
            coff.getSymbolName(reloc.target),
            @tagName(reloc.type),
        });

        const ctx: Context = .{
            .source_vaddr = source_vaddr,
            .target_vaddr = target_vaddr_with_addend,
            .image_base = image_base,
            .code = code,
            .ptr_width = coff.ptr_width,
        };

        const target = coff.base.comp.root_mod.resolved_target.result;
        switch (target.cpu.arch) {
            .aarch64 => reloc.resolveAarch64(ctx),
            .x86, .x86_64 => reloc.resolveX86(ctx),
            else => unreachable, // unhandled target architecture
        }
    }

    const Context = struct {
        source_vaddr: u32,
        target_vaddr: u32,
        image_base: u64,
        code: []u8,
        ptr_width: PtrWidth,
    };

    fn resolveAarch64(reloc: Relocation, ctx: Context) void {
        var buffer = ctx.code[reloc.offset..];
        switch (reloc.type) {
            .got_page, .import_page, .page => {
                const source_page = @as(i32, @intCast(ctx.source_vaddr >> 12));
                const target_page = @as(i32, @intCast(ctx.target_vaddr >> 12));
                const pages = @as(u21, @bitCast(@as(i21, @intCast(target_page - source_page))));
                var inst = aarch64_util.Instruction{
                    .pc_relative_address = mem.bytesToValue(std.meta.TagPayload(
                        aarch64_util.Instruction,
                        aarch64_util.Instruction.pc_relative_address,
                    ), buffer[0..4]),
                };
                inst.pc_relative_address.immhi = @as(u19, @truncate(pages >> 2));
                inst.pc_relative_address.immlo = @as(u2, @truncate(pages));
                mem.writeInt(u32, buffer[0..4], inst.toU32(), .little);
            },
            .got_pageoff, .import_pageoff, .pageoff => {
                assert(!reloc.pcrel);

                const narrowed = @as(u12, @truncate(@as(u64, @intCast(ctx.target_vaddr))));
                if (isArithmeticOp(buffer[0..4])) {
                    var inst = aarch64_util.Instruction{
                        .add_subtract_immediate = mem.bytesToValue(std.meta.TagPayload(
                            aarch64_util.Instruction,
                            aarch64_util.Instruction.add_subtract_immediate,
                        ), buffer[0..4]),
                    };
                    inst.add_subtract_immediate.imm12 = narrowed;
                    mem.writeInt(u32, buffer[0..4], inst.toU32(), .little);
                } else {
                    var inst = aarch64_util.Instruction{
                        .load_store_register = mem.bytesToValue(std.meta.TagPayload(
                            aarch64_util.Instruction,
                            aarch64_util.Instruction.load_store_register,
                        ), buffer[0..4]),
                    };
                    const offset: u12 = blk: {
                        if (inst.load_store_register.size == 0) {
                            if (inst.load_store_register.v == 1) {
                                // 128-bit SIMD is scaled by 16.
                                break :blk @divExact(narrowed, 16);
                            }
                            // Otherwise, 8-bit SIMD or ldrb.
                            break :blk narrowed;
                        } else {
                            const denom: u4 = math.powi(u4, 2, inst.load_store_register.size) catch unreachable;
                            break :blk @divExact(narrowed, denom);
                        }
                    };
                    inst.load_store_register.offset = offset;
                    mem.writeInt(u32, buffer[0..4], inst.toU32(), .little);
                }
            },
            .direct => {
                assert(!reloc.pcrel);
                switch (reloc.length) {
                    2 => mem.writeInt(
                        u32,
                        buffer[0..4],
                        @as(u32, @truncate(ctx.target_vaddr + ctx.image_base)),
                        .little,
                    ),
                    3 => mem.writeInt(u64, buffer[0..8], ctx.target_vaddr + ctx.image_base, .little),
                    else => unreachable,
                }
            },

            .got => unreachable,
            .import => unreachable,
        }
    }

    fn resolveX86(reloc: Relocation, ctx: Context) void {
        var buffer = ctx.code[reloc.offset..];
        switch (reloc.type) {
            .got_page => unreachable,
            .got_pageoff => unreachable,
            .page => unreachable,
            .pageoff => unreachable,
            .import_page => unreachable,
            .import_pageoff => unreachable,

            .got, .import => {
                assert(reloc.pcrel);
                const disp = @as(i32, @intCast(ctx.target_vaddr)) - @as(i32, @intCast(ctx.source_vaddr)) - 4;
                mem.writeInt(i32, buffer[0..4], disp, .little);
            },
            .direct => {
                if (reloc.pcrel) {
                    const disp = @as(i32, @intCast(ctx.target_vaddr)) - @as(i32, @intCast(ctx.source_vaddr)) - 4;
                    mem.writeInt(i32, buffer[0..4], disp, .little);
                } else switch (ctx.ptr_width) {
                    .p32 => mem.writeInt(u32, buffer[0..4], @as(u32, @intCast(ctx.target_vaddr + ctx.image_base)), .little),
                    .p64 => switch (reloc.length) {
                        2 => mem.writeInt(u32, buffer[0..4], @as(u32, @truncate(ctx.target_vaddr + ctx.image_base)), .little),
                        3 => mem.writeInt(u64, buffer[0..8], ctx.target_vaddr + ctx.image_base, .little),
                        else => unreachable,
                    },
                }
            },
        }
    }

    fn isArithmeticOp(inst: *const [4]u8) bool {
        const group_decode = @as(u5, @truncate(inst[3]));
        return ((group_decode >> 2) == 4);
    }
};

pub fn addRelocation(coff: *Coff, atom_index: Atom.Index, reloc: Relocation) !void {
    const comp = coff.base.comp;
    const gpa = comp.gpa;
    log.debug("  (adding reloc of type {s} to target %{d})", .{ @tagName(reloc.type), reloc.target.sym_index });
    const gop = try coff.relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, reloc);
}

fn addBaseRelocation(coff: *Coff, atom_index: Atom.Index, offset: u32) !void {
    const comp = coff.base.comp;
    const gpa = comp.gpa;
    log.debug("  (adding base relocation at offset 0x{x} in %{d})", .{
        offset,
        coff.getAtom(atom_index).getSymbolIndex().?,
    });
    const gop = try coff.base_relocs.getOrPut(gpa, atom_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(gpa, offset);
}

fn freeRelocations(coff: *Coff, atom_index: Atom.Index) void {
    const comp = coff.base.comp;
    const gpa = comp.gpa;
    var removed_relocs = coff.relocs.fetchOrderedRemove(atom_index);
    if (removed_relocs) |*relocs| relocs.value.deinit(gpa);
    var removed_base_relocs = coff.base_relocs.fetchOrderedRemove(atom_index);
    if (removed_base_relocs) |*base_relocs| base_relocs.value.deinit(gpa);
}

/// Represents an import table in the .idata section where each contained pointer
/// is to a symbol from the same DLL.
///
/// The layout of .idata section is as follows:
///
/// --- ADDR1 : IAT (all import tables concatenated together)
///     ptr
///     ptr
///     0 sentinel
///     ptr
///     0 sentinel
/// --- ADDR2: headers
///     ImportDirectoryEntry header
///     ImportDirectoryEntry header
///     sentinel
/// --- ADDR2: lookup tables
///     Lookup table
///     0 sentinel
///     Lookup table
///     0 sentinel
/// --- ADDR3: name hint tables
///     hint-symname
///     hint-symname
/// --- ADDR4: DLL names
///     DLL#1 name
///     DLL#2 name
/// --- END
const ImportTable = struct {
    entries: std.ArrayListUnmanaged(SymbolWithLoc) = .empty,
    free_list: std.ArrayListUnmanaged(u32) = .empty,
    lookup: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .empty,

    fn deinit(itab: *ImportTable, allocator: Allocator) void {
        itab.entries.deinit(allocator);
        itab.free_list.deinit(allocator);
        itab.lookup.deinit(allocator);
    }

    /// Size of the import table does not include the sentinel.
    fn size(itab: ImportTable) u32 {
        return @as(u32, @intCast(itab.entries.items.len)) * @sizeOf(u64);
    }

    fn addImport(itab: *ImportTable, allocator: Allocator, target: SymbolWithLoc) !ImportIndex {
        try itab.entries.ensureUnusedCapacity(allocator, 1);
        const index: u32 = blk: {
            if (itab.free_list.pop()) |index| {
                log.debug("  (reusing import entry index {d})", .{index});
                break :blk index;
            } else {
                log.debug("  (allocating import entry at index {d})", .{itab.entries.items.len});
                const index = @as(u32, @intCast(itab.entries.items.len));
                _ = itab.entries.addOneAssumeCapacity();
                break :blk index;
            }
        };
        itab.entries.items[index] = target;
        try itab.lookup.putNoClobber(allocator, target, index);
        return index;
    }

    const Context = struct {
        coff: *const Coff,
        /// Index of this ImportTable in a global list of all tables.
        /// This is required in order to calculate the base vaddr of this ImportTable.
        index: usize,
        /// Offset into the string interning table of the DLL this ImportTable corresponds to.
        name_off: u32,
    };

    fn getBaseAddress(ctx: Context) u32 {
        const header = ctx.coff.sections.items(.header)[ctx.coff.idata_section_index.?];
        var addr = header.virtual_address;
        for (ctx.coff.import_tables.values(), 0..) |other_itab, i| {
            if (ctx.index == i) break;
            addr += @as(u32, @intCast(other_itab.entries.items.len * @sizeOf(u64))) + 8;
        }
        return addr;
    }

    fn getImportAddress(itab: *const ImportTable, target: SymbolWithLoc, ctx: Context) ?u32 {
        const index = itab.lookup.get(target) orelse return null;
        const base_vaddr = getBaseAddress(ctx);
        return base_vaddr + index * @sizeOf(u64);
    }

    const FormatContext = struct {
        itab: ImportTable,
        ctx: Context,
    };

    fn format(itab: ImportTable, comptime unused_format_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = itab;
        _ = unused_format_string;
        _ = options;
        _ = writer;
        @compileError("do not format ImportTable directly; use itab.fmtDebug()");
    }

    fn format2(
        fmt_ctx: FormatContext,
        comptime unused_format_string: []const u8,
        options: fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        _ = options;
        comptime assert(unused_format_string.len == 0);
        const lib_name = fmt_ctx.ctx.coff.temp_strtab.getAssumeExists(fmt_ctx.ctx.name_off);
        const base_vaddr = getBaseAddress(fmt_ctx.ctx);
        try writer.print("IAT({s}.dll) @{x}:", .{ lib_name, base_vaddr });
        for (fmt_ctx.itab.entries.items, 0..) |entry, i| {
            try writer.print("\n  {d}@{?x} => {s}", .{
                i,
                fmt_ctx.itab.getImportAddress(entry, fmt_ctx.ctx),
                fmt_ctx.ctx.coff.getSymbolName(entry),
            });
        }
    }

    fn fmtDebug(itab: ImportTable, ctx: Context) fmt.Formatter(format2) {
        return .{ .data = .{ .itab = itab, .ctx = ctx } };
    }

    const ImportIndex = u32;
};

fn pwriteAll(coff: *Coff, bytes: []const u8, offset: u64) error{LinkFailure}!void {
    const comp = coff.base.comp;
    const diags = &comp.link_diags;
    coff.base.file.?.pwriteAll(bytes, offset) catch |err| {
        return diags.fail("failed to write: {s}", .{@errorName(err)});
    };
}

const Coff = @This();

const std = @import("std");
const build_options = @import("build_options");
const builtin = @import("builtin");
const assert = std.debug.assert;
const coff_util = std.coff;
const fmt = std.fmt;
const fs = std.fs;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;

const Allocator = std.mem.Allocator;
const Path = std.Build.Cache.Path;
const Directory = std.Build.Cache.Directory;
const Cache = std.Build.Cache;

const aarch64_util = @import("../arch/aarch64/bits.zig");
const allocPrint = std.fmt.allocPrint;
const codegen = @import("../codegen.zig");
const link = @import("../link.zig");
const target_util = @import("../target.zig");
const trace = @import("../tracy.zig").trace;

const Air = @import("../Air.zig");
const Compilation = @import("../Compilation.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;
const Zcu = @import("../Zcu.zig");
const InternPool = @import("../InternPool.zig");
const TableSection = @import("table_section.zig").TableSection;
const StringTable = @import("StringTable.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const AnalUnit = InternPool.AnalUnit;
const dev = @import("../dev.zig");

/// This is the start of a Portable Executable (PE) file.
/// It starts with a MS-DOS header followed by a MS-DOS stub program.
/// This data does not change so we include it as follows in all binaries.
///
/// In this context,
/// A "paragraph" is 16 bytes.
/// A "page" is 512 bytes.
/// A "long" is 4 bytes.
/// A "word" is 2 bytes.
const msdos_stub: [120]u8 = .{
    'M', 'Z', // Magic number. Stands for Mark Zbikowski (designer of the MS-DOS executable format).
    0x78, 0x00, // Number of bytes in the last page. This matches the size of this entire MS-DOS stub.
    0x01, 0x00, // Number of pages.
    0x00, 0x00, // Number of entries in the relocation table.
    0x04, 0x00, // The number of paragraphs taken up by the header. 4 * 16 = 64, which matches the header size (all bytes before the MS-DOS stub program).
    0x00, 0x00, // The number of paragraphs required by the program.
    0x00, 0x00, // The number of paragraphs requested by the program.
    0x00, 0x00, // Initial value for SS (relocatable segment address).
    0x00, 0x00, // Initial value for SP.
    0x00, 0x00, // Checksum.
    0x00, 0x00, // Initial value for IP.
    0x00, 0x00, // Initial value for CS (relocatable segment address).
    0x40, 0x00, // Absolute offset to relocation table. 64 matches the header size (all bytes before the MS-DOS stub program).
    0x00, 0x00, // Overlay number. Zero means this is the main executable.
}
// Reserved words.
++ .{ 0x00, 0x00 } ** 4
// OEM-related fields.
++ .{
    0x00, 0x00, // OEM identifier.
    0x00, 0x00, // OEM information.
}
// Reserved words.
++ .{ 0x00, 0x00 } ** 10
// Address of the PE header (a long). This matches the size of this entire MS-DOS stub, so that's the address of what's after this MS-DOS stub.
++ .{ 0x78, 0x00, 0x00, 0x00 }
// What follows is a 16-bit x86 MS-DOS program of 7 instructions that prints the bytes after these instructions and then exits.
++ .{
    // Set the value of the data segment to the same value as the code segment.
    0x0e, // push cs
    0x1f, // pop ds
    // Set the DX register to the address of the message.
    // If you count all bytes of these 7 instructions you get 14, so that's the address of what's after these instructions.
    0xba, 14, 0x00, // mov dx, 14
    // Set AH to the system call code for printing a message.
    0xb4, 0x09, // mov ah, 0x09
    // Perform the system call to print the message.
    0xcd, 0x21, // int 0x21
    // Set AH to 0x4c which is the system call code for exiting, and set AL to 0x01 which is the exit code.
    0xb8, 0x01, 0x4c, // mov ax, 0x4c01
    // Peform the system call to exit the program with exit code 1.
    0xcd, 0x21, // int 0x21
}
// Message to print.
++ "This program cannot be run in DOS mode.".*
// Message terminators.
++ .{
    '$', // We do not pass a length to the print system call; the string is terminated by this character.
    0x00, 0x00, // Terminating zero bytes.
};
