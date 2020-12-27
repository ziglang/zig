const DebugSymbols = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;
const DW = std.dwarf;
const leb = std.leb;
const Allocator = mem.Allocator;

const trace = @import("../../tracy.zig").trace;
const MachO = @import("../MachO.zig");
const satMul = MachO.satMul;
const alloc_num = MachO.alloc_num;
const alloc_den = MachO.alloc_den;

usingnamespace @import("commands.zig");

base: *MachO,
file: fs.File,

/// Mach header
header: ?macho.mach_header_64 = null,

/// Table of all load commands
load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},
/// __PAGEZERO segment
pagezero_segment_cmd_index: ?u16 = null,
/// __TEXT segment
text_segment_cmd_index: ?u16 = null,
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

linkedit_off: u16 = 0x1000,
linkedit_size: u16 = 0x1000,

header_dirty: bool = false,
load_commands_dirty: bool = false,
string_table_dirty: bool = false,

/// You must call this function *after* `MachO.populateMissingMetadata()`
/// has been called to get a viable debug symbols output.
pub fn populateMissingMetadata(self: *DebugSymbols, allocator: *Allocator) !void {
    if (self.header == null) {
        const base_header = self.base.header.?;
        var header: macho.mach_header_64 = undefined;
        header.magic = macho.MH_MAGIC_64;
        header.cputype = base_header.cputype;
        header.cpusubtype = base_header.cpusubtype;
        header.filetype = macho.MH_DSYM;
        // These will get populated at the end of flushing the results to file.
        header.ncmds = 0;
        header.sizeofcmds = 0;
        header.flags = 0;
        header.reserved = 0;
        self.header = header;
        self.header_dirty = true;
    }
    if (self.uuid_cmd_index == null) {
        const base_cmd = self.base.load_commands.items[self.base.uuid_cmd_index.?];
        self.uuid_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(allocator, base_cmd);
        self.header_dirty = true;
        self.load_commands_dirty = true;
    }
    if (self.symtab_cmd_index == null) {
        self.symtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.symtab_cmd_index.?].Symtab;
        const symtab_size = base_cmd.nsyms * @sizeOf(macho.nlist_64);
        const symtab_off = self.findFreeSpaceLinkedit(symtab_size, @sizeOf(macho.nlist_64));

        log.debug("found dSym symbol table free space 0x{x} to 0x{x}", .{ symtab_off, symtab_off + symtab_size });

        const strtab_off = self.findFreeSpaceLinkedit(base_cmd.strsize, 1);

        log.debug("found dSym string table free space 0x{x} to 0x{x}", .{ strtab_off, strtab_off + base_cmd.strsize });

        try self.load_commands.append(allocator, .{
            .Symtab = .{
                .cmd = macho.LC_SYMTAB,
                .cmdsize = @sizeOf(macho.symtab_command),
                .symoff = @intCast(u32, symtab_off),
                .nsyms = base_cmd.nsyms,
                .stroff = @intCast(u32, strtab_off),
                .strsize = base_cmd.strsize,
            },
        });
        try self.writeLocalSymbol(0);
        self.header_dirty = true;
        self.load_commands_dirty = true;
        self.string_table_dirty = true;
    }
    if (self.pagezero_segment_cmd_index == null) {
        self.pagezero_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.pagezero_segment_cmd_index.?].Segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .Segment = cmd });
        self.header_dirty = true;
        self.load_commands_dirty = true;
    }
    if (self.text_segment_cmd_index == null) {
        self.text_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.text_segment_cmd_index.?].Segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .Segment = cmd });
        self.header_dirty = true;
        self.load_commands_dirty = true;
    }
    if (self.data_segment_cmd_index == null) outer: {
        if (self.base.data_segment_cmd_index == null) break :outer; // __DATA is optional
        self.data_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.data_segment_cmd_index.?].Segment;
        const cmd = try self.copySegmentCommand(allocator, base_cmd);
        try self.load_commands.append(allocator, .{ .Segment = cmd });
        self.header_dirty = true;
        self.load_commands_dirty = true;
    }
    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.linkedit_segment_cmd_index.?].Segment;
        var cmd = try self.copySegmentCommand(allocator, base_cmd);
        cmd.inner.vmsize = self.linkedit_size;
        cmd.inner.fileoff = self.linkedit_off;
        cmd.inner.filesize = self.linkedit_size;
        try self.load_commands.append(allocator, .{ .Segment = cmd });
        self.header_dirty = true;
        self.load_commands_dirty = true;
    }
}

