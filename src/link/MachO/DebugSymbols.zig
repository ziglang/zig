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
/// __DWARF segment
dwarf_segment_cmd_index: ?u16 = null,
/// __DATA segment
data_segment_cmd_index: ?u16 = null,
/// __LINKEDIT segment
linkedit_segment_cmd_index: ?u16 = null,
/// Symbol table
symtab_cmd_index: ?u16 = null,
/// UUID load command
uuid_cmd_index: ?u16 = null,

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
}

pub fn flush(self: *DebugSymbols) !void {
    try self.writeHeader();
    assert(!self.header_dirty);
    assert(!self.load_commands_dirty);
}

pub fn deinit(self: *DebugSymbols, allocator: *Allocator) void {
    self.file.close();
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
