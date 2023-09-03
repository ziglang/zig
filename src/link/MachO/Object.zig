//! Represents an input relocatable Object file.
//! Each Object is fully loaded into memory for easier
//! access into different data within.

name: []const u8,
mtime: u64,
contents: []align(@alignOf(u64)) const u8,

header: macho.mach_header_64 = undefined,

/// Symtab and strtab might not exist for empty object files so we use an optional
/// to signal this.
in_symtab: ?[]align(1) const macho.nlist_64 = null,
in_strtab: ?[]const u8 = null,

/// Output symtab is sorted so that we can easily reference symbols following each
/// other in address space.
/// The length of the symtab is at least of the input symtab length however there
/// can be trailing section symbols.
symtab: []macho.nlist_64 = undefined,
/// Can be undefined as set together with in_symtab.
source_symtab_lookup: []u32 = undefined,
/// Can be undefined as set together with in_symtab.
reverse_symtab_lookup: []u32 = undefined,
/// Can be undefined as set together with in_symtab.
source_address_lookup: []i64 = undefined,
/// Can be undefined as set together with in_symtab.
source_section_index_lookup: []Entry = undefined,
/// Can be undefined as set together with in_symtab.
strtab_lookup: []u32 = undefined,
/// Can be undefined as set together with in_symtab.
atom_by_index_table: []?Atom.Index = undefined,
/// Can be undefined as set together with in_symtab.
globals_lookup: []i64 = undefined,
/// Can be undefined as set together with in_symtab.
relocs_lookup: []Entry = undefined,

/// All relocations sorted and flatened, sorted by address descending
/// per section.
relocations: std.ArrayListUnmanaged(macho.relocation_info) = .{},
/// Beginning index to the relocations array for each input section
/// defined within this Object file.
section_relocs_lookup: std.ArrayListUnmanaged(u32) = .{},

/// Data-in-code records sorted by address.
data_in_code: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

atoms: std.ArrayListUnmanaged(Atom.Index) = .{},
exec_atoms: std.ArrayListUnmanaged(Atom.Index) = .{},

eh_frame_sect_id: ?u8 = null,
eh_frame_relocs_lookup: std.AutoArrayHashMapUnmanaged(u32, Record) = .{},
eh_frame_records_lookup: std.AutoArrayHashMapUnmanaged(SymbolWithLoc, u32) = .{},

unwind_info_sect_id: ?u8 = null,
unwind_relocs_lookup: []Record = undefined,
unwind_records_lookup: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

const Entry = struct {
    start: u32 = 0,
    len: u32 = 0,
};

const Record = struct {
    dead: bool,
    reloc: Entry,
};

pub fn isObject(file: std.fs.File) bool {
    const reader = file.reader();
    const hdr = reader.readStruct(macho.mach_header_64) catch return false;
    defer file.seekTo(0) catch {};
    return hdr.filetype == macho.MH_OBJECT;
}

pub fn deinit(self: *Object, gpa: Allocator) void {
    self.atoms.deinit(gpa);
    self.exec_atoms.deinit(gpa);
    gpa.free(self.name);
    gpa.free(self.contents);
    if (self.in_symtab) |_| {
        gpa.free(self.source_symtab_lookup);
        gpa.free(self.reverse_symtab_lookup);
        gpa.free(self.source_address_lookup);
        gpa.free(self.source_section_index_lookup);
        gpa.free(self.strtab_lookup);
        gpa.free(self.symtab);
        gpa.free(self.atom_by_index_table);
        gpa.free(self.globals_lookup);
        gpa.free(self.relocs_lookup);
    }
    self.eh_frame_relocs_lookup.deinit(gpa);
    self.eh_frame_records_lookup.deinit(gpa);
    if (self.hasUnwindRecords()) {
        gpa.free(self.unwind_relocs_lookup);
    }
    self.unwind_records_lookup.deinit(gpa);
    self.relocations.deinit(gpa);
    self.section_relocs_lookup.deinit(gpa);
    self.data_in_code.deinit(gpa);
}

