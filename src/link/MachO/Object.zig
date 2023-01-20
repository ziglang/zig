//! Represents an input relocatable Object file.
//! Each Object is fully loaded into memory for easier
//! access into different data within.

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
const Atom = @import("ZldAtom.zig");
const AtomIndex = @import("zld.zig").AtomIndex;
const DwarfInfo = @import("DwarfInfo.zig");
const LoadCommandIterator = macho.LoadCommandIterator;
const Zld = @import("zld.zig").Zld;
const SymbolWithLoc = @import("zld.zig").SymbolWithLoc;

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
source_address_lookup: []i64 = undefined,
/// Can be undefined as set together with in_symtab.
source_section_index_lookup: []i64 = undefined,
/// Can be undefined as set together with in_symtab.
strtab_lookup: []u32 = undefined,
/// Can be undefined as set together with in_symtab.
atom_by_index_table: []AtomIndex = undefined,
/// Can be undefined as set together with in_symtab.
globals_lookup: []i64 = undefined,

atoms: std.ArrayListUnmanaged(AtomIndex) = .{},

pub fn deinit(self: *Object, gpa: Allocator) void {
    self.atoms.deinit(gpa);
    gpa.free(self.name);
    gpa.free(self.contents);
    if (self.in_symtab) |_| {
        gpa.free(self.source_symtab_lookup);
        gpa.free(self.source_address_lookup);
        gpa.free(self.source_section_index_lookup);
        gpa.free(self.strtab_lookup);
        gpa.free(self.symtab);
        gpa.free(self.atom_by_index_table);
        gpa.free(self.globals_lookup);
    }
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
            .SYMTAB => {
                const symtab = cmd.cast(macho.symtab_command).?;
                self.in_symtab = @ptrCast(
                    [*]const macho.nlist_64,
                    @alignCast(@alignOf(macho.nlist_64), &self.contents[symtab.symoff]),
                )[0..symtab.nsyms];
                self.in_strtab = self.contents[symtab.stroff..][0..symtab.strsize];

                const nsects = self.getSourceSections().len;

                self.symtab = try allocator.alloc(macho.nlist_64, self.in_symtab.?.len + nsects);
                self.source_symtab_lookup = try allocator.alloc(u32, self.in_symtab.?.len);
                self.strtab_lookup = try allocator.alloc(u32, self.in_symtab.?.len);
                self.globals_lookup = try allocator.alloc(i64, self.in_symtab.?.len);
                self.atom_by_index_table = try allocator.alloc(AtomIndex, self.in_symtab.?.len + nsects);
                // This is wasteful but we need to be able to lookup source symbol address after stripping and
                // allocating of sections.
                self.source_address_lookup = try allocator.alloc(i64, self.in_symtab.?.len);
                self.source_section_index_lookup = try allocator.alloc(i64, nsects);

                for (self.symtab) |*sym| {
                    sym.* = .{
                        .n_value = 0,
                        .n_sect = 0,
                        .n_desc = 0,
                        .n_strx = 0,
                        .n_type = 0,
                    };
                }

                mem.set(i64, self.globals_lookup, -1);
                mem.set(AtomIndex, self.atom_by_index_table, 0);
                mem.set(i64, self.source_section_index_lookup, -1);

                // You would expect that the symbol table is at least pre-sorted based on symbol's type:
                // local < extern defined < undefined. Unfortunately, this is not guaranteed! For instance,
                // the GO compiler does not necessarily respect that therefore we sort immediately by type
                // and address within.
                var sorted_all_syms = try std.ArrayList(SymbolAtIndex).initCapacity(allocator, self.in_symtab.?.len);
                defer sorted_all_syms.deinit();

                for (self.in_symtab.?) |_, index| {
                    sorted_all_syms.appendAssumeCapacity(.{ .index = @intCast(u32, index) });
                }

                // We sort by type: defined < undefined, and
                // afterwards by address in each group. Normally, dysymtab should
                // be enough to guarantee the sort, but turns out not every compiler
                // is kind enough to specify the symbols in the correct order.
                sort.sort(SymbolAtIndex, sorted_all_syms.items, self, SymbolAtIndex.lessThan);

                for (sorted_all_syms.items) |sym_id, i| {
                    const sym = sym_id.getSymbol(self);

                    if (sym.sect() and self.source_section_index_lookup[sym.n_sect - 1] == -1) {
                        self.source_section_index_lookup[sym.n_sect - 1] = @intCast(i64, i);
                    }

                    self.symtab[i] = sym;
                    self.source_symtab_lookup[i] = sym_id.index;
                    self.source_address_lookup[i] = if (sym.undf()) -1 else @intCast(i64, sym.n_value);

                    const sym_name_len = mem.sliceTo(@ptrCast([*:0]const u8, self.in_strtab.?.ptr + sym.n_strx), 0).len + 1;
                    self.strtab_lookup[i] = @intCast(u32, sym_name_len);
                }
            },
            else => {},
        }
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
        return mem.sliceTo(@ptrCast([*:0]const u8, ctx.in_strtab.?.ptr + off), 0);
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
                    if (lhs.ext() and rhs.ext()) {
                        if ((lhs.pext() or lhs.weakDef()) and (rhs.pext() or rhs.weakDef())) {
                            return false;
                        } else return rhs.pext() or rhs.weakDef();
                    } else {
                        const lhs_name = lhs_index.getSymbolName(ctx);
                        const lhs_temp = mem.startsWith(u8, lhs_name, "l") or mem.startsWith(u8, lhs_name, "L");
                        const rhs_name = rhs_index.getSymbolName(ctx);
                        const rhs_temp = mem.startsWith(u8, rhs_name, "l") or mem.startsWith(u8, rhs_name, "L");
                        if (lhs_temp and rhs_temp) {
                            return false;
                        } else return rhs_temp;
                    }
                } else return lhs.n_sect < rhs.n_sect;
            } else return lhs.n_value < rhs.n_value;
        } else if (lhs.undf() and rhs.undf()) {
            return false;
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

    const index = @import("zld.zig").lsearch(macho.nlist_64, symbols, FirstMatch{
        .n_sect = n_sect,
    });
    const len = @import("zld.zig").lsearch(macho.nlist_64, symbols[index..], FirstNonMatch{
        .n_sect = n_sect,
    });

    return .{ .index = @intCast(u32, index), .len = @intCast(u32, len) };
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

    const index = @import("zld.zig").lsearch(macho.nlist_64, symbols, Predicate{
        .addr = start_addr,
    });
    const len = @import("zld.zig").lsearch(macho.nlist_64, symbols[index..], Predicate{
        .addr = end_addr,
    });

    return .{ .index = @intCast(u32, index), .len = @intCast(u32, len) };
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

/// Splits input sections into Atoms.
/// If the Object was compiled with `MH_SUBSECTIONS_VIA_SYMBOLS`, splits section
/// into subsections where each subsection then represents an Atom.
pub fn splitIntoAtoms(self: *Object, zld: *Zld, object_id: u31) !void {
    const gpa = zld.gpa;

    log.debug("splitting object({d}, {s}) into atoms", .{ object_id, self.name });

    const sections = self.getSourceSections();
    for (sections) |sect, id| {
        if (sect.isDebug()) continue;
        const out_sect_id = (try zld.getOutputSection(sect)) orelse {
            log.debug("  unhandled section '{s},{s}'", .{ sect.segName(), sect.sectName() });
            continue;
        };
        if (sect.size == 0) continue;

        const sect_id = @intCast(u8, id);
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
        for (sections) |sect, id| {
            if (sect.isDebug()) continue;
            const out_sect_id = (try zld.getOutputSection(sect)) orelse continue;
            if (sect.size == 0) continue;

            const sect_id = @intCast(u8, id);
            const sym_index = self.getSectionAliasSymbolIndex(sect_id);
            const atom_index = try self.createAtomFromSubsection(
                zld,
                object_id,
                sym_index,
                0,
                0,
                sect.size,
                sect.@"align",
                out_sect_id,
            );
            zld.addAtomToSection(atom_index);
        }
        return;
    }

    // Well, shit, sometimes compilers skip the dysymtab load command altogether, meaning we
    // have to infer the start of undef section in the symtab ourselves.
    const iundefsym = blk: {
        const dysymtab = self.parseDysymtab() orelse {
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

    for (sections) |sect, id| {
        sorted_sections[id] = .{ .header = sect, .id = @intCast(u8, id) };
    }

    std.sort.sort(SortedSection, sorted_sections, {}, sectionLessThanByAddress);

    var sect_sym_index: u32 = 0;
    for (sorted_sections) |section| {
        const sect = section.header;
        if (sect.isDebug()) continue;

        const sect_id = section.id;
        log.debug("splitting section '{s},{s}' into atoms", .{ sect.segName(), sect.sectName() });

        // Get output segment/section in the final artifact.
        const out_sect_id = (try zld.getOutputSection(sect)) orelse continue;

        log.debug("  output sect({d}, '{s},{s}')", .{
            out_sect_id + 1,
            zld.sections.items(.header)[out_sect_id].segName(),
            zld.sections.items(.header)[out_sect_id].sectName(),
        });

        const cpu_arch = zld.options.target.cpu.arch;
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
                    zld,
                    object_id,
                    sym_index,
                    0,
                    0,
                    atom_size,
                    sect.@"align",
                    out_sect_id,
                );
                zld.addAtomToSection(atom_index);
            }

            var next_sym_index = sect_start_index;
            while (next_sym_index < sect_start_index + sect_loc.len) {
                const next_sym = symtab[next_sym_index];
                const addr = next_sym.n_value;
                const atom_loc = filterSymbolsByAddress(symtab[next_sym_index..], addr, addr + 1);
                assert(atom_loc.len > 0);
                const atom_sym_index = atom_loc.index + next_sym_index;
                const nsyms_trailing = atom_loc.len - 1;
                next_sym_index += atom_loc.len;

                // TODO: We want to bubble up the first externally defined symbol here.
                const atom_size = if (next_sym_index < sect_start_index + sect_loc.len)
                    symtab[next_sym_index].n_value - addr
                else
                    sect.addr + sect.size - addr;

                const atom_align = if (addr > 0)
                    math.min(@ctz(addr), sect.@"align")
                else
                    sect.@"align";

                const atom_index = try self.createAtomFromSubsection(
                    zld,
                    object_id,
                    atom_sym_index,
                    atom_sym_index + 1,
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

                zld.addAtomToSection(atom_index);
            }
        } else {
            const alias_index = self.getSectionAliasSymbolIndex(sect_id);
            const atom_index = try self.createAtomFromSubsection(
                zld,
                object_id,
                alias_index,
                sect_start_index,
                sect_loc.len,
                sect.size,
                sect.@"align",
                out_sect_id,
            );
            zld.addAtomToSection(atom_index);
        }
    }
}

fn createAtomFromSubsection(
    self: *Object,
    zld: *Zld,
    object_id: u31,
    sym_index: u32,
    inner_sym_index: u32,
    inner_nsyms_trailing: u32,
    size: u64,
    alignment: u32,
    out_sect_id: u8,
) !AtomIndex {
    const gpa = zld.gpa;
    const atom_index = try zld.createEmptyAtom(sym_index, size, alignment);
    const atom = zld.getAtomPtr(atom_index);
    atom.inner_sym_index = inner_sym_index;
    atom.inner_nsyms_trailing = inner_nsyms_trailing;
    atom.file = object_id;
    self.symtab[sym_index].n_sect = out_sect_id + 1;

    log.debug("creating ATOM(%{d}, '{s}') in sect({d}, '{s},{s}') in object({d})", .{
        sym_index,
        self.getSymbolName(sym_index),
        out_sect_id + 1,
        zld.sections.items(.header)[out_sect_id].segName(),
        zld.sections.items(.header)[out_sect_id].sectName(),
        object_id,
    });

    try self.atoms.append(gpa, atom_index);
    self.atom_by_index_table[sym_index] = atom_index;

    var it = Atom.getInnerSymbolsIterator(zld, atom_index);
    while (it.next()) |sym_loc| {
        const inner = zld.getSymbolPtr(sym_loc);
        inner.n_sect = out_sect_id + 1;
        self.atom_by_index_table[sym_loc.sym_index] = atom_index;
    }

    return atom_index;
}

pub fn getSourceSymbol(self: Object, index: u32) ?macho.nlist_64 {
    const symtab = self.in_symtab.?;
    if (index >= symtab.len) return null;
    const mapped_index = self.source_symtab_lookup[index];
    return symtab[mapped_index];
}

/// Expects an arena allocator.
/// Caller owns memory.
pub fn createReverseSymbolLookup(self: Object, arena: Allocator) ![]u32 {
    const symtab = self.in_symtab orelse return &[0]u32{};
    const lookup = try arena.alloc(u32, symtab.len);
    for (self.source_symtab_lookup) |source_id, id| {
        lookup[source_id] = @intCast(u32, id);
    }
    return lookup;
}

pub fn getSourceSection(self: Object, index: u16) macho.section_64 {
    const sections = self.getSourceSections();
    assert(index < sections.len);
    return sections[index];
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

pub fn parseDataInCode(self: Object) ?[]const macho.data_in_code_entry {
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
                    [*]const macho.data_in_code_entry,
                    @alignCast(@alignOf(macho.data_in_code_entry), &self.contents[dice.dataoff]),
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

pub fn getSectionContents(self: Object, sect: macho.section_64) []const u8 {
    const size = @intCast(usize, sect.size);
    return self.contents[sect.offset..][0..size];
}

pub fn getSectionAliasSymbolIndex(self: Object, sect_id: u8) u32 {
    const start = @intCast(u32, self.in_symtab.?.len);
    return start + sect_id;
}

pub fn getSectionAliasSymbol(self: *Object, sect_id: u8) macho.nlist_64 {
    return self.symtab[self.getSectionAliasSymbolIndex(sect_id)];
}

pub fn getSectionAliasSymbolPtr(self: *Object, sect_id: u8) *macho.nlist_64 {
    return &self.symtab[self.getSectionAliasSymbolIndex(sect_id)];
}

pub fn getRelocs(self: Object, sect: macho.section_64) []align(1) const macho.relocation_info {
    if (sect.nreloc == 0) return &[0]macho.relocation_info{};
    return @ptrCast([*]align(1) const macho.relocation_info, self.contents.ptr + sect.reloff)[0..sect.nreloc];
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

pub fn getAtomIndexForSymbol(self: Object, sym_index: u32) ?AtomIndex {
    const atom_index = self.atom_by_index_table[sym_index];
    if (atom_index == 0) return null;
    return atom_index;
}
