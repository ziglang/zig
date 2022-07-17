const Object = @This();

const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
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
const MachO = @import("../MachO.zig");
const MatchingSection = MachO.MatchingSection;
const SymbolWithLoc = MachO.SymbolWithLoc;

file: fs.File,
name: []const u8,
mtime: u64,

/// Data contents of the file. Includes sections, and data of load commands.
/// Excludes the backing memory for the header and load commands.
/// Initialized in `parse`.
contents: []const u8 = undefined,

file_offset: ?u32 = null,

header: macho.mach_header_64 = undefined,

load_commands: std.ArrayListUnmanaged(macho.LoadCommand) = .{},

segment_cmd_index: ?u16 = null,
text_section_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
build_version_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,

// __DWARF segment sections
dwarf_debug_info_index: ?u16 = null,
dwarf_debug_abbrev_index: ?u16 = null,
dwarf_debug_str_index: ?u16 = null,
dwarf_debug_line_index: ?u16 = null,
dwarf_debug_line_str_index: ?u16 = null,
dwarf_debug_ranges_index: ?u16 = null,

symtab: std.ArrayListUnmanaged(macho.nlist_64) = .{},
strtab: []const u8 = &.{},
data_in_code_entries: []const macho.data_in_code_entry = &.{},

sections_as_symbols: std.AutoHashMapUnmanaged(u16, u32) = .{},

/// List of atoms that map to the symbols parsed from this object file.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

/// Table of atoms belonging to this object file indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, *Atom) = .{},

pub fn deinit(self: *Object, gpa: Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(gpa);
    }
    self.load_commands.deinit(gpa);
    gpa.free(self.contents);
    self.sections_as_symbols.deinit(gpa);
    self.atom_by_index_table.deinit(gpa);

    for (self.managed_atoms.items) |atom| {
        atom.deinit(gpa);
        gpa.destroy(atom);
    }
    self.managed_atoms.deinit(gpa);

    gpa.free(self.name);
}

pub fn parse(self: *Object, allocator: Allocator, target: std.Target) !void {
    const file_stat = try self.file.stat();
    const file_size = math.cast(usize, file_stat.size) orelse return error.Overflow;
    self.contents = try self.file.readToEndAlloc(allocator, file_size);

    var stream = std.io.fixedBufferStream(self.contents);
    const reader = stream.reader();

    const file_offset = self.file_offset orelse 0;
    if (file_offset > 0) {
        try reader.context.seekTo(file_offset);
    }

    self.header = try reader.readStruct(macho.mach_header_64);
    if (self.header.filetype != macho.MH_OBJECT) {
        log.debug("invalid filetype: expected 0x{x}, found 0x{x}", .{
            macho.MH_OBJECT,
            self.header.filetype,
        });
        return error.NotObject;
    }

    const this_arch: std.Target.Cpu.Arch = switch (self.header.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |value| {
            log.err("unsupported cpu architecture 0x{x}", .{value});
            return error.UnsupportedCpuArchitecture;
        },
    };
    if (this_arch != target.cpu.arch) {
        log.err("mismatched cpu architecture: expected {s}, found {s}", .{ target.cpu.arch, this_arch });
        return error.MismatchedCpuArchitecture;
    }

    try self.load_commands.ensureUnusedCapacity(allocator, self.header.ncmds);

    var i: u16 = 0;
    while (i < self.header.ncmds) : (i += 1) {
        var cmd = try macho.LoadCommand.read(allocator, reader);
        switch (cmd.cmd()) {
            .SEGMENT_64 => {
                self.segment_cmd_index = i;
                var seg = cmd.segment;
                for (seg.sections.items) |*sect, j| {
                    const index = @intCast(u16, j);
                    const segname = sect.segName();
                    const sectname = sect.sectName();
                    if (mem.eql(u8, segname, "__DWARF")) {
                        if (mem.eql(u8, sectname, "__debug_info")) {
                            self.dwarf_debug_info_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_abbrev")) {
                            self.dwarf_debug_abbrev_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_str")) {
                            self.dwarf_debug_str_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_line")) {
                            self.dwarf_debug_line_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_line_str")) {
                            self.dwarf_debug_line_str_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_ranges")) {
                            self.dwarf_debug_ranges_index = index;
                        }
                    } else if (mem.eql(u8, segname, "__TEXT")) {
                        if (mem.eql(u8, sectname, "__text")) {
                            self.text_section_index = index;
                        }
                    }

                    sect.offset += file_offset;
                    if (sect.reloff > 0) {
                        sect.reloff += file_offset;
                    }
                }

                seg.inner.fileoff += file_offset;
            },
            .SYMTAB => {
                self.symtab_cmd_index = i;
                cmd.symtab.symoff += file_offset;
                cmd.symtab.stroff += file_offset;
            },
            .DYSYMTAB => {
                self.dysymtab_cmd_index = i;
            },
            .BUILD_VERSION => {
                self.build_version_cmd_index = i;
            },
            .DATA_IN_CODE => {
                self.data_in_code_cmd_index = i;
                cmd.linkedit_data.dataoff += file_offset;
            },
            else => {
                log.debug("Unknown load command detected: 0x{x}.", .{cmd.cmd()});
            },
        }
        self.load_commands.appendAssumeCapacity(cmd);
    }

    try self.parseSymtab(allocator);
    self.parseDataInCode();
}