pub fn parse(self: *Object, allocator: Allocator) !void {
    var stream = std.io.fixedBufferStream(self.contents);
    const reader = stream.reader();

    self.header = try reader.readStruct(macho.mach_header_64);

    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    const nsects = self.getSourceSections().len;

    // Prepopulate relocations per section lookup table.
    try self.section_relocs_lookup.resize(allocator, nsects);
    @memset(self.section_relocs_lookup.items, 0);

    // Parse symtab.
    const symtab = while (it.next()) |cmd| switch (cmd.cmd()) {
        .SYMTAB => break cmd.cast(macho.symtab_command).?,
        else => {},
    } else return;

    self.in_symtab = @as([*]align(1) const macho.nlist_64, @ptrCast(self.contents.ptr + symtab.symoff))[0..symtab.nsyms];
    self.in_strtab = self.contents[symtab.stroff..][0..symtab.strsize];

    self.symtab = try allocator.alloc(macho.nlist_64, self.in_symtab.?.len + nsects);
    self.source_symtab_lookup = try allocator.alloc(u32, self.in_symtab.?.len);
    self.reverse_symtab_lookup = try allocator.alloc(u32, self.in_symtab.?.len);
    self.strtab_lookup = try allocator.alloc(u32, self.in_symtab.?.len);
    self.globals_lookup = try allocator.alloc(i64, self.in_symtab.?.len);
    self.atom_by_index_table = try allocator.alloc(?Atom.Index, self.in_symtab.?.len + nsects);
    self.relocs_lookup = try allocator.alloc(Entry, self.in_symtab.?.len + nsects);
    // This is wasteful but we need to be able to lookup source symbol address after stripping and
    // allocating of sections.
    self.source_address_lookup = try allocator.alloc(i64, self.in_symtab.?.len);
    self.source_section_index_lookup = try allocator.alloc(Entry, nsects);

    for (self.symtab) |*sym| {
        sym.* = .{
            .n_value = 0,
            .n_sect = 0,
            .n_desc = 0,
            .n_strx = 0,
            .n_type = 0,
        };
    }

    @memset(self.globals_lookup, -1);
    @memset(self.atom_by_index_table, null);
    @memset(self.source_section_index_lookup, .{});
    @memset(self.relocs_lookup, .{});

    // You would expect that the symbol table is at least pre-sorted based on symbol's type:
    // local < extern defined < undefined. Unfortunately, this is not guaranteed! For instance,
    // the GO compiler does not necessarily respect that therefore we sort immediately by type
    // and address within.
    var sorted_all_syms = try std.ArrayList(SymbolAtIndex).initCapacity(allocator, self.in_symtab.?.len);
    defer sorted_all_syms.deinit();

    for (self.in_symtab.?, 0..) |_, index| {
        sorted_all_syms.appendAssumeCapacity(.{ .index = @as(u32, @intCast(index)) });
    }

    // We sort by type: defined < undefined, and
    // afterwards by address in each group. Normally, dysymtab should
    // be enough to guarantee the sort, but turns out not every compiler
    // is kind enough to specify the symbols in the correct order.
    mem.sort(SymbolAtIndex, sorted_all_syms.items, self, SymbolAtIndex.lessThan);

    var prev_sect_id: u8 = 0;
    var section_index_lookup: ?Entry = null;
    for (sorted_all_syms.items, 0..) |sym_id, i| {
        const sym = sym_id.getSymbol(self);

        if (section_index_lookup) |*lookup| {
            if (sym.n_sect != prev_sect_id or sym.undf()) {
                self.source_section_index_lookup[prev_sect_id - 1] = lookup.*;
                section_index_lookup = null;
            } else {
                lookup.len += 1;
            }
        }
        if (sym.sect() and section_index_lookup == null) {
            section_index_lookup = .{ .start = @as(u32, @intCast(i)), .len = 1 };
        }

        prev_sect_id = sym.n_sect;

        self.symtab[i] = sym;
        self.source_symtab_lookup[i] = sym_id.index;
        self.reverse_symtab_lookup[sym_id.index] = @as(u32, @intCast(i));
        self.source_address_lookup[i] = if (sym.undf()) -1 else @as(i64, @intCast(sym.n_value));

        const sym_name_len = mem.sliceTo(@as([*:0]const u8, @ptrCast(self.in_strtab.?.ptr + sym.n_strx)), 0).len + 1;
        self.strtab_lookup[i] = @as(u32, @intCast(sym_name_len));
    }

    // If there were no undefined symbols, make sure we populate the
    // source section index lookup for the last scanned section.
    if (section_index_lookup) |lookup| {
        self.source_section_index_lookup[prev_sect_id - 1] = lookup;
    }

    // Parse __TEXT,__eh_frame header if one exists
    self.eh_frame_sect_id = self.getSourceSectionIndexByName("__TEXT", "__eh_frame");

    // Parse __LD,__compact_unwind header if one exists
    self.unwind_info_sect_id = self.getSourceSectionIndexByName("__LD", "__compact_unwind");
    if (self.hasUnwindRecords()) {
        self.unwind_relocs_lookup = try allocator.alloc(Record, self.getUnwindRecords().len);
        @memset(self.unwind_relocs_lookup, .{ .dead = true, .reloc = .{} });
    }
}

const SymbolAtIndex = struct {
    index: u32,

    const Context = *const Object;

    fn getSymbol(self: SymbolAtIndex, ctx: Context) macho.nlist_64 {
        return ctx.in_symtab.?[self.index];
    }

    fn getSymbolName(self: SymbolAtIndex, ctx: Context) []const u8 {
        const off = self.getSymbol(ctx).n_strx;
        return mem.sliceTo(@as([*:0]const u8, @ptrCast(ctx.in_strtab.?.ptr + off)), 0);
    }

    fn getSymbolSeniority(self: SymbolAtIndex, ctx: Context) u2 {
        const sym = self.getSymbol(ctx);
        if (!sym.ext()) {
            const sym_name = self.getSymbolName(ctx);
            if (mem.startsWith(u8, sym_name, "l") or mem.startsWith(u8, sym_name, "L")) return 3;
            return 2;
        }
        if (sym.weakDef() or sym.pext()) return 1;
        return 0;
    }

    /// Performs lexicographic-like check.
    /// * lhs and rhs defined
    ///   * if lhs == rhs
    ///     * if lhs.n_sect == rhs.n_sect
    ///       * ext < weak < local < temp
    ///     * lhs.n_sect < rhs.n_sect
    ///   * lhs < rhs
    /// * !rhs is undefined
    fn lessThan(ctx: Context, lhs_index: SymbolAtIndex, rhs_index: SymbolAtIndex) bool {
        const lhs = lhs_index.getSymbol(ctx);
        const rhs = rhs_index.getSymbol(ctx);
        if (lhs.sect() and rhs.sect()) {
            if (lhs.n_value == rhs.n_value) {
                if (lhs.n_sect == rhs.n_sect) {
                    const lhs_senior = lhs_index.getSymbolSeniority(ctx);
                    const rhs_senior = rhs_index.getSymbolSeniority(ctx);
                    if (lhs_senior == rhs_senior) {
                        return lessThanByNStrx(ctx, lhs_index, rhs_index);
                    } else return lhs_senior < rhs_senior;
                } else return lhs.n_sect < rhs.n_sect;
            } else return lhs.n_value < rhs.n_value;
        } else if (lhs.undf() and rhs.undf()) {
            return lessThanByNStrx(ctx, lhs_index, rhs_index);
        } else return rhs.undf();
    }

    fn lessThanByNStrx(ctx: Context, lhs: SymbolAtIndex, rhs: SymbolAtIndex) bool {
        return lhs.getSymbol(ctx).n_strx < rhs.getSymbol(ctx).n_strx;
    }
};

