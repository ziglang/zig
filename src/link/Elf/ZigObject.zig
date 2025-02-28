//! ZigObject encapsulates the state of the incrementally compiled Zig module.
//! It stores the associated input local and global symbols, allocated atoms,
//! and any relocations that may have been emitted.
//! Think about this as fake in-memory Object file for the Zig module.

data: std.ArrayListUnmanaged(u8) = .empty,
/// Externally owned memory.
basename: []const u8,
index: File.Index,

symtab: std.MultiArrayList(ElfSym) = .{},
strtab: StringTable = .{},
symbols: std.ArrayListUnmanaged(Symbol) = .empty,
symbols_extra: std.ArrayListUnmanaged(u32) = .empty,
symbols_resolver: std.ArrayListUnmanaged(Elf.SymbolResolver.Index) = .empty,
local_symbols: std.ArrayListUnmanaged(Symbol.Index) = .empty,
global_symbols: std.ArrayListUnmanaged(Symbol.Index) = .empty,
globals_lookup: std.AutoHashMapUnmanaged(u32, Symbol.Index) = .empty,

atoms: std.ArrayListUnmanaged(Atom) = .empty,
atoms_indexes: std.ArrayListUnmanaged(Atom.Index) = .empty,
atoms_extra: std.ArrayListUnmanaged(u32) = .empty,
relocs: std.ArrayListUnmanaged(std.ArrayListUnmanaged(elf.Elf64_Rela)) = .empty,

num_dynrelocs: u32 = 0,

output_symtab_ctx: Elf.SymtabCtx = .{},
output_ar_state: Archive.ArState = .{},

dwarf: ?Dwarf = null,

/// Table of tracked LazySymbols.
lazy_syms: LazySymbolTable = .{},

/// Table of tracked `Nav`s.
navs: NavTable = .{},

/// TLS variables indexed by Atom.Index.
tls_variables: TlsTable = .{},

/// Table of tracked `Uav`s.
uavs: UavTable = .{},

debug_info_section_dirty: bool = false,
debug_abbrev_section_dirty: bool = false,
debug_aranges_section_dirty: bool = false,
debug_str_section_dirty: bool = false,
debug_line_section_dirty: bool = false,
debug_line_str_section_dirty: bool = false,
debug_loclists_section_dirty: bool = false,
debug_rnglists_section_dirty: bool = false,
eh_frame_section_dirty: bool = false,

text_index: ?Symbol.Index = null,
rodata_index: ?Symbol.Index = null,
data_relro_index: ?Symbol.Index = null,
data_index: ?Symbol.Index = null,
bss_index: ?Symbol.Index = null,
tdata_index: ?Symbol.Index = null,
tbss_index: ?Symbol.Index = null,
eh_frame_index: ?Symbol.Index = null,
debug_info_index: ?Symbol.Index = null,
debug_abbrev_index: ?Symbol.Index = null,
debug_aranges_index: ?Symbol.Index = null,
debug_str_index: ?Symbol.Index = null,
debug_line_index: ?Symbol.Index = null,
debug_line_str_index: ?Symbol.Index = null,
debug_loclists_index: ?Symbol.Index = null,
debug_rnglists_index: ?Symbol.Index = null,

pub const global_symbol_bit: u32 = 0x80000000;
pub const symbol_mask: u32 = 0x7fffffff;
pub const SHN_ATOM: u16 = 0x100;

const InitOptions = struct {
    symbol_count_hint: u64,
    program_code_size_hint: u64,
};

pub fn init(self: *ZigObject, elf_file: *Elf, options: InitOptions) !void {
    _ = options;
    const comp = elf_file.base.comp;
    const gpa = comp.gpa;
    const ptr_size = elf_file.ptrWidthBytes();

    try self.atoms.append(gpa, .{ .extra_index = try self.addAtomExtra(gpa, .{}) }); // null input section
    try self.relocs.append(gpa, .{}); // null relocs section
    try self.strtab.buffer.append(gpa, 0);

    {
        const name_off = try self.strtab.insert(gpa, self.basename);
        const symbol_index = try self.newLocalSymbol(gpa, name_off);
        const sym = self.symbol(symbol_index);
        const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
        esym.st_info = elf.STT_FILE;
        esym.st_shndx = elf.SHN_ABS;
    }

    switch (comp.config.debug_format) {
        .strip => {},
        .dwarf => |v| {
            var dwarf = Dwarf.init(&elf_file.base, v);

            const addSectionSymbolWithAtom = struct {
                fn addSectionSymbolWithAtom(
                    zo: *ZigObject,
                    allocator: Allocator,
                    name: [:0]const u8,
                    alignment: Atom.Alignment,
                    shndx: u32,
                ) !Symbol.Index {
                    const name_off = try zo.addString(allocator, name);
                    const sym_index = try zo.addSectionSymbol(allocator, name_off, shndx);
                    const sym = zo.symbol(sym_index);
                    const atom_index = try zo.newAtom(allocator, name_off);
                    const atom_ptr = zo.atom(atom_index).?;
                    atom_ptr.alignment = alignment;
                    atom_ptr.output_section_index = shndx;
                    sym.ref = .{ .index = atom_index, .file = zo.index };
                    zo.symtab.items(.shndx)[sym.esym_index] = atom_index;
                    zo.symtab.items(.elf_sym)[sym.esym_index].st_shndx = SHN_ATOM;
                    return sym_index;
                }
            }.addSectionSymbolWithAtom;

            if (self.debug_str_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_str"),
                    .flags = elf.SHF_MERGE | elf.SHF_STRINGS,
                    .entsize = 1,
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_str_section_dirty = true;
                self.debug_str_index = try addSectionSymbolWithAtom(self, gpa, ".debug_str", .@"1", osec);
            }

            if (self.debug_info_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_info"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_info_section_dirty = true;
                self.debug_info_index = try addSectionSymbolWithAtom(self, gpa, ".debug_info", .@"1", osec);
            }

            if (self.debug_abbrev_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_abbrev"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_abbrev_section_dirty = true;
                self.debug_abbrev_index = try addSectionSymbolWithAtom(self, gpa, ".debug_abbrev", .@"1", osec);
            }

            if (self.debug_aranges_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_aranges"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = 16,
                });
                self.debug_aranges_section_dirty = true;
                self.debug_aranges_index = try addSectionSymbolWithAtom(self, gpa, ".debug_aranges", .@"16", osec);
            }

            if (self.debug_line_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_line"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_line_section_dirty = true;
                self.debug_line_index = try addSectionSymbolWithAtom(self, gpa, ".debug_line", .@"1", osec);
            }

            if (self.debug_line_str_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_line_str"),
                    .flags = elf.SHF_MERGE | elf.SHF_STRINGS,
                    .entsize = 1,
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_line_str_section_dirty = true;
                self.debug_line_str_index = try addSectionSymbolWithAtom(self, gpa, ".debug_line_str", .@"1", osec);
            }

            if (self.debug_loclists_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_loclists"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_loclists_section_dirty = true;
                self.debug_loclists_index = try addSectionSymbolWithAtom(self, gpa, ".debug_loclists", .@"1", osec);
            }

            if (self.debug_rnglists_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".debug_rnglists"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.debug_rnglists_section_dirty = true;
                self.debug_rnglists_index = try addSectionSymbolWithAtom(self, gpa, ".debug_rnglists", .@"1", osec);
            }

            if (self.eh_frame_index == null) {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".eh_frame"),
                    .type = if (elf_file.getTarget().cpu.arch == .x86_64)
                        elf.SHT_X86_64_UNWIND
                    else
                        elf.SHT_PROGBITS,
                    .flags = elf.SHF_ALLOC,
                    .addralign = ptr_size,
                });
                self.eh_frame_section_dirty = true;
                self.eh_frame_index = try addSectionSymbolWithAtom(self, gpa, ".eh_frame", Atom.Alignment.fromNonzeroByteUnits(ptr_size), osec);
            }

            try dwarf.initMetadata();
            self.dwarf = dwarf;
        },
        .code_view => unreachable,
    }
}

pub fn deinit(self: *ZigObject, allocator: Allocator) void {
    self.data.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.symbols.deinit(allocator);
    self.symbols_extra.deinit(allocator);
    self.symbols_resolver.deinit(allocator);
    self.local_symbols.deinit(allocator);
    self.global_symbols.deinit(allocator);
    self.globals_lookup.deinit(allocator);
    self.atoms.deinit(allocator);
    self.atoms_indexes.deinit(allocator);
    self.atoms_extra.deinit(allocator);
    for (self.relocs.items) |*list| {
        list.deinit(allocator);
    }
    self.relocs.deinit(allocator);

    for (self.navs.values()) |*meta| {
        meta.exports.deinit(allocator);
    }
    self.navs.deinit(allocator);

    self.lazy_syms.deinit(allocator);

    for (self.uavs.values()) |*meta| {
        meta.exports.deinit(allocator);
    }
    self.uavs.deinit(allocator);
    self.tls_variables.deinit(allocator);

    if (self.dwarf) |*dwarf| {
        dwarf.deinit();
    }
}

