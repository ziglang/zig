const Object = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const io = std.io;
const log = std.log.scoped(.object);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const parseName = @import("Zld.zig").parseName;

usingnamespace @import("commands.zig");

allocator: *Allocator,
file: fs.File,
name: []u8,
ar_name: ?[]u8 = null,

header: macho.mach_header_64,

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

segment_cmd_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
build_version_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,
text_section_index: ?u16 = null,

// __DWARF segment sections
dwarf_debug_info_index: ?u16 = null,
dwarf_debug_abbrev_index: ?u16 = null,
dwarf_debug_str_index: ?u16 = null,
dwarf_debug_line_index: ?u16 = null,
dwarf_debug_ranges_index: ?u16 = null,

symtab: std.ArrayListUnmanaged(macho.nlist_64) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},

data_in_code_entries: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

pub fn deinit(self: *Object) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);
    self.symtab.deinit(self.allocator);
    self.strtab.deinit(self.allocator);
    self.data_in_code_entries.deinit(self.allocator);
    self.allocator.free(self.name);
    if (self.ar_name) |v| {
        self.allocator.free(v);
    }
    self.file.close();
}

/// Caller owns the returned Object instance and is responsible for calling
/// `deinit` to free allocated memory.
pub fn initFromFile(allocator: *Allocator, arch: std.Target.Cpu.Arch, name: []const u8, file: fs.File) !Object {
    var reader = file.reader();
    const header = try reader.readStruct(macho.mach_header_64);

    if (header.filetype != macho.MH_OBJECT) {
        // Reset file cursor.
        try file.seekTo(0);
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
    if (this_arch != arch) {
        log.err("mismatched cpu architecture: found {s}, expected {s}", .{ this_arch, arch });
        return error.MismatchedCpuArchitecture;
    }

    var self = Object{
        .allocator = allocator,
        .name = try allocator.dupe(u8, name),
        .file = file,
        .header = header,
    };

    try self.readLoadCommands(reader, .{});

    if (self.symtab_cmd_index != null) {
        try self.readSymtab();
        try self.readStrtab();
    }

    if (self.data_in_code_cmd_index != null) try self.readDataInCode();

    log.debug("\n\n", .{});
    log.debug("{s} defines symbols", .{self.name});
    for (self.symtab.items) |sym| {
        const symname = self.getString(sym.n_strx);
        log.debug("'{s}': {}", .{ symname, sym });
    }

    return self;
}

pub const ReadOffset = struct {
    offset: ?u32 = null,
};

pub fn readLoadCommands(self: *Object, reader: anytype, offset: ReadOffset) !void {
    const offset_mod = offset.offset orelse 0;
    try self.load_commands.ensureCapacity(self.allocator, self.header.ncmds);

    var i: u16 = 0;
    while (i < self.header.ncmds) : (i += 1) {
        var cmd = try LoadCommand.read(self.allocator, reader);
        switch (cmd.cmd()) {
            macho.LC_SEGMENT_64 => {
                self.segment_cmd_index = i;
                var seg = cmd.Segment;
                for (seg.sections.items) |*sect, j| {
                    const index = @intCast(u16, j);
                    const segname = parseName(&sect.segname);
                    const sectname = parseName(&sect.sectname);
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
                    }

                    sect.offset += offset_mod;
                    if (sect.reloff > 0)
                        sect.reloff += offset_mod;
                }

                seg.inner.fileoff += offset_mod;
            },
            macho.LC_SYMTAB => {
                self.symtab_cmd_index = i;
                cmd.Symtab.symoff += offset_mod;
                cmd.Symtab.stroff += offset_mod;
            },
            macho.LC_DYSYMTAB => {
                self.dysymtab_cmd_index = i;
            },
            macho.LC_BUILD_VERSION => {
                self.build_version_cmd_index = i;
            },
            macho.LC_DATA_IN_CODE => {
                self.data_in_code_cmd_index = i;
                cmd.LinkeditData.dataoff += offset_mod;
            },
            else => {
                log.debug("Unknown load command detected: 0x{x}.", .{cmd.cmd()});
            },
        }
        self.load_commands.appendAssumeCapacity(cmd);
    }
}

pub fn readSymtab(self: *Object) !void {
    const symtab_cmd = self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    var buffer = try self.allocator.alloc(u8, @sizeOf(macho.nlist_64) * symtab_cmd.nsyms);
    defer self.allocator.free(buffer);
    _ = try self.file.preadAll(buffer, symtab_cmd.symoff);
    try self.symtab.ensureCapacity(self.allocator, symtab_cmd.nsyms);
    // TODO this align case should not be needed.
    // Probably a bug in stage1.
    const slice = @alignCast(@alignOf(macho.nlist_64), mem.bytesAsSlice(macho.nlist_64, buffer));
    self.symtab.appendSliceAssumeCapacity(slice);
}

pub fn readStrtab(self: *Object) !void {
    const symtab_cmd = self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    var buffer = try self.allocator.alloc(u8, symtab_cmd.strsize);
    defer self.allocator.free(buffer);
    _ = try self.file.preadAll(buffer, symtab_cmd.stroff);
    try self.strtab.ensureCapacity(self.allocator, symtab_cmd.strsize);
    self.strtab.appendSliceAssumeCapacity(buffer);
}

pub fn getString(self: *const Object, str_off: u32) []const u8 {
    assert(str_off < self.strtab.items.len);
    return mem.spanZ(@ptrCast([*:0]const u8, self.strtab.items.ptr + str_off));
}

pub fn readSection(self: Object, allocator: *Allocator, index: u16) ![]u8 {
    const seg = self.load_commands.items[self.segment_cmd_index.?].Segment;
    const sect = seg.sections.items[index];
    var buffer = try allocator.alloc(u8, sect.size);
    _ = try self.file.preadAll(buffer, sect.offset);
    return buffer;
}

pub fn readDataInCode(self: *Object) !void {
    const index = self.data_in_code_cmd_index orelse return;
    const data_in_code = self.load_commands.items[index].LinkeditData;

    var buffer = try self.allocator.alloc(u8, data_in_code.datasize);
    defer self.allocator.free(buffer);

    _ = try self.file.preadAll(buffer, data_in_code.dataoff);

    var stream = io.fixedBufferStream(buffer);
    var reader = stream.reader();
    while (true) {
        const dice = reader.readStruct(macho.data_in_code_entry) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
        try self.data_in_code_entries.append(self.allocator, dice);
    }
}