fn filterSymbolsBySection(symbols: []macho.nlist_64, n_sect: u8) struct {
    index: u32,
    len: u32,
} {
    const FirstMatch = struct {
        n_sect: u8,

        pub fn predicate(pred: @This(), symbol: macho.nlist_64) bool {
            return symbol.n_sect == pred.n_sect;
        }
    };
    const FirstNonMatch = struct {
        n_sect: u8,

        pub fn predicate(pred: @This(), symbol: macho.nlist_64) bool {
            return symbol.n_sect != pred.n_sect;
        }
    };

    const index = MachO.lsearch(macho.nlist_64, symbols, FirstMatch{
        .n_sect = n_sect,
    });
    const len = MachO.lsearch(macho.nlist_64, symbols[index..], FirstNonMatch{
        .n_sect = n_sect,
    });

    return .{ .index = @as(u32, @intCast(index)), .len = @as(u32, @intCast(len)) };
}

fn filterSymbolsByAddress(symbols: []macho.nlist_64, start_addr: u64, end_addr: u64) struct {
    index: u32,
    len: u32,
} {
    const Predicate = struct {
        addr: u64,

        pub fn predicate(pred: @This(), symbol: macho.nlist_64) bool {
            return symbol.n_value >= pred.addr;
        }
    };

    const index = MachO.lsearch(macho.nlist_64, symbols, Predicate{
        .addr = start_addr,
    });
    const len = MachO.lsearch(macho.nlist_64, symbols[index..], Predicate{
        .addr = end_addr,
    });

    return .{ .index = @as(u32, @intCast(index)), .len = @as(u32, @intCast(len)) };
}

const SortedSection = struct {
    header: macho.section_64,
    id: u8,
};

fn sectionLessThanByAddress(ctx: void, lhs: SortedSection, rhs: SortedSection) bool {
    _ = ctx;
    if (lhs.header.addr == rhs.header.addr) {
        return lhs.id < rhs.id;
    }
    return lhs.header.addr < rhs.header.addr;
}

pub const SplitIntoAtomsError = error{
    OutOfMemory,
    EndOfStream,
    MissingEhFrameSection,
    BadDwarfCfi,
};

pub fn splitIntoAtoms(self: *Object, macho_file: *MachO, object_id: u32) SplitIntoAtomsError!void {
    log.debug("splitting object({d}, {s}) into atoms", .{ object_id, self.name });

    try self.splitRegularSections(macho_file, object_id);
    try self.parseEhFrameSection(macho_file, object_id);
    try self.parseUnwindInfo(macho_file, object_id);
    try self.parseDataInCode(macho_file.base.allocator);
}

