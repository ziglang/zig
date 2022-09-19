const DebugSymbols = @This();

const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const fs = std.fs;
const link = @import("../../link.zig");
const log = std.log.scoped(.dsym);
const macho = std.macho;
const makeStaticString = MachO.makeStaticString;
const math = std.math;
const mem = std.mem;
const padToIdeal = MachO.padToIdeal;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Dwarf = @import("../Dwarf.zig");
const MachO = @import("../MachO.zig");
const Module = @import("../../Module.zig");
const StringTable = @import("../strtab.zig").StringTable;
const Type = @import("../../type.zig").Type;

base: *MachO,
dwarf: Dwarf,
file: fs.File,

segments: std.ArrayListUnmanaged(macho.segment_command_64) = .{},
sections: std.ArrayListUnmanaged(macho.section_64) = .{},

linkedit_segment_cmd_index: ?u8 = null,
dwarf_segment_cmd_index: ?u8 = null,

debug_info_section_index: ?u8 = null,
debug_abbrev_section_index: ?u8 = null,
debug_str_section_index: ?u8 = null,
debug_aranges_section_index: ?u8 = null,
debug_line_section_index: ?u8 = null,

debug_string_table_dirty: bool = false,
debug_abbrev_section_dirty: bool = false,
debug_aranges_section_dirty: bool = false,
debug_info_header_dirty: bool = false,
debug_line_header_dirty: bool = false,

strtab: StringTable(.strtab) = .{},

relocs: std.ArrayListUnmanaged(Reloc) = .{},

pub const Reloc = struct {
    @"type": enum {
        direct_load,
        got_load,
    },
    target: u32,
    offset: u64,
    addend: u32,
    prev_vaddr: u64,
};