pub fn flush(self: *ZigObject, elf_file: *Elf, tid: Zcu.PerThread.Id) !void {
    // Handle any lazy symbols that were emitted by incremental compilation.
    if (self.lazy_syms.getPtr(.anyerror_type)) |metadata| {
        const pt: Zcu.PerThread = .activate(elf_file.base.comp.zcu.?, tid);
        defer pt.deactivate();

        // Most lazy symbols can be updated on first use, but
        // anyerror needs to wait for everything to be flushed.
        if (metadata.text_state != .unused) self.updateLazySymbol(
            elf_file,
            pt,
            .{ .kind = .code, .ty = .anyerror_type },
            metadata.text_symbol_index,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.LinkFailure,
            else => |e| return e,
        };
        if (metadata.rodata_state != .unused) self.updateLazySymbol(
            elf_file,
            pt,
            .{ .kind = .const_data, .ty = .anyerror_type },
            metadata.rodata_symbol_index,
        ) catch |err| return switch (err) {
            error.CodegenFail => error.LinkFailure,
            else => |e| return e,
        };
    }
    for (self.lazy_syms.values()) |*metadata| {
        if (metadata.text_state != .unused) metadata.text_state = .flushed;
        if (metadata.rodata_state != .unused) metadata.rodata_state = .flushed;
    }

    if (build_options.enable_logging) {
        const pt: Zcu.PerThread = .activate(elf_file.base.comp.zcu.?, tid);
        defer pt.deactivate();
        for (self.navs.keys(), self.navs.values()) |nav_index, meta| {
            checkNavAllocated(pt, nav_index, meta);
        }
        for (self.uavs.keys(), self.uavs.values()) |uav_index, meta| {
            checkUavAllocated(pt, uav_index, meta);
        }
    }

    if (self.dwarf) |*dwarf| {
        const pt: Zcu.PerThread = .activate(elf_file.base.comp.zcu.?, tid);
        defer pt.deactivate();
        try dwarf.flushModule(pt);

        const gpa = elf_file.base.comp.gpa;
        const cpu_arch = elf_file.getTarget().cpu.arch;

        // TODO invert this logic so that we manage the output section with the atom, not the
        // other way around
        for ([_]u32{
            self.debug_info_index.?,
            self.debug_abbrev_index.?,
            self.debug_str_index.?,
            self.debug_aranges_index.?,
            self.debug_line_index.?,
            self.debug_line_str_index.?,
            self.debug_loclists_index.?,
            self.debug_rnglists_index.?,
            self.eh_frame_index.?,
        }, [_]*Dwarf.Section{
            &dwarf.debug_info.section,
            &dwarf.debug_abbrev.section,
            &dwarf.debug_str.section,
            &dwarf.debug_aranges.section,
            &dwarf.debug_line.section,
            &dwarf.debug_line_str.section,
            &dwarf.debug_loclists.section,
            &dwarf.debug_rnglists.section,
            &dwarf.debug_frame.section,
        }, [_]Dwarf.Section.Index{
            .debug_info,
            .debug_abbrev,
            .debug_str,
            .debug_aranges,
            .debug_line,
            .debug_line_str,
            .debug_loclists,
            .debug_rnglists,
            .debug_frame,
        }) |sym_index, sect, sect_index| {
            const sym = self.symbol(sym_index);
            const atom_ptr = self.atom(sym.ref.index).?;
            if (!atom_ptr.alive) continue;

            const relocs = &self.relocs.items[atom_ptr.relocsShndx().?];
            for (sect.units.items) |*unit| {
                try relocs.ensureUnusedCapacity(gpa, unit.cross_unit_relocs.items.len +
                    unit.cross_section_relocs.items.len);
                for (unit.cross_unit_relocs.items) |reloc| {
                    const target_unit = sect.getUnit(reloc.target_unit);
                    const r_offset = unit.off + reloc.source_off;
                    const r_addend: i64 = @intCast(target_unit.off + reloc.target_off + (if (reloc.target_entry.unwrap()) |target_entry|
                        target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(target_unit, sect, dwarf).off
                    else
                        0));
                    const r_type = relocation.dwarf.crossSectionRelocType(dwarf.format, cpu_arch);
                    atom_ptr.addRelocAssumeCapacity(.{
                        .r_offset = r_offset,
                        .r_addend = r_addend,
                        .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                    }, self);
                }
                for (unit.cross_section_relocs.items) |reloc| {
                    const target_sym_index = switch (reloc.target_sec) {
                        .debug_abbrev => self.debug_abbrev_index.?,
                        .debug_aranges => self.debug_aranges_index.?,
                        .debug_frame => self.eh_frame_index.?,
                        .debug_info => self.debug_info_index.?,
                        .debug_line => self.debug_line_index.?,
                        .debug_line_str => self.debug_line_str_index.?,
                        .debug_loclists => self.debug_loclists_index.?,
                        .debug_rnglists => self.debug_rnglists_index.?,
                        .debug_str => self.debug_str_index.?,
                    };
                    const target_sec = switch (reloc.target_sec) {
                        inline else => |target_sec| &@field(dwarf, @tagName(target_sec)).section,
                    };
                    const target_unit = target_sec.getUnit(reloc.target_unit);
                    const r_offset = unit.off + reloc.source_off;
                    const r_addend: i64 = @intCast(target_unit.off + reloc.target_off + (if (reloc.target_entry.unwrap()) |target_entry|
                        target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(target_unit, sect, dwarf).off
                    else
                        0));
                    const r_type = relocation.dwarf.crossSectionRelocType(dwarf.format, cpu_arch);
                    atom_ptr.addRelocAssumeCapacity(.{
                        .r_offset = r_offset,
                        .r_addend = r_addend,
                        .r_info = (@as(u64, @intCast(target_sym_index)) << 32) | r_type,
                    }, self);
                }

                for (unit.entries.items) |*entry| {
                    const entry_off = unit.off + unit.header_len + entry.off;

                    try relocs.ensureUnusedCapacity(gpa, entry.cross_entry_relocs.items.len +
                        entry.cross_unit_relocs.items.len + entry.cross_section_relocs.items.len +
                        entry.external_relocs.items.len);
                    for (entry.cross_entry_relocs.items) |reloc| {
                        const r_offset = entry_off + reloc.source_off;
                        const r_addend: i64 = @intCast(unit.off + reloc.target_off + (if (reloc.target_entry.unwrap()) |target_entry|
                            unit.header_len + unit.getEntry(target_entry).assertNonEmpty(unit, sect, dwarf).off
                        else
                            0));
                        const r_type = relocation.dwarf.crossSectionRelocType(dwarf.format, cpu_arch);
                        atom_ptr.addRelocAssumeCapacity(.{
                            .r_offset = r_offset,
                            .r_addend = r_addend,
                            .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                        }, self);
                    }
                    for (entry.cross_unit_relocs.items) |reloc| {
                        const target_unit = sect.getUnit(reloc.target_unit);
                        const r_offset = entry_off + reloc.source_off;
                        const r_addend: i64 = @intCast(target_unit.off + reloc.target_off + (if (reloc.target_entry.unwrap()) |target_entry|
                            target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(target_unit, sect, dwarf).off
                        else
                            0));
                        const r_type = relocation.dwarf.crossSectionRelocType(dwarf.format, cpu_arch);
                        atom_ptr.addRelocAssumeCapacity(.{
                            .r_offset = r_offset,
                            .r_addend = r_addend,
                            .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                        }, self);
                    }
                    for (entry.cross_section_relocs.items) |reloc| {
                        const target_sym_index = switch (reloc.target_sec) {
                            .debug_abbrev => self.debug_abbrev_index.?,
                            .debug_aranges => self.debug_aranges_index.?,
                            .debug_frame => self.eh_frame_index.?,
                            .debug_info => self.debug_info_index.?,
                            .debug_line => self.debug_line_index.?,
                            .debug_line_str => self.debug_line_str_index.?,
                            .debug_loclists => self.debug_loclists_index.?,
                            .debug_rnglists => self.debug_rnglists_index.?,
                            .debug_str => self.debug_str_index.?,
                        };
                        const target_sec = switch (reloc.target_sec) {
                            inline else => |target_sec| &@field(dwarf, @tagName(target_sec)).section,
                        };
                        const target_unit = target_sec.getUnit(reloc.target_unit);
                        const r_offset = entry_off + reloc.source_off;
                        const r_addend: i64 = @intCast(target_unit.off + reloc.target_off + (if (reloc.target_entry.unwrap()) |target_entry|
                            target_unit.header_len + target_unit.getEntry(target_entry).assertNonEmpty(target_unit, sect, dwarf).off
                        else
                            0));
                        const r_type = relocation.dwarf.crossSectionRelocType(dwarf.format, cpu_arch);
                        atom_ptr.addRelocAssumeCapacity(.{
                            .r_offset = r_offset,
                            .r_addend = r_addend,
                            .r_info = (@as(u64, @intCast(target_sym_index)) << 32) | r_type,
                        }, self);
                    }
                    for (entry.external_relocs.items) |reloc| {
                        const target_sym = self.symbol(reloc.target_sym);
                        const r_offset = entry_off + reloc.source_off;
                        const r_addend: i64 = @intCast(reloc.target_off);
                        const r_type = relocation.dwarf.externalRelocType(target_sym.*, sect_index, dwarf.address_size, cpu_arch);
                        atom_ptr.addRelocAssumeCapacity(.{
                            .r_offset = r_offset,
                            .r_addend = r_addend,
                            .r_info = (@as(u64, @intCast(reloc.target_sym)) << 32) | r_type,
                        }, self);
                    }
                }
            }
        }

        self.debug_abbrev_section_dirty = false;
        self.debug_aranges_section_dirty = false;
        self.debug_rnglists_section_dirty = false;
        self.debug_str_section_dirty = false;
    }

    // The point of flushModule() is to commit changes, so in theory, nothing should
    // be dirty after this. However, it is possible for some things to remain
    // dirty because they fail to be written in the event of compile errors,
    // such as debug_line_header_dirty and debug_info_header_dirty.
    assert(!self.debug_abbrev_section_dirty);
    assert(!self.debug_aranges_section_dirty);
    assert(!self.debug_rnglists_section_dirty);
    assert(!self.debug_str_section_dirty);
}

fn newSymbol(self: *ZigObject, allocator: Allocator, name_off: u32, st_bind: u4) !Symbol.Index {
    try self.symtab.ensureUnusedCapacity(allocator, 1);
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    try self.symbols_extra.ensureUnusedCapacity(allocator, @sizeOf(Symbol.Extra));

    const index = self.addSymbolAssumeCapacity();
    const sym = &self.symbols.items[index];
    sym.name_offset = name_off;
    sym.extra_index = self.addSymbolExtraAssumeCapacity(.{});

    const esym_idx: u32 = @intCast(self.symtab.addOneAssumeCapacity());
    const esym = ElfSym{ .elf_sym = .{
        .st_value = 0,
        .st_name = name_off,
        .st_info = @as(u8, @intCast(st_bind)) << 4,
        .st_other = 0,
        .st_size = 0,
        .st_shndx = 0,
    } };
    self.symtab.set(index, esym);
    sym.esym_index = esym_idx;

    return index;
}

fn newLocalSymbol(self: *ZigObject, allocator: Allocator, name_off: u32) !Symbol.Index {
    try self.local_symbols.ensureUnusedCapacity(allocator, 1);
    const fake_index: Symbol.Index = @intCast(self.local_symbols.items.len);
    const index = try self.newSymbol(allocator, name_off, elf.STB_LOCAL);
    self.local_symbols.appendAssumeCapacity(index);
    return fake_index;
}

fn newGlobalSymbol(self: *ZigObject, allocator: Allocator, name_off: u32) !Symbol.Index {
    try self.global_symbols.ensureUnusedCapacity(allocator, 1);
    try self.symbols_resolver.ensureUnusedCapacity(allocator, 1);
    const fake_index: Symbol.Index = @intCast(self.global_symbols.items.len);
    const index = try self.newSymbol(allocator, name_off, elf.STB_GLOBAL);
    self.global_symbols.appendAssumeCapacity(index);
    self.symbols_resolver.addOneAssumeCapacity().* = 0;
    return fake_index | global_symbol_bit;
}

fn newAtom(self: *ZigObject, allocator: Allocator, name_off: u32) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    try self.atoms_indexes.ensureUnusedCapacity(allocator, 1);
    try self.relocs.ensureUnusedCapacity(allocator, 1);

    const index = self.addAtomAssumeCapacity();
    self.atoms_indexes.appendAssumeCapacity(index);
    const atom_ptr = self.atom(index).?;
    atom_ptr.name_offset = name_off;

    const relocs_index: u32 = @intCast(self.relocs.items.len);
    self.relocs.addOneAssumeCapacity().* = .{};
    atom_ptr.relocs_section_index = relocs_index;

    return index;
}

fn newSymbolWithAtom(self: *ZigObject, allocator: Allocator, name_off: u32) !Symbol.Index {
    const atom_index = try self.newAtom(allocator, name_off);
    const sym_index = try self.newLocalSymbol(allocator, name_off);
    const sym = self.symbol(sym_index);
    sym.ref = .{ .index = atom_index, .file = self.index };
    self.symtab.items(.shndx)[sym.esym_index] = atom_index;
    self.symtab.items(.elf_sym)[sym.esym_index].st_shndx = SHN_ATOM;
    return sym_index;
}