/// Splits input regular sections into Atoms.
/// If the Object was compiled with `MH_SUBSECTIONS_VIA_SYMBOLS`, splits section
/// into subsections where each subsection then represents an Atom.
pub fn splitRegularSections(self: *Object, macho_file: *MachO, object_id: u32) !void {
    const gpa = macho_file.base.allocator;

    const sections = self.getSourceSections();
    for (sections, 0..) |sect, id| {
        if (sect.isDebug()) continue;
        const out_sect_id = (try Atom.getOutputSection(macho_file, sect)) orelse {
            log.debug("  unhandled section '{s},{s}'", .{ sect.segName(), sect.sectName() });
            continue;
        };
        if (sect.size == 0) continue;

        const sect_id = @as(u8, @intCast(id));
        const sym = self.getSectionAliasSymbolPtr(sect_id);
        sym.* = .{
            .n_strx = 0,
            .n_type = macho.N_SECT,
            .n_sect = out_sect_id + 1,
            .n_desc = 0,
            .n_value = sect.addr,
        };
    }

    if (self.in_symtab == null) {
        for (sections, 0..) |sect, id| {
            if (sect.isDebug()) continue;
            const out_sect_id = (try Atom.getOutputSection(macho_file, sect)) orelse continue;
            if (sect.size == 0) continue;

            const sect_id = @as(u8, @intCast(id));
            const sym_index = self.getSectionAliasSymbolIndex(sect_id);
            const atom_index = try self.createAtomFromSubsection(
                macho_file,
                object_id,
                sym_index,
                sym_index,
                1,
                sect.size,
                sect.@"align",
                out_sect_id,
            );
            macho_file.addAtomToSection(atom_index);
        }
        return;
    }

    // Well, shit, sometimes compilers skip the dysymtab load command altogether, meaning we
    // have to infer the start of undef section in the symtab ourselves.
    const iundefsym = blk: {
        const dysymtab = self.getDysymtab() orelse {
            var iundefsym: usize = self.in_symtab.?.len;
            while (iundefsym > 0) : (iundefsym -= 1) {
                const sym = self.symtab[iundefsym - 1];
                if (sym.sect()) break;
            }
            break :blk iundefsym;
        };
        break :blk dysymtab.iundefsym;
    };

    // We only care about defined symbols, so filter every other out.
    const symtab = try gpa.dupe(macho.nlist_64, self.symtab[0..iundefsym]);
    defer gpa.free(symtab);

    const subsections_via_symbols = self.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0;

    // Sort section headers by address.
    var sorted_sections = try gpa.alloc(SortedSection, sections.len);
    defer gpa.free(sorted_sections);

    for (sections, 0..) |sect, id| {
        sorted_sections[id] = .{ .header = sect, .id = @as(u8, @intCast(id)) };
    }

    mem.sort(SortedSection, sorted_sections, {}, sectionLessThanByAddress);

    var sect_sym_index: u32 = 0;
    for (sorted_sections) |section| {
        const sect = section.header;
        if (sect.isDebug()) continue;

        const sect_id = section.id;
        log.debug("splitting section '{s},{s}' into atoms", .{ sect.segName(), sect.sectName() });

        // Get output segment/section in the final artifact.
        const out_sect_id = (try Atom.getOutputSection(macho_file, sect)) orelse continue;

        log.debug("  output sect({d}, '{s},{s}')", .{
            out_sect_id + 1,
            macho_file.sections.items(.header)[out_sect_id].segName(),
            macho_file.sections.items(.header)[out_sect_id].sectName(),
        });

        try self.parseRelocs(gpa, section.id);

        const cpu_arch = macho_file.base.options.target.cpu.arch;
        const sect_loc = filterSymbolsBySection(symtab[sect_sym_index..], sect_id + 1);
        const sect_start_index = sect_sym_index + sect_loc.index;

        sect_sym_index += sect_loc.len;

        if (sect.size == 0) continue;
        if (subsections_via_symbols and sect_loc.len > 0) {
            // If the first nlist does not match the start of the section,
            // then we need to encapsulate the memory range [section start, first symbol)
            // as a temporary symbol and insert the matching Atom.
            const first_sym = symtab[sect_start_index];
            if (first_sym.n_value > sect.addr) {
                const sym_index = self.getSectionAliasSymbolIndex(sect_id);
                const atom_size = first_sym.n_value - sect.addr;
                const atom_index = try self.createAtomFromSubsection(
                    macho_file,
                    object_id,
                    sym_index,
                    sym_index,
                    1,
                    atom_size,
                    sect.@"align",
                    out_sect_id,
                );
                if (!sect.isZerofill()) {
                    try self.cacheRelocs(macho_file, atom_index);
                }
                macho_file.addAtomToSection(atom_index);
            }

            var next_sym_index = sect_start_index;
            while (next_sym_index < sect_start_index + sect_loc.len) {
                const next_sym = symtab[next_sym_index];
                const addr = next_sym.n_value;
                const atom_loc = filterSymbolsByAddress(symtab[next_sym_index..], addr, addr + 1);
                assert(atom_loc.len > 0);
                const atom_sym_index = atom_loc.index + next_sym_index;
                const nsyms_trailing = atom_loc.len;
                next_sym_index += atom_loc.len;

                const atom_size = if (next_sym_index < sect_start_index + sect_loc.len)
                    symtab[next_sym_index].n_value - addr
                else
                    sect.addr + sect.size - addr;

                const atom_align = if (addr > 0)
                    @min(@ctz(addr), sect.@"align")
                else
                    sect.@"align";

                const atom_index = try self.createAtomFromSubsection(
                    macho_file,
                    object_id,
                    atom_sym_index,
                    atom_sym_index,
                    nsyms_trailing,
                    atom_size,
                    atom_align,
                    out_sect_id,
                );

                // TODO rework this at the relocation level
                if (cpu_arch == .x86_64 and addr == sect.addr) {
                    // In x86_64 relocs, it can so happen that the compiler refers to the same
                    // atom by both the actual assigned symbol and the start of the section. In this
                    // case, we need to link the two together so add an alias.
                    const alias_index = self.getSectionAliasSymbolIndex(sect_id);
                    self.atom_by_index_table[alias_index] = atom_index;
                }
                if (!sect.isZerofill()) {
                    try self.cacheRelocs(macho_file, atom_index);
                }
                macho_file.addAtomToSection(atom_index);
            }
        } else {
            const alias_index = self.getSectionAliasSymbolIndex(sect_id);
            const atom_index = try self.createAtomFromSubsection(
                macho_file,
                object_id,
                alias_index,
                sect_start_index,
                sect_loc.len,
                sect.size,
                sect.@"align",
                out_sect_id,
            );
            if (!sect.isZerofill()) {
                try self.cacheRelocs(macho_file, atom_index);
            }
            macho_file.addAtomToSection(atom_index);
        }
    }
}