/// You must call this function *after* `MachO.populateMissingMetadata()`
/// has been called to get a viable debug symbols output.
pub fn populateMissingMetadata(self: *DebugSymbols, allocator: Allocator) !void {
    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @intCast(u8, self.segments.items.len);
        const fileoff = @intCast(u64, self.base.page_size);
        const needed_size = @intCast(u64, self.base.page_size) * 2;
        log.debug("found __LINKEDIT segment free space 0x{x} to 0x{x}", .{ fileoff, needed_size });
        // TODO this needs reworking
        try self.segments.append(allocator, .{
            .segname = makeStaticString("__LINKEDIT"),
            .vmaddr = fileoff,
            .vmsize = needed_size,
            .fileoff = fileoff,
            .filesize = needed_size,
            .maxprot = macho.PROT.READ,
            .initprot = macho.PROT.READ,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (self.dwarf_segment_cmd_index == null) {
        self.dwarf_segment_cmd_index = @intCast(u8, self.segments.items.len);

        const linkedit = self.segments.items[self.linkedit_segment_cmd_index.?];
        const ideal_size: u16 = 200 + 128 + 160 + 250;
        const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.base.page_size);
        const fileoff = linkedit.fileoff + linkedit.filesize;
        const vmaddr = linkedit.vmaddr + linkedit.vmsize;

        log.debug("found __DWARF segment free space 0x{x} to 0x{x}", .{ fileoff, fileoff + needed_size });

        try self.segments.append(allocator, .{
            .segname = makeStaticString("__DWARF"),
            .vmaddr = vmaddr,
            .vmsize = needed_size,
            .fileoff = fileoff,
            .filesize = needed_size,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (self.debug_str_section_index == null) {
        assert(self.dwarf.strtab.items.len == 0);
        self.debug_str_section_index = try self.allocateSection(
            "__debug_str",
            @intCast(u32, self.dwarf.strtab.items.len),
            0,
        );
        self.debug_string_table_dirty = true;
    }

    if (self.debug_info_section_index == null) {
        self.debug_info_section_index = try self.allocateSection("__debug_info", 200, 0);
        self.debug_info_header_dirty = true;
    }

    if (self.debug_abbrev_section_index == null) {
        self.debug_abbrev_section_index = try self.allocateSection("__debug_abbrev", 128, 0);
        self.debug_abbrev_section_dirty = true;
    }

    if (self.debug_aranges_section_index == null) {
        self.debug_aranges_section_index = try self.allocateSection("__debug_aranges", 160, 4);
        self.debug_aranges_section_dirty = true;
    }

    if (self.debug_line_section_index == null) {
        self.debug_line_section_index = try self.allocateSection("__debug_line", 250, 0);
        self.debug_line_header_dirty = true;
    }
}

fn allocateSection(self: *DebugSymbols, sectname: []const u8, size: u64, alignment: u16) !u8 {
    const segment = &self.segments.items[self.dwarf_segment_cmd_index.?];
    var sect = macho.section_64{
        .sectname = makeStaticString(sectname),
        .segname = segment.segname,
        .size = @intCast(u32, size),
        .@"align" = alignment,
    };
    const alignment_pow_2 = try math.powi(u32, 2, alignment);
    const off = self.findFreeSpace(size, alignment_pow_2);

    assert(off + size <= segment.fileoff + segment.filesize); // TODO expand

    log.debug("found {s},{s} section free space 0x{x} to 0x{x}", .{
        sect.segName(),
        sect.sectName(),
        off,
        off + size,
    });

    sect.addr = segment.vmaddr + off - segment.fileoff;
    sect.offset = @intCast(u32, off);

    const index = @intCast(u8, self.sections.items.len);
    try self.sections.append(self.base.base.allocator, sect);
    segment.cmdsize += @sizeOf(macho.section_64);
    segment.nsects += 1;

    return index;
}

fn detectAllocCollision(self: *DebugSymbols, start: u64, size: u64) ?u64 {
    const end = start + padToIdeal(size);
    for (self.sections.items) |section| {
        const increased_size = padToIdeal(section.size);
        const test_end = section.offset + increased_size;
        if (end > section.offset and start < test_end) {
            return test_end;
        }
    }
    return null;
}

pub fn findFreeSpace(self: *DebugSymbols, object_size: u64, min_alignment: u64) u64 {
    const segment = self.segments.items[self.dwarf_segment_cmd_index.?];
    var offset: u64 = segment.fileoff;
    while (self.detectAllocCollision(offset, object_size)) |item_end| {
        offset = mem.alignForwardGeneric(u64, item_end, min_alignment);
    }
    return offset;
}

pub fn flushModule(self: *DebugSymbols, allocator: Allocator, options: link.Options) !void {
    // TODO This linker code currently assumes there is only 1 compilation unit and it corresponds to the
    // Zig source code.
    const module = options.module orelse return error.LinkingWithoutZigSourceUnimplemented;

    for (self.relocs.items) |*reloc| {
        const sym = switch (reloc.@"type") {
            .direct_load => self.base.getSymbol(.{ .sym_index = reloc.target, .file = null }),
            .got_load => blk: {
                const got_index = self.base.got_entries_table.get(.{
                    .sym_index = reloc.target,
                    .file = null,
                }).?;
                const got_entry = self.base.got_entries.items[got_index];
                break :blk got_entry.getSymbol(self.base);
            },
        };
        if (sym.n_value == reloc.prev_vaddr) continue;

        const sym_name = switch (reloc.@"type") {
            .direct_load => self.base.getSymbolName(.{ .sym_index = reloc.target, .file = null }),
            .got_load => blk: {
                const got_index = self.base.got_entries_table.get(.{
                    .sym_index = reloc.target,
                    .file = null,
                }).?;
                const got_entry = self.base.got_entries.items[got_index];
                break :blk got_entry.getName(self.base);
            },
        };
        const sect = &self.sections.items[self.debug_info_section_index.?];
        const file_offset = sect.offset + reloc.offset;
        log.debug("resolving relocation: {d}@{x} ('{s}') at offset {x}", .{
            reloc.target,
            sym.n_value,
            sym_name,
            file_offset,
        });
        try self.file.pwriteAll(mem.asBytes(&sym.n_value), file_offset);
        reloc.prev_vaddr = sym.n_value;
    }

    if (self.debug_abbrev_section_dirty) {
        try self.dwarf.writeDbgAbbrev(&self.base.base);
        self.debug_abbrev_section_dirty = false;
    }

    if (self.debug_info_header_dirty) {
        // Currently only one compilation unit is supported, so the address range is simply
        // identical to the main program header virtual address and memory size.
        const text_section = self.base.sections.items(.header)[self.base.text_section_index.?];
        const low_pc = text_section.addr;
        const high_pc = text_section.addr + text_section.size;
        try self.dwarf.writeDbgInfoHeader(&self.base.base, module, low_pc, high_pc);
        self.debug_info_header_dirty = false;
    }

    if (self.debug_aranges_section_dirty) {
        // Currently only one compilation unit is supported, so the address range is simply
        // identical to the main program header virtual address and memory size.
        const text_section = self.base.sections.items(.header)[self.base.text_section_index.?];
        try self.dwarf.writeDbgAranges(&self.base.base, text_section.addr, text_section.size);
        self.debug_aranges_section_dirty = false;
    }

    if (self.debug_line_header_dirty) {
        try self.dwarf.writeDbgLineHeader(&self.base.base, module);
        self.debug_line_header_dirty = false;
    }

    {
        const dwarf_segment = &self.segments.items[self.dwarf_segment_cmd_index.?];
        const debug_strtab_sect = &self.sections.items[self.debug_str_section_index.?];
        if (self.debug_string_table_dirty or self.dwarf.strtab.items.len != debug_strtab_sect.size) {
            const allocated_size = self.allocatedSize(debug_strtab_sect.offset);
            const needed_size = self.dwarf.strtab.items.len;

            if (needed_size > allocated_size) {
                debug_strtab_sect.size = 0; // free the space
                const new_offset = self.findFreeSpace(needed_size, 1);
                debug_strtab_sect.addr = dwarf_segment.vmaddr + new_offset - dwarf_segment.fileoff;
                debug_strtab_sect.offset = @intCast(u32, new_offset);
            }
            debug_strtab_sect.size = @intCast(u32, needed_size);

            log.debug("__debug_strtab start=0x{x} end=0x{x}", .{
                debug_strtab_sect.offset,
                debug_strtab_sect.offset + needed_size,
            });

            try self.file.pwriteAll(self.dwarf.strtab.items, debug_strtab_sect.offset);
            self.debug_string_table_dirty = false;
        }
    }

    var lc_buffer = std.ArrayList(u8).init(allocator);
    defer lc_buffer.deinit();
    const lc_writer = lc_buffer.writer();
    var ncmds: u32 = 0;

    self.updateDwarfSegment();
    try self.writeLinkeditSegmentData(&ncmds, lc_writer);
    self.updateDwarfSegment();

    {
        try lc_writer.writeStruct(self.base.uuid);
        ncmds += 1;
    }

    var headers_buf = std.ArrayList(u8).init(allocator);
    defer headers_buf.deinit();
    try self.writeSegmentHeaders(&ncmds, headers_buf.writer());

    try self.file.pwriteAll(headers_buf.items, @sizeOf(macho.mach_header_64));
    try self.file.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64) + headers_buf.items.len);

    try self.writeHeader(ncmds, @intCast(u32, lc_buffer.items.len + headers_buf.items.len));

    assert(!self.debug_abbrev_section_dirty);
    assert(!self.debug_aranges_section_dirty);
    assert(!self.debug_string_table_dirty);
}

pub fn deinit(self: *DebugSymbols, allocator: Allocator) void {
    self.file.close();
    self.segments.deinit(allocator);
    self.sections.deinit(allocator);
    self.dwarf.deinit();
    self.strtab.deinit(allocator);
    self.relocs.deinit(allocator);
}

pub fn swapRemoveRelocs(self: *DebugSymbols, target: u32) void {
    // TODO re-implement using a hashmap with free lists
    var last_index: usize = 0;
    while (last_index < self.relocs.items.len) {
        const reloc = self.relocs.items[last_index];
        if (reloc.target == target) {
            _ = self.relocs.swapRemove(last_index);
        } else {
            last_index += 1;
        }
    }
}

fn updateDwarfSegment(self: *DebugSymbols) void {
    const linkedit = self.segments.items[self.linkedit_segment_cmd_index.?];
    const dwarf_segment = &self.segments.items[self.dwarf_segment_cmd_index.?];

    const new_start_aligned = linkedit.vmaddr + linkedit.vmsize;
    const old_start_aligned = dwarf_segment.vmaddr;
    const diff = new_start_aligned - old_start_aligned;
    if (diff > 0) {
        dwarf_segment.vmaddr = new_start_aligned;
    }

    var max_offset: u64 = 0;
    for (self.sections.items) |*sect| {
        sect.addr += diff;
        log.debug("  {s},{s} - 0x{x}-0x{x} - 0x{x}-0x{x}", .{
            sect.segName(),
            sect.sectName(),
            sect.offset,
            sect.offset + sect.size,
            sect.addr,
            sect.addr + sect.size,
        });
        if (sect.offset + sect.size > max_offset) {
            max_offset = sect.offset + sect.size;
        }
    }

    const file_size = max_offset - dwarf_segment.fileoff;
    log.debug("__DWARF size 0x{x}", .{file_size});

    if (file_size != dwarf_segment.filesize) {
        dwarf_segment.filesize = file_size;
        dwarf_segment.vmsize = mem.alignForwardGeneric(u64, dwarf_segment.filesize, self.base.page_size);
    }
}

fn writeSegmentHeaders(self: *DebugSymbols, ncmds: *u32, writer: anytype) !void {
    // Write segment/section headers from the binary file first.
    const end = self.base.linkedit_segment_cmd_index.?;
    for (self.base.segments.items[0..end]) |seg, i| {
        const indexes = self.base.getSectionIndexes(@intCast(u8, i));
        var out_seg = seg;
        out_seg.fileoff = 0;
        out_seg.filesize = 0;
        out_seg.cmdsize = @sizeOf(macho.segment_command_64);
        out_seg.nsects = 0;

        // Update section headers count; any section with size of 0 is excluded
        // since it doesn't have any data in the final binary file.
        for (self.base.sections.items(.header)[indexes.start..indexes.end]) |header| {
            if (header.size == 0) continue;
            out_seg.cmdsize += @sizeOf(macho.section_64);
            out_seg.nsects += 1;
        }

        if (out_seg.nsects == 0 and
            (mem.eql(u8, out_seg.segName(), "__DATA_CONST") or
            mem.eql(u8, out_seg.segName(), "__DATA"))) continue;

        try writer.writeStruct(out_seg);
        for (self.base.sections.items(.header)[indexes.start..indexes.end]) |header| {
            if (header.size == 0) continue;
            var out_header = header;
            out_header.offset = 0;
            try writer.writeStruct(out_header);
        }

        ncmds.* += 1;
    }
    // Next, commit DSYM's __LINKEDIT and __DWARF segments headers.
    for (self.segments.items) |seg| {
        try writer.writeStruct(seg);
        ncmds.* += 1;
    }
    for (self.sections.items) |header| {
        try writer.writeStruct(header);
    }
}

fn writeHeader(self: *DebugSymbols, ncmds: u32, sizeofcmds: u32) !void {
    var header: macho.mach_header_64 = .{};
    header.filetype = macho.MH_DSYM;

    switch (self.base.base.options.target.cpu.arch) {
        .aarch64 => {
            header.cputype = macho.CPU_TYPE_ARM64;
            header.cpusubtype = macho.CPU_SUBTYPE_ARM_ALL;
        },
        .x86_64 => {
            header.cputype = macho.CPU_TYPE_X86_64;
            header.cpusubtype = macho.CPU_SUBTYPE_X86_64_ALL;
        },
        else => return error.UnsupportedCpuArchitecture,
    }

    header.ncmds = ncmds;
    header.sizeofcmds = sizeofcmds;

    log.debug("writing Mach-O header {}", .{header});

    try self.file.pwriteAll(mem.asBytes(&header), 0);
}

pub fn allocatedSize(self: *DebugSymbols, start: u64) u64 {
    const seg = self.segments.items[self.dwarf_segment_cmd_index.?];
    assert(start >= seg.fileoff);
    var min_pos: u64 = std.math.maxInt(u64);
    for (self.sections.items) |section| {
        if (section.offset <= start) continue;
        if (section.offset < min_pos) min_pos = section.offset;
    }
    return min_pos - start;
}

fn writeLinkeditSegmentData(self: *DebugSymbols, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const source_vmaddr = self.base.segments.items[self.base.linkedit_segment_cmd_index.?].vmaddr;
    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    seg.vmaddr = source_vmaddr;

    var symtab_cmd = macho.symtab_command{
        .cmdsize = @sizeOf(macho.symtab_command),
        .symoff = 0,
        .nsyms = 0,
        .stroff = 0,
        .strsize = 0,
    };
    try self.writeSymtab(&symtab_cmd);
    try self.writeStrtab(&symtab_cmd);
    try lc_writer.writeStruct(symtab_cmd);
    ncmds.* += 1;

    const aligned_size = mem.alignForwardGeneric(u64, seg.filesize, self.base.page_size);
    seg.filesize = aligned_size;
    seg.vmsize = aligned_size;
}

fn writeSymtab(self: *DebugSymbols, lc: *macho.symtab_command) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = self.base.base.allocator;

    var locals = std.ArrayList(macho.nlist_64).init(gpa);
    defer locals.deinit();

    for (self.base.locals.items) |sym, sym_id| {
        if (sym.n_strx == 0) continue; // no name, skip
        if (sym.n_desc == MachO.N_DESC_GCED) continue; // GCed, skip
        const sym_loc = MachO.SymbolWithLoc{ .sym_index = @intCast(u32, sym_id), .file = null };
        if (self.base.symbolIsTemp(sym_loc)) continue; // local temp symbol, skip
        if (self.base.getGlobal(self.base.getSymbolName(sym_loc)) != null) continue; // global symbol is either an export or import, skip
        var out_sym = sym;
        out_sym.n_strx = try self.strtab.insert(gpa, self.base.getSymbolName(sym_loc));
        try locals.append(out_sym);
    }

    var exports = std.ArrayList(macho.nlist_64).init(gpa);
    defer exports.deinit();

    for (self.base.globals.items) |global| {
        const sym = self.base.getSymbol(global);
        if (sym.undf()) continue; // import, skip
        if (sym.n_desc == MachO.N_DESC_GCED) continue; // GCed, skip
        var out_sym = sym;
        out_sym.n_strx = try self.strtab.insert(gpa, self.base.getSymbolName(global));
        try exports.append(out_sym);
    }

    const nlocals = locals.items.len;
    const nexports = exports.items.len;
    const nsyms = nlocals + nexports;

    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff, @alignOf(macho.nlist_64));
    const needed_size = nsyms * @sizeOf(macho.nlist_64);

    if (needed_size > seg.filesize) {
        const aligned_size = mem.alignForwardGeneric(u64, needed_size, self.base.page_size);
        const diff = @intCast(u32, aligned_size - seg.filesize);
        const dwarf_seg = &self.segments.items[self.dwarf_segment_cmd_index.?];
        seg.filesize = aligned_size;

        try copyRangeAllOverlappingAlloc(
            self.base.base.allocator,
            self.file,
            dwarf_seg.fileoff,
            dwarf_seg.fileoff + diff,
            math.cast(usize, dwarf_seg.filesize) orelse return error.Overflow,
        );

        const old_seg_fileoff = dwarf_seg.fileoff;
        dwarf_seg.fileoff += diff;

        log.debug("  (moving __DWARF segment from 0x{x} to 0x{x})", .{ old_seg_fileoff, dwarf_seg.fileoff });

        for (self.sections.items) |*sect| {
            const old_offset = sect.offset;
            sect.offset += diff;

            log.debug("  (moving {s},{s} from 0x{x} to 0x{x})", .{
                sect.segName(),
                sect.sectName(),
                old_offset,
                sect.offset,
            });
        }
    }

    lc.symoff = @intCast(u32, offset);
    lc.nsyms = @intCast(u32, nsyms);

    const locals_off = lc.symoff;
    const locals_size = nlocals * @sizeOf(macho.nlist_64);
    const exports_off = locals_off + locals_size;
    const exports_size = nexports * @sizeOf(macho.nlist_64);

    log.debug("writing local symbols from 0x{x} to 0x{x}", .{ locals_off, locals_size + locals_off });
    try self.file.pwriteAll(mem.sliceAsBytes(locals.items), locals_off);

    log.debug("writing exported symbols from 0x{x} to 0x{x}", .{ exports_off, exports_size + exports_off });
    try self.file.pwriteAll(mem.sliceAsBytes(exports.items), exports_off);
}