pub fn flush(self: *DebugSymbols, allocator: *Allocator) !void {
    try self.writeStringTable();
    try self.writeLoadCommands(allocator);
    try self.writeHeader();

    assert(!self.header_dirty);
    assert(!self.load_commands_dirty);
    assert(!self.string_table_dirty);
}

pub fn deinit(self: *DebugSymbols, allocator: *Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(allocator);
    }
    self.file.close();
}

fn copySegmentCommand(self: *DebugSymbols, allocator: *Allocator, base_cmd: SegmentCommand) !SegmentCommand {
    var cmd = SegmentCommand.empty(.{
        .cmd = macho.LC_SEGMENT_64,
        .cmdsize = base_cmd.inner.cmdsize,
        .segname = undefined,
        .vmaddr = base_cmd.inner.vmaddr,
        .vmsize = base_cmd.inner.vmsize,
        .fileoff = 0,
        .filesize = 0,
        .maxprot = base_cmd.inner.maxprot,
        .initprot = base_cmd.inner.initprot,
        .nsects = base_cmd.inner.nsects,
        .flags = base_cmd.inner.flags,
    });
    mem.copy(u8, &cmd.inner.segname, &base_cmd.inner.segname);

    try cmd.sections.ensureCapacity(allocator, cmd.inner.nsects);
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

/// Writes all load commands and section headers.
fn writeLoadCommands(self: *DebugSymbols, allocator: *Allocator) !void {
    if (!self.load_commands_dirty) return;

    var sizeofcmds: usize = 0;
    for (self.load_commands.items) |lc| {
        sizeofcmds += lc.cmdsize();
    }

    var buffer = try allocator.alloc(u8, sizeofcmds);
    defer allocator.free(buffer);
    var writer = std.io.fixedBufferStream(buffer).writer();
    for (self.load_commands.items) |lc| {
        try lc.write(writer);
    }

    const off = @sizeOf(macho.mach_header_64);
    log.debug("writing {} dSym load commands from 0x{x} to 0x{x}", .{ self.load_commands.items.len, off, off + sizeofcmds });
    try self.file.pwriteAll(buffer, off);
    self.load_commands_dirty = false;
}

fn writeHeader(self: *DebugSymbols) !void {
    if (!self.header_dirty) return;

    self.header.?.ncmds = @intCast(u32, self.load_commands.items.len);
    var sizeofcmds: u32 = 0;
    for (self.load_commands.items) |cmd| {
        sizeofcmds += cmd.cmdsize();
    }
    self.header.?.sizeofcmds = sizeofcmds;
    log.debug("writing Mach-O dSym header {}", .{self.header.?});
    try self.file.pwriteAll(mem.asBytes(&self.header.?), 0);
    self.header_dirty = false;
}

fn allocatedSizeLinkedit(self: *DebugSymbols, start: u64) u64 {
    assert(start > 0);
    var min_pos: u64 = std.math.maxInt(u64);

    if (self.symtab_cmd_index) |idx| {
        const symtab = self.load_commands.items[idx].Symtab;
        if (symtab.symoff >= start and symtab.symoff < min_pos) min_pos = symtab.symoff;
        if (symtab.stroff >= start and symtab.stroff < min_pos) min_pos = symtab.stroff;
    }

    return min_pos - start;
}

fn detectAllocCollisionLinkedit(self: *DebugSymbols, start: u64, size: u64) ?u64 {
    const end = start + satMul(size, alloc_num) / alloc_den;

    if (self.symtab_cmd_index) |idx| outer: {
        if (self.load_commands.items.len == idx) break :outer;
        const symtab = self.load_commands.items[idx].Symtab;
        {
            // Symbol table
            const symsize = symtab.nsyms * @sizeOf(macho.nlist_64);
            const increased_size = satMul(symsize, alloc_num) / alloc_den;
            const test_end = symtab.symoff + increased_size;
            if (end > symtab.symoff and start < test_end) {
                return test_end;
            }
        }
        {
            // String table
            const increased_size = satMul(symtab.strsize, alloc_num) / alloc_den;
            const test_end = symtab.stroff + increased_size;
            if (end > symtab.stroff and start < test_end) {
                return test_end;
            }
        }
    }

    return null;
}

fn findFreeSpaceLinkedit(self: *DebugSymbols, object_size: u64, min_alignment: u16) u64 {
    var start: u64 = self.linkedit_off;
    while (self.detectAllocCollisionLinkedit(start, object_size)) |item_end| {
        start = mem.alignForwardGeneric(u64, item_end, min_alignment);
    }
    return start;
}

fn relocateSymbolTable(self: *DebugSymbols) !void {
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    const nlocals = self.base.local_symbols.items.len;
    const nglobals = self.base.global_symbols.items.len;
    const nsyms = nlocals + nglobals;

    if (symtab.nsyms < nsyms) {
        const linkedit_segment = self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
        const needed_size = nsyms * @sizeOf(macho.nlist_64);
        if (needed_size > self.allocatedSizeLinkedit(symtab.symoff)) {
            // Move the entire symbol table to a new location
            const new_symoff = self.findFreeSpaceLinkedit(needed_size, @alignOf(macho.nlist_64));
            const existing_size = symtab.nsyms * @sizeOf(macho.nlist_64);

            assert(new_symoff + existing_size <= self.linkedit_off + self.linkedit_size);
            log.debug("relocating dSym symbol table from 0x{x}-0x{x} to 0x{x}-0x{x}", .{
                symtab.symoff,
                symtab.symoff + existing_size,
                new_symoff,
                new_symoff + existing_size,
            });

            const amt = try self.file.copyRangeAll(symtab.symoff, self.file, new_symoff, existing_size);
            if (amt != existing_size) return error.InputOutput;
            symtab.symoff = @intCast(u32, new_symoff);
        }
        symtab.nsyms = @intCast(u32, nsyms);
        self.load_commands_dirty = true;
    }
}

pub fn writeLocalSymbol(self: *DebugSymbols, index: usize) !void {
    const tracy = trace(@src());
    defer tracy.end();
    try self.relocateSymbolTable();
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    const off = symtab.symoff + @sizeOf(macho.nlist_64) * index;
    log.debug("writing dSym local symbol {} at 0x{x}", .{ index, off });
    try self.file.pwriteAll(mem.asBytes(&self.base.local_symbols.items[index]), off);
}

pub fn writeStringTable(self: *DebugSymbols) !void {
    if (!self.string_table_dirty) return;

    const tracy = trace(@src());
    defer tracy.end();

    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    const allocated_size = self.allocatedSizeLinkedit(symtab.stroff);
    const needed_size = mem.alignForwardGeneric(u64, self.base.string_table.items.len, @alignOf(u64));

    if (needed_size > allocated_size) {
        symtab.strsize = 0;
        symtab.stroff = @intCast(u32, self.findFreeSpaceLinkedit(needed_size, 1));
    }
    symtab.strsize = @intCast(u32, needed_size);
    log.debug("writing dSym string table from 0x{x} to 0x{x}", .{ symtab.stroff, symtab.stroff + symtab.strsize });

    try self.file.pwriteAll(self.base.string_table.items, symtab.stroff);
    self.load_commands_dirty = true;
    self.string_table_dirty = false;
}
