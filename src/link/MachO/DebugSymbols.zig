allocator: Allocator,
file: fs.File,

symtab_cmd: macho.symtab_command = .{},
uuid_cmd: macho.uuid_command = .{ .uuid = [_]u8{0} ** 16 },

segments: std.ArrayListUnmanaged(macho.segment_command_64) = .empty,
sections: std.ArrayListUnmanaged(macho.section_64) = .empty,

dwarf_segment_cmd_index: ?u8 = null,
linkedit_segment_cmd_index: ?u8 = null,

debug_info_section_index: ?u8 = null,
debug_abbrev_section_index: ?u8 = null,
debug_str_section_index: ?u8 = null,
debug_aranges_section_index: ?u8 = null,
debug_line_section_index: ?u8 = null,
debug_line_str_section_index: ?u8 = null,
debug_loclists_section_index: ?u8 = null,
debug_rnglists_section_index: ?u8 = null,

relocs: std.ArrayListUnmanaged(Reloc) = .empty,

/// Output synthetic sections
symtab: std.ArrayListUnmanaged(macho.nlist_64) = .empty,
strtab: std.ArrayListUnmanaged(u8) = .empty,

pub const Reloc = struct {
    type: enum {
        direct_load,
        got_load,
    },
    target: u32,
    offset: u64,
    addend: u32,
};

