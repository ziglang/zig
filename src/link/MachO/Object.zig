const Object = @This();

const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const dwarf = std.dwarf;
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
const LoadCommandIterator = macho.LoadCommandIterator;
const MachO = @import("../MachO.zig");
const SymbolWithLoc = MachO.SymbolWithLoc;

name: []const u8,
mtime: u64,
contents: []align(@alignOf(u64)) const u8,

header: macho.mach_header_64 = undefined,

/// Symtab and strtab might not exist for empty object files so we use an optional
/// to signal this.
in_symtab: ?[]align(1) const macho.nlist_64 = null,
in_strtab: ?[]const u8 = null,

symtab: std.ArrayListUnmanaged(macho.nlist_64) = .{},
sections: std.ArrayListUnmanaged(macho.section_64) = .{},

sections_as_symbols: std.AutoHashMapUnmanaged(u16, u32) = .{},

/// List of atoms that map to the symbols parsed from this object file.
managed_atoms: std.ArrayListUnmanaged(*Atom) = .{},

/// Table of atoms belonging to this object file indexed by the symbol index.
atom_by_index_table: std.AutoHashMapUnmanaged(u32, *Atom) = .{},

pub fn deinit(self: *Object, gpa: Allocator) void {
    self.symtab.deinit(gpa);
    self.sections.deinit(gpa);
    self.sections_as_symbols.deinit(gpa);
    self.atom_by_index_table.deinit(gpa);

    for (self.managed_atoms.items) |atom| {
        atom.deinit(gpa);
        gpa.destroy(atom);
    }
    self.managed_atoms.deinit(gpa);

    gpa.free(self.name);
    gpa.free(self.contents);
}

pub fn parse(self: *Object, allocator: Allocator, cpu_arch: std.Target.Cpu.Arch) !void {
    var stream = std.io.fixedBufferStream(self.contents);
    const reader = stream.reader();

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
    if (this_arch != cpu_arch) {
        log.err("mismatched cpu architecture: expected {s}, found {s}", .{
            @tagName(cpu_arch),
            @tagName(this_arch),
        });
        return error.MismatchedCpuArchitecture;
    }

    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .SEGMENT_64 => {
                const segment = cmd.cast(macho.segment_command_64).?;
                try self.sections.ensureUnusedCapacity(allocator, segment.nsects);
                for (cmd.getSections()) |sect| {
                    self.sections.appendAssumeCapacity(sect);
                }
            },
            .SYMTAB => {
                const symtab = cmd.cast(macho.symtab_command).?;
                // Sadly, SYMTAB may be at an unaligned offset within the object file.
                self.in_symtab = @ptrCast(
                    [*]align(1) const macho.nlist_64,
                    self.contents.ptr + symtab.symoff,
                )[0..symtab.nsyms];
                self.in_strtab = self.contents[symtab.stroff..][0..symtab.strsize];
                try self.symtab.appendUnalignedSlice(allocator, self.in_symtab.?);
            },
            else => {},
        }
    }
}

const Context = struct {
    object: *const Object,
};

