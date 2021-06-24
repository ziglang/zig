const Dylib = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.dylib);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Arch = std.Target.Cpu.Arch;
const Symbol = @import("Symbol.zig");
const LibStub = @import("../tapi.zig").LibStub;

usingnamespace @import("commands.zig");

allocator: *Allocator,

arch: ?Arch = null,
header: ?macho.mach_header_64 = null,
file: ?fs.File = null,
name: ?[]const u8 = null,
syslibroot: ?[]const u8 = null,

ordinal: ?u16 = null,

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
id_cmd_index: ?u16 = null,

id: ?Id = null,

/// Parsed symbol table represented as hash map of symbols'
/// names. We can and should defer creating *Symbols until
/// a symbol is referenced by an object file.
symbols: std.StringArrayHashMapUnmanaged(void) = .{},

dependent_libs: std.StringArrayHashMapUnmanaged(void) = .{},

pub const Id = struct {
    name: []const u8,
    timestamp: u32,
    current_version: u32,
    compatibility_version: u32,

    pub fn deinit(id: *Id, allocator: *Allocator) void {
        allocator.free(id.name);
    }
};

pub const Error = error{
    OutOfMemory,
    EmptyStubFile,
    MismatchedCpuArchitecture,
    UnsupportedCpuArchitecture,
} || fs.File.OpenError || std.os.PReadError;

pub fn createAndParseFromPath(
    allocator: *Allocator,
    arch: Arch,
    path: []const u8,
    syslibroot: ?[]const u8,
    recurse_libs: bool,
) Error!?[]*Dylib {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |e| return e,
    };
    errdefer file.close();

    const dylib = try allocator.create(Dylib);
    errdefer allocator.destroy(dylib);

    const name = try allocator.dupe(u8, path);
    errdefer allocator.free(name);

    dylib.* = .{
        .allocator = allocator,
        .arch = arch,
        .name = name,
        .file = file,
        .syslibroot = syslibroot,
    };

    dylib.parse() catch |err| switch (err) {
        error.EndOfStream, error.NotDylib => {
            try file.seekTo(0);

            var lib_stub = LibStub.loadFromFile(allocator, file) catch {
                dylib.deinit();
                allocator.destroy(dylib);
                return null;
            };
            defer lib_stub.deinit();

            try dylib.parseFromStub(lib_stub);
        },
        else => |e| return e,
    };

    var dylibs = std.ArrayList(*Dylib).init(allocator);
    defer dylibs.deinit();
    try dylibs.append(dylib);

    if (recurse_libs) {
        try dylib.parseDependentLibs(&dylibs);
    }

    return dylibs.toOwnedSlice();
}

pub fn deinit(self: *Dylib) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);

    for (self.symbols.keys()) |key| {
        self.allocator.free(key);
    }
    self.symbols.deinit(self.allocator);

    for (self.dependent_libs.keys()) |key| {
        self.allocator.free(key);
    }
    self.dependent_libs.deinit(self.allocator);

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
        log.debug("invalid filetype: expected 0x{x}, found 0x{x}", .{ macho.MH_DYLIB, self.header.?.filetype });
        return error.NotDylib;
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

