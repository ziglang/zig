const Dylib = @This();

const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const fmt = std.fmt;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const fat = @import("fat.zig");
const tapi = @import("../tapi.zig");

const Allocator = mem.Allocator;
const CrossTarget = std.zig.CrossTarget;
const LibStub = tapi.LibStub;
const LoadCommandIterator = macho.LoadCommandIterator;
const MachO = @import("../MachO.zig");
const Tbd = tapi.Tbd;

id: ?Id = null,
weak: bool = false,
/// Header is only set if Dylib is parsed directly from a binary and not a stub file.
header: ?macho.mach_header_64 = null,

/// Parsed symbol table represented as hash map of symbols'
/// names. We can and should defer creating *Symbols until
/// a symbol is referenced by an object file.
///
/// The value for each parsed symbol represents whether the
/// symbol is defined as a weak symbol or strong.
/// TODO when the referenced symbol is weak, ld64 marks it as
/// N_REF_TO_WEAK but need to investigate if there's more to it
/// such as weak binding entry or simply weak. For now, we generate
/// standard bind or lazy bind.
symbols: std.StringArrayHashMapUnmanaged(bool) = .{},

pub const Id = struct {
    name: []const u8,
    timestamp: u32,
    current_version: u32,
    compatibility_version: u32,

    pub fn default(allocator: Allocator, name: []const u8) !Id {
        return Id{
            .name = try allocator.dupe(u8, name),
            .timestamp = 2,
            .current_version = 0x10000,
            .compatibility_version = 0x10000,
        };
    }

    pub fn fromLoadCommand(allocator: Allocator, lc: macho.dylib_command, name: []const u8) !Id {
        return Id{
            .name = try allocator.dupe(u8, name),
            .timestamp = lc.dylib.timestamp,
            .current_version = lc.dylib.current_version,
            .compatibility_version = lc.dylib.compatibility_version,
        };
    }

    pub fn deinit(id: Id, allocator: Allocator) void {
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
                    const major = math.cast(u16, int) orelse return error.Overflow;
                    out += @as(u32, @intCast(major)) << 16;
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

        var split = mem.splitScalar(u8, string, '.');
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
            out += @as(u32, @intCast(try fmt.parseInt(u8, values[1], 10))) << 8;
        }
        out += @as(u32, @intCast(try fmt.parseInt(u16, values[0], 10))) << 16;

        return out;
    }
};

pub fn isDylib(file: std.fs.File, fat_offset: u64) bool {
    const reader = file.reader();
    const hdr = reader.readStruct(macho.mach_header_64) catch return false;
    defer file.seekTo(fat_offset) catch {};
    return hdr.filetype == macho.MH_DYLIB;
}

pub fn deinit(self: *Dylib, allocator: Allocator) void {
    for (self.symbols.keys()) |key| {
        allocator.free(key);
    }
    self.symbols.deinit(allocator);
    if (self.id) |*id| {
        id.deinit(allocator);
    }
}

pub fn parseFromBinary(
    self: *Dylib,
    allocator: Allocator,
    dylib_id: u16,
    dependent_libs: anytype,
    name: []const u8,
    data: []align(@alignOf(u64)) const u8,
) !void {
    var stream = std.io.fixedBufferStream(data);
    const reader = stream.reader();

    log.debug("parsing shared library '{s}'", .{name});

    self.header = try reader.readStruct(macho.mach_header_64);

    const should_lookup_reexports = self.header.?.flags & macho.MH_NO_REEXPORTED_DYLIBS == 0;
    var it = LoadCommandIterator{
        .ncmds = self.header.?.ncmds,
        .buffer = data[@sizeOf(macho.mach_header_64)..][0..self.header.?.sizeofcmds],
    };
    while (it.next()) |cmd| {
        switch (cmd.cmd()) {
            .SYMTAB => {
                const symtab_cmd = cmd.cast(macho.symtab_command).?;
                const symtab = @as(
                    [*]const macho.nlist_64,
                    // Alignment is guaranteed as a dylib is a final linked image and has to have sections
                    // properly aligned in order to be correctly loaded by the loader.
                    @ptrCast(@alignCast(&data[symtab_cmd.symoff])),
                )[0..symtab_cmd.nsyms];
                const strtab = data[symtab_cmd.stroff..][0..symtab_cmd.strsize];

                for (symtab) |sym| {
                    const add_to_symtab = sym.ext() and (sym.sect() or sym.indr());
                    if (!add_to_symtab) continue;

                    const sym_name = mem.sliceTo(@as([*:0]const u8, @ptrCast(strtab.ptr + sym.n_strx)), 0);
                    try self.symbols.putNoClobber(allocator, try allocator.dupe(u8, sym_name), false);
                }
            },
            .ID_DYLIB => {
                self.id = try Id.fromLoadCommand(
                    allocator,
                    cmd.cast(macho.dylib_command).?,
                    cmd.getDylibPathName(),
                );
            },
            .REEXPORT_DYLIB => {
                if (should_lookup_reexports) {
                    // Parse install_name to dependent dylib.
                    var id = try Id.fromLoadCommand(
                        allocator,
                        cmd.cast(macho.dylib_command).?,
                        cmd.getDylibPathName(),
                    );
                    try dependent_libs.writeItem(.{ .id = id, .parent = dylib_id });
                }
            },
            else => {},
        }
    }
}