/// TODO actually create fake input shdrs and return that instead.
pub fn inputShdr(self: *ZigObject, atom_index: Atom.Index, elf_file: *Elf) elf.Elf64_Shdr {
    const atom_ptr = self.atom(atom_index) orelse return Elf.null_shdr;
    const shndx = atom_ptr.output_section_index;
    var shdr = elf_file.sections.items(.shdr)[shndx];
    shdr.sh_addr = 0;
    shdr.sh_offset = 0;
    shdr.sh_size = atom_ptr.size;
    shdr.sh_addralign = atom_ptr.alignment.toByteUnits() orelse 1;
    return shdr;
}

pub fn resolveSymbols(self: *ZigObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;

    for (self.global_symbols.items, 0..) |index, i| {
        const global = &self.symbols.items[index];
        const esym = global.elfSym(elf_file);
        const shndx = self.symtab.items(.shndx)[global.esym_index];
        const resolv = &self.symbols_resolver.items[i];
        const gop = try elf_file.resolver.getOrPut(gpa, .{
            .index = @intCast(i | global_symbol_bit),
            .file = self.index,
        }, elf_file);
        if (!gop.found_existing) {
            gop.ref.* = .{ .index = 0, .file = 0 };
        }
        resolv.* = gop.index;

        if (esym.st_shndx == elf.SHN_UNDEF) continue;
        if (esym.st_shndx != elf.SHN_ABS and esym.st_shndx != elf.SHN_COMMON) {
            assert(esym.st_shndx == SHN_ATOM);
            const atom_ptr = self.atom(shndx) orelse continue;
            if (!atom_ptr.alive) continue;
        }
        if (elf_file.symbol(gop.ref.*) == null) {
            gop.ref.* = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
            continue;
        }

        if (self.asFile().symbolRank(esym, false) < elf_file.symbol(gop.ref.*).?.symbolRank(elf_file)) {
            gop.ref.* = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
        }
    }
}

pub fn claimUnresolved(self: *ZigObject, elf_file: *Elf) void {
    for (self.global_symbols.items, 0..) |index, i| {
        const global = &self.symbols.items[index];
        const esym = self.symtab.items(.elf_sym)[index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;
        if (elf_file.symbol(self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file)) != null) continue;

        const is_import = blk: {
            if (!elf_file.isEffectivelyDynLib()) break :blk false;
            const vis = @as(elf.STV, @enumFromInt(esym.st_other));
            if (vis == .HIDDEN) break :blk false;
            break :blk true;
        };

        global.value = 0;
        global.ref = .{ .index = 0, .file = 0 };
        global.esym_index = @intCast(index);
        global.file_index = self.index;
        global.version_index = if (is_import) .LOCAL else elf_file.default_sym_version;
        global.flags.import = is_import;

        const idx = self.symbols_resolver.items[i];
        elf_file.resolver.values.items[idx - 1] = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
    }
}

pub fn claimUnresolvedRelocatable(self: ZigObject, elf_file: *Elf) void {
    for (self.global_symbols.items, 0..) |index, i| {
        const global = &self.symbols.items[index];
        const esym = self.symtab.items(.elf_sym)[index];
        if (esym.st_shndx != elf.SHN_UNDEF) continue;
        if (elf_file.symbol(self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file)) != null) continue;

        global.value = 0;
        global.ref = .{ .index = 0, .file = 0 };
        global.esym_index = @intCast(index);
        global.file_index = self.index;

        const idx = self.symbols_resolver.items[i];
        elf_file.resolver.values.items[idx - 1] = .{ .index = @intCast(i | global_symbol_bit), .file = self.index };
    }
}

pub fn scanRelocs(self: *ZigObject, elf_file: *Elf, undefs: anytype) !void {
    const gpa = elf_file.base.comp.gpa;
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        const shdr = atom_ptr.inputShdr(elf_file);
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        if (atom_ptr.scanRelocsRequiresCode(elf_file)) {
            // TODO ideally we don't have to fetch the code here.
            // Perhaps it would make sense to save the code until flushModule where we
            // would free all of generated code?
            const code = try self.codeAlloc(elf_file, atom_index);
            defer gpa.free(code);
            try atom_ptr.scanRelocs(elf_file, code, undefs);
        } else try atom_ptr.scanRelocs(elf_file, null, undefs);
    }
}

pub fn markLive(self: *ZigObject, elf_file: *Elf) void {
    for (self.global_symbols.items, 0..) |index, i| {
        const global = self.symbols.items[index];
        const esym = self.symtab.items(.elf_sym)[index];
        if (esym.st_bind() == elf.STB_WEAK) continue;

        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        const should_keep = esym.st_shndx == elf.SHN_UNDEF or
            (esym.st_shndx == elf.SHN_COMMON and global.elfSym(elf_file).st_shndx != elf.SHN_COMMON);
        if (should_keep and !file.isAlive()) {
            file.setAlive();
            file.markLive(elf_file);
        }
    }
}

pub fn markImportsExports(self: *ZigObject, elf_file: *Elf) void {
    for (0..self.global_symbols.items.len) |i| {
        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const sym = elf_file.symbol(ref) orelse continue;
        const file = sym.file(elf_file).?;
        // https://github.com/ziglang/zig/issues/21678
        if (@as(u16, @bitCast(sym.version_index)) == @as(u16, @bitCast(elf.Versym.LOCAL))) continue;
        const vis: elf.STV = @enumFromInt(sym.elfSym(elf_file).st_other);
        if (vis == .HIDDEN) continue;
        if (file == .shared_object and !sym.isAbs(elf_file)) {
            sym.flags.import = true;
            continue;
        }
        if (file.index() == self.index) {
            sym.flags.@"export" = true;
            if (elf_file.isEffectivelyDynLib() and vis != .PROTECTED) {
                sym.flags.import = true;
            }
        }
    }
}

pub fn checkDuplicates(self: *ZigObject, dupes: anytype, elf_file: *Elf) error{OutOfMemory}!void {
    for (self.global_symbols.items, 0..) |index, i| {
        const esym = self.symtab.items(.elf_sym)[index];
        const shndx = self.symtab.items(.shndx)[index];
        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const ref_sym = elf_file.symbol(ref) orelse continue;
        const ref_file = ref_sym.file(elf_file).?;

        if (self.index == ref_file.index() or
            esym.st_shndx == elf.SHN_UNDEF or
            esym.st_bind() == elf.STB_WEAK or
            esym.st_shndx == elf.SHN_COMMON) continue;

        if (esym.st_shndx == SHN_ATOM) {
            const atom_ptr = self.atom(shndx) orelse continue;
            if (!atom_ptr.alive) continue;
        }

        const gop = try dupes.getOrPut(self.symbols_resolver.items[i]);
        if (!gop.found_existing) {
            gop.value_ptr.* = .{};
        }
        try gop.value_ptr.append(elf_file.base.comp.gpa, self.index);
    }
}

/// This is just a temporary helper function that allows us to re-read what we wrote to file into a buffer.
/// We need this so that we can write to an archive.
/// TODO implement writing ZigObject data directly to a buffer instead.
pub fn readFileContents(self: *ZigObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    const shsize: u64 = switch (elf_file.ptr_width) {
        .p32 => @sizeOf(elf.Elf32_Shdr),
        .p64 => @sizeOf(elf.Elf64_Shdr),
    };
    var end_pos: u64 = elf_file.shdr_table_offset.? + elf_file.sections.items(.shdr).len * shsize;
    for (elf_file.sections.items(.shdr)) |shdr| {
        if (shdr.sh_type == elf.SHT_NOBITS) continue;
        end_pos = @max(end_pos, shdr.sh_offset + shdr.sh_size);
    }
    const size = std.math.cast(usize, end_pos) orelse return error.Overflow;
    try self.data.resize(gpa, size);

    const amt = try elf_file.base.file.?.preadAll(self.data.items, 0);
    if (amt != size) return error.InputOutput;
}

pub fn updateArSymtab(self: ZigObject, ar_symtab: *Archive.ArSymtab, elf_file: *Elf) error{OutOfMemory}!void {
    const gpa = elf_file.base.comp.gpa;

    try ar_symtab.symtab.ensureUnusedCapacity(gpa, self.global_symbols.items.len);

    for (self.global_symbols.items, 0..) |index, i| {
        const global = self.symbols.items[index];
        const ref = self.resolveSymbol(@intCast(i | global_symbol_bit), elf_file);
        const sym = elf_file.symbol(ref).?;
        assert(sym.file(elf_file).?.index() == self.index);
        if (global.outputShndx(elf_file) == null) continue;

        const off = try ar_symtab.strtab.insert(gpa, global.name(elf_file));
        ar_symtab.symtab.appendAssumeCapacity(.{ .off = off, .file_index = self.index });
    }
}

pub fn updateArSize(self: *ZigObject) void {
    self.output_ar_state.size = self.data.items.len;
}

pub fn writeAr(self: ZigObject, writer: anytype) !void {
    const name = self.basename;
    const hdr = Archive.setArHdr(.{
        .name = if (name.len <= Archive.max_member_name_len)
            .{ .name = name }
        else
            .{ .name_off = self.output_ar_state.name_off },
        .size = self.data.items.len,
    });
    try writer.writeAll(mem.asBytes(&hdr));
    try writer.writeAll(self.data.items);
}

pub fn initRelaSections(self: *ZigObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        if (atom_ptr.output_section_index == elf_file.section_indexes.eh_frame) continue;
        const rela_shndx = atom_ptr.relocsShndx() orelse continue;
        // TODO this check will become obsolete when we rework our relocs mechanism at the ZigObject level
        if (self.relocs.items[rela_shndx].items.len == 0) continue;
        const out_shndx = atom_ptr.output_section_index;
        const out_shdr = elf_file.sections.items(.shdr)[out_shndx];
        if (out_shdr.sh_type == elf.SHT_NOBITS) continue;
        const rela_sect_name = try std.fmt.allocPrintZ(gpa, ".rela{s}", .{
            elf_file.getShString(out_shdr.sh_name),
        });
        defer gpa.free(rela_sect_name);
        _ = elf_file.sectionByName(rela_sect_name) orelse
            try elf_file.addRelaShdr(try elf_file.insertShString(rela_sect_name), out_shndx);
    }
}

pub fn addAtomsToRelaSections(self: *ZigObject, elf_file: *Elf) !void {
    const gpa = elf_file.base.comp.gpa;
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        if (!atom_ptr.alive) continue;
        if (atom_ptr.output_section_index == elf_file.section_indexes.eh_frame) continue;
        const rela_shndx = atom_ptr.relocsShndx() orelse continue;
        // TODO this check will become obsolete when we rework our relocs mechanism at the ZigObject level
        if (self.relocs.items[rela_shndx].items.len == 0) continue;
        const out_shndx = atom_ptr.output_section_index;
        const out_shdr = elf_file.sections.items(.shdr)[out_shndx];
        if (out_shdr.sh_type == elf.SHT_NOBITS) continue;
        const rela_sect_name = try std.fmt.allocPrintZ(gpa, ".rela{s}", .{
            elf_file.getShString(out_shdr.sh_name),
        });
        defer gpa.free(rela_sect_name);
        const out_rela_shndx = elf_file.sectionByName(rela_sect_name).?;
        const out_rela_shdr = &elf_file.sections.items(.shdr)[out_rela_shndx];
        out_rela_shdr.sh_info = out_shndx;
        out_rela_shdr.sh_link = elf_file.section_indexes.symtab.?;
        const atom_list = &elf_file.sections.items(.atom_list)[out_rela_shndx];
        try atom_list.append(gpa, .{ .index = atom_index, .file = self.index });
    }
}