/// You must call this function *after* `ZigObject.initMetadata()`
/// has been called to get a viable debug symbols output.
pub fn initMetadata(self: *DebugSymbols, macho_file: *MachO) !void {
    try self.strtab.append(self.allocator, 0);

    {
        self.dwarf_segment_cmd_index = @as(u8, @intCast(self.segments.items.len));

        const page_size = macho_file.getPageSize();
        const off = @as(u64, @intCast(page_size));
        const ideal_size: u16 = 200 + 128 + 160 + 250;
        const needed_size = mem.alignForward(u64, padToIdeal(ideal_size), page_size);

        log.debug("found __DWARF segment free space 0x{x} to 0x{x}", .{ off, off + needed_size });

        try self.segments.append(self.allocator, .{
            .segname = makeStaticString("__DWARF"),
            .vmsize = needed_size,
            .fileoff = off,
            .filesize = needed_size,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    self.debug_str_section_index = try self.createSection("__debug_str", 0);
    self.debug_info_section_index = try self.createSection("__debug_info", 0);
    self.debug_abbrev_section_index = try self.createSection("__debug_abbrev", 0);
    self.debug_aranges_section_index = try self.createSection("__debug_aranges", 4);
    self.debug_line_section_index = try self.createSection("__debug_line", 0);
    self.debug_line_str_section_index = try self.createSection("__debug_line_str", 0);
    self.debug_loclists_section_index = try self.createSection("__debug_loclists", 0);
    self.debug_rnglists_section_index = try self.createSection("__debug_rnglists", 0);

    self.linkedit_segment_cmd_index = @intCast(self.segments.items.len);
    try self.segments.append(self.allocator, .{
        .segname = makeStaticString("__LINKEDIT"),
        .maxprot = macho.PROT.READ,
        .initprot = macho.PROT.READ,
        .cmdsize = @sizeOf(macho.segment_command_64),
    });
}

fn createSection(self: *DebugSymbols, sectname: []const u8, alignment: u16) !u8 {
    const segment = self.getDwarfSegmentPtr();
    var sect = macho.section_64{
        .sectname = makeStaticString(sectname),
        .segname = segment.segname,
        .@"align" = alignment,
    };

    log.debug("create {s},{s} section", .{ sect.segName(), sect.sectName() });

    const index: u8 = @intCast(self.sections.items.len);
    try self.sections.append(self.allocator, sect);
    segment.cmdsize += @sizeOf(macho.section_64);
    segment.nsects += 1;

    return index;
}

pub fn growSection(
    self: *DebugSymbols,
    sect_index: u8,
    needed_size: u64,
    requires_file_copy: bool,
    macho_file: *MachO,
) !void {
    const sect = self.getSectionPtr(sect_index);

    const allocated_size = self.allocatedSize(sect.offset);
    if (needed_size > allocated_size) {
        const existing_size = sect.size;
        sect.size = 0; // free the space
        const new_offset = try self.findFreeSpace(needed_size, 1);

        log.debug("moving {s} section: {} bytes from 0x{x} to 0x{x}", .{
            sect.sectName(),
            existing_size,
            sect.offset,
            new_offset,
        });

        if (requires_file_copy) {
            const amt = try self.file.copyRangeAll(
                sect.offset,
                self.file,
                new_offset,
                existing_size,
            );
            if (amt != existing_size) return error.InputOutput;
        }

        sect.offset = @intCast(new_offset);
    } else if (sect.offset + allocated_size == std.math.maxInt(u64)) {
        try self.file.setEndPos(sect.offset + needed_size);
    }

    sect.size = needed_size;
    self.markDirty(sect_index, macho_file);
}

pub fn markDirty(self: *DebugSymbols, sect_index: u8, macho_file: *MachO) void {
    if (macho_file.getZigObject()) |zo| {
        if (self.debug_info_section_index.? == sect_index) {
            zo.debug_info_header_dirty = true;
        } else if (self.debug_line_section_index.? == sect_index) {
            zo.debug_line_header_dirty = true;
        } else if (self.debug_abbrev_section_index.? == sect_index) {
            zo.debug_abbrev_dirty = true;
        } else if (self.debug_str_section_index.? == sect_index) {
            zo.debug_strtab_dirty = true;
        } else if (self.debug_aranges_section_index.? == sect_index) {
            zo.debug_aranges_dirty = true;
        }
    }
}

fn detectAllocCollision(self: *DebugSymbols, start: u64, size: u64) !?u64 {
    var at_end = true;
    const end = start + padToIdeal(size);

    for (self.sections.items) |section| {
        const increased_size = padToIdeal(section.size);
        const test_end = section.offset + increased_size;
        if (start < test_end) {
            if (end > section.offset) return test_end;
            if (test_end < std.math.maxInt(u64)) at_end = false;
        }
    }

    if (at_end) try self.file.setEndPos(end);
    return null;
}

fn findFreeSpace(self: *DebugSymbols, object_size: u64, min_alignment: u64) !u64 {
    const segment = self.getDwarfSegmentPtr();
    var offset: u64 = segment.fileoff;
    while (try self.detectAllocCollision(offset, object_size)) |item_end| {
        offset = mem.alignForward(u64, item_end, min_alignment);
    }
    return offset;
}

pub fn flushModule(self: *DebugSymbols, macho_file: *MachO) !void {
    const zo = macho_file.getZigObject().?;
    for (self.relocs.items) |*reloc| {
        const sym = zo.symbols.items[reloc.target];
        const sym_name = sym.getName(macho_file);
        const addr = switch (reloc.type) {
            .direct_load => sym.getAddress(.{}, macho_file),
            .got_load => sym.getGotAddress(macho_file),
        };
        const sect = &self.sections.items[self.debug_info_section_index.?];
        const file_offset = sect.offset + reloc.offset;
        log.debug("resolving relocation: {d}@{x} ('{s}') at offset {x}", .{
            reloc.target,
            addr,
            sym_name,
            file_offset,
        });
        try self.file.pwriteAll(mem.asBytes(&addr), file_offset);
    }

    self.finalizeDwarfSegment(macho_file);
    try self.writeLinkeditSegmentData(macho_file);

    // Write load commands
    const ncmds, const sizeofcmds = try self.writeLoadCommands(macho_file);
    try self.writeHeader(macho_file, ncmds, sizeofcmds);
}

pub fn deinit(self: *DebugSymbols) void {
    const gpa = self.allocator;
    self.file.close();
    self.segments.deinit(gpa);
    self.sections.deinit(gpa);
    self.relocs.deinit(gpa);
    self.symtab.deinit(gpa);
    self.strtab.deinit(gpa);
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

fn finalizeDwarfSegment(self: *DebugSymbols, macho_file: *MachO) void {
    const base_vmaddr = blk: {
        // Note that we purposely take the last VM address of the MachO binary including
        // the binary's LINKEDIT segment. This is in contrast to how dsymutil does it
        // which overwrites the the address space taken by the original MachO binary,
        // however at the cost of having LINKEDIT preceed DWARF in dSYM binary which we
        // do not want as we want to be able to incrementally move DWARF sections in the
        // file as we please.
        const last_seg = macho_file.getLinkeditSegment();
        break :blk last_seg.vmaddr + last_seg.vmsize;
    };
    const dwarf_segment = self.getDwarfSegmentPtr();

    var file_size: u64 = 0;
    for (self.sections.items) |header| {
        file_size = @max(file_size, header.offset + header.size);
    }

    const page_size = macho_file.getPageSize();
    const aligned_size = mem.alignForward(u64, file_size, page_size);
    dwarf_segment.vmaddr = base_vmaddr;
    dwarf_segment.filesize = aligned_size;
    dwarf_segment.vmsize = aligned_size;

    const linkedit = self.getLinkeditSegmentPtr();
    linkedit.vmaddr = mem.alignForward(
        u64,
        dwarf_segment.vmaddr + aligned_size,
        page_size,
    );
    linkedit.fileoff = mem.alignForward(
        u64,
        dwarf_segment.fileoff + aligned_size,
        page_size,
    );
    log.debug("found __LINKEDIT segment free space at 0x{x}", .{linkedit.fileoff});
}

fn writeLoadCommands(self: *DebugSymbols, macho_file: *MachO) !struct { usize, usize } {
    const gpa = self.allocator;
    const needed_size = load_commands.calcLoadCommandsSizeDsym(macho_file, self);
    const buffer = try gpa.alloc(u8, needed_size);
    defer gpa.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    var ncmds: usize = 0;

    // UUID comes first presumably to speed up lookup by the consumer like lldb.
    @memcpy(&self.uuid_cmd.uuid, &macho_file.uuid_cmd.uuid);
    try writer.writeStruct(self.uuid_cmd);
    ncmds += 1;

    // Segment and section load commands
    {
        // Write segment/section headers from the binary file first.
        const slice = macho_file.sections.slice();
        var sect_id: usize = 0;
        for (macho_file.segments.items, 0..) |seg, seg_id| {
            if (seg_id == macho_file.linkedit_seg_index.?) break;
            var out_seg = seg;
            out_seg.fileoff = 0;
            out_seg.filesize = 0;
            try writer.writeStruct(out_seg);
            for (slice.items(.header)[sect_id..][0..seg.nsects]) |header| {
                var out_header = header;
                out_header.offset = 0;
                try writer.writeStruct(out_header);
            }
            sect_id += seg.nsects;
        }
        ncmds += macho_file.segments.items.len - 1;

        // Next, commit DSYM's __LINKEDIT and __DWARF segments headers.
        sect_id = 0;
        for (self.segments.items) |seg| {
            try writer.writeStruct(seg);
            for (self.sections.items[sect_id..][0..seg.nsects]) |header| {
                try writer.writeStruct(header);
            }
            sect_id += seg.nsects;
        }
        ncmds += self.segments.items.len;
    }

    try writer.writeStruct(self.symtab_cmd);
    ncmds += 1;

    assert(stream.pos == needed_size);

    try self.file.pwriteAll(buffer, @sizeOf(macho.mach_header_64));

    return .{ ncmds, buffer.len };
}

fn writeHeader(self: *DebugSymbols, macho_file: *MachO, ncmds: usize, sizeofcmds: usize) !void {
    var header: macho.mach_header_64 = .{};
    header.filetype = macho.MH_DSYM;

    switch (macho_file.getTarget().cpu.arch) {
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

    header.ncmds = @intCast(ncmds);
    header.sizeofcmds = @intCast(sizeofcmds);

    log.debug("writing Mach-O header {}", .{header});

    try self.file.pwriteAll(mem.asBytes(&header), 0);
}

fn allocatedSize(self: *DebugSymbols, start: u64) u64 {
    if (start == 0) return 0;
    const seg = self.getDwarfSegmentPtr();
    assert(start >= seg.fileoff);
    var min_pos: u64 = std.math.maxInt(u64);
    for (self.sections.items) |section| {
        if (section.offset <= start) continue;
        if (section.offset < min_pos) min_pos = section.offset;
    }
    return min_pos - start;
}

fn writeLinkeditSegmentData(self: *DebugSymbols, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const page_size = macho_file.getPageSize();
    const seg = &self.segments.items[self.linkedit_segment_cmd_index.?];

    var off = math.cast(u32, seg.fileoff) orelse return error.Overflow;
    off = try self.writeSymtab(off, macho_file);
    off = mem.alignForward(u32, off, @alignOf(u64));
    off = try self.writeStrtab(off);
    seg.filesize = off - seg.fileoff;

    const aligned_size = mem.alignForward(u64, seg.filesize, page_size);
    seg.vmsize = aligned_size;
}

pub fn writeSymtab(self: *DebugSymbols, off: u32, macho_file: *MachO) !u32 {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = self.allocator;
    const cmd = &self.symtab_cmd;
    cmd.nsyms = macho_file.symtab_cmd.nsyms;
    cmd.strsize = macho_file.symtab_cmd.strsize;
    cmd.symoff = off;

    try self.symtab.resize(gpa, cmd.nsyms);
    try self.strtab.resize(gpa, cmd.strsize);
    self.strtab.items[0] = 0;

    if (macho_file.getZigObject()) |zo| {
        zo.writeSymtab(macho_file, self);
    }
    for (macho_file.objects.items) |index| {
        macho_file.getFile(index).?.writeSymtab(macho_file, self);
    }
    for (macho_file.dylibs.items) |index| {
        macho_file.getFile(index).?.writeSymtab(macho_file, self);
    }
    if (macho_file.getInternalObject()) |internal| {
        internal.writeSymtab(macho_file, self);
    }

    try self.file.pwriteAll(mem.sliceAsBytes(self.symtab.items), cmd.symoff);

    return off + cmd.nsyms * @sizeOf(macho.nlist_64);
}

pub fn writeStrtab(self: *DebugSymbols, off: u32) !u32 {
    const cmd = &self.symtab_cmd;
    cmd.stroff = off;
    try self.file.pwriteAll(self.strtab.items, cmd.stroff);
    return off + cmd.strsize;
}

pub fn getSectionIndexes(self: *DebugSymbols, segment_index: u8) struct { start: u8, end: u8 } {
    var start: u8 = 0;
    const nsects: u8 = for (self.segments.items, 0..) |seg, i| {
        if (i == segment_index) break @intCast(seg.nsects);
        start += @intCast(seg.nsects);
    } else 0;
    return .{ .start = start, .end = start + nsects };
}

fn getDwarfSegmentPtr(self: *DebugSymbols) *macho.segment_command_64 {
    const index = self.dwarf_segment_cmd_index.?;
    return &self.segments.items[index];
}

fn getLinkeditSegmentPtr(self: *DebugSymbols) *macho.segment_command_64 {
    const index = self.linkedit_segment_cmd_index.?;
    return &self.segments.items[index];
}

pub fn getSectionPtr(self: *DebugSymbols, sect: u8) *macho.section_64 {
    assert(sect < self.sections.items.len);
    return &self.sections.items[sect];
}

pub fn getSection(self: DebugSymbols, sect: u8) macho.section_64 {
    assert(sect < self.sections.items.len);
    return self.sections.items[sect];
}

const DebugSymbols = @This();

const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const fs = std.fs;
const link = @import("../../link.zig");
const load_commands = @import("load_commands.zig");
const log = std.log.scoped(.link_dsym);
const macho = std.macho;
const makeStaticString = MachO.makeStaticString;
const math = std.math;
const mem = std.mem;
const padToIdeal = MachO.padToIdeal;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const MachO = @import("../MachO.zig");
const StringTable = @import("../StringTable.zig");
const Type = @import("../../Type.zig");