fn addObjCClassSymbol(self: *Dylib, allocator: Allocator, sym_name: []const u8) !void {
    const expanded = &[_][]const u8{
        try std.fmt.allocPrint(allocator, "_OBJC_CLASS_$_{s}", .{sym_name}),
        try std.fmt.allocPrint(allocator, "_OBJC_METACLASS_$_{s}", .{sym_name}),
    };

    for (expanded) |sym| {
        if (self.symbols.contains(sym)) continue;
        try self.symbols.putNoClobber(allocator, sym, false);
    }
}

fn addObjCIVarSymbol(self: *Dylib, allocator: Allocator, sym_name: []const u8) !void {
    const expanded = try std.fmt.allocPrint(allocator, "_OBJC_IVAR_$_{s}", .{sym_name});
    if (self.symbols.contains(expanded)) return;
    try self.symbols.putNoClobber(allocator, expanded, false);
}

fn addObjCEhTypeSymbol(self: *Dylib, allocator: Allocator, sym_name: []const u8) !void {
    const expanded = try std.fmt.allocPrint(allocator, "_OBJC_EHTYPE_$_{s}", .{sym_name});
    if (self.symbols.contains(expanded)) return;
    try self.symbols.putNoClobber(allocator, expanded, false);
}

fn addSymbol(self: *Dylib, allocator: Allocator, sym_name: []const u8) !void {
    if (self.symbols.contains(sym_name)) return;
    try self.symbols.putNoClobber(allocator, try allocator.dupe(u8, sym_name), false);
}

fn addWeakSymbol(self: *Dylib, allocator: Allocator, sym_name: []const u8) !void {
    if (self.symbols.contains(sym_name)) return;
    try self.symbols.putNoClobber(allocator, try allocator.dupe(u8, sym_name), true);
}

const TargetMatcher = struct {
    allocator: Allocator,
    target: CrossTarget,
    target_strings: std.ArrayListUnmanaged([]const u8) = .{},

    fn init(allocator: Allocator, target: CrossTarget) !TargetMatcher {
        var self = TargetMatcher{
            .allocator = allocator,
            .target = target,
        };
        const apple_string = try targetToAppleString(allocator, target);
        try self.target_strings.append(allocator, apple_string);

        const abi = target.abi orelse .none;
        if (abi == .simulator) {
            // For Apple simulator targets, linking gets tricky as we need to link against the simulator
            // hosts dylibs too.
            const host_target = try targetToAppleString(allocator, .{
                .cpu_arch = target.cpu_arch.?,
                .os_tag = .macos,
            });
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

    inline fn cpuArchToAppleString(cpu_arch: std.Target.Cpu.Arch) []const u8 {
        return switch (cpu_arch) {
            .aarch64 => "arm64",
            .x86_64 => "x86_64",
            else => unreachable,
        };
    }

    inline fn abiToAppleString(abi: std.Target.Abi) ?[]const u8 {
        return switch (abi) {
            .none => null,
            .simulator => "simulator",
            .macabi => "maccatalyst",
            else => unreachable,
        };
    }

    fn targetToAppleString(allocator: Allocator, target: CrossTarget) ![]const u8 {
        const cpu_arch = cpuArchToAppleString(target.cpu_arch.?);
        const os_tag = @tagName(target.os_tag.?);
        const target_abi = abiToAppleString(target.abi orelse .none);
        if (target_abi) |abi| {
            return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ cpu_arch, os_tag, abi });
        }
        return std.fmt.allocPrint(allocator, "{s}-{s}", .{ cpu_arch, os_tag });
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
        return hasValue(archs, cpuArchToAppleString(self.target.cpu_arch.?));
    }

    fn matchesTargetTbd(self: TargetMatcher, tbd: Tbd) !bool {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const targets = switch (tbd) {
            .v3 => |v3| blk: {
                var targets = std.ArrayList([]const u8).init(arena.allocator());
                for (v3.archs) |arch| {
                    const target = try std.fmt.allocPrint(arena.allocator(), "{s}-{s}", .{ arch, v3.platform });
                    try targets.append(target);
                }
                break :blk targets.items;
            },
            .v4 => |v4| v4.targets,
        };

        return self.matchesTarget(targets);
    }
};

