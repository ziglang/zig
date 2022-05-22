const DebugSymbols = @This();

const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const fs = std.fs;
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
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
const TextBlock = MachO.TextBlock;
const Type = @import("../../type.zig").Type;

base: *MachO,
dwarf: Dwarf,
file: fs.File,

/// Table of all load commands
load_commands: std.ArrayListUnmanaged(macho.LoadCommand) = .{},
/// __PAGEZERO segment
pagezero_segment_cmd_index: ?u16 = null,
/// __TEXT segment
text_segment_cmd_index: ?u16 = null,
/// __DATA_CONST segment
data_const_segment_cmd_index: ?u16 = null,
/// __DATA segment
data_segment_cmd_index: ?u16 = null,
/// __LINKEDIT segment
linkedit_segment_cmd_index: ?u16 = null,
/// __DWARF segment
dwarf_segment_cmd_index: ?u16 = null,
/// Symbol table
symtab_cmd_index: ?u16 = null,
/// UUID load command
uuid_cmd_index: ?u16 = null,

/// Index into __TEXT,__text section.
text_section_index: ?u16 = null,

debug_info_section_index: ?u16 = null,
debug_abbrev_section_index: ?u16 = null,
debug_str_section_index: ?u16 = null,
debug_aranges_section_index: ?u16 = null,
debug_line_section_index: ?u16 = null,