fn writeStrtab(self: *DebugSymbols, lc: *macho.symtab_command) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];
    const symtab_size = @intCast(u32, lc.nsyms * @sizeOf(macho.nlist_64));
    const offset = mem.alignForwardGeneric(u64, lc.symoff + symtab_size, @alignOf(u64));
    lc.stroff = @intCast(u32, offset);

    const needed_size = mem.alignForwardGeneric(u64, self.strtab.buffer.items.len, @alignOf(u64));
    lc.strsize = @intCast(u32, needed_size);

    if (symtab_size + needed_size > seg.filesize) {
        const aligned_size = mem.alignForwardGeneric(u64, offset + needed_size, self.base.page_size);
        const diff = @intCast(u32, aligned_size - seg.filesize);
        const dwarf_seg = &self.segments.items[self.dwarf_segment_cmd_index.?];
        seg.filesize = aligned_size;

        try copyRangeAllOverlappingAlloc(
            self.base.base.allocator,
            self.file,
            dwarf_seg.fileoff,
            dwarf_seg.fileoff + diff,
            math.cast(usize, dwarf_seg.filesize) orelse return error.Overflow,
        );

        const old_seg_fileoff = dwarf_seg.fileoff;
        dwarf_seg.fileoff += diff;

        log.debug("  (moving __DWARF segment from 0x{x} to 0x{x})", .{ old_seg_fileoff, dwarf_seg.fileoff });

        for (self.sections.items) |*sect| {
            const old_offset = sect.offset;
            sect.offset += diff;

            log.debug("  (moving {s},{s} from 0x{x} to 0x{x})", .{
                sect.segName(),
                sect.sectName(),
                old_offset,
                sect.offset,
            });
        }
    }

    log.debug("writing string table from 0x{x} to 0x{x}", .{ lc.stroff, lc.stroff + lc.strsize });

    try self.file.pwriteAll(self.strtab.buffer.items, lc.stroff);
}

fn copyRangeAllOverlappingAlloc(
    allocator: Allocator,
    file: std.fs.File,
    in_offset: u64,
    out_offset: u64,
    len: usize,
) !void {
    const buf = try allocator.alloc(u8, len);
    defer allocator.free(buf);
    const amt = try file.preadAll(buf, in_offset);
    try file.pwriteAll(buf[0..amt], out_offset);
}