pub fn updateSymtabSize(self: *ZigObject, elf_file: *Elf) !void {
    for (self.local_symbols.items) |index| {
        const local = &self.symbols.items[index];
        if (local.atom(elf_file)) |atom_ptr| if (!atom_ptr.alive) continue;
        const name = local.name(elf_file);
        assert(name.len > 0);
        const esym = local.elfSym(elf_file);
        switch (esym.st_type()) {
            elf.STT_SECTION, elf.STT_NOTYPE => continue,
            else => {},
        }
        local.flags.output_symtab = true;
        local.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, elf_file);
        self.output_symtab_ctx.nlocals += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(name.len)) + 1;
    }

    for (self.global_symbols.items, self.symbols_resolver.items) |index, resolv| {
        const global = &self.symbols.items[index];
        const ref = elf_file.resolver.values.items[resolv - 1];
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        if (global.atom(elf_file)) |atom_ptr| if (!atom_ptr.alive) continue;
        global.flags.output_symtab = true;
        if (global.isLocal(elf_file)) {
            global.addExtra(.{ .symtab = self.output_symtab_ctx.nlocals }, elf_file);
            self.output_symtab_ctx.nlocals += 1;
        } else {
            global.addExtra(.{ .symtab = self.output_symtab_ctx.nglobals }, elf_file);
            self.output_symtab_ctx.nglobals += 1;
        }
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.name(elf_file).len)) + 1;
    }
}

pub fn writeSymtab(self: ZigObject, elf_file: *Elf) void {
    for (self.local_symbols.items) |index| {
        const local = &self.symbols.items[index];
        const idx = local.outputSymtabIndex(elf_file) orelse continue;
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = @intCast(elf_file.strtab.items.len);
        elf_file.strtab.appendSliceAssumeCapacity(local.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        local.setOutputSym(elf_file, out_sym);
    }

    for (self.global_symbols.items, self.symbols_resolver.items) |index, resolv| {
        const global = self.symbols.items[index];
        const ref = elf_file.resolver.values.items[resolv - 1];
        const ref_sym = elf_file.symbol(ref) orelse continue;
        if (ref_sym.file(elf_file).?.index() != self.index) continue;
        const idx = global.outputSymtabIndex(elf_file) orelse continue;
        const st_name = @as(u32, @intCast(elf_file.strtab.items.len));
        elf_file.strtab.appendSliceAssumeCapacity(global.name(elf_file));
        elf_file.strtab.appendAssumeCapacity(0);
        const out_sym = &elf_file.symtab.items[idx];
        out_sym.st_name = st_name;
        global.setOutputSym(elf_file, out_sym);
    }
}

/// Returns atom's code.
/// Caller owns the memory.
pub fn codeAlloc(self: *ZigObject, elf_file: *Elf, atom_index: Atom.Index) ![]u8 {
    const gpa = elf_file.base.comp.gpa;
    const atom_ptr = self.atom(atom_index).?;
    const file_offset = atom_ptr.offset(elf_file);
    const size = std.math.cast(usize, atom_ptr.size) orelse return error.Overflow;
    const code = try gpa.alloc(u8, size);
    errdefer gpa.free(code);
    const amt = try elf_file.base.file.?.preadAll(code, file_offset);
    if (amt != code.len) {
        log.err("fetching code for {s} failed", .{atom_ptr.name(elf_file)});
        return error.InputOutput;
    }
    return code;
}

pub fn getNavVAddr(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    log.debug("getNavVAddr {}({d})", .{ nav.fqn.fmt(ip), nav_index });
    const this_sym_index = if (nav.getExtern(ip)) |@"extern"| try self.getGlobalSymbol(
        elf_file,
        nav.name.toSlice(ip),
        @"extern".lib_name.toSlice(ip),
    ) else try self.getOrCreateMetadataForNav(zcu, nav_index);
    const this_sym = self.symbol(this_sym_index);
    const vaddr = this_sym.address(.{}, elf_file);
    switch (reloc_info.parent) {
        .none => unreachable,
        .atom_index => |atom_index| {
            const parent_atom = self.symbol(atom_index).atom(elf_file).?;
            const r_type = relocation.encode(.abs, elf_file.getTarget().cpu.arch);
            try parent_atom.addReloc(elf_file.base.comp.gpa, .{
                .r_offset = reloc_info.offset,
                .r_info = (@as(u64, @intCast(this_sym_index)) << 32) | r_type,
                .r_addend = reloc_info.addend,
            }, self);
        },
        .debug_output => |debug_output| switch (debug_output) {
            .dwarf => |wip_nav| try wip_nav.infoExternalReloc(.{
                .source_off = @intCast(reloc_info.offset),
                .target_sym = this_sym_index,
                .target_off = reloc_info.addend,
            }),
            .plan9 => unreachable,
            .none => unreachable,
        },
    }
    return @intCast(vaddr);
}

pub fn getUavVAddr(
    self: *ZigObject,
    elf_file: *Elf,
    uav: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    const sym_index = self.uavs.get(uav).?.symbol_index;
    const sym = self.symbol(sym_index);
    const vaddr = sym.address(.{}, elf_file);
    switch (reloc_info.parent) {
        .none => unreachable,
        .atom_index => |atom_index| {
            const parent_atom = self.symbol(atom_index).atom(elf_file).?;
            const r_type = relocation.encode(.abs, elf_file.getTarget().cpu.arch);
            try parent_atom.addReloc(elf_file.base.comp.gpa, .{
                .r_offset = reloc_info.offset,
                .r_info = (@as(u64, @intCast(sym_index)) << 32) | r_type,
                .r_addend = reloc_info.addend,
            }, self);
        },
        .debug_output => |debug_output| switch (debug_output) {
            .dwarf => |wip_nav| try wip_nav.infoExternalReloc(.{
                .source_off = @intCast(reloc_info.offset),
                .target_sym = sym_index,
                .target_off = reloc_info.addend,
            }),
            .plan9 => unreachable,
            .none => unreachable,
        },
    }
    return @intCast(vaddr);
}

pub fn lowerUav(
    self: *ZigObject,
    elf_file: *Elf,
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
    if (self.uavs.get(uav)) |metadata| {
        assert(metadata.allocated);
        const sym = self.symbol(metadata.symbol_index);
        const existing_alignment = sym.atom(elf_file).?.alignment;
        if (uav_alignment.order(existing_alignment).compare(.lte))
            return .{ .mcv = .{ .load_symbol = metadata.symbol_index } };
    }

    const osec = if (self.data_relro_index) |sym_index|
        self.symbol(sym_index).outputShndx(elf_file).?
    else osec: {
        const osec = try elf_file.addSection(.{
            .name = try elf_file.insertShString(".data.rel.ro"),
            .type = elf.SHT_PROGBITS,
            .addralign = 1,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
        });
        self.data_relro_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".data.rel.ro"), osec);
        break :osec osec;
    };

    var name_buf: [32]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buf, "__anon_{d}", .{
        @intFromEnum(uav),
    }) catch unreachable;
    const res = self.lowerConst(
        elf_file,
        pt,
        name,
        val,
        uav_alignment,
        osec,
        src_loc,
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Zcu.ErrorMsg.create(
            gpa,
            src_loc,
            "unable to lower constant value: {s}",
            .{@errorName(e)},
        ) },
    };
    const sym_index = switch (res) {
        .ok => |sym_index| sym_index,
        .fail => |em| return .{ .fail = em },
    };
    try self.uavs.put(gpa, uav, .{ .symbol_index = sym_index, .allocated = true });
    return .{ .mcv = .{ .load_symbol = sym_index } };
}

pub fn getOrCreateMetadataForLazySymbol(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    lazy_sym: link.File.LazySymbol,
) !Symbol.Index {
    const gop = try self.lazy_syms.getOrPut(pt.zcu.gpa, lazy_sym.ty);
    errdefer _ = if (!gop.found_existing) self.lazy_syms.pop();
    if (!gop.found_existing) gop.value_ptr.* = .{};
    const symbol_index_ptr, const state_ptr = switch (lazy_sym.kind) {
        .code => .{ &gop.value_ptr.text_symbol_index, &gop.value_ptr.text_state },
        .const_data => .{ &gop.value_ptr.rodata_symbol_index, &gop.value_ptr.rodata_state },
    };
    switch (state_ptr.*) {
        .unused => symbol_index_ptr.* = try self.newSymbolWithAtom(pt.zcu.gpa, 0),
        .pending_flush => return symbol_index_ptr.*,
        .flushed => {},
    }
    state_ptr.* = .pending_flush;
    const symbol_index = symbol_index_ptr.*;
    // anyerror needs to be deferred until flushModule
    if (lazy_sym.ty != .anyerror_type) try self.updateLazySymbol(elf_file, pt, lazy_sym, symbol_index);
    return symbol_index;
}

fn freeNavMetadata(self: *ZigObject, elf_file: *Elf, sym_index: Symbol.Index) void {
    const sym = self.symbol(sym_index);
    sym.atom(elf_file).?.free(elf_file);
    log.debug("adding %{d} to local symbols free list", .{sym_index});
    self.symbols.items[sym_index] = .{};
    // TODO free GOT entry here
}

pub fn freeNav(self: *ZigObject, elf_file: *Elf, nav_index: InternPool.Nav.Index) void {
    const gpa = elf_file.base.comp.gpa;

    log.debug("freeNav ({d})", .{nav_index});

    if (self.navs.fetchRemove(nav_index)) |const_kv| {
        var kv = const_kv;
        const sym_index = kv.value.symbol_index;
        self.freeNavMetadata(elf_file, sym_index);
        kv.value.exports.deinit(gpa);
    }

    if (self.dwarf) |*dwarf| {
        dwarf.freeNav(nav_index);
    }
}

pub fn getOrCreateMetadataForNav(self: *ZigObject, zcu: *Zcu, nav_index: InternPool.Nav.Index) !Symbol.Index {
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const gop = try self.navs.getOrPut(gpa, nav_index);
    if (!gop.found_existing) {
        const symbol_index = try self.newSymbolWithAtom(gpa, 0);
        const sym = self.symbol(symbol_index);
        if (ip.getNav(nav_index).isThreadlocal(ip) and zcu.comp.config.any_non_single_threaded) {
            sym.flags.is_tls = true;
        }
        gop.value_ptr.* = .{ .symbol_index = symbol_index };
    }
    return gop.value_ptr.symbol_index;
}

