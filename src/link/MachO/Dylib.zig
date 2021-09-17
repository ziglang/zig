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

    pub const ParseError = fmt.ParseIntError || fmt.BufPrintError;

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
                log.debug("malformed version field: {s}", .{string});
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

pub fn parse(self: *Dylib, allocator: *Allocator, target: std.Target) !void {
    log.debug("parsing shared library '{s}'", .{self.name});

    self.library_offset = try fat.getLibraryOffset(self.file.reader(), target);

    try self.file.seekTo(self.library_offset);

    var reader = self.file.reader();
    self.header = try reader.readStruct(macho.mach_header_64);

    if (self.header.?.filetype != macho.MH_DYLIB) {
        log.debug("invalid filetype: expected 0x{x}, found 0x{x}", .{ macho.MH_DYLIB, self.header.?.filetype });
        return error.NotDylib;
    }

    const this_arch: std.Target.Cpu.Arch = try fat.decodeArch(self.header.?.cputype, true);

    if (this_arch != target.cpu.arch) {
        log.err("mismatched cpu architecture: expected {s}, found {s}", .{ target.cpu.arch, this_arch });
        return error.MismatchedCpuArchitecture;
    }

    try self.readLoadCommands(allocator, reader);
    try self.parseId(allocator);
    try self.parseSymbols(allocator);
}

fn readLoadCommands(self: *Dylib, allocator: *Allocator, reader: anytype) !void {
    const should_lookup_reexports = self.header.?.flags & macho.MH_NO_REEXPORTED_DYLIBS == 0;

    try self.load_commands.ensureTotalCapacity(allocator, self.header.?.ncmds);

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

fn addObjCClassSymbol(self: *Dylib, allocator: *Allocator, sym_name: []const u8) !void {
    const expanded = &[_][]const u8{
        try std.fmt.allocPrint(allocator, "_OBJC_CLASS_$_{s}", .{sym_name}),
        try std.fmt.allocPrint(allocator, "_OBJC_METACLASS_$_{s}", .{sym_name}),
    };

    for (expanded) |sym| {
        if (self.symbols.contains(sym)) continue;
        try self.symbols.putNoClobber(allocator, sym, .{});
    }
}

fn addSymbol(self: *Dylib, allocator: *Allocator, sym_name: []const u8) !void {
    if (self.symbols.contains(sym_name)) return;
    try self.symbols.putNoClobber(allocator, try allocator.dupe(u8, sym_name), {});
}

const TargetMatcher = struct {
    allocator: *Allocator,
    target: std.Target,
    target_strings: std.ArrayListUnmanaged([]const u8) = .{},

    fn init(allocator: *Allocator, target: std.Target) !TargetMatcher {
        var self = TargetMatcher{
            .allocator = allocator,
            .target = target,
        };
        try self.target_strings.append(allocator, try targetToAppleString(allocator, target));

        if (target.abi == .simulator) {
            // For Apple simulator targets, linking gets tricky as we need to link against the simulator
            // hosts dylibs too.
            const host_target = try targetToAppleString(allocator, (std.zig.CrossTarget{
                .cpu_arch = target.cpu.arch,
                .os_tag = .macos,
            }).toTarget());
            try self.target_strings.append(allocator, host_target);
        }

        return self;
    }

    fn deinit(self: *TargetMatcher) void {
        for (self.target_strings.items) |t| {
            self.allocator.free(t);
        }
        self.target_strings.deinit(self.allocator);
    }

    fn targetToAppleString(allocator: *Allocator, target: std.Target) ![]const u8 {
        const arch = switch (target.cpu.arch) {
            .aarch64 => "arm64",
            .x86_64 => "x86_64",
            else => unreachable,
        };
        const os = @tagName(target.os.tag);
        const abi: ?[]const u8 = switch (target.abi) {
            .gnu => null,
            .simulator => "simulator",
            else => unreachable,
        };
        if (abi) |x| {
            return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ arch, os, x });
        }
        return std.fmt.allocPrint(allocator, "{s}-{s}", .{ arch, os });
    }

    fn hasValue(stack: []const []const u8, needle: []const u8) bool {
        for (stack) |v| {
            if (mem.eql(u8, v, needle)) return true;
        }
        return false;
    }

    fn matchesTarget(self: TargetMatcher, targets: []const []const u8) bool {
        for (self.target_strings.items) |t| {
            if (hasValue(targets, t)) return true;
        }
        return false;
    }

    fn matchesArch(self: TargetMatcher, archs: []const []const u8) bool {
        return hasValue(archs, @tagName(self.target.cpu.arch));
    }
};

