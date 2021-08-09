const Dylib = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const fmt = std.fmt;
const log = std.log.scoped(.dylib);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const fat = @import("fat.zig");
const commands = @import("commands.zig");

const Allocator = mem.Allocator;
const Arch = std.Target.Cpu.Arch;
const LibStub = @import("../tapi.zig").LibStub;
const LoadCommand = commands.LoadCommand;
const MachO = @import("../MachO.zig");

file: fs.File,
name: []const u8,

header: ?macho.mach_header_64 = null,

// The actual dylib contents we care about linking with will be embedded at
// an offset within a file if we are linking against a fat lib
library_offset: u64 = 0,

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
id_cmd_index: ?u16 = null,

id: ?Id = null,

/// Parsed symbol table represented as hash map of symbols'
/// names. We can and should defer creating *Symbols until
/// a symbol is referenced by an object file.
symbols: std.StringArrayHashMapUnmanaged(void) = .{},

/// Array list of all dependent libs of this dylib.
dependent_libs: std.ArrayListUnmanaged(Id) = .{},

pub const Id = struct {
    name: []const u8,
    timestamp: u32,
    current_version: u32,
    compatibility_version: u32,

    pub fn default(allocator: *Allocator, name: []const u8) !Id {
        return Id{
            .name = try allocator.dupe(u8, name),
            .timestamp = 2,
            .current_version = 0x10000,
            .compatibility_version = 0x10000,
        };
    }

    pub fn fromLoadCommand(allocator: *Allocator, lc: commands.GenericCommandWithData(macho.dylib_command)) !Id {
        const dylib = lc.inner.dylib;
        const dylib_name = @ptrCast([*:0]const u8, lc.data[dylib.name - @sizeOf(macho.dylib_command) ..]);
        const name = try allocator.dupe(u8, mem.spanZ(dylib_name));

        return Id{
            .name = name,
            .timestamp = dylib.timestamp,
            .current_version = dylib.current_version,
            .compatibility_version = dylib.compatibility_version,
        };
    }

    pub fn deinit(id: *Id, allocator: *Allocator) void {
        allocator.free(id.name);
    }

    const ParseError = fmt.ParseIntError || fmt.BufPrintError;

    pub fn parseCurrentVersion(id: *Id, version: anytype) ParseError!void {
        id.current_version = try parseVersion(version);
    }

    pub fn parseCompatibilityVersion(id: *Id, version: anytype) ParseError!void {
        id.compatibility_version = try parseVersion(version);
    }

    fn parseVersion(version: anytype) ParseError!u32 {
        const string = blk: {
            switch (version) {
                .int => |int| {
                    var out: u32 = 0;
                    const major = try math.cast(u16, int);
                    out += @intCast(u32, major) << 16;
                    return out;
                },
                .float => |float| {
                    var buf: [256]u8 = undefined;
                    break :blk try fmt.bufPrint(&buf, "{d:.2}", .{float});
                },
                .string => |string| {
                    break :blk string;
                },
            }
        };

        var out: u32 = 0;
        var values: [3][]const u8 = undefined;

        var split = mem.split(u8, string, ".");
        var count: u4 = 0;
        while (split.next()) |value| {
            if (count > 2) {
                log.warn("malformed version field: {s}", .{string});
                return 0x10000;
            }
            values[count] = value;
            count += 1;
        }

        if (count > 2) {
            out += try fmt.parseInt(u8, values[2], 10);
        }
        if (count > 1) {
            out += @intCast(u32, try fmt.parseInt(u8, values[1], 10)) << 8;
        }
        out += @intCast(u32, try fmt.parseInt(u16, values[0], 10)) << 16;

        return out;
    }
};

pub const Error = error{
    OutOfMemory,
    EmptyStubFile,
    MismatchedCpuArchitecture,
    UnsupportedCpuArchitecture,
} || fs.File.OpenError || std.os.PReadError || Id.ParseError;

pub const CreateOpts = struct {
    syslibroot: ?[]const u8 = null,
    id: ?Id = null,
};

pub fn createAndParseFromPath(
    allocator: *Allocator,
    arch: Arch,
    path: []const u8,
    opts: CreateOpts,
) Error!?[]Dylib {
    const file = fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |e| return e,
    };
    errdefer file.close();

    const name = try allocator.dupe(u8, path);
    errdefer allocator.free(name);

    var dylib = Dylib{
        .name = name,
        .file = file,
    };

    dylib.parse(allocator, arch) catch |err| switch (err) {
        error.EndOfStream, error.NotDylib => {
            try file.seekTo(0);

            var lib_stub = LibStub.loadFromFile(allocator, file) catch {
                dylib.deinit(allocator);
                return null;
            };
            defer lib_stub.deinit();

            try dylib.parseFromStub(allocator, arch, lib_stub);
        },
        else => |e| return e,
    };

    if (opts.id) |id| {
        if (dylib.id.?.current_version < id.compatibility_version) {
            log.warn("found dylib is incompatible with the required minimum version", .{});
            log.warn("  | dylib: {s}", .{id.name});
            log.warn("  | required minimum version: {}", .{id.compatibility_version});
            log.warn("  | dylib version: {}", .{dylib.id.?.current_version});

            // TODO maybe this should be an error and facilitate auto-cleanup?
            dylib.deinit(allocator);
            return null;
        }
    }

    var dylibs = std.ArrayList(Dylib).init(allocator);
    defer dylibs.deinit();

    try dylibs.append(dylib);
    // TODO this should not be performed if the user specifies `-flat_namespace` flag.
    // See ld64 manpages.
    try dylib.parseDependentLibs(allocator, arch, &dylibs, opts.syslibroot);

    return dylibs.toOwnedSlice();
}