load_commands_dirty: bool = false,
debug_string_table_dirty: bool = false,
debug_abbrev_section_dirty: bool = false,
debug_aranges_section_dirty: bool = false,
debug_info_header_dirty: bool = false,
debug_line_header_dirty: bool = false,

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
    if (self.uuid_cmd_index == null) {
        const base_cmd = self.base.load_commands.items[self.base.uuid_cmd_index.?];
        self.uuid_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(allocator, base_cmd);
        self.load_commands_dirty = true;
    }

    if (self.symtab_cmd_index == null) {
        self.symtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.base.allocator, .{
            .symtab = .{
                .cmdsize = @sizeOf(macho.symtab_command),
                .symoff = 0,
                .nsyms = 0,
                .stroff = 0,
                .strsize = 0,
            },
        });
        self.load_commands_dirty = true;
    }

    if (self.pagezero_segment_cmd_index == null) {
        self.pagezero_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.pagezero_segment_cmd_index.?].segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .segment = cmd });
        self.load_commands_dirty = true;
    }

    if (self.text_segment_cmd_index == null) {
        self.text_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.text_segment_cmd_index.?].segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .segment = cmd });
        self.load_commands_dirty = true;
    }

    if (self.data_const_segment_cmd_index == null) outer: {
        if (self.base.data_const_segment_cmd_index == null) break :outer; // __DATA_CONST is optional
        self.data_const_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.data_const_segment_cmd_index.?].segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .segment = cmd });
        self.load_commands_dirty = true;
    }

    if (self.data_segment_cmd_index == null) outer: {
        if (self.base.data_segment_cmd_index == null) break :outer; // __DATA is optional
        self.data_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.data_segment_cmd_index.?].segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .segment = cmd });
        self.load_commands_dirty = true;
    }

    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.linkedit_segment_cmd_index.?].segment;
        var cmd = try self.copySegmentCommand(allocator, base_cmd);
        // TODO this needs reworking
        cmd.inner.vmsize = self.base.page_size;
        cmd.inner.fileoff = self.base.page_size;
        cmd.inner.filesize = self.base.page_size;
        try self.load_commands.append(allocator, .{ .segment = cmd });
        self.load_commands_dirty = true;
    }

    if (self.dwarf_segment_cmd_index == null) {
        self.dwarf_segment_cmd_index = @intCast(u16, self.load_commands.items.len);

        const linkedit = self.load_commands.items[self.linkedit_segment_cmd_index.?].segment;
        const ideal_size: u16 = 200 + 128 + 160 + 250;
        const needed_size = mem.alignForwardGeneric(u64, padToIdeal(ideal_size), self.base.page_size);
        const fileoff = linkedit.inner.fileoff + linkedit.inner.filesize;
        const vmaddr = linkedit.inner.vmaddr + linkedit.inner.vmsize;

        log.debug("found __DWARF segment free space 0x{x} to 0x{x}", .{ fileoff, fileoff + needed_size });

        try self.load_commands.append(allocator, .{
            .segment = .{
                .inner = .{
                    .segname = makeStaticString("__DWARF"),
                    .vmaddr = vmaddr,
                    .vmsize = needed_size,
                    .fileoff = fileoff,
                    .filesize = needed_size,
                    .cmdsize = @sizeOf(macho.segment_command_64),
                },
            },
        });
        self.load_commands_dirty = true;
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

fn allocateSection(self: *DebugSymbols, sectname: []const u8, size: u64, alignment: u16) !u16 {
    const seg = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
    var sect = macho.section_64{
        .sectname = makeStaticString(sectname),
        .segname = seg.inner.segname,
        .size = @intCast(u32, size),
        .@"align" = alignment,
    };
    const alignment_pow_2 = try math.powi(u32, 2, alignment);
    const off = self.findFreeSpace(size, alignment_pow_2);

    assert(off + size <= seg.inner.fileoff + seg.inner.filesize); // TODO expand

    log.debug("found {s},{s} section free space 0x{x} to 0x{x}", .{
        sect.segName(),
        sect.sectName(),
        off,
        off + size,
    });

    sect.addr = seg.inner.vmaddr + off - seg.inner.fileoff;
    sect.offset = @intCast(u32, off);

    const index = @intCast(u16, seg.sections.items.len);
    try seg.sections.append(self.base.base.allocator, sect);
    seg.inner.cmdsize += @sizeOf(macho.section_64);
    seg.inner.nsects += 1;

    // TODO
    // const match = MatchingSection{
    //     .seg = segment_id,
    //     .sect = index,
    // };
    // _ = try self.section_ordinals.getOrPut(self.base.allocator, match);
    // try self.block_free_lists.putNoClobber(self.base.allocator, match, .{});

    self.load_commands_dirty = true;

    return index;
}

fn detectAllocCollision(self: *DebugSymbols, start: u64, size: u64) ?u64 {
    const seg = self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
    const end = start + padToIdeal(size);
    for (seg.sections.items) |section| {
        const increased_size = padToIdeal(section.size);
        const test_end = section.offset + increased_size;
        if (end > section.offset and start < test_end) {
            return test_end;
        }
    }
    return null;
}

pub fn findFreeSpace(self: *DebugSymbols, object_size: u64, min_alignment: u64) u64 {
    const seg = self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
    var offset: u64 = seg.inner.fileoff;
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
            .direct_load => self.base.locals.items[reloc.target],
            .got_load => blk: {
                const got_index = self.base.got_entries_table.get(.{ .local = reloc.target }).?;
                const got_entry = self.base.got_entries.items[got_index];
                break :blk self.base.locals.items[got_entry.atom.local_sym_index];
            },
        };
        if (sym.n_value == reloc.prev_vaddr) continue;

        const seg = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
        const sect = &seg.sections.items[self.debug_info_section_index.?];
        const file_offset = sect.offset + reloc.offset;
        log.debug("resolving relocation: {d}@{x} ('{s}') at offset {x}", .{
            reloc.target,
            sym.n_value,
            self.base.getString(sym.n_strx),
            file_offset,
        });
        try self.file.pwriteAll(mem.asBytes(&sym.n_value), file_offset);
        reloc.prev_vaddr = sym.n_value;
    }

    if (self.debug_abbrev_section_dirty) {
        try self.dwarf.writeDbgAbbrev(&self.base.base);
        self.load_commands_dirty = true;
        self.debug_abbrev_section_dirty = false;
    }

    if (self.debug_info_header_dirty) {
        // Currently only one compilation unit is supported, so the address range is simply
        // identical to the main program header virtual address and memory size.
        const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].segment;
        const text_section = text_segment.sections.items[self.text_section_index.?];
        const low_pc = text_section.addr;
        const high_pc = text_section.addr + text_section.size;
        try self.dwarf.writeDbgInfoHeader(&self.base.base, module, low_pc, high_pc);
        self.debug_info_header_dirty = false;
    }

    if (self.debug_aranges_section_dirty) {
        // Currently only one compilation unit is supported, so the address range is simply
        // identical to the main program header virtual address and memory size.
        const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].segment;
        const text_section = text_segment.sections.items[self.text_section_index.?];
        try self.dwarf.writeDbgAranges(&self.base.base, text_section.addr, text_section.size);
        self.load_commands_dirty = true;
        self.debug_aranges_section_dirty = false;
    }

    if (self.debug_line_header_dirty) {
        try self.dwarf.writeDbgLineHeader(&self.base.base, module);
        self.debug_line_header_dirty = false;
    }

    {
        const dwarf_segment = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
        const debug_strtab_sect = &dwarf_segment.sections.items[self.debug_str_section_index.?];
        if (self.debug_string_table_dirty or self.dwarf.strtab.items.len != debug_strtab_sect.size) {
            const allocated_size = self.allocatedSize(debug_strtab_sect.offset);
            const needed_size = self.dwarf.strtab.items.len;

            if (needed_size > allocated_size) {
                debug_strtab_sect.size = 0; // free the space
                const new_offset = self.findFreeSpace(needed_size, 1);
                debug_strtab_sect.addr = dwarf_segment.inner.vmaddr + new_offset - dwarf_segment.inner.fileoff;
                debug_strtab_sect.offset = @intCast(u32, new_offset);
            }
            debug_strtab_sect.size = @intCast(u32, needed_size);

            log.debug("__debug_strtab start=0x{x} end=0x{x}", .{
                debug_strtab_sect.offset,
                debug_strtab_sect.offset + needed_size,
            });

            try self.file.pwriteAll(self.dwarf.strtab.items, debug_strtab_sect.offset);
            self.load_commands_dirty = true;
            self.debug_string_table_dirty = false;
        }
    }

    self.updateDwarfSegment();
    try self.writeLinkeditSegment();
    try self.updateVirtualMemoryMapping();
    try self.writeLoadCommands(allocator);
    try self.writeHeader();

    assert(!self.load_commands_dirty);
    assert(!self.debug_abbrev_section_dirty);
    assert(!self.debug_aranges_section_dirty);
    assert(!self.debug_string_table_dirty);
}