pub fn parseFromStub(self: *Dylib, allocator: *Allocator, target: std.Target, lib_stub: LibStub) !void {
    if (lib_stub.inner.len == 0) return error.EmptyStubFile;

    log.debug("parsing shared library from stub '{s}'", .{self.name});

    const umbrella_lib = lib_stub.inner[0];

    var id = try Id.default(allocator, umbrella_lib.installName());
    if (umbrella_lib.currentVersion()) |version| {
        try id.parseCurrentVersion(version);
    }
    if (umbrella_lib.compatibilityVersion()) |version| {
        try id.parseCompatibilityVersion(version);
    }
    self.id = id;

    var umbrella_libs = std.StringHashMap(void).init(allocator);
    defer umbrella_libs.deinit();

    log.debug("  (install_name '{s}')", .{umbrella_lib.installName()});

    var matcher = try TargetMatcher.init(allocator, target);
    defer matcher.deinit();

    for (lib_stub.inner) |elem, stub_index| {
        const is_match = switch (elem) {
            .v3 => |stub| matcher.matchesArch(stub.archs),
            .v4 => |stub| matcher.matchesTarget(stub.targets),
        };
        if (!is_match) continue;

        if (stub_index > 0) {
            // TODO I thought that we could switch on presence of `parent-umbrella` map;
            // however, turns out `libsystem_notify.dylib` is fully reexported by `libSystem.dylib`
            // BUT does not feature a `parent-umbrella` map as the only sublib. Apple's bug perhaps?
            try umbrella_libs.put(elem.installName(), .{});
        }

        switch (elem) {
            .v3 => |stub| {
                if (stub.exports) |exports| {
                    for (exports) |exp| {
                        if (!matcher.matchesArch(exp.archs)) continue;

                        if (exp.symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addSymbol(allocator, sym_name);
                            }
                        }

                        if (exp.objc_classes) |objc_classes| {
                            for (objc_classes) |class_name| {
                                try self.addObjCClassSymbol(allocator, class_name);
                            }
                        }

                        // TODO track which libs were already parsed in different steps
                        if (exp.re_exports) |re_exports| {
                            for (re_exports) |lib| {
                                if (umbrella_libs.contains(lib)) continue;

                                log.debug("  (found re-export '{s}')", .{lib});

                                const dep_id = try Id.default(allocator, lib);
                                try self.dependent_libs.append(allocator, dep_id);
                            }
                        }
                    }
                }
            },
            .v4 => |stub| {
                if (stub.exports) |exports| {
                    for (exports) |exp| {
                        if (!matcher.matchesTarget(exp.targets)) continue;

                        if (exp.symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addSymbol(allocator, sym_name);
                            }
                        }

                        if (exp.objc_classes) |classes| {
                            for (classes) |sym_name| {
                                try self.addObjCClassSymbol(allocator, sym_name);
                            }
                        }
                    }
                }

                if (stub.reexports) |reexports| {
                    for (reexports) |reexp| {
                        if (!matcher.matchesTarget(reexp.targets)) continue;

                        if (reexp.symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addSymbol(allocator, sym_name);
                            }
                        }

                        if (reexp.objc_classes) |classes| {
                            for (classes) |sym_name| {
                                try self.addObjCClassSymbol(allocator, sym_name);
                            }
                        }
                    }
                }

                if (stub.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbol(allocator, sym_name);
                    }
                }
            },
        }
    }

    // For V4, we add dependent libs in a separate pass since some stubs such as libSystem include
    // re-exports directly in the stub file.
    for (lib_stub.inner) |elem| {
        if (elem == .v3) break;
        const stub = elem.v4;

        // TODO track which libs were already parsed in different steps
        if (stub.reexported_libraries) |reexports| {
            for (reexports) |reexp| {
                if (!matcher.matchesTarget(reexp.targets)) continue;

                for (reexp.libraries) |lib| {
                    if (umbrella_libs.contains(lib)) continue;

                    log.debug("  (found re-export '{s}')", .{lib});

                    const dep_id = try Id.default(allocator, lib);
                    try self.dependent_libs.append(allocator, dep_id);
                }
            }
        }
    }
}

pub fn parseDependentLibs(
    self: *Dylib,
    macho_file: *MachO,
    syslibroot: ?[]const u8,
) !void {
    outer: for (self.dependent_libs.items) |id| {
        if (macho_file.dylibs_map.contains(id.name)) continue :outer;

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
            const with_ext = try std.fmt.allocPrint(macho_file.base.allocator, "{s}{s}", .{
                without_ext,
                ext,
            });
            defer macho_file.base.allocator.free(with_ext);

            const full_path = if (syslibroot) |root|
                try fs.path.join(macho_file.base.allocator, &.{ root, with_ext })
            else
                with_ext;
            defer if (syslibroot) |_| macho_file.base.allocator.free(full_path);

            log.debug("trying dependency at fully resolved path {s}", .{full_path});

            const did_parse_successfully = try macho_file.parseDylib(full_path, .{
                .id = id,
                .syslibroot = syslibroot,
                .is_dependent = true,
            });
            if (!did_parse_successfully) continue;
        } else {
            log.debug("unable to resolve dependency {s}", .{id.name});
        }
    }
}