pub fn parseFromStub(
    self: *Dylib,
    allocator: Allocator,
    target: std.Target,
    lib_stub: LibStub,
    dylib_id: u16,
    dependent_libs: anytype,
    name: []const u8,
) !void {
    if (lib_stub.inner.len == 0) return error.EmptyStubFile;

    log.debug("parsing shared library from stub '{s}'", .{name});

    const umbrella_lib = lib_stub.inner[0];

    {
        var id = try Id.default(allocator, umbrella_lib.installName());
        if (umbrella_lib.currentVersion()) |version| {
            try id.parseCurrentVersion(version);
        }
        if (umbrella_lib.compatibilityVersion()) |version| {
            try id.parseCompatibilityVersion(version);
        }
        self.id = id;
    }

    var umbrella_libs = std.StringHashMap(void).init(allocator);
    defer umbrella_libs.deinit();

    log.debug("  (install_name '{s}')", .{umbrella_lib.installName()});

    var matcher = try TargetMatcher.init(allocator, .{
        .cpu_arch = target.cpu.arch,
        .os_tag = target.os.tag,
        .abi = target.abi,
    });
    defer matcher.deinit();

    for (lib_stub.inner, 0..) |elem, stub_index| {
        if (!(try matcher.matchesTargetTbd(elem))) continue;

        if (stub_index > 0) {
            // TODO I thought that we could switch on presence of `parent-umbrella` map;
            // however, turns out `libsystem_notify.dylib` is fully reexported by `libSystem.dylib`
            // BUT does not feature a `parent-umbrella` map as the only sublib. Apple's bug perhaps?
            try umbrella_libs.put(elem.installName(), {});
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

                        if (exp.weak_symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addWeakSymbol(allocator, sym_name);
                            }
                        }

                        if (exp.objc_classes) |objc_classes| {
                            for (objc_classes) |class_name| {
                                try self.addObjCClassSymbol(allocator, class_name);
                            }
                        }

                        if (exp.objc_ivars) |objc_ivars| {
                            for (objc_ivars) |ivar| {
                                try self.addObjCIVarSymbol(allocator, ivar);
                            }
                        }

                        if (exp.objc_eh_types) |objc_eh_types| {
                            for (objc_eh_types) |eht| {
                                try self.addObjCEhTypeSymbol(allocator, eht);
                            }
                        }

                        // TODO track which libs were already parsed in different steps
                        if (exp.re_exports) |re_exports| {
                            for (re_exports) |lib| {
                                if (umbrella_libs.contains(lib)) continue;

                                log.debug("  (found re-export '{s}')", .{lib});

                                var dep_id = try Id.default(allocator, lib);
                                try dependent_libs.writeItem(.{ .id = dep_id, .parent = dylib_id });
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

                        if (exp.weak_symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addWeakSymbol(allocator, sym_name);
                            }
                        }

                        if (exp.objc_classes) |classes| {
                            for (classes) |sym_name| {
                                try self.addObjCClassSymbol(allocator, sym_name);
                            }
                        }

                        if (exp.objc_ivars) |objc_ivars| {
                            for (objc_ivars) |ivar| {
                                try self.addObjCIVarSymbol(allocator, ivar);
                            }
                        }

                        if (exp.objc_eh_types) |objc_eh_types| {
                            for (objc_eh_types) |eht| {
                                try self.addObjCEhTypeSymbol(allocator, eht);
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

                        if (reexp.weak_symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addWeakSymbol(allocator, sym_name);
                            }
                        }

                        if (reexp.objc_classes) |classes| {
                            for (classes) |sym_name| {
                                try self.addObjCClassSymbol(allocator, sym_name);
                            }
                        }

                        if (reexp.objc_ivars) |objc_ivars| {
                            for (objc_ivars) |ivar| {
                                try self.addObjCIVarSymbol(allocator, ivar);
                            }
                        }

                        if (reexp.objc_eh_types) |objc_eh_types| {
                            for (objc_eh_types) |eht| {
                                try self.addObjCEhTypeSymbol(allocator, eht);
                            }
                        }
                    }
                }

                if (stub.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClassSymbol(allocator, sym_name);
                    }
                }

                if (stub.objc_ivars) |objc_ivars| {
                    for (objc_ivars) |ivar| {
                        try self.addObjCIVarSymbol(allocator, ivar);
                    }
                }

                if (stub.objc_eh_types) |objc_eh_types| {
                    for (objc_eh_types) |eht| {
                        try self.addObjCEhTypeSymbol(allocator, eht);
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

                    var dep_id = try Id.default(allocator, lib);
                    try dependent_libs.writeItem(.{ .id = dep_id, .parent = dylib_id });
                }
            }
        }
    }
}
