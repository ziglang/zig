const Object = @This();

const std = @import("std");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const fs = std.fs;
const io = std.io;
const log = std.log.scoped(.object);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const sort = std.sort;
const commands = @import("commands.zig");
const segmentName = commands.segmentName;
const sectionName = commands.sectionName;

const Allocator = mem.Allocator;
const LoadCommand = commands.LoadCommand;
const MachO = @import("../MachO.zig");
const TextBlock = @import("TextBlock.zig");

file: fs.File,
name: []const u8,

file_offset: ?u32 = null,

header: ?macho.mach_header_64 = null,

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

segment_cmd_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
build_version_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,

text_section_index: ?u16 = null,
mod_init_func_section_index: ?u16 = null,

// __DWARF segment sections
dwarf_debug_info_index: ?u16 = null,
dwarf_debug_abbrev_index: ?u16 = null,
dwarf_debug_str_index: ?u16 = null,
dwarf_debug_line_index: ?u16 = null,
dwarf_debug_ranges_index: ?u16 = null,

symtab: std.ArrayListUnmanaged(macho.nlist_64) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
data_in_code_entries: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

// Debug info
debug_info: ?DebugInfo = null,
tu_name: ?[]const u8 = null,
tu_comp_dir: ?[]const u8 = null,
mtime: ?u64 = null,

text_blocks: std.ArrayListUnmanaged(*TextBlock) = .{},
sections_as_symbols: std.AutoHashMapUnmanaged(u16, u32) = .{},

// TODO symbol mapping and its inverse can probably be simple arrays
// instead of hash maps.
symbol_mapping: std.AutoHashMapUnmanaged(u32, u32) = .{},
reverse_symbol_mapping: std.AutoHashMapUnmanaged(u32, u32) = .{},

const DebugInfo = struct {
    inner: dwarf.DwarfInfo,
    debug_info: []u8,
    debug_abbrev: []u8,
    debug_str: []u8,
    debug_line: []u8,
    debug_ranges: []u8,

    pub fn parseFromObject(allocator: *Allocator, object: *const Object) !?DebugInfo {
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
            .debug_ranges = debug_ranges,
        };
        try dwarf.openDwarfDebugInfo(&inner, allocator);

        return DebugInfo{
            .inner = inner,
            .debug_info = debug_info,
            .debug_abbrev = debug_abbrev,
            .debug_str = debug_str,
            .debug_line = debug_line,
            .debug_ranges = debug_ranges,
        };
    }

    pub fn deinit(self: *DebugInfo, allocator: *Allocator) void {
        allocator.free(self.debug_info);
        allocator.free(self.debug_abbrev);
        allocator.free(self.debug_str);
        allocator.free(self.debug_line);
        allocator.free(self.debug_ranges);
        self.inner.abbrev_table_list.deinit();
        self.inner.compile_unit_list.deinit();
        self.inner.func_list.deinit();
    }
};

pub fn deinit(self: *Object, allocator: *Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(allocator);
    }
    self.load_commands.deinit(allocator);
    self.data_in_code_entries.deinit(allocator);
    self.symtab.deinit(allocator);
    self.strtab.deinit(allocator);
    self.text_blocks.deinit(allocator);
    self.sections_as_symbols.deinit(allocator);
    self.symbol_mapping.deinit(allocator);
    self.reverse_symbol_mapping.deinit(allocator);
    allocator.free(self.name);

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

pub fn createAndParseFromPath(allocator: *Allocator, target: std.Target, path: []const u8) !?Object {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |e| return e,
    };
    errdefer file.close();

    const name = try allocator.dupe(u8, path);
    errdefer allocator.free(name);

    var object = Object{
        .name = name,
        .file = file,
    };

    object.parse(allocator, target) catch |err| switch (err) {
        error.EndOfStream, error.NotObject => {
            object.deinit(allocator);
            return null;
        },
        else => |e| return e,
    };

    return object;
}