fn addSectionSymbol(self: *ZigObject, allocator: Allocator, name_off: u32, shndx: u32) !Symbol.Index {
    const index = try self.newLocalSymbol(allocator, name_off);
    const sym = self.symbol(index);
    const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
    esym.st_info |= elf.STT_SECTION;
    // TODO create fake shdrs?
    // esym.st_shndx = shndx;
    sym.output_section_index = shndx;
    return index;
}

fn getNavShdrIndex(
    self: *ZigObject,
    elf_file: *Elf,
    zcu: *Zcu,
    nav_index: InternPool.Nav.Index,
    sym_index: Symbol.Index,
    code: []const u8,
) error{OutOfMemory}!u32 {
    const gpa = elf_file.base.comp.gpa;
    const ptr_size = elf_file.ptrWidthBytes();
    const ip = &zcu.intern_pool;
    const any_non_single_threaded = elf_file.base.comp.config.any_non_single_threaded;
    const nav_val = zcu.navValue(nav_index);
    if (ip.isFunctionType(nav_val.typeOf(zcu).toIntern())) {
        if (self.text_index) |symbol_index|
            return self.symbol(symbol_index).outputShndx(elf_file).?;
        const osec = try elf_file.addSection(.{
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            .name = try elf_file.insertShString(".text"),
            .addralign = 1,
        });
        self.text_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".text"), osec);
        return osec;
    }
    const is_const, const is_threadlocal, const nav_init = switch (ip.indexToKey(nav_val.toIntern())) {
        .variable => |variable| .{ false, variable.is_threadlocal, variable.init },
        .@"extern" => |@"extern"| .{ @"extern".is_const, @"extern".is_threadlocal, .none },
        else => .{ true, false, nav_val.toIntern() },
    };
    const has_relocs = self.symbol(sym_index).atom(elf_file).?.relocs(elf_file).len > 0;
    if (any_non_single_threaded and is_threadlocal) {
        const is_bss = !has_relocs and for (code) |byte| {
            if (byte != 0) break false;
        } else true;
        if (is_bss) {
            if (self.tbss_index) |symbol_index|
                return self.symbol(symbol_index).outputShndx(elf_file).?;
            const osec = try elf_file.addSection(.{
                .name = try elf_file.insertShString(".tbss"),
                .flags = elf.SHF_ALLOC | elf.SHF_WRITE | elf.SHF_TLS,
                .type = elf.SHT_NOBITS,
                .addralign = 1,
            });
            self.tbss_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".tbss"), osec);
            return osec;
        }
        if (self.tdata_index) |symbol_index|
            return self.symbol(symbol_index).outputShndx(elf_file).?;
        const osec = try elf_file.addSection(.{
            .type = elf.SHT_PROGBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE | elf.SHF_TLS,
            .name = try elf_file.insertShString(".tdata"),
            .addralign = 1,
        });
        self.tdata_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".tdata"), osec);
        return osec;
    }
    if (is_const) {
        if (self.data_relro_index) |symbol_index|
            return self.symbol(symbol_index).outputShndx(elf_file).?;
        const osec = try elf_file.addSection(.{
            .name = try elf_file.insertShString(".data.rel.ro"),
            .type = elf.SHT_PROGBITS,
            .addralign = 1,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
        });
        self.data_relro_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".data.rel.ro"), osec);
        return osec;
    }
    if (nav_init != .none and Value.fromInterned(nav_init).isUndefDeep(zcu))
        return switch (zcu.navFileScope(nav_index).mod.optimize_mode) {
            .Debug, .ReleaseSafe => {
                if (self.data_index) |symbol_index|
                    return self.symbol(symbol_index).outputShndx(elf_file).?;
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".data"),
                    .type = elf.SHT_PROGBITS,
                    .addralign = ptr_size,
                    .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
                });
                self.data_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".data"), osec);
                return osec;
            },
            .ReleaseFast, .ReleaseSmall => {
                if (self.bss_index) |symbol_index|
                    return self.symbol(symbol_index).outputShndx(elf_file).?;
                const osec = try elf_file.addSection(.{
                    .type = elf.SHT_NOBITS,
                    .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
                    .name = try elf_file.insertShString(".bss"),
                    .addralign = 1,
                });
                self.bss_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".bss"), osec);
                return osec;
            },
        };
    const is_bss = !has_relocs and for (code) |byte| {
        if (byte != 0) break false;
    } else true;
    if (is_bss) {
        if (self.bss_index) |symbol_index|
            return self.symbol(symbol_index).outputShndx(elf_file).?;
        const osec = try elf_file.addSection(.{
            .type = elf.SHT_NOBITS,
            .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
            .name = try elf_file.insertShString(".bss"),
            .addralign = 1,
        });
        self.bss_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".bss"), osec);
        return osec;
    }
    if (self.data_index) |symbol_index|
        return self.symbol(symbol_index).outputShndx(elf_file).?;
    const osec = try elf_file.addSection(.{
        .name = try elf_file.insertShString(".data"),
        .type = elf.SHT_PROGBITS,
        .addralign = ptr_size,
        .flags = elf.SHF_ALLOC | elf.SHF_WRITE,
    });
    self.data_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".data"), osec);
    return osec;
}

fn updateNavCode(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    sym_index: Symbol.Index,
    shdr_index: u32,
    code: []const u8,
    stt_bits: u8,
) link.File.UpdateNavError!void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    log.debug("updateNavCode {}({d})", .{ nav.fqn.fmt(ip), nav_index });

    const target = zcu.navFileScope(nav_index).mod.resolved_target.result;
    const required_alignment = switch (pt.navAlignment(nav_index)) {
        .none => target_util.defaultFunctionAlignment(target),
        else => |a| a.maxStrict(target_util.minFunctionAlignment(target)),
    };

    const sym = self.symbol(sym_index);
    const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
    const atom_ptr = sym.atom(elf_file).?;
    const name_offset = try self.strtab.insert(gpa, nav.fqn.toSlice(ip));

    atom_ptr.alive = true;
    atom_ptr.name_offset = name_offset;
    atom_ptr.output_section_index = shdr_index;

    sym.name_offset = name_offset;
    esym.st_name = name_offset;
    esym.st_info |= stt_bits;
    esym.st_size = code.len;

    const old_size = atom_ptr.size;
    const old_vaddr = atom_ptr.value;
    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;

    if (old_size > 0 and elf_file.base.child_pid == null) {
        const capacity = atom_ptr.capacity(elf_file);
        const need_realloc = code.len > capacity or !required_alignment.check(@intCast(atom_ptr.value));
        if (need_realloc) {
            self.allocateAtom(atom_ptr, true, elf_file) catch |err|
                return elf_file.base.cgFail(nav_index, "failed to allocate atom: {s}", .{@errorName(err)});

            log.debug("growing {} from 0x{x} to 0x{x}", .{ nav.fqn.fmt(ip), old_vaddr, atom_ptr.value });
            if (old_vaddr != atom_ptr.value) {
                sym.value = 0;
                esym.st_value = 0;
            }
        } else if (code.len < old_size) {
            // TODO shrink section size
        }
    } else {
        self.allocateAtom(atom_ptr, true, elf_file) catch |err|
            return elf_file.base.cgFail(nav_index, "failed to allocate atom: {s}", .{@errorName(err)});

        errdefer self.freeNavMetadata(elf_file, sym_index);
        sym.value = 0;
        esym.st_value = 0;
    }

    self.navs.getPtr(nav_index).?.allocated = true;

    if (elf_file.base.child_pid) |pid| {
        switch (builtin.os.tag) {
            .linux => {
                var code_vec: [1]std.posix.iovec_const = .{.{
                    .base = code.ptr,
                    .len = code.len,
                }};
                var remote_vec: [1]std.posix.iovec_const = .{.{
                    .base = @as([*]u8, @ptrFromInt(@as(usize, @intCast(sym.address(.{}, elf_file))))),
                    .len = code.len,
                }};
                const rc = std.os.linux.process_vm_writev(pid, &code_vec, &remote_vec, 0);
                switch (std.os.linux.E.init(rc)) {
                    .SUCCESS => assert(rc == code.len),
                    else => |errno| log.warn("process_vm_writev failure: {s}", .{@tagName(errno)}),
                }
            },
            else => return elf_file.base.cgFail(nav_index, "ELF hot swap unavailable on host operating system '{s}'", .{@tagName(builtin.os.tag)}),
        }
    }

    const shdr = elf_file.sections.items(.shdr)[shdr_index];
    if (shdr.sh_type != elf.SHT_NOBITS) {
        const file_offset = atom_ptr.offset(elf_file);
        elf_file.base.file.?.pwriteAll(code, file_offset) catch |err|
            return elf_file.base.cgFail(nav_index, "failed to write to output file: {s}", .{@errorName(err)});
        log.debug("writing {} from 0x{x} to 0x{x}", .{ nav.fqn.fmt(ip), file_offset, file_offset + code.len });
    }
}

fn updateTlv(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
    sym_index: Symbol.Index,
    shndx: u32,
    code: []const u8,
) link.File.UpdateNavError!void {
    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = zcu.gpa;
    const nav = ip.getNav(nav_index);

    log.debug("updateTlv {}({d})", .{ nav.fqn.fmt(ip), nav_index });

    const required_alignment = pt.navAlignment(nav_index);

    const sym = self.symbol(sym_index);
    const esym = &self.symtab.items(.elf_sym)[sym.esym_index];
    const atom_ptr = sym.atom(elf_file).?;
    const name_offset = try self.strtab.insert(gpa, nav.fqn.toSlice(ip));

    atom_ptr.alive = true;
    atom_ptr.name_offset = name_offset;
    atom_ptr.output_section_index = shndx;

    sym.name_offset = name_offset;
    esym.st_name = name_offset;
    esym.st_info = elf.STT_TLS;
    esym.st_size = code.len;

    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;

    const gop = try self.tls_variables.getOrPut(gpa, atom_ptr.atom_index);
    assert(!gop.found_existing); // TODO incremental updates

    self.allocateAtom(atom_ptr, true, elf_file) catch |err|
        return elf_file.base.cgFail(nav_index, "failed to allocate atom: {s}", .{@errorName(err)});
    sym.value = 0;
    esym.st_value = 0;

    self.navs.getPtr(nav_index).?.allocated = true;

    const shdr = elf_file.sections.items(.shdr)[shndx];
    if (shdr.sh_type != elf.SHT_NOBITS) {
        const file_offset = atom_ptr.offset(elf_file);
        elf_file.base.file.?.pwriteAll(code, file_offset) catch |err|
            return elf_file.base.cgFail(nav_index, "failed to write to output file: {s}", .{@errorName(err)});
        log.debug("writing TLV {s} from 0x{x} to 0x{x}", .{
            atom_ptr.name(elf_file),
            file_offset,
            file_offset + code.len,
        });
    }
}

