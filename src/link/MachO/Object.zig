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
const MachO = @import("../MachO.zig");

file: fs.File,
name: []const u8,

file_offset: ?u32 = null,

header: ?macho.mach_header_64 = null,

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
strtab: std.ArrayListUnmanaged(u8) = .{},
data_in_code_entries: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

// Debug info
debug_info: ?DebugInfo = null,
tu_name: ?[]const u8 = null,
tu_comp_dir: ?[]const u8 = null,
mtime: ?u64 = null,

contained_atoms: std.ArrayListUnmanaged(*Atom) = .{},
start_atoms: std.AutoHashMapUnmanaged(MachO.MatchingSection, *Atom) = .{},
end_atoms: std.AutoHashMapUnmanaged(MachO.MatchingSection, *Atom) = .{},
sections_as_symbols: std.AutoHashMapUnmanaged(u16, u32) = .{},

// TODO symbol mapping and its inverse can probably be simple arrays
// instead of hash maps.
symbol_mapping: std.AutoHashMapUnmanaged(u32, u32) = .{},
reverse_symbol_mapping: std.AutoHashMapUnmanaged(u32, u32) = .{},

analyzed: bool = false,

const DebugInfo = struct {
    inner: dwarf.DwarfInfo,
    debug_info: []u8,
    debug_abbrev: []u8,
    debug_str: []u8,
    debug_line: []u8,
    debug_line_str: []u8,
    debug_ranges: []u8,

    pub fn parseFromObject(allocator: Allocator, object: *const Object) !?DebugInfo {
        var debug_info = blk: {
            const index = object.dwarf_debug_info_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_abbrev = blk: {
            const index = object.dwarf_debug_abbrev_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_str = blk: {
            const index = object.dwarf_debug_str_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_line = blk: {
            const index = object.dwarf_debug_line_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_line_str = blk: {
            if (object.dwarf_debug_line_str_index) |ind| {
                break :blk try object.readSection(allocator, ind);
            }
            break :blk try allocator.alloc(u8, 0);
        };
        var debug_ranges = blk: {
            if (object.dwarf_debug_ranges_index) |ind| {
                break :blk try object.readSection(allocator, ind);
            }
            break :blk try allocator.alloc(u8, 0);
        };

        var inner: dwarf.DwarfInfo = .{
            .endian = .Little,
            .debug_info = debug_info,
            .debug_abbrev = debug_abbrev,
            .debug_str = debug_str,
            .debug_line = debug_line,
            .debug_line_str = debug_line_str,
            .debug_ranges = debug_ranges,
        };
        try dwarf.openDwarfDebugInfo(&inner, allocator);

        return DebugInfo{
            .inner = inner,
            .debug_info = debug_info,
            .debug_abbrev = debug_abbrev,
            .debug_str = debug_str,
            .debug_line = debug_line,
            .debug_line_str = debug_line_str,
            .debug_ranges = debug_ranges,
        };
    }

    pub fn deinit(self: *DebugInfo, allocator: Allocator) void {
        allocator.free(self.debug_info);
        allocator.free(self.debug_abbrev);
        allocator.free(self.debug_str);
        allocator.free(self.debug_line);
        allocator.free(self.debug_line_str);
        allocator.free(self.debug_ranges);
        self.inner.deinit(allocator);
    }
};

pub fn deinit(self: *Object, allocator: Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(allocator);
    }
    self.load_commands.deinit(allocator);
    self.data_in_code_entries.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.sections_as_symbols.deinit(allocator);
    self.symbol_mapping.deinit(allocator);
    self.reverse_symbol_mapping.deinit(allocator);
    allocator.free(self.name);

    self.contained_atoms.deinit(allocator);
    self.start_atoms.deinit(allocator);
    self.end_atoms.deinit(allocator);

    if (self.debug_info) |*db| {
        db.deinit(allocator);
    }

    if (self.tu_name) |n| {
        allocator.free(n);
    }

    if (self.tu_comp_dir) |n| {
        allocator.free(n);
    }
}

pub fn free(self: *Object, allocator: Allocator, macho_file: *MachO) void {
    log.debug("freeObject {*}", .{self});

    var it = self.end_atoms.iterator();
    while (it.next()) |entry| {
        const match = entry.key_ptr.*;
        const first_atom = self.start_atoms.get(match).?;
        const last_atom = entry.value_ptr.*;
        var atom = first_atom;

        while (true) {
            if (atom.local_sym_index != 0) {
                macho_file.locals_free_list.append(allocator, atom.local_sym_index) catch {};
                const local = &macho_file.locals.items[atom.local_sym_index];
                local.* = .{
                    .n_strx = 0,
                    .n_type = 0,
                    .n_sect = 0,
                    .n_desc = 0,
                    .n_value = 0,
                };
                atom.local_sym_index = 0;
            }
            if (atom == last_atom) {
                break;
            }
            if (atom.next) |next| {
                atom = next;
            } else break;
        }
    }

    self.freeAtoms(macho_file);
}

fn freeAtoms(self: *Object, macho_file: *MachO) void {
    var it = self.end_atoms.iterator();
    while (it.next()) |entry| {
        const match = entry.key_ptr.*;
        var first_atom: *Atom = self.start_atoms.get(match).?;
        var last_atom: *Atom = entry.value_ptr.*;

        if (macho_file.atoms.getPtr(match)) |atom_ptr| {
            if (atom_ptr.* == last_atom) {
                if (first_atom.prev) |prev| {
                    // TODO shrink the section size here
                    atom_ptr.* = prev;
                } else {
                    _ = macho_file.atoms.fetchRemove(match);
                }
            }
        }

        if (first_atom.prev) |prev| {
            prev.next = last_atom.next;
        } else {
            first_atom.prev = null;
        }

        if (last_atom.next) |next| {
            next.prev = last_atom.prev;
        } else {
            last_atom.next = null;
        }
    }
}

pub fn parse(self: *Object, allocator: Allocator, target: std.Target) !void {
    const reader = self.file.reader();
    if (self.file_offset) |offset| {
        try reader.context.seekTo(offset);
    }

    const header = try reader.readStruct(macho.mach_header_64);
    if (header.filetype != macho.MH_OBJECT) {
        log.debug("invalid filetype: expected 0x{x}, found 0x{x}", .{
            macho.MH_OBJECT,
            header.filetype,
        });
        return error.NotObject;
    }

    const this_arch: std.Target.Cpu.Arch = switch (header.cputype) {
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

    self.header = header;

    try self.readLoadCommands(allocator, reader);
    try self.parseSymtab(allocator);
    try self.parseDataInCode(allocator);
    try self.parseDebugInfo(allocator);
}

pub fn readLoadCommands(self: *Object, allocator: Allocator, reader: anytype) !void {
    const header = self.header orelse unreachable; // Unreachable here signifies a fatal unexplored condition.
    const offset = self.file_offset orelse 0;

    try self.load_commands.ensureUnusedCapacity(allocator, header.ncmds);

    var i: u16 = 0;
    while (i < header.ncmds) : (i += 1) {
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

                    sect.offset += offset;
                    if (sect.reloff > 0) {
                        sect.reloff += offset;
                    }
                }

                seg.inner.fileoff += offset;
            },
            .SYMTAB => {
                self.symtab_cmd_index = i;
                cmd.symtab.symoff += offset;
                cmd.symtab.stroff += offset;
            },
            .DYSYMTAB => {
                self.dysymtab_cmd_index = i;
            },
            .BUILD_VERSION => {
                self.build_version_cmd_index = i;
            },
            .DATA_IN_CODE => {
                self.data_in_code_cmd_index = i;
                cmd.linkedit_data.dataoff += offset;
            },
            else => {
                log.debug("Unknown load command detected: 0x{x}.", .{cmd.cmd()});
            },
        }
        self.load_commands.appendAssumeCapacity(cmd);
    }
}

const NlistWithIndex = struct {
    nlist: macho.nlist_64,
    index: u32,

    fn lessThan(_: void, lhs: NlistWithIndex, rhs: NlistWithIndex) bool {
        // We sort by type: defined < undefined, and
        // afterwards by address in each group. Normally, dysymtab should
        // be enough to guarantee the sort, but turns out not every compiler
        // is kind enough to specify the symbols in the correct order.
        if (lhs.nlist.sect()) {
            if (rhs.nlist.sect()) {
                // Same group, sort by address.
                return lhs.nlist.n_value < rhs.nlist.n_value;
            } else {
                return true;
            }
        } else {
            return false;
        }
    }

    fn filterInSection(symbols: []NlistWithIndex, sect: macho.section_64) []NlistWithIndex {
        const Predicate = struct {
            addr: u64,

            pub fn predicate(self: @This(), symbol: NlistWithIndex) bool {
                return symbol.nlist.n_value >= self.addr;
            }
        };

        const start = MachO.findFirst(NlistWithIndex, symbols, 0, Predicate{ .addr = sect.addr });
        const end = MachO.findFirst(NlistWithIndex, symbols, start, Predicate{ .addr = sect.addr + sect.size });

        return symbols[start..end];
    }
};

fn filterDice(dices: []macho.data_in_code_entry, start_addr: u64, end_addr: u64) []macho.data_in_code_entry {
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

pub fn parseIntoAtoms(self: *Object, allocator: Allocator, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = self.load_commands.items[self.segment_cmd_index.?].segment;

    log.debug("analysing {s}", .{self.name});

    // You would expect that the symbol table is at least pre-sorted based on symbol's type:
    // local < extern defined < undefined. Unfortunately, this is not guaranteed! For instance,
    // the GO compiler does not necessarily respect that therefore we sort immediately by type
    // and address within.
    var sorted_all_nlists = try std.ArrayList(NlistWithIndex).initCapacity(allocator, self.symtab.items.len);
    defer sorted_all_nlists.deinit();

    for (self.symtab.items) |nlist, index| {
        sorted_all_nlists.appendAssumeCapacity(.{
            .nlist = nlist,
            .index = @intCast(u32, index),
        });
    }

    sort.sort(NlistWithIndex, sorted_all_nlists.items, {}, NlistWithIndex.lessThan);

    // Well, shit, sometimes compilers skip the dysymtab load command altogether, meaning we
    // have to infer the start of undef section in the symtab ourselves.
    const iundefsym = if (self.dysymtab_cmd_index) |cmd_index| blk: {
        const dysymtab = self.load_commands.items[cmd_index].dysymtab;
        break :blk dysymtab.iundefsym;
    } else blk: {
        var iundefsym: usize = sorted_all_nlists.items.len;
        while (iundefsym > 0) : (iundefsym -= 1) {
            const nlist = sorted_all_nlists.items[iundefsym - 1];
            if (nlist.nlist.sect()) break;
        }
        break :blk iundefsym;
    };

    // We only care about defined symbols, so filter every other out.
    const sorted_nlists = sorted_all_nlists.items[0..iundefsym];

    for (seg.sections.items) |sect, id| {
        const sect_id = @intCast(u8, id);
        log.debug("putting section '{s},{s}' as an Atom", .{ sect.segName(), sect.sectName() });

        // Get matching segment/section in the final artifact.
        const match = (try macho_file.getMatchingSection(sect)) orelse {
            log.debug("unhandled section", .{});
            continue;
        };

        // Read section's code
        var code = try allocator.alloc(u8, @intCast(usize, sect.size));
        defer allocator.free(code);
        _ = try self.file.preadAll(code, sect.offset);

        // Read section's list of relocations
        var raw_relocs = try allocator.alloc(u8, sect.nreloc * @sizeOf(macho.relocation_info));
        defer allocator.free(raw_relocs);
        _ = try self.file.preadAll(raw_relocs, sect.reloff);
        const relocs = mem.bytesAsSlice(macho.relocation_info, raw_relocs);

        // Symbols within this section only.
        const filtered_nlists = NlistWithIndex.filterInSection(sorted_nlists, sect);

        macho_file.has_dices = macho_file.has_dices or blk: {
            if (self.text_section_index) |index| {
                if (index != id) break :blk false;
                if (self.data_in_code_entries.items.len == 0) break :blk false;
                break :blk true;
            }
            break :blk false;
        };
        macho_file.has_stabs = macho_file.has_stabs or self.debug_info != null;

        // Since there is no symbol to refer to this atom, we create
        // a temp one, unless we already did that when working out the relocations
        // of other atoms.
        const atom_local_sym_index = self.sections_as_symbols.get(sect_id) orelse blk: {
            const atom_local_sym_index = @intCast(u32, macho_file.locals.items.len);
            try macho_file.locals.append(allocator, .{
                .n_strx = 0,
                .n_type = macho.N_SECT,
                .n_sect = @intCast(u8, macho_file.section_ordinals.getIndex(match).? + 1),
                .n_desc = 0,
                .n_value = 0,
            });
            try self.sections_as_symbols.putNoClobber(allocator, sect_id, atom_local_sym_index);
            break :blk atom_local_sym_index;
        };
        const alignment = try math.powi(u32, 2, sect.@"align");
        const aligned_size = mem.alignForwardGeneric(u64, sect.size, alignment);
        const atom = try macho_file.createEmptyAtom(atom_local_sym_index, aligned_size, sect.@"align");

        const is_zerofill = blk: {
            const section_type = sect.type_();
            break :blk section_type == macho.S_ZEROFILL or section_type == macho.S_THREAD_LOCAL_ZEROFILL;
        };
        if (!is_zerofill) {
            mem.copy(u8, atom.code.items, code);
        }

        // TODO stage2 bug: @alignCast shouldn't be needed
        try atom.parseRelocs(@alignCast(@alignOf(macho.relocation_info), relocs), .{
            .base_addr = sect.addr,
            .allocator = allocator,
            .object = self,
            .macho_file = macho_file,
        });

        if (macho_file.has_dices) {
            const dices = filterDice(self.data_in_code_entries.items, sect.addr, sect.addr + sect.size);
            try atom.dices.ensureTotalCapacity(allocator, dices.len);

            for (dices) |dice| {
                atom.dices.appendAssumeCapacity(.{
                    .offset = dice.offset - (math.cast(u32, sect.addr) orelse return error.Overflow),
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
        try atom.contained.ensureTotalCapacity(allocator, filtered_nlists.len);

        for (filtered_nlists) |nlist_with_index| {
            const nlist = nlist_with_index.nlist;
            const local_sym_index = self.symbol_mapping.get(nlist_with_index.index) orelse unreachable;
            const local = &macho_file.locals.items[local_sym_index];
            local.n_sect = @intCast(u8, macho_file.section_ordinals.getIndex(match).? + 1);

            const stab: ?Atom.Stab = if (self.debug_info) |di| blk: {
                // TODO there has to be a better to handle this.
                for (di.inner.func_list.items) |func| {
                    if (func.pc_range) |range| {
                        if (nlist.n_value >= range.start and nlist.n_value < range.end) {
                            break :blk Atom.Stab{
                                .function = range.end - range.start,
                            };
                        }
                    }
                }
                // TODO
                // if (zld.globals.contains(zld.getString(sym.strx))) break :blk .global;
                break :blk .static;
            } else null;

            atom.contained.appendAssumeCapacity(.{
                .local_sym_index = local_sym_index,
                .offset = nlist.n_value - sect.addr,
                .stab = stab,
            });
        }

        if (!self.start_atoms.contains(match)) {
            try self.start_atoms.putNoClobber(allocator, match, atom);
        }

        if (self.end_atoms.getPtr(match)) |last| {
            last.*.next = atom;
            atom.prev = last.*;
            last.* = atom;
        } else {
            try self.end_atoms.putNoClobber(allocator, match, atom);
        }
        try self.contained_atoms.append(allocator, atom);
    }
}

fn parseSymtab(self: *Object, allocator: Allocator) !void {
    const index = self.symtab_cmd_index orelse return;
    const symtab_cmd = self.load_commands.items[index].symtab;

    var symtab = try allocator.alloc(u8, @sizeOf(macho.nlist_64) * symtab_cmd.nsyms);
    defer allocator.free(symtab);
    _ = try self.file.preadAll(symtab, symtab_cmd.symoff);
    const slice = @alignCast(@alignOf(macho.nlist_64), mem.bytesAsSlice(macho.nlist_64, symtab));
    try self.symtab.appendSlice(allocator, slice);

    var strtab = try allocator.alloc(u8, symtab_cmd.strsize);
    defer allocator.free(strtab);
    _ = try self.file.preadAll(strtab, symtab_cmd.stroff);
    try self.strtab.appendSlice(allocator, strtab);
}

pub fn parseDebugInfo(self: *Object, allocator: Allocator) !void {
    log.debug("parsing debug info in '{s}'", .{self.name});

    var debug_info = blk: {
        var di = try DebugInfo.parseFromObject(allocator, self);
        break :blk di orelse return;
    };

    // We assume there is only one CU.
    const compile_unit = debug_info.inner.findCompileUnit(0x0) catch |err| switch (err) {
        error.MissingDebugInfo => {
            // TODO audit cases with missing debug info and audit our dwarf.zig module.
            log.debug("invalid or missing debug info in {s}; skipping", .{self.name});
            return;
        },
        else => |e| return e,
    };
    const name = try compile_unit.die.getAttrString(&debug_info.inner, dwarf.AT.name);
    const comp_dir = try compile_unit.die.getAttrString(&debug_info.inner, dwarf.AT.comp_dir);

    self.debug_info = debug_info;
    self.tu_name = try allocator.dupe(u8, name);
    self.tu_comp_dir = try allocator.dupe(u8, comp_dir);

    if (self.mtime == null) {
        self.mtime = mtime: {
            const stat = self.file.stat() catch break :mtime 0;
            break :mtime @intCast(u64, @divFloor(stat.mtime, 1_000_000_000));
        };
    }
}

pub fn parseDataInCode(self: *Object, allocator: Allocator) !void {
    const index = self.data_in_code_cmd_index orelse return;
    const data_in_code = self.load_commands.items[index].linkedit_data;

    var buffer = try allocator.alloc(u8, data_in_code.datasize);
    defer allocator.free(buffer);

    _ = try self.file.preadAll(buffer, data_in_code.dataoff);

    var stream = io.fixedBufferStream(buffer);
    var reader = stream.reader();
    while (true) {
        const dice = reader.readStruct(macho.data_in_code_entry) catch |err| switch (err) {
            error.EndOfStream => break,
        };
        try self.data_in_code_entries.append(allocator, dice);
    }
}

fn readSection(self: Object, allocator: Allocator, index: u16) ![]u8 {
    const seg = self.load_commands.items[self.segment_cmd_index.?].segment;
    const sect = seg.sections.items[index];
    var buffer = try allocator.alloc(u8, @intCast(usize, sect.size));
    _ = try self.file.preadAll(buffer, sect.offset);
    return buffer;
}

pub fn getString(self: Object, off: u32) []const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@ptrCast([*:0]const u8, self.strtab.items.ptr + off), 0);
}
