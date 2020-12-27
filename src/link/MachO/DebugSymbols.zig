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

const MachO = @import("../MachO.zig");

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

header_dirty: bool = false,
load_commands_dirty: bool = false,

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
    if (self.pagezero_segment_cmd_index == null) {
        self.pagezero_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.pagezero_segment_cmd_index.?].Segment;
        try self.copySegmentCommand(allocator, base_cmd);
    }
    if (self.text_segment_cmd_index == null) {
        self.text_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.text_segment_cmd_index.?].Segment;
        try self.copySegmentCommand(allocator, base_cmd);
    }
    if (self.data_segment_cmd_index == null) outer: {
        if (self.base.data_segment_cmd_index == null) break :outer; // __DATA is optional
        self.data_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        const base_cmd = self.base.load_commands.items[self.base.data_segment_cmd_index.?].Segment;
        try self.copySegmentCommand(allocator, base_cmd);
    }
    if (self.uuid_cmd_index == null) {
        const base_cmd = self.base.load_commands.items[self.base.uuid_cmd_index.?];
        self.uuid_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(allocator, base_cmd);
        self.header_dirty = true;
        self.load_commands_dirty = true;
    }
}

pub fn flush(self: *DebugSymbols, allocator: *Allocator) !void {
    try self.writeLoadCommands(allocator);
    try self.writeHeader();
    assert(!self.header_dirty);
    assert(!self.load_commands_dirty);
}

pub fn deinit(self: *DebugSymbols, allocator: *Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(allocator);
    }
    self.file.close();
}

fn copySegmentCommand(self: *DebugSymbols, allocator: *Allocator, base_cmd: SegmentCommand) !void {
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

    try self.load_commands.append(allocator, .{ .Segment = cmd });
    self.header_dirty = true;
    self.load_commands_dirty = true;
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