fn readLoadCommands(self: *Dylib, reader: anytype) !void {
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

fn parseId(self: *Dylib) !void {
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

fn parseSymbols(self: *Dylib) !void {
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
        try self.symbols.putNoClobber(self.allocator, name, {});
    }
}

fn hasTarget(targets: []const []const u8, target: []const u8) bool {
    for (targets) |t| {
        if (mem.eql(u8, t, target)) return true;
    }
    return false;
}

fn addObjCClassSymbols(self: *Dylib, sym_name: []const u8) !void {
    const expanded = &[_][]const u8{
        try std.fmt.allocPrint(self.allocator, "_OBJC_CLASS_$_{s}", .{sym_name}),
        try std.fmt.allocPrint(self.allocator, "_OBJC_METACLASS_$_{s}", .{sym_name}),
    };

    for (expanded) |sym| {
        if (self.symbols.contains(sym)) continue;
        try self.symbols.putNoClobber(self.allocator, sym, .{});
    }
}

pub fn parseFromStub(self: *Dylib, lib_stub: LibStub) !void {
    if (lib_stub.inner.len == 0) return error.EmptyStubFile;

    log.debug("parsing shared library from stub '{s}'", .{self.name.?});

    const umbrella_lib = lib_stub.inner[0];
    self.id = .{
        .name = try self.allocator.dupe(u8, umbrella_lib.install_name),
        // TODO parse from the stub
        .timestamp = 2,
        .current_version = 0,
        .compatibility_version = 0,
    };

    const target_string: []const u8 = switch (self.arch.?) {
        .aarch64 => "arm64-macos",
        .x86_64 => "x86_64-macos",
        else => unreachable,
    };

    for (lib_stub.inner) |stub| {
        if (!hasTarget(stub.targets, target_string)) continue;

        if (stub.reexported_libraries) |reexports| {
            for (reexports) |reexp| {
                if (!hasTarget(reexp.targets, target_string)) continue;

                try self.dependent_libs.ensureUnusedCapacity(self.allocator, reexp.libraries.len);
                for (reexp.libraries) |lib| {
                    self.dependent_libs.putAssumeCapacity(try self.allocator.dupe(u8, lib), {});
                }
            }
        }

        if (stub.exports) |exports| {
            for (exports) |exp| {
                if (!hasTarget(exp.targets, target_string)) continue;

                if (exp.symbols) |symbols| {
                    for (symbols) |sym_name| {
                        if (self.symbols.contains(sym_name)) continue;
                        try self.symbols.putNoClobber(self.allocator, try self.allocator.dupe(u8, sym_name), {});
                    }
                }

                if (exp.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbols(sym_name);
                    }
                }
            }
        }

        if (stub.reexports) |reexports| {
            for (reexports) |reexp| {
                if (!hasTarget(reexp.targets, target_string)) continue;

                if (reexp.symbols) |symbols| {
                    for (symbols) |sym_name| {
                        if (self.symbols.contains(sym_name)) continue;
                        try self.symbols.putNoClobber(self.allocator, try self.allocator.dupe(u8, sym_name), {});
                    }
                }

                if (reexp.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbols(sym_name);
                    }
                }
            }
        }

        if (stub.objc_classes) |classes| {
            for (classes) |sym_name| {
                try self.addObjCClassSymbols(sym_name);
            }
        }
    }
}

pub fn parseDependentLibs(self: *Dylib, out: *std.ArrayList(*Dylib)) !void {
    outer: for (self.dependent_libs.keys()) |lib| {
        const dirname = fs.path.dirname(lib) orelse {
            log.warn("unable to resolve dependency {s}", .{lib});
            continue;
        };
        const filename = fs.path.basename(lib);
        const without_ext = if (mem.lastIndexOfScalar(u8, filename, '.')) |index|
            filename[0..index]
        else
            filename;

        for (&[_][]const u8{ "dylib", "tbd" }) |ext| {
            const with_ext = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{
                without_ext,
                ext,
            });
            defer self.allocator.free(with_ext);

            const lib_path = if (self.syslibroot) |syslibroot|
                try fs.path.join(self.allocator, &.{ syslibroot, dirname, with_ext })
            else
                try fs.path.join(self.allocator, &.{ dirname, with_ext });

            log.debug("trying dependency at fully resolved path {s}", .{lib_path});

            const dylibs = (try createAndParseFromPath(
                self.allocator,
                self.arch.?,
                lib_path,
                self.syslibroot,
                true,
            )) orelse {
                continue;
            };

            try out.appendSlice(dylibs);

            continue :outer;
        } else {
            log.warn("unable to resolve dependency {s}", .{lib});
        }
    }
}

pub fn createProxy(self: *Dylib, sym_name: []const u8) !?*Symbol {
    if (!self.symbols.contains(sym_name)) return null;

    const name = try self.allocator.dupe(u8, sym_name);
    const proxy = try self.allocator.create(Symbol.Proxy);
    errdefer self.allocator.destroy(proxy);

    proxy.* = .{
        .base = .{
            .@"type" = .proxy,
            .name = name,
        },
        .file = self,
    };

    return &proxy.base;
}