fn createAtomFromSubsection(
    self: *Object,
    macho_file: *MachO,
    object_id: u32,
    sym_index: u32,
    inner_sym_index: u32,
    inner_nsyms_trailing: u32,
    size: u64,
    alignment: u32,
    out_sect_id: u8,
) !Atom.Index {
    const gpa = macho_file.base.allocator;
    const atom_index = try macho_file.createAtom(sym_index, .{ .size = size, .alignment = alignment });
    const atom = macho_file.getAtomPtr(atom_index);
    atom.inner_sym_index = inner_sym_index;
    atom.inner_nsyms_trailing = inner_nsyms_trailing;
    atom.file = object_id + 1;
    self.symtab[sym_index].n_sect = out_sect_id + 1;

    log.debug("creating ATOM(%{d}, '{s}') in sect({d}, '{s},{s}') in object({d})", .{
        sym_index,
        self.getSymbolName(sym_index),
        out_sect_id + 1,
        macho_file.sections.items(.header)[out_sect_id].segName(),
        macho_file.sections.items(.header)[out_sect_id].sectName(),
        object_id,
    });

    try self.atoms.append(gpa, atom_index);
    self.atom_by_index_table[sym_index] = atom_index;

    var it = Atom.getInnerSymbolsIterator(macho_file, atom_index);
    while (it.next()) |sym_loc| {
        const inner = macho_file.getSymbolPtr(sym_loc);
        inner.n_sect = out_sect_id + 1;
        self.atom_by_index_table[sym_loc.sym_index] = atom_index;
    }

    const out_sect = macho_file.sections.items(.header)[out_sect_id];
    if (out_sect.isCode() and
        mem.eql(u8, "__TEXT", out_sect.segName()) and
        mem.eql(u8, "__text", out_sect.sectName()))
    {
        // TODO currently assuming a single section for executable machine code
        try self.exec_atoms.append(gpa, atom_index);
    }

    return atom_index;
}

fn filterRelocs(
    relocs: []align(1) const macho.relocation_info,
    start_addr: u64,
    end_addr: u64,
) Entry {
    const Predicate = struct {
        addr: u64,

        pub fn predicate(self: @This(), rel: macho.relocation_info) bool {
            return rel.r_address >= self.addr;
        }
    };
    const LPredicate = struct {
        addr: u64,

        pub fn predicate(self: @This(), rel: macho.relocation_info) bool {
            return rel.r_address < self.addr;
        }
    };

    const start = MachO.bsearch(macho.relocation_info, relocs, Predicate{ .addr = end_addr });
    const len = MachO.lsearch(macho.relocation_info, relocs[start..], LPredicate{ .addr = start_addr });

    return .{ .start = @as(u32, @intCast(start)), .len = @as(u32, @intCast(len)) };
}

/// Parse all relocs for the input section, and sort in descending order.
/// Previously, I have wrongly assumed the compilers output relocations for each
/// section in a sorted manner which is simply not true.
fn parseRelocs(self: *Object, gpa: Allocator, sect_id: u8) !void {
    const section = self.getSourceSection(sect_id);
    const start = @as(u32, @intCast(self.relocations.items.len));
    if (self.getSourceRelocs(section)) |relocs| {
        try self.relocations.ensureUnusedCapacity(gpa, relocs.len);
        self.relocations.appendUnalignedSliceAssumeCapacity(relocs);
        mem.sort(macho.relocation_info, self.relocations.items[start..], {}, relocGreaterThan);
    }
    self.section_relocs_lookup.items[sect_id] = start;
}

fn cacheRelocs(self: *Object, macho_file: *MachO, atom_index: Atom.Index) !void {
    const atom = macho_file.getAtom(atom_index);

    const source_sect_id = if (self.getSourceSymbol(atom.sym_index)) |source_sym| blk: {
        break :blk source_sym.n_sect - 1;
    } else blk: {
        // If there was no matching symbol present in the source symtab, this means
        // we are dealing with either an entire section, or part of it, but also
        // starting at the beginning.
        const nbase = @as(u32, @intCast(self.in_symtab.?.len));
        const sect_id = @as(u8, @intCast(atom.sym_index - nbase));
        break :blk sect_id;
    };
    const source_sect = self.getSourceSection(source_sect_id);
    assert(!source_sect.isZerofill());
    const relocs = self.getRelocs(source_sect_id);

    self.relocs_lookup[atom.sym_index] = if (self.getSourceSymbol(atom.sym_index)) |source_sym| blk: {
        const offset = source_sym.n_value - source_sect.addr;
        break :blk filterRelocs(relocs, offset, offset + atom.size);
    } else filterRelocs(relocs, 0, atom.size);
}

fn relocGreaterThan(ctx: void, lhs: macho.relocation_info, rhs: macho.relocation_info) bool {
    _ = ctx;
    return lhs.r_address > rhs.r_address;
}