pub fn parse(self: *Object, allocator: *Allocator, target: std.Target) !void {
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

pub fn readLoadCommands(self: *Object, allocator: *Allocator, reader: anytype) !void {
    const header = self.header orelse unreachable; // Unreachable here signifies a fatal unexplored condition.
    const offset = self.file_offset orelse 0;

    try self.load_commands.ensureCapacity(allocator, header.ncmds);

    var i: u16 = 0;
    while (i < header.ncmds) : (i += 1) {
        var cmd = try LoadCommand.read(allocator, reader);
        switch (cmd.cmd()) {
            macho.LC_SEGMENT_64 => {
                self.segment_cmd_index = i;
                var seg = cmd.Segment;
                for (seg.sections.items) |*sect, j| {
                    const index = @intCast(u16, j);
                    const segname = segmentName(sect.*);
                    const sectname = sectionName(sect.*);
                    if (mem.eql(u8, segname, "__DWARF")) {
                        if (mem.eql(u8, sectname, "__debug_info")) {
                            self.dwarf_debug_info_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_abbrev")) {
                            self.dwarf_debug_abbrev_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_str")) {
                            self.dwarf_debug_str_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_line")) {
                            self.dwarf_debug_line_index = index;
                        } else if (mem.eql(u8, sectname, "__debug_ranges")) {
                            self.dwarf_debug_ranges_index = index;
                        }
                    } else if (mem.eql(u8, segname, "__TEXT")) {
                        if (mem.eql(u8, sectname, "__text")) {
                            self.text_section_index = index;
                        }
                    } else if (mem.eql(u8, segname, "__DATA")) {
                        if (mem.eql(u8, sectname, "__mod_init_func")) {
                            self.mod_init_func_section_index = index;
                        }
                    }

                    sect.offset += offset;
                    if (sect.reloff > 0) {
                        sect.reloff += offset;
                    }
                }

                seg.inner.fileoff += offset;
            },
            macho.LC_SYMTAB => {
                self.symtab_cmd_index = i;
                cmd.Symtab.symoff += offset;
                cmd.Symtab.stroff += offset;
            },
            macho.LC_DYSYMTAB => {
                self.dysymtab_cmd_index = i;
            },
            macho.LC_BUILD_VERSION => {
                self.build_version_cmd_index = i;
            },
            macho.LC_DATA_IN_CODE => {
                self.data_in_code_cmd_index = i;
                cmd.LinkeditData.dataoff += offset;
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
        if (MachO.symbolIsSect(lhs.nlist)) {
            if (MachO.symbolIsSect(rhs.nlist)) {
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

const Context = struct {
    allocator: *Allocator,
    object: *Object,
    macho_file: *MachO,
    match: MachO.MatchingSection,
};

const TextBlockParser = struct {
    section: macho.section_64,
    code: []u8,
    relocs: []macho.relocation_info,
    nlists: []NlistWithIndex,
    index: u32 = 0,

    fn peek(self: TextBlockParser) ?NlistWithIndex {
        return if (self.index + 1 < self.nlists.len) self.nlists[self.index + 1] else null;
    }

    fn lessThanBySeniority(context: Context, lhs: NlistWithIndex, rhs: NlistWithIndex) bool {
        if (!MachO.symbolIsExt(rhs.nlist)) {
            return MachO.symbolIsTemp(lhs.nlist, context.object.getString(lhs.nlist.n_strx));
        } else if (MachO.symbolIsPext(rhs.nlist) or MachO.symbolIsWeakDef(rhs.nlist)) {
            return !MachO.symbolIsExt(lhs.nlist);
        } else {
            return false;
        }
    }

    pub fn next(self: *TextBlockParser, context: Context) !?*TextBlock {
        if (self.index == self.nlists.len) return null;

        var aliases = std.ArrayList(NlistWithIndex).init(context.allocator);
        defer aliases.deinit();

        const next_nlist: ?NlistWithIndex = blk: while (true) {
            const curr_nlist = self.nlists[self.index];
            try aliases.append(curr_nlist);

            if (self.peek()) |next_nlist| {
                if (curr_nlist.nlist.n_value == next_nlist.nlist.n_value) {
                    self.index += 1;
                    continue;
                }
                break :blk next_nlist;
            }
            break :blk null;
        } else null;

        for (aliases.items) |*nlist_with_index| {
            nlist_with_index.index = context.object.symbol_mapping.get(nlist_with_index.index) orelse unreachable;
        }

        if (aliases.items.len > 1) {
            // Bubble-up senior symbol as the main link to the text block.
            sort.sort(
                NlistWithIndex,
                aliases.items,
                context,
                TextBlockParser.lessThanBySeniority,
            );
        }

        const senior_nlist = aliases.pop();
        const senior_sym = &context.macho_file.locals.items[senior_nlist.index];
        senior_sym.n_sect = @intCast(u8, context.macho_file.section_ordinals.getIndex(context.match).? + 1);

        const start_addr = senior_nlist.nlist.n_value - self.section.addr;
        const end_addr = if (next_nlist) |n| n.nlist.n_value - self.section.addr else self.section.size;

        const code = self.code[start_addr..end_addr];
        const size = code.len;

        const max_align = self.section.@"align";
        const actual_align = if (senior_nlist.nlist.n_value > 0)
            math.min(@ctz(u64, senior_nlist.nlist.n_value), max_align)
        else
            max_align;

        const stab: ?TextBlock.Stab = if (context.object.debug_info) |di| blk: {
            // TODO there has to be a better to handle this.
            for (di.inner.func_list.items) |func| {
                if (func.pc_range) |range| {
                    if (senior_nlist.nlist.n_value >= range.start and senior_nlist.nlist.n_value < range.end) {
                        break :blk TextBlock.Stab{
                            .function = range.end - range.start,
                        };
                    }
                }
            }
            // TODO
            // if (self.macho_file.globals.contains(self.macho_file.getString(senior_sym.strx))) break :blk .global;
            break :blk .static;
        } else null;

        const block = try context.allocator.create(TextBlock);
        block.* = TextBlock.empty;
        block.local_sym_index = senior_nlist.index;
        block.stab = stab;
        block.size = size;
        block.alignment = actual_align;
        try context.macho_file.managed_blocks.append(context.allocator, block);

        try block.code.appendSlice(context.allocator, code);

        try block.aliases.ensureTotalCapacity(context.allocator, aliases.items.len);
        for (aliases.items) |alias| {
            block.aliases.appendAssumeCapacity(alias.index);
            const sym = &context.macho_file.locals.items[alias.index];
            sym.n_sect = @intCast(u8, context.macho_file.section_ordinals.getIndex(context.match).? + 1);
        }

        try block.parseRelocs(self.relocs, .{
            .base_addr = start_addr,
            .allocator = context.allocator,
            .object = context.object,
            .macho_file = context.macho_file,
        });

        if (context.macho_file.has_dices) {
            const dices = filterDice(
                context.object.data_in_code_entries.items,
                senior_nlist.nlist.n_value,
                senior_nlist.nlist.n_value + size,
            );
            try block.dices.ensureTotalCapacity(context.allocator, dices.len);

            for (dices) |dice| {
                block.dices.appendAssumeCapacity(.{
                    .offset = dice.offset - try math.cast(u32, senior_nlist.nlist.n_value),
                    .length = dice.length,
                    .kind = dice.kind,
                });
            }
        }

        self.index += 1;

        return block;
    }
};

pub fn parseTextBlocks(
    self: *Object,
    allocator: *Allocator,
    object_id: u16,
    macho_file: *MachO,
) !void {
    const seg = self.load_commands.items[self.segment_cmd_index.?].Segment;

    log.debug("analysing {s}", .{self.name});

    // You would expect that the symbol table is at least pre-sorted based on symbol's type:
    // local < extern defined < undefined. Unfortunately, this is not guaranteed! For instance,
    // the GO compiler does not necessarily respect that therefore we sort immediately by type
    // and address within.
    var sorted_all_nlists = std.ArrayList(NlistWithIndex).init(allocator);
    defer sorted_all_nlists.deinit();
    try sorted_all_nlists.ensureTotalCapacity(self.symtab.items.len);

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
        const dysymtab = self.load_commands.items[cmd_index].Dysymtab;
        break :blk dysymtab.iundefsym;
    } else blk: {
        var iundefsym: usize = sorted_all_nlists.items.len;
        while (iundefsym > 0) : (iundefsym -= 1) {
            const nlist = sorted_all_nlists.items[iundefsym];
            if (MachO.symbolIsSect(nlist.nlist)) break;
        }
        break :blk iundefsym;
    };

    // We only care about defined symbols, so filter every other out.
    const sorted_nlists = sorted_all_nlists.items[0..iundefsym];

    for (seg.sections.items) |sect, id| {
        const sect_id = @intCast(u8, id);
        log.debug("putting section '{s},{s}' as a TextBlock", .{
            segmentName(sect),
            sectionName(sect),
        });

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

        // In release mode, if the object file was generated with dead code stripping optimisations,
        // note it now and parse sections as atoms.
        const is_splittable = blk: {
            if (macho_file.base.options.optimize_mode == .Debug) break :blk false;
            break :blk self.header.?.flags & macho.MH_SUBSECTIONS_VIA_SYMBOLS != 0;
        };

        macho_file.has_dices = blk: {
            if (self.text_section_index) |index| {
                if (index != id) break :blk false;
                if (self.data_in_code_entries.items.len == 0) break :blk false;
                break :blk true;
            }
            break :blk false;
        };
        macho_file.has_stabs = macho_file.has_stabs or self.debug_info != null;

        next: {
            if (is_splittable) blocks: {
                if (filtered_nlists.len == 0) break :blocks;

                // If the first nlist does not match the start of the section,
                // then we need to encapsulate the memory range [section start, first symbol)
                // as a temporary symbol and insert the matching TextBlock.
                const first_nlist = filtered_nlists[0].nlist;
                if (first_nlist.n_value > sect.addr) {
                    const sym_name = try std.fmt.allocPrint(allocator, "l_{s}_{s}_{s}", .{
                        self.name,
                        segmentName(sect),
                        sectionName(sect),
                    });
                    defer allocator.free(sym_name);

                    const block_local_sym_index = self.sections_as_symbols.get(sect_id) orelse blk: {
                        const block_local_sym_index = @intCast(u32, macho_file.locals.items.len);
                        try macho_file.locals.append(allocator, .{
                            .n_strx = try macho_file.makeString(sym_name),
                            .n_type = macho.N_SECT,
                            .n_sect = @intCast(u8, macho_file.section_ordinals.getIndex(match).? + 1),
                            .n_desc = 0,
                            .n_value = sect.addr,
                        });
                        try self.sections_as_symbols.putNoClobber(allocator, sect_id, block_local_sym_index);
                        break :blk block_local_sym_index;
                    };

                    const block_code = code[0 .. first_nlist.n_value - sect.addr];
                    const block_size = block_code.len;

                    const block = try allocator.create(TextBlock);
                    block.* = TextBlock.empty;
                    block.local_sym_index = block_local_sym_index;
                    block.size = block_size;
                    block.alignment = sect.@"align";
                    try macho_file.managed_blocks.append(allocator, block);

                    try block.code.appendSlice(allocator, block_code);

                    try block.parseRelocs(relocs, .{
                        .base_addr = 0,
                        .allocator = allocator,
                        .object = self,
                        .macho_file = macho_file,
                    });

                    if (macho_file.has_dices) {
                        const dices = filterDice(self.data_in_code_entries.items, sect.addr, sect.addr + block_size);
                        try block.dices.ensureTotalCapacity(allocator, dices.len);

                        for (dices) |dice| {
                            block.dices.appendAssumeCapacity(.{
                                .offset = dice.offset - try math.cast(u32, sect.addr),
                                .length = dice.length,
                                .kind = dice.kind,
                            });
                        }
                    }

                    // Update target section's metadata
                    // TODO should we update segment's size here too?
                    // How does it tie with incremental space allocs?
                    const tseg = &macho_file.load_commands.items[match.seg].Segment;
                    const tsect = &tseg.sections.items[match.sect];
                    const new_alignment = math.max(tsect.@"align", block.alignment);
                    const new_alignment_pow_2 = try math.powi(u32, 2, new_alignment);
                    const new_size = mem.alignForwardGeneric(u64, tsect.size, new_alignment_pow_2) + block.size;
                    tsect.size = new_size;
                    tsect.@"align" = new_alignment;

                    if (macho_file.blocks.getPtr(match)) |last| {
                        last.*.next = block;
                        block.prev = last.*;
                        last.* = block;
                    } else {
                        try macho_file.blocks.putNoClobber(allocator, match, block);
                    }

                    try self.text_blocks.append(allocator, block);
                }

                var parser = TextBlockParser{
                    .section = sect,
                    .code = code,
                    .relocs = relocs,
                    .nlists = filtered_nlists,
                };

                while (try parser.next(.{
                    .allocator = allocator,
                    .object = self,
                    .macho_file = macho_file,
                    .match = match,
                })) |block| {
                    const sym = macho_file.locals.items[block.local_sym_index];
                    const is_ext = blk: {
                        const orig_sym_id = self.reverse_symbol_mapping.get(block.local_sym_index) orelse unreachable;
                        break :blk MachO.symbolIsExt(self.symtab.items[orig_sym_id]);
                    };
                    if (is_ext) {
                        if (macho_file.symbol_resolver.get(sym.n_strx)) |resolv| {
                            assert(resolv.where == .global);
                            if (resolv.file != object_id) {
                                log.debug("deduping definition of {s} in {s}", .{
                                    macho_file.getString(sym.n_strx),
                                    self.name,
                                });
                                log.debug("  already defined in {s}", .{
                                    macho_file.objects.items[resolv.file].name,
                                });
                                continue;
                            }
                        }
                    }

                    if (sym.n_value == sect.addr) {
                        if (self.sections_as_symbols.get(sect_id)) |alias| {
                            // In x86_64 relocs, it can so happen that the compiler refers to the same
                            // atom by both the actual assigned symbol and the start of the section. In this
                            // case, we need to link the two together so add an alias.
                            try block.aliases.append(allocator, alias);
                        }
                    }

                    // Update target section's metadata
                    // TODO should we update segment's size here too?
                    // How does it tie with incremental space allocs?
                    const tseg = &macho_file.load_commands.items[match.seg].Segment;
                    const tsect = &tseg.sections.items[match.sect];
                    const new_alignment = math.max(tsect.@"align", block.alignment);
                    const new_alignment_pow_2 = try math.powi(u32, 2, new_alignment);
                    const new_size = mem.alignForwardGeneric(u64, tsect.size, new_alignment_pow_2) + block.size;
                    tsect.size = new_size;
                    tsect.@"align" = new_alignment;

                    if (macho_file.blocks.getPtr(match)) |last| {
                        last.*.next = block;
                        block.prev = last.*;
                        last.* = block;
                    } else {
                        try macho_file.blocks.putNoClobber(allocator, match, block);
                    }

                    try self.text_blocks.append(allocator, block);
                }

                break :next;
            }

            // Since there is no symbol to refer to this block, we create
            // a temp one, unless we already did that when working out the relocations
            // of other text blocks.
            const sym_name = try std.fmt.allocPrint(allocator, "l_{s}_{s}_{s}", .{
                self.name,
                segmentName(sect),
                sectionName(sect),
            });
            defer allocator.free(sym_name);

            const block_local_sym_index = self.sections_as_symbols.get(sect_id) orelse blk: {
                const block_local_sym_index = @intCast(u32, macho_file.locals.items.len);
                try macho_file.locals.append(allocator, .{
                    .n_strx = try macho_file.makeString(sym_name),
                    .n_type = macho.N_SECT,
                    .n_sect = @intCast(u8, macho_file.section_ordinals.getIndex(match).? + 1),
                    .n_desc = 0,
                    .n_value = sect.addr,
                });
                try self.sections_as_symbols.putNoClobber(allocator, sect_id, block_local_sym_index);
                break :blk block_local_sym_index;
            };

            const block = try allocator.create(TextBlock);
            block.* = TextBlock.empty;
            block.local_sym_index = block_local_sym_index;
            block.size = sect.size;
            block.alignment = sect.@"align";
            try macho_file.managed_blocks.append(allocator, block);

            try block.code.appendSlice(allocator, code);

            try block.parseRelocs(relocs, .{
                .base_addr = 0,
                .allocator = allocator,
                .object = self,
                .macho_file = macho_file,
            });

            if (macho_file.has_dices) {
                const dices = filterDice(self.data_in_code_entries.items, sect.addr, sect.addr + sect.size);
                try block.dices.ensureTotalCapacity(allocator, dices.len);

                for (dices) |dice| {
                    block.dices.appendAssumeCapacity(.{
                        .offset = dice.offset - try math.cast(u32, sect.addr),
                        .length = dice.length,
                        .kind = dice.kind,
                    });
                }
            }

            // Since this is block gets a helper local temporary symbol that didn't exist
            // in the object file which encompasses the entire section, we need traverse
            // the filtered symbols and note which symbol is contained within so that
            // we can properly allocate addresses down the line.
            // While we're at it, we need to update segment,section mapping of each symbol too.
            try block.contained.ensureTotalCapacity(allocator, filtered_nlists.len);

            for (filtered_nlists) |nlist_with_index| {
                const nlist = nlist_with_index.nlist;
                const local_sym_index = self.symbol_mapping.get(nlist_with_index.index) orelse unreachable;
                const local = &macho_file.locals.items[local_sym_index];
                local.n_sect = @intCast(u8, macho_file.section_ordinals.getIndex(match).? + 1);

                const stab: ?TextBlock.Stab = if (self.debug_info) |di| blk: {
                    // TODO there has to be a better to handle this.
                    for (di.inner.func_list.items) |func| {
                        if (func.pc_range) |range| {
                            if (nlist.n_value >= range.start and nlist.n_value < range.end) {
                                break :blk TextBlock.Stab{
                                    .function = range.end - range.start,
                                };
                            }
                        }
                    }
                    // TODO
                    // if (zld.globals.contains(zld.getString(sym.strx))) break :blk .global;
                    break :blk .static;
                } else null;

                block.contained.appendAssumeCapacity(.{
                    .local_sym_index = local_sym_index,
                    .offset = nlist.n_value - sect.addr,
                    .stab = stab,
                });
            }

            // Update target section's metadata
            // TODO should we update segment's size here too?
            // How does it tie with incremental space allocs?
            const tseg = &macho_file.load_commands.items[match.seg].Segment;
            const tsect = &tseg.sections.items[match.sect];
            const new_alignment = math.max(tsect.@"align", block.alignment);
            const new_alignment_pow_2 = try math.powi(u32, 2, new_alignment);
            const new_size = mem.alignForwardGeneric(u64, tsect.size, new_alignment_pow_2) + block.size;
            tsect.size = new_size;
            tsect.@"align" = new_alignment;

            if (macho_file.blocks.getPtr(match)) |last| {
                last.*.next = block;
                block.prev = last.*;
                last.* = block;
            } else {
                try macho_file.blocks.putNoClobber(allocator, match, block);
            }

            try self.text_blocks.append(allocator, block);
        }
    }
}

fn parseSymtab(self: *Object, allocator: *Allocator) !void {
    const index = self.symtab_cmd_index orelse return;
    const symtab_cmd = self.load_commands.items[index].Symtab;

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

pub fn parseDebugInfo(self: *Object, allocator: *Allocator) !void {
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
    const name = try compile_unit.die.getAttrString(&debug_info.inner, dwarf.AT_name);
    const comp_dir = try compile_unit.die.getAttrString(&debug_info.inner, dwarf.AT_comp_dir);

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

pub fn parseDataInCode(self: *Object, allocator: *Allocator) !void {
    const index = self.data_in_code_cmd_index orelse return;
    const data_in_code = self.load_commands.items[index].LinkeditData;

    var buffer = try allocator.alloc(u8, data_in_code.datasize);
    defer allocator.free(buffer);

    _ = try self.file.preadAll(buffer, data_in_code.dataoff);

    var stream = io.fixedBufferStream(buffer);
    var reader = stream.reader();
    while (true) {
        const dice = reader.readStruct(macho.data_in_code_entry) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
        try self.data_in_code_entries.append(allocator, dice);
    }
}

fn readSection(self: Object, allocator: *Allocator, index: u16) ![]u8 {
    const seg = self.load_commands.items[self.segment_cmd_index.?].Segment;
    const sect = seg.sections.items[index];
    var buffer = try allocator.alloc(u8, @intCast(usize, sect.size));
    _ = try self.file.preadAll(buffer, sect.offset);
    return buffer;
}

pub fn getString(self: Object, off: u32) []const u8 {
    assert(off < self.strtab.items.len);
    return mem.spanZ(@ptrCast([*:0]const u8, self.strtab.items.ptr + off));
}
