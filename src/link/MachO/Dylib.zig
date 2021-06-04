const Dylib = @This();

const std = @import("std");
const fs = std.fs;
const log = std.log.scoped(.dylib);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Symbol = @import("Symbol.zig");

usingnamespace @import("commands.zig");

allocator: *Allocator,
arch: ?std.Target.Cpu.Arch = null,
header: ?macho.mach_header_64 = null,
file: ?fs.File = null,
name: ?[]const u8 = null,

ordinal: ?u16 = null,

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
id_cmd_index: ?u16 = null,

id: ?Id = null,

symbols: std.StringArrayHashMapUnmanaged(*Symbol) = .{},

pub const Id = struct {
    name: []const u8,
    timestamp: u32,
    current_version: u32,
    compatibility_version: u32,

    pub fn deinit(id: *Id, allocator: *Allocator) void {
        allocator.free(id.name);
    }
};

pub fn init(allocator: *Allocator) Dylib {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Dylib) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);

    for (self.symbols.values()) |value| {
        value.deinit(self.allocator);
        self.allocator.destroy(value);
    }
    self.symbols.deinit(self.allocator);

    if (self.name) |name| {
        self.allocator.free(name);
    }

    if (self.id) |*id| {
        id.deinit(self.allocator);
    }
}

pub fn closeFile(self: Dylib) void {
    if (self.file) |file| {
        file.close();
    }
}

pub fn parse(self: *Dylib) !void {
    log.debug("parsing shared library '{s}'", .{self.name.?});

    var reader = self.file.?.reader();
    self.header = try reader.readStruct(macho.mach_header_64);

    if (self.header.?.filetype != macho.MH_DYLIB) {
        log.err("invalid filetype: expected 0x{x}, found 0x{x}", .{ macho.MH_DYLIB, self.header.?.filetype });
        return error.MalformedDylib;
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
    try self.parseId();
    try self.parseSymbols();
}

pub fn readLoadCommands(self: *Dylib, reader: anytype) !void {
    try self.load_commands.ensureCapacity(self.allocator, self.header.?.ncmds);

    var i: u16 = 0;
    while (i < self.header.?.ncmds) : (i += 1) {
        var cmd = try LoadCommand.read(self.allocator, reader);
        switch (cmd.cmd()) {
            macho.LC_SYMTAB => {
                self.symtab_cmd_index = i;
            },
            macho.LC_DYSYMTAB => {
                self.dysymtab_cmd_index = i;
            },
            macho.LC_ID_DYLIB => {
                self.id_cmd_index = i;
            },
            else => {
                log.debug("Unknown load command detected: 0x{x}.", .{cmd.cmd()});
            },
        }
        self.load_commands.appendAssumeCapacity(cmd);
    }
}

pub fn parseId(self: *Dylib) !void {
    const index = self.id_cmd_index orelse {
        log.debug("no LC_ID_DYLIB load command found; using hard-coded defaults...", .{});
        self.id = .{
            .name = try self.allocator.dupe(u8, self.name.?),
            .timestamp = 2,
            .current_version = 0,
            .compatibility_version = 0,
        };
        return;
    };
    const id_cmd = self.load_commands.items[index].Dylib;
    const dylib = id_cmd.inner.dylib;

    // TODO should we compare the name from the dylib's id with the user-specified one?
    const dylib_name = @ptrCast([*:0]const u8, id_cmd.data[dylib.name - @sizeOf(macho.dylib_command) ..]);
    const name = try self.allocator.dupe(u8, mem.spanZ(dylib_name));

    self.id = .{
        .name = name,
        .timestamp = dylib.timestamp,
        .current_version = dylib.current_version,
        .compatibility_version = dylib.compatibility_version,
    };
}

pub fn parseSymbols(self: *Dylib) !void {
    const index = self.symtab_cmd_index orelse return;
    const symtab_cmd = self.load_commands.items[index].Symtab;

    var symtab = try self.allocator.alloc(u8, @sizeOf(macho.nlist_64) * symtab_cmd.nsyms);
    defer self.allocator.free(symtab);
    _ = try self.file.?.preadAll(symtab, symtab_cmd.symoff);
    const slice = @alignCast(@alignOf(macho.nlist_64), mem.bytesAsSlice(macho.nlist_64, symtab));

    var strtab = try self.allocator.alloc(u8, symtab_cmd.strsize);
    defer self.allocator.free(strtab);
    _ = try self.file.?.preadAll(strtab, symtab_cmd.stroff);

    for (slice) |sym| {
        const sym_name = mem.spanZ(@ptrCast([*:0]const u8, strtab.ptr + sym.n_strx));

        if (!(Symbol.isSect(sym) and Symbol.isExt(sym))) continue;

        const name = try self.allocator.dupe(u8, sym_name);
        const proxy = try self.allocator.create(Symbol.Proxy);
        errdefer self.allocator.destroy(proxy);

        proxy.* = .{
            .base = .{
                .@"type" = .proxy,
                .name = name,
            },
            .dylib = self,
        };

        try self.symbols.putNoClobber(self.allocator, name, &proxy.base);
    }
}

pub fn isDylib(file: fs.File) !bool {
    const header = try file.reader().readStruct(macho.mach_header_64);
    try file.seekTo(0);
    return header.filetype == macho.MH_DYLIB;
}