fn parseEhFrameSection(self: *Object, macho_file: *MachO, object_id: u32) !void {
    const sect_id = self.eh_frame_sect_id orelse return;
    const sect = self.getSourceSection(sect_id);

    log.debug("parsing __TEXT,__eh_frame section", .{});

    const gpa = macho_file.base.allocator;

    if (macho_file.eh_frame_section_index == null) {
        macho_file.eh_frame_section_index = try macho_file.initSection("__TEXT", "__eh_frame", .{});
    }

    const cpu_arch = macho_file.base.options.target.cpu.arch;
    try self.parseRelocs(gpa, sect_id);
    const relocs = self.getRelocs(sect_id);

    var it = self.getEhFrameRecordsIterator();
    var record_count: u32 = 0;
    while (try it.next()) |_| {
        record_count += 1;
    }

    try self.eh_frame_relocs_lookup.ensureTotalCapacity(gpa, record_count);
    try self.eh_frame_records_lookup.ensureUnusedCapacity(gpa, record_count);

    it.reset();

    while (try it.next()) |record| {
        const offset = it.pos - record.getSize();
        const rel_pos: Entry = switch (cpu_arch) {
            .aarch64 => filterRelocs(relocs, offset, offset + record.getSize()),
            .x86_64 => .{},
            else => unreachable,
        };
        self.eh_frame_relocs_lookup.putAssumeCapacityNoClobber(offset, .{
            .dead = false,
            .reloc = rel_pos,
        });

        if (record.tag == .fde) {
            const target = blk: {
                switch (cpu_arch) {
                    .aarch64 => {
                        assert(rel_pos.len > 0); // TODO convert to an error as the FDE eh frame is malformed
                        // Find function symbol that this record describes
                        const rel = for (relocs[rel_pos.start..][0..rel_pos.len]) |rel| {
                            if (rel.r_address - @as(i32, @intCast(offset)) == 8 and
                                @as(macho.reloc_type_arm64, @enumFromInt(rel.r_type)) == .ARM64_RELOC_UNSIGNED)
                                break rel;
                        } else unreachable;
                        const target = Atom.parseRelocTarget(macho_file, .{
                            .object_id = object_id,
                            .rel = rel,
                            .code = it.data[offset..],
                            .base_offset = @as(i32, @intCast(offset)),
                        });
                        break :blk target;
                    },
                    .x86_64 => {
                        const target_address = record.getTargetSymbolAddress(.{
                            .base_addr = sect.addr,
                            .base_offset = offset,
                        });
                        const target_sym_index = self.getSymbolByAddress(target_address, null);
                        const target = if (self.getGlobal(target_sym_index)) |global_index|
                            macho_file.globals.items[global_index]
                        else
                            SymbolWithLoc{ .sym_index = target_sym_index, .file = object_id + 1 };
                        break :blk target;
                    },
                    else => unreachable,
                }
            };
            if (target.getFile() != object_id) {
                log.debug("FDE at offset {x} marked DEAD", .{offset});
                self.eh_frame_relocs_lookup.getPtr(offset).?.dead = true;
            } else {
                // You would think that we are done but turns out that the compilers may use
                // whichever symbol alias they want for a target symbol. This in particular
                // very problematic when using Zig's @export feature to re-export symbols under
                // additional names. For that reason, we need to ensure we record aliases here
                // too so that we can tie them with their matching unwind records and vice versa.
                const aliases = self.getSymbolAliases(target.sym_index);
                var i: u32 = 0;
                while (i < aliases.len) : (i += 1) {
                    const actual_target = SymbolWithLoc{
                        .sym_index = i + aliases.start,
                        .file = target.file,
                    };
                    log.debug("FDE at offset {x} tracks {s}", .{
                        offset,
                        macho_file.getSymbolName(actual_target),
                    });
                    try self.eh_frame_records_lookup.putNoClobber(gpa, actual_target, offset);
                }
            }
        }
    }
}

fn parseUnwindInfo(self: *Object, macho_file: *MachO, object_id: u32) !void {
    const gpa = macho_file.base.allocator;
    const cpu_arch = macho_file.base.options.target.cpu.arch;
    const sect_id = self.unwind_info_sect_id orelse {
        // If it so happens that the object had `__eh_frame` section defined but no `__compact_unwind`,
        // we will try fully synthesising unwind info records to somewhat match Apple ld's
        // approach. However, we will only synthesise DWARF records and nothing more. For this reason,
        // we still create the output `__TEXT,__unwind_info` section.
        if (self.hasEhFrameRecords()) {
            if (macho_file.unwind_info_section_index == null) {
                macho_file.unwind_info_section_index = try macho_file.initSection(
                    "__TEXT",
                    "__unwind_info",
                    .{},
                );
            }
        }
        return;
    };

    log.debug("parsing unwind info in {s}", .{self.name});

    if (macho_file.unwind_info_section_index == null) {
        macho_file.unwind_info_section_index = try macho_file.initSection("__TEXT", "__unwind_info", .{});
    }

    const unwind_records = self.getUnwindRecords();

    try self.unwind_records_lookup.ensureUnusedCapacity(gpa, @as(u32, @intCast(unwind_records.len)));

    const needs_eh_frame = for (unwind_records) |record| {
        if (UnwindInfo.UnwindEncoding.isDwarf(record.compactUnwindEncoding, cpu_arch)) break true;
    } else false;

    if (needs_eh_frame and !self.hasEhFrameRecords()) return error.MissingEhFrameSection;

    try self.parseRelocs(gpa, sect_id);
    const relocs = self.getRelocs(sect_id);

    for (unwind_records, 0..) |record, record_id| {
        const offset = record_id * @sizeOf(macho.compact_unwind_entry);
        const rel_pos = filterRelocs(
            relocs,
            offset,
            offset + @sizeOf(macho.compact_unwind_entry),
        );
        assert(rel_pos.len > 0); // TODO convert to an error as the unwind info is malformed
        self.unwind_relocs_lookup[record_id] = .{
            .dead = false,
            .reloc = rel_pos,
        };

        // Find function symbol that this record describes
        const rel = relocs[rel_pos.start..][rel_pos.len - 1];
        const target = Atom.parseRelocTarget(macho_file, .{
            .object_id = object_id,
            .rel = rel,
            .code = mem.asBytes(&record),
            .base_offset = @as(i32, @intCast(offset)),
        });
        if (target.getFile() != object_id) {
            log.debug("unwind record {d} marked DEAD", .{record_id});
            self.unwind_relocs_lookup[record_id].dead = true;
        } else {
            // You would think that we are done but turns out that the compilers may use
            // whichever symbol alias they want for a target symbol. This in particular
            // very problematic when using Zig's @export feature to re-export symbols under
            // additional names. For that reason, we need to ensure we record aliases here
            // too so that we can tie them with their matching unwind records and vice versa.
            const aliases = self.getSymbolAliases(target.sym_index);
            var i: u32 = 0;
            while (i < aliases.len) : (i += 1) {
                const actual_target = SymbolWithLoc{
                    .sym_index = i + aliases.start,
                    .file = target.file,
                };
                log.debug("unwind record {d} tracks {s}", .{
                    record_id,
                    macho_file.getSymbolName(actual_target),
                });
                try self.unwind_records_lookup.putNoClobber(gpa, actual_target, @intCast(record_id));
            }
        }
    }
}