const Context = struct {
    symtab: []const macho.nlist_64,
    strtab: []const u8,
};

const SymbolAtIndex = struct {
    index: u32,

    fn getSymbol(self: SymbolAtIndex, ctx: Context) macho.nlist_64 {
        return ctx.symtab[self.index];
    }

    fn getSymbolName(self: SymbolAtIndex, ctx: Context) []const u8 {
        const sym = self.getSymbol(ctx);
        assert(sym.n_strx < ctx.strtab.len);
        return mem.sliceTo(@ptrCast([*:0]const u8, ctx.strtab.ptr + sym.n_strx), 0);
    }

    fn lessThan(ctx: Context, lhs_index: SymbolAtIndex, rhs_index: SymbolAtIndex) bool {
        // We sort by type: defined < undefined, and
        // afterwards by address in each group. Normally, dysymtab should
        // be enough to guarantee the sort, but turns out not every compiler
        // is kind enough to specify the symbols in the correct order.
        const lhs = lhs_index.getSymbol(ctx);
        const rhs = rhs_index.getSymbol(ctx);
        if (lhs.sect()) {
            if (rhs.sect()) {
                // Same group, sort by address.
                return lhs.n_value < rhs.n_value;
            } else {
                return true;
            }
        } else {
            return false;
        }
    }
};

fn filterSymbolsByAddress(
    indexes: []SymbolAtIndex,
    start_addr: u64,
    end_addr: u64,
    ctx: Context,
) []SymbolAtIndex {
    const Predicate = struct {
        addr: u64,
        ctx: Context,

        pub fn predicate(pred: @This(), index: SymbolAtIndex) bool {
            return index.getSymbol(pred.ctx).n_value >= pred.addr;
        }
    };

    const start = MachO.findFirst(SymbolAtIndex, indexes, 0, Predicate{
        .addr = start_addr,
        .ctx = ctx,
    });
    const end = MachO.findFirst(SymbolAtIndex, indexes, start, Predicate{
        .addr = end_addr,
        .ctx = ctx,
    });

    return indexes[start..end];
}

fn filterRelocs(
    relocs: []const macho.relocation_info,
    start_addr: u64,
    end_addr: u64,
) []const macho.relocation_info {
    const Predicate = struct {
        addr: u64,

        pub fn predicate(self: @This(), rel: macho.relocation_info) bool {
            return rel.r_address < self.addr;
        }
    };

    const start = MachO.findFirst(macho.relocation_info, relocs, 0, Predicate{ .addr = end_addr });
    const end = MachO.findFirst(macho.relocation_info, relocs, start, Predicate{ .addr = start_addr });

    return relocs[start..end];
}