const SymbolAtIndex = struct {
    index: u32,

    fn getSymbol(self: SymbolAtIndex, ctx: Context) macho.nlist_64 {
        return ctx.object.getSourceSymbol(self.index).?;
    }

    fn getSymbolName(self: SymbolAtIndex, ctx: Context) []const u8 {
        const sym = self.getSymbol(ctx);
        return ctx.object.getString(sym.n_strx);
    }

    /// Returns whether lhs is less than rhs by allocated address in object file.
    /// Undefined symbols are pushed to the back (always evaluate to true).
    fn lessThan(ctx: Context, lhs_index: SymbolAtIndex, rhs_index: SymbolAtIndex) bool {
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

    /// Returns whether lhs is less senior than rhs. The rules are:
    /// 1. ext
    /// 2. weak
    /// 3. local
    /// 4. temp (local starting with `l` prefix).
    fn lessThanBySeniority(ctx: Context, lhs_index: SymbolAtIndex, rhs_index: SymbolAtIndex) bool {
        const lhs = lhs_index.getSymbol(ctx);
        const rhs = rhs_index.getSymbol(ctx);
        if (!rhs.ext()) {
            const lhs_name = lhs_index.getSymbolName(ctx);
            return mem.startsWith(u8, lhs_name, "l") or mem.startsWith(u8, lhs_name, "L");
        } else if (rhs.pext() or rhs.weakDef()) {
            return !lhs.ext();
        } else {
            return false;
        }
    }

    /// Like lessThanBySeniority but negated.
    fn greaterThanBySeniority(ctx: Context, lhs_index: SymbolAtIndex, rhs_index: SymbolAtIndex) bool {
        return !lessThanBySeniority(ctx, lhs_index, rhs_index);
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
    relocs: []align(1) const macho.relocation_info,
    start_addr: u64,
    end_addr: u64,
) []align(1) const macho.relocation_info {
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

pub fn scanInputSections(self: Object, macho_file: *MachO) !void {
    for (self.sections.items) |sect| {
        const sect_id = (try macho_file.getOutputSection(sect)) orelse {
            log.debug("  unhandled section", .{});
            continue;
        };
        const output = macho_file.sections.items(.header)[sect_id];
        log.debug("mapping '{s},{s}' into output sect({d}, '{s},{s}')", .{
            sect.segName(),
            sect.sectName(),
            sect_id + 1,
            output.segName(),
            output.sectName(),
        });
    }
}

/// Splits object into atoms assuming one-shot linking mode.
pub fn splitIntoAtoms(self: *Object, macho_file: *MachO, object_id: u32) !void {
    assert(macho_file.mode == .one_shot);

    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.allocator;

    log.debug("splitting object({d}, {s}) into atoms: one-shot mode", .{ object_id, self.name });

    const in_symtab = self.in_symtab orelse {
        for (self.sections.items) |sect, id| {
            if (sect.isDebug()) continue;
            const out_sect_id = (try macho_file.getOutputSection(sect)) orelse {
                log.debug("  unhandled section", .{});
                continue;
            };
            if (sect.size == 0) continue;

            const sect_id = @intCast(u8, id);
            const sym_index = self.sections_as_symbols.get(sect_id) orelse blk: {
                const sym_index = @intCast(u32, self.symtab.items.len);
                try self.symtab.append(gpa, .{
                    .n_strx = 0,
                    .n_type = macho.N_SECT,
                    .n_sect = out_sect_id + 1,
                    .n_desc = 0,
                    .n_value = sect.addr,
                });
                try self.sections_as_symbols.putNoClobber(gpa, sect_id, sym_index);
                break :blk sym_index;
            };
            const code: ?[]const u8 = if (!sect.isZerofill()) try self.getSectionContents(sect) else null;
            const relocs = @ptrCast(
                [*]align(1) const macho.relocation_info,
                self.contents.ptr + sect.reloff,
            )[0..sect.nreloc];
            const atom = try self.createAtomFromSubsection(
                macho_file,
                object_id,
                sym_index,
                sect.size,
                sect.@"align",
                code,
                relocs,
                &.{},
                out_sect_id,
                sect,
            );
            try macho_file.addAtomToSection(atom);
        }
        return;
    };

    // You would expect that the symbol table is at least pre-sorted based on symbol's type:
    // local < extern defined < undefined. Unfortunately, this is not guaranteed! For instance,
    // the GO compiler does not necessarily respect that therefore we sort immediately by type
    // and address within.
    const context = Context{
        .object = self,
    };
    var sorted_all_syms = try std.ArrayList(SymbolAtIndex).initCapacity(gpa, in_symtab.len);
    defer sorted_all_syms.deinit();

    for (in_symtab) |_, index| {
        sorted_all_syms.appendAssumeCapacity(.{ .index = @intCast(u32, index) });
    }

    // We sort by type: defined < undefined, and
    // afterwards by address in each group. Normally, dysymtab should
    // be enough to guarantee the sort, but turns out not every compiler
    // is kind enough to specify the symbols in the correct order.
    sort.sort(SymbolAtIndex, sorted_all_syms.items, context, SymbolAtIndex.lessThan);

    // Well, shit, sometimes compilers skip the dysymtab load command altogether, meaning we
    // have to infer the start of undef section in the symtab ourselves.
    const iundefsym = blk: {
        const dysymtab = self.parseDysymtab() orelse {
            var iundefsym: usize = sorted_all_syms.items.len;
            while (iundefsym > 0) : (iundefsym -= 1) {
                const sym = sorted_all_syms.items[iundefsym - 1].getSymbol(context);
                if (sym.sect()) break;
            }
            break :blk iundefsym;
        };
        break :blk dysymtab.iundefsym;
    };

    // We only care about defined symbols, so filter every other out.
    const sorted_syms = sorted_all_syms.items[0..iundefsym];
    const subsections_via_symbols = self.header.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0;

    for (self.sections.items) |sect, id| {
        if (sect.isDebug()) continue;

        const sect_id = @intCast(u8, id);
        log.debug("splitting section '{s},{s}' into atoms", .{ sect.segName(), sect.sectName() });

        // Get matching segment/section in the final artifact.
        const out_sect_id = (try macho_file.getOutputSection(sect)) orelse {
            log.debug("  unhandled section", .{});
            continue;
        };

        log.debug("  output sect({d}, '{s},{s}')", .{
            out_sect_id + 1,
            macho_file.sections.items(.header)[out_sect_id].segName(),
            macho_file.sections.items(.header)[out_sect_id].sectName(),
        });

        const cpu_arch = macho_file.base.options.target.cpu.arch;

        // Read section's code
        const code: ?[]const u8 = if (!sect.isZerofill()) try self.getSectionContents(sect) else null;

        // Read section's list of relocations
        const relocs = @ptrCast(
            [*]align(1) const macho.relocation_info,
            self.contents.ptr + sect.reloff,
        )[0..sect.nreloc];

        // Symbols within this section only.
        const filtered_syms = filterSymbolsByAddress(
            sorted_syms,
            sect.addr,
            sect.addr + sect.size,
            context,
        );

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
                        .n_sect = out_sect_id + 1,
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
                    out_sect_id,
                    sect,
                );
                try macho_file.addAtomToSection(atom);
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

                // We want to bubble up the first externally defined symbol here.
                assert(atom_syms.len > 0);
                var sorted_atom_syms = std.ArrayList(SymbolAtIndex).init(gpa);
                defer sorted_atom_syms.deinit();
                try sorted_atom_syms.appendSlice(atom_syms);
                sort.sort(
                    SymbolAtIndex,
                    sorted_atom_syms.items,
                    context,
                    SymbolAtIndex.greaterThanBySeniority,
                );

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
                    math.min(@ctz(addr), sect.@"align")
                else
                    sect.@"align";
                const atom = try self.createAtomFromSubsection(
                    macho_file,
                    object_id,
                    sorted_atom_syms.items[0].index,
                    atom_size,
                    atom_align,
                    atom_code,
                    relocs,
                    sorted_atom_syms.items[1..],
                    out_sect_id,
                    sect,
                );

                if (cpu_arch == .x86_64 and addr == sect.addr) {
                    // In x86_64 relocs, it can so happen that the compiler refers to the same
                    // atom by both the actual assigned symbol and the start of the section. In this
                    // case, we need to link the two together so add an alias.
                    const alias = self.sections_as_symbols.get(sect_id) orelse blk: {
                        const alias = @intCast(u32, self.symtab.items.len);
                        try self.symtab.append(gpa, .{
                            .n_strx = 0,
                            .n_type = macho.N_SECT,
                            .n_sect = out_sect_id + 1,
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

                try macho_file.addAtomToSection(atom);
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
                    .n_sect = out_sect_id + 1,
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
                out_sect_id,
                sect,
            );
            try macho_file.addAtomToSection(atom);
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
    relocs: []align(1) const macho.relocation_info,
    indexes: []const SymbolAtIndex,
    out_sect_id: u8,
    sect: macho.section_64,
) !*Atom {
    const gpa = macho_file.base.allocator;
    const sym = self.symtab.items[sym_index];
    const atom = try MachO.createEmptyAtom(gpa, sym_index, size, alignment);
    atom.file = object_id;
    self.symtab.items[sym_index].n_sect = out_sect_id + 1;

    log.debug("creating ATOM(%{d}, '{s}') in sect({d}, '{s},{s}') in object({d})", .{
        sym_index,
        self.getString(sym.n_strx),
        out_sect_id + 1,
        macho_file.sections.items(.header)[out_sect_id].segName(),
        macho_file.sections.items(.header)[out_sect_id].sectName(),
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

    // Since this is atom gets a helper local temporary symbol that didn't exist
    // in the object file which encompasses the entire section, we need traverse
    // the filtered symbols and note which symbol is contained within so that
    // we can properly allocate addresses down the line.
    // While we're at it, we need to update segment,section mapping of each symbol too.
    try atom.contained.ensureTotalCapacity(gpa, indexes.len);
    for (indexes) |inner_sym_index| {
        const inner_sym = &self.symtab.items[inner_sym_index.index];
        inner_sym.n_sect = out_sect_id + 1;
        atom.contained.appendAssumeCapacity(.{
            .sym_index = inner_sym_index.index,
            .offset = inner_sym.n_value - sym.n_value,
        });

        try self.atom_by_index_table.putNoClobber(gpa, inner_sym_index.index, atom);
    }

    return atom;
}

pub fn getSourceSymbol(self: Object, index: u32) ?macho.nlist_64 {
    const symtab = self.in_symtab.?;
    if (index >= symtab.len) return null;
    return symtab[index];
}

pub fn getSourceSection(self: Object, index: u16) macho.section_64 {
    assert(index < self.sections.items.len);
    return self.sections.items[index];
}

pub fn parseDataInCode(self: Object) ?[]align(1) const macho.data_in_code_entry {
    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .DATA_IN_CODE => {
                const dice = cmd.cast(macho.linkedit_data_command).?;
                const ndice = @divExact(dice.datasize, @sizeOf(macho.data_in_code_entry));
                return @ptrCast(
                    [*]align(1) const macho.data_in_code_entry,
                    self.contents.ptr + dice.dataoff,
                )[0..ndice];
            },
            else => {},
        }
    } else return null;
}

fn parseDysymtab(self: Object) ?macho.dysymtab_command {
    var it = LoadCommandIterator{
        .ncmds = self.header.ncmds,
        .buffer = self.contents[@sizeOf(macho.mach_header_64)..][0..self.header.sizeofcmds],
    };
    while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .DYSYMTAB => {
                return cmd.cast(macho.dysymtab_command).?;
            },
            else => {},
        }
    } else return null;
}

pub fn parseDwarfInfo(self: Object) error{Overflow}!dwarf.DwarfInfo {
    var di = dwarf.DwarfInfo{
        .endian = .Little,
        .debug_info = &[0]u8{},
        .debug_abbrev = &[0]u8{},
        .debug_str = &[0]u8{},
        .debug_str_offsets = &[0]u8{},
        .debug_line = &[0]u8{},
        .debug_line_str = &[0]u8{},
        .debug_ranges = &[0]u8{},
        .debug_loclists = &[0]u8{},
        .debug_rnglists = &[0]u8{},
        .debug_addr = &[0]u8{},
        .debug_names = &[0]u8{},
        .debug_frame = &[0]u8{},
    };
    for (self.sections.items) |sect| {
        const segname = sect.segName();
        const sectname = sect.sectName();
        if (mem.eql(u8, segname, "__DWARF")) {
            if (mem.eql(u8, sectname, "__debug_info")) {
                di.debug_info = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_abbrev")) {
                di.debug_abbrev = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_str")) {
                di.debug_str = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_str_offsets")) {
                di.debug_str_offsets = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_line")) {
                di.debug_line = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_line_str")) {
                di.debug_line_str = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_ranges")) {
                di.debug_ranges = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_loclists")) {
                di.debug_loclists = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_rnglists")) {
                di.debug_rnglists = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_addr")) {
                di.debug_addr = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_names")) {
                di.debug_names = try self.getSectionContents(sect);
            } else if (mem.eql(u8, sectname, "__debug_frame")) {
                di.debug_frame = try self.getSectionContents(sect);
            }
        }
    }
    return di;
}

pub fn getSectionContents(self: Object, sect: macho.section_64) error{Overflow}![]const u8 {
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
    const strtab = self.in_strtab.?;
    assert(off < strtab.len);
    return mem.sliceTo(@ptrCast([*:0]const u8, strtab.ptr + off), 0);
}

pub fn getAtomForSymbol(self: Object, sym_index: u32) ?*Atom {
    return self.atom_by_index_table.get(sym_index);
}