pub fn deinit(self: *DebugSymbols, allocator: Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(allocator);
    }
    self.load_commands.deinit(allocator);
    self.dwarf.deinit();
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

fn copySegmentCommand(
    self: *DebugSymbols,
    allocator: Allocator,
    base_cmd: macho.SegmentCommand,
) !macho.SegmentCommand {
    var cmd = macho.SegmentCommand{
        .inner = .{
            .segname = undefined,
            .cmdsize = base_cmd.inner.cmdsize,
            .vmaddr = base_cmd.inner.vmaddr,
            .vmsize = base_cmd.inner.vmsize,
            .maxprot = base_cmd.inner.maxprot,
            .initprot = base_cmd.inner.initprot,
            .nsects = base_cmd.inner.nsects,
            .flags = base_cmd.inner.flags,
        },
    };
    mem.copy(u8, &cmd.inner.segname, &base_cmd.inner.segname);

    try cmd.sections.ensureTotalCapacity(allocator, cmd.inner.nsects);
    for (base_cmd.sections.items) |base_sect, i| {
        var sect = macho.section_64{
            .sectname = undefined,
            .segname = undefined,
            .addr = base_sect.addr,
            .size = base_sect.size,
            .offset = 0,
            .@"align" = base_sect.@"align",
            .reloff = 0,
            .nreloc = 0,
            .flags = base_sect.flags,
            .reserved1 = base_sect.reserved1,
            .reserved2 = base_sect.reserved2,
            .reserved3 = base_sect.reserved3,
        };
        mem.copy(u8, &sect.sectname, &base_sect.sectname);
        mem.copy(u8, &sect.segname, &base_sect.segname);

        if (self.base.text_section_index.? == i) {
            self.text_section_index = @intCast(u16, i);
        }

        cmd.sections.appendAssumeCapacity(sect);
    }

    return cmd;
}