fn filterDice(
    dices: []const macho.data_in_code_entry,
    start_addr: u64,
    end_addr: u64,
) []const macho.data_in_code_entry {
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

/// Splits object into atoms assuming one-shot linking mode.
pub fn splitIntoAtomsOneShot(
    self: *Object,
    macho_file: *MachO,
    object_id: u32,
    gc_roots: ?*std.AutoHashMap(*Atom, void),
) !void {
    assert(macho_file.mode == .one_shot);

    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.allocator;
    const seg = self.load_commands.items[self.segment_cmd_index.?].segment;

    log.debug("splitting object({d}, {s}) into atoms: one-shot mode", .{ object_id, self.name });

    // You would expect that the symbol table is at least pre-sorted based on symbol's type:
    // local < extern defined < undefined. Unfortunately, this is not guaranteed! For instance,
    // the GO compiler does not necessarily respect that therefore we sort immediately by type
    // and address within.
    const context = Context{
        .symtab = self.getSourceSymtab(),
        .strtab = self.strtab,
    };
    var sorted_all_syms = try std.ArrayList(SymbolAtIndex).initCapacity(gpa, context.symtab.len);
    defer sorted_all_syms.deinit();

    for (context.symtab) |_, index| {
        sorted_all_syms.appendAssumeCapacity(.{ .index = @intCast(u32, index) });
    }

    sort.sort(SymbolAtIndex, sorted_all_syms.items, context, SymbolAtIndex.lessThan);

    // Well, shit, sometimes compilers skip the dysymtab load command altogether, meaning we
    // have to infer the start of undef section in the symtab ourselves.
    const iundefsym = if (self.dysymtab_cmd_index) |cmd_index| blk: {
        const dysymtab = self.load_commands.items[cmd_index].dysymtab;
        break :blk dysymtab.iundefsym;
    } else blk: {
        var iundefsym: usize = sorted_all_syms.items.len;
        while (iundefsym > 0) : (iundefsym -= 1) {
            const sym = sorted_all_syms.items[iundefsym - 1].getSymbol(context);
            if (sym.sect()) break;
        }
        break :blk iundefsym;
    };

    // We only care about defined symbols, so filter every other out.
    const sorted_syms = sorted_all_syms.items[0..iundefsym];
    const dead_strip = macho_file.base.options.gc_sections orelse false;
    const subsections_via_symbols = self.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0 and
        (macho_file.base.options.optimize_mode != .Debug or dead_strip);
    // const subsections_via_symbols = self.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0;

    for (seg.sections.items) |sect, id| {
        const sect_id = @intCast(u8, id);
        log.debug("splitting section '{s},{s}' into atoms", .{ sect.segName(), sect.sectName() });

        // Get matching segment/section in the final artifact.
        const match = (try macho_file.getMatchingSection(sect)) orelse {
            log.debug("  unhandled section", .{});
            continue;
        };

        log.debug("  output sect({d}, '{s},{s}')", .{
            macho_file.getSectionOrdinal(match),
            macho_file.getSection(match).segName(),
            macho_file.getSection(match).sectName(),
        });

        const arch = macho_file.base.options.target.cpu.arch;
        const is_zerofill = blk: {
            const section_type = sect.type_();
            break :blk section_type == macho.S_ZEROFILL or section_type == macho.S_THREAD_LOCAL_ZEROFILL;
        };

        // Read section's code
        const code: ?[]const u8 = if (!is_zerofill) try self.getSectionContents(sect_id) else null;

        // Read section's list of relocations
        const raw_relocs = self.contents[sect.reloff..][0 .. sect.nreloc * @sizeOf(macho.relocation_info)];
        const relocs = mem.bytesAsSlice(
            macho.relocation_info,
            @alignCast(@alignOf(macho.relocation_info), raw_relocs),
        );

        // Symbols within this section only.
        const filtered_syms = filterSymbolsByAddress(
            sorted_syms,
            sect.addr,
            sect.addr + sect.size,
            context,
        );

        macho_file.has_dices = macho_file.has_dices or blk: {
            if (self.text_section_index) |index| {
                if (index != id) break :blk false;
                if (self.data_in_code_entries.len == 0) break :blk false;
                break :blk true;
            }
            break :blk false;
        };

        if (subsections_via_symbols and filtered_syms.len > 0) {
            // If the first nlist does not match the start of the section,
            // then we need to encapsulate the memory range [section start, first symbol)
            // as a temporary symbol and insert the matching Atom.
            const first_sym = filtered_syms[0].getSymbol(context);
            if (first_sym.n_value > sect.addr) {
                const sym_index = self.sections_as_symbols.get(sect_id) orelse blk: {
                    const sym_index = @intCast(u32, self.symtab.items.len);
                    try self.symtab.append(gpa, .{
                        .n_strx = 0,
                        .n_type = macho.N_SECT,
                        .n_sect = macho_file.getSectionOrdinal(match),
                        .n_desc = 0,
                        .n_value = sect.addr,
                    });
                    try self.sections_as_symbols.putNoClobber(gpa, sect_id, sym_index);
                    break :blk sym_index;
                };
                const atom_size = first_sym.n_value - sect.addr;
                const atom_code: ?[]const u8 = if (code) |cc| blk: {
                    const size = math.cast(usize, atom_size) orelse return error.Overflow;
                    break :blk cc[0..size];
                } else null;
                const atom = try self.createAtomFromSubsection(
                    macho_file,
                    object_id,
                    sym_index,
                    atom_size,
                    sect.@"align",
                    atom_code,
                    relocs,
                    &.{},
                    match,
                    sect,
                    gc_roots,
                );
                try macho_file.addAtomToSection(atom, match);
            }

            var next_sym_count: usize = 0;
            while (next_sym_count < filtered_syms.len) {
                const next_sym = filtered_syms[next_sym_count].getSymbol(context);
                const addr = next_sym.n_value;
                const atom_syms = filterSymbolsByAddress(
                    filtered_syms[next_sym_count..],
                    addr,
                    addr + 1,
                    context,
                );
                next_sym_count += atom_syms.len;

                assert(atom_syms.len > 0);
                const sym_index = atom_syms[0].index;
                const atom_size = blk: {
                    const end_addr = if (next_sym_count < filtered_syms.len)
                        filtered_syms[next_sym_count].getSymbol(context).n_value
                    else
                        sect.addr + sect.size;
                    break :blk end_addr - addr;
                };
                const atom_code: ?[]const u8 = if (code) |cc| blk: {
                    const start = math.cast(usize, addr - sect.addr) orelse return error.Overflow;
                    const size = math.cast(usize, atom_size) orelse return error.Overflow;
                    break :blk cc[start..][0..size];
                } else null;
                const atom_align = if (addr > 0)
                    math.min(@ctz(u64, addr), sect.@"align")
                else
                    sect.@"align";
                const atom = try self.createAtomFromSubsection(
                    macho_file,
                    object_id,
                    sym_index,
                    atom_size,
                    atom_align,
                    atom_code,
                    relocs,
                    atom_syms[1..],
                    match,
                    sect,
                    gc_roots,
                );

                if (arch == .x86_64 and addr == sect.addr) {
                    // In x86_64 relocs, it can so happen that the compiler refers to the same
                    // atom by both the actual assigned symbol and the start of the section. In this
                    // case, we need to link the two together so add an alias.
                    const alias = self.sections_as_symbols.get(sect_id) orelse blk: {
                        const alias = @intCast(u32, self.symtab.items.len);
                        try self.symtab.append(gpa, .{
                            .n_strx = 0,
                            .n_type = macho.N_SECT,
                            .n_sect = macho_file.getSectionOrdinal(match),
                            .n_desc = 0,
                            .n_value = addr,
                        });
                        try self.sections_as_symbols.putNoClobber(gpa, sect_id, alias);
                        break :blk alias;
                    };
                    try atom.contained.append(gpa, .{
                        .sym_index = alias,
                        .offset = 0,
                    });
                    try self.atom_by_index_table.put(gpa, alias, atom);
                }

                try macho_file.addAtomToSection(atom, match);
            }
        } else {
            // If there is no symbol to refer to this atom, we create
            // a temp one, unless we already did that when working out the relocations
            // of other atoms.
            const sym_index = self.sections_as_symbols.get(sect_id) orelse blk: {
                const sym_index = @intCast(u32, self.symtab.items.len);
                try self.symtab.append(gpa, .{
                    .n_strx = 0,
                    .n_type = macho.N_SECT,
                    .n_sect = macho_file.getSectionOrdinal(match),
                    .n_desc = 0,
                    .n_value = sect.addr,
                });
                try self.sections_as_symbols.putNoClobber(gpa, sect_id, sym_index);
                break :blk sym_index;
            };
            const atom = try self.createAtomFromSubsection(
                macho_file,
                object_id,
                sym_index,
                sect.size,
                sect.@"align",
                code,
                relocs,
                filtered_syms,
                match,
                sect,
                gc_roots,
            );
            try macho_file.addAtomToSection(atom, match);
        }
    }
}

fn createAtomFromSubsection(
    self: *Object,
    macho_file: *MachO,
    object_id: u32,
    sym_index: u32,
    size: u64,
    alignment: u32,
    code: ?[]const u8,
    relocs: []const macho.relocation_info,
    indexes: []const SymbolAtIndex,
    match: MatchingSection,
    sect: macho.section_64,
    gc_roots: ?*std.AutoHashMap(*Atom, void),
) !*Atom {
    const gpa = macho_file.base.allocator;
    const sym = self.symtab.items[sym_index];
    const atom = try MachO.createEmptyAtom(gpa, sym_index, size, alignment);
    atom.file = object_id;
    self.symtab.items[sym_index].n_sect = macho_file.getSectionOrdinal(match);

    log.debug("creating ATOM(%{d}, '{s}') in sect({d}, '{s},{s}') in object({d})", .{
        sym_index,
        self.getString(sym.n_strx),
        macho_file.getSectionOrdinal(match),
        macho_file.getSection(match).segName(),
        macho_file.getSection(match).sectName(),
        object_id,
    });

    try self.atom_by_index_table.putNoClobber(gpa, sym_index, atom);
    try self.managed_atoms.append(gpa, atom);

    if (code) |cc| {
        assert(size == cc.len);
        mem.copy(u8, atom.code.items, cc);
    }

    const base_offset = sym.n_value - sect.addr;
    const filtered_relocs = filterRelocs(relocs, base_offset, base_offset + size);
    try atom.parseRelocs(filtered_relocs, .{
        .macho_file = macho_file,
        .base_addr = sect.addr,
        .base_offset = @intCast(i32, base_offset),
    });

    if (macho_file.has_dices) {
        const dices = filterDice(self.data_in_code_entries, sym.n_value, sym.n_value + size);
        try atom.dices.ensureTotalCapacity(gpa, dices.len);

        for (dices) |dice| {
            atom.dices.appendAssumeCapacity(.{
                .offset = dice.offset - (math.cast(u32, sym.n_value) orelse return error.Overflow),
                .length = dice.length,
                .kind = dice.kind,
            });
        }
    }

    // Since this is atom gets a helper local temporary symbol that didn't exist
    // in the object file which encompasses the entire section, we need traverse
    // the filtered symbols and note which symbol is contained within so that
    // we can properly allocate addresses down the line.
    // While we're at it, we need to update segment,section mapping of each symbol too.
    try atom.contained.ensureTotalCapacity(gpa, indexes.len + 1);
    atom.contained.appendAssumeCapacity(.{
        .sym_index = sym_index,
        .offset = 0,
    });

    for (indexes) |inner_sym_index| {
        const inner_sym = &self.symtab.items[inner_sym_index.index];
        inner_sym.n_sect = macho_file.getSectionOrdinal(match);
        atom.contained.appendAssumeCapacity(.{
            .sym_index = inner_sym_index.index,
            .offset = inner_sym.n_value - sym.n_value,
        });

        try self.atom_by_index_table.putNoClobber(gpa, inner_sym_index.index, atom);
    }

    if (gc_roots) |gcr| {
        const is_gc_root = blk: {
            if (sect.isDontDeadStrip()) break :blk true;
            if (sect.isDontDeadStripIfReferencesLive()) {
                // TODO if isDontDeadStripIfReferencesLive we should analyse the edges
                // before making it a GC root
                break :blk true;
            }
            if (mem.eql(u8, "__StaticInit", sect.sectName())) break :blk true;
            switch (sect.type_()) {
                macho.S_MOD_INIT_FUNC_POINTERS,
                macho.S_MOD_TERM_FUNC_POINTERS,
                => break :blk true,
                else => break :blk false,
            }
        };
        if (is_gc_root) {
            try gcr.putNoClobber(atom, {});
        }
    }

    return atom;
}

fn parseSymtab(self: *Object, allocator: Allocator) !void {
    const index = self.symtab_cmd_index orelse return;
    const symtab = self.load_commands.items[index].symtab;
    try self.symtab.appendSlice(allocator, self.getSourceSymtab());
    self.strtab = self.contents[symtab.stroff..][0..symtab.strsize];
}

pub fn getSourceSymtab(self: Object) []const macho.nlist_64 {
    const index = self.symtab_cmd_index orelse return &[0]macho.nlist_64{};
    const symtab = self.load_commands.items[index].symtab;
    const symtab_size = @sizeOf(macho.nlist_64) * symtab.nsyms;
    const raw_symtab = self.contents[symtab.symoff..][0..symtab_size];
    return mem.bytesAsSlice(
        macho.nlist_64,
        @alignCast(@alignOf(macho.nlist_64), raw_symtab),
    );
}

fn parseDataInCode(self: *Object) void {
    const index = self.data_in_code_cmd_index orelse return;
    const data_in_code = self.load_commands.items[index].linkedit_data;
    const raw_dice = self.contents[data_in_code.dataoff..][0..data_in_code.datasize];
    self.data_in_code_entries = mem.bytesAsSlice(
        macho.data_in_code_entry,
        @alignCast(@alignOf(macho.data_in_code_entry), raw_dice),
    );
}

pub fn getSectionContents(self: Object, sect_id: u16) error{Overflow}![]const u8 {
    const sect = self.getSection(sect_id);
    const size = math.cast(usize, sect.size) orelse return error.Overflow;
    log.debug("getting {s},{s} data at 0x{x} - 0x{x}", .{
        sect.segName(),
        sect.sectName(),
        sect.offset,
        sect.offset + sect.size,
    });
    return self.contents[sect.offset..][0..size];
}

pub fn getString(self: Object, off: u32) []const u8 {
    assert(off < self.strtab.len);
    return mem.sliceTo(@ptrCast([*:0]const u8, self.strtab.ptr + off), 0);
}

pub fn getSection(self: Object, n_sect: u16) macho.section_64 {
    const seg = self.load_commands.items[self.segment_cmd_index.?].segment;
    assert(n_sect < seg.sections.items.len);
    return seg.sections.items[n_sect];
}
