const DebugSymbols = @This();

const std = @import("std");
const fs = std.fs;
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

pub fn deinit(self: *DebugSymbols, allocator: *Allocator) void {
    self.file.close();
}