fn updateDwarfSegment(self: *DebugSymbols) void {
    const dwarf_segment = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;

    var max_offset: u64 = 0;
    for (dwarf_segment.sections.items) |sect| {
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

    const file_size = max_offset - dwarf_segment.inner.fileoff;
    log.debug("__DWARF size 0x{x}", .{file_size});

    if (file_size != dwarf_segment.inner.filesize) {
        dwarf_segment.inner.filesize = file_size;
        if (dwarf_segment.inner.vmsize < dwarf_segment.inner.filesize) {
            dwarf_segment.inner.vmsize = mem.alignForwardGeneric(u64, dwarf_segment.inner.filesize, self.base.page_size);
        }
        self.load_commands_dirty = true;
    }
}

/// Writes all load commands and section headers.
fn writeLoadCommands(self: *DebugSymbols, allocator: Allocator) !void {
    if (!self.load_commands_dirty) return;

    var sizeofcmds: u32 = 0;
    for (self.load_commands.items) |lc| {
        sizeofcmds += lc.cmdsize();
    }

    var buffer = try allocator.alloc(u8, sizeofcmds);
    defer allocator.free(buffer);
    var fib = std.io.fixedBufferStream(buffer);
    const writer = fib.writer();
    for (self.load_commands.items) |lc| {
        try lc.write(writer);
    }

    const off = @sizeOf(macho.mach_header_64);
    log.debug("writing {} load commands from 0x{x} to 0x{x}", .{ self.load_commands.items.len, off, off + sizeofcmds });
    try self.file.pwriteAll(buffer, off);
    self.load_commands_dirty = false;
}

fn writeHeader(self: *DebugSymbols) !void {
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

    header.ncmds = @intCast(u32, self.load_commands.items.len);
    header.sizeofcmds = 0;

    for (self.load_commands.items) |cmd| {
        header.sizeofcmds += cmd.cmdsize();
    }

    log.debug("writing Mach-O header {}", .{header});

    try self.file.pwriteAll(mem.asBytes(&header), 0);
}

pub fn allocatedSize(self: *DebugSymbols, start: u64) u64 {
    const seg = self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
    assert(start >= seg.inner.fileoff);
    var min_pos: u64 = std.math.maxInt(u64);
    for (seg.sections.items) |section| {
        if (section.offset <= start) continue;
        if (section.offset < min_pos) min_pos = section.offset;
    }
    return min_pos - start;
}

fn updateVirtualMemoryMapping(self: *DebugSymbols) !void {
    const macho_file = self.base;
    const allocator = macho_file.base.allocator;

    const IndexTuple = std.meta.Tuple(&[_]type{ *?u16, *?u16 });
    const indices = &[_]IndexTuple{
        .{ &macho_file.text_segment_cmd_index, &self.text_segment_cmd_index },
        .{ &macho_file.data_const_segment_cmd_index, &self.data_const_segment_cmd_index },
        .{ &macho_file.data_segment_cmd_index, &self.data_segment_cmd_index },
    };

    for (indices) |tuple| {
        const orig_cmd = macho_file.load_commands.items[tuple[0].*.?].segment;
        const cmd = try self.copySegmentCommand(allocator, orig_cmd);
        const comp_cmd = &self.load_commands.items[tuple[1].*.?];
        comp_cmd.deinit(allocator);
        self.load_commands.items[tuple[1].*.?] = .{ .segment = cmd };
    }

    // TODO should we set the linkedit vmsize to that of the binary?
    const orig_cmd = macho_file.load_commands.items[macho_file.linkedit_segment_cmd_index.?].segment;
    const orig_vmaddr = orig_cmd.inner.vmaddr;
    const linkedit_cmd = &self.load_commands.items[self.linkedit_segment_cmd_index.?].segment;
    linkedit_cmd.inner.vmaddr = orig_vmaddr;

    // Update VM address for the DWARF segment and sections including re-running relocations.
    // TODO re-run relocations
    const dwarf_cmd = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
    const new_start_aligned = orig_vmaddr + linkedit_cmd.inner.vmsize;
    const old_start_aligned = dwarf_cmd.inner.vmaddr;
    const diff = new_start_aligned - old_start_aligned;
    if (diff > 0) {
        dwarf_cmd.inner.vmaddr = new_start_aligned;

        for (dwarf_cmd.sections.items) |*sect| {
            sect.addr += (new_start_aligned - old_start_aligned);
        }
    }

    self.load_commands_dirty = true;
}

fn writeLinkeditSegment(self: *DebugSymbols) !void {
    const tracy = trace(@src());
    defer tracy.end();

    try self.writeSymbolTable();
    try self.writeStringTable();

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].segment;
    const aligned_size = mem.alignForwardGeneric(u64, seg.inner.filesize, self.base.page_size);
    seg.inner.filesize = aligned_size;
    seg.inner.vmsize = aligned_size;
}