pub fn updateFunc(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    air: Air,
    liveness: Liveness,
) link.File.UpdateNavError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const gpa = elf_file.base.comp.gpa;
    const func = zcu.funcInfo(func_index);

    log.debug("updateFunc {}({d})", .{ ip.getNav(func.owner_nav).fqn.fmt(ip), func.owner_nav });

    const sym_index = try self.getOrCreateMetadataForNav(zcu, func.owner_nav);
    self.atom(self.symbol(sym_index).ref.index).?.freeRelocs(self);

    var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer code_buffer.deinit(gpa);

    var debug_wip_nav = if (self.dwarf) |*dwarf| try dwarf.initWipNav(pt, func.owner_nav, sym_index) else null;
    defer if (debug_wip_nav) |*wip_nav| wip_nav.deinit();

    try codegen.generateFunction(
        &elf_file.base,
        pt,
        zcu.navSrcLoc(func.owner_nav),
        func_index,
        air,
        liveness,
        &code_buffer,
        if (debug_wip_nav) |*dn| .{ .dwarf = dn } else .none,
    );
    const code = code_buffer.items;

    const shndx = try self.getNavShdrIndex(elf_file, zcu, func.owner_nav, sym_index, code);
    log.debug("setting shdr({x},{s}) for {}", .{
        shndx,
        elf_file.getShString(elf_file.sections.items(.shdr)[shndx].sh_name),
        ip.getNav(func.owner_nav).fqn.fmt(ip),
    });
    const old_rva, const old_alignment = blk: {
        const atom_ptr = self.atom(self.symbol(sym_index).ref.index).?;
        break :blk .{ atom_ptr.value, atom_ptr.alignment };
    };
    try self.updateNavCode(elf_file, pt, func.owner_nav, sym_index, shndx, code, elf.STT_FUNC);
    const new_rva, const new_alignment = blk: {
        const atom_ptr = self.atom(self.symbol(sym_index).ref.index).?;
        break :blk .{ atom_ptr.value, atom_ptr.alignment };
    };

    if (debug_wip_nav) |*wip_nav| self.dwarf.?.finishWipNavFunc(pt, func.owner_nav, code.len, wip_nav) catch |err|
        return elf_file.base.cgFail(func.owner_nav, "failed to finish dwarf function: {s}", .{@errorName(err)});

    // Exports will be updated by `Zcu.processExports` after the update.

    if (old_rva != new_rva and old_rva > 0) {
        // If we had to reallocate the function, we re-use the existing slot for a trampoline.
        // In the rare case that the function has been further overaligned we skip creating a
        // trampoline and update all symbols referring this function.
        if (old_alignment.order(new_alignment) == .lt) {
            @panic("TODO update all symbols referring this function");
        }

        // Create a trampoline to the new location at `old_rva`.
        if (!self.symbol(sym_index).flags.has_trampoline) {
            const name = try std.fmt.allocPrint(gpa, "{s}$trampoline", .{
                self.symbol(sym_index).name(elf_file),
            });
            defer gpa.free(name);
            const osec = if (self.text_index) |sect_sym_index|
                self.symbol(sect_sym_index).outputShndx(elf_file).?
            else osec: {
                const osec = try elf_file.addSection(.{
                    .name = try elf_file.insertShString(".text"),
                    .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
                    .type = elf.SHT_PROGBITS,
                    .addralign = 1,
                });
                self.text_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".text"), osec);
                break :osec osec;
            };
            const name_off = try self.addString(gpa, name);
            const tr_size = trampolineSize(elf_file.getTarget().cpu.arch);
            const tr_sym_index = try self.newSymbolWithAtom(gpa, name_off);
            const tr_sym = self.symbol(tr_sym_index);
            const tr_esym = &self.symtab.items(.elf_sym)[tr_sym.esym_index];
            tr_esym.st_info |= elf.STT_OBJECT;
            tr_esym.st_size = tr_size;
            const tr_atom_ptr = tr_sym.atom(elf_file).?;
            tr_atom_ptr.value = old_rva;
            tr_atom_ptr.alive = true;
            tr_atom_ptr.alignment = old_alignment;
            tr_atom_ptr.output_section_index = osec;
            tr_atom_ptr.size = tr_size;
            const target_sym = self.symbol(sym_index);
            target_sym.addExtra(.{ .trampoline = tr_sym_index }, elf_file);
            target_sym.flags.has_trampoline = true;
        }
        const target_sym = self.symbol(sym_index);
        writeTrampoline(self.symbol(target_sym.extra(elf_file).trampoline).*, target_sym.*, elf_file) catch |err|
            return elf_file.base.cgFail(func.owner_nav, "failed to write trampoline: {s}", .{@errorName(err)});
    }
}

pub fn updateNav(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    nav_index: InternPool.Nav.Index,
) link.File.UpdateNavError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);

    log.debug("updateNav {}({d})", .{ nav.fqn.fmt(ip), nav_index });

    const nav_init = switch (ip.indexToKey(nav.status.fully_resolved.val)) {
        .func => .none,
        .variable => |variable| variable.init,
        .@"extern" => |@"extern"| {
            const sym_index = try self.getGlobalSymbol(
                elf_file,
                nav.name.toSlice(ip),
                @"extern".lib_name.toSlice(ip),
            );
            if (!ip.isFunctionType(@"extern".ty)) {
                const sym = self.symbol(sym_index);
                sym.flags.is_extern_ptr = true;
                if (@"extern".is_threadlocal) sym.flags.is_tls = true;
            }
            if (self.dwarf) |*dwarf| dwarf: {
                var debug_wip_nav = try dwarf.initWipNav(pt, nav_index, sym_index) orelse break :dwarf;
                defer debug_wip_nav.deinit();
                dwarf.finishWipNav(pt, nav_index, &debug_wip_nav) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.Overflow => return error.Overflow,
                    else => |e| return elf_file.base.cgFail(nav_index, "failed to finish dwarf nav: {s}", .{@errorName(e)}),
                };
            }
            return;
        },
        else => nav.status.fully_resolved.val,
    };

    if (nav_init != .none and Value.fromInterned(nav_init).typeOf(zcu).hasRuntimeBits(zcu)) {
        const sym_index = try self.getOrCreateMetadataForNav(zcu, nav_index);
        self.symbol(sym_index).atom(elf_file).?.freeRelocs(self);

        var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
        defer code_buffer.deinit(zcu.gpa);

        var debug_wip_nav = if (self.dwarf) |*dwarf| try dwarf.initWipNav(pt, nav_index, sym_index) else null;
        defer if (debug_wip_nav) |*wip_nav| wip_nav.deinit();

        try codegen.generateSymbol(
            &elf_file.base,
            pt,
            zcu.navSrcLoc(nav_index),
            Value.fromInterned(nav_init),
            &code_buffer,
            .{ .atom_index = sym_index },
        );
        const code = code_buffer.items;

        const shndx = try self.getNavShdrIndex(elf_file, zcu, nav_index, sym_index, code);
        log.debug("setting shdr({x},{s}) for {}", .{
            shndx,
            elf_file.getShString(elf_file.sections.items(.shdr)[shndx].sh_name),
            nav.fqn.fmt(ip),
        });
        if (elf_file.sections.items(.shdr)[shndx].sh_flags & elf.SHF_TLS != 0)
            try self.updateTlv(elf_file, pt, nav_index, sym_index, shndx, code)
        else
            try self.updateNavCode(elf_file, pt, nav_index, sym_index, shndx, code, elf.STT_OBJECT);

        if (debug_wip_nav) |*wip_nav| self.dwarf.?.finishWipNav(pt, nav_index, wip_nav) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.Overflow => return error.Overflow,
            else => |e| return elf_file.base.cgFail(nav_index, "failed to finish dwarf nav: {s}", .{@errorName(e)}),
        };
    } else if (self.dwarf) |*dwarf| try dwarf.updateComptimeNav(pt, nav_index);

    // Exports will be updated by `Zcu.processExports` after the update.
}

pub fn updateContainerType(
    self: *ZigObject,
    pt: Zcu.PerThread,
    ty: InternPool.Index,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (self.dwarf) |*dwarf| try dwarf.updateContainerType(pt, ty);
}

fn updateLazySymbol(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    sym: link.File.LazySymbol,
    symbol_index: Symbol.Index,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    var required_alignment: InternPool.Alignment = .none;
    var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer code_buffer.deinit(gpa);

    const name_str_index = blk: {
        const name = try std.fmt.allocPrint(gpa, "__lazy_{s}_{}", .{
            @tagName(sym.kind),
            Type.fromInterned(sym.ty).fmt(pt),
        });
        defer gpa.free(name);
        break :blk try self.strtab.insert(gpa, name);
    };

    const src = Type.fromInterned(sym.ty).srcLocOrNull(zcu) orelse Zcu.LazySrcLoc.unneeded;
    try codegen.generateLazySymbol(
        &elf_file.base,
        pt,
        src,
        sym,
        &required_alignment,
        &code_buffer,
        .none,
        .{ .atom_index = symbol_index },
    );
    const code = code_buffer.items;

    const output_section_index = switch (sym.kind) {
        .code => if (self.text_index) |sym_index|
            self.symbol(sym_index).outputShndx(elf_file).?
        else osec: {
            const osec = try elf_file.addSection(.{
                .name = try elf_file.insertShString(".text"),
                .type = elf.SHT_PROGBITS,
                .addralign = 1,
                .flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            });
            self.text_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".text"), osec);
            break :osec osec;
        },
        .const_data => if (self.rodata_index) |sym_index|
            self.symbol(sym_index).outputShndx(elf_file).?
        else osec: {
            const osec = try elf_file.addSection(.{
                .name = try elf_file.insertShString(".rodata"),
                .type = elf.SHT_PROGBITS,
                .addralign = 1,
                .flags = elf.SHF_ALLOC,
            });
            self.rodata_index = try self.addSectionSymbol(gpa, try self.addString(gpa, ".rodata"), osec);
            break :osec osec;
        },
    };
    const local_sym = self.symbol(symbol_index);
    local_sym.name_offset = name_str_index;
    const local_esym = &self.symtab.items(.elf_sym)[local_sym.esym_index];
    local_esym.st_name = name_str_index;
    local_esym.st_info |= elf.STT_OBJECT;
    local_esym.st_size = code.len;
    const atom_ptr = local_sym.atom(elf_file).?;
    atom_ptr.alive = true;
    atom_ptr.name_offset = name_str_index;
    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;
    atom_ptr.output_section_index = output_section_index;

    try self.allocateAtom(atom_ptr, true, elf_file);
    errdefer self.freeNavMetadata(elf_file, symbol_index);

    local_sym.value = 0;
    local_esym.st_value = 0;

    try elf_file.pwriteAll(code, atom_ptr.offset(elf_file));
}

const LowerConstResult = union(enum) {
    ok: Symbol.Index,
    fail: *Zcu.ErrorMsg,
};

fn lowerConst(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    name: []const u8,
    val: Value,
    required_alignment: InternPool.Alignment,
    output_section_index: u32,
    src_loc: Zcu.LazySrcLoc,
) !LowerConstResult {
    const gpa = pt.zcu.gpa;

    var code_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer code_buffer.deinit(gpa);

    const name_off = try self.addString(gpa, name);
    const sym_index = try self.newSymbolWithAtom(gpa, name_off);

    try codegen.generateSymbol(
        &elf_file.base,
        pt,
        src_loc,
        val,
        &code_buffer,
        .{ .atom_index = sym_index },
    );
    const code = code_buffer.items;

    const local_sym = self.symbol(sym_index);
    const local_esym = &self.symtab.items(.elf_sym)[local_sym.esym_index];
    local_esym.st_info |= elf.STT_OBJECT;
    local_esym.st_size = code.len;
    const atom_ptr = local_sym.atom(elf_file).?;
    atom_ptr.alive = true;
    atom_ptr.alignment = required_alignment;
    atom_ptr.size = code.len;
    atom_ptr.output_section_index = output_section_index;

    try self.allocateAtom(atom_ptr, true, elf_file);
    errdefer self.freeNavMetadata(elf_file, sym_index);

    try elf_file.pwriteAll(code, atom_ptr.offset(elf_file));

    return .{ .ok = sym_index };
}

