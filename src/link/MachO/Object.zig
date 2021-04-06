const Object = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const io = std.io;
const log = std.log.scoped(.object);
const macho = std.macho;
const mem = std.mem;
const reloc = @import("reloc.zig");

const Allocator = mem.Allocator;
const Relocation = reloc.Relocation;
const Symbol = @import("Symbol.zig");
const parseName = @import("Zld.zig").parseName;

usingnamespace @import("commands.zig");

allocator: *Allocator,
arch: ?std.Target.Cpu.Arch = null,
header: ?macho.mach_header_64 = null,
file: ?fs.File = null,
file_offset: ?u32 = null,
name: ?[]u8 = null,

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},
sections: std.ArrayListUnmanaged(Section) = .{},

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

symtab: std.ArrayListUnmanaged(Symbol) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},

data_in_code_entries: std.ArrayListUnmanaged(macho.data_in_code_entry) = .{},

pub const Section = struct {
    inner: macho.section_64,
    code: []u8,
    relocs: ?[]*Relocation,

    pub fn deinit(self: *Section, allocator: *Allocator) void {
        allocator.free(self.code);

        if (self.relocs) |relocs| {
            for (relocs) |rel| {
                allocator.destroy(rel);
            }
            allocator.free(relocs);
        }
    }
};

pub fn init(allocator: *Allocator) Object {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Object) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);

    for (self.sections.items) |*sect| {
        sect.deinit(self.allocator);
    }
    self.sections.deinit(self.allocator);

    self.symtab.deinit(self.allocator);
    self.strtab.deinit(self.allocator);
    self.data_in_code_entries.deinit(self.allocator);

    if (self.name) |n| {
        self.allocator.free(n);
    }
}

pub fn closeFile(self: Object) void {
    if (self.file) |f| {
        f.close();
    }
}

pub fn parse(self: *Object) !void {
    var reader = self.file.?.reader();
    if (self.file_offset) |offset| {
        try reader.context.seekTo(offset);
    }

    self.header = try reader.readStruct(macho.mach_header_64);

    if (self.header.?.filetype != macho.MH_OBJECT) {
        log.err("invalid filetype: expected 0x{x}, found 0x{x}", .{ macho.MH_OBJECT, self.header.?.filetype });
        return error.MalformedObject;
    }

    const this_arch: std.Target.Cpu.Arch = switch (self.header.?.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |value| {
            log.err("unsupported cpu architecture 0x{x}", .{value});
            return error.UnsupportedCpuArchitecture;
        },
    };
    if (this_arch != self.arch.?) {
        log.err("mismatched cpu architecture: expected {s}, found {s}", .{ self.arch.?, this_arch });
        return error.MismatchedCpuArchitecture;
    }

    try self.readLoadCommands(reader);
    try self.parseSections();
    if (self.symtab_cmd_index != null) try self.parseSymtab();
    if (self.data_in_code_cmd_index != null) try self.readDataInCode();
}

pub fn readLoadCommands(self: *Object, reader: anytype) !void {
    const offset = self.file_offset orelse 0;
    try self.load_commands.ensureCapacity(self.allocator, self.header.?.ncmds);

    var i: u16 = 0;
    while (i < self.header.?.ncmds) : (i += 1) {
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

pub fn parseSections(self: *Object) !void {
    const seg = self.load_commands.items[self.segment_cmd_index.?].Segment;

    try self.sections.ensureCapacity(self.allocator, seg.sections.items.len);

    for (seg.sections.items) |sect| {
        // Read sections' code
        var code = try self.allocator.alloc(u8, sect.size);
        _ = try self.file.?.preadAll(code, sect.offset);

        var section = Section{
            .inner = sect,
            .code = code,
            .relocs = undefined,
        };

        // Parse relocations
        var relocs: ?[]*Relocation = if (sect.nreloc > 0) relocs: {
            var raw_relocs = try self.allocator.alloc(u8, @sizeOf(macho.relocation_info) * sect.nreloc);
            defer self.allocator.free(raw_relocs);

            _ = try self.file.?.preadAll(raw_relocs, sect.reloff);

            break :relocs try reloc.parse(
                self.allocator,
                &section.code,
                mem.bytesAsSlice(macho.relocation_info, raw_relocs),
            );
        } else null;

        self.sections.appendAssumeCapacity(section);
    }
}

pub fn parseSymtab(self: *Object) !void {
    const symtab_cmd = self.load_commands.items[self.symtab_cmd_index.?].Symtab;

    var symtab = try self.allocator.alloc(u8, @sizeOf(macho.nlist_64) * symtab_cmd.nsyms);
    defer self.allocator.free(symtab);

    _ = try self.file.?.preadAll(symtab, symtab_cmd.symoff);
    try self.symtab.ensureCapacity(self.allocator, symtab_cmd.nsyms);

    var stream = std.io.fixedBufferStream(symtab);
    var reader = stream.reader();

    while (true) {
        const symbol = reader.readStruct(macho.nlist_64) catch |err| switch (err) {
            error.EndOfStream => break,
            else => |e| return e,
        };
        const tag: Symbol.Tag = tag: {
            if (Symbol.isLocal(symbol)) {
                if (Symbol.isStab(symbol))
                    break :tag .Stab
                else
                    break :tag .Local;
            } else if (Symbol.isGlobal(symbol)) {
                if (Symbol.isWeakDef(symbol))
                    break :tag .Weak
                else
                    break :tag .Strong;
            } else {
                break :tag .Undef;
            }
        };
        self.symtab.appendAssumeCapacity(.{
            .tag = tag,
            .inner = symbol,
        });
    }

    var strtab = try self.allocator.alloc(u8, symtab_cmd.strsize);
    defer self.allocator.free(strtab);

    _ = try self.file.?.preadAll(strtab, symtab_cmd.stroff);
    try self.strtab.appendSlice(self.allocator, strtab);
}

pub fn getString(self: *const Object, str_off: u32) []const u8 {
    assert(str_off < self.strtab.items.len);
    return mem.spanZ(@ptrCast([*:0]const u8, self.strtab.items.ptr + str_off));
}

pub fn readSection(self: Object, allocator: *Allocator, index: u16) ![]u8 {
    const seg = self.load_commands.items[self.segment_cmd_index.?].Segment;
    const sect = seg.sections.items[index];
    var buffer = try allocator.alloc(u8, sect.size);
    _ = try self.file.?.preadAll(buffer, sect.offset);
    return buffer;
}

pub fn readDataInCode(self: *Object) !void {
    const index = self.data_in_code_cmd_index orelse return;
    const data_in_code = self.load_commands.items[index].LinkeditData;

    var buffer = try self.allocator.alloc(u8, data_in_code.datasize);
    defer self.allocator.free(buffer);

    _ = try self.file.?.preadAll(buffer, data_in_code.dataoff);

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
