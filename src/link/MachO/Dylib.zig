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

symbols: std.StringArrayHashMapUnmanaged(*Symbol) = .{},

pub fn init(allocator: *Allocator) Dylib {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Dylib) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);

    for (self.symbols.items()) |entry| {
        entry.value.deinit(self.allocator);
        self.allocator.destroy(entry.value);
    }
    self.symbols.deinit(self.allocator);

    if (self.name) |name| {
        self.allocator.free(name);
    }
}

pub fn closeFile(self: Dylib) void {
    if (self.file) |file| {
        file.close();
    }
}

pub fn parse(self: *Dylib) !void {
    log.warn("parsing shared library '{s}'", .{self.name.?});

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
            else => {
                log.debug("Unknown load command detected: 0x{x}.", .{cmd.cmd()});
            },
        }
        self.load_commands.appendAssumeCapacity(cmd);
    }
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