pub fn getSourceSymbol(self: Object, index: u32) ?macho.nlist_64 {
    const symtab = self.in_symtab.?;
    if (index >= symtab.len) return null;
    const mapped_index = self.source_symtab_lookup[index];
    return symtab[mapped_index];
}

pub fn getSourceSection(self: Object, index: u8) macho.section_64 {
    const sections = self.getSourceSections();
    assert(index < sections.len);
    return sections[index];
}

pub fn getSourceSectionByName(self: Object, segname: []const u8, sectname: []const u8) ?macho.section_64 {
    const index = self.getSourceSectionIndexByName(segname, sectname) orelse return null;
    const sections = self.getSourceSections();
    return sections[index];
}

pub fn getSourceSectionIndexByName(self: Object, segname: []const u8, sectname: []const u8) ?u8 {
    const sections = self.getSourceSections();
    for (sections, 0..) |sect, i| {
        if (mem.eql(u8, segname, sect.segName()) and mem.eql(u8, sectname, sect.sectName()))
            return @as(u8, @intCast(i));
    } else return null;
}

pub fn getSourceSections(self: Object) []const macho.section_64 {
    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    while (it.next()) |cmd| switch (cmd.cmd()) {
        .SEGMENT_64 => {
            return cmd.getSections();
        },
        else => {},
    } else unreachable;
}

pub fn parseDataInCode(self: *Object, gpa: Allocator) !void {
    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    const cmd = while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .DATA_IN_CODE => break cmd.cast(macho.linkedit_data_command).?,
            else => {},
        }
    } else return;
    const ndice = @divExact(cmd.datasize, @sizeOf(macho.data_in_code_entry));
    const dice = @as([*]align(1) const macho.data_in_code_entry, @ptrCast(self.contents.ptr + cmd.dataoff))[0..ndice];
    try self.data_in_code.ensureTotalCapacityPrecise(gpa, dice.len);
    self.data_in_code.appendUnalignedSliceAssumeCapacity(dice);
    mem.sort(macho.data_in_code_entry, self.data_in_code.items, {}, diceLessThan);
}

fn diceLessThan(ctx: void, lhs: macho.data_in_code_entry, rhs: macho.data_in_code_entry) bool {
    _ = ctx;
    return lhs.offset < rhs.offset;
}

fn getDysymtab(self: Object) ?macho.dysymtab_command {
    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .DYSYMTAB => return cmd.cast(macho.dysymtab_command).?,
            else => {},
        }
    } else return null;
}

pub fn parseDwarfInfo(self: Object) DwarfInfo {
    var di = DwarfInfo{
        .debug_info = &[0]u8{},
        .debug_abbrev = &[0]u8{},
        .debug_str = &[0]u8{},
    };
    for (self.getSourceSections()) |sect| {
        if (!sect.isDebug()) continue;
        const sectname = sect.sectName();
        if (mem.eql(u8, sectname, "__debug_info")) {
            di.debug_info = self.getSectionContents(sect);
        } else if (mem.eql(u8, sectname, "__debug_abbrev")) {
            di.debug_abbrev = self.getSectionContents(sect);
        } else if (mem.eql(u8, sectname, "__debug_str")) {
            di.debug_str = self.getSectionContents(sect);
        }
    }
    return di;
}

/// Returns Platform composed from the first encountered build version type load command:
/// either LC_BUILD_VERSION or LC_VERSION_MIN_*.
pub fn getPlatform(self: Object) ?Platform {
    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .BUILD_VERSION,
            .VERSION_MIN_MACOSX,
            .VERSION_MIN_IPHONEOS,
            .VERSION_MIN_TVOS,
            .VERSION_MIN_WATCHOS,
            => return Platform.fromLoadCommand(cmd),
            else => {},
        }
    } else return null;
}

pub fn getSectionContents(self: Object, sect: macho.section_64) []const u8 {
    const size = @as(usize, @intCast(sect.size));
    return self.contents[sect.offset..][0..size];
}

