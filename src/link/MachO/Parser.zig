const Parser = @This();

const std = @import("std");
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const macho = std.macho;

const Allocator = std.mem.Allocator;

const LoadCommand = @import("commands.zig").LoadCommand;

allocator: *Allocator,

/// Mach-O header
header: ?macho.mach_header_64 = null,

/// Load commands
load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

text_cmd_index: ?usize = null,

linkedit_cmd_index: ?usize = null,
linkedit_cmd_offset: ?u64 = null,

code_sig_cmd_offset: ?u64 = null,

end_pos: ?u64 = null,

pub fn init(allocator: *Allocator) Parser {
    return .{
        .allocator = allocator,
    };
}

pub fn parse(self: *Parser, reader: anytype) !void {
    self.header = try reader.readStruct(macho.mach_header_64);

    const ncmds = self.header.?.ncmds;
    try self.load_commands.ensureCapacity(self.allocator, ncmds);

    var off: u64 = @sizeOf(macho.mach_header_64);
    var i: u16 = 0;
    while (i < ncmds) : (i += 1) {
        const cmd = try LoadCommand.read(self.allocator, reader);
        switch (cmd.cmd()) {
            macho.LC_SEGMENT_64 => {
                const x = cmd.Segment;
                if (mem.eql(u8, mem.trimRight(u8, x.inner.segname[0..], &[_]u8{0}), "__LINKEDIT")) {
                    self.linkedit_cmd_index = i;
                    self.linkedit_cmd_offset = off;
                } else if (mem.eql(u8, mem.trimRight(u8, x.inner.segname[0..], &[_]u8{0}), "__TEXT")) {
                    self.text_cmd_index = i;
                }
            },
            macho.LC_SYMTAB => {
                const x = cmd.Symtab;
                self.end_pos = x.stroff + x.strsize;
            },
            else => {},
        }
        off += cmd.cmdsize();
        self.load_commands.appendAssumeCapacity(cmd);
    }

    self.code_sig_cmd_offset = off;

    // TODO parse memory mapped segments
}

pub fn parseFile(self: *Parser, file: fs.File) !void {
    return self.parse(file.reader());
}

pub fn deinit(self: *Parser) void {
    for (self.load_commands.items) |*cmd| {
        cmd.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);
}