fn writeSymbolTable(self: *DebugSymbols) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].symtab;
    symtab.symoff = @intCast(u32, seg.inner.fileoff);

    var locals = std.ArrayList(macho.nlist_64).init(self.base.base.allocator);
    defer locals.deinit();

    for (self.base.locals.items) |sym| {
        if (sym.n_strx == 0) continue;
        if (self.base.symbol_resolver.get(sym.n_strx)) |_| continue;
        try locals.append(sym);
    }

    const nlocals = locals.items.len;
    const nexports = self.base.globals.items.len;
    const locals_off = symtab.symoff;
    const locals_size = nlocals * @sizeOf(macho.nlist_64);
    const exports_off = locals_off + locals_size;
    const exports_size = nexports * @sizeOf(macho.nlist_64);

    symtab.nsyms = @intCast(u32, nlocals + nexports);
    const needed_size = (nlocals + nexports) * @sizeOf(macho.nlist_64);

    if (needed_size > seg.inner.filesize) {
        const aligned_size = mem.alignForwardGeneric(u64, needed_size, self.base.page_size);
        const diff = @intCast(u32, aligned_size - seg.inner.filesize);
        const dwarf_seg = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
        seg.inner.filesize = aligned_size;

        try MachO.copyRangeAllOverlappingAlloc(
            self.base.base.allocator,
            self.file,
            dwarf_seg.inner.fileoff,
            dwarf_seg.inner.fileoff + diff,
            math.cast(usize, dwarf_seg.inner.filesize) orelse return error.Overflow,
        );

        const old_seg_fileoff = dwarf_seg.inner.fileoff;
        dwarf_seg.inner.fileoff += diff;

        log.debug("  (moving __DWARF segment from 0x{x} to 0x{x})", .{ old_seg_fileoff, dwarf_seg.inner.fileoff });

        for (dwarf_seg.sections.items) |*sect| {
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

    log.debug("writing local symbols from 0x{x} to 0x{x}", .{ locals_off, locals_size + locals_off });
    try self.file.pwriteAll(mem.sliceAsBytes(locals.items), locals_off);

    log.debug("writing exported symbols from 0x{x} to 0x{x}", .{ exports_off, exports_size + exports_off });
    try self.file.pwriteAll(mem.sliceAsBytes(self.base.globals.items), exports_off);

    self.load_commands_dirty = true;
}

fn writeStringTable(self: *DebugSymbols) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].symtab;
    const symtab_size = @intCast(u32, symtab.nsyms * @sizeOf(macho.nlist_64));
    symtab.stroff = symtab.symoff + symtab_size;

    const needed_size = mem.alignForwardGeneric(u64, self.base.strtab.items.len, @alignOf(u64));
    symtab.strsize = @intCast(u32, needed_size);

    if (symtab_size + needed_size > seg.inner.filesize) {
        const aligned_size = mem.alignForwardGeneric(u64, symtab_size + needed_size, self.base.page_size);
        const diff = @intCast(u32, aligned_size - seg.inner.filesize);
        const dwarf_seg = &self.load_commands.items[self.dwarf_segment_cmd_index.?].segment;
        seg.inner.filesize = aligned_size;

        try MachO.copyRangeAllOverlappingAlloc(
            self.base.base.allocator,
            self.file,
            dwarf_seg.inner.fileoff,
            dwarf_seg.inner.fileoff + diff,
            math.cast(usize, dwarf_seg.inner.filesize) orelse return error.Overflow,
        );

        const old_seg_fileoff = dwarf_seg.inner.fileoff;
        dwarf_seg.inner.fileoff += diff;

        log.debug("  (moving __DWARF segment from 0x{x} to 0x{x})", .{ old_seg_fileoff, dwarf_seg.inner.fileoff });

        for (dwarf_seg.sections.items) |*sect| {
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

    log.debug("writing string table from 0x{x} to 0x{x}", .{ symtab.stroff, symtab.stroff + symtab.strsize });

    try self.file.pwriteAll(self.base.strtab.items, symtab.stroff);

    self.load_commands_dirty = true;
}