pub fn updateExports(
    self: *ZigObject,
    elf_file: *Elf,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) link.File.UpdateExportsError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const zcu = pt.zcu;
    const gpa = elf_file.base.comp.gpa;
    const metadata = switch (exported) {
        .nav => |nav| blk: {
            _ = try self.getOrCreateMetadataForNav(zcu, nav);
            break :blk self.navs.getPtr(nav).?;
        },
        .uav => |uav| self.uavs.getPtr(uav) orelse blk: {
            const first_exp = export_indices[0].ptr(zcu);
            const res = try self.lowerUav(elf_file, pt, uav, .none, first_exp.src);
            switch (res) {
                .mcv => {},
                .fail => |em| {
                    // TODO maybe it's enough to return an error here and let Zcu.processExportsInner
                    // handle the error?
                    try zcu.failed_exports.ensureUnusedCapacity(zcu.gpa, 1);
                    zcu.failed_exports.putAssumeCapacityNoClobber(export_indices[0], em);
                    return;
                },
            }
            break :blk self.uavs.getPtr(uav).?;
        },
    };
    const sym_index = metadata.symbol_index;
    const esym_index = self.symbol(sym_index).esym_index;
    const esym = self.symtab.items(.elf_sym)[esym_index];
    const esym_shndx = self.symtab.items(.shndx)[esym_index];

    for (export_indices) |export_idx| {
        const exp = export_idx.ptr(zcu);
        if (exp.opts.section.unwrap()) |section_name| {
            if (!section_name.eqlSlice(".text", &zcu.intern_pool)) {
                try zcu.failed_exports.ensureUnusedCapacity(zcu.gpa, 1);
                zcu.failed_exports.putAssumeCapacityNoClobber(export_idx, try Zcu.ErrorMsg.create(
                    gpa,
                    exp.src,
                    "Unimplemented: ExportOptions.section",
                    .{},
                ));
                continue;
            }
        }
        const stb_bits: u8 = switch (exp.opts.linkage) {
            .internal => elf.STB_LOCAL,
            .strong => elf.STB_GLOBAL,
            .weak => elf.STB_WEAK,
            .link_once => {
                try zcu.failed_exports.ensureUnusedCapacity(zcu.gpa, 1);
                zcu.failed_exports.putAssumeCapacityNoClobber(export_idx, try Zcu.ErrorMsg.create(
                    gpa,
                    exp.src,
                    "Unimplemented: GlobalLinkage.LinkOnce",
                    .{},
                ));
                continue;
            },
        };
        const stt_bits: u8 = @as(u4, @truncate(esym.st_info));
        const exp_name = exp.opts.name.toSlice(&zcu.intern_pool);
        const name_off = try self.strtab.insert(gpa, exp_name);
        const global_sym_index = if (metadata.@"export"(self, exp_name)) |exp_index|
            exp_index.*
        else blk: {
            const global_sym_index = try self.getGlobalSymbol(elf_file, exp_name, null);
            try metadata.exports.append(gpa, global_sym_index);
            break :blk global_sym_index;
        };

        const value = self.symbol(sym_index).value;
        const global_sym = self.symbol(global_sym_index);
        global_sym.value = value;
        global_sym.flags.weak = exp.opts.linkage == .weak;
        global_sym.version_index = elf_file.default_sym_version;
        global_sym.ref = .{ .index = esym_shndx, .file = self.index };
        const global_esym = &self.symtab.items(.elf_sym)[global_sym.esym_index];
        global_esym.st_value = @intCast(value);
        global_esym.st_shndx = esym.st_shndx;
        global_esym.st_info = (stb_bits << 4) | stt_bits;
        global_esym.st_name = name_off;
        global_esym.st_size = esym.st_size;
        self.symtab.items(.shndx)[global_sym.esym_index] = esym_shndx;
    }
}

pub fn updateLineNumber(self: *ZigObject, pt: Zcu.PerThread, ti_id: InternPool.TrackedInst.Index) !void {
    if (self.dwarf) |*dwarf| {
        const comp = dwarf.bin_file.comp;
        const diags = &comp.link_diags;
        dwarf.updateLineNumber(pt.zcu, ti_id) catch |err| switch (err) {
            error.Overflow => return error.Overflow,
            error.OutOfMemory => return error.OutOfMemory,
            else => |e| return diags.fail("failed to update dwarf line numbers: {s}", .{@errorName(e)}),
        };
    }
}

pub fn deleteExport(
    self: *ZigObject,
    elf_file: *Elf,
    exported: Zcu.Exported,
    name: InternPool.NullTerminatedString,
) void {
    const metadata = switch (exported) {
        .nav => |nav| self.navs.getPtr(nav),
        .uav => |uav| self.uavs.getPtr(uav),
    } orelse return;
    const zcu = elf_file.base.comp.zcu.?;
    const exp_name = name.toSlice(&zcu.intern_pool);
    const sym_index = metadata.@"export"(self, exp_name) orelse return;
    log.debug("deleting export '{s}'", .{exp_name});
    const esym_index = self.symbol(sym_index.*).esym_index;
    const esym = &self.symtab.items(.elf_sym)[esym_index];
    _ = self.globals_lookup.remove(esym.st_name);
    esym.* = Elf.null_sym;
    self.symtab.items(.shndx)[esym_index] = elf.SHN_UNDEF;
}

pub fn getGlobalSymbol(self: *ZigObject, elf_file: *Elf, name: []const u8, lib_name: ?[]const u8) !u32 {
    _ = lib_name;
    const gpa = elf_file.base.comp.gpa;
    const off = try self.strtab.insert(gpa, name);
    const lookup_gop = try self.globals_lookup.getOrPut(gpa, off);
    if (!lookup_gop.found_existing) {
        lookup_gop.value_ptr.* = try self.newGlobalSymbol(gpa, off);
    }
    return lookup_gop.value_ptr.*;
}

const max_trampoline_len = 12;

fn trampolineSize(cpu_arch: std.Target.Cpu.Arch) u64 {
    const len = switch (cpu_arch) {
        .x86_64 => 5, // jmp rel32
        else => @panic("TODO implement trampoline size for this CPU arch"),
    };
    comptime assert(len <= max_trampoline_len);
    return len;
}

fn writeTrampoline(tr_sym: Symbol, target: Symbol, elf_file: *Elf) !void {
    const atom_ptr = tr_sym.atom(elf_file).?;
    const fileoff = atom_ptr.offset(elf_file);
    const source_addr = tr_sym.address(.{}, elf_file);
    const target_addr = target.address(.{ .trampoline = false }, elf_file);
    var buf: [max_trampoline_len]u8 = undefined;
    const out = switch (elf_file.getTarget().cpu.arch) {
        .x86_64 => try x86_64.writeTrampolineCode(source_addr, target_addr, &buf),
        else => @panic("TODO implement write trampoline for this CPU arch"),
    };
    try elf_file.base.file.?.pwriteAll(out, fileoff);

    if (elf_file.base.child_pid) |pid| {
        switch (builtin.os.tag) {
            .linux => {
                var local_vec: [1]std.posix.iovec_const = .{.{
                    .base = out.ptr,
                    .len = out.len,
                }};
                var remote_vec: [1]std.posix.iovec_const = .{.{
                    .base = @as([*]u8, @ptrFromInt(@as(usize, @intCast(source_addr)))),
                    .len = out.len,
                }};
                const rc = std.os.linux.process_vm_writev(pid, &local_vec, &remote_vec, 0);
                switch (std.os.linux.E.init(rc)) {
                    .SUCCESS => assert(rc == out.len),
                    else => |errno| log.warn("process_vm_writev failure: {s}", .{@tagName(errno)}),
                }
            },
            else => return error.HotSwapUnavailableOnHostOperatingSystem,
        }
    }
}

pub fn allocateAtom(self: *ZigObject, atom_ptr: *Atom, requires_padding: bool, elf_file: *Elf) !void {
    const slice = elf_file.sections.slice();
    const shdr = &slice.items(.shdr)[atom_ptr.output_section_index];
    const last_atom_ref = &slice.items(.last_atom)[atom_ptr.output_section_index];

    // This only works if this atom is the only atom in the output section. In
    // every other case, we need to redo the prev/next links.
    if (last_atom_ref.eql(atom_ptr.ref())) last_atom_ref.* = .{};

    const alloc_res = try elf_file.allocateChunk(.{
        .shndx = atom_ptr.output_section_index,
        .size = atom_ptr.size,
        .alignment = atom_ptr.alignment,
        .requires_padding = requires_padding,
    });
    atom_ptr.value = @intCast(alloc_res.value);
    log.debug("allocated {s} at {x}\n  placement {?}", .{
        atom_ptr.name(elf_file),
        atom_ptr.offset(elf_file),
        alloc_res.placement,
    });

    const expand_section = if (elf_file.atom(alloc_res.placement)) |placement_atom|
        placement_atom.nextAtom(elf_file) == null
    else
        true;
    if (expand_section) {
        last_atom_ref.* = atom_ptr.ref();
        if (self.dwarf) |_| {
            // The .debug_info section has `low_pc` and `high_pc` values which is the virtual address
            // range of the compilation unit. When we expand the text section, this range changes,
            // so the DW_TAG.compile_unit tag of the .debug_info section becomes dirty.
            self.debug_info_section_dirty = true;
            // This becomes dirty for the same reason. We could potentially make this more
            // fine-grained with the addition of support for more compilation units. It is planned to
            // model each package as a different compilation unit.
            self.debug_aranges_section_dirty = true;
            self.debug_rnglists_section_dirty = true;
        }
    }
    shdr.sh_addralign = @max(shdr.sh_addralign, atom_ptr.alignment.toByteUnits().?);

    // This function can also reallocate an atom.
    // In this case we need to "unplug" it from its previous location before
    // plugging it in to its new location.
    if (atom_ptr.prevAtom(elf_file)) |prev| {
        prev.next_atom_ref = atom_ptr.next_atom_ref;
    }
    if (atom_ptr.nextAtom(elf_file)) |next| {
        next.prev_atom_ref = atom_ptr.prev_atom_ref;
    }

    if (elf_file.atom(alloc_res.placement)) |big_atom| {
        atom_ptr.prev_atom_ref = alloc_res.placement;
        atom_ptr.next_atom_ref = big_atom.next_atom_ref;
        big_atom.next_atom_ref = atom_ptr.ref();
    } else {
        atom_ptr.prev_atom_ref = .{ .index = 0, .file = 0 };
        atom_ptr.next_atom_ref = .{ .index = 0, .file = 0 };
    }

    log.debug("  prev {?}, next {?}", .{ atom_ptr.prev_atom_ref, atom_ptr.next_atom_ref });
}