pub fn deinit(self: *Dylib, allocator: *Allocator) void {
    for (self.load_commands.items) |*lc| {
        lc.deinit(allocator);
    }
    self.load_commands.deinit(allocator);

    for (self.symbols.keys()) |key| {
        allocator.free(key);
    }
    self.symbols.deinit(allocator);

    for (self.dependent_libs.items) |*id| {
        id.deinit(allocator);
    }
    self.dependent_libs.deinit(allocator);
    allocator.free(self.name);

    if (self.id) |*id| {
        id.deinit(allocator);
    }
}

pub fn parse(self: *Dylib, allocator: *Allocator, arch: Arch) !void {
    log.debug("parsing shared library '{s}'", .{self.name});

    self.library_offset = try fat.getLibraryOffset(self.file.reader(), arch);

    try self.file.seekTo(self.library_offset);

    var reader = self.file.reader();
    self.header = try reader.readStruct(macho.mach_header_64);

    if (self.header.?.filetype != macho.MH_DYLIB) {
        log.debug("invalid filetype: expected 0x{x}, found 0x{x}", .{ macho.MH_DYLIB, self.header.?.filetype });
        return error.NotDylib;
    }

    const this_arch: Arch = try fat.decodeArch(self.header.?.cputype, true);

    if (this_arch != arch) {
        log.err("mismatched cpu architecture: expected {s}, found {s}", .{ arch, this_arch });
        return error.MismatchedCpuArchitecture;
    }

    try self.readLoadCommands(allocator, reader);
    try self.parseId(allocator);
    try self.parseSymbols(allocator);
}

fn readLoadCommands(self: *Dylib, allocator: *Allocator, reader: anytype) !void {
    const should_lookup_reexports = self.header.?.flags & macho.MH_NO_REEXPORTED_DYLIBS == 0;

    try self.load_commands.ensureCapacity(allocator, self.header.?.ncmds);

    var i: u16 = 0;
    while (i < self.header.?.ncmds) : (i += 1) {
        var cmd = try LoadCommand.read(allocator, reader);
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
            macho.LC_REEXPORT_DYLIB => {
                if (should_lookup_reexports) {
                    // Parse install_name to dependent dylib.
                    const id = try Id.fromLoadCommand(allocator, cmd.Dylib);
                    try self.dependent_libs.append(allocator, id);
                }
            },
            else => {
                log.debug("Unknown load command detected: 0x{x}.", .{cmd.cmd()});
            },
        }
        self.load_commands.appendAssumeCapacity(cmd);
    }
}

fn parseId(self: *Dylib, allocator: *Allocator) !void {
    const index = self.id_cmd_index orelse {
        log.debug("no LC_ID_DYLIB load command found; using hard-coded defaults...", .{});
        self.id = try Id.default(allocator, self.name);
        return;
    };
    self.id = try Id.fromLoadCommand(allocator, self.load_commands.items[index].Dylib);
}

fn parseSymbols(self: *Dylib, allocator: *Allocator) !void {
    const index = self.symtab_cmd_index orelse return;
    const symtab_cmd = self.load_commands.items[index].Symtab;

    var symtab = try allocator.alloc(u8, @sizeOf(macho.nlist_64) * symtab_cmd.nsyms);
    defer allocator.free(symtab);
    _ = try self.file.preadAll(symtab, symtab_cmd.symoff + self.library_offset);
    const slice = @alignCast(@alignOf(macho.nlist_64), mem.bytesAsSlice(macho.nlist_64, symtab));

    var strtab = try allocator.alloc(u8, symtab_cmd.strsize);
    defer allocator.free(strtab);
    _ = try self.file.preadAll(strtab, symtab_cmd.stroff + self.library_offset);

    for (slice) |sym| {
        const add_to_symtab = MachO.symbolIsExt(sym) and (MachO.symbolIsSect(sym) or MachO.symbolIsIndr(sym));

        if (!add_to_symtab) continue;

        const sym_name = mem.spanZ(@ptrCast([*:0]const u8, strtab.ptr + sym.n_strx));
        const name = try allocator.dupe(u8, sym_name);
        try self.symbols.putNoClobber(allocator, name, {});
    }
}

fn hasTarget(targets: []const []const u8, target: []const u8) bool {
    for (targets) |t| {
        if (mem.eql(u8, t, target)) return true;
    }
    return false;
}