pub fn getSectionAliasSymbolIndex(self: Object, sect_id: u8) u32 {
    const start = @as(u32, @intCast(self.in_symtab.?.len));
    return start + sect_id;
}

pub fn getSectionAliasSymbol(self: *Object, sect_id: u8) macho.nlist_64 {
    return self.symtab[self.getSectionAliasSymbolIndex(sect_id)];
}

pub fn getSectionAliasSymbolPtr(self: *Object, sect_id: u8) *macho.nlist_64 {
    return &self.symtab[self.getSectionAliasSymbolIndex(sect_id)];
}

fn getSourceRelocs(self: Object, sect: macho.section_64) ?[]align(1) const macho.relocation_info {
    if (sect.nreloc == 0) return null;
    return @as([*]align(1) const macho.relocation_info, @ptrCast(self.contents.ptr + sect.reloff))[0..sect.nreloc];
}

pub fn getRelocs(self: Object, sect_id: u8) []const macho.relocation_info {
    const sect = self.getSourceSection(sect_id);
    const start = self.section_relocs_lookup.items[sect_id];
    const len = sect.nreloc;
    return self.relocations.items[start..][0..len];
}

pub fn getSymbolName(self: Object, index: u32) []const u8 {
    const strtab = self.in_strtab.?;
    const sym = self.symtab[index];

    if (self.getSourceSymbol(index) == null) {
        assert(sym.n_strx == 0);
        return "";
    }

    const start = sym.n_strx;
    const len = self.strtab_lookup[index];

    return strtab[start..][0 .. len - 1 :0];
}

fn getSymbolAliases(self: Object, index: u32) Entry {
    const addr = self.source_address_lookup[index];
    var start = index;
    while (start > 0 and
        self.source_address_lookup[start - 1] == addr) : (start -= 1)
    {}
    const end: u32 = for (self.source_address_lookup[start..], start..) |saddr, i| {
        if (saddr != addr) break @as(u32, @intCast(i));
    } else @as(u32, @intCast(self.source_address_lookup.len));
    return .{ .start = start, .len = end - start };
}

pub fn getSymbolByAddress(self: Object, addr: u64, sect_hint: ?u8) u32 {
    // Find containing atom
    const Predicate = struct {
        addr: i64,

        pub fn predicate(pred: @This(), other: i64) bool {
            return if (other == -1) true else other > pred.addr;
        }
    };

    if (sect_hint) |sect_id| {
        if (self.source_section_index_lookup[sect_id].len > 0) {
            const lookup = self.source_section_index_lookup[sect_id];
            const target_sym_index = MachO.lsearch(
                i64,
                self.source_address_lookup[lookup.start..][0..lookup.len],
                Predicate{ .addr = @as(i64, @intCast(addr)) },
            );
            if (target_sym_index > 0) {
                // Hone in on the most senior alias of the target symbol.
                // See SymbolAtIndex.lessThan for more context.
                const aliases = self.getSymbolAliases(@intCast(lookup.start + target_sym_index - 1));
                return aliases.start;
            }
        }
        return self.getSectionAliasSymbolIndex(sect_id);
    }

    const target_sym_index = MachO.lsearch(i64, self.source_address_lookup, Predicate{
        .addr = @as(i64, @intCast(addr)),
    });
    assert(target_sym_index > 0);
    return @as(u32, @intCast(target_sym_index - 1));
}

pub fn getGlobal(self: Object, sym_index: u32) ?u32 {
    if (self.globals_lookup[sym_index] == -1) return null;
    return @as(u32, @intCast(self.globals_lookup[sym_index]));
}

pub fn getAtomIndexForSymbol(self: Object, sym_index: u32) ?Atom.Index {
    return self.atom_by_index_table[sym_index];
}

pub fn hasUnwindRecords(self: Object) bool {
    return self.unwind_info_sect_id != null;
}

pub fn getUnwindRecords(self: Object) []align(1) const macho.compact_unwind_entry {
    const sect_id = self.unwind_info_sect_id orelse return &[0]macho.compact_unwind_entry{};
    const sect = self.getSourceSection(sect_id);
    const data = self.getSectionContents(sect);
    const num_entries = @divExact(data.len, @sizeOf(macho.compact_unwind_entry));
    return @as([*]align(1) const macho.compact_unwind_entry, @ptrCast(data))[0..num_entries];
}

pub fn hasEhFrameRecords(self: Object) bool {
    return self.eh_frame_sect_id != null;
}

pub fn getEhFrameRecordsIterator(self: Object) eh_frame.Iterator {
    const sect_id = self.eh_frame_sect_id orelse return .{ .data = &[0]u8{} };
    const sect = self.getSourceSection(sect_id);
    const data = self.getSectionContents(sect);
    return .{ .data = data };
}

pub fn hasDataInCode(self: Object) bool {
    return self.data_in_code.items.len > 0;
}

const Object = @This();

const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const eh_frame = @import("eh_frame.zig");
const fs = std.fs;
const io = std.io;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const sort = std.sort;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Atom = @import("Atom.zig");
const DwarfInfo = @import("DwarfInfo.zig");
const LoadCommandIterator = macho.LoadCommandIterator;
const MachO = @import("../MachO.zig");
const Platform = @import("load_commands.zig").Platform;
const SymbolWithLoc = MachO.SymbolWithLoc;
const UnwindInfo = @import("UnwindInfo.zig");