pub fn resetShdrIndexes(self: *ZigObject, backlinks: []const u32) void {
    for (self.atoms_indexes.items) |atom_index| {
        const atom_ptr = self.atom(atom_index) orelse continue;
        atom_ptr.output_section_index = backlinks[atom_ptr.output_section_index];
    }
    inline for ([_]?Symbol.Index{
        self.text_index,
        self.rodata_index,
        self.data_relro_index,
        self.data_index,
        self.bss_index,
        self.tdata_index,
        self.tbss_index,
        self.eh_frame_index,
        self.debug_info_index,
        self.debug_abbrev_index,
        self.debug_aranges_index,
        self.debug_str_index,
        self.debug_line_index,
        self.debug_line_str_index,
        self.debug_loclists_index,
        self.debug_rnglists_index,
    }) |maybe_sym_index| {
        if (maybe_sym_index) |sym_index| {
            const sym = self.symbol(sym_index);
            sym.output_section_index = backlinks[sym.output_section_index];
        }
    }
}

pub fn asFile(self: *ZigObject) File {
    return .{ .zig_object = self };
}

pub fn sectionSymbol(self: *ZigObject, shndx: u32, elf_file: *Elf) ?*Symbol {
    inline for ([_]?Symbol.Index{
        self.text_index,
        self.rodata_index,
        self.data_relro_index,
        self.data_index,
        self.bss_index,
        self.tdata_index,
        self.tbss_index,
        self.eh_frame_index,
        self.debug_info_index,
        self.debug_abbrev_index,
        self.debug_aranges_index,
        self.debug_str_index,
        self.debug_line_index,
        self.debug_line_str_index,
        self.debug_loclists_index,
        self.debug_rnglists_index,
    }) |maybe_sym_index| {
        if (maybe_sym_index) |sym_index| {
            const sym = self.symbol(sym_index);
            if (sym.outputShndx(elf_file) == shndx) return sym;
        }
    }
    return null;
}

pub fn addString(self: *ZigObject, allocator: Allocator, string: []const u8) !u32 {
    return self.strtab.insert(allocator, string);
}

pub fn getString(self: ZigObject, off: u32) [:0]const u8 {
    return self.strtab.getAssumeExists(off);
}

fn addAtom(self: *ZigObject, allocator: Allocator) !Atom.Index {
    try self.atoms.ensureUnusedCapacity(allocator, 1);
    try self.atoms_extra.ensureUnusedCapacity(allocator, @sizeOf(Atom.Extra));
    return self.addAtomAssumeCapacity();
}

fn addAtomAssumeCapacity(self: *ZigObject) Atom.Index {
    const atom_index: Atom.Index = @intCast(self.atoms.items.len);
    const atom_ptr = self.atoms.addOneAssumeCapacity();
    atom_ptr.* = .{
        .file_index = self.index,
        .atom_index = atom_index,
        .extra_index = self.addAtomExtraAssumeCapacity(.{}),
    };
    return atom_index;
}

pub fn atom(self: *ZigObject, atom_index: Atom.Index) ?*Atom {
    if (atom_index == 0) return null;
    assert(atom_index < self.atoms.items.len);
    return &self.atoms.items[atom_index];
}

fn addAtomExtra(self: *ZigObject, allocator: Allocator, extra: Atom.Extra) !u32 {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    try self.atoms_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addAtomExtraAssumeCapacity(extra);
}

fn addAtomExtraAssumeCapacity(self: *ZigObject, extra: Atom.Extra) u32 {
    const index = @as(u32, @intCast(self.atoms_extra.items.len));
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields) |field| {
        self.atoms_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn atomExtra(self: ZigObject, index: u32) Atom.Extra {
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
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

pub fn setAtomExtra(self: *ZigObject, index: u32, extra: Atom.Extra) void {
    assert(index > 0);
    const fields = @typeInfo(Atom.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.atoms_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

inline fn isGlobal(index: Symbol.Index) bool {
    return index & global_symbol_bit != 0;
}

pub fn symbol(self: *ZigObject, index: Symbol.Index) *Symbol {
    const actual_index = index & symbol_mask;
    if (isGlobal(index)) return &self.symbols.items[self.global_symbols.items[actual_index]];
    return &self.symbols.items[self.local_symbols.items[actual_index]];
}

pub fn resolveSymbol(self: ZigObject, index: Symbol.Index, elf_file: *Elf) Elf.Ref {
    if (isGlobal(index)) {
        const resolv = self.symbols_resolver.items[index & symbol_mask];
        return elf_file.resolver.get(resolv).?;
    }
    return .{ .index = index, .file = self.index };
}

fn addSymbol(self: *ZigObject, allocator: Allocator) !Symbol.Index {
    try self.symbols.ensureUnusedCapacity(allocator, 1);
    return self.addSymbolAssumeCapacity();
}

fn addSymbolAssumeCapacity(self: *ZigObject) Symbol.Index {
    const index: Symbol.Index = @intCast(self.symbols.items.len);
    self.symbols.appendAssumeCapacity(.{ .file_index = self.index });
    return index;
}

pub fn addSymbolExtra(self: *ZigObject, allocator: Allocator, extra: Symbol.Extra) !u32 {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    try self.symbols_extra.ensureUnusedCapacity(allocator, fields.len);
    return self.addSymbolExtraAssumeCapacity(extra);
}

pub fn addSymbolExtraAssumeCapacity(self: *ZigObject, extra: Symbol.Extra) u32 {
    const index = @as(u32, @intCast(self.symbols_extra.items.len));
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields) |field| {
        self.symbols_extra.appendAssumeCapacity(switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        });
    }
    return index;
}

pub fn symbolExtra(self: *ZigObject, index: u32) Symbol.Extra {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
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

pub fn setSymbolExtra(self: *ZigObject, index: u32, extra: Symbol.Extra) void {
    const fields = @typeInfo(Symbol.Extra).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        self.symbols_extra.items[index + i] = switch (field.type) {
            u32 => @field(extra, field.name),
            else => @compileError("bad field type"),
        };
    }
}

pub fn fmtSymtab(self: *ZigObject, elf_file: *Elf) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
    } };
}

const FormatContext = struct {
    self: *ZigObject,
    elf_file: *Elf,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const self = ctx.self;
    const elf_file = ctx.elf_file;
    try writer.writeAll("  locals\n");
    for (self.local_symbols.items) |index| {
        const local = self.symbols.items[index];
        try writer.print("    {}\n", .{local.fmt(elf_file)});
    }
    try writer.writeAll("  globals\n");
    for (ctx.self.global_symbols.items) |index| {
        const global = self.symbols.items[index];
        try writer.print("    {}\n", .{global.fmt(elf_file)});
    }
}

pub fn fmtAtoms(self: *ZigObject, elf_file: *Elf) std.fmt.Formatter(formatAtoms) {
    return .{ .data = .{
        .self = self,
        .elf_file = elf_file,
    } };
}

fn formatAtoms(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    try writer.writeAll("  atoms\n");
    for (ctx.self.atoms_indexes.items) |atom_index| {
        const atom_ptr = ctx.self.atom(atom_index) orelse continue;
        try writer.print("    {}\n", .{atom_ptr.fmt(ctx.elf_file)});
    }
}

const ElfSym = struct {
    elf_sym: elf.Elf64_Sym,
    shndx: u32 = elf.SHN_UNDEF,
};

const LazySymbolMetadata = struct {
    const State = enum { unused, pending_flush, flushed };
    text_symbol_index: Symbol.Index = undefined,
    rodata_symbol_index: Symbol.Index = undefined,
    text_state: State = .unused,
    rodata_state: State = .unused,
};

const AvMetadata = struct {
    symbol_index: Symbol.Index,
    /// A list of all exports aliases of this Av.
    exports: std.ArrayListUnmanaged(Symbol.Index) = .empty,
    /// Set to true if the AV has been initialized and allocated.
    allocated: bool = false,

    fn @"export"(m: AvMetadata, zig_object: *ZigObject, name: []const u8) ?*u32 {
        for (m.exports.items) |*exp| {
            const exp_name = zig_object.getString(zig_object.symbol(exp.*).name_offset);
            if (mem.eql(u8, name, exp_name)) return exp;
        }
        return null;
    }
};

fn checkNavAllocated(pt: Zcu.PerThread, index: InternPool.Nav.Index, meta: AvMetadata) void {
    if (!meta.allocated) {
        const zcu = pt.zcu;
        const ip = &zcu.intern_pool;
        const nav = ip.getNav(index);
        log.err("NAV {}({d}) assigned symbol {d} but not allocated!", .{
            nav.fqn.fmt(ip),
            index,
            meta.symbol_index,
        });
    }
}

fn checkUavAllocated(pt: Zcu.PerThread, index: InternPool.Index, meta: AvMetadata) void {
    if (!meta.allocated) {
        const zcu = pt.zcu;
        const uav = Value.fromInterned(index);
        const ty = uav.typeOf(zcu);
        log.err("UAV {}({d}) assigned symbol {d} but not allocated!", .{
            ty.fmt(pt),
            index,
            meta.symbol_index,
        });
    }
}

const TlsVariable = struct {
    symbol_index: Symbol.Index,
    code: []const u8 = &[0]u8{},

    fn deinit(tlv: *TlsVariable, allocator: Allocator) void {
        allocator.free(tlv.code);
    }
};

const AtomList = std.ArrayListUnmanaged(Atom.Index);
const NavTable = std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, AvMetadata);
const UavTable = std.AutoArrayHashMapUnmanaged(InternPool.Index, AvMetadata);
const LazySymbolTable = std.AutoArrayHashMapUnmanaged(InternPool.Index, LazySymbolMetadata);
const TlsTable = std.AutoArrayHashMapUnmanaged(Atom.Index, void);

const x86_64 = struct {
    fn writeTrampolineCode(source_addr: i64, target_addr: i64, buf: *[max_trampoline_len]u8) ![]u8 {
        const disp = @as(i64, @intCast(target_addr)) - source_addr - 5;
        var bytes = [_]u8{
            0xe9, 0x00, 0x00, 0x00, 0x00, // jmp rel32
        };
        assert(bytes.len == trampolineSize(.x86_64));
        mem.writeInt(i32, bytes[1..][0..4], @intCast(disp), .little);
        @memcpy(buf[0..bytes.len], &bytes);
        return buf[0..bytes.len];
    }
};

const assert = std.debug.assert;
const build_options = @import("build_options");
const builtin = @import("builtin");
const codegen = @import("../../codegen.zig");
const elf = std.elf;
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const mem = std.mem;
const relocation = @import("relocation.zig");
const target_util = @import("../../target.zig");
const trace = @import("../../tracy.zig").trace;
const std = @import("std");
const Allocator = std.mem.Allocator;

const Air = @import("../../Air.zig");
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Dwarf = @import("../Dwarf.zig");
const Elf = @import("../Elf.zig");
const File = @import("file.zig").File;
const InternPool = @import("../../InternPool.zig");
const Liveness = @import("../../Liveness.zig");
const Zcu = @import("../../Zcu.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");
const AnalUnit = InternPool.AnalUnit;
const ZigObject = @This();