fn addObjCClassSymbols(self: *Dylib, allocator: *Allocator, sym_name: []const u8) !void {
    const expanded = &[_][]const u8{
        try std.fmt.allocPrint(allocator, "_OBJC_CLASS_$_{s}", .{sym_name}),
        try std.fmt.allocPrint(allocator, "_OBJC_METACLASS_$_{s}", .{sym_name}),
    };

    for (expanded) |sym| {
        if (self.symbols.contains(sym)) continue;
        try self.symbols.putNoClobber(allocator, sym, .{});
    }
}

pub fn parseFromStub(self: *Dylib, allocator: *Allocator, arch: Arch, lib_stub: LibStub) !void {
    if (lib_stub.inner.len == 0) return error.EmptyStubFile;

    log.debug("parsing shared library from stub '{s}'", .{self.name});

    const umbrella_lib = lib_stub.inner[0];

    var id = try Id.default(allocator, umbrella_lib.install_name);
    if (umbrella_lib.current_version) |version| {
        try id.parseCurrentVersion(version);
    }
    if (umbrella_lib.compatibility_version) |version| {
        try id.parseCompatibilityVersion(version);
    }
    self.id = id;

    const target_string: []const u8 = switch (arch) {
        .aarch64 => "arm64-macos",
        .x86_64 => "x86_64-macos",
        else => unreachable,
    };

    var umbrella_libs = std.StringHashMap(void).init(allocator);
    defer umbrella_libs.deinit();

    for (lib_stub.inner) |stub, stub_index| {
        if (!hasTarget(stub.targets, target_string)) continue;

        if (stub_index > 0) {
            // TODO I thought that we could switch on presence of `parent-umbrella` map;
            // however, turns out `libsystem_notify.dylib` is fully reexported by `libSystem.dylib`
            // BUT does not feature a `parent-umbrella` map as the only sublib. Apple's bug perhaps?
            try umbrella_libs.put(stub.install_name, .{});
        }

        if (stub.exports) |exports| {
            for (exports) |exp| {
                if (!hasTarget(exp.targets, target_string)) continue;

                if (exp.symbols) |symbols| {
                    for (symbols) |sym_name| {
                        if (self.symbols.contains(sym_name)) continue;
                        try self.symbols.putNoClobber(allocator, try allocator.dupe(u8, sym_name), {});
                    }
                }

                if (exp.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbols(allocator, sym_name);
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
                        try self.symbols.putNoClobber(allocator, try allocator.dupe(u8, sym_name), {});
                    }
                }

                if (reexp.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbols(allocator, sym_name);
                    }
                }
            }
        }

        if (stub.objc_classes) |classes| {
            for (classes) |sym_name| {
                try self.addObjCClassSymbols(allocator, sym_name);
            }
        }
    }

    log.debug("{s}", .{umbrella_lib.install_name});

    // TODO track which libs were already parsed in different steps
    for (lib_stub.inner) |stub| {
        if (!hasTarget(stub.targets, target_string)) continue;

        if (stub.reexported_libraries) |reexports| {
            for (reexports) |reexp| {
                if (!hasTarget(reexp.targets, target_string)) continue;

                for (reexp.libraries) |lib| {
                    if (umbrella_libs.contains(lib)) {
                        log.debug("  | {s} <= {s}", .{ lib, umbrella_lib.install_name });
                        continue;
                    }

                    log.debug("  | {s}", .{lib});

                    const dep_id = try Id.default(allocator, lib);
                    try self.dependent_libs.append(allocator, dep_id);
                }
            }
        }
    }
}

pub fn parseDependentLibs(
    self: *Dylib,
    allocator: *Allocator,
    arch: Arch,
    out: *std.ArrayList(Dylib),
    syslibroot: ?[]const u8,
) !void {
    outer: for (self.dependent_libs.items) |id| {
        const has_ext = blk: {
            const basename = fs.path.basename(id.name);
            break :blk mem.lastIndexOfScalar(u8, basename, '.') != null;
        };
        const extension = if (has_ext) fs.path.extension(id.name) else "";
        const without_ext = if (has_ext) blk: {
            const index = mem.lastIndexOfScalar(u8, id.name, '.') orelse unreachable;
            break :blk id.name[0..index];
        } else id.name;

        for (&[_][]const u8{ extension, ".tbd" }) |ext| {
            const with_ext = try std.fmt.allocPrint(allocator, "{s}{s}", .{
                without_ext,
                ext,
            });
            defer allocator.free(with_ext);

            const full_path = if (syslibroot) |root|
                try fs.path.join(allocator, &.{ root, with_ext })
            else
                with_ext;
            defer if (syslibroot) |_| allocator.free(full_path);

            log.debug("trying dependency at fully resolved path {s}", .{full_path});

            const dylibs = (try createAndParseFromPath(
                allocator,
                arch,
                full_path,
                .{
                    .id = id,
                    .syslibroot = syslibroot,
                },
            )) orelse {
                continue;
            };
            defer allocator.free(dylibs);

            try out.appendSlice(dylibs);

            continue :outer;
        } else {
            log.warn("unable to resolve dependency {s}", .{id.name});
        }
    }
}
